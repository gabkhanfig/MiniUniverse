const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const expect = std.testing.expect;
const Thread = std.Thread;
const Mutex = Thread.Mutex;
const Condition = Thread.Condition;
const Atomic = std.atomic.Value;
const AtomicOrder = std.builtin.AtomicOrder;

/// Number of jobs each `JobThread` can have queued.
const JOB_QUEUE_CAPACITY = 8192;

/// Future for job completion.
/// For all `runJob()` functions, or making a job and explicitly doing `call()`,
/// the future CANNOT be ignored, as it uses atomic reference counting to deallocate
/// the future. To ignore the future, call `deinit()`. To get the return value,
/// call `wait()`.
pub fn Future(comptime T: type) type {
    return struct {
        const Self = @This();

        shared: *anyopaque,

        pub fn init(shared: *JobFutureSharedMutex(T)) Self {
            _ = shared.counter.fetchAdd(1, AtomicOrder.SeqCst);
            return Self{ .shared = @ptrCast(shared) };
        }

        /// Explicitly do not `wait()`.
        /// To get the job return value, call `wait()`.
        pub fn deinit(self: Self) void {
            const sharedCast: *JobFutureSharedMutex(T) = @ptrCast(@alignCast(self.shared));
            sharedCast.decrementRefCount();
        }

        /// Halts this threads execution, waiting until the job has finished executing,
        /// returning the job function's return value.
        /// To discard and continue execution, call `deinit()` instead.
        pub fn wait(self: Self) T {
            const sharedCast: *JobFutureSharedMutex(T) = @ptrCast(@alignCast(self.shared));

            while (true) {
                if (!sharedCast.mutex.tryLock()) {
                    if (std.Thread.yield()) {
                        continue;
                    } else |_| {
                        @panic("failed to yield thread??");
                    }
                }

                if (sharedCast.data) |data| { // get the actual data
                    sharedCast.decrementRefCount();
                    return data;
                } else {
                    sharedCast.mutex.unlock();
                    if (std.Thread.yield()) {
                        continue;
                    } else |_| {
                        @panic("failed to yield thread??");
                    }
                    continue;
                }
            }
        }
    };
}

/// Thread pool, owning multiple `JobThread` instances. Can execute a job, which
/// is a function, and arguments to the function, with a future for it's completion.
/// Will load balance the jobs across the `JobThread` instances.
pub const JobSystem = struct {
    const Self = @This();

    impl: *anyopaque,

    /// Creates a new job system, using `inThreadCount` threads.
    /// Takes ownership of `allocator`, which will be used to allocate
    /// the threads, jobs, and everything else.
    /// Errors can occur from either allocation errors, or thread errors.
    pub fn init(allocator: Allocator, inThreadCount: usize) !Self {
        assert(inThreadCount > 0);
        const impl = try allocator.create(JobSystemImpl);
        impl.currentThread = Atomic(usize).init(0);
        impl.allocator = allocator;

        impl.threads = try impl.allocator.alloc(*JobThread, inThreadCount);
        for (0..inThreadCount) |i| {
            impl.threads[i] = try JobThread.init(&impl.allocator);
        }
        return Self{ .impl = @ptrCast(impl) };
    }

    /// Finishes execution of all existing queued jobs,
    /// freeing all resources, and joining all threads.
    pub fn deinit(self: *Self) void {
        const implCast: *JobSystemImpl = @ptrCast(@alignCast(self.impl));
        const allocator = implCast.allocator;
        for (0..implCast.threads.len) |i| {
            implCast.threads[i].deinit();
        }
        allocator.free(implCast.threads);
        allocator.destroy(implCast);
    }

    /// The number of threads this JobSystem instance owns.
    pub fn threadCount(self: *const Self) usize {
        const implCast: *const JobSystemImpl = @ptrCast(@alignCast(self.impl));
        return implCast.threads.len;
    }

    /// Runs a job given a `function` and tuple `args` to call `function` with.
    /// Returns a future, optionally holding the return value of `function`.
    /// The future cannot be ignored, as it uses shared ref counting.
    /// Call `wait()` or `deinit()` on the future if it's not needed.
    pub fn runJob(self: *Self, function: anytype, args: anytype) Allocator.Error!Future(JobFuturePair(@TypeOf(function)).RetT()) {
        const newOptimal = self.getOptimalThreadIndexForExecution();
        const implCast: *JobSystemImpl = @ptrCast(@alignCast(self.impl));

        implCast.currentThread.store(newOptimal, AtomicOrder.Release);

        return implCast.threads[newOptimal].runJob(function, args);
    }

    fn getOptimalThreadIndexForExecution(self: *const Self) usize {
        const implCast: *const JobSystemImpl = @ptrCast(@alignCast(self.impl));
        const oldCurrent = implCast.currentThread.load(AtomicOrder.Acquire);

        for (0..implCast.threads.len) |i| {
            const checkIndex = (oldCurrent + i) % implCast.threads.len;
            const isNotExecuting = implCast.threads[checkIndex].isExecuting.load(AtomicOrder.Acquire);
            if (isNotExecuting) {
                return checkIndex;
            }
        }
        return (oldCurrent + 1) % implCast.threads.len;
    }
};

