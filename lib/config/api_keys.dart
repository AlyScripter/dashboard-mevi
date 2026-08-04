// API Keys Configuration
// This file loads API keys from .env file for security

import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiKeys {
  // MapBox API Key - Get from https://account.mapbox.com/
  static String get mapboxAccessToken {
    final key = dotenv.env['MAPBOX_ACCESS_TOKEN'];
    if (key == null || key.isEmpty) {
      throw Exception('MAPBOX_ACCESS_TOKEN not found in .env file');
    }
    return key;
  }

  // WeatherAPI Key - Get from https://www.weatherapi.com/
  static String get weatherApiKey {
    final key = dotenv.env['WEATHER_API_KEY'];
    if (key == null || key.isEmpty) {
      throw Exception('WEATHER_API_KEY not found in .env file');
    }
    return key;
  }

  // OpenRouteService API Key - Get from https://openrouteservice.org/dev/#/signup
  static String get openRouteServiceApiKey {
    final key = dotenv.env['OPENROUTE_SERVICE_API_KEY'];
    if (key == null || key.isEmpty) {
      throw Exception('OPENROUTE_SERVICE_API_KEY not found in .env file');
    }
    return key;
  }
}
