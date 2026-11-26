import 'dart:convert';
import 'dart:typed_data';

import 'package:dashboardmevi/model/cam_cloud_frame.dart';
import 'package:flutter_test/flutter_test.dart';

String _encodePoints(List<({int x, int y, int z, int r, int g, int b, int cls})> pts) {
  final bytes = Uint8List(pts.length * 10);
  final bd = ByteData.sublistView(bytes);
  for (int i = 0; i < pts.length; i++) {
    final off = i * 10;
    final p = pts[i];
    bd.setInt16(off, p.x, Endian.little);
    bd.setInt16(off + 2, p.y, Endian.little);
    bd.setInt16(off + 4, p.z, Endian.little);
    bytes[off + 6] = p.r;
    bytes[off + 7] = p.g;
    bytes[off + 8] = p.b;
    bytes[off + 9] = p.cls;
  }
  return base64Encode(bytes);
}

void main() {
  group('CamCloudFrame.tryParse', () {
    test('decodes valid v1 binary payload (little-endian int16 * u, rgb, cls)', () {
      final p = _encodePoints([
        (x: 1050, y: -250, z: 120, r: 210, g: 220, b: 230, cls: 4),
        (x: 500, y: 0, z: -150, r: 40, g: 80, b: 180, cls: 1),
      ]);

      final frame = CamCloudFrame.tryParse({
        'sv': 1,
        'i': 42,
        't': 123.45,
        'n': 2,
        'fmt': 'xyz16_rgb8_cls8',
        'u': 0.01,
        'p': p,
      });

      expect(frame, isNotNull);
      expect(frame!.idx, 42);
      expect(frame.timestamp, closeTo(123.45, 1e-6));
      expect(frame.count, 2);
      expect(frame.unit, 0.01);

      // Point 0: (10.5, -2.5, 1.2), RGB (210, 220, 230), cls 4 (Vehicle)
      expect(frame.xyz[0], closeTo(10.50, 1e-4));
      expect(frame.xyz[1], closeTo(-2.50, 1e-4));
      expect(frame.xyz[2], closeTo(1.20, 1e-4));
      expect(frame.rgbArgb[0], 0xFFD2DCE6);
      expect(frame.classes[0], 4);

      // Point 1: (5.0, 0.0, -1.5), RGB (40, 80, 180), cls 1 (Road)
      expect(frame.xyz[3], closeTo(5.00, 1e-4));
      expect(frame.xyz[4], closeTo(0.00, 1e-4));
      expect(frame.xyz[5], closeTo(-1.50, 1e-4));
      expect(frame.rgbArgb[1], 0xFF2850B4);
      expect(frame.classes[1], 1);
    });

    test('accepts valid empty cloud (n == 0)', () {
      final frame = CamCloudFrame.tryParse({
        'sv': 1,
        'i': 0,
        't': 0.0,
        'n': 0,
        'fmt': 'xyz16_rgb8_cls8',
        'u': 0.01,
        'p': '',
      });

      expect(frame, isNotNull);
      expect(frame!.count, 0);
      expect(frame.xyz.length, 0);
    });

    test('rejects invalid schema version, format, byte length, or base64', () {
      final validP = _encodePoints([
        (x: 100, y: 100, z: 0, r: 255, g: 0, b: 0, cls: 5),
      ]);

      expect(
        CamCloudFrame.tryParse({
          'sv': 2,
          'i': 1,
          't': 1.0,
          'n': 1,
          'fmt': 'xyz16_rgb8_cls8',
          'u': 0.01,
          'p': validP,
        }),
        isNull,
      );

      expect(
        CamCloudFrame.tryParse({
          'sv': 1,
          'i': 1,
          't': 1.0,
          'n': 1,
          'fmt': 'xyz32',
          'u': 0.01,
          'p': validP,
        }),
        isNull,
      );

      // Mismatched count (n=2 while bytes only encode 1 point)
      expect(
        CamCloudFrame.tryParse({
          'sv': 1,
          'i': 1,
          't': 1.0,
          'n': 2,
          'fmt': 'xyz16_rgb8_cls8',
          'u': 0.01,
          'p': validP,
        }),
        isNull,
      );

      // Invalid base64
      expect(
        CamCloudFrame.tryParse({
          'sv': 1,
          'i': 1,
          't': 1.0,
          'n': 1,
          'fmt': 'xyz16_rgb8_cls8',
          'u': 0.01,
          'p': '!!!not-base64!!!',
        }),
        isNull,
      );
    });
  });
}

