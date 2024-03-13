const std = @import("std");
const c = @import("../../clibs.zig");
const isCurrentOnRenderThread = @import("../../Engine.zig").isCurrentOnRenderThread;
const assert = std.debug.assert;

/// Will only ever be accessed by 1 thread, the Engine's OpenGL render thread.
var currentBoundIBO: u32 = 0;

const Self = @This();

id: u32,
indexCount: u32 = 0,

pub fn init() Self {
    assert(isCurrentOnRenderThread());
    var id: u32 = undefined;
    c.glCreateBuffers(1, &id);
    return Self{ .id = id };
}

pub fn deinit(self: Self) void {
    assert(isCurrentOnRenderThread());
    if (self.isBound()) {
        currentBoundIBO = 0;
    }
    c.glDeleteBuffers(1, &self.id);
}

pub fn bufferData(self: *Self, indices: []const u32) void {
    assert(isCurrentOnRenderThread());
    c.glNamedBufferData(self.id, @intCast(indices.len * @sizeOf(u32)), @ptrCast(indices.ptr), c.GL_STATIC_DRAW);
    self.indexCount = @intCast(indices.len);
}

pub fn bind(self: Self) void {
    assert(isCurrentOnRenderThread());
    if (self.isBound()) {
        return;
    }
    c.glBindBuffer(c.GL_ELEMENT_ARRAY_BUFFER, self.id);
    currentBoundIBO = self.id;
}

pub fn unbind() void {
    assert(isCurrentOnRenderThread());
    c.glBindBuffer(c.GL_ELEMENT_ARRAY_BUFFER, 0);
    currentBoundIBO = 0;
}

fn isBound(self: *const Self) bool {
    return self.id == currentBoundIBO;
}
