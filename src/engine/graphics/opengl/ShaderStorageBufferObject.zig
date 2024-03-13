const std = @import("std");
const c = @import("../../clibs.zig");
//const Engine = @import("../../Engine.zig");
const assert = std.debug.assert;

var currentBoundSSBO: u32 = 0;

const Self = @This();

id: u32,

pub fn init() Self {
    var id: u32 = undefined;
    c.glCreateBuffers(1, &id);
    return Self{ .id = id };
}

pub fn deinit(self: Self) void {
    c.glDeleteBuffers(1, &self.id);
}

pub fn bufferData(self: *Self, comptime T: type, data: []const T) void {
    c.glNamedBufferData(self.id, @intCast(data.len * @sizeOf(T)), @ptrCast(data.ptr), c.GL_STATIC_DRAW);
}

pub fn bind(self: Self, index: u32) void {
    if (self.isBound()) {
        return;
    }
    c.glBindBuffer(c.GL_SHADER_STORAGE_BUFFER, self.id);
    c.glBindBufferBase(c.GL_SHADER_STORAGE_BUFFER, index, self.id); // TODO is this correct?
}

pub fn unbind() void {
    c.glBindBuffer(c.GL_SHADER_STORAGE_BUFFER, 0);
}

pub fn isBound(self: *const Self) bool {
    return self.id == currentBoundSSBO;
}
