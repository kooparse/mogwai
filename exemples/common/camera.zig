const c = @import("c.zig");
const math = @import("std").math;
usingnamespace @import("zalgebra");

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

    pub fn update(self: *Self, window: *c.GLFWwindow, delta_time: f64, should_update: bool) void {
        const speed: f32 = self.speed * @floatCast(f32, delta_time);

        self.should_update = should_update;

        if (self.should_update) {
            if (c.glfwGetKey(window, c.GLFW_KEY_W) == c.GLFW_PRESS) {
                self.position = self.position.add(self.front.scale(speed));
            }

            if (c.glfwGetKey(window, c.GLFW_KEY_W) == c.GLFW_PRESS) {
                self.position = self.position.add(self.front.scale(speed));
            }

            if (c.glfwGetKey(window, c.GLFW_KEY_S) == c.GLFW_PRESS) {
                self.position = self.position.sub(self.front.scale(speed));
            }

            if (c.glfwGetKey(window, c.GLFW_KEY_A) == c.GLFW_PRESS) {
                self.position = self.position.sub((self.front.cross(self.up).norm()).scale(speed));
            }

            if (c.glfwGetKey(window, c.GLFW_KEY_D) == c.GLFW_PRESS) {
                self.position = self.position.add((self.front.cross(self.up).norm()).scale(speed));
            }

            if (c.glfwGetKey(window, c.GLFW_KEY_E) == c.GLFW_PRESS) {
                self.position = self.position.add(self.up.scale(speed));
            }

            if (c.glfwGetKey(window, c.GLFW_KEY_Q) == c.GLFW_PRESS) {
                self.position = self.position.sub(self.up.scale(speed));
            }
        }

        var pos_x: f64 = 0;
        var pos_y: f64 = 0;
        c.glfwGetCursorPos(window, &pos_x, &pos_y);

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
        direction.x = @floatCast(f32, math.cos(toRadians(self.yaw)) * math.cos(toRadians(self.pitch)));
        direction.y = @floatCast(f32, math.sin(toRadians(self.pitch)));
        direction.z = @floatCast(f32, math.sin(toRadians(self.yaw)) * math.cos(toRadians(self.pitch)));
        self.front = direction.norm();
    }
};
