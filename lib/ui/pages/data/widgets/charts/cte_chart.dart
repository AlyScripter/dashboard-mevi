import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../../services/ros_service.dart';
import '../../models/data_point.dart';

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
              const Icon(Icons.track_changes, color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Cross Track Error',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              StreamBuilder<double>(
                stream: _rosService.crossTrackErrorStream,
                builder: (context, snapshot) {
                  final currentValue = snapshot.data ?? 0.0;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getCteColor(currentValue).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _getCteColor(currentValue),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      '${currentValue.toStringAsFixed(2)}m',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _getCteColor(currentValue),
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
            child: _cteHistory.isNotEmpty
                ? LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 0.5,
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
                            interval: 1,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                '${value.toStringAsFixed(1)}m',
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
                      minY: -3,
                      maxY: 3,
                      lineBarsData: [
                        LineChartBarData(
                          spots: _cteHistory
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
                          color: Colors.orange,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: Colors.orange.withValues(alpha: 0.1),
                          ),
                        ),
                      ],
                      lineTouchData: LineTouchData(
                        enabled: true,
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipItems: (touchedSpots) {
                            return touchedSpots.map((LineBarSpot touchedSpot) {
                              return LineTooltipItem(
                                '${touchedSpot.y.toStringAsFixed(2)}m',
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
                      'Waiting for CTE data...',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Color _getCteColor(double cte) {
    final absCte = cte.abs();
    if (absCte < 0.5) return Colors.green;
    if (absCte < 1.5) return Colors.orange;
    return Colors.red;
  }
}
