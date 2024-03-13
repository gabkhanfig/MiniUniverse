const std = @import("std");
const expect = std.testing.expect;
const isSignedInt = @import("math_util.zig").isSignedInt;

pub fn Vector3(comptime T: type) type {
    const IS_SIGNED_INT = isSignedInt(T);

    return extern struct {
        const Self = @This();

        x: T = std.mem.zeroes(T),
        y: T = std.mem.zeroes(T),
        z: T = std.mem.zeroes(T),

        pub fn add(self: Self, other: Self) Self {
            return .{ .x = self.x + other.x, .y = self.y + other.y, .z = self.z + other.z };
        }

        pub fn addAssign(self: *Self, other: Self) void {
            self.* = self.add(other);
        }

        pub fn addScalar(self: Self, scalar: T) Self {
            return .{ .x = self.x + scalar, .y = self.y + scalar, .z = self.z + scalar };
        }

        pub fn addScalarAssign(self: *Self, scalar: T) void {
            self.* = self.addScalar(scalar);
        }

        pub fn sub(self: Self, other: Self) Self {
            return .{ .x = self.x - other.x, .y = self.y - other.y, .z = self.z - other.z };
        }

        pub fn subAssign(self: *Self, other: Self) void {
            self.* = self.sub(other);
        }

        pub fn subScalar(self: Self, scalar: T) Self {
            return .{ .x = self.x - scalar, .y = self.y - scalar, .z = self.z - scalar };
        }

        pub fn subScalarAssign(self: *Self, scalar: T) void {
            self.* = self.subScalar(scalar);
        }

        pub fn mul(self: Self, other: Self) Self {
            return .{ .x = self.x * other.x, .y = self.y * other.y, .z = self.z * other.z };
        }

        pub fn mulAssign(self: *Self, other: Self) void {
            self.* = self.mul(other);
        }

        pub fn mulScalar(self: Self, scalar: T) Self {
            return .{ .x = self.x * scalar, .y = self.y * scalar, .z = self.z * scalar };
        }

        pub fn mulScalarAssign(self: *Self, scalar: T) void {
            self.* = self.mulScalar(scalar);
        }

        pub fn div(self: Self, other: Self) Self {
            if (comptime IS_SIGNED_INT) {
                return .{ .x = @divTrunc(self.x, other.x), .y = @divTrunc(self.y, other.y), .z = @divTrunc(self.z, other.z) };
            } else {
                return .{ .x = self.x / other.x, .y = self.y / other.y, .z = self.z / other.z };
            }
        }

        pub fn divAssign(self: *Self, other: Self) void {
            self.* = self.div(other);
        }

        pub fn divScalar(self: Self, scalar: T) Self {
            if (comptime IS_SIGNED_INT) {
                return .{ .x = @divTrunc(self.x, scalar), .y = @divTrunc(self.y, scalar), .z = @divTrunc(self.z, scalar) };
            } else {
                return .{ .x = self.x / scalar, .y = self.y / scalar, .z = self.z / scalar };
            }
        }

        pub fn divScalarAssign(self: *Self, scalar: T) void {
            self.* = self.divScalar(scalar);
        }

        pub fn eql(self: Self, other: Self) bool {
            return self.x == other.x and self.y == other.y and self.z == other.z;
        }
    };
}

// Tests

test "Default 0" {
    {
        const v = Vector3(f32){};
        try expect(v.x == 0);
        try expect(v.y == 0);
        try expect(v.z == 0);
    }
    {
        const v = Vector3(f64){};
        try expect(v.x == 0);
        try expect(v.y == 0);
        try expect(v.z == 0);
    }
    {
        const v = Vector3(i32){};
        try expect(v.x == 0);
        try expect(v.y == 0);
        try expect(v.z == 0);
    }
    {
        const v = Vector3(u32){};
        try expect(v.x == 0);
        try expect(v.y == 0);
        try expect(v.z == 0);
    }
}

