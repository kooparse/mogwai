const std = @import("std");
const math = std.math;
const panic = std.debug.panic;
const za = @import("zalgebra");

pub const Mode = enum { None, Move, Rotate, Scale };
pub const State = enum { Idle, Hover, Dragging };

const Vec2 = za.Vec2;
const Vec3 = za.Vec3;
const Vec4 = za.Vec4;
const Quat = za.Quat;
const Mat4 = za.Mat4;

/// Ray used to store the projected cursor ray.
const Ray = struct {
    origin: Vec3, 
    dir: Vec3
};

/// Bounding Box used for collision detection.
/// Also used to construct box vertices.
const BoundingBox = struct {
    min: Vec3,
    max: Vec3,
};

/// Collection of bounding boxes.
const BoundingCollection = struct {
    /// X axis.
    x: BoundingBox,
    /// Y axis.
    y: BoundingBox,
    /// Z axis.
    z: BoundingBox,

    /// YZ Panel.
    yz: BoundingBox,
    /// XZ Panel.
    xz: BoundingBox,
    /// XY Panel.
    xy: BoundingBox,

    /// X box (scaling gizmo).
    x_box: BoundingBox,
    /// Y box (scaling gizmo).
    y_box: BoundingBox,
    /// Z box (scaling gizmo).
    z_box: BoundingBox,

    const Self = @This();

    pub fn init(config: *const Config) Self {
        const max_pos = config.panel_size + config.panel_offset;

        return .{
            .x = BoundingBox {
                .min = Vec3.zero(),
                .max = Vec3.new(config.axis_length, config.axis_size, config.axis_size)
            },

            .y = BoundingBox {
                .min = Vec3.zero(),
                .max = Vec3.new(config.axis_size, config.axis_length, config.axis_size)
            },

            .z = BoundingBox {
                .min = Vec3.zero(),
                .max = Vec3.new(config.axis_size, config.axis_size, -config.axis_length)
            },

            .yz = BoundingBox {
                .min = Vec3.new(0, config.panel_offset, -config.panel_offset),
                .max = Vec3.new(config.panel_width, max_pos, -max_pos)
            },

            .xz = BoundingBox {
                .min = Vec3.new(config.panel_offset, 0, -config.panel_offset),
                .max = Vec3.new(max_pos, config.panel_width, -max_pos)
            },

            .xy = BoundingBox {
                .min = Vec3.new(config.panel_offset, config.panel_offset, 0),
                .max = Vec3.new(max_pos, max_pos, config.panel_width)
            },

            .x_box = BoundingBox {
                .min = Vec3.new(config.axis_length, -config.scale_box_size , -config.scale_box_size),
                .max= Vec3.new(config.axis_length + config.scale_box_size * 2, config.scale_box_size, config.scale_box_size),
            },

            .y_box = BoundingBox {
                .min = Vec3.new(-config.scale_box_size, config.axis_length, -config.scale_box_size),
                .max= Vec3.new(config.scale_box_size, config.axis_length + config.scale_box_size * 2, config.scale_box_size),
            },

            .z_box = BoundingBox {
                .min = Vec3.new(-config.scale_box_size , -config.scale_box_size, -config.axis_length),
                .max= Vec3.new( config.scale_box_size, config.scale_box_size, -(config.axis_length + config.scale_box_size * 2),),
            }
        };
    }


};

/// All Gizmo visible parts.
pub const GizmoItem = enum {
    PanelYZ,
    PanelXY,
    PanelXZ,
    ArrowX,
    ArrowY,
    ArrowZ,
    RotateX,
    RotateY,
    RotateZ,
    ScalerX,
    ScalerY,
    ScalerZ,
};

/// This is the computed result from the given target matrix after
/// gizmo manipulation. It's the result type of the `manipulate` method.
/// Hint: To transform `Quat` into `Vec3`, use the `extract_rotation` method.
pub const GizmoTransform = struct {
    position: Vec3 = Vec3.new(0, 0, 0),
    rotation: Quat = Quat.new(0, 0, 0, 0),
    scale: Vec3 = Vec3.new(1, 1, 1),
};

