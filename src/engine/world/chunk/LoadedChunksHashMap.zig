const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const expect = std.testing.expect;
const Chunk = @import("Chunk.zig");
const ChunkPosition = @import("../world_transform.zig").ChunkPosition;

const Self = @This();

groups: []Group,
chunkCount: usize = 0,

pub fn init() Self {
    var slice: []Group = undefined;
    slice.len = 0;
    return Self{ .groups = slice };
}

pub fn deinit(self: Self, allocator: Allocator) void {
    if (self.chunkCount == 0) {
        return;
    }

    for (self.groups) |group| {
        group.deinit(allocator);
    }
    allocator.free(self.groups);
}

pub fn find(self: Self, key: ChunkPosition) ?Chunk {
    if (self.chunkCount == 0) {
        return null;
    }

    const hashCode = key.hash();
    const groupBitmask = HashGroupBitmask.init(hashCode);
    const groupIndex = @mod(groupBitmask.value, self.groups.len);

    const found = self.groups[groupIndex].find(key, hashCode);
    if (found == null) {
        return null;
    }

    return self.groups[groupIndex].pairs[found.?].value;
}

pub fn insert(self: *Self, key: ChunkPosition, value: Chunk, allocator: Allocator) Allocator.Error!void {
    try self.ensureTotalCapacity(self.chunkCount + 1, allocator);

    const hashCode = key.hash();
    const groupBitmask = HashGroupBitmask.init(hashCode);
    const groupIndex = @mod(groupBitmask.value, self.groups.len);

    try self.groups[groupIndex].insert(key, value, hashCode, allocator);
    self.chunkCount += 1;
}

pub fn erase(self: *Self, key: ChunkPosition, allocator: Allocator) void {
    if (self.chunkCount == 0) return;

    const hashCode = key.hash();
    const groupBitmask = HashGroupBitmask.init(hashCode);
    const groupIndex = @mod(groupBitmask.value, self.groups.len);

    const result = self.groups[groupIndex].erase(key, hashCode, allocator);
    self.chunkCount -= 1;
    if (result == false) {
        @panic("Cannot erase chunk entry that is not mapped");
    }
}

fn ensureTotalCapacity(self: *Self, minCapacity: usize, allocator: Allocator) Allocator.Error!void {
    if (!self.shouldReallocate(minCapacity)) {
        return;
    }

    const newGroupCount = calculateNewGroupCount(minCapacity);
    if (newGroupCount <= self.groups.len) {
        return;
    }

    const newGroups = try allocator.alloc(Group, newGroupCount);
    for (0..newGroups.len) |i| {
        newGroups[i] = try Group.init(allocator);
    }

    for (self.groups) |oldGroup| {
        const oldHashMasksAsBytePtr: [*]u8 = @ptrCast(oldGroup.hashMasks);
        for (0..oldGroup.capacity) |i| {
            if (oldHashMasksAsBytePtr[i] == 0) {
                continue;
            }

            const pair = oldGroup.pairs[i];
            const hashCode = pair.key.hash();
            const groupBitmask = HashGroupBitmask.init(hashCode);
            const groupIndex = @mod(groupBitmask.value, self.groups.len);

            const newGroup = &newGroups[groupIndex];

            try newGroup.ensureTotalCapacity(newGroup.pairCount + 1, allocator);

            const newHashMasksAsBytePtr: [*]u8 = @ptrCast(newGroup.hashMasks);

            newHashMasksAsBytePtr[newGroup.pairCount] = oldHashMasksAsBytePtr[i];
            newGroup.pairs[newGroup.pairCount] = pair;
            newGroup.pairCount += 1;
        }

        const currentAllocationSize = calculateChunksHashGroupAllocationSize(oldGroup.capacity);

        var allocSlice: []align(Group.ALIGNMENT) u8 = undefined;
        allocSlice.ptr = @ptrCast(oldGroup.hashMasks);
        allocSlice.len = currentAllocationSize;

        allocator.free(allocSlice);
    }

    if (self.groups.len > 0) {
        allocator.free(self.groups);
    }

    self.groups = newGroups;
}

fn shouldReallocate(self: *const Self, requiredCapacity: usize) bool {
    if (self.groups.len == 0) {
        return true;
    }

    const loadFactorScaledPairCount = @shrExact(self.chunkCount & ~@as(usize, 0b11), 2) * 3; // multiply by 0.75
    return requiredCapacity > loadFactorScaledPairCount;
}

fn calculateNewGroupCount(requiredCapacity: usize) usize {
    if (requiredCapacity < Group.GROUP_ALLOC_SIZE) {
        return 1;
    } else {
        const out = requiredCapacity / (Group.GROUP_ALLOC_SIZE / 16);
        return out;
    }
}

