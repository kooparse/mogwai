const std = @import("std");
const print = std.debug.print;
const math = std.math;
const testing = std.testing;
const root = @import("main.zig");
usingnamespace @import("vec4.zig");
usingnamespace @import("vec3.zig");

pub const mat4 = Mat4(f32);
pub const mat4_f64 = Mat4(f64);
pub const perspective = mat4.perspective;
pub const orthographic = mat4.orthographic;
pub const look_at = mat4.look_at;

/// A column-major 4x4 matrix.
/// Note: Column-major means accessing data like m.data[COLUMN][ROW].
pub fn Mat4(comptime T: type) type {
    if (@typeInfo(T) != .Float) {
        @compileError("Mat4 not implemented for " ++ @typeName(T));
    }

    return struct {
        data: [4][4]T,

        const Self = @This();

        pub fn identity() Self {
            return Self{
                .data = .{
                    .{ 1., 0., 0., 0. },
                    .{ 0., 1., 0., 0. },
                    .{ 0., 0., 1., 0. },
                    .{ 0., 0., 0., 1. },
                },
            };
        }

        /// Return a pointer to the inner data of the matrix.
        pub fn get_data(mat: *const Self) *const T {
            return @ptrCast(*const T, &mat.data);
        }

        pub fn is_eq(left: Self, right: Self) bool {
            var col: usize = 0;
            var row: usize = 0;

            while (col < 4) : (col += 1) {
                while (row < 4) : (row += 1) {
                    if (left.data[col][row] != right.data[col][row]) {
                        return false;
                    }
                }
            }

            return true;
        }

        pub fn mult_by_vec4(mat: Self, v: Vec4(T)) Vec4(T) {
            var result: Vec4(T) = undefined;

            result.x = (mat.data[0][0] * v.x) + (mat.data[1][0] * v.y) + (mat.data[2][0] * v.z) + (mat.data[3][0] * v.w);
            result.y = (mat.data[0][1] * v.x) + (mat.data[1][1] * v.y) + (mat.data[2][1] * v.z) + (mat.data[3][1] * v.w);
            result.z = (mat.data[0][2] * v.x) + (mat.data[1][2] * v.y) + (mat.data[2][2] * v.z) + (mat.data[3][2] * v.w);
            result.w = (mat.data[0][3] * v.x) + (mat.data[1][3] * v.y) + (mat.data[2][3] * v.z) + (mat.data[3][3] * v.w);

            return result;
        }

        /// Construct 4x4 translation matrix by multiplying identity matrix and
        /// given translation vector.
        pub fn from_translate(axis: Vec3(T)) Self {
            var mat = Self.identity();

            mat.data[3][0] = axis.x;
            mat.data[3][1] = axis.y;
            mat.data[3][2] = axis.z;

            return mat;
        }

        /// Make a translation between the given matrix and the given axis.
        pub fn translate(mat: Self, axis: Vec3(T)) Self {
            const trans_mat = Self.from_translate(axis);
            return Self.mult(trans_mat, mat);
        }

        /// Get translation Vec3 from current matrix.
        pub fn extract_translation(self: Self) Vec3(T) {
            return Vec3(T).new(self.data[3][0], self.data[3][1], self.data[3][2]);
        }

        /// Construct a 4x4 matrix from given axis and angle (in degrees).
        pub fn from_rotation(angle_in_degrees: T, axis: Vec3(T)) Self {
            var mat = Self.identity();

            const norm_axis = axis.norm();

            const sin_theta = math.sin(root.to_radians(angle_in_degrees));
            const cos_theta = math.cos(root.to_radians(angle_in_degrees));
            const cos_value = 1.0 - cos_theta;

            mat.data[0][0] = (norm_axis.x * norm_axis.x * cos_value) + cos_theta;
            mat.data[0][1] = (norm_axis.x * norm_axis.y * cos_value) + (norm_axis.z * sin_theta);
            mat.data[0][2] = (norm_axis.x * norm_axis.z * cos_value) - (norm_axis.y * sin_theta);

            mat.data[1][0] = (norm_axis.y * norm_axis.x * cos_value) - (norm_axis.z * sin_theta);
            mat.data[1][1] = (norm_axis.y * norm_axis.y * cos_value) + cos_theta;
            mat.data[1][2] = (norm_axis.y * norm_axis.z * cos_value) + (norm_axis.x * sin_theta);

            mat.data[2][0] = (norm_axis.z * norm_axis.x * cos_value) + (norm_axis.y * sin_theta);
            mat.data[2][1] = (norm_axis.z * norm_axis.y * cos_value) - (norm_axis.x * sin_theta);
            mat.data[2][2] = (norm_axis.z * norm_axis.z * cos_value) + cos_theta;

            return mat;
        }

        pub fn rotate(mat: Self, angle_in_degrees: T, axis: Vec3(T)) Self {
            const rotation_mat = Self.from_rotation(angle_in_degrees, axis);
            return Self.mult(mat, rotation_mat);
        }

        /// Construct a rotation matrix from euler angles (X * Y * Z).
        /// Order matters because matrix multiplication are NOT commutative.
        pub fn from_euler_angle(euler_angle: Vec3(T)) Self {
            const x = Self.from_rotation(euler_angle.x, vec3.new(1, 0, 0));
            const y = Self.from_rotation(euler_angle.y, vec3.new(0, 1, 0));
            const z = Self.from_rotation(euler_angle.z, vec3.new(0, 0, 1));

            return z.mult(y.mult(x));
        }

        /// Return the rotation as Euler angles in degrees.
        /// Taken from Mike Day at Insomniac Games (and `glm` as the same function).
        /// For more details: https://d3cw3dd2w32x2b.cloudfront.net/wp-content/uploads/2012/07/euler-angles1.pdf
        pub fn extract_rotation(self: Self) Vec3(T) {
            const theta_x = math.atan2(T, self.data[1][2], self.data[2][2]);
            const c2 = math.sqrt(math.pow(f32, self.data[0][0], 2) + math.pow(f32, self.data[0][1], 2));
            const theta_y = math.atan2(T, -self.data[0][2], math.sqrt(c2));
            const s1 = math.sin(theta_x);
            const c1 = math.cos(theta_x);
            const theta_z = math.atan2(T, s1 * self.data[2][0] - c1 * self.data[1][0], c1 * self.data[1][1] - s1 * self.data[2][1]);

            return vec3.new(root.to_degrees(theta_x), root.to_degrees(theta_y), root.to_degrees(theta_z));
        }

        pub fn from_scale(axis: Vec3(T)) Self {
            var mat = Self.identity();

            mat.data[0][0] = axis.x;
            mat.data[1][1] = axis.y;
            mat.data[2][2] = axis.z;

            return mat;
        }

        pub fn scale(mat: Self, axis: Vec3(T)) Self {
            const scale_mat = Self.from_scale(axis);
            return Self.mult(scale_mat, mat);
        }

        pub fn extract_scale(mat: Self) Vec3(T) {
            return Vec3(T).new(mat.data[0][0], mat.data[1][1], mat.data[2][2]);
        }

        /// Construct a perspective 4x4 matrix.
        /// Note: Field of view is given in degrees.
        /// Also for more details https://www.khronos.org/registry/OpenGL-Refpages/gl2.1/xhtml/gluPerspective.xml.
        pub fn perspective(fovy_in_degrees: T, aspect_ratio: T, z_near: T, z_far: T) Self {
            var mat: Self = undefined;

            const f = 1.0 / math.tan(fovy_in_degrees * 0.5);

            mat.data[0][0] = f / aspect_ratio;
            mat.data[1][1] = f;
            mat.data[2][2] = (z_near + z_far) / (z_near - z_far);
            mat.data[2][3] = -1;
            mat.data[3][2] = 2 * z_far * z_near / (z_near - z_far);

            return mat;
        }

        /// Construct an orthographic 4x4 matrix.
        pub fn orthographic(left: T, right: T, bottom: T, top: T, z_near: T, z_far: T) Self {
            var mat: Self = undefined;

            mat.data[0][0] = 2.0 / (right - left);
            mat.data[1][1] = 2.0 / (top - bottom);
            mat.data[2][2] = 2.0 / (z_near - z_far);
            mat.data[3][3] = 1.0;

            mat.data[3][0] = (left + right) / (left - right);
            mat.data[3][1] = (bottom + top) / (bottom - top);
            mat.data[3][2] = (z_far + z_near) / (z_near - z_far);

            return mat;
        }

        /// Right-handed look_at function.
        pub fn look_at(eye: Vec3(T), target: Vec3(T), up: Vec3(T)) Self {
            const f = Vec3(T).norm(Vec3(T).sub(target, eye));
            const s = Vec3(T).norm(Vec3(T).cross(f, up));
            const u = Vec3(T).cross(s, f);

            var mat: Self = undefined;
            mat.data[0][0] = s.x;
            mat.data[0][1] = u.x;
            mat.data[0][2] = -f.x;
            mat.data[0][3] = 0.0;

            mat.data[1][0] = s.y;
            mat.data[1][1] = u.y;
            mat.data[1][2] = -f.y;
            mat.data[1][3] = 0.0;

            mat.data[2][0] = s.z;
            mat.data[2][1] = u.z;
            mat.data[2][2] = -f.z;
            mat.data[2][3] = 0.0;

            mat.data[3][0] = -Vec3(T).dot(s, eye);
            mat.data[3][1] = -Vec3(T).dot(u, eye);
            mat.data[3][2] = Vec3(T).dot(f, eye);
            mat.data[3][3] = 1.0;

            return mat;
        }

        /// Matrices multiplication.
        /// Produce a new matrix from given two matrices.
        pub fn mult(left: Self, right: Self) Self {
            var mat = Self.identity();
            var columns: usize = 0;

            while (columns < 4) : (columns += 1) {
                var rows: usize = 0;
                while (rows < 4) : (rows += 1) {
                    var sum: T = 0.0;
                    var current_mat: usize = 0;

                    while (current_mat < 4) : (current_mat += 1) {
                        sum += left.data[current_mat][rows] * right.data[columns][current_mat];
                    }

                    mat.data[columns][rows] = sum;
                }
            }

            return mat;
        }

        /// Construct inverse 4x4 from given matrix.
        /// Note: This is not the most efficient way to do this.
        /// TODO: Make it more efficient.
        pub fn inv(mat: Self) Self {
            var inv_mat: Self = undefined;

            var s: [6]T = undefined;
            var c: [6]T = undefined;

            s[0] = mat.data[0][0] * mat.data[1][1] - mat.data[1][0] * mat.data[0][1];
            s[1] = mat.data[0][0] * mat.data[1][2] - mat.data[1][0] * mat.data[0][2];
            s[2] = mat.data[0][0] * mat.data[1][3] - mat.data[1][0] * mat.data[0][3];
            s[3] = mat.data[0][1] * mat.data[1][2] - mat.data[1][1] * mat.data[0][2];
            s[4] = mat.data[0][1] * mat.data[1][3] - mat.data[1][1] * mat.data[0][3];
            s[5] = mat.data[0][2] * mat.data[1][3] - mat.data[1][2] * mat.data[0][3];

            c[0] = mat.data[2][0] * mat.data[3][1] - mat.data[3][0] * mat.data[2][1];
            c[1] = mat.data[2][0] * mat.data[3][2] - mat.data[3][0] * mat.data[2][2];
            c[2] = mat.data[2][0] * mat.data[3][3] - mat.data[3][0] * mat.data[2][3];
            c[3] = mat.data[2][1] * mat.data[3][2] - mat.data[3][1] * mat.data[2][2];
            c[4] = mat.data[2][1] * mat.data[3][3] - mat.data[3][1] * mat.data[2][3];
            c[5] = mat.data[2][2] * mat.data[3][3] - mat.data[3][2] * mat.data[2][3];

            const determ = 1.0 / (s[0] * c[5] - s[1] * c[4] + s[2] * c[3] + s[3] * c[2] - s[4] * c[1] + s[5] * c[0]);

            inv_mat.data[0][0] =
                (mat.data[1][1] * c[5] - mat.data[1][2] * c[4] + mat.data[1][3] * c[3]) * determ;
            inv_mat.data[0][1] =
                (-mat.data[0][1] * c[5] + mat.data[0][2] * c[4] - mat.data[0][3] * c[3]) * determ;
            inv_mat.data[0][2] =
                (mat.data[3][1] * s[5] - mat.data[3][2] * s[4] + mat.data[3][3] * s[3]) * determ;
            inv_mat.data[0][3] =
                (-mat.data[2][1] * s[5] + mat.data[2][2] * s[4] - mat.data[2][3] * s[3]) * determ;

            inv_mat.data[1][0] =
                (-mat.data[1][0] * c[5] + mat.data[1][2] * c[2] - mat.data[1][3] * c[1]) * determ;
            inv_mat.data[1][1] =
                (mat.data[0][0] * c[5] - mat.data[0][2] * c[2] + mat.data[0][3] * c[1]) * determ;
            inv_mat.data[1][2] =
                (-mat.data[3][0] * s[5] + mat.data[3][2] * s[2] - mat.data[3][3] * s[1]) * determ;
            inv_mat.data[1][3] =
                (mat.data[2][0] * s[5] - mat.data[2][2] * s[2] + mat.data[2][3] * s[1]) * determ;

            inv_mat.data[2][0] =
                (mat.data[1][0] * c[4] - mat.data[1][1] * c[2] + mat.data[1][3] * c[0]) * determ;
            inv_mat.data[2][1] =
                (-mat.data[0][0] * c[4] + mat.data[0][1] * c[2] - mat.data[0][3] * c[0]) * determ;
            inv_mat.data[2][2] =
                (mat.data[3][0] * s[4] - mat.data[3][1] * s[2] + mat.data[3][3] * s[0]) * determ;
            inv_mat.data[2][3] =
                (-mat.data[2][0] * s[4] + mat.data[2][1] * s[2] - mat.data[2][3] * s[0]) * determ;

            inv_mat.data[3][0] =
                (-mat.data[1][0] * c[3] + mat.data[1][1] * c[1] - mat.data[1][2] * c[0]) * determ;
            inv_mat.data[3][1] =
                (mat.data[0][0] * c[3] - mat.data[0][1] * c[1] + mat.data[0][2] * c[0]) * determ;
            inv_mat.data[3][2] =
                (-mat.data[3][0] * s[3] + mat.data[3][1] * s[1] - mat.data[3][2] * s[0]) * determ;
            inv_mat.data[3][3] =
                (mat.data[2][0] * s[3] - mat.data[2][1] * s[1] + mat.data[2][2] * s[0]) * determ;

            return inv_mat;
        }

        /// Display the 4x4 matrix.
        pub fn fmt(self: Self) void {
            print("\n", .{});
            print("({d}, {d}, {d}, {d})\n", .{ self.data[0][0], self.data[1][0], self.data[2][0], self.data[3][0] });
            print("({d}, {d}, {d}, {d})\n", .{ self.data[0][1], self.data[1][1], self.data[2][1], self.data[3][1] });
            print("({d}, {d}, {d}, {d})\n", .{ self.data[0][2], self.data[1][2], self.data[2][2], self.data[3][2] });
            print("({d}, {d}, {d}, {d})\n", .{ self.data[0][3], self.data[1][3], self.data[2][3], self.data[3][3] });
            print("\n", .{});
        }
    };
}

