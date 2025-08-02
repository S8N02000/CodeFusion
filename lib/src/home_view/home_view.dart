import 'dart:io';
import 'dart:ui'; // Import pour BackdropFilter

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
    final expandedFolders = ref.watch(expandedFoldersProvider);

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
            icon: const Icon(Icons.folder_zip_outlined),
            tooltip: 'Tout réduire',
            onPressed: expandedFolders.isNotEmpty
                ? () => ref.read(expandedFoldersProvider.notifier).state = {}
                : null,
          ),
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
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Expanded(
              child: _buildBody(context, selectedDirectory, fileTreeAsync),
            ),
            if (selectedDirectory != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: selectedNodes.isNotEmpty ? _exportSelectedFilesToFile : null,
                      icon: const Icon(Icons.save_as_outlined, size: 16),
                      label: const Text('Exporter'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: selectedNodes.isNotEmpty ? _copySelectedFilesToClipboard : null,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_isCopied ? Icons.check_circle_outline : Icons.content_copy, size: 16.0),
                          const SizedBox(width: 8),
                          if (_isCopied)
                            const Text('Copié !')
                          else
                            tokenCountAsync.when(
                              data: (count) => Text('Copier (~${_formatTokens(count)})'),
                              loading: () => const Row(children: [Text('Calcul...'), SizedBox(width:12, height:12, child: CircularProgressIndicator(strokeWidth:2, color: Colors.white))]),
                              error: (e, s) => const Text('Erreur'),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassPanel({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          decoration: BoxDecoration(
            // AJUSTEMENT : Une opacité légèrement plus faible pour un look plus subtil.
            color: Theme.of(context).colorScheme.background.withOpacity(0.65),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.1), width: 0.5),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, String? selectedDirectory, AsyncValue<FileNode?> fileTreeAsync) {
    if (selectedDirectory == null) {
      return Center(
        key: const ValueKey('welcome'),
        child: ElevatedButton(
          onPressed: _pickDirectory,
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16)),
          child: const Text("Sélectionner un dossier de projet"),
        )
      );
    }

    return _buildGlassPanel(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: fileTreeAsync.when(
          loading: () => Center(key: const ValueKey('loading'), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: const [CircularProgressIndicator(), SizedBox(height: 16), Text('Analyse du projet...')])),
          error: (error, stack) {
            if (error is Exception && error.toString().contains('Scan cancelled')) {
              return Center(key: const ValueKey('loading-cancelled'), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: const [CircularProgressIndicator(), SizedBox(height: 16), Text('Changement de dossier...')]));
            }
            return Center(key: const ValueKey('error'), child: Padding(padding: const EdgeInsets.all(16.0), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.error_outline, color: Colors.red, size: 48), const SizedBox(height: 16), const Text('Une erreur est survenue.', textAlign: TextAlign.center), Text('Vérifiez les permissions du dossier.', style: Theme.of(context).textTheme.bodySmall), const SizedBox(height: 16), ElevatedButton(onPressed: () => ref.invalidate(fileTreeProvider), child: const Text('Réessayer'))])));
          },
          data: (fileTree) {
            final fileMetadata = ref.watch(fileSvgIconMetadataLoaderProvider);
            final folderMetadata = ref.watch(folderSvgIconMetadataLoaderProvider);
            return fileMetadata.when(
              data: (fm) => folderMetadata.when(
                  data: (fom) => FileListPanel(key: const ValueKey('data-panel'), fileSvgIconMetadata: fm, folderSvgIconMetadata: fom),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, s) => const Center(child: Text("Erreur icônes dossiers"))),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => const Center(child: Text("Erreur icônes fichiers")));
          },
        ),
      ),
    );
  }

  Future<String> _generateCombinedContent() async {
    final settingsController = ref.read(settingsControllerProvider);
    final selectedPaths = ref.read(selectedNodesProvider);
    final rootPath = ref.read(selectedDirectoryProvider);
    if (rootPath == null) return "";

    final List<Future<String>> contentFutures = [];
    for (var filePath in selectedPaths) {
      if (await FileSystemEntity.isDirectory(filePath)) continue;
      contentFutures.add(Future(() async {
        try {
          final file = File(filePath);
          final fileContent = await file.readAsString();
          final displayPath = settingsController.pathOption == PathOption.full ? filePath : path.relative(filePath, from: rootPath);
          return '### START OF FILE: $displayPath ###\n$fileContent\n### END OF FILE: $displayPath ###\n\n';
        } catch (e) {
          return '';
        }
      }));
    }
    final contents = await Future.wait(contentFutures);
    return contents.join();
  }

  void _pickDirectory() async {
    String? directoryPath = await FilePicker.platform.getDirectoryPath();
    if (directoryPath != null) {
      ref.read(settingsControllerProvider.notifier).updateLastUsedDirectory(directoryPath);
      ref.read(selectedNodesProvider.notifier).state = {};
      ref.read(expandedFoldersProvider.notifier).state = {};
      ref.read(selectedDirectoryProvider.notifier).state = directoryPath;
    }
  }

  void _copySelectedFilesToClipboard() async {
    final combinedContent = await _generateCombinedContent();
    if (combinedContent.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: combinedContent));
      if (!mounted) return;
      setState(() => _isCopied = true);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _isCopied = false);
      });
    }
  }

  void _exportSelectedFilesToFile() async {
    final combinedContent = await _generateCombinedContent();
    if (combinedContent.isEmpty) return;

    try {
      String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Veuillez choisir où sauvegarder votre fichier :',
        fileName: 'code-fusion-export.txt',
      );
      if (outputPath != null) {
        final file = File(outputPath);
        await file.writeAsString(combinedContent);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Fichier exporté avec succès vers $outputPath')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'exportation du fichier : $e')),
        );
      }
    }
  }

  String _formatTokens(int tokens) {
    if (tokens >= 1000) return '${(tokens / 1000).toStringAsFixed(1)}k';
    return tokens.toString();
  }
}