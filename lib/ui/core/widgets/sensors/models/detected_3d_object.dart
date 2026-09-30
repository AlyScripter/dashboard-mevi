import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Jenis / kelas objek yang terdeteksi oleh sensor autonomous (LIDAR, Kamera, Radar).
enum Detected3DClass {
  car,
  pedestrian,
  bicycle,
  truck,
  trafficCone,
  obstacle;

  String get label {
    switch (this) {
      case Detected3DClass.car:
        return 'Car';
      case Detected3DClass.pedestrian:
        return 'Pedestrian';
      case Detected3DClass.bicycle:
        return 'Bicycle';
      case Detected3DClass.truck:
        return 'Truck';
      case Detected3DClass.trafficCone:
        return 'Cone';
      case Detected3DClass.obstacle:
        return 'Obstacle';
    }
  }

  /// Warna utama kelas objek untuk 3D bounding box & floating badge
  Color get primaryColor {
    switch (this) {
      case Detected3DClass.car:
        return const Color(0xFF0288D1); // Cyan / Vivid Blue
      case Detected3DClass.pedestrian:
        return const Color(0xFFFF6D00); // Vibrant Amber / Orange
      case Detected3DClass.bicycle:
        return const Color(0xFF8E24AA); // Purple / Magenta
      case Detected3DClass.truck:
        return const Color(0xFF1976D2); // Deep Blue
      case Detected3DClass.trafficCone:
        return const Color(0xFFFF3D00); // Bright Red-Orange
      case Detected3DClass.obstacle:
        return const Color(0xFFD32F2F); // Crimson Red
    }
  }

  IconData get iconData {
    switch (this) {
      case Detected3DClass.car:
        return LucideIcons.car;
      case Detected3DClass.pedestrian:
        return LucideIcons.user;
      case Detected3DClass.bicycle:
        return LucideIcons.bike;
      case Detected3DClass.truck:
        return LucideIcons.truck;
      case Detected3DClass.trafficCone:
        return LucideIcons.triangleAlert;
      case Detected3DClass.obstacle:
        return LucideIcons.shieldAlert;
    }
  }
}

/// Model data untuk objek 3D terdeteksi di ruang 3D dunia nyata.
class Detected3DObject {
  final String id;
  final Detected3DClass objectClass;
  final double x; // meter (+ kanan, - kiri)
  final double y; // meter (ketinggian dasar dari permukaan aspal)
  final double z; // meter (jarak ke depan)
  final double width;
  final double height;
  final double length;
  final double yawDeg;
  final double confidence;
  final bool isParked;
  final String? customLabel;
  final String? customDistance;

  const Detected3DObject({
    required this.id,
    required this.objectClass,
    required this.x,
    this.y = 0.0,
    required this.z,
    required this.width,
    required this.height,
    required this.length,
    this.yawDeg = 0.0,
    this.confidence = 0.95,
    this.isParked = false,
    this.customLabel,
    this.customDistance,
  });
}
