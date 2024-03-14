//! Structure containing the indices of different block states within a chunk
//! Uses custom bit-widths to compress the used memory as aggressively as possible.
//! Uses more memory for more unique block states that a chunk owns.
//! Increase the amount of unique block states this can hold by calling
//! `reserve()`. It's important that the same allocator is used for all
//! functions that take an allocator.
//!
//! # Size
//!
//! 8 bytes for the `BlockStateIndices` itself, and then a varying size
//! allocated depending on the amount of unique `BlockState`'s in the chunk.
//!
//! - Up to 4 => 16384 bytes
//! - Up to 16 => 32768 bytes
//! - Up to 256 => 65536 bytes
//! - Up to CHUNK_SIZE (max) => 131072 bytes

const std = @import("std");
const Allocator = std.mem.Allocator;
const world_transform = @import("../world_transform.zig");
const BlockIndex = world_transform.BlockIndex;
const CHUNK_LENGTH = world_transform.CHUNK_LENGTH;
const CHUNK_SIZE = world_transform.CHUNK_SIZE;
const expect = std.testing.expect;
const assert = std.debug.assert;

const Self = @This();

const ENUM_MASK: usize = @shlExact(0b11111111, 56);
const PTR_MASK: usize = 0xFFFFFFFFFFFF;

taggedPtr: usize,

/// Allocate indices supporting up to 2 different block states within a chunk,
/// using a bit width of 1 bit per block state.
/// Free the allocation using `deinit()`, passing in the same `allocator` used with
/// this `init()` function.
///
/// # Increasing amount of block states that can be indexed
///
/// Use `reallocate()` with the required number of unique block states
/// to allow this `BlockStateIndices` instance to support it.
/// Pass in the same `allocator` used with this `init()` function.
pub fn init(allocator: Allocator) Allocator.Error!Self {
    const indexBitWidth = IndexBitWidth.b2;
    const indexBitWidthAsUsize: usize = @intFromEnum(indexBitWidth);
    const indexBitWidthAsTag = @shlExact(indexBitWidthAsUsize, 56);

    const indices = try allocator.create(BlockStateIndices2Bit);
    indices.* = BlockStateIndices2Bit{};

    return Self{ .taggedPtr = @intFromPtr(indices) | indexBitWidthAsTag };
}

/// Frees the allocated indices.
/// The same `allocator` as used with `init()` and `reallocate()` must be used.
pub fn deinit(self: Self, allocator: Allocator) void {
    const e = self.getTag();
    const ptr = self.getIndicesPtrMut();

    switch (e) {
        .b2 => {
            const as2Bit: *BlockStateIndices2Bit = @ptrCast(@alignCast(ptr));
            allocator.destroy(as2Bit);
        },
        .b4 => {
            const as4Bit: *BlockStateIndices4Bit = @ptrCast(@alignCast(ptr));
            allocator.destroy(as4Bit);
        },
        .b8 => {
            const as8Bit: *BlockStateIndices8Bit = @ptrCast(@alignCast(ptr));
            allocator.destroy(as8Bit);
        },
        .b16 => {
            const as16Bit: *BlockStateIndices16Bit = @ptrCast(@alignCast(ptr));
            allocator.destroy(as16Bit);
        },
    }
}

/// Get the index of the block state referenced by the block at `position`.
pub fn blockStateIndexAt(self: *const Self, position: BlockIndex) u16 {
    const e = self.getTag();
    const ptr = self.getIndicesPtr();

    switch (e) {
        .b2 => {
            const as2Bit: *const BlockStateIndices2Bit = @ptrCast(@alignCast(ptr));
            return as2Bit.indexAt(position);
        },
        .b4 => {
            const as4Bit: *const BlockStateIndices4Bit = @ptrCast(@alignCast(ptr));
            return as4Bit.indexAt(position);
        },
        .b8 => {
            const as8Bit: *const BlockStateIndices8Bit = @ptrCast(@alignCast(ptr));
            return as8Bit.indexAt(position);
        },
        .b16 => {
            const as16Bit: *const BlockStateIndices16Bit = @ptrCast(@alignCast(ptr));
            return as16Bit.indexAt(position);
        },
    }
}