test "Add" {
    {
        const v1 = Vector3(f32){ .x = 1, .y = 2, .z = 3 };
        const v2 = Vector3(f32){ .x = 4, .y = 5, .z = 6 };
        const v = v1.add(v2);
        try expect(v.x == 5);
        try expect(v.y == 7);
        try expect(v.z == 9);
    }
    {
        const v1 = Vector3(f64){ .x = 1, .y = 2, .z = 3 };
        const v2 = Vector3(f64){ .x = 4, .y = 5, .z = 6 };
        const v = v1.add(v2);
        try expect(v.x == 5);
        try expect(v.y == 7);
        try expect(v.z == 9);
    }
    {
        const v1 = Vector3(i32){ .x = 1, .y = 2, .z = 3 };
        const v2 = Vector3(i32){ .x = 4, .y = 5, .z = 6 };
        const v = v1.add(v2);
        try expect(v.x == 5);
        try expect(v.y == 7);
        try expect(v.z == 9);
    }
    {
        const v1 = Vector3(u32){ .x = 1, .y = 2, .z = 3 };
        const v2 = Vector3(u32){ .x = 4, .y = 5, .z = 6 };
        const v = v1.add(v2);
        try expect(v.x == 5);
        try expect(v.y == 7);
        try expect(v.z == 9);
    }
}

test "Add assign" {
    {
        var v = Vector3(f32){ .x = 1, .y = 2, .z = 3 };
        const v2 = Vector3(f32){ .x = 4, .y = 5, .z = 6 };
        v.addAssign(v2);
        try expect(v.x == 5);
        try expect(v.y == 7);
        try expect(v.z == 9);
    }
    {
        var v = Vector3(f64){ .x = 1, .y = 2, .z = 3 };
        const v2 = Vector3(f64){ .x = 4, .y = 5, .z = 6 };
        v.addAssign(v2);
        try expect(v.x == 5);
        try expect(v.y == 7);
        try expect(v.z == 9);
    }
    {
        var v = Vector3(i32){ .x = 1, .y = 2, .z = 3 };
        const v2 = Vector3(i32){ .x = 4, .y = 5, .z = 6 };
        v.addAssign(v2);
        try expect(v.x == 5);
        try expect(v.y == 7);
        try expect(v.z == 9);
    }
    {
        var v = Vector3(u32){ .x = 1, .y = 2, .z = 3 };
        const v2 = Vector3(u32){ .x = 4, .y = 5, .z = 6 };
        v.addAssign(v2);
        try expect(v.x == 5);
        try expect(v.y == 7);
        try expect(v.z == 9);
    }
}

test "Add scalar" {
    {
        const v1 = Vector3(f32){ .x = 1, .y = 2, .z = 3 };
        const v = v1.addScalar(4);
        try expect(v.x == 5);
        try expect(v.y == 6);
        try expect(v.z == 7);
    }
    {
        const v1 = Vector3(f64){ .x = 1, .y = 2, .z = 3 };
        const v = v1.addScalar(4);
        try expect(v.x == 5);
        try expect(v.y == 6);
        try expect(v.z == 7);
    }
    {
        const v1 = Vector3(i32){ .x = 1, .y = 2, .z = 3 };
        const v = v1.addScalar(4);
        try expect(v.x == 5);
        try expect(v.y == 6);
        try expect(v.z == 7);
    }
    {
        const v1 = Vector3(u32){ .x = 1, .y = 2, .z = 3 };
        const v = v1.addScalar(4);
        try expect(v.x == 5);
        try expect(v.y == 6);
        try expect(v.z == 7);
    }
}

test "Add scalar assign" {
    {
        var v = Vector3(f32){ .x = 1, .y = 2, .z = 3 };
        v.addScalarAssign(4);
        try expect(v.x == 5);
        try expect(v.y == 6);
        try expect(v.z == 7);
    }
    {
        var v = Vector3(f64){ .x = 1, .y = 2, .z = 3 };
        v.addScalarAssign(4);
        try expect(v.x == 5);
        try expect(v.y == 6);
        try expect(v.z == 7);
    }
    {
        var v = Vector3(i32){ .x = 1, .y = 2, .z = 3 };
        v.addScalarAssign(4);
        try expect(v.x == 5);
        try expect(v.y == 6);
        try expect(v.z == 7);
    }
    {
        var v = Vector3(u32){ .x = 1, .y = 2, .z = 3 };
        v.addScalarAssign(4);
        try expect(v.x == 5);
        try expect(v.y == 6);
        try expect(v.z == 7);
    }
}

