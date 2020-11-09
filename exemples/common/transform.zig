usingnamespace @import("zalgebra");

pub const Transform = struct {
    position: vec3 = vec3.new(0., 0., 0.),
    rotation: quat = quat.new(1, 0, 0, 0),
    scale: vec3 = vec3.new(1., 1., 1.),

    pub fn new(position: vec3, rotation: quat, scale: vec3) Transform {
        return .{
            .position = position,
            .rotation = rotation,
            .scale = scale,
        };
    }

    pub fn get_model(self: *const Transform) mat4 {
        var translate = mat4.from_translate(self.position);
        var rot = self.rotation.to_mat4();
        var scale = mat4.from_scale(self.scale);

        return mat4.mult(scale, mat4.mult(translate, rot));
    }
};