test "zalgebra.Mat4.is_eq" {
    const mat_0 = mat4.identity();
    const mat_1 = mat4.identity();
    const mat_2 = mat4{
        .data = .{
            .{ 0., 0., 0., 0. },
            .{ 0., 0., 0., 0. },
            .{ 0., 0., 0., 0. },
            .{ 0., 0., 0., 0. },
        },
    };

    testing.expectEqual(mat4.is_eq(mat_0, mat_1), true);
    testing.expectEqual(mat4.is_eq(mat_0, mat_2), false);
}

test "zalgebra.Mat4.from_translate" {
    const mat4_trans = mat4.from_translate(vec3.new(2, 3, 4));

    testing.expectEqual(mat4.is_eq(mat4_trans, mat4{
        .data = .{
            .{ 1., 0., 0., 0. },
            .{ 0., 1., 0., 0. },
            .{ 0., 0., 1., 0. },
            .{ 2., 3., 4., 1. },
        },
    }), true);
}

test "zalgebra.Mat4.translate" {
    const base = mat4.from_translate(vec3.new(2, 3, 2));
    const result = mat4.translate(base, vec3.new(2, 3, 4));

    testing.expectEqual(mat4.is_eq(result, mat4{
        .data = .{
            .{ 1., 0., 0., 0. },
            .{ 0., 1., 0., 0. },
            .{ 0., 0., 1., 0. },
            .{ 4., 9., 8., 1. },
        },
    }), true);
}

