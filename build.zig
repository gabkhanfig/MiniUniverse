const std = @import("std");
const LazyPath = std.Build.LazyPath;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "MiniUniverse",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    linkAndIncludeCLibs(exe);

    b.installArtifact(exe);
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/tests.zig" },
        .target = target,
        .optimize = optimize,
    });
    linkAndIncludeCLibs(exe_unit_tests);

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}

fn linkAndIncludeCLibs(artifact: *std.Build.Step.Compile) void {
    const flags = [_][]const u8{};

    artifact.linkLibC();
    artifact.linkLibCpp();

    // OpenGL
    artifact.linkSystemLibrary("opengl32");
    artifact.addCSourceFile(.{ .file = LazyPath.relative("dependencies/opengl/glad.c"), .flags = &flags });
    artifact.addIncludePath(LazyPath.relative("dependencies/opengl"));

    artifact.linkSystemLibrary("gdi32");
    artifact.linkSystemLibrary("user32");
    artifact.linkSystemLibrary("shell32");

    // GLFW
    artifact.addLibraryPath(LazyPath.relative("dependencies/glfw-zig/zig-out/lib"));
    artifact.addIncludePath(LazyPath.relative("dependencies/glfw-zig/zig-out/include"));
    artifact.addObjectFile(LazyPath.relative("dependencies/glfw-zig/zig-out/lib/glfw.lib"));

    // stb_image
    artifact.addIncludePath(LazyPath.relative("dependencies/stb"));
    artifact.addCSourceFile(.{ .file = LazyPath.relative("dependencies/stb/stb_image.c"), .flags = &flags });
}
