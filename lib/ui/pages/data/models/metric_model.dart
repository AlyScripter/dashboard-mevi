import 'package:flutter/material.dart';

enum TrendDirection { up, down, stable }

class MetricData {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color color;
  final TrendDirection trend;

  MetricData({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    required this.trend,
  });
}
