import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Jenis skenario jalan raya untuk visualisasi BEV 3D.
enum BevScenarioType {
  straight,
  rightTurn,
  leftTurn,
  tJunction,
  crossroad;

  String get number => switch (this) {
        BevScenarioType.straight => '1',
        BevScenarioType.rightTurn => '2',
        BevScenarioType.leftTurn => '3',
        BevScenarioType.tJunction => '4',
        BevScenarioType.crossroad => '5',
      };

  String get label => switch (this) {
        BevScenarioType.straight => 'Lurus',
        BevScenarioType.rightTurn => 'Belok Kanan',
        BevScenarioType.leftTurn => 'Belok Kiri',
        BevScenarioType.tJunction => 'Pertigaan',
        BevScenarioType.crossroad => 'Berhenti',
      };

  IconData get iconData => switch (this) {
        BevScenarioType.straight => LucideIcons.arrowUp,
        BevScenarioType.rightTurn => LucideIcons.cornerUpRight,
        BevScenarioType.leftTurn => LucideIcons.cornerUpLeft,
        BevScenarioType.tJunction => LucideIcons.gitFork,
        BevScenarioType.crossroad => LucideIcons.octagonAlert,
      };

  double get defaultSteeringAngle => switch (this) {
        BevScenarioType.straight => 0.0,
        BevScenarioType.rightTurn => 28.0,
        BevScenarioType.leftTurn => -28.0,
        BevScenarioType.tJunction => 12.0,
        BevScenarioType.crossroad => 0.0,
      };
}
