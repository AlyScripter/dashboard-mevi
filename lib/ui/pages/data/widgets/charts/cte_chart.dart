import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../../services/ros_service.dart';
import '../../../../../core/theme/colors.dart';
import '../../models/data_point.dart';
import 'chart_container.dart';

class CteChart extends StatefulWidget {
  const CteChart({super.key});

  @override
  State<CteChart> createState() => _CteChartState();
}

class _CteChartState extends State<CteChart> {
  final List<DataPoint> _cteHistory = [];
  final int _maxDataPoints = 30;
  final RosService _rosService = RosService();

  @override
  void initState() {
    super.initState();
    _setupCteListener();
  }

  void _setupCteListener() {
    if (_rosService.currentCte != 0.0) {
      _cteHistory.add(DataPoint(DateTime.now(), _rosService.currentCte));
    }
    _rosService.crossTrackErrorStream.listen((cte) {
      if (mounted) {
        setState(() {
          _cteHistory.add(DataPoint(DateTime.now(), cte));
          if (_cteHistory.length > _maxDataPoints) {
            _cteHistory.removeAt(0);
          }
        });
      }
    });
  }

  Color _getCteColor(double cte) {
    if (cte.abs() < 0.2) return const Color(0xFF16A34A);
    if (cte.abs() < 0.5) return const Color(0xFFD97706);
    return const Color(0xFFDC2626);
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    final gridLineClr = isLight ? const Color(0xFFF1F5F9) : AppColors.glassDivider;
    final axisTextClr = isLight ? const Color(0xFF94A3B8) : AppColors.glassTextSecondary;
    final lineClr = isLight ? const Color(0xFFD97706) : const Color(0xFFF59E0B);
    final waitingTextClr = isLight ? const Color(0xFF94A3B8) : AppColors.glassTextSecondary;

    return ChartContainer(
      icon: LucideIcons.crosshair,
      title: 'Cross Track Error Analysis',
      iconBadgeBg: isLight ? const Color(0xFFFFFBEB) : const Color(0x1AF59E0B),
      iconColor: isLight ? const Color(0xFFD97706) : const Color(0xFFF59E0B),
      trailing: StreamBuilder<double>(
        stream: _rosService.crossTrackErrorStream,
        initialData: _rosService.currentCte,
        builder: (context, snapshot) {
          final currentValue = snapshot.data ?? 0.0;
          final clr = _getCteColor(currentValue);
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
              '${currentValue.toStringAsFixed(2)}m',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: clr,
                fontSize: 12,
              ),
            ),
          );
        },
      ),
      child: _cteHistory.isNotEmpty
          ? LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 0.5,
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
                      interval: 1.0,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toStringAsFixed(1)}m',
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
                maxX: (_cteHistory.length - 1).toDouble(),
                minY: -2.0,
                maxY: 2.0,
                lineBarsData: [
                  LineChartBarData(
                    spots: _cteHistory.asMap().entries.map((entry) {
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
                          '${spot.y.toStringAsFixed(2)}m',
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
                'Waiting for CTE data...',
                style: TextStyle(
                  color: waitingTextClr,
                  fontSize: 12,
                ),
              ),
            ),
    );
  }
}
