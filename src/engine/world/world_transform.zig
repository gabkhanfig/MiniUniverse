const CHUNK_LENGTH = 256;
const CHUNK_SIZE: comptime_int = CHUNK_LENGTH * CHUNK_LENGTH;

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
