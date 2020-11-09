# Mogwai

Graphic utility used to manipulate objects in 3D for scene editing (commonly called Gizmo).

If you would like to contribute, don't hesitate! ;)

<img src="https://github.com/kooparse/mogwai/blob/master/.github/mogwai.png" alt="preview" />

## Examples

```zig
usingnamespace @import("mogwai");

pub fn main () void {
  var gizmo = Mogwai(.{
    .screen_width   = 800,
    .screen_height  = 600,
    .snap_axis = 0.5,
    .snap_angle = 5 
  });

  // Get all vertices for your renderer.
  const xy_panel = gizmo.meshes.move_panels.xy;
  const yz_panel = gizmo.meshes.move_panels.yz

  // Mode is an enum containing all different modes
  // for the gizmo (move, rotate, scale, none).
  var gizmo_mode = Mode.Move;

  while(true) {
    // After pulling cursor state and positions:
    gizmo.set_cursor(pos_x, pos_y, is_pressed);
    // After updating the view matrix (camera moving...).
    gizmo.set_camera(view, proj);

    // You just have to pass a mode and the model matrix from the
    // selected object from your scene.
    if (gizmo.manipulate(target_model_matrix, gizmo_mode)) |result| {
        switch (result.mode) {
            Mode.Move => {
                target.transform.position = result.position;
            },
            Mode.Rotate => {
                target.transform.rotation = result.rotation.extract_rotation();
            },
            Mode.Scale => {
                target.transform.scale = result.scale;
            },
            else => {},
        }
    }

    // Draw all the meshes
    your_renderer.draw(&yz_panel, gizmo.is_hover(GizmoItem.PanelYZ));
  }
}
```

## Documentation

### Config

Field | Type | Description
------------ | ------------- | -------------
screen_width | i32 | Width of the screen (required)
screen_height | i32 | Height of the screen (required)
dpi | i32 | Pixel ratio of your monitor
snap | ?f32 | Snap when dragging gizmo, value is equals to floor factor
arcball_radius | f32 | Radius of the rotation circles
arcball_thickness | f32 | Width of the rotation circle borders
panel_size| f32 | The width/height of panels
panel_offset| f32 | Offset of the panels from the origin position
panel_width| f32 | Plans width for panels
axis_length | f32 | Length of arrows
axis_size | f32 | The width/height of arrows
scale_box_size | f32 | Size of the scaler boxes


## Contributing to the project

Don’t be shy about shooting any questions you may have. If you are a beginner/junior, don’t hesitate, I will always encourage you. It’s a safe place here. Also, I would be very happy to receive any kind of pull requests, you will have (at least) some feedback/guidance rapidly.

Behind screens, there are human beings, living any sort of story. So be always kind and respectful, because we all sheer to learn new things.


## Thanks
This project is inspired by [tinygizmo](https://github.com/ddiakopoulos/tinygizmo) and [ImGuizmo](https://github.com/CedricGuillemet/ImGuizmo).