test "Subtract" {
    {
        const v1 = Vector3(f32){ .x = 4, .y = 4, .z = 4 };
        const v2 = Vector3(f32){ .x = 1, .y = 2, .z = 3 };
        const v = v1.sub(v2);
        try expect(v.x == 3);
        try expect(v.y == 2);
        try expect(v.z == 1);
    }
    {
        const v1 = Vector3(f64){ .x = 4, .y = 4, .z = 4 };
        const v2 = Vector3(f64){ .x = 1, .y = 2, .z = 3 };
        const v = v1.sub(v2);
        try expect(v.x == 3);
        try expect(v.y == 2);
        try expect(v.z == 1);
    }
    {
        const v1 = Vector3(i32){ .x = 4, .y = 4, .z = 4 };
        const v2 = Vector3(i32){ .x = 1, .y = 2, .z = 3 };
        const v = v1.sub(v2);
        try expect(v.x == 3);
        try expect(v.y == 2);
        try expect(v.z == 1);
    }
    {
        const v1 = Vector3(u32){ .x = 4, .y = 4, .z = 4 };
        const v2 = Vector3(u32){ .x = 1, .y = 2, .z = 3 };
        const v = v1.sub(v2);
        try expect(v.x == 3);
        try expect(v.y == 2);
        try expect(v.z == 1);
    }
}

test "Subtract assign" {
    {
        var v = Vector3(f32){ .x = 4, .y = 4, .z = 4 };
        const v1 = Vector3(f32){ .x = 1, .y = 2, .z = 3 };
        v.subAssign(v1);
        try expect(v.x == 3);
        try expect(v.y == 2);
        try expect(v.z == 1);
    }
    {
        var v = Vector3(f64){ .x = 4, .y = 4, .z = 4 };
        const v1 = Vector3(f64){ .x = 1, .y = 2, .z = 3 };
        v.subAssign(v1);
        try expect(v.x == 3);
        try expect(v.y == 2);
        try expect(v.z == 1);
    }
    {
        var v = Vector3(i32){ .x = 4, .y = 4, .z = 4 };
        const v1 = Vector3(i32){ .x = 1, .y = 2, .z = 3 };
        v.subAssign(v1);
        try expect(v.x == 3);
        try expect(v.y == 2);
        try expect(v.z == 1);
    }
    {
        var v = Vector3(u32){ .x = 4, .y = 4, .z = 4 };
        const v1 = Vector3(u32){ .x = 1, .y = 2, .z = 3 };
        v.subAssign(v1);
        try expect(v.x == 3);
        try expect(v.y == 2);
        try expect(v.z == 1);
    }
}

test "Subtract scalar" {
    {
        const v1 = Vector3(f32){ .x = 4, .y = 5, .z = 6 };
        const v = v1.subScalar(1);
        try expect(v.x == 3);
        try expect(v.y == 4);
        try expect(v.z == 5);
    }
    {
        const v1 = Vector3(f64){ .x = 4, .y = 5, .z = 6 };
        const v = v1.subScalar(1);
        try expect(v.x == 3);
        try expect(v.y == 4);
        try expect(v.z == 5);
    }
    {
        const v1 = Vector3(i32){ .x = 4, .y = 5, .z = 6 };
        const v = v1.subScalar(1);
        try expect(v.x == 3);
        try expect(v.y == 4);
        try expect(v.z == 5);
    }
    {
        const v1 = Vector3(u32){ .x = 4, .y = 5, .z = 6 };
        const v = v1.subScalar(1);
        try expect(v.x == 3);
        try expect(v.y == 4);
        try expect(v.z == 5);
    }
}

test "Subtract scalar assign" {
    {
        var v = Vector3(f32){ .x = 4, .y = 5, .z = 6 };
        v.subScalarAssign(1);
        try expect(v.x == 3);
        try expect(v.y == 4);
        try expect(v.z == 5);
    }
    {
        var v = Vector3(f64){ .x = 4, .y = 5, .z = 6 };
        v.subScalarAssign(1);
        try expect(v.x == 3);
        try expect(v.y == 4);
        try expect(v.z == 5);
    }
    {
        var v = Vector3(i32){ .x = 4, .y = 5, .z = 6 };
        v.subScalarAssign(1);
        try expect(v.x == 3);
        try expect(v.y == 4);
        try expect(v.z == 5);
    }
    {
        var v = Vector3(u32){ .x = 4, .y = 5, .z = 6 };
        v.subScalarAssign(1);
        try expect(v.x == 3);
        try expect(v.y == 4);
        try expect(v.z == 5);
    }
}

