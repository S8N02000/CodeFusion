// lib/src/settings/settings_view.dart
import 'package:flutter/material.dart';
import 'settings_controller.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key, required this.controller});

  static const routeName = '/settings';

  final SettingsController controller;

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  // AJOUT : Contrôleur pour le champ de texte
  late final TextEditingController _ignoredFoldersController;

  @override
  void initState() {
    super.initState();
    // Initialise le champ de texte avec les valeurs actuelles, séparées par des virgules
    _ignoredFoldersController = TextEditingController(
      text: widget.controller.ignoredFolders.join(', '),
    );
  }

  @override
  void dispose() {
    _ignoredFoldersController.dispose();
    super.dispose();
  }

  // AJOUT : Méthode pour sauvegarder
  void _saveIgnoredFolders() {
    // Transforme la chaîne "dossier1, dossier2" en une liste propre ['dossier1', 'dossier2']
    final folders = _ignoredFoldersController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    widget.controller.updateIgnoredFolders(folders);

    // Feedback pour l'utilisateur
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Liste des dossiers à ignorer sauvegardée !')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          // AJOUT : Bouton de sauvegarde
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveIgnoredFolders,
            tooltip: 'Sauvegarder les changements',
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView( // Utiliser ListView pour éviter les problèmes de dépassement
          children: [
            const Text('Theme Mode'),
            // ... (Dropdown ThemeMode inchangé)
            const SizedBox(height: 20),
            const Text('Path Display Option'),
            // ... (Dropdown PathOption inchangé)
            const SizedBox(height: 20),

            // AJOUT : Section pour les dossiers à ignorer
            const Text('Dossiers et fichiers à ignorer'),
            const SizedBox(height: 8),
            Text(
              'Entrez les noms séparés par des virgules.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _ignoredFoldersController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'node_modules, .git, build, ...',
              ),
              onSubmitted: (_) => _saveIgnoredFolders(), // Sauvegarde aussi avec "Entrée"
            ),
          ],
        ),
      ),
    );
  }
}