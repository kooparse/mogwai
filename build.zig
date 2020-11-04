const std = @import("std");
const Builder = std.build.Builder;
const builtin = @import("builtin");

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();

    // Build step for the library
    {
        var lib = b.addStaticLibrary("mogwai", "src/main.zig");
        // lib.addPackage(.{ .name = "zalgebra", .path = "libs/zalgebra/src/main.zig" });
        lib.setBuildMode(mode);

        var tests = b.addTest("src/main.zig");
        tests.setBuildMode(mode);

        const test_step = b.step("test", "Run tests");
        test_step.dependOn(&tests.step);

        b.default_step.dependOn(&lib.step);
        lib.install();
    }

    // Build step for exemples.
    {
        var exe = b.addExecutable("glfw_opengl", "exemples/_glfw_opengl.zig");
        exe.setBuildMode(mode);
        exe.addPackage(.{ .name = "zalgebra", .path = "src/libs/zalgebra/src/main.zig" });
        exe.addPackage(.{ .name = "mogwai", .path = "src/main.zig" });

        switch (builtin.os.tag) {
            .macos => {
                exe.addFrameworkDir("/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System/Library/Frameworks");
                exe.linkFramework("OpenGL");
            },
            else => {
                @panic("Don't know how to build on your system.");
            },
        }

        exe.linkSystemLibrary("glfw");
        exe.install();

        const play = b.step("run", "Run Mogwai exemple");
        const run = exe.run();
        run.step.dependOn(b.getInstallStep());

        play.dependOn(&run.step);

    }
}
