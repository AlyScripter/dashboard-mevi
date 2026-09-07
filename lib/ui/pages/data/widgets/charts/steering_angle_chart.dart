import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../../services/ros_service.dart';
import '../../../../../core/theme/colors.dart';
import '../../models/data_point.dart';

class SteeringAngleChart extends StatefulWidget {
  const SteeringAngleChart({super.key});

  @override
  State<SteeringAngleChart> createState() => _SteeringAngleChartState();
}

class _SteeringAngleChartState extends State<SteeringAngleChart> {
  final List<DataPoint> _steeringHistory = [];
  final int _maxDataPoints = 30;
  final RosService _rosService = RosService();

  @override
  void initState() {
    super.initState();
    _setupSteeringListener();
  }

  void _setupSteeringListener() {
    _rosService.steeringAngleStream.listen((steeringAngle) {
      if (mounted) {
        setState(() {
          _steeringHistory.add(DataPoint(DateTime.now(), steeringAngle));
          if (_steeringHistory.length > _maxDataPoints) {
            _steeringHistory.removeAt(0);
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    // REVISI: light mode → kartu putih bersih dengan border/shadow tipis,
    // garis chart & label dibuat lebih gelap/pekat supaya tetap kontras
    // di atas background putih. Dark mode tetap navy glass seperti semula.
    final cardBg = isLight ? Colors.white : AppColors.glassSurface;
    final cardBorderClr = isLight
        ? const Color(0xFFDDE3EC)
        : AppColors.glassBlueBorder.withValues(alpha: 0.35);
    final cardShadowClr = isLight
        ? Colors.black.withValues(alpha: 0.06)
        : AppColors.glassBlueGlow.withValues(alpha: 0.08);
    final headerIconClr = isLight
        ? const Color(0xFF1565C0)
        : AppColors.glassBlueBorder;
    final titleClr = isLight
        ? const Color(0xFF1A2331)
        : AppColors.glassTextPrimary;
    final gridLineClr = isLight
        ? const Color(0xFFE3E7EE)
        : AppColors.glassDivider;
    final axisTextClr = isLight
        ? const Color(0xFF5B6472)
        : AppColors.glassTextSecondary;
    final lineClr = isLight
        ? const Color(0xFF1565C0)
        : AppColors.glassBlueBorder;
    final tooltipBg = isLight ? Colors.white : AppColors.glassSurfaceAlt;
    final tooltipTextClr = isLight
        ? const Color(0xFF1A2331)
        : AppColors.glassTextPrimary;
    final waitingTextClr = isLight
        ? const Color(0xFF5B6472)
        : AppColors.glassTextSecondary;

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorderClr, width: 1),
        boxShadow: [
          BoxShadow(
            color: cardShadowClr,
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.turn_right, color: headerIconClr, size: 20),
              const SizedBox(width: 8),
              Text(
                'Steering Angle',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: titleClr,
                ),
              ),
              const Spacer(),
              StreamBuilder<double>(
                stream: _rosService.steeringAngleStream,
                builder: (context, snapshot) {
                  final currentValue = snapshot.data ?? 0.0;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getSteeringColor(
                        currentValue,
                      ).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _getSteeringColor(currentValue),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      '${currentValue.toStringAsFixed(1)}°',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _getSteeringColor(currentValue),
                        fontSize: 12,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _steeringHistory.isNotEmpty
                ? LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 10,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(color: gridLineClr, strokeWidth: 1);
                        },
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            interval: 15,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                '${value.toInt()}°',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: axisTextClr,
                                ),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      borderData: FlBorderData(
                        show: true,
                        border: Border.all(color: gridLineClr, width: 1),
                      ),
                      minX: 0,
                      maxX: (_maxDataPoints - 1).toDouble(),
                      minY: -45,
                      maxY: 45,
                      lineBarsData: [
                        LineChartBarData(
                          spots: _steeringHistory
                              .asMap()
                              .entries
                              .map(
                                (entry) => FlSpot(
                                  entry.key.toDouble(),
                                  entry.value.value,
                                ),
                              )
                              .toList(),
                          isCurved: true,
                          color: lineClr,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: lineClr.withValues(alpha: 0.12),
                          ),
                        ),
                      ],
                      lineTouchData: LineTouchData(
                        enabled: true,
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipColor: (touchedSpot) => tooltipBg,
                          getTooltipItems: (touchedSpots) {
                            return touchedSpots.map((LineBarSpot touchedSpot) {
                              return LineTooltipItem(
                                '${touchedSpot.y.toStringAsFixed(1)}°',
                                TextStyle(
                                  color: tooltipTextClr,
                                  fontWeight: FontWeight.bold,
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
                      'Waiting for steering data...',
                      style: TextStyle(color: waitingTextClr, fontSize: 14),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Color _getSteeringColor(double angle) {
    final absAngle = angle.abs();
    if (absAngle < 5) return Colors.green;
    if (absAngle < 15) return Colors.orange;
    return Colors.red;
  }
}
