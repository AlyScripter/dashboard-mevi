import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:dashboardmevi/config/api_keys.dart';
import 'package:dashboardmevi/core/theme/colors.dart';

class WeatherTimeWidget extends StatefulWidget {
  const WeatherTimeWidget({
    super.key,
    this.embedded = false,
    this.showWeather = true,
    this.compactMode = false,
  });
  final bool embedded;
  final bool showWeather;
  final bool compactMode; // For smaller display in DataPage

  @override
  _WeatherTimeWidgetState createState() => _WeatherTimeWidgetState();
}

class _WeatherTimeWidgetState extends State<WeatherTimeWidget> {
  late Timer _timer;
  Timer? _weatherTimer;
  String _currentTime = '';

  final String _city = 'Bandung,Indonesia';

  String? _temperature;
  String? _weatherCondition;
  IconData? _weatherIcon;

  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());

    if (widget.showWeather) {
      _fetchWeather();
      _weatherTimer = Timer.periodic(
        const Duration(minutes: 10),
        (_) => _fetchWeather(),
      );
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    _weatherTimer?.cancel();
    super.dispose();
  }

  void _updateTime() {
    setState(() {
      _currentTime = DateFormat('H.mm').format(DateTime.now());
    });
  }

  Future<void> _fetchWeather() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    final url = Uri.parse(
      'http://api.weatherapi.com/v1/current.json?key=${ApiKeys.weatherApiKey}&q=$_city&aqi=no',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final description = data['current']['condition']['text'];
        final temperature = data['current']['temp_c'];

        if (mounted) {
          setState(() {
            _weatherCondition = _formatWeatherDescription(description);
            _weatherIcon = _getWeatherIcon(description);
            _temperature = '${temperature.round()}°C';
            _isLoading = false;
            _hasError = false;
          });
        }
      } else {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    } catch (error) {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  String _formatWeatherDescription(String description) {
    if (description.isEmpty) return 'Unknown';
    return description[0].toUpperCase() + description.substring(1);
  }

  IconData _getWeatherIcon(String description) {
    final condition = description.toLowerCase();

    if (condition.contains('clear') || condition.contains('sunny')) {
      return LucideIcons.sun;
    } else if (condition.contains('rain') || condition.contains('drizzle')) {
      return LucideIcons.cloudRain;
    } else if (condition.contains('thunder') || condition.contains('storm')) {
      return LucideIcons.cloudLightning;
    } else if (condition.contains('snow')) {
      return LucideIcons.cloudSnow;
    } else if (condition.contains('fog') || condition.contains('mist')) {
      return LucideIcons.cloudFog;
    } else if (condition.contains('cloud')) {
      return LucideIcons.cloud;
    } else {
      return LucideIcons.cloud;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    // --- THEME-AWARE COLORS ---
    // REVISI: compactMode + light → gradient persis nav rail
    // (0xFF1565C0 top → 0xFF1976D2 bottom), border 0xFF1E88E5, teks/icon putih.
    final useNavStyle = isLight && widget.compactMode;

    final bgColor = useNavStyle
        ? null
        : isLight
        ? Colors.white
        : AppColors.glassNavyTint;
    final bgGradient = useNavStyle
        ? const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
          )
        : null;
    final borderColor = useNavStyle
        ? const Color(0xFF1E88E5)
        : isLight
        ? AppColors.primary.withValues(alpha: 0.35)
        : AppColors.glassBlueBorder.withValues(alpha: 0.85);
    final shadowColor = useNavStyle
        ? const Color(0xFF1565C0).withValues(alpha: 0.35)
        : isLight
        ? Colors.black.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.35);
    final textPrimary = useNavStyle
        ? Colors.white
        : isLight
        ? const Color(0xFF1A1A2E)
        : AppColors.glassTextPrimary;
    final textSecondary = useNavStyle
        ? Colors.white70
        : isLight
        ? const Color(0xFF555577)
        : AppColors.glassTextSecondary;
    final iconColor = useNavStyle
        ? Colors.white
        : isLight
        ? AppColors.primary
        : const Color(0xFF7DB4FF);

    return LayoutBuilder(
      builder: (context, constraints) {
        final data = MediaQuery.of(context);
        final screenW = data.size.width;
        final screenH = data.size.height;
        final availW =
            (constraints.maxWidth.isFinite && constraints.maxWidth > 0)
            ? constraints.maxWidth
            : screenW;

        final diagonal =
            sqrt(screenW * screenW + screenH * screenH) / data.devicePixelRatio;
        final isLargeScreen = diagonal >= 700;
        final isTablet = diagonal >= 500 && diagonal < 700;
        final compact = widget.compactMode || availW < 380 || screenW < 420;

        final timeFont = widget.embedded
            ? 18.0
            : widget.compactMode
            ? (isLargeScreen
                  ? 15.0
                  : isTablet
                  ? 13.0
                  : 12.0)
            : (isLargeScreen
                  ? 20.0
                  : compact
                  ? 14.0
                  : 17.0);
        final weatherFont = widget.compactMode
            ? (isLargeScreen
                  ? 12.0
                  : isTablet
                  ? 11.0
                  : 10.0)
            : (isLargeScreen
                  ? 14.0
                  : compact
                  ? 11.0
                  : 13.0);
        final iconSize = widget.compactMode
            ? (isLargeScreen
                  ? 16.0
                  : isTablet
                  ? 14.0
                  : 13.0)
            : (isLargeScreen
                  ? 22.0
                  : compact
                  ? 15.0
                  : 19.0);
        final gap = widget.compactMode
            ? (isLargeScreen
                  ? 8.0
                  : isTablet
                  ? 6.0
                  : 5.0)
            : (isLargeScreen
                  ? 12.0
                  : compact
                  ? 6.0
                  : 10.0);
        // REVISI: containerHeight compactMode difix ke 34px
        final containerHeight = widget.embedded
            ? null
            : widget.compactMode
            ? 34.0
            : (isLargeScreen
                  ? 56.0
                  : compact
                  ? 34.0
                  : 48.0);
        // REVISI: horizontalPadding compactMode = 10px
        final horizontalPadding = widget.compactMode
            ? 10.0
            : (isLargeScreen
                  ? 16.0
                  : compact
                  ? 10.0
                  : 14.0);

        final content = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _currentTime,
              style: TextStyle(
                fontSize: timeFont,
                fontWeight: FontWeight.w900,
                color: textPrimary,
              ),
            ),
            if (widget.showWeather) ...[
              SizedBox(width: gap),
              if (_isLoading)
                SizedBox(
                  width: iconSize,
                  height: iconSize,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: iconColor,
                  ),
                )
              else if (_hasError)
                IconButton(
                  icon: Icon(LucideIcons.refreshCw, size: iconSize),
                  color: Colors.redAccent,
                  tooltip: "Retry",
                  onPressed: _fetchWeather,
                )
              else if (_weatherCondition != null &&
                  _temperature != null &&
                  _weatherIcon != null) ...[
                Icon(_weatherIcon, size: iconSize, color: iconColor),
                SizedBox(width: gap / 1.2),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: availW * 0.45),
                  child: Text(
                    '$_weatherCondition $_temperature',
                    style: TextStyle(
                      fontSize: weatherFont,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ],
        );

        // THEME-AWARE box: gradient nav rail di compactMode+light,
        // putih bersih di light non-compact, navy di dark.
        final box = Container(
          height: containerHeight,
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            // vertical 0 di compactMode — height sudah fix
            vertical: widget.compactMode ? 0 : 8,
          ),
          decoration: BoxDecoration(
            color: bgColor,
            gradient: bgGradient,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: 1.0),
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [content],
          ),
        );

        if (widget.embedded) {
          return Padding(padding: const EdgeInsets.all(0), child: content);
        }

        return ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isLargeScreen
                ? 420
                : compact
                ? 220
                : 380,
          ),
          child: SizedBox(height: containerHeight ?? 48, child: box),
        );
      },
    );
  }
}
