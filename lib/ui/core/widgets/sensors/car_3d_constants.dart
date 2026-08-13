/// Shared tuning constants for the MEVI 3D car visualization.
///
/// There are two separate renderers behind [Car3DViewerWidget]:
///   * `car_3d_viewer_web_mobile.dart` — model_viewer_plus (GLB), used on
///     Web / Android / iOS, the only platforms it actually supports.
///   * `car_3d_viewer_desktop.dart` — flutter_cube (OBJ), used on
///     Windows / Linux / macOS, where model_viewer_plus cannot run.
///
/// Both need to know which way is "forward" for the model, so that value
/// lives here once instead of being duplicated (and drifting) in two files.
class Car3DConstants {
  Car3DConstants._();

  /// Extra yaw, in degrees, applied on top of the live steering angle so
  /// the car's nose points "up" (forward / into the road) inside the
  /// widget — matching the perspective drawn by FrontBevWidget underneath
  /// it, instead of facing sideways or backwards.
  ///
  /// 180 is a starting guess, not a measurement — the .glb and the .obj
  /// are two different exports of the same physical model and may not
  /// agree on which way "0 rotation" faces, and this project's sandbox
  /// has no way to actually render either file to check. Run the app,
  /// look at the car, and if it's not pointing up, nudge this value in
  /// 90° steps (0 / 90 / 180 / 270) until it is — no other code needs to
  /// change.
  ///
  /// If the GLB (web/mobile) and OBJ (desktop) end up needing *different*
  /// offsets, split this into `glbForwardYawOffsetDeg` and
  /// `objForwardYawOffsetDeg` and update each viewer file to use its own.
  static const double forwardYawOffsetDeg = 180;
}
