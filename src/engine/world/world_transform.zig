pub const ChunkPosition = struct {
    x: i32,
    y: i32,
    layer: i8,

    pub fn eql(self: *const @This(), other: @This()) bool {
        return self.x == other.x and self.y == other.y and self.layer == other.layer;
    }

    pub fn hash(self: @This()) usize {
        var h: usize = 0;

        h |= @intCast(self.x);
        h |= @shlExact(@as(usize, @intCast(self.y)), 32);

        const layer: usize = @intCast(self.layer);
        h ^= layer;
        return h;
    }
};
