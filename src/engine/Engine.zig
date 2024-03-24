const std = @import("std");
const assert = std.debug.assert;
const c = @import("clibs.zig");
const Mutex = std.Thread.Mutex;
const Allocator = std.mem.Allocator;
const job_system = @import("sync/job_system.zig");
const JobThread = job_system.JobThread;
const JobSystem = job_system.JobSystem;
const AtomicValue = std.atomic.Value;
const AtomicOrder = std.builtin.AtomicOrder;
const Window = @import("graphics/Window.zig");
const OpenGLInstance = @import("graphics/opengl/OpenGLInstance.zig");

const Self = @This();

var engineInstance: AtomicValue(?*Self) = AtomicValue(?*Self).init(null);

allocator: Allocator,
renderThread: *JobThread,
jobSystem: JobSystem,
_window: Window,
_openglInstance: OpenGLInstance,

/// Initializes the engine globally, if it hasn't been already.
/// Call `deinit()` to deinitialize the engine globally.
/// `timeoutInMillis` represents the amount of time it will wait for the current global
/// engine to be deinitialized if it exists. If `timeoutInMillis` it null, it will wait
/// infinitely.
///
/// # Errors
///
/// If the engine has already been globally initialized, the thread will loop for `timeoutInMillis` milliseconds
/// until `deinit()` is called. If the global instance is not deinitialized before that time, an error is returned.
/// This behaviour is used to make it straightforward to try different engine configurations concurrently.
pub fn init(allocator: Allocator, params: EngineInitializationParams, timeoutInMillis: ?u64) EngineInitError!void {
    const start = std.time.Instant.now() catch unreachable;
    var timeoutAsNanos: u64 = undefined;
    if (timeoutInMillis) |t| {
        timeoutAsNanos = t * std.time.ns_per_ms;
    } else {
        timeoutAsNanos = std.math.maxInt(u64);
    }

    while (true) {
        if (engineInstance.load(AtomicOrder.Acquire) != null) {
            const now = std.time.Instant.now() catch unreachable;
            if (start.since(now) > timeoutAsNanos) {
                return EngineInitError.EngineTimeout;
            }

            if (std.Thread.yield()) {
                continue;
            } else |_| {
                return EngineInitError.SystemCannotYield;
            }
        }

        const newEngine = try Self.create(allocator, params);

        // Are these the right atomic orders?
        while (engineInstance.cmpxchgWeak(null, newEngine, AtomicOrder.SeqCst, AtomicOrder.SeqCst) == null) {
            if (std.Thread.yield()) {
                continue;
            } else |_| {
                return EngineInitError.SystemCannotYield;
            }
        }

        break;
    }

    const e: ?*Self = engineInstance.load(AtomicOrder.Acquire);
    assert(e != null);
}

/// Deinitializes the global engine, freeing it's resources.
pub fn deinit() void {
    const engine: ?*Self = engineInstance.load(AtomicOrder.Acquire);
    if (engine == null) {
        @panic("Cannot deinitialize a non-initialized engine");
    }
    engine.?.cleanup();
    engineInstance.store(null, std.builtin.AtomicOrder.Release);
}

/// Gets the global engine instance.
/// The lifetime of the returned value must never exceed the lifetime of the engine itself.
pub fn get() *Self {
    const engine: ?*Self = engineInstance.load(std.builtin.AtomicOrder.Acquire);
    assert(engine != null);
    return engine;
}

/// Checks if the calling thread is the same thread as the OpenGL render thread.
/// This is useful because nearly all OpenGL functions require being executed on the same thread
/// that the OpenGL context was created on, which must be the render thread.
///
/// For development use, if the engine instance is null, simply returns true. This allows
/// experimenting with singlethreaded stuff.
pub fn isCurrentOnRenderThread() bool {
    const engine: ?*Self = engineInstance.load(std.builtin.AtomicOrder.Acquire);
    if (std.debug.runtime_safety) {
        if (engine == null) {
            return true;
        }
    } else {
        assert(engine != null);
    }
    return std.Thread.getCurrentId() == engine.?.renderThread.threadId;
}

fn create(allocator: Allocator, params: EngineInitializationParams) EngineInitError!*Self {
    const newEngine = try allocator.create(Self);
    newEngine.allocator = allocator;
    newEngine.renderThread = try JobThread.init(&newEngine.allocator);
    newEngine.jobSystem = try JobSystem.init(newEngine.allocator, params.jobThreadCount);
    newEngine._window = Window.init(newEngine.renderThread, .{ .x = 640, .y = 480 });
    newEngine._openglInstance = OpenGLInstance.init(newEngine.renderThread);
    return newEngine;
}

fn cleanup(self: *Self) void {
    const allocator = self.allocator;
    self._window.deinit();
    //self._openglInstance.deinit();
    self.renderThread.deinit();
    self.jobSystem.deinit();
    allocator.destroy(self);
}

pub const EngineInitializationParams = struct {
    /// Specifies how many threads are to be used by the job system.
    /// It is recommended for this value to be the `system thread count - 2`.
    /// This allows the total used threads by the engine to equal the amount of logical threads
    /// available. This is `jobThreadCount` + `1 main thread` + `1 OpenGL thread`.
    jobThreadCount: usize,

    pub fn default() EngineInitializationParams {
        var jobThreadCount: usize = 2; // leaves main thread + OpenGL render thread, meaning 4 used threads
        const logicalThreads = std.Thread.getCpuCount();
        if (logicalThreads) |value| {
            if (value < 4) {
                @panic("Mini Universe requires a system with 4 or more logical threads");
            }
            jobThreadCount = value - 2;
        } else |err| {
            switch (err) {
                .PermissionDenied => @panic("Failed to get system logical thread count: Permission Denied\n"),
                .SystemResources => @panic("Failed to get system logical thread count: System Resources\n"),
                .Unexpected => @panic("Failed to get system logical thread count: Unexpected Error"),
            }
        }

        return EngineInitializationParams{
            .jobThreadCount = jobThreadCount,
        };
    }
};

// https://ziglang.org/documentation/master/#Merging-Error-Sets
pub const EngineInitError = Allocator.Error || std.Thread.SpawnError || std.Thread.YieldError || error{EngineTimeout};

test "Engine init deinit" {
    try Self.init(std.testing.allocator, .{ .jobThreadCount = 2 }, 1);
    Self.deinit();
}
