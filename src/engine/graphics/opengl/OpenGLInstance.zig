const std = @import("std");
const c = @import("../../clibs.zig");
const assert = std.debug.assert;
const JobThread = @import("../../sync/job_system.zig").JobThread;
//const Engine = @import("../../Engine.zig");

const Self = @This();

pub fn init(renderThread: ?*JobThread) Self {
    if (renderThread == null) {
        const result = c.gladLoadGL();
        if (result == c.GL_FALSE) {
            @panic("Failed to load OpenGL");
        }
    } else {
        const future = renderThread.?.runJob(c.gladLoadGL, .{}) catch unreachable;
        const result: c_int = future.wait();
        if (result == c.GL_FALSE) {
            @panic("Failed to load OpenGL");
        }

        return Self{};
    }
}

/// # Asserts
///
/// Can only be called the current engine instance's render thread.
pub fn clear() void {
    //assert(Engine.isCurrentOnRenderThread());
    c.glClear(c.GL_COLOR_BUFFER_BIT);
}
