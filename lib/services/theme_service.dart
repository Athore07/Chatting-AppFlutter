import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService with ChangeNotifier {
  static const String _themeKey = 'is_dark_mode';

  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;

  ThemeService() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool(_themeKey) ?? false;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, _isDarkMode);
    notifyListeners();
  }

  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  // Just use default themes with primary color
  ThemeData get lightTheme => ThemeData.light().copyWith(
    primaryColor: Colors.blue,
    colorScheme: const ColorScheme.light(primary: Colors.blue),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.blue,
      foregroundColor: Colors.white,
    ),
  );

  ThemeData get darkTheme => ThemeData.dark().copyWith(
    primaryColor: Colors.blue.shade700,
    colorScheme: ColorScheme.dark(primary: Colors.blue.shade700),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.grey.shade900,
      foregroundColor: Colors.white,
    ),
  );
}