const JobSystemImpl = struct {
    threads: []*JobThread,
    /// Circular index around `threadCount`. Ideally, this will allow
    /// dynamic load balancing for running many jobs.
    currentThread: Atomic(usize),
    allocator: Allocator,
};

/// Wrapper around a thread to run jobs.
pub const JobThread = struct {
    const Self = @This();

    /// DO NOT MODIFY
    threadId: Thread.Id = 0,

    isExecuting: Atomic(bool) = Atomic(bool).init(false),
    shouldExecute: Atomic(bool) = Atomic(bool).init(false),
    isPendingKill: Atomic(bool) = Atomic(bool).init(false),

    condMutex: Mutex = .{},
    condVar: Condition = .{},
    thread: Thread,

    queueMutex: Mutex = .{},
    queue: JobRingQueue = .{},

    activeMutex: Mutex = .{},
    activeWork: ActiveJobs = .{},

    allocator: *Allocator,

    pub fn init(allocator: *Allocator) !*JobThread {
        const jobThread = try allocator.create(Self);
        jobThread.* = .{ .allocator = allocator, .thread = try Thread.spawn(.{ .allocator = allocator.* }, Self.threadLoop, .{jobThread}) };
        std.Thread.yield() catch unreachable;
        return jobThread;
    }

    pub fn deinit(self: *Self) void {
        const allocator = self.allocator;
        self.wait();
        self.isPendingKill.store(true, AtomicOrder.Release);
        self.notifyExecute();
        self.thread.join();
        allocator.destroy(self);
    }

    pub fn wait(self: *const Self) void {
        if (Thread.yield()) {} else |_| {
            @panic("failed to yield thread");
        }

        while (self.isExecuting.load(AtomicOrder.Acquire) == true) {
            if (Thread.yield()) {} else |_| {
                @panic("failed to yield thread");
            }
        }
    }

    /// Runs a job given a `function` and tuple `args` to call `function` with.
    /// Returns a future, optionally holding the return value of `function`.
    /// The future cannot be ignored, as it uses shared ref counting.
    /// Call `wait()` or `deinit()` on the future if it's not needed.
    pub fn runJob(self: *Self, function: anytype, args: anytype) Allocator.Error!Future(JobFuturePair(@TypeOf(function)).RetT()) {
        const pair = try Job.init(self.allocator, function, args);
        self.queueMutex.lock();
        self.queue.push(pair.job);
        self.queueMutex.unlock();
        self.notifyExecute();
        return pair.future;
    }

    fn threadLoop(self: *Self) void {
        self.threadId = Thread.getCurrentId();
        while (self.isPendingKill.load(AtomicOrder.Acquire) == false) {
            self.queueMutex.lock();
            if (self.queue.len != 0) { // has jobs
                self.activeMutex.lock();
                self.activeWork.collectJobs(&self.queue);
                self.activeWork.invokeAllJobs();
                self.queueMutex.unlock();
                self.activeMutex.unlock();
                continue;
            }
            self.queueMutex.unlock();

            self.isExecuting.store(false, AtomicOrder.Release);
            self.condMutex.lock();
            self.condVar.wait(&self.condMutex);
            self.condMutex.unlock();

            self.queueMutex.lock();
            self.activeMutex.lock();
            self.activeWork.collectJobs(&self.queue);
            self.activeWork.invokeAllJobs();
            self.queueMutex.unlock();
            self.activeMutex.unlock();

            continue;
        }
    }

    fn notifyExecute(self: *Self) void {
        if (self.isExecuting.load(AtomicOrder.Acquire) == true) {
            // should already be looping the execution, in which if it has any queued jobs, it will execute them.
            return;
        }

        self.condMutex.lock();
        defer self.condMutex.unlock();

        self.condVar.signal();
        self.isExecuting.store(true, AtomicOrder.Release);
    }
};

