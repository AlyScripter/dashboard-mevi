// GENERATED ADAS 3.0 STUDIO CLAY 3D MESH SERVICE -- ZERO LATENCY, 60 FPS
// Sesuai referensi resmi '3.0 ADAS 视觉识别模型' (Matte Clay Grey).
import 'dart:typed_data';
import '../ui/core/widgets/sensors/models/detected_3d_object.dart';

class AdasMeshFace {
  final List<int> indices;
  final double nx, ny, nz;
  final bool isGlass;
  final bool isWheel;
  final bool isLightAccent;

  const AdasMeshFace({
    required this.indices,
    required this.nx,
    required this.ny,
    required this.nz,
    this.isGlass = false,
    this.isWheel = false,
    this.isLightAccent = false,
  });
}

class AdasMeshData {
  final Float32List vertices; // [x, y, z, x, y, z, ...]
  final List<AdasMeshFace> faces;

  const AdasMeshData({
    required this.vertices,
    required this.faces,
  });
}

class AdasMeshService {
  AdasMeshService._();

  // ==========================================================================
  // CAR MESH DATA (216 vertices, 168 faces)
  // ==========================================================================
  static final Float32List _carVertices = Float32List.fromList([
    0.3400, 0.1800, 0.4600, 0.4400, 0.1800, 0.4600, 0.3400, 0.2700, 0.4359, 0.4400, 0.2700, 0.4359, 0.3400, 0.3359, 0.3700, 0.4400, 0.3359, 0.3700, 0.3400, 0.3600, 0.2800, 0.4400, 0.3600, 0.2800, 0.3400, 0.3359, 0.1900, 0.4400, 0.3359, 0.1900, 0.3400, 0.2700, 0.1241, 0.4400, 0.2700, 0.1241, 0.3400, 0.1800, 0.1000, 0.4400, 0.1800, 0.1000, 0.3400, 0.0900, 0.1241, 0.4400, 0.0900, 0.1241, 0.3400, 0.0241, 0.1900, 0.4400, 0.0241, 0.1900, 0.3400, 0.0000, 0.2800, 0.4400, 0.0000, 0.2800, 0.3400, 0.0241, 0.3700, 0.4400, 0.0241, 0.3700, 0.3400, 0.0900, 0.4359, 0.4400, 0.0900, 0.4359, -0.3400, 0.1800, 0.4600, -0.4400, 0.1800, 0.4600, -0.3400, 0.2700, 0.4359, -0.4400, 0.2700, 0.4359, -0.3400, 0.3359, 0.3700, -0.4400, 0.3359, 0.3700, -0.3400, 0.3600, 0.2800, -0.4400, 0.3600, 0.2800, -0.3400, 0.3359, 0.1900, -0.4400, 0.3359, 0.1900, -0.3400, 0.2700, 0.1241, -0.4400, 0.2700, 0.1241, -0.3400, 0.1800, 0.1000, -0.4400, 0.1800, 0.1000, -0.3400, 0.0900, 0.1241, -0.4400, 0.0900, 0.1241, -0.3400, 0.0241, 0.1900, -0.4400, 0.0241, 0.1900, -0.3400, 0.0000, 0.2800, -0.4400, 0.0000, 0.2800, -0.3400, 0.0241, 0.3700, -0.4400, 0.0241, 0.3700, -0.3400, 0.0900, 0.4359, -0.4400, 0.0900, 0.4359, 0.3400, 0.1800, -0.1000, 0.4400, 0.1800, -0.1000, 0.3400, 0.2700, -0.1241, 0.4400, 0.2700, -0.1241, 0.3400, 0.3359, -0.1900, 0.4400, 0.3359, -0.1900, 0.3400, 0.3600, -0.2800, 0.4400, 0.3600, -0.2800, 0.3400, 0.3359, -0.3700, 0.4400, 0.3359, -0.3700, 0.3400, 0.2700, -0.4359, 0.4400, 0.2700, -0.4359, 0.3400, 0.1800, -0.4600, 0.4400, 0.1800, -0.4600, 0.3400, 0.0900, -0.4359, 0.4400, 0.0900, -0.4359, 0.3400, 0.0241, -0.3700, 0.4400, 0.0241, -0.3700, 0.3400, 0.0000, -0.2800, 0.4400, 0.0000, -0.2800, 0.3400, 0.0241, -0.1900, 0.4400, 0.0241, -0.1900, 0.3400, 0.0900, -0.1241, 0.4400, 0.0900, -0.1241, -0.3400, 0.1800, -0.1000, -0.4400, 0.1800, -0.1000, -0.3400, 0.2700, -0.1241, -0.4400, 0.2700, -0.1241, -0.3400, 0.3359, -0.1900, -0.4400, 0.3359, -0.1900, -0.3400, 0.3600, -0.2800, -0.4400, 0.3600, -0.2800, -0.3400, 0.3359, -0.3700, -0.4400, 0.3359, -0.3700, -0.3400, 0.2700, -0.4359, -0.4400, 0.2700, -0.4359, -0.3400, 0.1800, -0.4600, -0.4400, 0.1800, -0.4600, -0.3400, 0.0900, -0.4359, -0.4400, 0.0900, -0.4359, -0.3400, 0.0241, -0.3700, -0.4400, 0.0241, -0.3700, -0.3400, 0.0000, -0.2800, -0.4400, 0.0000, -0.2800, -0.3400, 0.0241, -0.1900, -0.4400, 0.0241, -0.1900, -0.3400, 0.0900, -0.1241, -0.4400, 0.0900, -0.1241, 0.0000, 0.0600, 0.5000, 0.3600, 0.0600, 0.5000, 0.3500, 0.2200, 0.5000, -0.3500, 0.2200, 0.5000, -0.3600, 0.0600, 0.5000, 0.2450, 0.2400, 0.5000, 0.0000, 0.2500, 0.5000, -0.2450, 0.2400, 0.5000, 0.0000, 0.0800, 0.4700, 0.4300, 0.0800, 0.4700, 0.4200, 0.3400, 0.4700, -0.4200, 0.3400, 0.4700, -0.4300, 0.0800, 0.4700, 0.2940, 0.3600, 0.4700, 0.0000, 0.3700, 0.4700, -0.2940, 0.3600, 0.4700, 0.0000, 0.1200, 0.4200, 0.4600, 0.1200, 0.4200, 0.4500, 0.4400, 0.4200, -0.4500, 0.4400, 0.4200, -0.4600, 0.1200, 0.4200, 0.3150, 0.4600, 0.4200, 0.0000, 0.4700, 0.4200, -0.3150, 0.4600, 0.4200, 0.0000, 0.1800, 0.3400, 0.4700, 0.1800, 0.3400, 0.4600, 0.4800, 0.3400, -0.4600, 0.4800, 0.3400, -0.4700, 0.1800, 0.3400, 0.3220, 0.5000, 0.3400, 0.0000, 0.5100, 0.3400, -0.3220, 0.5000, 0.3400, 0.0000, 0.1600, 0.2400, 0.4700, 0.1600, 0.2400, 0.4600, 0.5100, 0.2400, -0.4600, 0.5100, 0.2400, -0.4700, 0.1600, 0.2400, 0.3220, 0.5300, 0.2400, 0.0000, 0.5400, 0.2400, -0.3220, 0.5300, 0.2400, 0.0000, 0.1400, 0.1400, 0.4700, 0.1400, 0.1400, 0.4600, 0.5300, 0.1400, -0.4600, 0.5300, 0.1400, -0.4700, 0.1400, 0.1400, 0.3220, 0.5500, 0.1400, 0.0000, 0.5600, 0.1400, -0.3220, 0.5500, 0.1400, 0.0000, 0.1400, 0.0400, 0.4700, 0.1400, 0.0400, 0.4600, 0.5400, 0.0400, -0.4600, 0.5400, 0.0400, -0.4700, 0.1400, 0.0400, 0.3600, 0.8200, 0.0400, 0.0000, 0.8350, 0.0400, -0.3600, 0.8200, 0.0400, 0.0000, 0.1400, -0.0600, 0.4700, 0.1400, -0.0600, 0.4600, 0.5400, -0.0600, -0.4600, 0.5400, -0.0600, -0.4700, 0.1400, -0.0600, 0.3500, 0.9400, -0.0600, 0.0000, 0.9550, -0.0600, -0.3500, 0.9400, -0.0600, 0.0000, 0.1400, -0.1600, 0.4700, 0.1400, -0.1600, 0.4600, 0.5400, -0.1600, -0.4600, 0.5400, -0.1600, -0.4700, 0.1400, -0.1600, 0.3500, 0.9600, -0.1600, 0.0000, 0.9750, -0.1600, -0.3500, 0.9600, -0.1600, 0.0000, 0.1600, -0.2400, 0.4700, 0.1600, -0.2400, 0.4600, 0.5300, -0.2400, -0.4600, 0.5300, -0.2400, -0.4700, 0.1600, -0.2400, 0.3400, 0.9200, -0.2400, 0.0000, 0.9350, -0.2400, -0.3400, 0.9200, -0.2400, 0.0000, 0.1800, -0.3200, 0.4700, 0.1800, -0.3200, 0.4600, 0.5200, -0.3200, -0.4600, 0.5200, -0.3200, -0.4700, 0.1800, -0.3200, 0.3500, 0.7200, -0.3200, 0.0000, 0.7350, -0.3200, -0.3500, 0.7200, -0.3200, 0.0000, 0.1800, -0.3800, 0.4700, 0.1800, -0.3800, 0.4600, 0.5100, -0.3800, -0.4600, 0.5100, -0.3800, -0.4700, 0.1800, -0.3800, 0.3220, 0.5300, -0.3800, 0.0000, 0.5400, -0.3800, -0.3220, 0.5300, -0.3800, 0.0000, 0.1600, -0.4400, 0.4500, 0.1600, -0.4400, 0.4400, 0.4900, -0.4400, -0.4400, 0.4900, -0.4400, -0.4500, 0.1600, -0.4400, 0.3080, 0.5100, -0.4400, 0.0000, 0.5200, -0.4400, -0.3080, 0.5100, -0.4400, 0.0000, 0.1200, -0.4800, 0.4200, 0.1200, -0.4800, 0.4100, 0.4200, -0.4800, -0.4100, 0.4200, -0.4800, -0.4200, 0.1200, -0.4800, 0.2870, 0.4400, -0.4800, 0.0000, 0.4500, -0.4800, -0.2870, 0.4400, -0.4800, 0.0000, 0.0800, -0.5000, 0.3600, 0.0800, -0.5000, 0.3500, 0.2800, -0.5000, -0.3500, 0.2800, -0.5000, -0.3600, 0.0800, -0.5000, 0.2450, 0.3000, -0.5000, 0.0000, 0.3100, -0.5000, -0.2450, 0.3000, -0.5000
  ]);

