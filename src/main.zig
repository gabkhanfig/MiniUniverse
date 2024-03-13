const std = @import("std");
const c = @import("engine/clibs.zig");

const SCREEN_WIDTH = 640;
const SCREEN_HEIGHT = 640;

pub fn main() !void {
    if (c.glfwInit() == c.GLFW_FALSE) {
        @panic("Failed to initialize glfw!");
    }

    const createWindow = c.glfwCreateWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Muehehehe", null, null);
    if (createWindow == null) {
        c.glfwTerminate();
        @panic("Failed to create glfw window");
    }

    c.glfwMakeContextCurrent(createWindow);

    _ = c.gladLoadGL();

    c.glClearColor(1.0, 0.5, 0.5, 1.0);
    c.glViewport(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT);
    //c.glFrontFace(c.GL_CCW);

    defer c.glfwTerminate();

    while (c.glfwWindowShouldClose(createWindow) != c.GLFW_TRUE) {
        c.glfwPollEvents();

        c.glClear(c.GL_COLOR_BUFFER_BIT);

        c.glfwSwapBuffers(createWindow);
    }
}
