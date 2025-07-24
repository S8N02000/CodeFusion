import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'src/app.dart';
import 'src/home_view/state_providers.dart';
import 'src/settings/settings_controller.dart';
import 'src/settings/settings_service.dart';

void main() async {
  // Garantit que le moteur Flutter est prêt
  WidgetsFlutterBinding.ensureInitialized();

  // Crée le contrôleur qui gère les paramètres de l'application
  final settingsController = SettingsController(SettingsService());

  // Charge les paramètres utilisateur (thème, dossiers ignorés, etc.) avant de construire l'interface
  await settingsController.loadSettings();

  // Lance l'application
  runApp(
    ProviderScope(
      // La magie du pré-chargement se passe ici.
      // On "override" l'état initial du provider du dossier sélectionné
      // avec la valeur que nous avons chargée depuis les paramètres.
      // Si un dossier avait été utilisé la dernière fois, son chemin est injecté,
      // ce qui déclenche automatiquement le scan par `fileTreeProvider`.
      overrides: [
        selectedDirectoryProvider.overrideWith((ref) => settingsController.lastUsedDirectory),
      ],
      child: App(settingsController: settingsController),
    ),
  );
}