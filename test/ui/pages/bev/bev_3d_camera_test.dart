import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dashboardmevi/ui/core/widgets/sensors/bev_3d_camera.dart';

void main() {
  group('Bev3DCamera Tests', () {
    test('Default camera parameters match elevated drone BEV specifications', () {
      const camera = Bev3DCamera();
      expect(camera.cameraHeight, 10.5);
      expect(camera.cameraDistance, -6.5);
      expect(camera.pitchDeg, 32.0);
      expect(camera.horizonFraction, 0.52);
    });

    test('Ego car at z=1.0 is in front of camera and fully visible', () {
      const camera = Bev3DCamera();
      const viewportSize = Size(1280, 720);

      final pCenter = camera.project(0.0, 0.0, 1.0, viewportSize);
      expect(pCenter.isVisible, isTrue);
      expect(pCenter.depth, greaterThan(0.2));
      // Posisi y harus berada di bagian bawah layar (di atas tombol skenario)
      expect(pCenter.screenOffset.dy, greaterThan(500.0));
      expect(pCenter.screenOffset.dy, lessThan(720.0));
      // Posisi x tepat di tengah layar
      expect(pCenter.screenOffset.dx, closeTo(640.0, 1.0));
    });

    test('1:1 scale ratio: Ego car width matches neighbor car width at same distance', () {
      const camera = Bev3DCamera();
      const viewportSize = Size(1280, 720);

      // Ego car lebar 1.90m di x=0, z=1.0
      final egoL = camera.project(-0.95, 0.0, 1.0, viewportSize);
      final egoR = camera.project(0.95, 0.0, 1.0, viewportSize);
      final egoWidth = (egoR.screenOffset.dx - egoL.screenOffset.dx).abs();

      // Side car lebar 1.90m di x=4.0, z=1.0
      final sideL = camera.project(3.05, 0.0, 1.0, viewportSize);
      final sideR = camera.project(4.95, 0.0, 1.0, viewportSize);
      final sideWidth = (sideR.screenOffset.dx - sideL.screenOffset.dx).abs();

      // Skala harus 1:1 identik
      expect(egoWidth, closeTo(sideWidth, 0.1));
    });

    test('Far road horizon point is visible at top horizon area', () {
      const camera = Bev3DCamera();
      const viewportSize = Size(1280, 720);

      final farPoint = camera.project(0.0, 0.0, 80.0, viewportSize);
      expect(farPoint.isVisible, isTrue);
      expect(farPoint.screenOffset.dy, lessThan(200.0));
      expect(farPoint.screenOffset.dy, greaterThan(50.0));
    });
  });
}