///
pub const Job = struct {
    ptr: *anyopaque,
    func: *const fn (*anyopaque) void,

    ///
    pub fn init(allocator: *Allocator, function: anytype, args: anytype) Allocator.Error!JobFuturePair(@TypeOf(function)) {
        const typeOfFunc = @TypeOf(function);
        const PairT = JobFuturePair(typeOfFunc);

        return JobImpl(typeOfFunc, PairT.ArgTuple(), PairT.RetT()).init(allocator, function, args);
    }

    /// Invalidates and frees this Job afterwards. Cannot run `call()` twice.
    pub fn call(self: *Job) void {
        self.func(self.ptr);
    }
};

fn JobImpl(comptime FuncT: type, comptime ArgT: type, comptime RetT: type) type {
    return struct {
        const Self = @This();

        function: *const FuncT,
        args: ArgT,
        future: WithinJobFuture(RetT),
        allocator: *Allocator,

        fn init(
            allocator: *Allocator,
            function: anytype,
            args: ArgT,
        ) Allocator.Error!JobFuturePair(@TypeOf(function)) {
            const self = try allocator.create(Self);
            self.function = function;
            self.args = args;
            self.allocator = allocator;

            const shared = try JobFutureSharedMutex(RetT).init(allocator);

            self.future = WithinJobFuture(RetT).init(shared);

            return .{ .job = Job{ .ptr = @ptrCast(self), .func = Self.call }, .future = Future(RetT).init(shared) };
        }

        fn call(self: *anyopaque) void {
            const selfCast: *Self = @ptrCast(@alignCast(self));
            selfCast.future.set(@call(.auto, selfCast.function, selfCast.args));
            const allocator = selfCast.allocator;
            allocator.destroy(selfCast);
        }
    };
}

const JobRingQueue = struct {
    const Self = @This();

    len: usize = 0,
    readIndex: usize = 0,
    writeIndex: usize = 0,
    buffer: [JOB_QUEUE_CAPACITY]Job = undefined,

    fn push(self: *Self, job: Job) void {
        assert(self.len != JOB_QUEUE_CAPACITY);
        self.buffer[self.writeIndex] = job;
        self.writeIndex = @mod((self.writeIndex + 1), JOB_QUEUE_CAPACITY);
        self.len += 1;
    }
};

const ActiveJobs = struct {
    const Self = @This();

    len: usize = 0,
    buffer: [JOB_QUEUE_CAPACITY]Job = undefined,

    fn collectJobs(self: *Self, queue: *JobRingQueue) void {
        var count: usize = 0;
        var moveIndex = queue.readIndex;

        while (count < queue.len) {
            self.buffer[self.len] = queue.buffer[moveIndex];
            moveIndex = @mod((moveIndex + 1), JOB_QUEUE_CAPACITY);
            count += 1;
            self.len += 1;
        }

        queue.len = 0;
        queue.readIndex = 0;
        queue.writeIndex = 0;
    }

    fn invokeAllJobs(self: *Self) void {
        for (0..self.len) |i| {
            self.buffer[i].call();
        }
        self.len = 0;
    }
};

fn JobFutureSharedMutex(comptime T: type) type {
    return struct {
        const Self = @This();

        data: ?T,
        counter: Atomic(usize),
        mutex: Mutex,
        allocator: *Allocator,

        fn init(allocator: *Allocator) Allocator.Error!*Self {
            const mem = try allocator.create(Self);
            mem.data = null;
            mem.counter = Atomic(usize).init(1);
            mem.mutex = .{};
            mem.allocator = allocator;
            return mem;
        }

        fn decrementRefCount(self: *Self) void {
            const previous = self.counter.fetchSub(1, AtomicOrder.SeqCst); // TODO maybe different ordering?
            if (previous == 1) { // no more references left
                self.allocator.destroy(self);
            }
        }
    };
}

fn WithinJobFuture(comptime T: type) type {
    return struct {
        const Self = @This();

        shared: *anyopaque,

        fn init(shared: *JobFutureSharedMutex(T)) Self {
            return Self{ .shared = @ptrCast(shared) };
        }

        fn set(self: *Self, data: T) void {
            const sharedCast: *JobFutureSharedMutex(T) = @ptrCast(@alignCast(self.shared));
            sharedCast.mutex.lock();
            sharedCast.data = data;
            sharedCast.mutex.unlock();
            sharedCast.decrementRefCount();
            self.* = undefined;
        }
    };
}

