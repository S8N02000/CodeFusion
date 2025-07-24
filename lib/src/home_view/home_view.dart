import 'dart:io';

import 'package:code_fusion/src/home_view/file_list_panel.dart';
import 'package:code_fusion/src/home_view/state_providers.dart';
import 'package:code_fusion/src/home_view/utils.dart';
import 'package:code_fusion/src/settings/settings_controller.dart';
import 'package:code_fusion/src/settings/settings_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;

class HomeView extends ConsumerStatefulWidget {
  const HomeView({super.key, required this.controller});

  final SettingsController controller;
  static const routeName = '/';

  @override
  HomeViewState createState() => HomeViewState();
}

class HomeViewState extends ConsumerState<HomeView> {
  // Garder un état local uniquement pour les animations de l'UI comme "Copié !"
  bool _isCopied = false;

  @override
  Widget build(BuildContext context) {
    // Surveiller les providers nécessaires pour la vue
    final fileMetadata = ref.watch(fileSvgIconMetadataLoaderProvider);
    final folderMetadata = ref.watch(folderSvgIconMetadataLoaderProvider);
    final tokenCountAsync = ref.watch(estimatedTokenCountProvider);
    final selectedDirectory = ref.watch(selectedDirectoryProvider);
    final selectedNodes = ref.watch(selectedNodesProvider);

    return Scaffold(
      appBar: AppBar(
        title: selectedDirectory != null
            ? Consumer(builder: (context, ref, _) {
                // Le titre affiche le dossier racine sélectionné
                return folderMetadata.when(
                  data: (folderSvgIconMetadata) => ElevatedButton.icon(
                    onPressed: _pickDirectory,
                    icon: folderIconWidget(
                        path.basename(selectedDirectory), folderSvgIconMetadata),
                    label: Text(path.basename(selectedDirectory)),
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: Colors.transparent,
                    ),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (e, s) => const Icon(Icons.error),
                );
              })
            : const Text('CodeFusion'), // Titre par défaut
        actions: [
          IconButton(
            icon: const Icon(Icons.deselect),
            tooltip: 'Tout désélectionner',
            // Activer le bouton seulement si des éléments sont sélectionnés
            onPressed: selectedNodes.isNotEmpty
                ? () {
                    // La désélection est une simple modification du provider
                    ref.read(selectedNodesProvider.notifier).state = {};
                  }
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Rafraîchir la liste des fichiers',
            // Activer le bouton seulement si un dossier est ouvert
            onPressed: selectedDirectory != null ? () => _refreshAll(ref) : null,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.restorablePushNamed(context, SettingsView.routeName);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: selectedDirectory == null
                ? Center(
                    // Écran d'accueil pour inviter à sélectionner un dossier
                    child: ElevatedButton(
                      onPressed: _pickDirectory,
                      child: const Text("Sélectionner un dossier pour commencer"),
                    ),
                  )
                : fileMetadata.when(
                    // Une fois le dossier sélectionné, on charge les icônes
                    // puis on affiche le panneau de fichiers.
                    data: (fileSvgIconMetadata) => folderMetadata.when(
                      data: (folderSvgIconMetadata) => FileListPanel(
                        fileSvgIconMetadata: fileSvgIconMetadata,
                        folderSvgIconMetadata: folderSvgIconMetadata,
                      ),
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (error, stack) =>
                          const Center(child: Text('Erreur de chargement des icônes de dossiers')),
                    ),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (error, stack) =>
                        const Center(child: Text('Erreur de chargement des icônes de fichiers')),
                  ),
          ),
          // Le bouton de copie n'apparaît que si un dossier est sélectionné
          if (selectedDirectory != null)
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: ElevatedButton(
                onPressed: selectedNodes.isNotEmpty ? _copySelectedFilesToClipboard : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icone dynamique : check si copié, sinon icone de copie
                    Icon(_isCopied ? Icons.check : Icons.content_copy, size: 16.0),
                    const SizedBox(width: 8),
                    // Texte dynamique : gère l'état "copié", le chargement et l'affichage des tokens
                    if (_isCopied)
                      const Text('Copié dans le presse-papiers !')
                    else
                      tokenCountAsync.when(
                        data: (count) => Text('Copier le code (~${_formatTokens(count)} tokens)'),
                        loading: () => const Row(
                          children: [
                            Text('Calcul... '),
                            SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ],
                        ),
                        error: (e, s) => const Text('Erreur de calcul'),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Ouvre le sélecteur de fichiers pour choisir un dossier.
  void _pickDirectory() async {
    String? directoryPath = await FilePicker.platform.getDirectoryPath();
    if (directoryPath != null) {
      // Réinitialiser les états précédents avant de charger le nouveau dossier
      ref.read(selectedNodesProvider.notifier).state = {};
      ref.read(expandedFoldersProvider.notifier).state = {};

      // Mettre à jour le provider du dossier sélectionné.
      // Riverpod s'occupera de déclencher le scan via `fileTreeProvider`.
      ref.read(selectedDirectoryProvider.notifier).state = directoryPath;
    }
  }

  /// Rafraîchit l'arborescence des fichiers en invalidant le provider principal.
  void _refreshAll(WidgetRef ref) {
    // Invalider un provider force sa ré-exécution. C'est la manière propre
    // de déclencher un rafraîchissement avec Riverpod.
    ref.invalidate(fileTreeProvider);
  }

  /// Construit le contenu des fichiers sélectionnés et le copie dans le presse-papiers.
  void _copySelectedFilesToClipboard() async {
    final settingsController = ref.read(settingsControllerProvider);
    final selectedPaths = ref.read(selectedNodesProvider);
    final rootPath = ref.read(selectedDirectoryProvider);

    if (rootPath == null) return;

    // Utilise Future.wait pour lire tous les fichiers en parallèle,
    // ce qui est beaucoup plus rapide que de les lire un par un.
    final List<Future<String>> contentFutures = [];

    for (var filePath in selectedPaths) {
      // On s'assure de ne traiter que les fichiers
      if (FileSystemEntity.typeSync(filePath) != FileSystemEntityType.file) continue;

      contentFutures.add(Future(() async {
        try {
          final file = File(filePath);
          final fileContent = await file.readAsString();

          // Détermine le chemin à afficher selon les préférences de l'utilisateur
          final displayPath = settingsController.pathOption == PathOption.full
              ? filePath
              : path.relative(filePath, from: rootPath);

          return '### START OF FILE: $displayPath ###\n$fileContent\n### END OF FILE: $displayPath ###\n\n';
        } catch (e) {
          // Si un fichier ne peut être lu (ex: binaire, permissions), on retourne une chaîne vide
          // pour ne pas faire échouer toute l'opération.
          debugPrint("Impossible de lire le fichier $filePath: $e");
          return '';
        }
      }));
    }

    // Attend que tous les fichiers soient lus
    final contents = await Future.wait(contentFutures);
    final combinedContent = contents.join();

    if (combinedContent.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: combinedContent));
      if (!mounted) return;
      setState(() => _isCopied = true);

      // Réinitialise l'état du bouton après 2 secondes
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _isCopied = false);
      });
    }
  }

  /// Formatte le nombre de tokens pour une meilleure lisibilité (ex: 1.2k).
  String _formatTokens(int tokens) {
    if (tokens >= 1000) {
      return '${(tokens / 1000).toStringAsFixed(1)}k';
    }
    return tokens.toString();
  }
}