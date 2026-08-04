import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../../services/ros_service.dart';
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
    return ChartContainer(
      icon: LucideIcons.compass,
      title: 'IMU Yaw Analysis',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StreamBuilder<Map<String, double>>(
            stream: _rosService.imuStream,
            builder: (context, snapshot) {
              final currentValue = snapshot.data?['yaw'] ?? 0.0;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.teal, width: 1),
                ),
                child: Text(
                  '${currentValue.toStringAsFixed(1)}°',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
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
                            interval: 90,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                '${value.toInt()}°',
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
                          color: Colors.teal,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: Colors.teal.withValues(alpha: 0.1),
                          ),
                        ),
                      ],
                      lineTouchData: LineTouchData(
                        enabled: true,
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipItems: (touchedSpots) {
                            return touchedSpots.map((LineBarSpot touchedSpot) {
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
                : const Center(
                    child: Text(
                      'Waiting for IMU data...',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