fn JobFuturePair(comptime T: type) type {
    return struct {
        const Self = @This();

        job: Job,
        future: Future(RetT()),

        fn RetT() type {
            const typeInfo = @typeInfo(T);
            const fnInfo = typeInfo.Fn;
            const returnType = if (fnInfo.return_type) |retT| retT else void;
            return returnType;
        }

        fn ArgTuple() type {
            const typeInfo = @typeInfo(T);
            const fnInfo = typeInfo.Fn;

            if (fnInfo.params.len == 0) {
                return @TypeOf(.{});
            }

            comptime var paramTypes: [fnInfo.params.len]type = .{void} ** fnInfo.params.len;
            comptime {
                for (0..fnInfo.params.len) |i| {
                    if (fnInfo.params[i].type != null) {
                        paramTypes[i] = fnInfo.params[i].type.?;
                    }
                }
            }

            const argsTuple = std.meta.Tuple(&paramTypes);
            return argsTuple;
        }
    };
}

// Tests

test "JobThread init deinit" {
    var allocator = std.testing.allocator;
    var thread = try JobThread.init(&allocator);
    thread.deinit();
}

fn testSimpleJob() void {
    if (std.Thread.yield()) {} else |_| {
        @panic("failed to yield thread");
    }
}

test "JobThread run simple job" {
    var allocator = std.testing.allocator;
    var thread = try JobThread.init(&allocator);
    defer thread.deinit();

    const future = try thread.runJob(testSimpleJob, .{});
    future.wait();
}

fn testJobWithOneArgNoReturn(num: u64) void {
    std.time.sleep(num);
}

test "JobThread run job one arg no return" {
    var allocator = std.testing.allocator;
    var thread = try JobThread.init(&allocator);
    defer thread.deinit();

    const future = try thread.runJob(testJobWithOneArgNoReturn, .{1});
    future.wait();
}

fn testJobWithReturn() i32 {
    return 10;
}

test "JobThread run job no args has return" {
    var allocator = std.testing.allocator;
    var thread = try JobThread.init(&allocator);
    defer thread.deinit();

    const future = try thread.runJob(testJobWithReturn, .{});
    try expect(future.wait() == 10);
}

fn testJobMultipleArgsNoReturn(a: u64, b: u64) void {
    std.time.sleep(a + b);
}

test "JobThread run job multiple args no return" {
    var allocator = std.testing.allocator;
    var thread = try JobThread.init(&allocator);
    defer thread.deinit();

    const future = try thread.runJob(testJobMultipleArgsNoReturn, .{ 1, 2 });
    future.wait();
}

fn testJobMultipleArgsWithReturn(a: i32, b: i32) i32 {
    return a + b;
}

test "JobThread run job multiple args with return" {
    var allocator = std.testing.allocator;
    var thread = try JobThread.init(&allocator);
    defer thread.deinit();

    const future = try thread.runJob(testJobMultipleArgsWithReturn, .{ 1, 2 });
    try expect(future.wait() == 3);
}

test "Future deinit" {
    var allocator = std.testing.allocator;
    var thread = try JobThread.init(&allocator);
    defer thread.deinit();

    const future = try thread.runJob(testJobMultipleArgsWithReturn, .{ 1, 2 });
    future.deinit();
}

test "JobThread multiple jobs" {
    var allocator = std.testing.allocator;
    var thread = try JobThread.init(&allocator);
    defer thread.deinit();

    const f1 = try thread.runJob(testJobWithOneArgNoReturn, .{1});
    f1.deinit();

    const f2 = try thread.runJob(testJobWithOneArgNoReturn, .{5});
    f2.deinit();

    const f3 = try thread.runJob(testJobWithOneArgNoReturn, .{5});
    f3.deinit();

    const f4 = try thread.runJob(testJobMultipleArgsWithReturn, .{ 5, 5 });

    const f5 = try thread.runJob(testJobWithOneArgNoReturn, .{5});

    try expect(f4.wait() == 10);
    f5.wait();
}

test "JobSystem init deinit" {
    const allocator = std.testing.allocator;
    var jobSystem = try JobSystem.init(allocator, 4);
    defer jobSystem.deinit();
}

test "JobSystem many jobs ignore futures" {
    const allocator = std.testing.allocator;
    var jobSystem = try JobSystem.init(allocator, 4);
    defer jobSystem.deinit();

    for (0..32) |_| {
        const future = try jobSystem.runJob(testJobWithOneArgNoReturn, .{2});
        future.deinit();
    }
}

fn testDelayedReturn() i32 {
    std.time.sleep(10);
    return 9;
}

test "JobSystem many jobs with futures" {
    const allocator = std.testing.allocator;
    var jobSystem = try JobSystem.init(allocator, 4);
    defer jobSystem.deinit();

    var futures = std.ArrayList(Future(i32)).init(std.testing.allocator);
    defer futures.deinit();

    for (0..32) |_| {
        const future = try jobSystem.runJob(testDelayedReturn, .{});
        try futures.append(future);
    }

    for (futures.items) |future| {
        try expect(future.wait() == 9);
    }
}
