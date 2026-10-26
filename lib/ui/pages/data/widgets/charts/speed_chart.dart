import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../../services/ros_service.dart';
import '../../../../../core/theme/colors.dart';
import '../../models/data_point.dart';
import 'chart_container.dart';

class SpeedChart extends StatefulWidget {
  const SpeedChart({super.key});

  @override
  State<SpeedChart> createState() => _SpeedChartState();
}

class _SpeedChartState extends State<SpeedChart> {
  final List<DataPoint> _speedHistory = [];
  final int _maxDataPoints = 30;
  final RosService _rosService = RosService();

  @override
  void initState() {
    super.initState();
    _setupSpeedListener();
  }

  void _setupSpeedListener() {
    _rosService.speedometerStream.listen((speed) {
      if (mounted) {
        setState(() {
          _speedHistory.add(DataPoint(DateTime.now(), speed));
          if (_speedHistory.length > _maxDataPoints) {
            _speedHistory.removeAt(0);
          }
        });
      }
    });
  }

  Color _getSpeedColor(double speed) {
    if (speed < 20) return const Color(0xFF16A34A);
    if (speed < 40) return const Color(0xFFD97706);
    return const Color(0xFFDC2626);
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    final gridLineClr = isLight ? const Color(0xFFF1F5F9) : AppColors.glassDivider;
    final axisTextClr = isLight ? const Color(0xFF94A3B8) : AppColors.glassTextSecondary;
    final lineClr = isLight ? const Color(0xFF7C3AED) : const Color(0xFFA78BFA);
    final waitingTextClr = isLight ? const Color(0xFF94A3B8) : AppColors.glassTextSecondary;

    return ChartContainer(
      icon: LucideIcons.gauge,
      title: 'Speed Analysis',
      iconBadgeBg: isLight ? const Color(0xFFF5F3FF) : const Color(0x1A8B5CF6),
      iconColor: isLight ? const Color(0xFF7C3AED) : const Color(0xFFA78BFA),
      trailing: StreamBuilder<double>(
        stream: _rosService.speedometerRosStream,
        builder: (context, snapshot) {
          final currentValue = snapshot.data ?? 0.0;
          final clr = _getSpeedColor(currentValue);
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
            decoration: BoxDecoration(
              color: clr.withValues(alpha: isLight ? 0.10 : 0.20),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: clr.withValues(alpha: 0.4),
                width: 1,
              ),
            ),
            child: Text(
              '${currentValue.toStringAsFixed(1)} km/h',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: clr,
                fontSize: 12,
              ),
            ),
          );
        },
      ),
      child: _speedHistory.isNotEmpty
          ? LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 10,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: gridLineClr,
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: 10,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}',
                          style: TextStyle(
                            color: axisTextClr,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: (_speedHistory.length - 1).toDouble(),
                minY: 0,
                maxY: 60,
                lineBarsData: [
                  LineChartBarData(
                    spots: _speedHistory.asMap().entries.map((entry) {
                      return FlSpot(entry.key.toDouble(), entry.value.value);
                    }).toList(),
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: lineClr,
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: lineClr.withValues(alpha: isLight ? 0.08 : 0.15),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (spot) => isLight
                        ? const Color(0xFFF1F5F9)
                        : const Color(0xFF1E293B),
                    tooltipBorder: BorderSide(
                      color: isLight
                          ? const Color(0xFFCBD5E1)
                          : const Color(0xFF334155),
                      width: 1.0,
                    ),
                    tooltipBorderRadius: BorderRadius.circular(8),
                    tooltipPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        return LineTooltipItem(
                          '${spot.y.toStringAsFixed(1)} km/h',
                          TextStyle(
                            color: isLight
                                ? const Color(0xFF0F172A)
                                : Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 11.5,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            )
          : Center(
              child: Text(
                'Waiting for speed data...',
                style: TextStyle(
                  color: waitingTextClr,
                  fontSize: 12,
                ),
              ),
            ),
    );
  }
}
