const c = @import("c.zig").glfw;
const math = @import("std").math;
const za = @import("zalgebra");
const glfw = @import("glfw");

const Vec3 = za.Vec3;
const toRadians = za.toRadians;

pub const Camera = struct {
    position: Vec3,
    front: Vec3 = Vec3.new(0, 0, 1),
    up: Vec3 = Vec3.new(0, 1, 0),
    yaw: f64 = 90,
    pitch: f64 = 0,

    speed: f32 = 3,
    is_first_mouse: bool = true,

    last_cursor_pos_x: f64 = 0,
    last_cursor_pos_y: f64 = 0,

    should_update: bool = true,

    const Self = @This();

    pub fn init(position: Vec3) Self {
        return Self{ .position = position };
    }

    pub fn update(self: *Self, window: glfw.Window, delta_time: f64, should_update: bool) void {
        const speed: f32 = self.speed * @floatCast(f32, delta_time);

        self.should_update = should_update;

        if (self.should_update) {
            if (window.getKey(.w) == .press) {
                self.position = self.position.add(self.front.scale(speed));
            }

            if (window.getKey(.s) == .press) {
                self.position = self.position.sub(self.front.scale(speed));
            }

            if (window.getKey(.a) == .press) {
                self.position = self.position.sub((self.front.cross(self.up).norm()).scale(speed));
            }

            if (window.getKey(.d) == .press) {
                self.position = self.position.add((self.front.cross(self.up).norm()).scale(speed));
            }

            if (window.getKey(.e) == .press) {
                self.position = self.position.add(self.up.scale(speed));
            }

            if (window.getKey(.q) == .press) {
                self.position = self.position.sub(self.up.scale(speed));
            }
        }

        const pos = window.getCursorPos() catch unreachable;
        var pos_x: f64 = pos.xpos;
        var pos_y: f64 = pos.ypos;

        if (self.is_first_mouse or !self.should_update) {
            self.last_cursor_pos_x = pos_x;
            self.last_cursor_pos_y = pos_y;
            self.is_first_mouse = false;
        }

        var x_offset = pos_x - self.last_cursor_pos_x;
        var y_offset = self.last_cursor_pos_y - pos_y;
        self.last_cursor_pos_x = pos_x;
        self.last_cursor_pos_y = pos_y;

        if (!self.should_update) {
            return;
        }

        x_offset *= speed;
        y_offset *= speed;

        self.yaw += x_offset;
        self.pitch += y_offset;

        if (self.pitch > 89.0)
            self.pitch = 89.0;
        if (self.pitch < -89.0)
            self.pitch = -89.0;

        var direction: Vec3 = undefined;
        direction.data[0] = @floatCast(f32, math.cos(toRadians(self.yaw)) * math.cos(toRadians(self.pitch)));
        direction.data[1] = @floatCast(f32, math.sin(toRadians(self.pitch)));
        direction.data[2] = @floatCast(f32, math.sin(toRadians(self.yaw)) * math.cos(toRadians(self.pitch)));
        self.front = direction.norm();
    }
};
