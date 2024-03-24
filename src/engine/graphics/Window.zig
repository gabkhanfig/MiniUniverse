//! Engine window

const std = @import("std");
const c = @import("../clibs.zig");
const GLFWwindow = c.GLFWwindow;
const GLFW_TRUE = c.GLFW_TRUE;
const GLFW_FALSE = c.GLFW_FALSE;
const JobThread = @import("../sync/job_system.zig").JobThread;
const Vec2i = @import("../math/vector.zig").Vector2(i32);

const WINDOW_NAME = "Mini Universe";

const Self = @This();

glfwwindow: *GLFWwindow,
dimensions: Vec2i,

pub fn init(renderThread: ?*JobThread, dimensions: Vec2i) Self {
    if (c.glfwInit() == GLFW_FALSE) {
        @panic("failed to init glfw");
    }

    c.glfwWindowHint(c.GLFW_RESIZABLE, GLFW_FALSE);

    const createdWindow = c.glfwCreateWindow(dimensions.x, dimensions.y, WINDOW_NAME, null, null);
    if (createdWindow == null) {
        c.glfwTerminate();
        @panic("failed to create glfw window");
    }

    const window = createdWindow.?;

    if (renderThread == null) {
        c.glfwMakeContextCurrent(window);
    } else {
        const future = renderThread.?.runJob(c.glfwMakeContextCurrent, .{window}) catch unreachable;
        future.wait();
    }

    return Self{ .glfwwindow = window, .dimensions = dimensions };
}

pub fn deinit(self: Self) void {
    c.glfwDestroyWindow(self.glfwwindow);
    c.glfwTerminate();
}

pub fn shouldClose(self: Self) bool {
    const result = c.glfwWindowShouldClose(self.glfwwindow);
    return result == GLFW_TRUE;
}

pub fn pollEvents() void {
    c.glfwPollEvents();
}

// TODO implement window switching and resizing later
// pub const WindowDimensionsTag = enum {
//     windowed,
//     fullscreen,
// };

// pub const WindowDimensions = union(WindowDimensionsTag) {
//     windowed: Vec2i,
//     fullscreen: bool,
// };

// pub const WindowInitParams = struct {
//     dimensions: WindowDimensions,
// };