  static final List<AdasMeshFace> _carFaces = [
    AdasMeshFace(indices: [1, 3, 5, 7, 9, 11, 13, 15, 17, 19, 21, 23], nx: -1.000, ny: 0.000, nz: 0.000, isWheel: true),
    AdasMeshFace(indices: [1, 3, 2, 0], nx: 0.000, ny: 0.259, nz: 0.966, isWheel: true),
    AdasMeshFace(indices: [3, 5, 4, 2], nx: 0.000, ny: 0.707, nz: 0.707, isWheel: true),
    AdasMeshFace(indices: [5, 7, 6, 4], nx: 0.000, ny: 0.966, nz: 0.259, isWheel: true),
    AdasMeshFace(indices: [7, 9, 8, 6], nx: 0.000, ny: 0.966, nz: -0.259, isWheel: true),
    AdasMeshFace(indices: [9, 11, 10, 8], nx: 0.000, ny: 0.707, nz: -0.707, isWheel: true),
    AdasMeshFace(indices: [11, 13, 12, 10], nx: 0.000, ny: 0.259, nz: -0.966, isWheel: true),
    AdasMeshFace(indices: [13, 15, 14, 12], nx: 0.000, ny: -0.259, nz: -0.966, isWheel: true),
    AdasMeshFace(indices: [15, 17, 16, 14], nx: 0.000, ny: -0.707, nz: -0.707, isWheel: true),
    AdasMeshFace(indices: [17, 19, 18, 16], nx: 0.000, ny: -0.966, nz: -0.259, isWheel: true),
    AdasMeshFace(indices: [19, 21, 20, 18], nx: 0.000, ny: -0.966, nz: 0.259, isWheel: true),
    AdasMeshFace(indices: [21, 23, 22, 20], nx: 0.000, ny: -0.707, nz: 0.707, isWheel: true),
    AdasMeshFace(indices: [23, 1, 0, 22], nx: 0.000, ny: -0.259, nz: 0.966, isWheel: true),
    AdasMeshFace(indices: [47, 45, 43, 41, 39, 37, 35, 33, 31, 29, 27, 25], nx: 1.000, ny: 0.000, nz: 0.000, isWheel: true),
    AdasMeshFace(indices: [27, 25, 24, 26], nx: 0.000, ny: 0.259, nz: 0.966, isWheel: true),
    AdasMeshFace(indices: [29, 27, 26, 28], nx: 0.000, ny: 0.707, nz: 0.707, isWheel: true),
    AdasMeshFace(indices: [31, 29, 28, 30], nx: 0.000, ny: 0.966, nz: 0.259, isWheel: true),
    AdasMeshFace(indices: [33, 31, 30, 32], nx: 0.000, ny: 0.966, nz: -0.259, isWheel: true),
    AdasMeshFace(indices: [35, 33, 32, 34], nx: 0.000, ny: 0.707, nz: -0.707, isWheel: true),
    AdasMeshFace(indices: [37, 35, 34, 36], nx: 0.000, ny: 0.259, nz: -0.966, isWheel: true),
    AdasMeshFace(indices: [39, 37, 36, 38], nx: 0.000, ny: -0.259, nz: -0.966, isWheel: true),
    AdasMeshFace(indices: [41, 39, 38, 40], nx: 0.000, ny: -0.707, nz: -0.707, isWheel: true),
    AdasMeshFace(indices: [43, 41, 40, 42], nx: 0.000, ny: -0.966, nz: -0.259, isWheel: true),
    AdasMeshFace(indices: [45, 43, 42, 44], nx: 0.000, ny: -0.966, nz: 0.259, isWheel: true),
    AdasMeshFace(indices: [47, 45, 44, 46], nx: 0.000, ny: -0.707, nz: 0.707, isWheel: true),
    AdasMeshFace(indices: [25, 47, 46, 24], nx: 0.000, ny: -0.259, nz: 0.966, isWheel: true),
    AdasMeshFace(indices: [49, 51, 53, 55, 57, 59, 61, 63, 65, 67, 69, 71], nx: -1.000, ny: 0.000, nz: 0.000, isWheel: true),
    AdasMeshFace(indices: [49, 51, 50, 48], nx: 0.000, ny: 0.259, nz: 0.966, isWheel: true),
    AdasMeshFace(indices: [51, 53, 52, 50], nx: 0.000, ny: 0.707, nz: 0.707, isWheel: true),
    AdasMeshFace(indices: [53, 55, 54, 52], nx: 0.000, ny: 0.966, nz: 0.259, isWheel: true),
    AdasMeshFace(indices: [55, 57, 56, 54], nx: 0.000, ny: 0.966, nz: -0.259, isWheel: true),
    AdasMeshFace(indices: [57, 59, 58, 56], nx: 0.000, ny: 0.707, nz: -0.707, isWheel: true),
    AdasMeshFace(indices: [59, 61, 60, 58], nx: 0.000, ny: 0.259, nz: -0.966, isWheel: true),
    AdasMeshFace(indices: [61, 63, 62, 60], nx: 0.000, ny: -0.259, nz: -0.966, isWheel: true),
    AdasMeshFace(indices: [63, 65, 64, 62], nx: 0.000, ny: -0.707, nz: -0.707, isWheel: true),
    AdasMeshFace(indices: [65, 67, 66, 64], nx: 0.000, ny: -0.966, nz: -0.259, isWheel: true),
    AdasMeshFace(indices: [67, 69, 68, 66], nx: 0.000, ny: -0.966, nz: 0.259, isWheel: true),
    AdasMeshFace(indices: [69, 71, 70, 68], nx: 0.000, ny: -0.707, nz: 0.707, isWheel: true),
    AdasMeshFace(indices: [71, 49, 48, 70], nx: 0.000, ny: -0.259, nz: 0.966, isWheel: true),
    AdasMeshFace(indices: [95, 93, 91, 89, 87, 85, 83, 81, 79, 77, 75, 73], nx: 1.000, ny: 0.000, nz: 0.000, isWheel: true),
    AdasMeshFace(indices: [75, 73, 72, 74], nx: 0.000, ny: 0.259, nz: 0.966, isWheel: true),
    AdasMeshFace(indices: [77, 75, 74, 76], nx: 0.000, ny: 0.707, nz: 0.707, isWheel: true),
    AdasMeshFace(indices: [79, 77, 76, 78], nx: 0.000, ny: 0.966, nz: 0.259, isWheel: true),
    AdasMeshFace(indices: [81, 79, 78, 80], nx: 0.000, ny: 0.966, nz: -0.259, isWheel: true),
    AdasMeshFace(indices: [83, 81, 80, 82], nx: 0.000, ny: 0.707, nz: -0.707, isWheel: true),
    AdasMeshFace(indices: [85, 83, 82, 84], nx: 0.000, ny: 0.259, nz: -0.966, isWheel: true),
    AdasMeshFace(indices: [87, 85, 84, 86], nx: 0.000, ny: -0.259, nz: -0.966, isWheel: true),
    AdasMeshFace(indices: [89, 87, 86, 88], nx: 0.000, ny: -0.707, nz: -0.707, isWheel: true),
    AdasMeshFace(indices: [91, 89, 88, 90], nx: 0.000, ny: -0.966, nz: -0.259, isWheel: true),
    AdasMeshFace(indices: [93, 91, 90, 92], nx: 0.000, ny: -0.966, nz: 0.259, isWheel: true),
    AdasMeshFace(indices: [95, 93, 92, 94], nx: 0.000, ny: -0.707, nz: 0.707, isWheel: true),
    AdasMeshFace(indices: [73, 95, 94, 72], nx: 0.000, ny: -0.259, nz: 0.966, isWheel: true),
    AdasMeshFace(indices: [96, 104, 105, 97], nx: 0.000, ny: -0.832, nz: -0.555),
    AdasMeshFace(indices: [96, 100, 108, 104], nx: -0.000, ny: -0.832, nz: -0.555),
    AdasMeshFace(indices: [97, 105, 106, 98], nx: 0.390, ny: 0.015, nz: 0.921),
    AdasMeshFace(indices: [100, 99, 107, 108], nx: -0.361, ny: 0.023, nz: 0.932),
    AdasMeshFace(indices: [98, 106, 109, 101], nx: 0.035, ny: 0.223, nz: 0.974),
    AdasMeshFace(indices: [99, 103, 111, 107], nx: -0.043, ny: 0.226, nz: 0.973),
    AdasMeshFace(indices: [101, 109, 110, 102], nx: 0.008, ny: 0.239, nz: 0.971),
    AdasMeshFace(indices: [102, 110, 111, 103], nx: -0.008, ny: 0.243, nz: 0.970),
    AdasMeshFace(indices: [104, 112, 113, 105], nx: 0.000, ny: -0.781, nz: -0.625),
    AdasMeshFace(indices: [104, 108, 116, 112], nx: -0.000, ny: -0.781, nz: -0.625),
    AdasMeshFace(indices: [105, 113, 114, 106], nx: 0.848, ny: 0.026, nz: 0.530),
    AdasMeshFace(indices: [108, 107, 115, 116], nx: -0.828, ny: 0.032, nz: 0.560),
    AdasMeshFace(indices: [106, 114, 117, 109], nx: 0.064, ny: 0.431, nz: 0.900),
    AdasMeshFace(indices: [107, 111, 119, 115], nx: -0.069, ny: 0.435, nz: 0.898),
    AdasMeshFace(indices: [109, 117, 118, 110], nx: 0.014, ny: 0.445, nz: 0.896),
    AdasMeshFace(indices: [110, 118, 119, 111], nx: -0.014, ny: 0.447, nz: 0.894),
    AdasMeshFace(indices: [112, 120, 121, 113], nx: 0.000, ny: -0.800, nz: -0.600),
    AdasMeshFace(indices: [112, 116, 124, 120], nx: -0.000, ny: -0.800, nz: -0.600),
    AdasMeshFace(indices: [113, 121, 122, 114], nx: 0.988, ny: 0.033, nz: 0.148),
    AdasMeshFace(indices: [116, 115, 123, 124], nx: -0.990, ny: 0.031, nz: 0.139),
    AdasMeshFace(indices: [114, 122, 125, 117], nx: 0.128, ny: 0.881, nz: 0.456),
    AdasMeshFace(indices: [115, 119, 127, 123], nx: -0.131, ny: 0.882, nz: 0.453),
    AdasMeshFace(indices: [117, 125, 126, 118], nx: 0.028, ny: 0.893, nz: 0.449),
    AdasMeshFace(indices: [118, 126, 127, 119], nx: -0.028, ny: 0.894, nz: 0.447),
    AdasMeshFace(indices: [120, 128, 129, 121], nx: 0.000, ny: -0.981, nz: 0.196),
    AdasMeshFace(indices: [120, 124, 132, 128], nx: 0.000, ny: -0.981, nz: 0.196),
    AdasMeshFace(indices: [121, 129, 130, 122], nx: 1.000, ny: 0.029, nz: -0.006),
    AdasMeshFace(indices: [124, 123, 131, 132], nx: -0.999, ny: 0.033, nz: 0.010),
    AdasMeshFace(indices: [122, 130, 133, 125], nx: 0.137, ny: 0.949, nz: 0.285),
    AdasMeshFace(indices: [123, 127, 135, 131], nx: -0.137, ny: 0.949, nz: 0.285),
    AdasMeshFace(indices: [125, 133, 134, 126], nx: 0.030, ny: 0.957, nz: 0.287),
    AdasMeshFace(indices: [126, 134, 135, 127], nx: -0.030, ny: 0.957, nz: 0.287),
    AdasMeshFace(indices: [128, 136, 137, 129], nx: 0.000, ny: -0.981, nz: 0.196),
    AdasMeshFace(indices: [128, 132, 140, 136], nx: 0.000, ny: -0.981, nz: 0.196),
    AdasMeshFace(indices: [129, 137, 138, 130], nx: 1.000, ny: 0.026, nz: -0.005),
    AdasMeshFace(indices: [132, 131, 139, 140], nx: -1.000, ny: 0.029, nz: 0.006),
    AdasMeshFace(indices: [130, 138, 141, 133], nx: 0.141, ny: 0.971, nz: 0.194),
    AdasMeshFace(indices: [131, 135, 143, 139], nx: -0.141, ny: 0.971, nz: 0.194),
    AdasMeshFace(indices: [133, 141, 142, 134], nx: 0.030, ny: 0.980, nz: 0.196),
    AdasMeshFace(indices: [134, 142, 143, 135], nx: -0.030, ny: 0.980, nz: 0.196),
    AdasMeshFace(indices: [136, 144, 145, 137], nx: 0.000, ny: -1.000, nz: 0.000),
    AdasMeshFace(indices: [136, 140, 148, 144], nx: -0.000, ny: -1.000, nz: 0.000),
    AdasMeshFace(indices: [137, 145, 146, 138], nx: 1.000, ny: 0.025, nz: 0.000),
    AdasMeshFace(indices: [140, 139, 147, 148], nx: -1.000, ny: 0.026, nz: 0.003),
    AdasMeshFace(indices: [138, 146, 149, 141], nx: 0.941, ny: 0.336, nz: 0.034),
    AdasMeshFace(indices: [139, 143, 151, 147], nx: -0.049, ny: 0.341, nz: 0.939),
    AdasMeshFace(indices: [141, 149, 150, 142], nx: 0.014, ny: 0.345, nz: 0.938),
    AdasMeshFace(indices: [142, 150, 151, 143], nx: -0.014, ny: 0.342, nz: 0.940),
    AdasMeshFace(indices: [144, 152, 153, 145], nx: 0.000, ny: -1.000, nz: 0.000),
    AdasMeshFace(indices: [144, 148, 156, 152], nx: -0.000, ny: -1.000, nz: 0.000),
    AdasMeshFace(indices: [145, 153, 154, 146], nx: 1.000, ny: 0.025, nz: 0.000),
    AdasMeshFace(indices: [148, 147, 155, 156], nx: -1.000, ny: 0.025, nz: 0.000),
    AdasMeshFace(indices: [146, 154, 157, 149], nx: 0.964, ny: 0.265, nz: 0.000, isGlass: true),
    AdasMeshFace(indices: [147, 151, 159, 155], nx: -0.900, ny: 0.321, nz: 0.296, isGlass: true),
    AdasMeshFace(indices: [149, 157, 158, 150], nx: 0.027, ny: 0.641, nz: 0.767, isGlass: true),
    AdasMeshFace(indices: [150, 158, 159, 151], nx: -0.027, ny: 0.640, nz: 0.768, isGlass: true),
    AdasMeshFace(indices: [152, 160, 161, 153], nx: 0.000, ny: -1.000, nz: 0.000),
    AdasMeshFace(indices: [152, 156, 164, 160], nx: -0.000, ny: -1.000, nz: 0.000),
    AdasMeshFace(indices: [153, 161, 162, 154], nx: 1.000, ny: 0.025, nz: 0.000),
    AdasMeshFace(indices: [156, 155, 163, 164], nx: -1.000, ny: 0.025, nz: 0.000),
    AdasMeshFace(indices: [154, 162, 165, 157], nx: 0.967, ny: 0.253, nz: 0.000, isGlass: true),
    AdasMeshFace(indices: [155, 159, 167, 163], nx: -0.963, ny: 0.265, nz: 0.053, isGlass: true),
    AdasMeshFace(indices: [157, 165, 166, 158], nx: 0.042, ny: 0.980, nz: 0.196, isGlass: true),
    AdasMeshFace(indices: [158, 166, 167, 159], nx: -0.042, ny: 0.980, nz: 0.196, isGlass: true),
    AdasMeshFace(indices: [160, 168, 169, 161], nx: 0.000, ny: -0.970, nz: -0.243),
    AdasMeshFace(indices: [160, 164, 172, 168], nx: -0.000, ny: -0.970, nz: -0.243),
    AdasMeshFace(indices: [161, 169, 170, 162], nx: 1.000, ny: 0.027, nz: 0.007),
    AdasMeshFace(indices: [164, 163, 171, 172], nx: -1.000, ny: 0.025, nz: -0.003),
    AdasMeshFace(indices: [162, 170, 173, 165], nx: 0.955, ny: 0.294, nz: -0.037, isGlass: true),
    AdasMeshFace(indices: [163, 167, 175, 171], nx: -0.939, ny: 0.246, nz: -0.240, isGlass: true),
    AdasMeshFace(indices: [165, 173, 174, 166], nx: 0.039, ny: 0.892, nz: -0.451, isGlass: true),
    AdasMeshFace(indices: [166, 174, 175, 167], nx: -0.039, ny: 0.894, nz: -0.447, isGlass: true),
    AdasMeshFace(indices: [168, 176, 177, 169], nx: 0.000, ny: -0.970, nz: -0.243),
    AdasMeshFace(indices: [168, 172, 180, 176], nx: -0.000, ny: -0.970, nz: -0.243),
    AdasMeshFace(indices: [169, 177, 178, 170], nx: 1.000, ny: 0.029, nz: 0.007),
    AdasMeshFace(indices: [172, 171, 179, 180], nx: -1.000, ny: 0.027, nz: -0.003),
    AdasMeshFace(indices: [170, 178, 181, 173], nx: 0.875, ny: 0.481, nz: -0.060, isGlass: true),
    AdasMeshFace(indices: [171, 175, 183, 179], nx: -0.814, ny: 0.250, nz: -0.524, isGlass: true),
    AdasMeshFace(indices: [173, 181, 182, 174], nx: 0.016, ny: 0.372, nz: -0.928, isGlass: true),
    AdasMeshFace(indices: [174, 182, 183, 175], nx: -0.016, ny: 0.371, nz: -0.928, isGlass: true),
    AdasMeshFace(indices: [176, 184, 185, 177], nx: 0.000, ny: -1.000, nz: 0.000),
    AdasMeshFace(indices: [176, 180, 188, 184], nx: -0.000, ny: -1.000, nz: 0.000),
    AdasMeshFace(indices: [177, 185, 186, 178], nx: 1.000, ny: 0.030, nz: 0.000),
    AdasMeshFace(indices: [180, 179, 187, 188], nx: -1.000, ny: 0.029, nz: -0.005),
    AdasMeshFace(indices: [178, 186, 189, 181], nx: 0.142, ny: 0.976, nz: -0.163),
    AdasMeshFace(indices: [179, 183, 191, 187], nx: -0.402, ny: 0.221, nz: -0.888),
    AdasMeshFace(indices: [181, 189, 190, 182], nx: 0.009, ny: 0.300, nz: -0.954),
    AdasMeshFace(indices: [182, 190, 191, 183], nx: -0.009, ny: 0.294, nz: -0.956),
    AdasMeshFace(indices: [184, 192, 193, 185], nx: 0.000, ny: -0.949, nz: 0.316),
    AdasMeshFace(indices: [184, 188, 196, 192], nx: 0.000, ny: -0.949, nz: 0.316),
    AdasMeshFace(indices: [185, 193, 194, 186], nx: 0.945, ny: 0.029, nz: -0.325),
    AdasMeshFace(indices: [188, 187, 195, 196], nx: -0.945, ny: 0.029, nz: -0.325),
    AdasMeshFace(indices: [186, 194, 197, 189], nx: 0.140, ny: 0.924, nz: -0.355),
    AdasMeshFace(indices: [187, 191, 199, 195], nx: -0.135, ny: 0.930, nz: -0.342),
    AdasMeshFace(indices: [189, 197, 198, 190], nx: 0.031, ny: 0.946, nz: -0.323),
    AdasMeshFace(indices: [190, 198, 199, 191], nx: -0.031, ny: 0.948, nz: -0.316),
    AdasMeshFace(indices: [192, 200, 201, 193], nx: 0.000, ny: -0.707, nz: 0.707),
    AdasMeshFace(indices: [192, 196, 204, 200], nx: 0.000, ny: -0.707, nz: 0.707),
    AdasMeshFace(indices: [193, 201, 202, 194], nx: 0.787, ny: 0.026, nz: -0.616),
    AdasMeshFace(indices: [196, 195, 203, 204], nx: -0.779, ny: 0.024, nz: -0.626),
    AdasMeshFace(indices: [194, 202, 205, 197], nx: 0.076, ny: 0.470, nz: -0.879),
    AdasMeshFace(indices: [195, 199, 207, 203], nx: -0.072, ny: 0.478, nz: -0.875),
    AdasMeshFace(indices: [197, 205, 206, 198], nx: 0.017, ny: 0.492, nz: -0.870),
    AdasMeshFace(indices: [198, 206, 207, 199], nx: -0.017, ny: 0.496, nz: -0.868),
    AdasMeshFace(indices: [200, 208, 209, 201], nx: 0.000, ny: -0.447, nz: 0.894),
    AdasMeshFace(indices: [200, 204, 212, 208], nx: 0.000, ny: -0.447, nz: 0.894),
    AdasMeshFace(indices: [201, 209, 210, 202], nx: 0.307, ny: 0.015, nz: -0.952),
    AdasMeshFace(indices: [204, 203, 211, 212], nx: -0.295, ny: 0.010, nz: -0.955),
    AdasMeshFace(indices: [202, 210, 213, 205], nx: 0.025, ny: 0.131, nz: -0.991),
    AdasMeshFace(indices: [203, 207, 215, 211], nx: -0.022, ny: 0.135, nz: -0.991),
    AdasMeshFace(indices: [205, 213, 214, 206], nx: 0.006, ny: 0.140, nz: -0.990),
    AdasMeshFace(indices: [206, 214, 215, 207], nx: -0.006, ny: 0.141, nz: -0.990),
    AdasMeshFace(indices: [96, 97, 98, 101, 102], nx: 0.000, ny: 0.000, nz: 1.000),
    AdasMeshFace(indices: [96, 102, 103, 99, 100], nx: 0.000, ny: -0.000, nz: 1.000),
    AdasMeshFace(indices: [208, 214, 213, 210, 209], nx: 0.000, ny: 0.000, nz: -1.000),
    AdasMeshFace(indices: [208, 212, 211, 215, 214], nx: 0.000, ny: 0.000, nz: -1.000),
  ];

