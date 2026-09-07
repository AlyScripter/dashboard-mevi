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
        // Extract yaw from IMU data, same as heading_hud
        double yaw = imuData['yaw'] ?? 0.0;
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

    // REVISI: tambahkan kartu putih (light mode) / navy glass (dark mode)
    // di dalam ChartContainer biru, senada dengan pola Steering & CTE
    // Analysis, supaya chart tidak "tenggelam" di atas background biru.
    final innerCardBg = isLight ? Colors.white : AppColors.glassSurface;
    final innerCardBorder = isLight
        ? const Color(0xFFDDE3EC)
        : AppColors.glassBlueBorder.withValues(alpha: 0.35);
    final innerCardShadow = isLight
        ? Colors.black.withValues(alpha: 0.06)
        : AppColors.glassBlueGlow.withValues(alpha: 0.08);
    final gridLineClr = isLight
        ? const Color(0xFFE3E7EE)
        : AppColors.glassDivider;
    final axisTextClr = isLight
        ? const Color(0xFF5B6472)
        : AppColors.glassTextSecondary;
    final lineClr = isLight ? const Color(0xFF00796B) : Colors.teal;
    final waitingTextClr = isLight
        ? const Color(0xFF5B6472)
        : AppColors.glassTextSecondary;

    return ChartContainer(
      icon: LucideIcons.compass,
      title: 'IMU Yaw Analysis',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: innerCardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: innerCardBorder, width: 1),
          boxShadow: [
            BoxShadow(
              color: innerCardShadow,
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StreamBuilder<Map<String, double>>(
              stream: _rosService.imuStream,
              builder: (context, snapshot) {
                final currentValue = snapshot.data?['yaw'] ?? 0.0;
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: lineClr.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: lineClr, width: 1),
                  ),
                  child: Text(
                    '${currentValue.toStringAsFixed(1)}°',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: lineClr,
                      fontSize: 11,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _yawHistory.isNotEmpty
                  ? LineChart(
                      LineChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: 90,
                          getDrawingHorizontalLine: (value) {
                            return FlLine(color: gridLineClr, strokeWidth: 1);
                          },
                        ),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              interval: 90,
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
                        minY: -180,
                        maxY: 180,
                        lineBarsData: [
                          LineChartBarData(
                            spots: _yawHistory
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
                              color: lineClr.withValues(alpha: 0.1),
                            ),
                          ),
                        ],
                        lineTouchData: LineTouchData(
                          enabled: true,
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipItems: (touchedSpots) {
                              return touchedSpots.map((
                                LineBarSpot touchedSpot,
                              ) {
                                return LineTooltipItem(
                                  '${touchedSpot.y.toStringAsFixed(1)}°',
                                  const TextStyle(
                                    color: Colors.white,
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
                        'Waiting for IMU data...',
                        style: TextStyle(color: waitingTextClr, fontSize: 14),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
