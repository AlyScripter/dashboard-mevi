import 'dart:convert';
import 'dart:typed_data';

/// Immutable frame data decoded from `/bev/camcloud` (`std_msgs/String` JSON).
///
/// Contract v1:
/// ```json
/// {"sv":1,"i":idx,"t":t,"n":count,"fmt":"xyz16_rgb8_cls8","u":0.01,"p":"<base64>"}
/// ```
/// Binary layout in `p`: `n * 10` bytes, little-endian per point:
/// - `x, y, z`: `int16` scaled by `u` (meters in LiDAR frame: +x forward, +y left, +z up)
/// - `r, g, b`: `uint8`
/// - `cls`: `uint8` (`0`: other, `1`: road, `4`: Vehicle, `5`: Person)
class CamCloudFrame {
  static const int supportedSchemaVersion = 1;
  static const String expectedFormat = 'xyz16_rgb8_cls8';
  static const int recordBytes = 10;

  final int idx;
  final double timestamp;
  final int count;
  final double unit;

  /// Interleaved `[x0, y0, z0, x1, y1, z1, ...]` in meters (length `count * 3`).
  final Float32List xyz;

  /// Packed ARGB `0xFF000000 | (r << 16) | (g << 8) | b` (length `count`).
  final Uint32List rgbArgb;

  /// Per-point semantic class ID (length `count`).
  final Uint8List classes;

  const CamCloudFrame({
    required this.idx,
    required this.timestamp,
    required this.count,
    required this.unit,
    required this.xyz,
    required this.rgbArgb,
    required this.classes,
  });

  /// Parses and validates a `/bev/camcloud` JSON object. Returns `null` if invalid.
  static CamCloudFrame? tryParse(Map<String, dynamic> json) {
    final sv = json['sv'];
    final fmt = json['fmt'];
    if (sv != supportedSchemaVersion || fmt != expectedFormat) {
      return null;
    }

    final idxRaw = json['i'];
    final tRaw = json['t'];
    final nRaw = json['n'];
    final uRaw = json['u'];
    final pRaw = json['p'];

    if (idxRaw is! num ||
        tRaw is! num ||
        nRaw is! int ||
        uRaw is! num ||
        pRaw is! String) {
      return null;
    }

    final count = nRaw;
    final unit = uRaw.toDouble();
    final timestamp = tRaw.toDouble();
    if (count < 0 || !unit.isFinite || unit <= 0 || !timestamp.isFinite) {
      return null;
    }

    final Uint8List bytes;
    try {
      bytes = base64Decode(pRaw);
    } on FormatException {
      return null;
    }

    if (bytes.length != count * recordBytes) {
      return null;
    }

    final xyz = Float32List(count * 3);
    final rgbArgb = Uint32List(count);
    final classes = Uint8List(count);
    final bd = ByteData.sublistView(bytes);

    for (int k = 0; k < count; k++) {
      final off = k * recordBytes;
      final xyzBase = k * 3;
      xyz[xyzBase] = bd.getInt16(off, Endian.little) * unit;
      xyz[xyzBase + 1] = bd.getInt16(off + 2, Endian.little) * unit;
      xyz[xyzBase + 2] = bd.getInt16(off + 4, Endian.little) * unit;

      final r = bytes[off + 6];
      final g = bytes[off + 7];
      final b = bytes[off + 8];
      rgbArgb[k] = 0xFF000000 | (r << 16) | (g << 8) | b;
      classes[k] = bytes[off + 9];
    }

    return CamCloudFrame(
      idx: idxRaw.toInt(),
      timestamp: timestamp,
      count: count,
      unit: unit,
      xyz: xyz,
      rgbArgb: rgbArgb,
      classes: classes,
    );
  }
}

