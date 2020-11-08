const std = @import("std");
const math = std.math;
const print = std.debug.print;
const panic = std.debug.panic;
usingnamespace @import("./libs/zalgebra/src/main.zig");

pub const Mode = enum { None, Move, Rotate, Scale };
pub const State = enum { Idle, Hover, Dragging };

/// Ray used to store the projected cursor ray.
const Ray = struct {
    origin: vec3, 
    dir: vec3
};

/// Bounding Box used for collision detection.
/// Also used to construct box vertices.
const BoundingBox = struct {
    min: vec3,
    max: vec3,
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
                .min = vec3.zero(),
                .max = vec3.new(config.axis_length, config.axis_size, config.axis_size)
            },

            .y = BoundingBox {
                .min = vec3.zero(),
                .max = vec3.new(config.axis_size, config.axis_length, config.axis_size)
            },

            .z = BoundingBox {
                .min = vec3.zero(),
                .max = vec3.new(config.axis_size, config.axis_size, -config.axis_length)
            },

            .yz = BoundingBox {
                .min = vec3.new(0, config.panel_offset, -config.panel_offset),
                .max = vec3.new(config.panel_width, max_pos, -max_pos)
            },

            .xz = BoundingBox {
                .min = vec3.new(config.panel_offset, 0, -config.panel_offset),
                .max = vec3.new(max_pos, config.panel_width, -max_pos)
            },

            .xy = BoundingBox {
                .min = vec3.new(config.panel_offset, config.panel_offset, 0),
                .max = vec3.new(max_pos, max_pos, config.panel_width)
            },

            .x_box = BoundingBox {
                .min = vec3.new(config.axis_length, -config.scale_box_size , -config.scale_box_size),
                .max= vec3.new(config.axis_length + config.scale_box_size * 2, config.scale_box_size, config.scale_box_size),
            },

            .y_box = BoundingBox {
                .min = vec3.new(-config.scale_box_size, config.axis_length, -config.scale_box_size),
                .max= vec3.new(config.scale_box_size, config.axis_length + config.scale_box_size * 2, config.scale_box_size),
            },

            .z_box = BoundingBox {
                .min = vec3.new(-config.scale_box_size , -config.scale_box_size, -config.axis_length),
                .max= vec3.new( config.scale_box_size, config.scale_box_size, -(config.axis_length + config.scale_box_size * 2),),
            }
        };
    }


};