  static final AdasMeshData carMesh = AdasMeshData(
    vertices: _carVertices,
    faces: _carFaces,
  );

  // ==========================================================================
  // MOTORCYCLE MESH DATA (71 vertices, 48 faces)
  // ==========================================================================
  static final Float32List _motorcycleVertices = Float32List.fromList([
    -0.0400, 0.2200, 0.5800, 0.0400, 0.2200, 0.5800, -0.0400, 0.3300, 0.5505, 0.0400, 0.3300, 0.5505, -0.0400, 0.4105, 0.4700, 0.0400, 0.4105, 0.4700, -0.0400, 0.4400, 0.3600, 0.0400, 0.4400, 0.3600, -0.0400, 0.4105, 0.2500, 0.0400, 0.4105, 0.2500, -0.0400, 0.3300, 0.1695, 0.0400, 0.3300, 0.1695, -0.0400, 0.2200, 0.1400, 0.0400, 0.2200, 0.1400, -0.0400, 0.1100, 0.1695, 0.0400, 0.1100, 0.1695, -0.0400, 0.0295, 0.2500, 0.0400, 0.0295, 0.2500, -0.0400, 0.0000, 0.3600, 0.0400, 0.0000, 0.3600, -0.0400, 0.0295, 0.4700, 0.0400, 0.0295, 0.4700, -0.0400, 0.1100, 0.5505, 0.0400, 0.1100, 0.5505, -0.0400, 0.2200, -0.1200, 0.0400, 0.2200, -0.1200, -0.0400, 0.3300, -0.1495, 0.0400, 0.3300, -0.1495, -0.0400, 0.4105, -0.2300, 0.0400, 0.4105, -0.2300, -0.0400, 0.4400, -0.3400, 0.0400, 0.4400, -0.3400, -0.0400, 0.4105, -0.4500, 0.0400, 0.4105, -0.4500, -0.0400, 0.3300, -0.5305, 0.0400, 0.3300, -0.5305, -0.0400, 0.2200, -0.5600, 0.0400, 0.2200, -0.5600, -0.0400, 0.1100, -0.5305, 0.0400, 0.1100, -0.5305, -0.0400, 0.0295, -0.4500, 0.0400, 0.0295, -0.4500, -0.0400, 0.0000, -0.3400, 0.0400, 0.0000, -0.3400, -0.0400, 0.0295, -0.2300, 0.0400, 0.0295, -0.2300, -0.0400, 0.1100, -0.1495, 0.0400, 0.1100, -0.1495, 0.0000, 0.4800, 0.4400, -0.1300, 0.6600, 0.2600, 0.1300, 0.6600, 0.2600, -0.1200, 0.2000, 0.2200, 0.1200, 0.2000, 0.2200, 0.0000, 0.6800, 0.2400, -0.2200, 0.7000, 0.2200, 0.2200, 0.7000, 0.2200, -0.1400, 0.1600, 0.0000, 0.1400, 0.1600, 0.0000, -0.1200, 0.5200, 0.0600, 0.1200, 0.5200, 0.0600, -0.1300, 0.5400, -0.2600, 0.1300, 0.5400, -0.2600, 0.0000, 0.8400, 0.1200, 0.0000, 0.9800, 0.1200, 0.0000, 0.9100, 0.1900, 0.0000, 0.9100, 0.0500, -0.0900, 0.9100, 0.1200, 0.0900, 0.9100, 0.1200, -0.1600, 0.7800, 0.1400, 0.1600, 0.7800, 0.1400, 0.0000, 0.7600, 0.0200
  ]);