/// Set the index of the block state referenced by the block at `position`.
/// Asserts that the current indices bit width can support `index`.
/// To change the bit width, see `reserve()`.
pub fn setBlockStateIndexAt(self: *Self, index: u16, position: BlockIndex) void {
    const e = self.getTag();
    const ptr = self.getIndicesPtrMut();

    switch (e) {
        .b2 => {
            assert(index < 4);
            const as2Bit: *BlockStateIndices2Bit = @ptrCast(@alignCast(ptr));
            as2Bit.setIndexAt(@intCast(index), position);
        },
        .b4 => {
            assert(index < 16);
            const as4Bit: *BlockStateIndices4Bit = @ptrCast(@alignCast(ptr));
            as4Bit.setIndexAt(@intCast(index), position);
        },
        .b8 => {
            assert(index < 256);
            const as8Bit: *BlockStateIndices8Bit = @ptrCast(@alignCast(ptr));
            as8Bit.setIndexAt(@intCast(index), position);
        },
        .b16 => {
            assert(index < CHUNK_SIZE);
            const as16Bit: *BlockStateIndices16Bit = @ptrCast(@alignCast(ptr));
            as16Bit.setIndexAt(@intCast(index), position);
        },
    }
}

/// Reserves this `BlockStateIndices` to use the smallest
/// amount of memory required to fit up to `uniqueBlockStates` as a valid index.
/// Will not shrink the memory usage. Will copy over the existing indices.
pub fn reserve(self: *Self, allocator: Allocator, uniqueBlockStates: u16) Allocator.Error!void {
    if (!self.shouldReallocate(uniqueBlockStates)) {
        return;
    }
    try self.reallocate(allocator, uniqueBlockStates);
}

fn getTag(self: *const Self) IndexBitWidth {
    const maskedEnum = self.taggedPtr & ENUM_MASK;
    const e: IndexBitWidth = @enumFromInt(@shrExact(maskedEnum, 56));
    return e;
}

fn getIndicesPtr(self: *const Self) *const anyopaque {
    const ptr: *anyopaque = @ptrFromInt(self.taggedPtr & PTR_MASK);
    return ptr;
}

fn getIndicesPtrMut(self: *const Self) *anyopaque {
    const ptr: *anyopaque = @ptrFromInt(self.taggedPtr & PTR_MASK);
    return ptr;
}

fn getRequiredBitWidth(uniqueBlockStates: u16) IndexBitWidth {
    if (uniqueBlockStates > 256) {
        return .b16;
    } else if (uniqueBlockStates > 16) {
        return .b8;
    } else if (uniqueBlockStates > 8) {
        return .b4;
    } else {
        return .b2;
    }
}

fn shouldReallocate(self: *const Self, uniqueBlockStates: u16) bool {
    switch (self.getTag()) {
        .b2 => {
            if (uniqueBlockStates > 4) return true;
        },
        .b4 => {
            if (uniqueBlockStates > 16) return true;
        },
        .b8 => {
            if (uniqueBlockStates > 256) return true;
        },
        .b16 => {
            return false;
        },
    }
    return false;
}

