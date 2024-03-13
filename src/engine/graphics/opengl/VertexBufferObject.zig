const std = @import("std");
const c = @import("../../clibs.zig");
//const Engine = @import("../../Engine.zig");
const assert = std.debug.assert;

/// Will only ever be accessed by 1 thread, the Engine's OpenGL render thread.
var currentBoundVBO: u32 = 0;

const Self = @This();

id: u32,

pub fn init() Self {
    var id: u32 = undefined;
    c.glCreateBuffers(1, &id);
    return Self{ .id = id };
}

pub fn deinit(self: Self) void {
    if (isBound()) {
        currentBoundVBO = 0;
    }
    c.glDeleteBuffers(1, &self.id);
}

pub fn bufferData(self: *Self, comptime T: type, data: []const T) void {
    c.glNamedBufferData(self.id, @intCast(data.len * @sizeOf(T)), @ptrCast(data.ptr), c.GL_STATIC_DRAW);
}

pub fn bind(self: Self) void {
    if (self.isBound()) {
        return;
    }
    c.glBindBuffer(c.GL_ARRAY_BUFFER, self.id);
    currentBoundVBO = self.id;
}

pub fn unbind() void {
    c.glBindBuffer(c.GL_ARRAY_BUFFER, 0);
    currentBoundVBO = 0;
}

fn isBound(self: *const Self) bool {
    return self.id == currentBoundVBO;
}
