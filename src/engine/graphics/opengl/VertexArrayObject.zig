const std = @import("std");
const c = @import("../../clibs.zig");
//const Engine = @import("../../Engine.zig");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const VertexBufferObject = @import("VertexBufferObject.zig");
const IndexBufferObject = @import("IndexBufferObject.zig");

/// Will only ever be accessed by 1 thread, the Engine's OpenGL render thread.
var currentBoundVAO: u32 = 0;

const Self = @This();

id: u32,

pub fn init() Self {
    var id: u32 = undefined;
    c.glCreateVertexArrays(1, &id);
    return Self{ .id = id };
}

pub fn deinit(self: Self) void {
    if (self.isBound()) {
        currentBoundVAO = 0;
    }
    c.glDeleteVertexArrays(1, &self.id);
}

pub fn setFormatLayout(self: *Self, layout: Layout) void {
    var i: u32 = 0;
    var offset: u32 = 0;
    for (layout._elements.items) |element| {
        c.glEnableVertexArrayAttrib(self.id, i);
        c.glVertexArrayAttribBinding(self.id, i, 0);

        switch (element.elementType) {
            c.GL_FLOAT => {
                c.glVertexArrayAttribFormat(self.id, i, @intCast(element.count), c.GL_FLOAT, @intFromBool(element.normalized), offset);
            },
            c.GL_UNSIGNED_INT => {
                c.glVertexArrayAttribIFormat(self.id, i, @intCast(element.count), c.GL_UNSIGNED_INT, offset);
            },
            else => unreachable,
        }

        i += 1;
        offset += element.count * element.size;
    }
}

pub fn bindVertexBufferObject(self: Self, vbo: VertexBufferObject, bytesPerElements: u32) void {
    c.glVertexArrayVertexBuffer(self.id, 0, vbo.id, 0, @intCast(bytesPerElements));
}

pub fn bindIndexBufferObject(self: Self, ibo: IndexBufferObject) void {
    c.glVertexArrayElementBuffer(self.id, ibo.id);
}

pub fn bind(self: Self) void {
    if (self.isBound()) {
        return;
    }
    c.glBindVertexArray(self.id);
    currentBoundVAO = self.id;
}

pub fn unbind() void {
    c.glBindVertexArray(0);
    currentBoundVAO = 0;
}

fn isBound(self: *const Self) bool {
    return self.id == currentBoundVAO;
}

pub const Layout = struct {
    _elements: std.ArrayList(Element),
    /// Number of bytes between all attributes.
    stride: u32 = 0,

    pub fn init(allocator: Allocator) Layout {
        return Layout{ ._elements = std.ArrayList(Element).init(allocator) };
    }

    pub fn deinit(self: Layout) void {
        self._elements.deinit();
    }

    pub fn push(self: *Layout, comptime T: type, num: u32) Allocator.Error!void {
        const size = @sizeOf(T);
        if (T == u32) {
            try self._elements.append(Element{
                .elementType = c.GL_FLOAT,
                .count = num,
                .size = size,
                .normalized = false,
            });
        } else if (T == f32) {
            try self._elements.append(Element{
                .elementType = c.GL_UNSIGNED_INT,
                .count = num,
                .size = @sizeOf(f32),
                .normalized = false,
            });
        } else {
            @compileError("Unsupported VAO element type");
        }
        self.stride += num * size;
    }

    const Element = struct {
        elementType: u32,
        count: u32,
        size: u32,
        normalized: bool,
    };
};