fn reallocate(self: *Self, allocator: Allocator, uniqueBlockStates: u16) Allocator.Error!void {
    const requiredBitWidth = getRequiredBitWidth(uniqueBlockStates);
    const oldTag = self.getTag();
    const oldPtr = self.getIndicesPtrMut();

    var newPtr: *anyopaque = undefined;
    switch (requiredBitWidth) {
        .b2 => {
            const p = try allocator.create(BlockStateIndices2Bit);
            p.* = BlockStateIndices2Bit{};
            newPtr = @ptrCast(p);
        },
        .b4 => {
            const p = try allocator.create(BlockStateIndices4Bit);
            p.* = BlockStateIndices4Bit{};
            newPtr = @ptrCast(p);
        },
        .b8 => {
            const p = try allocator.create(BlockStateIndices8Bit);
            p.* = BlockStateIndices8Bit{};
            newPtr = @ptrCast(p);
        },
        .b16 => {
            const p = try allocator.create(BlockStateIndices16Bit);
            p.* = BlockStateIndices16Bit{};
            newPtr = @ptrCast(p);
        },
    }

    { // Change the taggedPtr of self to then set the indices
        const indexBitWidthAsUsize: usize = @intFromEnum(requiredBitWidth);
        const indexBitWidthAsTag = @shlExact(indexBitWidthAsUsize, 56);
        self.taggedPtr = @intFromPtr(newPtr) | indexBitWidthAsTag;
    }

    switch (oldTag) {
        .b2 => {
            const as2Bit: *BlockStateIndices2Bit = @ptrCast(@alignCast(oldPtr));
            for (0..CHUNK_SIZE) |i| {
                const pos = BlockIndex{ .index = @intCast(i) };
                self.setBlockStateIndexAt(as2Bit.indexAt(pos), pos);
            }
            allocator.destroy(as2Bit);
        },
        .b4 => {
            const as4Bit: *BlockStateIndices4Bit = @ptrCast(@alignCast(oldPtr));
            for (0..CHUNK_SIZE) |i| {
                const pos = BlockIndex{ .index = @intCast(i) };
                self.setBlockStateIndexAt(as4Bit.indexAt(pos), pos);
            }
            allocator.destroy(as4Bit);
        },
        .b8 => {
            const as8Bit: *BlockStateIndices8Bit = @ptrCast(@alignCast(oldPtr));
            for (0..CHUNK_SIZE) |i| {
                const pos = BlockIndex{ .index = @intCast(i) };
                self.setBlockStateIndexAt(as8Bit.indexAt(pos), pos);
            }
            allocator.destroy(as8Bit);
        },
        .b16 => {
            const as16Bit: *BlockStateIndices16Bit = @ptrCast(@alignCast(oldPtr));
            for (0..CHUNK_SIZE) |i| {
                const pos = BlockIndex{ .index = @intCast(i) };
                self.setBlockStateIndexAt(as16Bit.indexAt(pos), pos);
            }
            allocator.destroy(as16Bit);
        },
    }
}

const IndexBitWidth = enum(u8) {
    b2,
    b4,
    b8,
    b16,
};

const BlockStateIndices2Bit = struct {
    const ARRAY_SIZE = CHUNK_SIZE / 32;
    const BIT_INDEX_MASK = 31;
    const BIT_INDEX_MULTIPLIER = 2;

    indices: [ARRAY_SIZE]usize = .{0} ** ARRAY_SIZE,

    fn indexAt(self: BlockStateIndices2Bit, position: BlockIndex) u16 {
        const arrayIndex = position.index() / ARRAY_SIZE;
        const positionIndexCast: usize = @intCast(position.index());
        const firstBitIndex: u6 = @intCast(positionIndexCast & BIT_INDEX_MASK);
        const bitMask = @shlExact(@as(usize, 0b11), BIT_INDEX_MULTIPLIER * firstBitIndex);

        const masked = self.indices[arrayIndex] & bitMask;
        return @intCast(@shrExact(masked, BIT_INDEX_MULTIPLIER * firstBitIndex));
    }

    fn setIndexAt(self: *BlockStateIndices2Bit, index: u2, position: BlockIndex) void {
        const arrayIndex = position.index() / ARRAY_SIZE;
        const positionIndexCast: usize = @intCast(position.index());
        const firstBitIndex: u6 = @intCast(positionIndexCast & BIT_INDEX_MASK);
        const indexAsUsize: usize = @intCast(index);
        const bitMask = @shlExact(indexAsUsize, BIT_INDEX_MULTIPLIER * firstBitIndex);

        self.indices[arrayIndex] = self.indices[arrayIndex] | bitMask;
    }
};

const BlockStateIndices4Bit = struct {
    const ARRAY_SIZE = CHUNK_SIZE / 16;
    const BIT_INDEX_MASK = 15;
    const BIT_INDEX_MULTIPLIER = 4;

    indices: [ARRAY_SIZE]usize = .{0} ** ARRAY_SIZE,

    fn indexAt(self: BlockStateIndices4Bit, position: BlockIndex) u16 {
        const arrayIndex = position.index() / ARRAY_SIZE;
        const positionIndexCast: usize = @intCast(position.index());
        const firstBitIndex: u6 = @intCast(positionIndexCast & BIT_INDEX_MASK);
        const bitMask = @shlExact(@as(usize, 0b1111), BIT_INDEX_MULTIPLIER * firstBitIndex);

        const masked = self.indices[arrayIndex] & bitMask;
        return @intCast(@shrExact(masked, BIT_INDEX_MULTIPLIER * firstBitIndex));
    }

    fn setIndexAt(self: *BlockStateIndices4Bit, index: u4, position: BlockIndex) void {
        const arrayIndex = position.index() / ARRAY_SIZE;
        const positionIndexCast: usize = @intCast(position.index());
        const firstBitIndex: u6 = @intCast(positionIndexCast & BIT_INDEX_MASK);
        const indexAsUsize: usize = @intCast(index);
        const bitMask = @shlExact(indexAsUsize, BIT_INDEX_MULTIPLIER * firstBitIndex);

        self.indices[arrayIndex] = self.indices[arrayIndex] | bitMask;
    }
};