/// All Gizmo visible parts.
pub const GizmoItem = enum {
    PlaneYZ,
    PlaneXY,
    PlaneXZ,
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
/// Hint: To transform `quat` into `vec3`, use the `extract_rotation` method.
pub const GizmoTransform = struct {
    position: vec3 = vec3.new(0., 0., 0.),
    rotation: quat = quat.new(0, 0, 0, 0),
    scale: vec3 = vec3.new(1., 1., 1.),
};

/// Configuration.
/// Only viewport is required.
pub const Config = struct {
    /// Viewport options.
    screen_width: i32,
    screen_height: i32,
    dpi: i32 = 1,

    /// Snap mode.
    snap: ?f32 = null,

    /// Number of segments generated for the arcball.
    arcball_segments: usize = 60,
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
    axis_length: f32  = 1.,
    /// Axis boldness size.
    axis_size: f32  = 0.05,

    // Little "weight" box at the end of scaled axis.
    scale_box_size: f32 = 0.1
};

const Camera = struct {
    view: mat4,
    proj: mat4,
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
    click_offset: vec3 = vec3.zero(),
    /// Current position of the gizmo, usually the position of the target.
    position: vec3 = vec3.zero(),
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
    active_axis: ?vec3 = null,

    /// Used for compute theta on Rotate mode.
    /// Theta is the angle between `started_arm` and `ended_arm`.
    started_arm: ?vec3 = null,
    ended_arm: ?vec3 = null,

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
                .view = mat4.identity(),
                .proj = mat4.identity(),
            },
            .cursor = .{
                .x = 0.0,
                .y = 0.0,
                .is_pressed = false,
            },
        };
    }

    /// Return if given object is hovered by the cursor.
    pub fn is_hover(self: *const Self, object: GizmoItem) bool {
        return self.active != null and self.active.? == object;
    }

    /// Set the screen size.
    pub fn set_viewport(self: *Self, width: i32, height: i32, dpi: i32) void {
        self.config.screen_width = width;
        self.config.screen_height = height;
        self.viewport.dpi = dpi;
    }

    /// Set the cursor position and if it was pressed.
    pub fn set_cursor(self: *Self, x: f64, y: f64, is_pressed: bool) void {
        self.cursor.x = x;
        self.cursor.y = y;
        self.cursor.is_pressed = is_pressed;

        // If cursor is released, Gizmo isn't "active".
        if (!is_pressed) {
            self.state = State.Idle;
            self.active = null;
            self.click_offset = vec3.zero();
            self.original_transform = .{};
            self.active_axis = null;
            self.started_arm = null;
            self.ended_arm = null;
        }
    }

    /// Set the view matrix and projection matrix, needed to compute
    /// the position of the eye, and all intersection in space.
    pub fn set_camera(self: *Self, view: mat4, proj: mat4) void {
        self.cam.view = view;
        self.cam.proj = proj;
    }

    /// Manipulate the gizmo from the given cursor state and position.
    pub fn manipulate(self: *Self, target: mat4, mode: Mode) ?GizmoTransform {
        // If mode is none, we don't want to compute something.
        if (mode == Mode.None) {
            return null;
        }

        var result: ?GizmoTransform = null;

        // Gizmo's position in world space.
        self.position = target.extract_translation();
        // Position of the camera, where the ray will be cast.
        const eye = self.cam.view.inv().extract_translation();
        // Raycast used for collision detection.
        const ray = raycast(eye, self.cam, self.config, self.cursor);

        switch (mode) {
            Mode.Scale,
            Mode.Move => {
                var hit: ?vec3 = null;
                var nearest_distance: f32 = math.f32_max;

                if (self.state != State.Dragging) {
                    if (mode == Mode.Move) {
                        intersect_cuboid(self, ray, &self.bb.x, GizmoItem.ArrowX, vec3.right(), &nearest_distance, &hit);
                        intersect_cuboid(self, ray, &self.bb.y, GizmoItem.ArrowY, vec3.up(), &nearest_distance, &hit);
                        intersect_cuboid(self, ray, &self.bb.z, GizmoItem.ArrowZ, vec3.forward(), &nearest_distance, &hit);

                        intersect_cuboid(self, ray, &self.bb.yz, GizmoItem.PlaneYZ, vec3.right(), &nearest_distance, &hit);
                        intersect_cuboid(self, ray, &self.bb.xz, GizmoItem.PlaneXZ, vec3.up(), &nearest_distance, &hit);
                        intersect_cuboid(self, ray, &self.bb.xy, GizmoItem.PlaneXY, vec3.forward(), &nearest_distance, &hit);
                    }

                    if (mode == Mode.Scale) {
                        intersect_cuboid(self, ray, &self.bb.x, GizmoItem.ScalerX, vec3.right(), &nearest_distance, &hit);
                        intersect_cuboid(self, ray, &self.bb.y, GizmoItem.ScalerY, vec3.up(), &nearest_distance, &hit);
                        intersect_cuboid(self, ray, &self.bb.z, GizmoItem.ScalerZ, vec3.forward(), &nearest_distance, &hit);

                        intersect_cuboid(self, ray, &self.bb.x_box, GizmoItem.ScalerX, vec3.right(), &nearest_distance, &hit);
                        intersect_cuboid(self, ray, &self.bb.y_box, GizmoItem.ScalerY, vec3.up(), &nearest_distance, &hit);
                        intersect_cuboid(self, ray, &self.bb.z_box, GizmoItem.ScalerZ, vec3.forward(), &nearest_distance, &hit);
                    }

                    if (hit != null)  {
                        self.click_offset = hit.?;
                        self.original_transform.position = target.extract_translation();
                        self.original_transform.scale = target.extract_scale();
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
                            const plane_tangent = vec3.cross(axis, vec3.sub(position, eye));
                            plane_normal = vec3.cross(axis, plane_tangent);
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

                    if (self.config.snap) |snap| {
                        diff.x = math.floor(diff.x / snap) * snap;
                        diff.y = math.floor(diff.y / snap) * snap;
                        diff.z = math.floor(diff.z / snap) * snap;
                    }

                    result = .{};

                    switch (self.active.?) {
                        GizmoItem.ArrowX => {
                            result.?.position = original.position.add(vec3.new(diff.x, 0., 0.));
                        },
                        GizmoItem.ArrowY => {
                            result.?.position = original.position.add(vec3.new(0., diff.y, 0.));
                        },
                        GizmoItem.ArrowZ => {
                            result.?.position = original.position.add(vec3.new(0., 0., diff.z));
                        },
                        GizmoItem.PlaneYZ => {
                            result.?.position = original.position.add(vec3.new(0., diff.y, diff.z));
                        },
                        GizmoItem.PlaneXZ => {
                            result.?.position = original.position.add(vec3.new(diff.x, 0., diff.z));
                        },
                        GizmoItem.PlaneXY => {
                            result.?.position = original.position.add(vec3.new(diff.x, diff.y, 0.));
                        },
                        GizmoItem.ScalerX => {
                            result.?.scale = original.scale.add(vec3.new(diff.x, 0., 0.));
                        },
                        GizmoItem.ScalerY => {
                            result.?.scale = original.scale.add(vec3.new(0., diff.y, 0.));
                        },
                        GizmoItem.ScalerZ => {
                            result.?.scale = original.scale.add(vec3.new(0., 0., -diff.z));
                        },
                        else => {}
                    }
                }
            },

            Mode.Rotate => {
                var hit: ?vec3 = null;
                var nearest_distance: f32 = math.f32_max;

                if (self.state != State.Dragging) {
                    intersect_circle(self, ray, GizmoItem.RotateX, vec3.right(), &nearest_distance, &hit);
                    intersect_circle(self, ray, GizmoItem.RotateY, vec3.up(), &nearest_distance, &hit);
                    intersect_circle(self, ray, GizmoItem.RotateZ, vec3.forward(), &nearest_distance, &hit);

                    if (hit != null) {
                        self.original_transform.rotation = quat.from_mat4(target);
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

                    const arm = vec3.sub(self.position, p).norm();

                    if (self.started_arm == null) {
                        self.started_arm = arm;
                    }

                    self.ended_arm = arm;

                    // Now, we want to get the angle in degrees of those arms.
                    const dot_product = math.min(1, vec3.dot(self.ended_arm.?, self.started_arm.?));
                    // The `acos` of a dot product will gives us the angle between two vectors, in radians.
                    // We just have to convert it to degrees.
                    const angle = to_degrees(math.acos(dot_product));

                    // If angle is less than 1 degree, we don't want to do anything.
                    if (angle < 1) {
                        return null;
                    }

                    // if (self.config.snap) |snap| {
                    //     // const a = self.started_arm.?
                    //     // const b = normalize(to);
                    //     const snap_acos = math.floor(f32, math.acos(dot(a, b)) / angle) * angle;
                    //     return make_rotation_quat_axis_angle(normalize(cross(a, b)), snappedAcos);
                    // }

                    const cross_product = vec3.cross(self.started_arm.?, self.ended_arm.?).norm();
                    const new_rot = quat.from_axis(angle, cross_product);
                    const rotation = quat.mult(new_rot, self.original_transform.rotation);

                    result = .{ .rotation = rotation };
                }
            },
            else => {},
        }

        return result;
    }

    /// Collision between ray and axis-aligned bounding box.
    /// If hit happen, return the distance between the origin and the hit.
    fn ray_vs_aabb(min: vec3, max: vec3, r: Ray) ?f32 {
        var tmin = -math.inf_f32;
        var tmax = math.inf_f32;

        var i: i32 = 0;
        while (i < 3) : (i += 1) {
            if (r.dir.at(i) != 0) {
                const t1 = (min.at(i) - r.origin.at(i))/r.dir.at(i);
                const t2 = (max.at(i) - r.origin.at(i))/r.dir.at(i);

                tmin = math.max(tmin, math.min(t1, t2));
                tmax = math.min(tmax, math.max(t1, t2));
            } else if (r.origin.at(i) < min.at(i) or r.origin.at(i) > max.at(i)) {
                return null;
            }
        }

        if (tmax >= tmin and tmax >= 0.0) {
            return tmin;
        } 

        return null;
    }

    fn ray_vs_plane(normal: vec3, plane_pos: vec3, ray: Ray) ?f32 {
        var intersection: f32 = undefined;
        const denom: f32 = vec3.dot(normal, ray.dir);

        if (math.absFloat(denom) > 1e-6) {
            const line = vec3.sub(plane_pos, ray.origin);
            intersection = vec3.dot(line, normal) / denom;

            return if (intersection > 0) intersection else null;
        }


        return null;
    }

    fn ray_vs_disk(normal: vec3, disk_pos: vec3, ray: Ray, radius: f32) ?f32 {
        if (ray_vs_plane(normal, disk_pos, ray)) |intersection| {
            const p = vec3.add(ray.origin, vec3.scale(ray.dir, intersection));
            const v = vec3.sub(p, disk_pos);
            const d2 = vec3.dot(v, v);

            return if (math.sqrt(d2) <= radius) intersection else null;
        }

        return null;
    }

    fn intersect_cuboid(self: *Self, ray: Ray, bb: *const BoundingBox, selected_object: GizmoItem, axis: vec3, near_dist: *f32, near_hit: *?vec3) void {
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

    fn intersect_circle(self: *Self, ray: Ray, selected_object: GizmoItem, axis: vec3, near_dist: *f32, near_hit: *?vec3) void {
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
    fn raycast(pos: vec3, cam: Camera, config: Config, cursor: Cursor) Ray {
        const clip_ndc = vec2.new(
            (@floatCast(f32, cursor.x) * @intToFloat(f32, config.dpi)) / @intToFloat(f32, config.screen_width) - 1., 
            1. - (@floatCast(f32, cursor.y) * @intToFloat(f32, config.dpi)) / @intToFloat(f32, config.screen_height)
        );

        const clip_space = vec4.new(clip_ndc.x, clip_ndc.y, -1., 1.);
        const eye_tmp = mat4.mult_by_vec4(mat4.inv(cam.proj), clip_space);
        const world_tmp = mat4.mult_by_vec4(mat4.inv(cam.view), vec4.new(eye_tmp.x, eye_tmp.y, -1, 0.));

        return .{
            .origin = pos,
            .dir = vec3.new(world_tmp.x, world_tmp.y, world_tmp.z).norm(),
        };
    }

    /// Construct cuboid from given bounds.
    /// Used to construct cubes, axis and planes.
    fn construct_cuboid(min_bounds: vec3, max_bounds: vec3) [72]f32 {
        const a = min_bounds;
        const b = max_bounds;

        return .{
          a.x, a.y, a.z , a.x, a.y, b.z, 
          a.x, b.y, b.z , a.x, b.y, a.z, 
          b.x, a.y, a.z , b.x, b.y, a.z, 
          b.x, b.y, b.z , b.x, a.y, b.z, 
          a.x, a.y, a.z , b.x, a.y, a.z, 
          b.x, a.y, b.z , a.x, a.y, b.z, 
          a.x, b.y, a.z , a.x, b.y, b.z, 
          b.x, b.y, b.z , b.x, b.y, a.z, 
          a.x, a.y, a.z , a.x, b.y, a.z, 
          b.x, b.y, a.z , b.x, a.y, a.z, 
          a.x, a.y, b.z , b.x, a.y, b.z, 
          b.x, b.y, b.z , a.x, b.y, b.z, 
      };

    }

    /// Make gizmo planes (YZ, XZ, XY).
    fn make_move_panels(panel_size: f32, panel_offset: f32, panel_width: f32) MeshPanels {
        var mesh: MeshPanels = undefined;

        const max = panel_offset + panel_size;

        mesh.yz = construct_cuboid(vec3.new(0, panel_offset, -panel_offset), vec3.new(panel_width, max, -max));
        mesh.xz = construct_cuboid(vec3.new(panel_offset, 0, -panel_offset), vec3.new(max, panel_width, -max));
        mesh.xy = construct_cuboid(vec3.new(panel_offset, panel_offset, 0), vec3.new(max, max, panel_width));
        mesh.indices = CUBOID_INDICES;

        return mesh;
    }

    /// Make gizmo axis as cuboid. (X, Y, Z).
    fn make_move_axis(size: f32, length: f32) MeshAxis {
        var mesh: MeshAxis = undefined;

        mesh.x = construct_cuboid(vec3.new(0, 0, 0), vec3.new(length, size, size));
        mesh.y = construct_cuboid(vec3.new(0, 0, 0), vec3.new(size, length, size));
        mesh.z = construct_cuboid(vec3.new(0, 0, 0), vec3.new(size, size, -length));

        mesh.indices = CUBOID_INDICES;

        return mesh;
    }

    /// Make gizmo scale axis (with orthogonal cuboid at the end).
    /// TODO: I think we could a lot better here...
    fn make_scale_axis(size: f32, length: f32, box_size: f32) MeshScaleAxis {
        var mesh: MeshScaleAxis = undefined;

        const half_size = size * 0.5;
        const total_size = length + box_size * 2;

        const x_axis = construct_cuboid(vec3.new(0, 0, 0), vec3.new(length, size, size));
        const x_box = construct_cuboid(vec3.new(length, -box_size + half_size, -box_size + half_size), vec3.new(total_size, box_size + half_size, box_size + half_size));
        std.mem.copy(f32, &mesh.x, x_axis[0..]);
        std.mem.copy(f32, mesh.x[72..], x_box[0..]);

        const y_axis = construct_cuboid(vec3.new(0, 0, 0), vec3.new(size, length, size));
        const y_box = construct_cuboid(vec3.new(-box_size + half_size, length, -box_size + half_size), vec3.new(box_size + half_size, total_size, box_size + half_size));
        std.mem.copy(f32, &mesh.y, y_axis[0..]);
        std.mem.copy(f32, mesh.y[72..], y_box[0..]);

        const z_axis = construct_cuboid(vec3.new(0, 0, 0), vec3.new(size, size, -length));
        const z_box = construct_cuboid(vec3.new(-box_size + half_size, -box_size + half_size, -length), vec3.new(box_size + half_size, box_size + half_size, -total_size));
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
        var segment_vertex: [segments]vec3 = undefined;

        while (deg < max_deg) : (deg += @divExact(max_deg, segments)) {
            const angle = to_radians(@intToFloat(f32, deg));
            const x = math.cos(angle) * radius;
            const y = math.sin(angle) * radius;

            segment_vertex[i] = switch (axis) {
                GizmoItem.RotateX => vec3.new(x, y, 0),
                GizmoItem.RotateY => vec3.new(0, y, x),
                GizmoItem.RotateZ => vec3.new(x, 0, y),
                else => std.debug.panic("Object selected isn't a rotate axis.\n", .{})
            };

            i += 1;
        }

        var j: usize = 0;
        var k: usize = 0;
        while (j < segment_vertex.len) : (j += 1) {
            const pp = if (j == 0) segment_vertex[segment_vertex.len - 1] else segment_vertex[j - 1];
            const p0 = segment_vertex[j];
            const p1 = if (j == segment_vertex.len - 1) segment_vertex[0] else segment_vertex[j + 1];
            const p2 = if (j == segment_vertex.len - 2) segment_vertex[0] else if (j == segment_vertex.len - 1) segment_vertex[1] else segment_vertex[j + 2];

            for (create_segment(p0, p1, p2, pp, thickness, axis)) |v, idx| {
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
    fn create_segment(p0: vec3, p1: vec3, p2: vec3, pp: vec3, thickness: f32, axis: GizmoItem) [18]f32 {
        // Compute middle line.
        const line = vec3.sub(p1, p0);
        var normal: vec3 = undefined;

        // Compute tangeants.
        const t0 = vec3.add(vec3.sub(p0, pp).norm(), vec3.sub(p1, p0).norm()).norm();
        const t1 = vec3.add(vec3.sub(p2, p1).norm(), vec3.sub(p1, p0).norm()).norm();

        var miter0: vec3 = undefined;
        var miter1: vec3 = undefined;

        switch (axis) {
            GizmoItem.RotateX => {
                normal = vec3.new(-line.y, line.x, 0).norm();
                miter0 = vec3.new(-t0.y, t0.x, 0);
                miter1 = vec3.new(-t1.y, t1.x, 0);

            },
            GizmoItem.RotateY => {
                normal = vec3.new(0, -line.z, line.y).norm();
                miter0 = vec3.new(0, -t0.z, t0.y);
                miter1 = vec3.new(0, -t1.z, t1.y);

            },
            GizmoItem.RotateZ => {
                normal = vec3.new(-line.z, 0, line.x).norm();
                miter0 = vec3.new(-t0.z, 0, t0.x);
                miter1 = vec3.new(-t1.z, 0, t1.x);

            },
            else => std.debug.panic("Object selected isn't a rotate axis.\n", .{})
        }

        const length0 = thickness / vec3.dot(miter0, normal);
        const length1 = thickness / vec3.dot(miter1, normal);

        const a = vec3.add(p0, vec3.scale(miter0, length0));
        const b = vec3.add(p1, vec3.scale(miter1, length1));
        const e = vec3.sub(p0, vec3.scale(miter0, length0));
        const d = vec3.sub(p1, vec3.scale(miter1, length1));

        return .{
            a.x, a.y, a.z,
            b.x, b.y, b.z,
            e.x, e.y, e.z,

            b.x, b.y, b.z,
            d.x, d.y, d.z,
            e.x, e.y, e.z,
        };
    }
};
