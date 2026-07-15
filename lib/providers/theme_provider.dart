import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../core/theme/app_colors.dart';

class ThemeProvider extends ChangeNotifier {
  final StorageService _storageService;
  late ThemeMode _themeMode;
  Color _currentBrandColor = AppColors.primaryGreen;

  ThemeProvider(this._storageService) {
    _loadTheme();
  }

  ThemeMode get themeMode => _themeMode;
  Color get currentBrandColor => _currentBrandColor;

  void setBrandTheme(String brand) {
    switch (brand.toLowerCase()) {
      case 'tata':
        _currentBrandColor = AppColors.brandTata;
        break;
      case 'mg':
        _currentBrandColor = AppColors.brandMG;
        break;
      case 'mahindra':
        _currentBrandColor = AppColors.brandMahindra;
        break;
      case 'byd':
        _currentBrandColor = AppColors.brandBYD;
        break;
      case 'hyundai':
        _currentBrandColor = AppColors.brandHyundai;
        break;
      case 'kia':
        _currentBrandColor = AppColors.brandKia;
        break;
      case 'bmw':
        _currentBrandColor = AppColors.brandBMW;
        break;
      case 'mercedes':
        _currentBrandColor = AppColors.brandMercedes;
        break;
      default:
        _currentBrandColor = AppColors.primaryGreen;
    }
    notifyListeners();
  }

  bool get isDarkMode {
    if (_themeMode == ThemeMode.system) {
      return WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }

  void _loadTheme() {
    final themeStr = _storageService.getThemeMode();
    _themeMode = _parseThemeMode(themeStr);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _storageService.setThemeMode(_themeModeToString(mode));
    notifyListeners();
  }

  ThemeMode _parseThemeMode(String themeStr) {
    switch (themeStr) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }
}