  static final List<AdasMeshFace> _motorcycleFaces = [
    AdasMeshFace(indices: [0, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22], nx: -1.000, ny: 0.000, nz: 0.000, isWheel: true),
    AdasMeshFace(indices: [23, 21, 19, 17, 15, 13, 11, 9, 7, 5, 3, 1], nx: 1.000, ny: 0.000, nz: 0.000, isWheel: true),
    AdasMeshFace(indices: [0, 1, 3, 2], nx: -0.000, ny: 0.259, nz: 0.966, isWheel: true),
    AdasMeshFace(indices: [2, 3, 5, 4], nx: -0.000, ny: 0.707, nz: 0.707, isWheel: true),
    AdasMeshFace(indices: [4, 5, 7, 6], nx: -0.000, ny: 0.966, nz: 0.259, isWheel: true),
    AdasMeshFace(indices: [6, 7, 9, 8], nx: 0.000, ny: 0.966, nz: -0.259, isWheel: true),
    AdasMeshFace(indices: [8, 9, 11, 10], nx: 0.000, ny: 0.707, nz: -0.707, isWheel: true),
    AdasMeshFace(indices: [10, 11, 13, 12], nx: 0.000, ny: 0.259, nz: -0.966, isWheel: true),
    AdasMeshFace(indices: [12, 13, 15, 14], nx: 0.000, ny: -0.259, nz: -0.966, isWheel: true),
    AdasMeshFace(indices: [14, 15, 17, 16], nx: 0.000, ny: -0.707, nz: -0.707, isWheel: true),
    AdasMeshFace(indices: [16, 17, 19, 18], nx: 0.000, ny: -0.966, nz: -0.259, isWheel: true),
    AdasMeshFace(indices: [18, 19, 21, 20], nx: 0.000, ny: -0.966, nz: 0.259, isWheel: true),
    AdasMeshFace(indices: [20, 21, 23, 22], nx: 0.000, ny: -0.707, nz: 0.707, isWheel: true),
    AdasMeshFace(indices: [22, 23, 1, 0], nx: 0.000, ny: -0.259, nz: 0.966, isWheel: true),
    AdasMeshFace(indices: [24, 26, 28, 30, 32, 34, 36, 38, 40, 42, 44, 46], nx: -1.000, ny: 0.000, nz: 0.000, isWheel: true),
    AdasMeshFace(indices: [47, 45, 43, 41, 39, 37, 35, 33, 31, 29, 27, 25], nx: 1.000, ny: 0.000, nz: 0.000, isWheel: true),
    AdasMeshFace(indices: [24, 25, 27, 26], nx: -0.000, ny: 0.259, nz: 0.966, isWheel: true),
    AdasMeshFace(indices: [26, 27, 29, 28], nx: -0.000, ny: 0.707, nz: 0.707, isWheel: true),
    AdasMeshFace(indices: [28, 29, 31, 30], nx: -0.000, ny: 0.966, nz: 0.259, isWheel: true),
    AdasMeshFace(indices: [30, 31, 33, 32], nx: 0.000, ny: 0.966, nz: -0.259, isWheel: true),
    AdasMeshFace(indices: [32, 33, 35, 34], nx: 0.000, ny: 0.707, nz: -0.707, isWheel: true),
    AdasMeshFace(indices: [34, 35, 37, 36], nx: 0.000, ny: 0.259, nz: -0.966, isWheel: true),
    AdasMeshFace(indices: [36, 37, 39, 38], nx: 0.000, ny: -0.259, nz: -0.966, isWheel: true),
    AdasMeshFace(indices: [38, 39, 41, 40], nx: 0.000, ny: -0.707, nz: -0.707, isWheel: true),
    AdasMeshFace(indices: [40, 41, 43, 42], nx: 0.000, ny: -0.966, nz: -0.259, isWheel: true),
    AdasMeshFace(indices: [42, 43, 45, 44], nx: 0.000, ny: -0.966, nz: 0.259, isWheel: true),
    AdasMeshFace(indices: [44, 45, 47, 46], nx: 0.000, ny: -0.707, nz: 0.707, isWheel: true),
    AdasMeshFace(indices: [46, 47, 25, 24], nx: 0.000, ny: -0.259, nz: 0.966, isWheel: true),
    AdasMeshFace(indices: [51, 48, 49], nx: -0.839, ny: -0.065, nz: 0.541),
    AdasMeshFace(indices: [52, 50, 48], nx: 0.839, ny: -0.065, nz: 0.541),
    AdasMeshFace(indices: [51, 52, 48], nx: 0.000, ny: -0.618, nz: 0.786),
    AdasMeshFace(indices: [49, 48, 50], nx: -0.000, ny: 0.707, nz: 0.707),
    AdasMeshFace(indices: [49, 53, 54], nx: -0.000, ny: 0.707, nz: 0.707),
    AdasMeshFace(indices: [50, 55, 53], nx: 0.000, ny: 0.707, nz: 0.707),
    AdasMeshFace(indices: [58, 59, 61, 60], nx: -0.000, ny: 0.998, nz: 0.062),
    AdasMeshFace(indices: [56, 57, 59, 58], nx: 0.000, ny: -0.164, nz: 0.986),
    AdasMeshFace(indices: [56, 58, 60], nx: -0.998, ny: 0.050, nz: 0.034),
    AdasMeshFace(indices: [57, 61, 59], nx: 0.998, ny: 0.050, nz: 0.034),
    AdasMeshFace(indices: [62, 64, 63, 66], nx: -1.000, ny: 0.000, nz: 0.000),
    AdasMeshFace(indices: [62, 67, 63, 64], nx: 0.000, ny: 0.000, nz: 1.000),
    AdasMeshFace(indices: [62, 66, 63, 65], nx: 0.000, ny: 0.000, nz: -1.000),
    AdasMeshFace(indices: [62, 65, 63, 67], nx: 1.000, ny: -0.000, nz: 0.000),
    AdasMeshFace(indices: [58, 59, 69, 68], nx: 0.000, ny: -0.294, nz: 0.956),
    AdasMeshFace(indices: [60, 61, 69, 70], nx: 0.000, ny: -0.857, nz: 0.514),
    AdasMeshFace(indices: [58, 68, 70, 60], nx: -0.580, ny: 0.157, nz: -0.799),
    AdasMeshFace(indices: [59, 61, 70, 69], nx: 0.889, ny: 0.454, nz: 0.056),
    AdasMeshFace(indices: [68, 54, 53], nx: -0.000, ny: 0.707, nz: 0.707),
    AdasMeshFace(indices: [69, 53, 55], nx: 0.000, ny: 0.707, nz: 0.707),
  ];