/// Configuration.
/// Only viewport is required.
pub const Config = struct {
    /// Viewport options.
    screen_width: i32,
    screen_height: i32,
    dpi: i32 = 1,

    /// Snap mode.
    snap_axis: ?f32 = null,
    snap_angle: ?f32 = null,

    /// Radius of the arcball.
    arcball_radius: f32 = 1,
    /// The size of the handle when in Rotate mode.
    arcball_thickness: f32 = 0.02,

    /// Global size of dragging panels.
    panel_size: f32  = 0.5,
    /// Offset from gizmo current position.
    panel_offset: f32 = 0.2,
    /// Width of the panels.
    panel_width: f32 = 0.02,

    /// Length of axis.
    axis_length: f32  = 1,
    /// Axis boldness size.
    axis_size: f32  = 0.05,

    // Little "weight" box at the end of scaled axis.
    scale_box_size: f32 = 0.1
};

const Camera = struct {
    view: Mat4,
    proj: Mat4,
};

const Cursor = struct {
    x: f64,
    y: f64,
    is_pressed: bool = false,
};

const CUBOID_INDICES = [36]i32{
    0,1,2, 
    0,2,3, 
    4,5,6, 
    4,6,7, 
    8,9,10, 
    8,10,11,
    12,13,14, 
    12,14,15, 
    16,17,18,
    16,18,19, 
    20,21,22,
    20,22,23,
};

const MeshPanels = struct {
    yz: [72]f32,
    xz: [72]f32,
    xy: [72]f32,
    indices: @TypeOf(CUBOID_INDICES)
};

const MeshAxis = struct {
    x: [72]f32,
    y: [72]f32,
    z: [72]f32,
    indices: @TypeOf(CUBOID_INDICES)
};

pub const MeshRotateAxis = struct {
    x: [3240]f32,
    y: [3240]f32,
    z: [3240]f32,
};

pub const MeshScaleAxis = struct {
    x: [144]f32,
    y: [144]f32,
    z: [144]f32,
    indices: [72]i32,
};