const Group = struct {
    const GROUP_ALLOC_SIZE = 32;
    const INITIAL_ALLOCATION_SIZE = calculateChunksHashGroupAllocationSize(GROUP_ALLOC_SIZE);
    const ALIGNMENT = 32;

    hashMasks: [*]@Vector(32, u8),
    pairs: [*]*Pair,
    pairCount: usize = 0,
    capacity: usize = GROUP_ALLOC_SIZE,

    // https://www.openmymind.net/SIMD-With-Zig/

    fn init(allocator: Allocator) Allocator.Error!Group {
        const memory = try allocator.alignedAlloc(u8, ALIGNMENT, INITIAL_ALLOCATION_SIZE);
        @memset(memory, 0);

        const hashMasks: [*]@Vector(32, u8) = @ptrCast(@alignCast(memory.ptr));
        const pairs: [*]*Pair = @ptrCast(memory.ptr + GROUP_ALLOC_SIZE);

        return Group{
            .hashMasks = hashMasks,
            .pairs = pairs,
        };
    }

    fn deinit(self: Group, allocator: Allocator) void {
        for (0..self.capacity) |i| {
            const asBytePtr: [*]u8 = @ptrCast(self.hashMasks);
            if (asBytePtr[i] == 0) {
                continue;
            }

            allocator.destroy(self.pairs[i]);
        }

        const currentAllocationSize = calculateChunksHashGroupAllocationSize(self.capacity);

        var allocSlice: []align(ALIGNMENT) u8 = undefined;
        allocSlice.ptr = @ptrCast(self.hashMasks);
        allocSlice.len = currentAllocationSize;

        allocator.free(allocSlice);
    }

    fn find(self: *const Group, key: ChunkPosition, hashCode: usize) ?usize {
        const mask = HashPairBitmask.init(hashCode);
        const maskVec: @Vector(32, u8) = @splat(mask.value);

        var i: usize = 0;
        var maskIter: usize = 0;
        while (i < self.capacity) {
            var matches: @Vector(32, bool) = self.hashMasks[maskIter] == maskVec;
            var index = std.simd.firstTrue(matches);
            while (index != null) {
                if (self.pairs[i + index.?].key.eql(key)) {
                    return i + index.?;
                }
                matches[index.?] = false;
                index = std.simd.firstTrue(matches);
            }

            i += 32;
            maskIter += 1;
        }

        // for (0..self.capacity) |i| {
        //     if (self.hashMasks[i] != mask.value) {
        //         continue;
        //     }

        //     if (self.pairs[i].key.equal(key)) {
        //         return i;
        //     }
        // }

        return null;
    }

    /// Asserts that the entry doesn't exist.
    fn insert(self: *Group, key: ChunkPosition, value: Chunk, hashCode: usize, allocator: Allocator) Allocator.Error!void {
        const mask = HashPairBitmask.init(hashCode);

        if (comptime std.debug.runtime_safety) {
            const existingIndex = self.find(key, hashCode);
            if (existingIndex != null) {
                @panic("Cannot add duplicate chunk entries");
            }
        }

        try self.ensureTotalCapacity(self.pairCount + 1, allocator);

        // TODO SIMD

        const zeroVec: @Vector(32, u8) = @splat(0);
        const selfHashMasksAsBytePtr: [*]u8 = @ptrCast(self.hashMasks);

        var i: usize = 0;
        var maskIter: usize = 0;
        while (i < self.capacity) {
            const matches: @Vector(32, bool) = self.hashMasks[maskIter] == zeroVec;
            const index = std.simd.firstTrue(matches);
            if (index == null) {
                i += 32;
                maskIter += 1;
                continue;
            } else {
                const newPair = try allocator.create(Pair);
                newPair.key = key;
                newPair.value = value;

                selfHashMasksAsBytePtr[i] = mask.value;
                self.pairs[i] = newPair;
                self.pairCount += 1;
                return;
            }
        }

        // const selfHashMasksAsBytePtr: [*]u8 = @ptrCast(self.hashMasks);
        // for (0..self.capacity) |i| {
        //     if (selfHashMasksAsBytePtr[i] != 0) {
        //         continue;
        //     }

        //     const newPair = try allocator.create(Pair);
        //     newPair.key = key;
        //     newPair.value = value;

        //     selfHashMasksAsBytePtr[i] = mask.value;
        //     self.pairs[i] = newPair;
        //     self.pairCount += 1;
        //     return;
        // }

        @panic("Unreachable. Insert a mapped FatTree chunk failed.");
    }

    fn erase(self: *Group, key: ChunkPosition, hashCode: usize, allocator: Allocator) bool {
        const found = self.find(key, hashCode);

        if (found == null) {
            return false;
        }

        const selfHashMasksAsBytePtr: [*]u8 = @ptrCast(self.hashMasks);
        selfHashMasksAsBytePtr[found.?] = 0;
        allocator.destroy(self.pairs[found.?]);
        self.pairCount -= 1;

        if (self.pairCount == 0) {
            const currentAllocationSize = calculateChunksHashGroupAllocationSize(self.capacity);

            var allocSlice: []align(ALIGNMENT) u8 = undefined;
            allocSlice.ptr = @ptrCast(self.hashMasks);
            allocSlice.len = currentAllocationSize;

            allocator.free(allocSlice);
            allocator.destroy(self);
        }

        return true;
    }

    fn ensureTotalCapacity(self: *Group, minCapacity: usize, allocator: Allocator) Allocator.Error!void {
        if (minCapacity <= self.capacity) {
            return;
        }

        var mallocCapacity: usize = minCapacity;
        const rem = @mod(mallocCapacity, 32);
        if (rem != 0) {
            mallocCapacity += (32 - rem);
        }
        const allocSize = calculateChunksHashGroupAllocationSize(mallocCapacity);
        const memory = try allocator.alignedAlloc(u8, ALIGNMENT, allocSize);
        @memset(memory, 0);

        const hashMasks: [*]@Vector(32, u8) = @ptrCast(@alignCast(memory.ptr));
        const pairs: [*]*Pair = @ptrCast(memory.ptr + GROUP_ALLOC_SIZE);

        const selfHashMasksAsBytePtr: [*]u8 = @ptrCast(self.hashMasks);

        var movedIter: usize = 0;
        for (0..mallocCapacity) |i| {
            if (selfHashMasksAsBytePtr[i] == 0) {
                continue;
            }

            memory.ptr[movedIter] = selfHashMasksAsBytePtr[i]; // use the hash masks as u8 header
            pairs[movedIter] = self.pairs[i];
            movedIter += 1;
        }

        {
            const currentAllocationSize = calculateChunksHashGroupAllocationSize(self.capacity);
            var oldSlice: []align(ALIGNMENT) u8 = undefined;
            oldSlice.ptr = @alignCast(selfHashMasksAsBytePtr);
            oldSlice.len = currentAllocationSize;
            allocator.free(oldSlice);
        }

        self.hashMasks = hashMasks;
        self.pairs = pairs;
        self.capacity = mallocCapacity;
    }

    const Pair = struct {
        key: ChunkPosition,
        value: Chunk,
    };
};

