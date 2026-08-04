import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'lidar_painters.dart';

enum LidarVisualizationMode {
  polar, // Polar coordinate view (traditional)
  cartesian, // X-Y coordinate view
  range, // Range vs angle line chart
  heatmap, // Intensity heatmap
  birdEye, // Bird's eye view
}

class EnhancedLidarVisualization extends StatefulWidget {
  final List<double> ranges;
  final List<double> intensities;
  final double angleMin;
  final double angleMax;
  final double angleIncrement;
  final double rangeMin;
  final double rangeMax;
  final LidarVisualizationMode mode;

  const EnhancedLidarVisualization({
    super.key,
    required this.ranges,
    this.intensities = const [],
    // Default FOV matches lidarnode_w.py: -40° to +40° (front-only)
    this.angleMin = -40 * math.pi / 180, // -40 degrees in radians
    this.angleMax = 40 * math.pi / 180,  // +40 degrees in radians
    // 7 segments: [40, 30, 20, 0, -20, -30, -40] = 80° / 7 ≈ 11.4° per segment
    this.angleIncrement = 80 * math.pi / 180 / 7, // ~11.4 degrees per segment
    this.rangeMin = 0.0,
    // Max range matches lidarnode_w.py thresholds (max 3m for center)
    this.rangeMax = 3.0,
    this.mode = LidarVisualizationMode.polar,
  });

  @override
  State<EnhancedLidarVisualization> createState() =>
      _EnhancedLidarVisualizationState();
}

