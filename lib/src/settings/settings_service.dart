// lib/src/settings/settings_service.dart
import 'package:code_fusion/src/settings/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();

  // Clés de sauvegarde
  static const String _themeModeKey = 'themeMode';
  static const String _pathOptionKey = 'pathOption';
  // AJOUT : Nouvelles clés pour nos nouvelles fonctionnalités
  static const String _ignoredFoldersKey = 'ignoredFolders';
  static const String _lastUsedDirectoryKey = 'lastUsedDirectory';
  
  // Liste par défaut des dossiers à ignorer
  static const List<String> _defaultIgnoredFolders = [
    'node_modules',
    '.git',
    '.dart_tool',
    '.vscode',
    '.idea',
  ];

  // --- Theme & Path --- (inchangé)
  Future<ThemeMode> themeMode() async {
    final prefs = await _prefs;
    final mode = prefs.getString(_themeModeKey);
    return ThemeMode.values.firstWhere((e) => e.toString() == mode, orElse: () => ThemeMode.system);
  }
  Future<void> updateThemeMode(ThemeMode theme) async {
    final prefs = await _prefs;
    await prefs.setString(_themeModeKey, theme.toString());
  }
  Future<PathOption> pathOption() async {
    final prefs = await _prefs;
    final option = prefs.getString(_pathOptionKey);
    return PathOption.values.firstWhere((e) => e.toString() == option, orElse: () => PathOption.relative);
  }
  Future<void> updatePathOption(PathOption option) async {
    final prefs = await _prefs;
    await prefs.setString(_pathOptionKey, option.toString());
  }

  // --- AJOUT : Logique pour les dossiers à ignorer ---
  Future<List<String>> ignoredFolders() async {
    final prefs = await _prefs;
    // Charge la liste, si elle n'existe pas, retourne la liste par défaut
    return prefs.getStringList(_ignoredFoldersKey) ?? _defaultIgnoredFolders;
  }

  Future<void> updateIgnoredFolders(List<String> folders) async {
    final prefs = await _prefs;
    await prefs.setStringList(_ignoredFoldersKey, folders);
  }

  // --- AJOUT : Logique pour le dernier dossier utilisé ---
  Future<String?> lastUsedDirectory() async {
    final prefs = await _prefs;
    return prefs.getString(_lastUsedDirectoryKey);
  }

  Future<void> updateLastUsedDirectory(String path) async {
    final prefs = await _prefs;
    await prefs.setString(_lastUsedDirectoryKey, path);
  }
}