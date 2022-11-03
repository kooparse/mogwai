const std = @import("std");
const primitive = @import("common/primitive.zig");
const c = @import("./common/c.zig").glfw;

const opengl = @import("common/opengl.zig");
const Camera = @import("common/camera.zig").Camera;
const Shader = @import("common/shader.zig").Shader;

const glfw = @import("glfw");
const za = @import("zalgebra");
const Mogwai = @import("mogwai").Mogwai;
const Mode = @import("mogwai").Mode;
const GizmoItem = @import("mogwai").GizmoItem;

const Vec3 = za.Vec3;
const Vec4 = za.Vec4;
const Mat4 = za.Mat4;

const panic = std.debug.panic;
const print = std.debug.print;

const WINDOW_WIDTH: i32 = 1200;
const WINDOW_HEIGHT: i32 = 800;
const WINDOW_DPI: i32 = 2;
const WINDOW_NAME = "Game";

pub fn main() !void {
    glfw.init(.{}) catch {
        panic("Failed to intialize GLFW.\n", .{});
    };

    const window = glfw.Window.create(WINDOW_WIDTH, WINDOW_HEIGHT, WINDOW_NAME, null, null, .{
        .context_version_major = 3,
        .context_version_minor = 2,
        .opengl_forward_compat = true,
        .opengl_profile = .opengl_core_profile,
    }) catch {
        panic("Unable to create window.\n", .{});
    };

    try glfw.makeContextCurrent(window);

    c.glEnable(c.GL_DEPTH_TEST);

    defer window.destroy();
    defer glfw.terminate();

    const default_vert = @embedFile("assets/default.vert");
    const default_frag = @embedFile("assets/default.frag");

    const shader = try Shader.create("default_shader", default_vert, default_frag);

    // Our gizmo with some options.
    var gizmo = Mogwai.new(.{
        .screen_width = WINDOW_WIDTH,
        .screen_height = WINDOW_HEIGHT,
        .dpi = WINDOW_DPI,
    });

    var camera = Camera.init(Vec3.new(0.2, 0.8, -3));
    var view = za.lookAt(camera.position, Vec3.add(camera.position, camera.front), Vec3.up());
    const proj = za.perspective(45, @intToFloat(f32, WINDOW_WIDTH) / @intToFloat(f32, WINDOW_HEIGHT), 0.1, 100);

    var our_target_object = try opengl.GeometryObject.new(&primitive.CUBE_VERTICES, &primitive.CUBE_INDICES, &primitive.CUBE_COLORS, null);
    defer our_target_object.deinit();

    var x_axis = try opengl.GeometryObject.new(&gizmo.meshes.move_axis.x, &gizmo.meshes.move_axis.indices, null, null);
    var y_axis = try opengl.GeometryObject.new(&gizmo.meshes.move_axis.y, &gizmo.meshes.move_axis.indices, null, null);
    var z_axis = try opengl.GeometryObject.new(&gizmo.meshes.move_axis.z, &gizmo.meshes.move_axis.indices, null, null);
    var yz = try opengl.GeometryObject.new(&gizmo.meshes.move_panels.yz, &gizmo.meshes.move_panels.indices, null, null);
    var xz = try opengl.GeometryObject.new(&gizmo.meshes.move_panels.xz, &gizmo.meshes.move_panels.indices, null, null);
    var xy = try opengl.GeometryObject.new(&gizmo.meshes.move_panels.xy, &gizmo.meshes.move_panels.indices, null, null);
    var scale_x = try opengl.GeometryObject.new(&gizmo.meshes.scale_axis.x, &gizmo.meshes.scale_axis.indices, null, null);
    var scale_y = try opengl.GeometryObject.new(&gizmo.meshes.scale_axis.y, &gizmo.meshes.scale_axis.indices, null, null);
    var scale_z = try opengl.GeometryObject.new(&gizmo.meshes.scale_axis.z, &gizmo.meshes.scale_axis.indices, null, null);
    var rotate_x = try opengl.GeometryObject.new(&gizmo.meshes.rotate_axis.x, null, null, null);
    var rotate_y = try opengl.GeometryObject.new(&gizmo.meshes.rotate_axis.y, null, null, null);
    var rotate_z = try opengl.GeometryObject.new(&gizmo.meshes.rotate_axis.z, null, null, null);

    defer yz.deinit();
    defer xz.deinit();
    defer xy.deinit();
    defer x_axis.deinit();
    defer y_axis.deinit();
    defer z_axis.deinit();
    defer scale_x.deinit();
    defer scale_y.deinit();
    defer scale_z.deinit();
    defer rotate_x.deinit();
    defer rotate_y.deinit();
    defer rotate_z.deinit();

    var delta_time: f64 = 0.0;
    var last_frame: f64 = 0.0;

    var shouldClose = false;
    var gizmo_mode = Mode.Move;

    while (!shouldClose) {
        try glfw.pollEvents();
        c.glClear(c.GL_COLOR_BUFFER_BIT | c.GL_DEPTH_BUFFER_BIT);

        shouldClose = window.shouldClose() or window.getKey(.escape) == .press;

        // Compute times between frames (delta time).
        {
            var current_time = c.glfwGetTime();
            delta_time = current_time - last_frame;
            last_frame = current_time;
        }

        c.glUseProgram(shader.program_id);
        shader.setMat4("projection", &proj);
        shader.setMat4("view", &view);

        const is_pressed = window.getMouseButton(.left) == .press;
        const cursorPos = try window.getCursorPos();

        camera.update(window, delta_time, window.getKey(.left_shift) == .press);

        if (window.getKey(.left_shift) == .press) {
          try window.setInputModeCursor(.disabled);
            view = za.lookAt(camera.position, Vec3.add(camera.position, camera.front), camera.up);
        } else {
          try window.setInputModeCursor(.normal);
        }

        gizmo.setCursor(cursorPos.xpos, cursorPos.ypos, is_pressed);
        gizmo.setCamera(view, proj);

        if (window.getKey(.m) == .press) {
            gizmo_mode = Mode.Move;
        } else if (window.getKey(.r) == .press) {
            gizmo_mode = Mode.Rotate;
        } else if (window.getKey(.t) == .press) {
            gizmo_mode = Mode.Scale;
        }

        const target_model = our_target_object.transform.get_model();
        if (gizmo.manipulate(target_model, gizmo_mode)) |result| {
            switch (gizmo_mode) {
                Mode.Move => {
                    our_target_object.transform.position = result.position;
                },
                Mode.Rotate => {
                    our_target_object.transform.rotation = result.rotation;
                },
                Mode.Scale => {
                    our_target_object.transform.scale = result.scale;
                },
                else => {},
            }
        }

        // Render our target object.
        opengl.draw_geometry(&our_target_object, &shader, target_model, null);

        // Render our magnifico gizmo!
        {
            c.glDisable(c.GL_DEPTH_TEST);
            c.glEnable(c.GL_BLEND);
            c.glBlendFunc(c.GL_SRC_ALPHA, c.GL_ONE_MINUS_SRC_ALPHA);

            const alpha = 0.5;
            const model = Mat4.fromTranslate(gizmo.position);

            switch (gizmo_mode) {
                Mode.Move => {
                    // Render all panels.
                    opengl.draw_geometry(&yz, &shader, model, Vec4.new(0, 100, 255, if (gizmo.isHover(GizmoItem.PanelYZ)) 1 else alpha));
                    opengl.draw_geometry(&xz, &shader, model, Vec4.new(100, 255, 0, if (gizmo.isHover(GizmoItem.PanelXZ)) 1 else alpha));
                    opengl.draw_geometry(&xy, &shader, model, Vec4.new(255, 0, 255, if (gizmo.isHover(GizmoItem.PanelXY)) 1 else alpha));

                    // Render all axis.
                    opengl.draw_geometry(&x_axis, &shader, model, Vec4.new(255, 0, 0, if (gizmo.isHover(GizmoItem.ArrowX)) 1 else alpha));
                    opengl.draw_geometry(&y_axis, &shader, model, Vec4.new(0, 255, 0, if (gizmo.isHover(GizmoItem.ArrowY)) 1 else alpha));
                    opengl.draw_geometry(&z_axis, &shader, model, Vec4.new(0, 0, 255, if (gizmo.isHover(GizmoItem.ArrowZ)) 1 else alpha));
                },
                Mode.Rotate => {
                    c.glEnable(c.GL_DEPTH_TEST);
                    opengl.draw_geometry(&rotate_x, &shader, model, Vec4.new(255, 0, 0, if (gizmo.isHover(GizmoItem.RotateZ)) 1 else alpha));
                    opengl.draw_geometry(&rotate_y, &shader, model, Vec4.new(0, 255, 0, if (gizmo.isHover(GizmoItem.RotateX)) 1 else alpha));
                    opengl.draw_geometry(&rotate_z, &shader, model, Vec4.new(0, 0, 255, if (gizmo.isHover(GizmoItem.RotateY)) 1 else alpha));
                    c.glDisable(c.GL_DEPTH_TEST);
                },
                Mode.Scale => {
                    opengl.draw_geometry(&scale_x, &shader, model, Vec4.new(255, 0, 0, if (gizmo.isHover(GizmoItem.ScalerX)) 1 else alpha));
                    opengl.draw_geometry(&scale_y, &shader, model, Vec4.new(0, 255, 0, if (gizmo.isHover(GizmoItem.ScalerY)) 1 else alpha));
                    opengl.draw_geometry(&scale_z, &shader, model, Vec4.new(0, 0, 255, if (gizmo.isHover(GizmoItem.ScalerZ)) 1 else alpha));
                },
                else => {},
            }

            c.glDisable(c.GL_BLEND);
            c.glEnable(c.GL_DEPTH_TEST);
        }

        try window.swapBuffers();
    }
}
