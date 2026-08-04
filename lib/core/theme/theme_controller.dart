import 'package:flutter/material.dart';

// Simple global theme controller used to switch ThemeMode at runtime.
// Other parts of the app can update `appThemeMode.value` to change theme.
final ValueNotifier<ThemeMode> appThemeMode = ValueNotifier(ThemeMode.system);