class _EnhancedLidarVisualizationState
    extends State<EnhancedLidarVisualization> {
  LidarVisualizationMode _currentMode = LidarVisualizationMode.polar;
  final bool _showGrid = true;
  final bool _showIntensity = true;
  double _zoomLevel = 1.0;
  Offset _panOffset = Offset.zero;

  // Clean light theme colors
  static const Color _primaryColor = Color(0xFF2563EB); // Clean blue
  static const Color _accentColor = Color(0xFF10B981); // Clean green
  static const Color _surfaceColor = Color(0xFFFAFAFA); // Light surface
  static const Color _cardColor = Color(0xFFFFFFFF); // Pure white cards
  static const Color _textPrimary = Color(0xFF111827); // Dark text
  static const Color _textSecondary = Color(0xFF6B7280); // Gray text
  static const Color _borderColor = Color(0xFFE5E7EB); // Light border
  static const Color _gridColor = Color(0xFFF3F4F6); // Subtle grid

  @override
  void initState() {
    super.initState();
    _currentMode = widget.mode;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: _buildVisualization(),
            ),
          ),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildVisualization() {
    return Container(
      decoration: BoxDecoration(
        color: _surfaceColor.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor.withValues(alpha: 0.5)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: _getVisualizationWidget(),
      ),
    );
  }

  Widget _getVisualizationWidget() {
    switch (_currentMode) {
      case LidarVisualizationMode.polar:
        return _buildPolarView();
      case LidarVisualizationMode.cartesian:
        return _buildCartesianView();
      case LidarVisualizationMode.range:
        return _buildRangeChart();
      case LidarVisualizationMode.heatmap:
        return _buildHeatmapView();
      case LidarVisualizationMode.birdEye:
        return _buildBirdEyeView();
    }
  }

  Widget _buildPolarView() {
    return GestureDetector(
      onScaleStart: (details) {
        // Initialize scale/pan gesture
      },
      onScaleUpdate: (details) {
        setState(() {
          if (details.scale != 1.0) {
            _zoomLevel = (_zoomLevel * details.scale).clamp(0.5, 5.0);
          }
          _panOffset += details.focalPointDelta;
        });
      },
      onScaleEnd: (details) {
        // End scale/pan gesture
      },
      child: CustomPaint(
        painter: LidarPolarPainter(
          ranges: widget.ranges,
          intensities: widget.intensities,
          angleMin: widget.angleMin,
          angleMax: widget.angleMax,
          angleIncrement: widget.angleIncrement,
          rangeMax: widget.rangeMax,
          showGrid: _showGrid,
          showIntensity: _showIntensity,
          zoomLevel: _zoomLevel,
          panOffset: _panOffset,
        ),
        size: Size.infinite,
      ),
    );
  }

  Widget _buildCartesianView() {
    final points = _convertToCartesian();

    return ScatterChart(
      ScatterChartData(
        scatterSpots: points
            .map(
              (point) => ScatterSpot(
                point.dx,
                point.dy,
                dotPainter: FlDotCirclePainter(
                  radius: 3,
                  color: _getIntensityColor(point.intensity),
                  strokeColor: _cardColor,
                  strokeWidth: 1,
                ),
              ),
            )
            .toList(),
        minX: -widget.rangeMax,
        maxX: widget.rangeMax,
        minY: -widget.rangeMax,
        maxY: widget.rangeMax,
        gridData: FlGridData(
          show: _showGrid,
          drawVerticalLine: true,
          drawHorizontalLine: true,
          getDrawingVerticalLine: (value) =>
              FlLine(color: _gridColor, strokeWidth: 1),
          getDrawingHorizontalLine: (value) =>
              FlLine(color: _gridColor, strokeWidth: 1),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: _borderColor, width: 1.5),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) => Text(
                '${value.toInt()}m',
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) => Text(
                '${value.toInt()}m',
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
      ),
    );
  }

  Widget _buildRangeChart() {
    final spots = <FlSpot>[];
    for (int i = 0; i < widget.ranges.length; i++) {
      final angle = widget.angleMin + (i * widget.angleIncrement);
      final angleDegrees = angle * 180 / math.pi;
      spots.add(FlSpot(angleDegrees, widget.ranges[i]));
    }

    return LineChart(
      LineChartData(
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: _primaryColor,
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  _primaryColor.withValues(alpha: 0.15),
                  _primaryColor.withValues(alpha: 0.05),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
        minX: widget.angleMin * 180 / math.pi,
        maxX: widget.angleMax * 180 / math.pi,
        minY: widget.rangeMin,
        maxY: widget.rangeMax,
        gridData: FlGridData(
          show: _showGrid,
          drawVerticalLine: true,
          drawHorizontalLine: true,
          getDrawingVerticalLine: (value) =>
              FlLine(color: _gridColor, strokeWidth: 1),
          getDrawingHorizontalLine: (value) =>
              FlLine(color: _gridColor, strokeWidth: 1),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: _borderColor, width: 1.5),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            axisNameWidget: Text(
              'Range (m)',
              style: TextStyle(
                color: _textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) => Text(
                '${value.toInt()}',
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            axisNameWidget: Text(
              'Angle (°)',
              style: TextStyle(
                color: _textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            sideTitles: SideTitles(
              showTitles: true,
              interval: 45,
              getTitlesWidget: (value, meta) => Text(
                '${value.toInt()}°',
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
      ),
    );
  }

  Widget _buildHeatmapView() {
    return CustomPaint(
      painter: LidarHeatmapPainter(
        ranges: widget.ranges,
        intensities: widget.intensities,
        angleMin: widget.angleMin,
        angleMax: widget.angleMax,
        angleIncrement: widget.angleIncrement,
        rangeMax: widget.rangeMax,
        showGrid: _showGrid,
      ),
      size: Size.infinite,
    );
  }

  Widget _buildBirdEyeView() {
    return CustomPaint(
      painter: LidarBirdEyePainter(
        ranges: widget.ranges,
        intensities: widget.intensities,
        angleMin: widget.angleMin,
        angleMax: widget.angleMax,
        angleIncrement: widget.angleIncrement,
        rangeMax: widget.rangeMax,
        zoomLevel: _zoomLevel,
        panOffset: _panOffset,
      ),
      size: Size.infinite,
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                _buildStatItem(
                  'Data Points',
                  '${widget.ranges.length}',
                  _accentColor,
                  Icons.scatter_plot_rounded,
                ),
                const SizedBox(width: 12),
                _buildStatItem(
                  'Max Range',
                  '${widget.rangeMax.toStringAsFixed(1)}m',
                  _primaryColor,
                  Icons.straighten_rounded,
                ),
              ],
            ),
          ),
          _buildModeSelector(),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _accentColor.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _accentColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'SCANNING',
                  style: TextStyle(
                    color: _accentColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<CartesianPoint> _convertToCartesian() {
    final points = <CartesianPoint>[];
    for (int i = 0; i < widget.ranges.length; i++) {
      final angle = widget.angleMin + (i * widget.angleIncrement);
      final range = widget.ranges[i];
      final intensity = i < widget.intensities.length
          ? widget.intensities[i]
          : 0.0;

      if (range > widget.rangeMin && range < widget.rangeMax) {
        final x = range * math.cos(angle);
        final y = range * math.sin(angle);
        points.add(CartesianPoint(x, y, intensity));
      }
    }
    return points;
  }

  Color _getIntensityColor(double intensity) {
    if (!_showIntensity) return _primaryColor;

    // Clean gradient from blue to orange
    final normalized = intensity.clamp(0.0, 1.0);
    return Color.lerp(
          _primaryColor,
          const Color(0xFFF59E0B), // Amber
          normalized,
        ) ??
        _primaryColor;
  }

  Widget _buildModeSelector() {
    return PopupMenuButton<LidarVisualizationMode>(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: _cardColor,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _primaryColor.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_getModeIcon(_currentMode), color: _primaryColor, size: 14),
            const SizedBox(width: 6),
            Text(
              _getModeDisplayName(_currentMode),
              style: TextStyle(
                color: _primaryColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: _primaryColor,
              size: 16,
            ),
          ],
        ),
      ),
      onSelected: (mode) {
        setState(() {
          _currentMode = mode;
        });
      },
      itemBuilder: (context) => [
        _buildMenuItem(
          LidarVisualizationMode.polar,
          Icons.radio_button_checked_rounded,
          'Polar View',
        ),
        _buildMenuItem(
          LidarVisualizationMode.cartesian,
          Icons.grid_on_rounded,
          'Cartesian',
        ),
        _buildMenuItem(
          LidarVisualizationMode.range,
          Icons.show_chart_rounded,
          'Range Chart',
        ),
        _buildMenuItem(
          LidarVisualizationMode.heatmap,
          Icons.gradient_rounded,
          'Heatmap',
        ),
        _buildMenuItem(
          LidarVisualizationMode.birdEye,
          Icons.visibility_rounded,
          'Bird\'s Eye',
        ),
      ],
    );
  }

  IconData _getModeIcon(LidarVisualizationMode mode) {
    switch (mode) {
      case LidarVisualizationMode.polar:
        return Icons.radio_button_checked_rounded;
      case LidarVisualizationMode.cartesian:
        return Icons.grid_on_rounded;
      case LidarVisualizationMode.range:
        return Icons.show_chart_rounded;
      case LidarVisualizationMode.heatmap:
        return Icons.gradient_rounded;
      case LidarVisualizationMode.birdEye:
        return Icons.visibility_rounded;
    }
  }

  String _getModeDisplayName(LidarVisualizationMode mode) {
    switch (mode) {
      case LidarVisualizationMode.polar:
        return 'Polar';
      case LidarVisualizationMode.cartesian:
        return 'Cartesian';
      case LidarVisualizationMode.range:
        return 'Range Chart';
      case LidarVisualizationMode.heatmap:
        return 'Heatmap';
      case LidarVisualizationMode.birdEye:
        return 'Bird\'s Eye';
    }
  }

  PopupMenuItem<LidarVisualizationMode> _buildMenuItem(
    LidarVisualizationMode mode,
    IconData icon,
    String label,
  ) {
    final isSelected = _currentMode == mode;
    return PopupMenuItem(
      value: mode,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isSelected
                    ? _primaryColor.withValues(alpha: 0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 16,
                color: isSelected ? _primaryColor : _textSecondary,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? _primaryColor : _textPrimary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                fontSize: 13,
              ),
            ),
            if (isSelected) ...[
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: _primaryColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, size: 10, color: Colors.white),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class CartesianPoint {
  final double dx;
  final double dy;
  final double intensity;

  CartesianPoint(this.dx, this.dy, this.intensity);
}
