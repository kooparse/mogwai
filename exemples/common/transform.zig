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
        var rot = self.rotation.to_mat4();

        rot.data[0][0] *= self.scale.x;
        rot.data[0][1] *= self.scale.x;
        rot.data[0][2] *= self.scale.x;

        rot.data[1][0] *= self.scale.y;
        rot.data[1][1] *= self.scale.y;
        rot.data[1][2] *= self.scale.y;

        rot.data[2][0] *= self.scale.z;
        rot.data[2][1] *= self.scale.z;
        rot.data[2][2] *= self.scale.z;


        rot.data[3][0] = self.position.x;
        rot.data[3][1] = self.position.y;
        rot.data[3][2] = self.position.z;

        return rot;
    }
};