  static final AdasMeshData motorcycleMesh = AdasMeshData(
    vertices: _motorcycleVertices,
    faces: _motorcycleFaces,
  );

  // ==========================================================================
  // PEDESTRIAN MESH DATA (20 vertices, 17 faces)
  // ==========================================================================
  static final Float32List _pedestrianVertices = Float32List.fromList([
    0.0000, 0.8400, 0.0000, 0.0000, 0.9800, 0.0000, 0.0000, 0.9100, 0.1000, 0.0000, 0.9100, -0.0900, -0.0900, 0.9100, 0.0000, 0.0900, 0.9100, 0.0000, -0.1900, 0.8000, 0.0000, 0.1900, 0.8000, 0.0000, 0.0000, 0.7400, 0.0900, 0.0000, 0.7400, -0.0800, -0.1400, 0.4800, 0.0000, 0.1400, 0.4800, 0.0000, 0.0000, 0.4800, 0.0700, 0.0000, 0.4800, -0.0600, -0.0800, 0.2400, 0.0600, -0.0800, 0.0000, 0.1200, 0.0800, 0.2400, -0.0500, 0.0800, 0.0000, -0.1000, -0.2300, 0.4400, -0.0600, 0.2300, 0.4400, 0.0800
  ]);

  static final List<AdasMeshFace> _pedestrianFaces = [
    AdasMeshFace(indices: [0, 2, 1, 4], nx: -1.000, ny: 0.000, nz: 0.000),
    AdasMeshFace(indices: [0, 5, 1, 2], nx: 0.000, ny: 0.000, nz: 1.000),
    AdasMeshFace(indices: [0, 4, 1, 3], nx: 0.000, ny: 0.000, nz: -1.000),
    AdasMeshFace(indices: [0, 3, 1, 5], nx: 1.000, ny: -0.000, nz: 0.000),
    AdasMeshFace(indices: [6, 8, 7, 0], nx: -0.000, ny: 0.832, nz: 0.555),
    AdasMeshFace(indices: [6, 10, 12, 8], nx: -0.446, ny: -0.070, nz: 0.892),
    AdasMeshFace(indices: [7, 8, 12, 11], nx: 0.445, ny: -0.069, nz: 0.893),
    AdasMeshFace(indices: [6, 9, 13, 10], nx: -0.406, ny: -0.070, nz: -0.911),
    AdasMeshFace(indices: [7, 11, 13, 9], nx: 0.393, ny: -0.061, nz: -0.917),
    AdasMeshFace(indices: [10, 12, 14], nx: 0.444, ny: -0.111, nz: -0.889),
    AdasMeshFace(indices: [10, 14, 13], nx: 0.374, ny: 0.312, nz: 0.873),
    AdasMeshFace(indices: [14, 15, 10], nx: 0.000, ny: -0.243, nz: -0.970),
    AdasMeshFace(indices: [11, 16, 12], nx: -0.429, ny: 0.286, nz: -0.857),
    AdasMeshFace(indices: [11, 13, 16], nx: -0.392, ny: -0.093, nz: 0.915),
    AdasMeshFace(indices: [16, 11, 17], nx: 0.000, ny: 0.204, nz: -0.979),
    AdasMeshFace(indices: [6, 18, 10], nx: -0.527, ny: -0.082, nz: 0.846),
    AdasMeshFace(indices: [7, 11, 19], nx: -0.636, ny: 0.099, nz: 0.765),
  ];

