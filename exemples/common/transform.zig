const za = @import("zalgebra");
const Vec3 = za.Vec3;
const Quat = za.Quat;
const Mat4 = za.Mat4;

pub const Transform = struct {
    position: Vec3 = Vec3.new(0, 0, 0),
    rotation: Quat = Quat.new(1, 0, 0, 0),
    scale: Vec3 = Vec3.new(1, 1, 1),

    pub fn new(position: Vec3, rotation: Quat, scale: Vec3) Transform {
        return .{
            .position = position,
            .rotation = rotation,
            .scale = scale,
        };
    }

    pub fn get_model(self: *const Transform) Mat4 {
        const rotation = self.rotation.toMat4();
        const scale = Mat4.fromScale(self.scale);
        const transform = Mat4.fromTranslate(self.position);

        return transform.mul(rotation.mul(scale));
    }
};
