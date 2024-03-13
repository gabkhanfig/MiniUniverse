const std = @import("std");
const c = @import("engine/clibs.zig");
const Vbo = @import("engine/graphics/opengl/VertexBufferObject.zig");
const Ibo = @import("engine/graphics/opengl/IndexBufferObject.zig");
const Vao = @import("engine/graphics/opengl/VertexArrayObject.zig");
const RasterShader = @import("engine/graphics/opengl/shader.zig").RasterShader;

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

    const vertices: [6]f32 = .{
        -0.5, -0.5,
        0,    0.5,
        0.5,  -0.5,
    };

    // const indices: [3]u32 = .{
    //     0, 1, 2,
    // };

    var vbo = Vbo.init();
    vbo.bufferData(f32, &vertices);
    vbo.bind();

    c.glEnableVertexAttribArray(0);
    c.glVertexAttribPointer(0, 2, c.GL_FLOAT, c.GL_FALSE, 2 * @sizeOf(f32), @ptrFromInt(0));

    // var ibo = Ibo.init();
    // ibo.bufferData(&indices);
    // ibo.bind();

    // var vao = Vao.init();
    // var layout = Vao.Layout.init(std.heap.page_allocator);
    // defer layout.deinit();

    // layout.push(f32, 2) catch unreachable;
    // vao.setFormatLayout(layout);

    // vao.bindVertexBufferObject(vbo, 5 * @sizeOf(f32));
    // vao.bindIndexBufferObject(ibo);

    const vertSource = @embedFile("assets/shaders/basic.vert");
    const fragSource = @embedFile("assets/shaders/basic.frag");

    var raster = RasterShader.init(vertSource, fragSource) catch unreachable;
    defer raster.deinit();

    while (c.glfwWindowShouldClose(createWindow) != c.GLFW_TRUE) {
        c.glfwPollEvents();

        c.glClear(c.GL_COLOR_BUFFER_BIT);

        raster.bind();
        //vao.bind();
        //c.glDrawElements(c.GL_TRIANGLES, @intCast(ibo.indexCount), c.GL_UNSIGNED_INT, null);
        c.glDrawArrays(c.GL_TRIANGLES, 0, 6);

        c.glfwSwapBuffers(createWindow);
    }
}
