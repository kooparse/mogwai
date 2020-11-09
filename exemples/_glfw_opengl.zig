const std = @import("std");
const c = @import("common/c.zig");
const primitive = @import("common/primitive.zig");
const opengl = @import("common/opengl.zig");
usingnamespace @import("common/camera.zig");
usingnamespace @import("common/shader.zig");

usingnamespace @import("zalgebra");
usingnamespace @import("mogwai");

const panic = std.debug.panic;
const print = std.debug.print;

const WINDOW_WIDTH: i32 = 1200;
const WINDOW_HEIGHT: i32 = 800;
const WINDOW_DPI: i32 = 2;
const WINDOW_NAME = "Game";

pub fn main() !void {
    if (c.glfwInit() == c.GL_FALSE) {
        panic("Failed to intialize GLFW.\n", .{});
    }

    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MAJOR, 3);
    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MINOR, 2);
    c.glfwWindowHint(c.GLFW_OPENGL_FORWARD_COMPAT, c.GL_TRUE);
    c.glfwWindowHint(c.GLFW_OPENGL_PROFILE, c.GLFW_OPENGL_CORE_PROFILE);

    const window = c.glfwCreateWindow(WINDOW_WIDTH, WINDOW_HEIGHT, WINDOW_NAME, null, null) orelse {
        panic("Unable to create window.\n", .{});
    };

    c.glfwMakeContextCurrent(window);
    c.glEnable(c.GL_DEPTH_TEST);

    c.glfwSwapBuffers(window);
    c.glfwPollEvents();

    defer c.glfwDestroyWindow(window);
    defer c.glfwTerminate();

    const default_vert = @embedFile("assets/default.vert");
    const default_frag = @embedFile("assets/default.frag");

    const shader = try Shader.create("default_shader", default_vert, default_frag);

    // Our gizmo with some options.
    var gizmo = Mogwai.new(.{
        .screen_width = WINDOW_WIDTH,
        .screen_height = WINDOW_HEIGHT,
        .dpi = WINDOW_DPI,
        .snap_axis = 0.3,
    });

    var camera = Camera.init(vec3.new(0.2, 0.8, -3.));
    var view = look_at(camera.position, vec3.add(camera.position, camera.front), vec3.up());
    const proj = perspective(45., @intToFloat(f32, WINDOW_WIDTH) / @intToFloat(f32, WINDOW_HEIGHT), 0.1, 100.);

    var our_target_object = try opengl.GeometryObject.new(&primitive.CUBE_VERTICES, &primitive.CUBE_INDICES, &primitive.CUBE_UV_COORDS, &primitive.CUBE_COLORS, null);
    defer our_target_object.deinit();

    var x_axis = try opengl.GeometryObject.new(&gizmo.meshes.move_axis.x, &gizmo.meshes.move_axis.indices, null, null, null);
    var y_axis = try opengl.GeometryObject.new(&gizmo.meshes.move_axis.y, &gizmo.meshes.move_axis.indices, null, null, null);
    var z_axis = try opengl.GeometryObject.new(&gizmo.meshes.move_axis.z, &gizmo.meshes.move_axis.indices, null, null, null);
    var yz = try opengl.GeometryObject.new(&gizmo.meshes.move_panels.yz, &gizmo.meshes.move_panels.indices, null, null, null);
    var xz = try opengl.GeometryObject.new(&gizmo.meshes.move_panels.xz, &gizmo.meshes.move_panels.indices, null, null, null);
    var xy = try opengl.GeometryObject.new(&gizmo.meshes.move_panels.xy, &gizmo.meshes.move_panels.indices, null, null, null);
    var scale_x = try opengl.GeometryObject.new(&gizmo.meshes.scale_axis.x, &gizmo.meshes.scale_axis.indices, null, null, null);
    var scale_y = try opengl.GeometryObject.new(&gizmo.meshes.scale_axis.y, &gizmo.meshes.scale_axis.indices, null, null, null);
    var scale_z = try opengl.GeometryObject.new(&gizmo.meshes.scale_axis.z, &gizmo.meshes.scale_axis.indices, null, null, null);
    var rotate_x = try opengl.GeometryObject.new(&gizmo.meshes.rotate_axis.x, null, null, null, null);
    var rotate_y = try opengl.GeometryObject.new(&gizmo.meshes.rotate_axis.y, null, null, null, null);
    var rotate_z = try opengl.GeometryObject.new(&gizmo.meshes.rotate_axis.z, null, null, null, null);

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
        c.glfwPollEvents();
        c.glClear(c.GL_COLOR_BUFFER_BIT | c.GL_DEPTH_BUFFER_BIT);

        shouldClose = c.glfwWindowShouldClose(window) == c.GL_TRUE or
            c.glfwGetKey(window, c.GLFW_KEY_ESCAPE) == c.GLFW_PRESS;

        // Compute times between frames (delta time).
        {
            var current_time = c.glfwGetTime();
            delta_time = current_time - last_frame;
            last_frame = current_time;
        }

        c.glUseProgram(shader.program_id);
        shader.setMat4("projection", &proj);
        shader.setMat4("view", &view);

        const is_pressed = c.glfwGetMouseButton(window, c.GLFW_MOUSE_BUTTON_LEFT) == c.GLFW_PRESS;
        var pos_x: f64 = 0.;
        var pos_y: f64 = 0.;
        c.glfwGetCursorPos(window, &pos_x, &pos_y);

        camera.update(window, delta_time, c.glfwGetKey(window, c.GLFW_KEY_LEFT_SHIFT) == c.GLFW_PRESS);

        if (c.glfwGetKey(window, c.GLFW_KEY_LEFT_SHIFT) == c.GLFW_PRESS) {
            c.glfwSetInputMode(window, c.GLFW_CURSOR, c.GLFW_CURSOR_DISABLED);
            view = mat4.look_at(camera.position, vec3.add(camera.position, camera.front), camera.up);
        } else {
            c.glfwSetInputMode(window, c.GLFW_CURSOR, c.GLFW_CURSOR_NORMAL);
        }

        gizmo.set_cursor(pos_x, pos_y, is_pressed);
        gizmo.set_camera(view, proj);

        if (c.glfwGetKey(window, c.GLFW_KEY_M) == c.GLFW_PRESS) {
            gizmo_mode = Mode.Move;
        } else if (c.glfwGetKey(window, c.GLFW_KEY_R) == c.GLFW_PRESS) {
            gizmo_mode = Mode.Rotate;
        } else if (c.glfwGetKey(window, c.GLFW_KEY_T) == c.GLFW_PRESS) {
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
        opengl.draw_geometry(&our_target_object, &shader, target_model, null, false);

        // Render our magnifico gizmo!
        {
            c.glDisable(c.GL_DEPTH_TEST);
            c.glEnable(c.GL_BLEND);
            c.glBlendFunc(c.GL_SRC_ALPHA, c.GL_ONE_MINUS_SRC_ALPHA);

            const alpha = 0.5;
            const model = mat4.from_translate(gizmo.position);

            switch (gizmo_mode) {
                Mode.Move => {
                    // Render all panels.
                    opengl.draw_geometry(&yz, &shader, model, vec4.new(0, 100, 255, if (gizmo.is_hover(GizmoItem.PanelYZ)) 1 else alpha), true);
                    opengl.draw_geometry(&xz, &shader, model, vec4.new(100, 255, 0, if (gizmo.is_hover(GizmoItem.PanelXZ)) 1 else alpha), true);
                    opengl.draw_geometry(&xy, &shader, model, vec4.new(255, 0, 255, if (gizmo.is_hover(GizmoItem.PanelXY)) 1 else alpha), true);

                    // Render all axis.
                    opengl.draw_geometry(&x_axis, &shader, model, vec4.new(255, 0, 0, if (gizmo.is_hover(GizmoItem.ArrowX)) 1 else alpha), true);
                    opengl.draw_geometry(&y_axis, &shader, model, vec4.new(0, 255, 0, if (gizmo.is_hover(GizmoItem.ArrowY)) 1 else alpha), true);
                    opengl.draw_geometry(&z_axis, &shader, model, vec4.new(0, 0, 255, if (gizmo.is_hover(GizmoItem.ArrowZ)) 1 else alpha), true);
                },
                Mode.Rotate => {
                    c.glEnable(c.GL_DEPTH_TEST);
                    opengl.draw_geometry(&rotate_x, &shader, model, vec4.new(255, 0, 0, if (gizmo.is_hover(GizmoItem.RotateZ)) 1 else alpha), true);
                    opengl.draw_geometry(&rotate_y, &shader, model, vec4.new(0, 255, 0, if (gizmo.is_hover(GizmoItem.RotateX)) 1 else alpha), true);
                    opengl.draw_geometry(&rotate_z, &shader, model, vec4.new(0, 0, 255, if (gizmo.is_hover(GizmoItem.RotateY)) 1 else alpha), true);
                    c.glDisable(c.GL_DEPTH_TEST);
                },
                Mode.Scale => {
                    opengl.draw_geometry(&scale_x, &shader, model, vec4.new(255, 0, 0, if (gizmo.is_hover(GizmoItem.ScalerX)) 1 else alpha), true);
                    opengl.draw_geometry(&scale_y, &shader, model, vec4.new(0, 255, 0, if (gizmo.is_hover(GizmoItem.ScalerY)) 1 else alpha), true);
                    opengl.draw_geometry(&scale_z, &shader, model, vec4.new(0, 0, 255, if (gizmo.is_hover(GizmoItem.ScalerZ)) 1 else alpha), true);
                },
                else => {}
            }

            c.glDisable(c.GL_BLEND);
            c.glEnable(c.GL_DEPTH_TEST);
        }

        c.glfwSwapBuffers(window);
    }
}