  static final AdasMeshData pedestrianMesh = AdasMeshData(
    vertices: _pedestrianVertices,
    faces: _pedestrianFaces,
  );

  // ==========================================================================
  // TRUCK MESH DATA (162 vertices, 89 faces)
  // ==========================================================================
  static final Float32List _truckVertices = Float32List.fromList([
    0.3600, 0.2000, 0.5200, 0.4800, 0.2000, 0.5200, 0.3600, 0.3000, 0.4932, 0.4800, 0.3000, 0.4932, 0.3600, 0.3732, 0.4200, 0.4800, 0.3732, 0.4200, 0.3600, 0.4000, 0.3200, 0.4800, 0.4000, 0.3200, 0.3600, 0.3732, 0.2200, 0.4800, 0.3732, 0.2200, 0.3600, 0.3000, 0.1468, 0.4800, 0.3000, 0.1468, 0.3600, 0.2000, 0.1200, 0.4800, 0.2000, 0.1200, 0.3600, 0.1000, 0.1468, 0.4800, 0.1000, 0.1468, 0.3600, 0.0268, 0.2200, 0.4800, 0.0268, 0.2200, 0.3600, 0.0000, 0.3200, 0.4800, 0.0000, 0.3200, 0.3600, 0.0268, 0.4200, 0.4800, 0.0268, 0.4200, 0.3600, 0.1000, 0.4932, 0.4800, 0.1000, 0.4932, -0.3600, 0.2000, 0.5200, -0.4800, 0.2000, 0.5200, -0.3600, 0.3000, 0.4932, -0.4800, 0.3000, 0.4932, -0.3600, 0.3732, 0.4200, -0.4800, 0.3732, 0.4200, -0.3600, 0.4000, 0.3200, -0.4800, 0.4000, 0.3200, -0.3600, 0.3732, 0.2200, -0.4800, 0.3732, 0.2200, -0.3600, 0.3000, 0.1468, -0.4800, 0.3000, 0.1468, -0.3600, 0.2000, 0.1200, -0.4800, 0.2000, 0.1200, -0.3600, 0.1000, 0.1468, -0.4800, 0.1000, 0.1468, -0.3600, 0.0268, 0.2200, -0.4800, 0.0268, 0.2200, -0.3600, 0.0000, 0.3200, -0.4800, 0.0000, 0.3200, -0.3600, 0.0268, 0.4200, -0.4800, 0.0268, 0.4200, -0.3600, 0.1000, 0.4932, -0.4800, 0.1000, 0.4932, 0.3600, 0.2000, -0.0200, 0.4800, 0.2000, -0.0200, 0.3600, 0.3000, -0.0468, 0.4800, 0.3000, -0.0468, 0.3600, 0.3732, -0.1200, 0.4800, 0.3732, -0.1200, 0.3600, 0.4000, -0.2200, 0.4800, 0.4000, -0.2200, 0.3600, 0.3732, -0.3200, 0.4800, 0.3732, -0.3200, 0.3600, 0.3000, -0.3932, 0.4800, 0.3000, -0.3932, 0.3600, 0.2000, -0.4200, 0.4800, 0.2000, -0.4200, 0.3600, 0.1000, -0.3932, 0.4800, 0.1000, -0.3932, 0.3600, 0.0268, -0.3200, 0.4800, 0.0268, -0.3200, 0.3600, 0.0000, -0.2200, 0.4800, 0.0000, -0.2200, 0.3600, 0.0268, -0.1200, 0.4800, 0.0268, -0.1200, 0.3600, 0.1000, -0.0468, 0.4800, 0.1000, -0.0468, -0.3600, 0.2000, -0.0200, -0.4800, 0.2000, -0.0200, -0.3600, 0.3000, -0.0468, -0.4800, 0.3000, -0.0468, -0.3600, 0.3732, -0.1200, -0.4800, 0.3732, -0.1200, -0.3600, 0.4000, -0.2200, -0.4800, 0.4000, -0.2200, -0.3600, 0.3732, -0.3200, -0.4800, 0.3732, -0.3200, -0.3600, 0.3000, -0.3932, -0.4800, 0.3000, -0.3932, -0.3600, 0.2000, -0.4200, -0.4800, 0.2000, -0.4200, -0.3600, 0.1000, -0.3932, -0.4800, 0.1000, -0.3932, -0.3600, 0.0268, -0.3200, -0.4800, 0.0268, -0.3200, -0.3600, 0.0000, -0.2200, -0.4800, 0.0000, -0.2200, -0.3600, 0.0268, -0.1200, -0.4800, 0.0268, -0.1200, -0.3600, 0.1000, -0.0468, -0.4800, 0.1000, -0.0468, 0.3600, 0.2000, -0.1800, 0.4800, 0.2000, -0.1800, 0.3600, 0.3000, -0.2068, 0.4800, 0.3000, -0.2068, 0.3600, 0.3732, -0.2800, 0.4800, 0.3732, -0.2800, 0.3600, 0.4000, -0.3800, 0.4800, 0.4000, -0.3800, 0.3600, 0.3732, -0.4800, 0.4800, 0.3732, -0.4800, 0.3600, 0.3000, -0.5532, 0.4800, 0.3000, -0.5532, 0.3600, 0.2000, -0.5800, 0.4800, 0.2000, -0.5800, 0.3600, 0.1000, -0.5532, 0.4800, 0.1000, -0.5532, 0.3600, 0.0268, -0.4800, 0.4800, 0.0268, -0.4800, 0.3600, 0.0000, -0.3800, 0.4800, 0.0000, -0.3800, 0.3600, 0.0268, -0.2800, 0.4800, 0.0268, -0.2800, 0.3600, 0.1000, -0.2068, 0.4800, 0.1000, -0.2068, -0.3600, 0.2000, -0.1800, -0.4800, 0.2000, -0.1800, -0.3600, 0.3000, -0.2068, -0.4800, 0.3000, -0.2068, -0.3600, 0.3732, -0.2800, -0.4800, 0.3732, -0.2800, -0.3600, 0.4000, -0.3800, -0.4800, 0.4000, -0.3800, -0.3600, 0.3732, -0.4800, -0.4800, 0.3732, -0.4800, -0.3600, 0.3000, -0.5532, -0.4800, 0.3000, -0.5532, -0.3600, 0.2000, -0.5800, -0.4800, 0.2000, -0.5800, -0.3600, 0.1000, -0.5532, -0.4800, 0.1000, -0.5532, -0.3600, 0.0268, -0.4800, -0.4800, 0.0268, -0.4800, -0.3600, 0.0000, -0.3800, -0.4800, 0.0000, -0.3800, -0.3600, 0.0268, -0.2800, -0.4800, 0.0268, -0.2800, -0.3600, 0.1000, -0.2068, -0.4800, 0.1000, -0.2068, -0.4400, 0.1200, 0.4800, 0.4400, 0.1200, 0.4800, -0.4400, 0.1200, 0.1200, 0.4400, 0.1200, 0.1200, -0.4400, 0.5200, 0.4700, 0.4400, 0.5200, 0.4700, -0.4200, 0.8800, 0.3600, 0.4200, 0.8800, 0.3600, -0.4200, 0.9000, 0.1200, 0.4200, 0.9000, 0.1200, -0.4700, 0.2200, 0.1000, 0.4700, 0.2200, 0.1000, -0.4700, 0.2200, -0.4800, 0.4700, 0.2200, -0.4800, -0.4700, 0.9800, 0.1000, 0.4700, 0.9800, 0.1000, -0.4700, 0.9800, -0.4800, 0.4700, 0.9800, -0.4800
  ]);

