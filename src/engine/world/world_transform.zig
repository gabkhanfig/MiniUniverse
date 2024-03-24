const std = @import("std");
const assert = std.debug.assert;
const expect = std.testing.expect;

pub const CHUNK_LENGTH = 256;
pub const CHUNK_SIZE: comptime_int = CHUNK_LENGTH * CHUNK_LENGTH;

/// Position of a block within a chunk.
/// x has a factor of 1.
/// y has a factor of CHUNK_LENGTH
pub const BlockIndex = extern struct {
    const Self = @This();

    x: u8,
    y: u8,

    pub fn index(self: Self) u16 {
        const x: u16 = @intCast(self.x);
        const y: u16 = @intCast(self.y);
        return x | @shlExact(y, 8);
    }

    pub fn fromIndex(inIndex: u16) Self {
        const xMask = inIndex & 0x00FF;
        const yMask = inIndex & 0xFF00;

        return Self{
            .x = @intCast(xMask),
            .y = @intCast(@shrExact(yMask, 8)),
        };
    }
};

/// Position of a chunk in the world.
/// Used with the `SpatialChunkHashGrid`.
pub const ChunkPosition = struct {
    const Self = @This();

    x: i32,
    y: i32,
    layer: i8,

    pub fn eql(self: *const Self, other: Self) bool {
        return self.x == other.x and self.y == other.y and self.layer == other.layer;
    }

    pub fn hash(self: Self) usize {
        var h: usize = 0;

        h |= @intCast(self.x);
        h |= @shlExact(@as(usize, @intCast(self.y)), 32);

        const layer: usize = @intCast(self.layer);
        h ^= layer;
        return h;
    }
};

// Tests

test "BlockIndex to index" {
    {
        const b = BlockIndex{ .x = 0, .y = 0 };
        try expect(b.index() == 0);
    }
    {
        const b = BlockIndex{ .x = 1, .y = 0 };
        try expect(b.index() == 1);
    }
    {
        const b = BlockIndex{ .x = 2, .y = 0 };
        try expect(b.index() == 2);
    }
    {
        const b = BlockIndex{ .x = 0, .y = 1 };
        try expect(b.index() == 256);
    }
    {
        const b = BlockIndex{ .x = CHUNK_LENGTH - 1, .y = CHUNK_LENGTH - 1 };
        try expect(b.index() == (CHUNK_SIZE - 1));
    }
}

test "BlockIndex from index" {
    {
        const b = BlockIndex.fromIndex(0);
        try expect(b.x == 0);
        try expect(b.y == 0);
    }
    {
        const b = BlockIndex.fromIndex(1);
        try expect(b.x == 1);
        try expect(b.y == 0);
    }
    {
        const b = BlockIndex.fromIndex(2);
        try expect(b.x == 2);
        try expect(b.y == 0);
    }
    {
        const b = BlockIndex.fromIndex(256);
        try expect(b.x == 0);
        try expect(b.y == 1);
    }
    {
        const b = BlockIndex.fromIndex(CHUNK_SIZE - 1);
        try expect(b.x == (CHUNK_LENGTH - 1));
        try expect(b.y == (CHUNK_LENGTH - 1));
    }
}