test "Multiply" {
    {
        const v1 = Vector3(f32){ .x = 2, .y = 2, .z = 2 };
        const v2 = Vector3(f32){ .x = 2, .y = 3, .z = 4 };
        const v = v1.mul(v2);
        try expect(v.x == 4);
        try expect(v.y == 6);
        try expect(v.z == 8);
    }
    {
        const v1 = Vector3(f64){ .x = 2, .y = 2, .z = 2 };
        const v2 = Vector3(f64){ .x = 2, .y = 3, .z = 4 };
        const v = v1.mul(v2);
        try expect(v.x == 4);
        try expect(v.y == 6);
        try expect(v.z == 8);
    }
    {
        const v1 = Vector3(i32){ .x = 2, .y = 2, .z = 2 };
        const v2 = Vector3(i32){ .x = 2, .y = 3, .z = 4 };
        const v = v1.mul(v2);
        try expect(v.x == 4);
        try expect(v.y == 6);
        try expect(v.z == 8);
    }
    {
        const v1 = Vector3(u32){ .x = 2, .y = 2, .z = 2 };
        const v2 = Vector3(u32){ .x = 2, .y = 3, .z = 4 };
        const v = v1.mul(v2);
        try expect(v.x == 4);
        try expect(v.y == 6);
        try expect(v.z == 8);
    }
}

test "Multiply assign" {
    {
        var v = Vector3(f32){ .x = 2, .y = 2, .z = 2 };
        const v1 = Vector3(f32){ .x = 2, .y = 3, .z = 4 };
        v.mulAssign(v1);
        try expect(v.x == 4);
        try expect(v.y == 6);
        try expect(v.z == 8);
    }
    {
        var v = Vector3(f64){ .x = 2, .y = 2, .z = 2 };
        const v1 = Vector3(f64){ .x = 2, .y = 3, .z = 4 };
        v.mulAssign(v1);
        try expect(v.x == 4);
        try expect(v.y == 6);
        try expect(v.z == 8);
    }
    {
        var v = Vector3(i32){ .x = 2, .y = 2, .z = 2 };
        const v1 = Vector3(i32){ .x = 2, .y = 3, .z = 4 };
        v.mulAssign(v1);
        try expect(v.x == 4);
        try expect(v.y == 6);
        try expect(v.z == 8);
    }
    {
        var v = Vector3(u32){ .x = 2, .y = 2, .z = 2 };
        const v1 = Vector3(u32){ .x = 2, .y = 3, .z = 4 };
        v.mulAssign(v1);
        try expect(v.x == 4);
        try expect(v.y == 6);
        try expect(v.z == 8);
    }
}

test "Multiply scalar" {
    {
        const v1 = Vector3(f32){ .x = 2, .y = 3, .z = 4 };
        const v = v1.mulScalar(2);
        try expect(v.x == 4);
        try expect(v.y == 6);
        try expect(v.z == 8);
    }
    {
        const v1 = Vector3(f64){ .x = 2, .y = 3, .z = 4 };
        const v = v1.mulScalar(2);
        try expect(v.x == 4);
        try expect(v.y == 6);
        try expect(v.z == 8);
    }
    {
        const v1 = Vector3(i32){ .x = 2, .y = 3, .z = 4 };
        const v = v1.mulScalar(2);
        try expect(v.x == 4);
        try expect(v.y == 6);
        try expect(v.z == 8);
    }
    {
        const v1 = Vector3(u32){ .x = 2, .y = 3, .z = 4 };
        const v = v1.mulScalar(2);
        try expect(v.x == 4);
        try expect(v.y == 6);
        try expect(v.z == 8);
    }
}

test "Multiply scalar assign" {
    {
        var v = Vector3(f32){ .x = 2, .y = 3, .z = 4 };
        v.mulScalarAssign(2);
        try expect(v.x == 4);
        try expect(v.y == 6);
        try expect(v.z == 8);
    }
    {
        var v = Vector3(f64){ .x = 2, .y = 3, .z = 4 };
        v.mulScalarAssign(2);
        try expect(v.x == 4);
        try expect(v.y == 6);
        try expect(v.z == 8);
    }
    {
        var v = Vector3(i32){ .x = 2, .y = 3, .z = 4 };
        v.mulScalarAssign(2);
        try expect(v.x == 4);
        try expect(v.y == 6);
        try expect(v.z == 8);
    }
    {
        var v = Vector3(u32){ .x = 2, .y = 3, .z = 4 };
        v.mulScalarAssign(2);
        try expect(v.x == 4);
        try expect(v.y == 6);
        try expect(v.z == 8);
    }
}