const HashGroupBitmask = struct {
    const BITMASK = 18446744073709551488; // ~0b1111111 as usize

    value: usize,

    fn init(hashCode: usize) HashGroupBitmask {
        return HashGroupBitmask{ .value = @shrExact(hashCode & BITMASK, 7) };
    }
};

const HashPairBitmask = struct {
    const BITMASK = 127; // 0b1111111
    const SET_FLAG = 0b10000000;

    value: u8,

    fn init(hashCode: usize) HashPairBitmask {
        return HashPairBitmask{ .value = @intCast((hashCode & BITMASK) | SET_FLAG) };
    }
};

fn calculateChunksHashGroupAllocationSize(requiredCapacity: usize) usize {
    assert(requiredCapacity % 32 == 0);

    // number of hash masks + size of pointer * required capacity;
    return requiredCapacity + (@sizeOf(*Self.Group.Pair) * requiredCapacity);
}

test "calculateChunksHashGroupAllocationSize 32" {
    try expect(calculateChunksHashGroupAllocationSize(32) == 288);
}

test "Group size and align" {
    try expect(@sizeOf(Group) == 32);
    try expect(@alignOf(Group) == 8);
}

test "Init deinit" {
    const allocator = std.testing.allocator;

    const map = Self.init();
    map.deinit(allocator);
}

test "Insert one" {
    const allocator = std.testing.allocator;

    const c = Chunk{ .inner = undefined };

    var map = Self.init();
    defer map.deinit(allocator);

    try map.insert(ChunkPosition{ .x = 0, .y = 0, .layer = 0 }, c, allocator);
}

test "Find one" {
    const allocator = std.testing.allocator;

    const c = Chunk{ .inner = undefined };

    var map = Self.init();
    defer map.deinit(allocator);

    const pos = ChunkPosition{ .x = 0, .y = 0, .layer = 0 };
    try map.insert(pos, c, allocator);

    const found = map.find(pos);
    try expect(found != null);

    try expect(map.find(.{ .x = 1, .y = 0, .layer = 0 }) == null);
}

test "Erase one" {
    const allocator = std.testing.allocator;

    const c = Chunk{ .inner = undefined };

    var map = Self.init();
    defer map.deinit(allocator);

    const pos = ChunkPosition{ .x = 0, .y = 0, .layer = 0 };
    try map.insert(pos, c, allocator);
    map.erase(pos, allocator);
}
