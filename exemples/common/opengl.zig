const c = @import("c.zig").glfw;
const std = @import("std");
const math = std.math;
const warn = std.debug.warn;
const ArrayList = std.ArrayList;
const gpa = std.heap.page_allocator;

const za = @import("zalgebra");
const Vec3 = za.Vec3;
const Vec4 = za.Vec4;
const Mat4 = za.Mat4;

const Shader = @import("shader.zig").Shader;
const Transform = @import("transform.zig").Transform;

const Texture = struct {
    id: u32,
    width: i32,
    height: i32,
    channels: i32 = 4,
};

pub const Mesh = struct {
    vertices: ArrayList(f32),
    indices: ?ArrayList(i32) = null,
    colors: ?ArrayList(f32) = null,
};

pub const GeometryObject = struct {
    gl: RenderDataObject,
    mesh: Mesh,

    transform: Transform,

    const Self = @This();

    pub fn new(vertices: []const f32, indices: ?[]const i32, colors: ?[]const f32, _: ?[]const u8) !Self {
        var obj: Self = .{
            .transform = Transform{},
            .gl = undefined,
            .mesh = .{
                .vertices = ArrayList(f32).init(gpa),
            },
        };

        try obj.mesh.vertices.appendSlice(vertices);

        if (indices) |data| {
            obj.mesh.indices = ArrayList(i32).init(gpa);
            try obj.mesh.indices.?.appendSlice(data);
        }

        if (colors) |data| {
            obj.mesh.colors = ArrayList(f32).init(gpa);
            try obj.mesh.colors.?.appendSlice(data);
        }

        obj.gl = RenderDataObject.from_mesh(&obj.mesh);
        return obj;
    }

    pub fn deinit(self: *Self) void {
        self.mesh.vertices.deinit();

        if (self.mesh.indices) |indices| {
            indices.deinit();
        }

        if (self.mesh.colors) |colors| {
            colors.deinit();
        }
    }
};

pub const RenderDataObject = struct {
    vao: u32,
    vbo: u32,
    ebo: ?u32,
    triangles: i32,

    pub fn from_mesh(mesh: *const Mesh) RenderDataObject {
        var render_data_object: RenderDataObject = undefined;
        render_data_object.triangles = @divExact(@intCast(i32, mesh.vertices.items.len), 3);

        c.glGenVertexArrays(1, &render_data_object.vao);
        c.glBindVertexArray(render_data_object.vao);

        var total = @intCast(isize, mesh.vertices.items.len) * @sizeOf(f32);

        if (mesh.colors) |colors| {
            total += @intCast(isize, colors.items.len) * @sizeOf(f32);
        }

        // Allocate memory for our vertex buffer object.
        // We use a 111222333 pattern, so we use BufferSubData api for this.
        c.glGenBuffers(1, &render_data_object.vbo);
        c.glBindBuffer(c.GL_ARRAY_BUFFER, render_data_object.vbo);
        c.glBufferData(c.GL_ARRAY_BUFFER, total, null, c.GL_STATIC_DRAW);

        var cursor: isize = 0;
        // Vertices batch
        {
            var size = @intCast(isize, mesh.vertices.items.len) * @sizeOf(f32);
            c.glBufferSubData(c.GL_ARRAY_BUFFER, 0, size, mesh.vertices.items.ptr);

            c.glVertexAttribPointer(0, 3, c.GL_FLOAT, c.GL_FALSE, 3 * @sizeOf(f32), null);
            c.glEnableVertexAttribArray(0);

            cursor += size;
        }

        // Colors batches
        if (mesh.colors) |colors| {
            var size = @intCast(isize, colors.items.len) * @sizeOf(f32);
            c.glBufferSubData(c.GL_ARRAY_BUFFER, cursor, size, colors.items.ptr);

            c.glVertexAttribPointer(2, 3, c.GL_FLOAT, c.GL_FALSE, 3 * @sizeOf(f32), @intToPtr(*const void, @intCast(usize, cursor)));
            c.glEnableVertexAttribArray(2);

            cursor += size;
        }

        if (mesh.indices) |indices| {
            var len = indices.items.len;
            render_data_object.triangles = @intCast(i32, len);
            render_data_object.ebo = 0;
            c.glGenBuffers(1, &render_data_object.ebo.?);
            c.glBindBuffer(c.GL_ELEMENT_ARRAY_BUFFER, render_data_object.ebo.?);
            c.glBufferData(c.GL_ELEMENT_ARRAY_BUFFER, @intCast(isize, len) * @sizeOf(i32), @ptrCast(*const void, indices.items), c.GL_STATIC_DRAW);
        }

        c.glBindBuffer(c.GL_ARRAY_BUFFER, 0);
        c.glBindVertexArray(0);

        return render_data_object;
    }
};

pub fn draw_geometry(obj: *const GeometryObject, shader: *const Shader, model: Mat4, color: ?Vec4) void {
    c.glBindVertexArray(obj.gl.vao);
    shader.setMat4("model", &model);

    if (color) |rgba| {
        shader.setRgba("color", &rgba);
    }

    if (obj.mesh.colors) |_| {
        shader.setBool("with_color", true);
    }

    if (obj.gl.ebo) |ebo| {
        c.glBindBuffer(c.GL_ELEMENT_ARRAY_BUFFER, ebo);
        c.glDrawElements(c.GL_TRIANGLES, obj.gl.triangles, c.GL_UNSIGNED_INT, null);
    } else {
        c.glDrawArrays(c.GL_TRIANGLES, 0, obj.gl.triangles);
    }

    // Cleanup uniforms.
    shader.setRgba("color", &Vec4.new(10, 100, 50, 1));
    shader.setMat4("model", &Mat4.identity());
    shader.setBool("with_color", false);
}