  static final List<AdasMeshFace> _truckFaces = [
    AdasMeshFace(indices: [1, 3, 5, 7, 9, 11, 13, 15, 17, 19, 21, 23], nx: -1.000, ny: 0.000, nz: 0.000, isWheel: true),
    AdasMeshFace(indices: [0, 1, 3, 2], nx: -0.000, ny: 0.259, nz: 0.966, isWheel: true),
    AdasMeshFace(indices: [2, 3, 5, 4], nx: -0.000, ny: 0.707, nz: 0.707, isWheel: true),
    AdasMeshFace(indices: [4, 5, 7, 6], nx: -0.000, ny: 0.966, nz: 0.259, isWheel: true),
    AdasMeshFace(indices: [6, 7, 9, 8], nx: 0.000, ny: 0.966, nz: -0.259, isWheel: true),
    AdasMeshFace(indices: [8, 9, 11, 10], nx: 0.000, ny: 0.707, nz: -0.707, isWheel: true),
    AdasMeshFace(indices: [10, 11, 13, 12], nx: 0.000, ny: 0.259, nz: -0.966, isWheel: true),
    AdasMeshFace(indices: [12, 13, 15, 14], nx: 0.000, ny: -0.259, nz: -0.966, isWheel: true),
    AdasMeshFace(indices: [14, 15, 17, 16], nx: 0.000, ny: -0.707, nz: -0.707, isWheel: true),
    AdasMeshFace(indices: [16, 17, 19, 18], nx: 0.000, ny: -0.966, nz: -0.259, isWheel: true),
    AdasMeshFace(indices: [18, 19, 21, 20], nx: 0.000, ny: -0.966, nz: 0.259, isWheel: true),
    AdasMeshFace(indices: [20, 21, 23, 22], nx: 0.000, ny: -0.707, nz: 0.707, isWheel: true),
    AdasMeshFace(indices: [22, 23, 1, 0], nx: 0.000, ny: -0.259, nz: 0.966, isWheel: true),
    AdasMeshFace(indices: [47, 45, 43, 41, 39, 37, 35, 33, 31, 29, 27, 25], nx: 1.000, ny: 0.000, nz: 0.000, isWheel: true),
    AdasMeshFace(indices: [24, 25, 27, 26], nx: -0.000, ny: -0.259, nz: -0.966, isWheel: true),
    AdasMeshFace(indices: [26, 27, 29, 28], nx: -0.000, ny: -0.707, nz: -0.707, isWheel: true),
    AdasMeshFace(indices: [28, 29, 31, 30], nx: -0.000, ny: -0.966, nz: -0.259, isWheel: true),
    AdasMeshFace(indices: [30, 31, 33, 32], nx: 0.000, ny: -0.966, nz: 0.259, isWheel: true),
    AdasMeshFace(indices: [32, 33, 35, 34], nx: 0.000, ny: -0.707, nz: 0.707, isWheel: true),
    AdasMeshFace(indices: [34, 35, 37, 36], nx: 0.000, ny: -0.259, nz: 0.966, isWheel: true),
    AdasMeshFace(indices: [36, 37, 39, 38], nx: 0.000, ny: 0.259, nz: 0.966, isWheel: true),
    AdasMeshFace(indices: [38, 39, 41, 40], nx: 0.000, ny: 0.707, nz: 0.707, isWheel: true),
    AdasMeshFace(indices: [40, 41, 43, 42], nx: 0.000, ny: 0.966, nz: 0.259, isWheel: true),
    AdasMeshFace(indices: [42, 43, 45, 44], nx: 0.000, ny: 0.966, nz: -0.259, isWheel: true),
    AdasMeshFace(indices: [44, 45, 47, 46], nx: 0.000, ny: 0.707, nz: -0.707, isWheel: true),
    AdasMeshFace(indices: [46, 47, 25, 24], nx: 0.000, ny: 0.259, nz: -0.966, isWheel: true),
    AdasMeshFace(indices: [49, 51, 53, 55, 57, 59, 61, 63, 65, 67, 69, 71], nx: -1.000, ny: 0.000, nz: 0.000, isWheel: true),
    AdasMeshFace(indices: [48, 49, 51, 50], nx: -0.000, ny: 0.259, nz: 0.966, isWheel: true),
    AdasMeshFace(indices: [50, 51, 53, 52], nx: -0.000, ny: 0.707, nz: 0.707, isWheel: true),
    AdasMeshFace(indices: [52, 53, 55, 54], nx: -0.000, ny: 0.966, nz: 0.259, isWheel: true),
    AdasMeshFace(indices: [54, 55, 57, 56], nx: 0.000, ny: 0.966, nz: -0.259, isWheel: true),
    AdasMeshFace(indices: [56, 57, 59, 58], nx: 0.000, ny: 0.707, nz: -0.707, isWheel: true),
    AdasMeshFace(indices: [58, 59, 61, 60], nx: 0.000, ny: 0.259, nz: -0.966, isWheel: true),
    AdasMeshFace(indices: [60, 61, 63, 62], nx: 0.000, ny: -0.259, nz: -0.966, isWheel: true),
    AdasMeshFace(indices: [62, 63, 65, 64], nx: 0.000, ny: -0.707, nz: -0.707, isWheel: true),
    AdasMeshFace(indices: [64, 65, 67, 66], nx: 0.000, ny: -0.966, nz: -0.259, isWheel: true),
    AdasMeshFace(indices: [66, 67, 69, 68], nx: 0.000, ny: -0.966, nz: 0.259, isWheel: true),
    AdasMeshFace(indices: [68, 69, 71, 70], nx: 0.000, ny: -0.707, nz: 0.707, isWheel: true),
    AdasMeshFace(indices: [70, 71, 49, 48], nx: 0.000, ny: -0.259, nz: 0.966, isWheel: true),
    AdasMeshFace(indices: [95, 93, 91, 89, 87, 85, 83, 81, 79, 77, 75, 73], nx: 1.000, ny: 0.000, nz: 0.000, isWheel: true),
    AdasMeshFace(indices: [72, 73, 75, 74], nx: -0.000, ny: -0.259, nz: -0.966, isWheel: true),
    AdasMeshFace(indices: [74, 75, 77, 76], nx: -0.000, ny: -0.707, nz: -0.707, isWheel: true),
    AdasMeshFace(indices: [76, 77, 79, 78], nx: -0.000, ny: -0.966, nz: -0.259, isWheel: true),
    AdasMeshFace(indices: [78, 79, 81, 80], nx: 0.000, ny: -0.966, nz: 0.259, isWheel: true),
    AdasMeshFace(indices: [80, 81, 83, 82], nx: 0.000, ny: -0.707, nz: 0.707, isWheel: true),
    AdasMeshFace(indices: [82, 83, 85, 84], nx: 0.000, ny: -0.259, nz: 0.966, isWheel: true),
    AdasMeshFace(indices: [84, 85, 87, 86], nx: 0.000, ny: 0.259, nz: 0.966, isWheel: true),
    AdasMeshFace(indices: [86, 87, 89, 88], nx: 0.000, ny: 0.707, nz: 0.707, isWheel: true),
    AdasMeshFace(indices: [88, 89, 91, 90], nx: 0.000, ny: 0.966, nz: 0.259, isWheel: true),
    AdasMeshFace(indices: [90, 91, 93, 92], nx: 0.000, ny: 0.966, nz: -0.259, isWheel: true),
    AdasMeshFace(indices: [92, 93, 95, 94], nx: 0.000, ny: 0.707, nz: -0.707, isWheel: true),
    AdasMeshFace(indices: [94, 95, 73, 72], nx: 0.000, ny: 0.259, nz: -0.966, isWheel: true),
    AdasMeshFace(indices: [97, 99, 101, 103, 105, 107, 109, 111, 113, 115, 117, 119], nx: -1.000, ny: 0.000, nz: 0.000, isWheel: true),
    AdasMeshFace(indices: [96, 97, 99, 98], nx: -0.000, ny: 0.259, nz: 0.966, isWheel: true),
    AdasMeshFace(indices: [98, 99, 101, 100], nx: -0.000, ny: 0.707, nz: 0.707, isWheel: true),
    AdasMeshFace(indices: [100, 101, 103, 102], nx: -0.000, ny: 0.966, nz: 0.259, isWheel: true),
    AdasMeshFace(indices: [102, 103, 105, 104], nx: 0.000, ny: 0.966, nz: -0.259, isWheel: true),
    AdasMeshFace(indices: [104, 105, 107, 106], nx: 0.000, ny: 0.707, nz: -0.707, isWheel: true),
    AdasMeshFace(indices: [106, 107, 109, 108], nx: 0.000, ny: 0.259, nz: -0.966, isWheel: true),
    AdasMeshFace(indices: [108, 109, 111, 110], nx: 0.000, ny: -0.259, nz: -0.966, isWheel: true),
    AdasMeshFace(indices: [110, 111, 113, 112], nx: 0.000, ny: -0.707, nz: -0.707, isWheel: true),
    AdasMeshFace(indices: [112, 113, 115, 114], nx: 0.000, ny: -0.966, nz: -0.259, isWheel: true),
    AdasMeshFace(indices: [114, 115, 117, 116], nx: 0.000, ny: -0.966, nz: 0.259, isWheel: true),
    AdasMeshFace(indices: [116, 117, 119, 118], nx: 0.000, ny: -0.707, nz: 0.707, isWheel: true),
    AdasMeshFace(indices: [118, 119, 97, 96], nx: 0.000, ny: -0.259, nz: 0.966, isWheel: true),
    AdasMeshFace(indices: [143, 141, 139, 137, 135, 133, 131, 129, 127, 125, 123, 121], nx: 1.000, ny: 0.000, nz: 0.000, isWheel: true),
    AdasMeshFace(indices: [120, 121, 123, 122], nx: -0.000, ny: -0.259, nz: -0.966, isWheel: true),
    AdasMeshFace(indices: [122, 123, 125, 124], nx: -0.000, ny: -0.707, nz: -0.707, isWheel: true),
    AdasMeshFace(indices: [124, 125, 127, 126], nx: -0.000, ny: -0.966, nz: -0.259, isWheel: true),
    AdasMeshFace(indices: [126, 127, 129, 128], nx: 0.000, ny: -0.966, nz: 0.259, isWheel: true),
    AdasMeshFace(indices: [128, 129, 131, 130], nx: 0.000, ny: -0.707, nz: 0.707, isWheel: true),
    AdasMeshFace(indices: [130, 131, 133, 132], nx: 0.000, ny: -0.259, nz: 0.966, isWheel: true),
    AdasMeshFace(indices: [132, 133, 135, 134], nx: 0.000, ny: 0.259, nz: 0.966, isWheel: true),
    AdasMeshFace(indices: [134, 135, 137, 136], nx: 0.000, ny: 0.707, nz: 0.707, isWheel: true),
    AdasMeshFace(indices: [136, 137, 139, 138], nx: 0.000, ny: 0.966, nz: 0.259, isWheel: true),
    AdasMeshFace(indices: [138, 139, 141, 140], nx: 0.000, ny: 0.966, nz: -0.259, isWheel: true),
    AdasMeshFace(indices: [140, 141, 143, 142], nx: 0.000, ny: 0.707, nz: -0.707, isWheel: true),
    AdasMeshFace(indices: [142, 143, 121, 120], nx: 0.000, ny: 0.259, nz: -0.966, isWheel: true),
    AdasMeshFace(indices: [144, 145, 149, 148], nx: -0.000, ny: 0.025, nz: 1.000),
    AdasMeshFace(indices: [148, 149, 151, 150], nx: -0.000, ny: 0.292, nz: 0.956, isGlass: true),
    AdasMeshFace(indices: [150, 151, 153, 152], nx: -0.000, ny: 0.997, nz: 0.083, isGlass: true),
    AdasMeshFace(indices: [144, 148, 150, 152, 146], nx: -0.981, ny: -0.005, nz: -0.194, isGlass: true),
    AdasMeshFace(indices: [145, 147, 153, 151, 149], nx: 1.000, ny: 0.026, nz: 0.000, isGlass: true),
    AdasMeshFace(indices: [158, 159, 161, 160], nx: -0.000, ny: 1.000, nz: 0.000),
    AdasMeshFace(indices: [154, 155, 159, 158], nx: 0.000, ny: 0.000, nz: 1.000),
    AdasMeshFace(indices: [156, 160, 161, 157], nx: 0.000, ny: 0.000, nz: -1.000),
    AdasMeshFace(indices: [154, 158, 160, 156], nx: -1.000, ny: 0.000, nz: 0.000),
    AdasMeshFace(indices: [155, 157, 161, 159], nx: 1.000, ny: 0.000, nz: 0.000),
    AdasMeshFace(indices: [154, 156, 157, 155], nx: 0.000, ny: -1.000, nz: 0.000),
  ];

