import 'package:flutter/material.dart';

// Simple global theme controller used to switch ThemeMode at runtime.
// Other parts of the app can update `appThemeMode.value` to change theme.
// Default: light mode (sesuai permintaan — tombol di nav rail toggle ke dark).
final ValueNotifier<ThemeMode> appThemeMode = ValueNotifier(ThemeMode.light);
