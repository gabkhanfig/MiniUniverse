const std = @import("std");
const expect = std.testing.expect;

pub fn Vector4(comptime T: type) type {
    const isSimdType = @sizeOf(T) == 4 or @sizeOf(T) == 8;
    const requiredAlign = if (isSimdType) @alignOf(T) else @alignOf(T) * 4;

    return extern struct {
        const Self = @This();

        x: T align(requiredAlign) = std.mem.zeroes(T),
        y: T = std.mem.zeroes(T),
        z: T = std.mem.zeroes(T),
        w: T = std.mem.zeroes(T),
    };
}
