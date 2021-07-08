usingnamespace @import("zalgebra");
const c = @import("c.zig");
const c_allocator = @import("std").heap.c_allocator;
const panic = @import("std").debug.panic;

pub const Shader = struct {
    name: []const u8,
    program_id: u32,
    vertex_id: u32,
    fragment_id: u32,
    geometry_id: ?u32,

    pub fn create(name: []const u8, vert_content: []const u8, frag_content: []const u8) !Shader {
        var sp: Shader = undefined;
        sp.name = name;

        {
            sp.vertex_id = c.glCreateShader(c.GL_VERTEX_SHADER);
            const source_ptr: ?[*]const u8 = vert_content.ptr;
            const source_len = @intCast(c.GLint, vert_content.len);
            c.glShaderSource(sp.vertex_id, 1, &source_ptr, &source_len);
            c.glCompileShader(sp.vertex_id);

            var ok: c.GLint = undefined;
            c.glGetShaderiv(sp.vertex_id, c.GL_COMPILE_STATUS, &ok);

            if (ok == 0) {
                var error_size: c.GLint = undefined;
                c.glGetShaderiv(sp.vertex_id, c.GL_INFO_LOG_LENGTH, &error_size);

                const message = try c_allocator.alloc(u8, @intCast(usize, error_size));
                c.glGetShaderInfoLog(sp.vertex_id, error_size, &error_size, message.ptr);
                panic("Error compiling vertex shader:\n{s}\n", .{message});
            }
        }

        {
            sp.fragment_id = c.glCreateShader(c.GL_FRAGMENT_SHADER);
            const source_ptr: ?[*]const u8 = frag_content.ptr;
            const source_len = @intCast(c.GLint, frag_content.len);
            c.glShaderSource(sp.fragment_id, 1, &source_ptr, &source_len);
            c.glCompileShader(sp.fragment_id);

            var ok: c.GLint = undefined;
            c.glGetShaderiv(sp.fragment_id, c.GL_COMPILE_STATUS, &ok);

            if (ok == 0) {
                var error_size: c.GLint = undefined;
                c.glGetShaderiv(sp.fragment_id, c.GL_INFO_LOG_LENGTH, &error_size);

                const message = try c_allocator.alloc(u8, @intCast(usize, error_size));
                c.glGetShaderInfoLog(sp.fragment_id, error_size, &error_size, message.ptr);
                panic("Error compiling fragment shader:\n{s}\n", .{message});
            }
        }

        sp.program_id = c.glCreateProgram();
        c.glAttachShader(sp.program_id, sp.vertex_id);
        c.glAttachShader(sp.program_id, sp.fragment_id);
        c.glLinkProgram(sp.program_id);

        var ok: c.GLint = undefined;
        c.glGetProgramiv(sp.program_id, c.GL_LINK_STATUS, &ok);

        if (ok == 0) {
            var error_size: c.GLint = undefined;
            c.glGetProgramiv(sp.program_id, c.GL_INFO_LOG_LENGTH, &error_size);
            const message = try c_allocator.alloc(u8, @intCast(usize, error_size));
            c.glGetProgramInfoLog(sp.program_id, error_size, &error_size, message.ptr);
            panic("Error linking shader program: {s}\n", .{message});
        }

        // Cleanup shaders (from gl doc).
        c.glDeleteShader(sp.vertex_id);
        c.glDeleteShader(sp.fragment_id);

        return sp;
    }

    pub fn setMat4(sp: Shader, name: [*c]const u8, value: *const Mat4) void {
        const id = c.glGetUniformLocation(sp.program_id, name);
        c.glUniformMatrix4fv(id, 1, c.GL_FALSE, value.getData());
    }

    pub fn setBool(sp: Shader, name: [*c]const u8, value: bool) void {
        const id = c.glGetUniformLocation(sp.program_id, name);
        c.glUniform1i(id, @boolToInt(value));
    }

    pub fn setFloat(sp: Shader, name: [*c]const u8, value: f32) void {
        const id = c.glGetUniformLocation(sp.program_id, name);
        c.glUniform1f(id, value);
    }

    pub fn setRgb(sp: Shader, name: [*c]const u8, value: *const Vec3) void {
        const id = c.glGetUniformLocation(sp.program_id, name);
        c.glUniform3f(id, value.x / 255.0, value.y / 255.0, value.z / 255.0);
    }

    pub fn setRgba(sp: Shader, name: [*c]const u8, value: *const Vec4) void {
        const id = c.glGetUniformLocation(sp.program_id, name);
        c.glUniform4f(id, value.x / 255.0, value.y / 255.0, value.z / 255.0, value.w);
    }
};
