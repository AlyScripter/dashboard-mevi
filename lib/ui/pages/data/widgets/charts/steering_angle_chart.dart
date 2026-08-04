import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../../services/ros_service.dart';
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
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.turn_right, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Steering Angle',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
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
                            interval: 15,
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
                          color: Colors.blue,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: Colors.blue.withValues(alpha: 0.1),
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
                      'Waiting for steering data...',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
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