pub const Mogwai = struct {
    /// Gizmo's mode, if `None` don't show/compute anything.
    mode: Mode = Mode.None,
    /// Current state.
    state: State = State.Idle,
    /// Active item.
    active: ?GizmoItem = null,

    /// All bounding box used for collision are stored here.
    bb: BoundingCollection,

    /// Gizmo general Config.
    config: Config,
    /// Client's view and projection matrices.
    cam: Camera,
    /// Client's cursor positions and state.
    cursor: Cursor,

    /// This is the point representing the 
    /// nearest successful collision.
    click_offset: Vec3 = Vec3.zero(),
    /// Current position of the gizmo, usually the position of the target.
    position: Vec3 = Vec3.zero(),
    /// All constructed meshes are stored there, used for client's renderer.
    meshes: struct {
        move_panels: MeshPanels,
        move_axis: MeshAxis,
        rotate_axis: MeshRotateAxis,
        scale_axis: MeshScaleAxis
    },

    /// We keep track of target's original data just before the dragging state starts.
    /// We extract those information from the given target matrix.
    original_transform: GizmoTransform = .{},
    /// Active axis (X, Y, Z).
    active_axis: ?Vec3 = null,

    /// Used for compute theta on Rotate mode.
    /// Theta is the angle between `started_arm` and `ended_arm`.
    started_arm: ?Vec3 = null,
    ended_arm: ?Vec3 = null,

    const Self = @This();

    /// Construct new gizmo from given config.
    pub fn new(config: Config) Self {
        return .{
            .config = config,
            .bb = BoundingCollection.init(&config),
            .meshes = .{
                .move_panels = make_move_panels(config.panel_size, config.panel_offset, config.panel_width),
                .move_axis = make_move_axis(config.axis_size, config.axis_length),
                .rotate_axis = make_rotate_axis(&config),
                .scale_axis = make_scale_axis(config.axis_size, config.axis_length, config.scale_box_size),
            },
            .cam = .{
                .view = Mat4.identity(),
                .proj = Mat4.identity(),
            },
            .cursor = .{
                .x = 0.0,
                .y = 0.0,
                .is_pressed = false,
            },
        };
    }

    /// Return if given object is hovered by the cursor.
    pub fn isHover(self: *const Self, object: GizmoItem) bool {
        return self.active != null and self.active.? == object;
    }

    /// Set the screen size.
    pub fn setViewport(self: *Self, width: i32, height: i32, dpi: i32) void {
        self.config.screen_width = width;
        self.config.screen_height = height;
        self.viewport.dpi = dpi;
    }

    /// Set the cursor position and if it was pressed.
    pub fn setCursor(self: *Self, x: f64, y: f64, is_pressed: bool) void {
        self.cursor.x = x;
        self.cursor.y = y;
        self.cursor.is_pressed = is_pressed;

        // If cursor is released, Gizmo isn't "active".
        if (!is_pressed) {
            self.state = State.Idle;
            self.active = null;
            self.click_offset = Vec3.zero();
            self.original_transform = .{};
            self.active_axis = null;
            self.started_arm = null;
            self.ended_arm = null;
        }
    }

    /// Set the view matrix and projection matrix, needed to compute
    /// the position of the eye, and all intersection in space.
    pub fn setCamera(self: *Self, view: Mat4, proj: Mat4) void {
        self.cam.view = view;
        self.cam.proj = proj;
    }

    /// Manipulate the gizmo from the given cursor state and position.
    pub fn manipulate(self: *Self, target: Mat4, mode: Mode) ?GizmoTransform {
        // If mode is none, we don't want to compute something.
        if (mode == Mode.None) {
            return null;
        }

        var result: ?GizmoTransform = null;

        // Gizmo's position in world space.
        self.position = target.extractTranslation();
        // Position of the camera, where the ray will be cast.
        const eye = self.cam.view.inv().extractTranslation();
        // Raycast used for collision detection.
        const ray = raycast(eye, self.cam, self.config, self.cursor);

        switch (mode) {
            Mode.Scale,
            Mode.Move => {
                var hit: ?Vec3 = null;
                var nearest_distance: f32 = math.f32_max;

                if (self.state != State.Dragging) {
                    if (mode == Mode.Move) {
                        intersect_cuboid(self, ray, &self.bb.x, GizmoItem.ArrowX, Vec3.right(), &nearest_distance, &hit);
                        intersect_cuboid(self, ray, &self.bb.y, GizmoItem.ArrowY, Vec3.up(), &nearest_distance, &hit);
                        intersect_cuboid(self, ray, &self.bb.z, GizmoItem.ArrowZ, Vec3.forward(), &nearest_distance, &hit);

                        intersect_cuboid(self, ray, &self.bb.yz, GizmoItem.PanelYZ, Vec3.right(), &nearest_distance, &hit);
                        intersect_cuboid(self, ray, &self.bb.xz, GizmoItem.PanelXZ, Vec3.up(), &nearest_distance, &hit);
                        intersect_cuboid(self, ray, &self.bb.xy, GizmoItem.PanelXY, Vec3.forward(), &nearest_distance, &hit);
                    }

                    if (mode == Mode.Scale) {
                        intersect_cuboid(self, ray, &self.bb.x, GizmoItem.ScalerX, Vec3.right(), &nearest_distance, &hit);
                        intersect_cuboid(self, ray, &self.bb.y, GizmoItem.ScalerY, Vec3.up(), &nearest_distance, &hit);
                        intersect_cuboid(self, ray, &self.bb.z, GizmoItem.ScalerZ, Vec3.forward(), &nearest_distance, &hit);

                        intersect_cuboid(self, ray, &self.bb.x_box, GizmoItem.ScalerX, Vec3.right(), &nearest_distance, &hit);
                        intersect_cuboid(self, ray, &self.bb.y_box, GizmoItem.ScalerY, Vec3.up(), &nearest_distance, &hit);
                        intersect_cuboid(self, ray, &self.bb.z_box, GizmoItem.ScalerZ, Vec3.forward(), &nearest_distance, &hit);
                    }

                    if (hit != null)  {
                        self.click_offset = hit.?;
                        self.original_transform.position = target.extractTranslation();
                        self.original_transform.scale = target.extractScale();
                        self.state = State.Hover;
                    }
                }

                if (self.state == State.Dragging) {
                    const axis = self.active_axis.?;
                    const position = self.click_offset;
                    var plane_normal = axis;

                    switch (self.active.?) {
                        GizmoItem.ScalerX,
                        GizmoItem.ScalerY,
                        GizmoItem.ScalerZ,
                        GizmoItem.ArrowX,
                        GizmoItem.ArrowY,
                        GizmoItem.ArrowZ => {
                            const plane_tangent = Vec3.cross(axis, Vec3.sub(position, eye));
                            plane_normal = Vec3.cross(axis, plane_tangent);
                        }, 
                        else => {}
                    }

                    if (ray_vs_plane(plane_normal, position, ray)) |dist| {
                        hit = ray.origin.add(ray.dir.scale(dist));
                    }
                } 

                if (!self.cursor.is_pressed or self.state == State.Idle) {
                    return result;
                }

                if (hit) |p| {
                    self.state = State.Dragging;

                    const original = self.original_transform;
                    var diff = p.sub(self.click_offset);

                    if (self.config.snap_axis) |snap| {
                        diff.data[0] = math.floor(diff.x() / snap) * snap;
                        diff.data[1] = math.floor(diff.y() / snap) * snap;
                        diff.data[2] = math.floor(diff.z() / snap) * snap;
                    }

                    result = .{};

                    // Used to clamp scale values at Epsilon.
                    const epsilon_vec = Vec3.new(math.f32_epsilon, math.f32_epsilon, math.f32_epsilon);

                    switch (self.active.?) {
                        GizmoItem.ArrowX => {
                            result.?.position = original.position.add(Vec3.new(diff.x(), 0, 0));
                        },
                        GizmoItem.ArrowY => {
                            result.?.position = original.position.add(Vec3.new(0, diff.y(), 0));
                        },
                        GizmoItem.ArrowZ => {
                            result.?.position = original.position.add(Vec3.new(0, 0, diff.z()));
                        },
                        GizmoItem.PanelYZ => {
                            result.?.position = original.position.add(Vec3.new(0, diff.y(), diff.z()));
                        },
                        GizmoItem.PanelXZ => {
                            result.?.position = original.position.add(Vec3.new(diff.x(), 0, diff.z()));
                        },
                        GizmoItem.PanelXY => {
                            result.?.position = original.position.add(Vec3.new(diff.x(), diff.y(), 0));
                        },
                        GizmoItem.ScalerX => {
                            result.?.scale = Vec3.max(original.scale.add(Vec3.new(diff.x(), 0, 0)), epsilon_vec);
                        },
                        GizmoItem.ScalerY => {
                            result.?.scale = Vec3.max(original.scale.add(Vec3.new(0, diff.y(), 0)), epsilon_vec);
                        },
                        GizmoItem.ScalerZ => {
                            result.?.scale = Vec3.max(original.scale.add(Vec3.new(0, 0, -diff.z())), epsilon_vec);
                        },
                        else => {}
                    }
                }
            },

            Mode.Rotate => {
                var hit: ?Vec3 = null;
                var nearest_distance: f32 = math.f32_max;

                if (self.state != State.Dragging) {
                    intersect_circle(self, ray, GizmoItem.RotateX, Vec3.right(), &nearest_distance, &hit);
                    intersect_circle(self, ray, GizmoItem.RotateY, Vec3.up(), &nearest_distance, &hit);
                    intersect_circle(self, ray, GizmoItem.RotateZ, Vec3.forward(), &nearest_distance, &hit);

                    if (hit != null) {
                        const normalized = target.orthoNormalize();
                        self.original_transform.rotation = Quat.fromMat4(normalized);
                        self.state = State.Hover;
                        self.click_offset = hit.?;
                    }

                }

                if (self.state == State.Dragging) {
                    const axis = self.active_axis.?;
                    const position = self.click_offset;

                    if (ray_vs_plane(axis, position, ray)) |dist| {
                        hit = ray.origin.add(ray.dir.scale(dist));
                    }
                }

                if (!self.cursor.is_pressed or self.state == State.Idle) {
                    return result;
                }

                if (hit) |p| {
                    self.state = State.Dragging;

                    const arm = Vec3.sub(self.position, p).norm();

                    if (self.started_arm == null) {
                        self.started_arm = arm;
                    }

                    self.ended_arm = arm;

                    // Now, we want to get the angle in degrees of those arms.
                    const dot_product = math.min(1, Vec3.dot(self.ended_arm.?, self.started_arm.?));
                    // The `acos` of a dot product will gives us the angle between two vectors, in radians.
                    // We just have to convert it to degrees.
                    var angle = za.toDegrees(math.acos(dot_product));

                    if (self.config.snap_angle) |snap| {
                        angle = math.floor(angle / snap) * snap;
                    }

                    // If angle is less than 1 degree, we don't want to do anything.
                    if (angle < 1) return null;

                    const cross_product = Vec3.cross(self.started_arm.?, self.ended_arm.?).norm();
                    const new_rot = Quat.fromAxis(angle, cross_product);
                    const rotation = Quat.mul(new_rot, self.original_transform.rotation);

                    result = .{ .rotation = rotation };
                }
            },
            else => {},
        }

        return result;
    }

    /// Collision between ray and axis-aligned bounding box.
    /// If hit happen, return the distance between the origin and the hit.
    fn ray_vs_aabb(min: Vec3, max: Vec3, r: Ray) ?f32 {
        var tmin = -math.inf_f32;
        var tmax = math.inf_f32;

        var i: usize = 0;
        while (i < 3) : (i += 1) {
            if (r.dir.data[i] != 0) {
                const t1 = (min.data[i] - r.origin.data[i])/r.dir.data[i];
                const t2 = (max.data[i] - r.origin.data[i])/r.dir.data[i];

                tmin = math.max(tmin, math.min(t1, t2));
                tmax = math.min(tmax, math.max(t1, t2));
            } else if (r.origin.data[i] < min.data[i] or r.origin.data[i] > max.data[i]) {
                return null;
            }
        }

        if (tmax >= tmin and tmax >= 0.0) {
            return tmin;
        } 

        return null;
    }

    fn ray_vs_plane(normal: Vec3, plane_pos: Vec3, ray: Ray) ?f32 {
        var intersection: f32 = undefined;
        const denom: f32 = Vec3.dot(normal, ray.dir);

        // TODO: absMath?
        if (denom > 1e-6) {
            const line = Vec3.sub(plane_pos, ray.origin);
            intersection = Vec3.dot(line, normal) / denom;

            return if (intersection > 0) intersection else null;
        }


        return null;
    }

    fn ray_vs_disk(normal: Vec3, disk_pos: Vec3, ray: Ray, radius: f32) ?f32 {
        if (ray_vs_plane(normal, disk_pos, ray)) |intersection| {
            const p = Vec3.add(ray.origin, Vec3.scale(ray.dir, intersection));
            const v = Vec3.sub(p, disk_pos);
            const d2 = Vec3.dot(v, v);

            return if (math.sqrt(d2) <= radius) intersection else null;
        }

        return null;
    }

    fn intersect_cuboid(self: *Self, ray: Ray, bb: *const BoundingBox, selected_object: GizmoItem, axis: Vec3, near_dist: *f32, near_hit: *?Vec3) void {
        const min = self.position.add(bb.min);
        const max = self.position.add(bb.max);

        if (ray_vs_aabb(min, max, ray)) |distance| {
            if (distance < near_dist.*) {
                const hit = ray.origin.add(ray.dir.scale(distance));

                near_dist.* = distance;
                self.active = selected_object;
                self.active_axis = axis;

                near_hit.* = hit;
            }
        }
    }

    fn intersect_circle(self: *Self, ray: Ray, selected_object: GizmoItem, axis: Vec3, near_dist: *f32, near_hit: *?Vec3) void {
        const outer_hit = ray_vs_disk(axis, self.position, ray, self.config.arcball_radius + self.config.arcball_thickness);
        const inner_hit = ray_vs_disk(axis, self.position, ray, self.config.arcball_radius - self.config.arcball_thickness);

        if (outer_hit != null and inner_hit == null and outer_hit.? < near_dist.*) {
            near_dist.* = outer_hit.?;
            self.active = selected_object;
            self.active_axis = axis;

            near_hit.* = ray.origin.add(ray.dir.scale(outer_hit.?));
        }
    }

    /// Simple raycast function used to intersect cursor and gizmo objects.
    fn raycast(pos: Vec3, cam: Camera, config: Config, cursor: Cursor) Ray {
        const clip_ndc = Vec2.new(
            (@floatCast(f32, cursor.x) * @intToFloat(f32, config.dpi)) / @intToFloat(f32, config.screen_width) - 1, 
            1 - (@floatCast(f32, cursor.y) * @intToFloat(f32, config.dpi)) / @intToFloat(f32, config.screen_height)
        );

        const clip_space = Vec4.new(clip_ndc.x(), clip_ndc.y(), -1, 1);
        const eye_tmp = Mat4.mulByVec4(Mat4.inv(cam.proj), clip_space);
        const world_tmp = Mat4.mulByVec4(Mat4.inv(cam.view), Vec4.new(eye_tmp.x(), eye_tmp.y(), -1, 0));

        return .{
            .origin = pos,
            .dir = Vec3.new(world_tmp.x(), world_tmp.y(), world_tmp.z()).norm(),
        };
    }

    /// Construct cuboid from given bounds.
    /// Used to construct cubes, axis and planes.
    fn construct_cuboid(min_bounds: Vec3, max_bounds: Vec3) [72]f32 {
        const a = min_bounds;
        const b = max_bounds;

        return .{
          a.x(), a.y(), a.z(), a.x(), a.y(), b.z(), 
          a.x(), b.y(), b.z(), a.x(), b.y(), a.z(), 
          b.x(), a.y(), a.z(), b.x(), b.y(), a.z(), 
          b.x(), b.y(), b.z(), b.x(), a.y(), b.z(), 
          a.x(), a.y(), a.z(), b.x(), a.y(), a.z(), 
          b.x(), a.y(), b.z(), a.x(), a.y(), b.z(), 
          a.x(), b.y(), a.z(), a.x(), b.y(), b.z(), 
          b.x(), b.y(), b.z(), b.x(), b.y(), a.z(), 
          a.x(), a.y(), a.z(), a.x(), b.y(), a.z(), 
          b.x(), b.y(), a.z(), b.x(), a.y(), a.z(), 
          a.x(), a.y(), b.z(), b.x(), a.y(), b.z(), 
          b.x(), b.y(), b.z(), a.x(), b.y(), b.z(), 
      };

    }

    /// Make gizmo planes (YZ, XZ, XY).
    fn make_move_panels(panel_size: f32, panel_offset: f32, panel_width: f32) MeshPanels {
        var mesh: MeshPanels = undefined;

        const max = panel_offset + panel_size;

        mesh.yz = construct_cuboid(Vec3.new(0, panel_offset, -panel_offset), Vec3.new(panel_width, max, -max));
        mesh.xz = construct_cuboid(Vec3.new(panel_offset, 0, -panel_offset), Vec3.new(max, panel_width, -max));
        mesh.xy = construct_cuboid(Vec3.new(panel_offset, panel_offset, 0), Vec3.new(max, max, panel_width));
        mesh.indices = CUBOID_INDICES;

        return mesh;
    }

    /// Make gizmo axis as cuboid. (X, Y, Z).
    fn make_move_axis(size: f32, length: f32) MeshAxis {
        var mesh: MeshAxis = undefined;

        mesh.x = construct_cuboid(Vec3.new(0, 0, 0), Vec3.new(length, size, size));
        mesh.y = construct_cuboid(Vec3.new(0, 0, 0), Vec3.new(size, length, size));
        mesh.z = construct_cuboid(Vec3.new(0, 0, 0), Vec3.new(size, size, -length));

        mesh.indices = CUBOID_INDICES;

        return mesh;
    }

    /// Make gizmo scale axis (with orthogonal cuboid at the end).
    /// TODO: I think we could a lot better here...
    fn make_scale_axis(size: f32, length: f32, box_size: f32) MeshScaleAxis {
        var mesh: MeshScaleAxis = undefined;

        const half_size = size * 0.5;
        const total_size = length + box_size * 2;

        const x_axis = construct_cuboid(Vec3.new(0, 0, 0), Vec3.new(length, size, size));
        const x_box = construct_cuboid(Vec3.new(length, -box_size + half_size, -box_size + half_size), Vec3.new(total_size, box_size + half_size, box_size + half_size));
        std.mem.copy(f32, &mesh.x, x_axis[0..]);
        std.mem.copy(f32, mesh.x[72..], x_box[0..]);

        const y_axis = construct_cuboid(Vec3.new(0, 0, 0), Vec3.new(size, length, size));
        const y_box = construct_cuboid(Vec3.new(-box_size + half_size, length, -box_size + half_size), Vec3.new(box_size + half_size, total_size, box_size + half_size));
        std.mem.copy(f32, &mesh.y, y_axis[0..]);
        std.mem.copy(f32, mesh.y[72..], y_box[0..]);

        const z_axis = construct_cuboid(Vec3.new(0, 0, 0), Vec3.new(size, size, -length));
        const z_box = construct_cuboid(Vec3.new(-box_size + half_size, -box_size + half_size, -length), Vec3.new(box_size + half_size, box_size + half_size, -total_size));
        std.mem.copy(f32, &mesh.z, z_axis[0..]);
        std.mem.copy(f32, mesh.z[72..], z_box[0..]);


        mesh.indices = CUBOID_INDICES ** 2;

        for (mesh.indices) |_, index| {
            if (index >= CUBOID_INDICES.len) {
                mesh.indices[index] += 24;
            }
        }

        return mesh;
    }

    /// This will create vertices for all axis circle 
    /// used to rotate the target.
    pub fn make_rotate_axis(config: *const Config) MeshRotateAxis {
        var mesh: MeshRotateAxis = undefined;

        mesh.x = create_axis_arcball(GizmoItem.RotateX, config.arcball_radius, config.arcball_thickness);
        mesh.y = create_axis_arcball(GizmoItem.RotateY, config.arcball_radius, config.arcball_thickness);
        mesh.z = create_axis_arcball(GizmoItem.RotateZ, config.arcball_radius, config.arcball_thickness);

        return mesh;
    }

    pub fn create_axis_arcball(axis: GizmoItem, radius: f32, thickness: f32) [60 * 18 * 3]f32 {
        const segments = 60;

        var deg: i32 = 0;
        var i: usize = 0;
        var vertex: [segments * 18 * 3]f32 = undefined;

        const max_deg: i32 = 360;
        var segment_vertex: [segments]Vec3 = undefined;

        while (deg < max_deg) : (deg += @divExact(max_deg, segments)) {
            const angle = za.toRadians(@intToFloat(f32, deg));
            const x = math.cos(angle) * radius;
            const y = math.sin(angle) * radius;

            segment_vertex[i] = switch (axis) {
                GizmoItem.RotateX => Vec3.new(x, y, 0),
                GizmoItem.RotateY => Vec3.new(0, y, x),
                GizmoItem.RotateZ => Vec3.new(x, 0, y),
                else => std.debug.panic("Object selected isn't a rotate axis.\n", .{})
            };

            i += 1;
        }

        var j: usize = 0;
        var k: usize = 0;
        while (j < segment_vertex.len) : (j += 1) {
            const p0 = segment_vertex[j];
            const p1 = if (j == segment_vertex.len - 1) segment_vertex[0] else segment_vertex[j + 1];
            const previous = if (j == 0) segment_vertex[segment_vertex.len - 1] else segment_vertex[j - 1];
            const next = if (j == segment_vertex.len - 2) segment_vertex[0] else if (j == segment_vertex.len - 1) segment_vertex[1] else segment_vertex[j + 2];

            for (create_segment(p0, p1, previous, next, thickness, axis)) |v, idx| {
                vertex[k + idx] = v;
            }

            k += 18;
        }

        return vertex;

    }

    /// This function will create a '2d' segment from two points. But to construct a 'perfect' joined path, 
    /// we also need two other points, the previous and next one. Those two points are used to 
    /// correctly compute the cross-section, which gives us sharp angles.
    /// More details in those posts: 
    /// https://forum.libcinder.org/topic/smooth-thick-lines-using-geometry-shader.
    fn create_segment(p0: Vec3, p1: Vec3, previous: Vec3, next: Vec3, thickness: f32, axis: GizmoItem) [18]f32 {
        // Compute middle line.
        const line = Vec3.sub(p1, p0);
        var normal: Vec3 = undefined;

        // Compute tangeants.
        const t0 = Vec3.add(Vec3.sub(p0, previous).norm(), Vec3.sub(p1, p0).norm()).norm();
        const t1 = Vec3.add(Vec3.sub(next, p1).norm(), Vec3.sub(p1, p0).norm()).norm();

        var miter0: Vec3 = undefined;
        var miter1: Vec3 = undefined;

        switch (axis) {
            GizmoItem.RotateX => {
                normal = Vec3.new(-line.y(), line.x(), 0).norm();
                miter0 = Vec3.new(-t0.y(), t0.x(), 0);
                miter1 = Vec3.new(-t1.y(), t1.x(), 0);

            },
            GizmoItem.RotateY => {
                normal = Vec3.new(0, -line.z(), line.y()).norm();
                miter0 = Vec3.new(0, -t0.z(), t0.y());
                miter1 = Vec3.new(0, -t1.z(), t1.y());

            },
            GizmoItem.RotateZ => {
                normal = Vec3.new(-line.z(), 0, line.x()).norm();
                miter0 = Vec3.new(-t0.z(), 0, t0.x());
                miter1 = Vec3.new(-t1.z(), 0, t1.x());

            },
            else => std.debug.panic("Object selected isn't a rotate axis.\n", .{})
        }

        const length0 = thickness / Vec3.dot(miter0, normal);
        const length1 = thickness / Vec3.dot(miter1, normal);

        const a = Vec3.add(p0, Vec3.scale(miter0, length0));
        const b = Vec3.add(p1, Vec3.scale(miter1, length1));
        const e = Vec3.sub(p0, Vec3.scale(miter0, length0));
        const d = Vec3.sub(p1, Vec3.scale(miter1, length1));

        return .{
            a.x(), a.y(), a.z(),
            b.x(), b.y(), b.z(),
            e.x(), e.y(), e.z(),

            b.x(), b.y(), b.z(),
            d.x(), d.y(), d.z(),
            e.x(), e.y(), e.z(),
        };
    }
};
