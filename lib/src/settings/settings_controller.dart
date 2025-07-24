// lib/src/settings/settings_controller.dart
import 'package:flutter/material.dart';
import 'settings_service.dart';

enum PathOption { full, relative }

class SettingsController with ChangeNotifier {
  SettingsController(this._settingsService);

  final SettingsService _settingsService;

  late ThemeMode _themeMode;
  ThemeMode get themeMode => _themeMode;
  
  late PathOption _pathOption;
  PathOption get pathOption => _pathOption;

  // AJOUT : État pour les nouvelles propriétés
  late List<String> _ignoredFolders;
  List<String> get ignoredFolders => _ignoredFolders;

  String? _lastUsedDirectory;
  String? get lastUsedDirectory => _lastUsedDirectory;

  Future<void> loadSettings() async {
    _themeMode = await _settingsService.themeMode();
    _pathOption = await _settingsService.pathOption();
    _ignoredFolders = await _settingsService.ignoredFolders(); // Charger
    _lastUsedDirectory = await _settingsService.lastUsedDirectory(); // Charger
    notifyListeners();
  }

  Future<void> updateThemeMode(ThemeMode? newThemeMode) async {
    if (newThemeMode == null || newThemeMode == _themeMode) return;
    _themeMode = newThemeMode;
    notifyListeners();
    await _settingsService.updateThemeMode(newThemeMode);
  }
  
  Future<void> updatePathOption(PathOption newPathOption) async {
    if (newPathOption == _pathOption) return;
    _pathOption = newPathOption;
    notifyListeners();
    await _settingsService.updatePathOption(newPathOption);
  }
  
  // AJOUT : Méthodes pour mettre à jour nos nouvelles propriétés
  Future<void> updateIgnoredFolders(List<String> newIgnoredFolders) async {
    _ignoredFolders = newIgnoredFolders;
    notifyListeners();
    await _settingsService.updateIgnoredFolders(newIgnoredFolders);
  }

  Future<void> updateLastUsedDirectory(String newPath) async {
    _lastUsedDirectory = newPath;
    notifyListeners();
    await _settingsService.updateLastUsedDirectory(newPath);
  }
}