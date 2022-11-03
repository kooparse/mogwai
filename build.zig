const std = @import("std");
const Builder = std.build.Builder;
const Pkg = std.build.Pkg;
const FileSource = std.build.FileSource;
const builtin = @import("builtin");

pub fn build(b: *Builder) !void {
    const mode = b.standardReleaseOptions();

    // Build step for the library
    {
        var tests = b.addTest("src/main.zig");
        tests.addPackagePath("zalgebra", "src/libs/zalgebra/src/main.zig");
        tests.setBuildMode(mode);

        const test_step = b.step("test", "Run tests");
        test_step.dependOn(&tests.step);
    }

    // Build step for exemples.
    {
        var exe = b.addExecutable("glfw_opengl", "exemples/_glfw_opengl.zig");
        exe.setBuildMode(mode);

        const zalgebra = Pkg{ .name = "zalgebra", .source = FileSource.relative("src/libs/zalgebra/src/main.zig") };

        exe.addPackage(zalgebra);
        exe.addPackage(.{
            .name = "mogwai",
            .source = FileSource.relative("src/main.zig"),
            .dependencies = &[_]Pkg{zalgebra},
        });

        switch (builtin.os.tag) {
            .macos => {
                exe.linkFramework("OpenGL");
            },
            else => {
                @panic("Don't know how to build on your system.");
            },
        }

        const glfw = @import("src/libs/mach-glfw/build.zig");

        exe.addPackage(glfw.pkg);
        try glfw.link(b, exe, .{});
        exe.install();

        const play = b.step("run", "Run Mogwai exemple");
        const run = exe.run();
        run.step.dependOn(b.getInstallStep());

        play.dependOn(&run.step);
    }
}