test "Divide" {
    {
        const v1 = Vector3(f32){ .x = 4, .y = 6, .z = 8 };
        const v2 = Vector3(f32){ .x = 2, .y = 3, .z = 4 };
        const v = v1.div(v2);
        try expect(v.x == 2);
        try expect(v.y == 2);
        try expect(v.z == 2);
    }
    {
        const v1 = Vector3(f64){ .x = 4, .y = 6, .z = 8 };
        const v2 = Vector3(f64){ .x = 2, .y = 3, .z = 4 };
        const v = v1.div(v2);
        try expect(v.x == 2);
        try expect(v.y == 2);
        try expect(v.z == 2);
    }
    {
        const v1 = Vector3(i32){ .x = 4, .y = 6, .z = 8 };
        const v2 = Vector3(i32){ .x = 2, .y = 3, .z = 4 };
        const v = v1.div(v2);
        try expect(v.x == 2);
        try expect(v.y == 2);
        try expect(v.z == 2);
    }
    {
        const v1 = Vector3(u32){ .x = 4, .y = 6, .z = 8 };
        const v2 = Vector3(u32){ .x = 2, .y = 3, .z = 4 };
        const v = v1.div(v2);
        try expect(v.x == 2);
        try expect(v.y == 2);
        try expect(v.z == 2);
    }
}

test "Divide assign" {
    {
        var v = Vector3(f32){ .x = 4, .y = 6, .z = 8 };
        const v1 = Vector3(f32){ .x = 2, .y = 3, .z = 4 };
        v.divAssign(v1);
        try expect(v.x == 2);
        try expect(v.y == 2);
        try expect(v.z == 2);
    }
    {
        var v = Vector3(f64){ .x = 4, .y = 6, .z = 8 };
        const v1 = Vector3(f64){ .x = 2, .y = 3, .z = 4 };
        v.divAssign(v1);
        try expect(v.x == 2);
        try expect(v.y == 2);
        try expect(v.z == 2);
    }
    {
        var v = Vector3(i32){ .x = 4, .y = 6, .z = 8 };
        const v1 = Vector3(i32){ .x = 2, .y = 3, .z = 4 };
        v.divAssign(v1);
        try expect(v.x == 2);
        try expect(v.y == 2);
        try expect(v.z == 2);
    }
    {
        var v = Vector3(u32){ .x = 4, .y = 6, .z = 8 };
        const v1 = Vector3(u32){ .x = 2, .y = 3, .z = 4 };
        v.divAssign(v1);
        try expect(v.x == 2);
        try expect(v.y == 2);
        try expect(v.z == 2);
    }
}

test "Divide scalar" {
    {
        const v1 = Vector3(f32){ .x = 4, .y = 6, .z = 8 };
        const v = v1.divScalar(2);
        try expect(v.x == 2);
        try expect(v.y == 3);
        try expect(v.z == 4);
    }
    {
        const v1 = Vector3(f64){ .x = 4, .y = 6, .z = 8 };
        const v = v1.divScalar(2);
        try expect(v.x == 2);
        try expect(v.y == 3);
        try expect(v.z == 4);
    }
    {
        const v1 = Vector3(i32){ .x = 4, .y = 6, .z = 8 };
        const v = v1.divScalar(2);
        try expect(v.x == 2);
        try expect(v.y == 3);
        try expect(v.z == 4);
    }
    {
        const v1 = Vector3(u32){ .x = 4, .y = 6, .z = 8 };
        const v = v1.divScalar(2);
        try expect(v.x == 2);
        try expect(v.y == 3);
        try expect(v.z == 4);
    }
}

test "Divide scalar assign" {
    {
        var v = Vector3(f32){ .x = 4, .y = 6, .z = 8 };
        v.divScalarAssign(2);
        try expect(v.x == 2);
        try expect(v.y == 3);
        try expect(v.z == 4);
    }
    {
        var v = Vector3(f64){ .x = 4, .y = 6, .z = 8 };
        v.divScalarAssign(2);
        try expect(v.x == 2);
        try expect(v.y == 3);
        try expect(v.z == 4);
    }
    {
        var v = Vector3(i32){ .x = 4, .y = 6, .z = 8 };
        v.divScalarAssign(2);
        try expect(v.x == 2);
        try expect(v.y == 3);
        try expect(v.z == 4);
    }
    {
        var v = Vector3(u32){ .x = 4, .y = 6, .z = 8 };
        v.divScalarAssign(2);
        try expect(v.x == 2);
        try expect(v.y == 3);
        try expect(v.z == 4);
    }
}