  static final AdasMeshData truckMesh = AdasMeshData(
    vertices: _truckVertices,
    faces: _truckFaces,
  );

  // ==========================================================================
  // BICYCLE MESH DATA (59 vertices, 11 faces)
  // ==========================================================================
  static final Float32List _bicycleVertices = Float32List.fromList([
    -0.0150, 0.2800, 0.6400, 0.0150, 0.2800, 0.6400, -0.0150, 0.4200, 0.6025, 0.0150, 0.4200, 0.6025, -0.0150, 0.5225, 0.5000, 0.0150, 0.5225, 0.5000, -0.0150, 0.5600, 0.3600, 0.0150, 0.5600, 0.3600, -0.0150, 0.5225, 0.2200, 0.0150, 0.5225, 0.2200, -0.0150, 0.4200, 0.1175, 0.0150, 0.4200, 0.1175, -0.0150, 0.2800, 0.0800, 0.0150, 0.2800, 0.0800, -0.0150, 0.1400, 0.1175, 0.0150, 0.1400, 0.1175, -0.0150, 0.0375, 0.2200, 0.0150, 0.0375, 0.2200, -0.0150, 0.0000, 0.3600, 0.0150, 0.0000, 0.3600, -0.0150, 0.0375, 0.5000, 0.0150, 0.0375, 0.5000, -0.0150, 0.1400, 0.6025, 0.0150, 0.1400, 0.6025, -0.0150, 0.2800, -0.0600, 0.0150, 0.2800, -0.0600, -0.0150, 0.4200, -0.0975, 0.0150, 0.4200, -0.0975, -0.0150, 0.5225, -0.2000, 0.0150, 0.5225, -0.2000, -0.0150, 0.5600, -0.3400, 0.0150, 0.5600, -0.3400, -0.0150, 0.5225, -0.4800, 0.0150, 0.5225, -0.4800, -0.0150, 0.4200, -0.5825, 0.0150, 0.4200, -0.5825, -0.0150, 0.2800, -0.6200, 0.0150, 0.2800, -0.6200, -0.0150, 0.1400, -0.5825, 0.0150, 0.1400, -0.5825, -0.0150, 0.0375, -0.4800, 0.0150, 0.0375, -0.4800, -0.0150, 0.0000, -0.3400, 0.0150, 0.0000, -0.3400, -0.0150, 0.0375, -0.2000, 0.0150, 0.0375, -0.2000, -0.0150, 0.1400, -0.0975, 0.0150, 0.1400, -0.0975, 0.0000, 0.2800, 0.0000, 0.0000, 0.5800, -0.1000, 0.0000, 0.6500, 0.2600, 0.0000, 0.2800, 0.3600, 0.0000, 0.2800, -0.3400, -0.1800, 0.6800, 0.2400, 0.1800, 0.6800, 0.2400, 0.0000, 0.8500, 0.0800, 0.0000, 0.9800, 0.0800, -0.0800, 0.9200, 0.0800, 0.0800, 0.9200, 0.0800
  ]);

  static final List<AdasMeshFace> _bicycleFaces = [
    AdasMeshFace(indices: [0, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22], nx: -1.000, ny: 0.000, nz: 0.000, isWheel: true),
    AdasMeshFace(indices: [23, 21, 19, 17, 15, 13, 11, 9, 7, 5, 3, 1], nx: 1.000, ny: 0.000, nz: 0.000, isWheel: true),
    AdasMeshFace(indices: [24, 26, 28, 30, 32, 34, 36, 38, 40, 42, 44, 46], nx: -1.000, ny: 0.000, nz: 0.000, isWheel: true),
    AdasMeshFace(indices: [47, 45, 43, 41, 39, 37, 35, 33, 31, 29, 27, 25], nx: 1.000, ny: 0.000, nz: 0.000, isWheel: true),
    AdasMeshFace(indices: [48, 49, 50], nx: 1.000, ny: -0.000, nz: 0.000),
    AdasMeshFace(indices: [48, 50, 51], nx: 1.000, ny: 0.000, nz: 0.000),
    AdasMeshFace(indices: [48, 52, 49], nx: 1.000, ny: 0.000, nz: 0.000),
    AdasMeshFace(indices: [50, 53, 54], nx: 0.000, ny: -0.555, nz: -0.832),
    AdasMeshFace(indices: [55, 57, 56, 58], nx: 0.000, ny: 0.000, nz: -1.000),
    AdasMeshFace(indices: [49, 55, 53], nx: 0.784, ny: -0.344, nz: 0.516),
    AdasMeshFace(indices: [49, 54, 55], nx: -0.784, ny: -0.344, nz: 0.516),
  ];

  static final AdasMeshData bicycleMesh = AdasMeshData(
    vertices: _bicycleVertices,
    faces: _bicycleFaces,
  );

  static AdasMeshData getMeshForClass(Detected3DClass cls) {
    switch (cls) {
      case Detected3DClass.car:
        return carMesh;
      case Detected3DClass.motorcycle:
        return motorcycleMesh;
      case Detected3DClass.pedestrian:
        return pedestrianMesh;
      case Detected3DClass.truck:
        return truckMesh;
      case Detected3DClass.bicycle:
        return bicycleMesh;
      default:
        return carMesh;
    }
  }
}
