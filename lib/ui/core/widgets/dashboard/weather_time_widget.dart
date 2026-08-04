import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:dashboardmevi/config/api_keys.dart';

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
    return LayoutBuilder(
      builder: (context, constraints) {
        // Determine available width and device type
        final data = MediaQuery.of(context);
        final screenW = data.size.width;
        final screenH = data.size.height;
        final availW =
            (constraints.maxWidth.isFinite && constraints.maxWidth > 0)
                ? constraints.maxWidth
                : screenW;

        // Calculate diagonal to detect device type (laptop vs tablet)
        final diagonal =
            sqrt(screenW * screenW + screenH * screenH) / data.devicePixelRatio;
        final isLargeScreen = diagonal >= 700; // ~13 inches threshold
        final isTablet =
            diagonal >= 500 && diagonal < 700; // ~10-13 inches (Infinix XPAD)
        final compact = widget.compactMode || availW < 380 || screenW < 420;

        // Use smaller sizes when in compactMode (for DataPage)
        final timeFont = widget.embedded
            ? 20.0
            : widget.compactMode
                ? (isLargeScreen
                    ? 18.0
                    : isTablet
                        ? 16.0
                        : 14.0)
                : (isLargeScreen
                    ? 24.0
                    : compact
                        ? 16.0
                        : 20.0);
        final weatherFont = widget.compactMode
            ? (isLargeScreen
                ? 14.0
                : isTablet
                    ? 12.0
                    : 11.0)
            : (isLargeScreen
                ? 18.0
                : compact
                    ? 12.0
                    : 16.0);
        final iconSize = widget.compactMode
            ? (isLargeScreen
                ? 20.0
                : isTablet
                    ? 18.0
                    : 16.0)
            : (isLargeScreen
                ? 28.0
                : compact
                    ? 18.0
                    : 24.0);
        final gap = widget.compactMode
            ? (isLargeScreen
                ? 10.0
                : isTablet
                    ? 8.0
                    : 6.0)
            : (isLargeScreen
                ? 16.0
                : compact
                    ? 8.0
                    : 12.0);
        final containerHeight = widget.embedded
            ? null
            : widget.compactMode
                ? (isLargeScreen
                    ? 48.0
                    : isTablet
                        ? 42.0
                        : 36.0)
                : (isLargeScreen
                    ? 70.0
                    : compact
                        ? 38.0
                        : 58.0);
        final horizontalPadding = widget.compactMode
            ? (isLargeScreen
                ? 14.0
                : isTablet
                    ? 12.0
                    : 10.0)
            : (isLargeScreen
                ? 20.0
                : compact
                    ? 12.0
                    : 16.0);

        final content = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _currentTime,
              style: TextStyle(
                fontSize: timeFont,
                fontWeight: FontWeight.w900,
                color: Colors.black87,
              ),
            ),
            if (widget.showWeather) ...[
              SizedBox(width: gap),
              if (_isLoading)
                SizedBox(
                  width: iconSize,
                  height: iconSize,
                  child: const CircularProgressIndicator(strokeWidth: 2),
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
                Icon(_weatherIcon, size: iconSize, color: Colors.black87),
                SizedBox(width: gap / 1.2),
                // Make weather text flexible so it wraps or truncates based on space
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: availW * 0.45),
                  child: Text(
                    '$_weatherCondition $_temperature',
                    style: TextStyle(
                      fontSize: weatherFont,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ],
        );

        final box = Container(
          height: containerHeight,
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [content]),
        );

        if (widget.embedded) {
          return Padding(padding: const EdgeInsets.all(0), child: content);
        }

        return ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isLargeScreen
                ? 520
                : compact
                    ? 260
                    : 480, // Match search bar width for tablet
          ),
          child: SizedBox(height: containerHeight ?? 56, child: box),
        );
      },
    );
  }
}
