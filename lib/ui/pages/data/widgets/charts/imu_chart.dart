import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../../services/ros_service.dart';
import '../../../../../core/theme/colors.dart';
import '../../models/data_point.dart';
import 'chart_container.dart';

class ImuChart extends StatefulWidget {
  const ImuChart({super.key});

  @override
  State<ImuChart> createState() => _ImuChartState();
}

class _ImuChartState extends State<ImuChart> {
  final List<DataPoint> _yawHistory = [];
  final int _maxDataPoints = 30;
  final RosService _rosService = RosService();

  @override
  void initState() {
    super.initState();
    _setupImuListener();
  }

  void _setupImuListener() {
    _rosService.imuStream.listen((imuData) {
      if (mounted) {
        final yaw = imuData['yaw'] ?? 0.0;
        setState(() {
          _yawHistory.add(DataPoint(DateTime.now(), yaw));
          if (_yawHistory.length > _maxDataPoints) {
            _yawHistory.removeAt(0);
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    final gridLineClr = isLight ? const Color(0xFFF1F5F9) : AppColors.glassDivider;
    final axisTextClr = isLight ? const Color(0xFF94A3B8) : AppColors.glassTextSecondary;
    final lineClr = isLight ? const Color(0xFF0D9488) : const Color(0xFF2DD4BF);
    final waitingTextClr = isLight ? const Color(0xFF94A3B8) : AppColors.glassTextSecondary;

    return ChartContainer(
      icon: LucideIcons.compass,
      title: 'IMU Yaw Analysis',
      iconBadgeBg: isLight ? const Color(0xFFF0FDFA) : const Color(0x1A14B8A6),
      iconColor: isLight ? const Color(0xFF0D9488) : const Color(0xFF2DD4BF),
      trailing: StreamBuilder<Map<String, double>>(
        stream: _rosService.imuStream,
        builder: (context, snapshot) {
          final currentValue = snapshot.data?['yaw'] ?? 0.0;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
            decoration: BoxDecoration(
              color: lineClr.withValues(alpha: isLight ? 0.10 : 0.20),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: lineClr.withValues(alpha: 0.4),
                width: 1,
              ),
            ),
            child: Text(
              '${currentValue.toStringAsFixed(1)}°',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: lineClr,
                fontSize: 12,
              ),
            ),
          );
        },
      ),
      child: _yawHistory.isNotEmpty
          ? LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 45,
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
                      reservedSize: 36,
                      interval: 45,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}°',
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
                maxX: (_yawHistory.length - 1).toDouble(),
                minY: -180,
                maxY: 180,
                lineBarsData: [
                  LineChartBarData(
                    spots: _yawHistory.asMap().entries.map((entry) {
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
                          '${spot.y.toStringAsFixed(1)}°',
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
                'Waiting for IMU data...',
                style: TextStyle(
                  color: waitingTextClr,
                  fontSize: 12,
                ),
              ),
            ),
    );
  }
}
