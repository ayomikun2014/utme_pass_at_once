import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

class AppThemeProvider extends ChangeNotifier {
  final String _boxName = 'settings_box';
  final String _themeKey = 'theme_mode';

  // Default to system theme until we load from local storage
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  AppThemeProvider() {
    _loadTheme();
  }

  // --- 1. Load Theme from Local Storage on Startup ---
  Future<void> _loadTheme() async {
    final box = await Hive.openBox(_boxName);
    final savedTheme = box.get(_themeKey);

    if (savedTheme == 'light') {
      _themeMode = ThemeMode.light;
    } else if (savedTheme == 'dark') {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.system;
    }

    notifyListeners(); // Instantly update the UI
  }

  // --- 2. Save Theme to Local Storage ---
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners(); // Update UI immediately so it feels snappy

    final box = await Hive.openBox(_boxName);

    String themeString = 'system';
    if (mode == ThemeMode.light) themeString = 'light';
    if (mode == ThemeMode.dark) themeString = 'dark';

    // Save it permanently to the device
    await box.put(_themeKey, themeString);
  }
}