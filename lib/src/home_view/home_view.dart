import 'dart:io';

import 'package:code_fusion/src/home_view/file_list_panel.dart';
import 'package:code_fusion/src/home_view/state_providers.dart';
import 'package:code_fusion/src/home_view/utils.dart';
import 'package:code_fusion/src/settings/settings_controller.dart';
import 'package:code_fusion/src/settings/settings_view.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  bool _isCopied = false;

  @override
  Widget build(BuildContext context) {
    final selectedDirectory = ref.watch(selectedDirectoryProvider);
    final fileTreeAsync = ref.watch(fileTreeProvider);
    final tokenCountAsync = ref.watch(estimatedTokenCountProvider);
    final selectedNodes = ref.watch(selectedNodesProvider);

    return Scaffold(
      appBar: AppBar(
        title: selectedDirectory != null
            ? Consumer(builder: (context, ref, _) {
                final folderMetadata = ref.watch(folderSvgIconMetadataLoaderProvider);
                return folderMetadata.when(
                  data: (data) => ElevatedButton.icon(
                      onPressed: _pickDirectory,
                      icon: folderIconWidget(path.basename(selectedDirectory), data),
                      label: Text(path.basename(selectedDirectory))),
                  loading: () => Text(path.basename(selectedDirectory)),
                  error: (e, s) => Text(path.basename(selectedDirectory)),
                );
              })
            : const Text('CodeFusion'),
        actions: [
          IconButton(
            icon: const Icon(Icons.deselect),
            tooltip: 'Tout désélectionner',
            onPressed: selectedNodes.isNotEmpty ? () => ref.read(selectedNodesProvider.notifier).state = {} : null,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Rafraîchir la liste',
            onPressed: selectedDirectory != null ? () => ref.invalidate(fileTreeProvider) : null,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.restorablePushNamed(context, SettingsView.routeName),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: selectedDirectory == null
                ? Center(
                    child: ElevatedButton(
                      onPressed: _pickDirectory,
                      child: const Text("Sélectionner un dossier pour commencer"),
                    ),
                  )
                : fileTreeAsync.when(
                    loading: () => const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Scan du dossier en cours...'),
                        ],
                      ),
                    ),
                    error: (error, stack) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red, size: 48),
                            const SizedBox(height: 16),
                            const Text(
                              'Une erreur est survenue lors du scan des fichiers.',
                              textAlign: TextAlign.center,
                            ),
                            Text(
                              'Vérifiez les permissions du dossier et la liste des dossiers ignorés.',
                              style: Theme.of(context).textTheme.bodySmall,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => ref.invalidate(fileTreeProvider),
                              child: const Text('Réessayer'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    data: (fileTree) {
                      final fileMetadata = ref.watch(fileSvgIconMetadataLoaderProvider);
                      final folderMetadata = ref.watch(folderSvgIconMetadataLoaderProvider);
                      return fileMetadata.when(
                        data: (fm) => folderMetadata.when(
                          data: (fom) => FileListPanel(fileSvgIconMetadata: fm, folderSvgIconMetadata: fom),
                          loading: () => const Center(child: CircularProgressIndicator()),
                          error: (e, s) => const Center(child: Text("Erreur de chargement des icônes de dossiers")),
                        ),
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (e, s) => const Center(child: Text("Erreur de chargement des icônes de fichiers")),
                      );
                    },
                  ),
          ),
          if (selectedDirectory != null)
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: ElevatedButton(
                onPressed: selectedNodes.isNotEmpty ? _copySelectedFilesToClipboard : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_isCopied ? Icons.check : Icons.content_copy, size: 16.0),
                    const SizedBox(width: 8),
                    if (_isCopied)
                      const Text('Copié dans le presse-papiers !')
                    else
                      tokenCountAsync.when(
                        data: (count) => Text('Copier le code (~${_formatTokens(count)} tokens)'),
                        loading: () => const Row(
                          children: [
                            Text('Calcul... '),
                            SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
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

  void _pickDirectory() async {
    String? directoryPath = await FilePicker.platform.getDirectoryPath();
    if (directoryPath != null) {
      // Sauvegarde ce chemin pour le prochain lancement de l'app
      ref.read(settingsControllerProvider.notifier).updateLastUsedDirectory(directoryPath);

      // Réinitialise les états de l'UI
      ref.read(selectedNodesProvider.notifier).state = {};
      ref.read(expandedFoldersProvider.notifier).state = {};

      // Met à jour le provider du dossier sélectionné, ce qui déclenchera un nouveau scan
      ref.read(selectedDirectoryProvider.notifier).state = directoryPath;
    }
  }

  void _copySelectedFilesToClipboard() async {
    final settingsController = ref.read(settingsControllerProvider);
    final selectedPaths = ref.read(selectedNodesProvider);
    final rootPath = ref.read(selectedDirectoryProvider);
    if (rootPath == null) return;

    final List<Future<String>> contentFutures = [];
    for (var filePath in selectedPaths) {
      if (await FileSystemEntity.isDirectory(filePath)) continue;
      contentFutures.add(Future(() async {
        try {
          final file = File(filePath);
          final fileContent = await file.readAsString();
          final displayPath = settingsController.pathOption == PathOption.full
              ? filePath
              : path.relative(filePath, from: rootPath);
          return '### START OF FILE: $displayPath ###\n$fileContent\n### END OF FILE: $displayPath ###\n\n';
        } catch (e) {
          debugPrint("Impossible de lire le fichier $filePath: $e");
          return '';
        }
      }));
    }

    final contents = await Future.wait(contentFutures);
    final combinedContent = contents.join();

    if (combinedContent.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: combinedContent));
      if (!mounted) return;
      setState(() => _isCopied = true);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _isCopied = false);
      });
    }
  }

  String _formatTokens(int tokens) {
    if (tokens >= 1000) return '${(tokens / 1000).toStringAsFixed(1)}k';
    return tokens.toString();
  }
}