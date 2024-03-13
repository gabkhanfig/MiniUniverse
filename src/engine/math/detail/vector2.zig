const std = @import("std");
const expect = std.testing.expect;

/// Given that this is a 2 dimensional vector, and simd instructions
/// are for 128 bits or more (16 bytes), only types with a size of
/// 8 bytes can be simd.
pub fn Vector2(comptime T: type) type {
    const isSimdType = @sizeOf(T) == 8;
    const requiredAlign = if (!isSimdType) @alignOf(T) else @alignOf(T) * 2;

    return extern struct {
        const Self = @This();

        x: T align(requiredAlign) = std.mem.zeroes(T),
        y: T = std.mem.zeroes(T),
    };
}

// Tests

test "Size and align f32" {
    try expect(@sizeOf(Vector2(f32)) == 8);
    try expect(@alignOf(Vector2(f32)) == 4);
}

test "Size and align f64" {
    try expect(@sizeOf(Vector2(f64)) == 16);
    try expect(@alignOf(Vector2(f64)) == 16);
}
