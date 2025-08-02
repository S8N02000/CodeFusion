import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'src/app.dart';
// CORRECTION : Import manquant, ajouté pour que 'selectedDirectoryProvider' soit reconnu.
import 'src/home_view/state_providers.dart';
import 'src/settings/settings_controller.dart';
import 'src/settings/settings_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settingsController = SettingsController(SettingsService());
  await settingsController.loadSettings();

  runApp(
    ProviderScope(
      overrides: [
        selectedDirectoryProvider.overrideWith((ref) => settingsController.lastUsedDirectory),
      ],
      child: App(settingsController: settingsController),
    ),
  );
}