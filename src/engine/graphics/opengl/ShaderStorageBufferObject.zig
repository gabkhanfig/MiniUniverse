const std = @import("std");
const c = @import("../../clibs.zig");
const isCurrentOnRenderThread = @import("../../Engine.zig").isCurrentOnRenderThread;
const assert = std.debug.assert;

var currentBoundSSBO: u32 = 0;

const Self = @This();

id: u32,

pub fn init() Self {
    assert(isCurrentOnRenderThread());
    var id: u32 = undefined;
    c.glCreateBuffers(1, &id);
    return Self{ .id = id };
}

pub fn deinit(self: Self) void {
    assert(isCurrentOnRenderThread());
    c.glDeleteBuffers(1, &self.id);
}

pub fn bufferData(self: *Self, comptime T: type, data: []const T) void {
    assert(isCurrentOnRenderThread());
    c.glNamedBufferData(self.id, @intCast(data.len * @sizeOf(T)), @ptrCast(data.ptr), c.GL_STATIC_DRAW);
}

pub fn bind(self: Self, index: u32) void {
    assert(isCurrentOnRenderThread());
    if (self.isBound()) {
        return;
    }
    c.glBindBuffer(c.GL_SHADER_STORAGE_BUFFER, self.id);
    c.glBindBufferBase(c.GL_SHADER_STORAGE_BUFFER, index, self.id); // TODO is this correct?
}

pub fn unbind() void {
    assert(isCurrentOnRenderThread());
    c.glBindBuffer(c.GL_SHADER_STORAGE_BUFFER, 0);
}

pub fn isBound(self: *const Self) bool {
    return self.id == currentBoundSSBO;
}