test "zalgebra.Mat4.from_scale" {
    const mat4_scale = mat4.from_scale(vec3.new(2, 3, 4));

    testing.expectEqual(mat4.is_eq(mat4_scale, mat4{
        .data = .{
            .{ 2., 0., 0., 0. },
            .{ 0., 3., 0., 0. },
            .{ 0., 0., 4., 0. },
            .{ 0., 0., 0., 1. },
        },
    }), true);
}

test "zalgebra.Mat4.scale" {
    const base = mat4.from_scale(vec3.new(2, 3, 4));
    const result = mat4.scale(base, vec3.new(2, 2, 2));

    testing.expectEqual(mat4.is_eq(result, mat4{
        .data = .{
            .{ 4., 0., 0., 0. },
            .{ 0., 6., 0., 0. },
            .{ 0., 0., 4., 0. },
            .{ 0., 0., 0., 1. },
        },
    }), true);
}

test "zalgebra.Mat4.inv" {
    const base: mat4 = .{
        .data = .{
            .{ 2., 0., 0., 4. },
            .{ 0., 2., 0., 0. },
            .{ 0., 0., 2., 0. },
            .{ 4., 0., 0., 2. },
        },
    };

    testing.expectEqual(mat4.is_eq(base.inv(), mat4{
        .data = .{
            .{ -0.1666666716337204, 0., 0., 0.3333333432674408 },
            .{ 0., 0.5, 0., 0. },
            .{ 0., 0., 0.5, 0. },
            .{ 0.3333333432674408, 0., 0., -0.1666666716337204 },
        },
    }), true);
}

test "zalgebra.Mat4.extract_translation" {
    var base = mat4.from_translate(vec3.new(2, 3, 2));
    base = base.translate(vec3.new(2, 3, 2));

    testing.expectEqual(vec3.is_eq(base.extract_translation(), vec3.new(4, 6, 4)), true);
}

test "zalgebra.Mat4.extract_rotation" {
    const lhs = mat4.from_euler_angle(vec3.new(45., -5., 20.));
    testing.expectEqual(vec3.is_eq(lhs.extract_rotation(), vec3.new(45.000003814697266, -4.99052524, 19.999998092651367)), true);
}

test "zalgebra.Mat4.extract_scale" {
    var base = mat4.from_scale(vec3.new(2, 4, 8));
    base = base.scale(vec3.new(2, 4, 8));

    testing.expectEqual(vec3.is_eq(base.extract_scale(), vec3.new(4, 16, 64)), true);
}