const BlockStateIndices8Bit = struct {
    indices: [CHUNK_SIZE]u8 = .{0} ** CHUNK_SIZE,

    fn indexAt(self: BlockStateIndices8Bit, position: BlockIndex) u16 {
        return self.indices[position.index()];
    }

    fn setIndexAt(self: *BlockStateIndices8Bit, index: u8, position: BlockIndex) void {
        self.indices[position.index()] = index;
    }
};

const BlockStateIndices16Bit = struct {
    indices: [CHUNK_SIZE]u16 = .{0} ** CHUNK_SIZE,

    fn indexAt(self: BlockStateIndices16Bit, position: BlockIndex) u16 {
        return self.indices[position.index()];
    }

    fn setIndexAt(self: *BlockStateIndices16Bit, index: u16, position: BlockIndex) void {
        self.indices[position.index()] = index;
    }
};

// Tests

test "BlockStateIndices2Bit" {
    try expect(@sizeOf(BlockStateIndices2Bit) == 16384);

    var indices: BlockStateIndices2Bit = .{};

    const bpos1 = BlockIndex{ .x = 0, .y = 0 };
    const bpos2 = BlockIndex{ .x = 9, .y = 8 };
    const bpos3 = BlockIndex{ .x = CHUNK_LENGTH - 1, .y = CHUNK_LENGTH - 1 };

    try expect(indices.indexAt(bpos1) == 0);
    try expect(indices.indexAt(bpos2) == 0);
    try expect(indices.indexAt(bpos3) == 0);

    const newValue = 3;

    indices.setIndexAt(newValue, bpos1);
    indices.setIndexAt(newValue, bpos2);
    indices.setIndexAt(newValue, bpos3);

    try expect(indices.indexAt(bpos1) == newValue);
    try expect(indices.indexAt(bpos2) == newValue);
    try expect(indices.indexAt(bpos3) == newValue);
}

test "BlockStateIndices4Bit" {
    try expect(@sizeOf(BlockStateIndices4Bit) == 32768);

    var indices: BlockStateIndices4Bit = .{};

    const bpos1 = BlockIndex{ .x = 0, .y = 0 };
    const bpos2 = BlockIndex{ .x = 9, .y = 8 };
    const bpos3 = BlockIndex{ .x = CHUNK_LENGTH - 1, .y = CHUNK_LENGTH - 1 };

    try expect(indices.indexAt(bpos1) == 0);
    try expect(indices.indexAt(bpos2) == 0);
    try expect(indices.indexAt(bpos3) == 0);

    const newValue = 9;

    indices.setIndexAt(newValue, bpos1);
    indices.setIndexAt(newValue, bpos2);
    indices.setIndexAt(newValue, bpos3);

    try expect(indices.indexAt(bpos1) == newValue);
    try expect(indices.indexAt(bpos2) == newValue);
    try expect(indices.indexAt(bpos3) == newValue);
}

test "BlockStateIndices8Bit" {
    try expect(@sizeOf(BlockStateIndices8Bit) == 65536);

    var indices: BlockStateIndices8Bit = .{};

    const bpos1 = BlockIndex{ .x = 0, .y = 0 };
    const bpos2 = BlockIndex{ .x = 9, .y = 8 };
    const bpos3 = BlockIndex{ .x = CHUNK_LENGTH - 1, .y = CHUNK_LENGTH - 1 };

    try expect(indices.indexAt(bpos1) == 0);
    try expect(indices.indexAt(bpos2) == 0);
    try expect(indices.indexAt(bpos3) == 0);

    const newValue = 199;

    indices.setIndexAt(newValue, bpos1);
    indices.setIndexAt(newValue, bpos2);
    indices.setIndexAt(newValue, bpos3);

    try expect(indices.indexAt(bpos1) == newValue);
    try expect(indices.indexAt(bpos2) == newValue);
    try expect(indices.indexAt(bpos3) == newValue);
}

