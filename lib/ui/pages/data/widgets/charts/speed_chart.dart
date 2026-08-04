import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../../services/ros_service.dart';
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

  @override
  Widget build(BuildContext context) {
    return ChartContainer(
      icon: LucideIcons.gauge,
      title: 'Speed Analysis',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StreamBuilder<double>(
            stream: _rosService.speedometerRosStream,
            builder: (context, snapshot) {
              final currentValue = snapshot.data ?? 0.0;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: _getSpeedColor(currentValue).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _getSpeedColor(currentValue),
                    width: 1,
                  ),
                ),
                child: Text(
                  '${currentValue.toStringAsFixed(1)} km/h',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _getSpeedColor(currentValue),
                    fontSize: 11,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _speedHistory.isNotEmpty
                ? LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 10,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: Colors.grey.shade300,
                            strokeWidth: 1,
                          );
                        },
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            interval: 20,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                '${value.toInt()}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
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
                        border: Border.all(
                          color: Colors.grey.shade300,
                          width: 1,
                        ),
                      ),
                      minX: 0,
                      maxX: (_maxDataPoints - 1).toDouble(),
                      minY: 0,
                      maxY: 60,
                      lineBarsData: [
                        LineChartBarData(
                          spots: _speedHistory
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
                          color: Colors.purple,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: Colors.purple.withValues(alpha: 0.1),
                          ),
                        ),
                      ],
                      lineTouchData: LineTouchData(
                        enabled: true,
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipItems: (touchedSpots) {
                            return touchedSpots.map((LineBarSpot touchedSpot) {
                              return LineTooltipItem(
                                '${touchedSpot.y.toStringAsFixed(1)} km/h',
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
                : const Center(
                    child: Text(
                      'Waiting for speed data...',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Color _getSpeedColor(double speed) {
    if (speed < 10) return Colors.green;
    if (speed < 30) return Colors.blue;
    if (speed < 45) return Colors.orange;
    return Colors.red;
  }
}
