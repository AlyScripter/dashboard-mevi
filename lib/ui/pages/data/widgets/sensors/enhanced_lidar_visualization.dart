import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'lidar_painters.dart';
import 'lidar_2d_scan_painter.dart';
import '../../../../../core/theme/colors.dart';

enum LidarVisualizationMode {
  polar, // Polar coordinate view (traditional)
  cartesian, // X-Y coordinate view
  range, // Range vs angle line chart
  heatmap, // Intensity heatmap
  birdEye, // Bird's eye view
  lidar2D, // Full-resolution 270° top-down X/Y scan (matplotlib-style)
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

  // ---- Dedicated full-resolution 270° scan, for LidarVisualizationMode.lidar2D ----
  // Kept separate from `ranges` above (which is downsampled to 360 bins
  // across a full -180..180 sweep for the other view modes) so the 2D
  // top-down plot can reproduce the real ~270° Hokuyo geometry exactly,
  // straight from the /scan rosbag data.
  final List<double> lidar2DRanges;
  final double lidar2DAngleMin;
  final double lidar2DAngleIncrement;
  final double lidar2DRangeMin;
  final double lidar2DRangeMax;

  const EnhancedLidarVisualization({
    super.key,
    required this.ranges,
    this.intensities = const [],
    // Default FOV matches lidarnode_w.py: -40° to +40° (front-only)
    this.angleMin = -40 * math.pi / 180, // -40 degrees in radians
    this.angleMax = 40 * math.pi / 180, // +40 degrees in radians
    // 7 segments: [40, 30, 20, 0, -20, -30, -40] = 80° / 7 ≈ 11.4° per segment
    this.angleIncrement = 80 * math.pi / 180 / 7, // ~11.4 degrees per segment
    this.rangeMin = 0.0,
    // Max range matches lidarnode_w.py thresholds (max 3m for center)
    this.rangeMax = 3.0,
    this.mode = LidarVisualizationMode.polar,
    this.lidar2DRanges = const [],
    // Real Hokuyo /scan geometry for the ~270° full scan.
    this.lidar2DAngleMin = -2.3561944901923448, // -135°
    this.lidar2DAngleIncrement = 0.004363323129985824, // 0.25°
    this.lidar2DRangeMin = 0.02,
    // 20x20m view, matching the reference Python (matplotlib) single-scan
    // radar plot the dark theme/marker style was ported from.
    this.lidar2DRangeMax = 20.0,
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

  // Dark-mode static colors (tetap dipakai di dark mode dan di dalam canvas)
  static const Color _primaryColor = AppColors.glassBlueBorder;
  static const Color _accentColor = Color(0xFF34D399);
  static const Color _surfaceColor = AppColors.glassSurfaceAlt;
  static const Color _cardColor = AppColors.glassSurface;
  static const Color _textPrimary = AppColors.glassTextPrimary;
  static const Color _textSecondary = AppColors.glassTextSecondary;
  static const Color _borderColor = AppColors.glassBlueBorder;
  static const Color _gridColor = Color(0xFF1E2633);

  // Light-mode nav rail colors
  static const Color _navTop = Color(0xFF1565C0);
  static const Color _navBottom = Color(0xFF1976D2);
  static const Color _navBorder = Color(0xFF1E88E5);

  @override
  void initState() {
    super.initState();
    _currentMode = widget.mode;
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    // REVISI: light mode → outer card biru nav, canvas polar tetap gelap
    // agar warna sensor (hijau/oranye/merah) tetap terbaca. Dark → navy.
    final outerGradient = isLight
        ? const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_navTop, _navBottom],
          )
        : null;
    final outerColor = isLight ? null : _cardColor;
    final outerBorder = isLight
        ? _navBorder.withValues(alpha: 0.70)
        : _borderColor.withValues(alpha: 0.35);
    final outerShadow = isLight
        ? _navTop.withValues(alpha: 0.30)
        : Colors.black.withValues(alpha: 0.35);

    return Container(
      decoration: BoxDecoration(
        color: outerColor,
        gradient: outerGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: outerBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: outerShadow,
            blurRadius: 20,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: _buildVisualization(isLight),
            ),
          ),
          _buildFooter(isLight),
        ],
      ),
    );
  }

  Widget _buildVisualization(bool isLight) {
    // REVISI: light mode → canvas putih agar titik lidar terlihat jelas;
    // dark mode → gelap seperti sebelumnya.
    return Container(
      decoration: BoxDecoration(
        color: isLight ? Colors.white : const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLight
              ? Colors.white.withValues(alpha: 0.20)
              : _borderColor.withValues(alpha: 0.2),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: _getVisualizationWidget(isLight),
      ),
    );
  }

  Widget _getVisualizationWidget(bool isLight) {
    switch (_currentMode) {
      case LidarVisualizationMode.polar:
        return _buildPolarView(isLight);
      case LidarVisualizationMode.cartesian:
        return _buildCartesianView();
      case LidarVisualizationMode.range:
        return _buildRangeChart();
      case LidarVisualizationMode.heatmap:
        return _buildHeatmapView();
      case LidarVisualizationMode.birdEye:
        return _buildBirdEyeView();
      case LidarVisualizationMode.lidar2D:
        return _buildLidar2DView(isLight);
    }
  }

  Widget _buildPolarView(bool isLight) {
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
          // REVISI: pass isLight ke painter untuk penyesuaian warna canvas
          isLight: isLight,
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
          border: Border.all(
            color: _borderColor.withValues(alpha: 0.35),
            width: 1.5,
          ),
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
          border: Border.all(
            color: _borderColor.withValues(alpha: 0.35),
            width: 1.5,
          ),
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

  Widget _buildLidar2DView(bool isLight) {
    // REVISI: light mode → canvas putih agar titik & grid terbaca; dark → hitam
    return Container(
      color: isLight ? Colors.white : const Color(0xFF0A0D13),
      padding: const EdgeInsets.all(4),
      child: CustomPaint(
        painter: Lidar2DScanPainter(
          ranges: widget.lidar2DRanges,
          angleMin: widget.lidar2DAngleMin,
          angleIncrement: widget.lidar2DAngleIncrement,
          rangeMin: widget.lidar2DRangeMin,
          rangeMax: widget.lidar2DRangeMax,
          viewRangeMeters: 20.0,
          title: 'MEVI - Single LiDAR Scan',
          isLight: isLight,
        ),
        size: Size.infinite,
      ),
    );
  }

  Widget _buildFooter(bool isLight) {
    // REVISI: footer light mode → biru sedikit lebih gelap dari outer card
    // agar ada pemisah visual antara canvas dan footer. Teks & icon putih.
    final footerColor = isLight ? const Color(0xFF1254A8) : _surfaceColor;
    final footerBorderTop = isLight
        ? Colors.white.withValues(alpha: 0.20)
        : _gridColor;
    final statTextPrimary = isLight ? Colors.white : _textPrimary;
    final statTextSecondary = isLight ? Colors.white70 : _textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: footerColor,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        border: Border(top: BorderSide(color: footerBorderTop, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                _buildStatItem(
                  'Data Points',
                  '${_currentMode == LidarVisualizationMode.lidar2D ? widget.lidar2DRanges.length : widget.ranges.length}',
                  _accentColor,
                  Icons.scatter_plot_rounded,
                  statTextPrimary,
                  statTextSecondary,
                ),
                const SizedBox(width: 12),
                _buildStatItem(
                  'Max Range',
                  '${(_currentMode == LidarVisualizationMode.lidar2D ? widget.lidar2DRangeMax : widget.rangeMax).toStringAsFixed(1)}m',
                  isLight ? Colors.white : _primaryColor,
                  Icons.straighten_rounded,
                  statTextPrimary,
                  statTextSecondary,
                ),
              ],
            ),
          ),
          _buildModeSelector(isLight),
          const SizedBox(width: 12),
          // SCANNING badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _accentColor.withValues(alpha: isLight ? 0.20 : 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _accentColor.withValues(alpha: isLight ? 0.40 : 0.2),
              ),
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
    Color textPrimary,
    Color textSecondary,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.20)),
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
                  color: textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: textSecondary,
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

  Widget _buildModeSelector(bool isLight) {
    // REVISI: light mode → selector pill putih transparan (contrast on blue),
    // popup menu biru nav. Dark mode → navy gelap.
    final selectorBg = isLight
        ? Colors.white.withValues(alpha: 0.18)
        : _primaryColor.withValues(alpha: 0.1);
    final selectorBorder = isLight
        ? Colors.white.withValues(alpha: 0.40)
        : _primaryColor.withValues(alpha: 0.2);
    final selectorTextClr = isLight ? Colors.white : _primaryColor;
    final popupBg = isLight ? const Color(0xFF1565C0) : _cardColor;
    final popupTextSelected = isLight ? Colors.white : _primaryColor;
    final popupTextNormal = isLight ? Colors.white70 : _textPrimary;

    return PopupMenuButton<LidarVisualizationMode>(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: popupBg,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selectorBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selectorBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_getModeIcon(_currentMode), color: selectorTextClr, size: 14),
            const SizedBox(width: 6),
            Text(
              _getModeDisplayName(_currentMode),
              style: TextStyle(
                color: selectorTextClr,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: selectorTextClr,
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
          isLight,
          popupTextSelected,
          popupTextNormal,
        ),
        _buildMenuItem(
          LidarVisualizationMode.cartesian,
          Icons.grid_on_rounded,
          'Cartesian',
          isLight,
          popupTextSelected,
          popupTextNormal,
        ),
        _buildMenuItem(
          LidarVisualizationMode.range,
          Icons.show_chart_rounded,
          'Range Chart',
          isLight,
          popupTextSelected,
          popupTextNormal,
        ),
        _buildMenuItem(
          LidarVisualizationMode.heatmap,
          Icons.gradient_rounded,
          'Heatmap',
          isLight,
          popupTextSelected,
          popupTextNormal,
        ),
        _buildMenuItem(
          LidarVisualizationMode.birdEye,
          Icons.visibility_rounded,
          'Bird\'s Eye',
          isLight,
          popupTextSelected,
          popupTextNormal,
        ),
        _buildMenuItem(
          LidarVisualizationMode.lidar2D,
          Icons.explore_rounded,
          '2D LiDAR',
          isLight,
          popupTextSelected,
          popupTextNormal,
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
      case LidarVisualizationMode.lidar2D:
        return Icons.explore_rounded;
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
      case LidarVisualizationMode.lidar2D:
        return '2D LiDAR';
    }
  }

  PopupMenuItem<LidarVisualizationMode> _buildMenuItem(
    LidarVisualizationMode mode,
    IconData icon,
    String label,
    bool isLight,
    Color textSelected,
    Color textNormal,
  ) {
    final isSelected = _currentMode == mode;
    // icon accent: tetap neon blue di dark, putih di light saat selected
    final iconAccent = isLight
        ? (isSelected ? Colors.white : Colors.white60)
        : (isSelected ? _primaryColor : _textSecondary);
    final iconBg = isSelected
        ? (isLight
              ? Colors.white.withValues(alpha: 0.20)
              : _primaryColor.withValues(alpha: 0.10))
        : Colors.transparent;

    return PopupMenuItem(
      value: mode,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: iconAccent),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? textSelected : textNormal,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                fontSize: 13,
              ),
            ),
            if (isSelected) ...[
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: isLight ? Colors.white : _primaryColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check,
                  size: 10,
                  color: isLight ? const Color(0xFF1565C0) : Colors.white,
                ),
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