test "BlockStateIndices16Bit" {
    try expect(@sizeOf(BlockStateIndices16Bit) == 131072);

    var indices: BlockStateIndices16Bit = .{};

    const bpos1 = BlockIndex{ .x = 0, .y = 0 };
    const bpos2 = BlockIndex{ .x = 9, .y = 8 };
    const bpos3 = BlockIndex{ .x = CHUNK_LENGTH - 1, .y = CHUNK_LENGTH - 1 };

    try expect(indices.indexAt(bpos1) == 0);
    try expect(indices.indexAt(bpos2) == 0);
    try expect(indices.indexAt(bpos3) == 0);

    const newValue = 4321;

    indices.setIndexAt(newValue, bpos1);
    indices.setIndexAt(newValue, bpos2);
    indices.setIndexAt(newValue, bpos3);

    try expect(indices.indexAt(bpos1) == newValue);
    try expect(indices.indexAt(bpos2) == newValue);
    try expect(indices.indexAt(bpos3) == newValue);
}

// test "Init deinit" {
//     const allocator = std.testing.allocator;

//     const indices = try Self.init(allocator);
//     defer indices.deinit(allocator);
// }

// test "0 initalized bit width 1" {
//     const allocator = std.testing.allocator;

//     var indices = try Self.init(allocator);
//     defer indices.deinit(allocator);

//     for (0..CHUNK_SIZE) |i| {
//         const pos = BlockIndex{ .index = @intCast(i) };
//         try expect(indices.blockStateIndexAt(pos) == 0);
//     }
// }

// test "Block index at" {
//     const allocator = std.testing.allocator;

//     var indices = try Self.init(allocator);
//     defer indices.deinit(allocator);

//     indices.setBlockStateIndexAt(1, BlockIndex.init(12, 11, 13));
//     try expect(indices.blockStateIndexAt(BlockIndex.init(12, 11, 13)) == 1);
// }

// test "Reserve" {
//     const allocator = std.testing.allocator;

//     var indices = try Self.init(allocator);
//     defer indices.deinit(allocator);

//     indices.setBlockStateIndexAt(1, BlockIndex.init(3, 0, 0));

//     try indices.reserve(allocator, 3);
//     try expect(indices.blockStateIndexAt(BlockIndex.init(3, 0, 0)) == 1);

//     try indices.reserve(allocator, 6);
//     try expect(indices.blockStateIndexAt(BlockIndex.init(3, 0, 0)) == 1);

//     try indices.reserve(allocator, 17);
//     try expect(indices.blockStateIndexAt(BlockIndex.init(3, 0, 0)) == 1);

//     try indices.reserve(allocator, 1000);
//     try expect(indices.blockStateIndexAt(BlockIndex.init(3, 0, 0)) == 1);
// }

// test "0 initalized all bit widths" {
//     const allocator = std.testing.allocator;

//     var indices = try Self.init(allocator);
//     defer indices.deinit(allocator);

//     for (0..CHUNK_SIZE) |i| {
//         const pos = BlockIndex{ .index = @intCast(i) };
//         try expect(indices.blockStateIndexAt(pos) == 0);
//     }

//     try indices.reserve(allocator, 3);
//     for (0..CHUNK_SIZE) |i| {
//         const pos = BlockIndex{ .index = @intCast(i) };
//         try expect(indices.blockStateIndexAt(pos) == 0);
//     }

//     try indices.reserve(allocator, 6);
//     for (0..CHUNK_SIZE) |i| {
//         const pos = BlockIndex{ .index = @intCast(i) };
//         try expect(indices.blockStateIndexAt(pos) == 0);
//     }

//     try indices.reserve(allocator, 17);
//     for (0..CHUNK_SIZE) |i| {
//         const pos = BlockIndex{ .index = @intCast(i) };
//         try expect(indices.blockStateIndexAt(pos) == 0);
//     }

//     try indices.reserve(allocator, 1000);
//     for (0..CHUNK_SIZE) |i| {
//         const pos = BlockIndex{ .index = @intCast(i) };
//         try expect(indices.blockStateIndexAt(pos) == 0);
//     }
// }
