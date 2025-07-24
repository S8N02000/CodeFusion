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
  String _selectedDirectory = '';

  bool _isCopied = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
  }

  void selectDirectory(WidgetRef ref, String directoryPath) {
    ref
        .read(selectedDirectoryProvider.state)
        .state = directoryPath;
    // Trigger loading of directory contents
    ref.refresh(directoryContentsProvider(directoryPath));
  }

  @override
  Widget build(BuildContext context) {
    final fileMetadata = ref.watch(fileSvgIconMetadataLoaderProvider);
    final folderMetadata = ref.watch(folderSvgIconMetadataLoaderProvider);
    final estimatedTokenCount = ref.watch(estimatedTokenCountProvider);

    // Check if a directory is selected or if the directory is empty
    final files = ref.watch(directoryContentsProvider(_selectedDirectory));
    bool shouldShowPickDirectory = _selectedDirectory.isEmpty ||
        (files.hasValue && (files.value?.isEmpty ?? true));

    return Scaffold(
      appBar: AppBar(
        title: _selectedDirectory.isNotEmpty
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Consumer(builder: (context, ref, _) {
                    final folderMetadataAsyncValue =
                        ref.watch(folderSvgIconMetadataLoaderProvider);
                    return folderMetadataAsyncValue.when(
                      data: (folderSvgIconMetadata) => ElevatedButton(
                        onPressed: _addDirectory,
                        child: Row(
                          children: [
                            folderIconWidget(path.basename(_selectedDirectory),
                                folderSvgIconMetadata),
                            const SizedBox(width: 8),
                            Text(path.basename(_selectedDirectory)),
                          ],
                        ),
                      ),
                      loading: () => const CircularProgressIndicator(),
                      error: (error, stack) => const Icon(Icons.error),
                    );
                  }),
                ],
              )
            : const SizedBox.shrink(),
        // If no directory is selected, show an empty widget
        actions: [
          Consumer(
            builder: (context, ref, _) {
              final selectedFiles = ref.watch(selectedFilesProvider);
              return Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.deselect),
                    tooltip: 'Tout désélectionner',
                    // On désactive le bouton si rien n'est sélectionné
                    onPressed: selectedFiles.isNotEmpty
                        ? () {
                            // Vider la liste des fichiers sélectionnés
                            ref.read(selectedFilesProvider.notifier).state = {};
                            // Réinitialiser le compteur de tokens
                            ref.read(estimatedTokenCountProvider.notifier).state = 0;
                          }
                        : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh), // Icône refresh
                    onPressed: () {
                      if (_selectedDirectory.isNotEmpty) {
                        _refreshAll(ref);
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings),
                    onPressed: () {
                      Navigator.restorablePushNamed(context, SettingsView.routeName);
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: shouldShowPickDirectory
                ? Center(
                    child: ElevatedButton(
                      onPressed: _addDirectory,
                      child: const Text("Pick Directory"),
                    ),
                  )
                : fileMetadata.when(
                    data: (fileSvgIconMetadata) => folderMetadata.when(
                      data: (folderSvgIconMetadata) => files.when(
                        data: (fileList) => FileListPanel(
                          files: fileList ?? [],
                          fileSvgIconMetadata: fileSvgIconMetadata,
                          folderSvgIconMetadata: folderSvgIconMetadata,
                          onSelectionChanged: (Set<String> newSelection) {},
                        ),
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (error, stack) =>
                            const Center(child: Text('Error loading files')),
                      ),
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (error, stack) =>
                          const Center(child: Text('Error loading folder icons')),
                    ),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, stack) =>
                        const Center(child: Text('Error loading file icons')),
                  ),
          ),
          if (_selectedDirectory.isNotEmpty) // Only show the button when a directory is selected
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton(
                onPressed:
                    ref.watch(selectedFilesProvider).isNotEmpty ? _copySelectedFilesToClipboard : null,
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Conditional icon based on the _isCopied state
                    _isCopied
                        ? const Icon(Icons.check, size: 16.0)
                        : const Icon(Icons.content_copy, size: 16.0),
                    const SizedBox(width: 8),
                    _isCopied
                        ? const Text('Copied!')
                        : _isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(
                                'Copy code (~${_formatTokens(estimatedTokenCount)} tokens)',
                              ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _addDirectory() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory != null) {
      setState(() {
        _selectedDirectory = selectedDirectory;
        _isLoading = true; // Indicate loading UI
      });

      // Trigger refresh
      ref.refresh(directoryContentsProvider(selectedDirectory));

      setState(() {
        _isLoading = false; // Reset loading UI
      });
    }
  }

  void _refreshAll(WidgetRef ref) {
    ref.refresh(directoryContentsProvider(_selectedDirectory));
    final expanded = ref.read(expandedFoldersProvider);
    for (final folder in expanded) {
      ref.refresh(directoryContentsProvider(folder));
    }
  }

  void _copySelectedFilesToClipboard() async {
    final settingsController = ref.watch(settingsControllerProvider);
    String combinedContent = '';
    final selectedFiles = ref.read(selectedFilesProvider); // Utilise directement le provider
    for (var filePath in selectedFiles) {
      var fileEntity = FileSystemEntity.typeSync(filePath);
      if (fileEntity == FileSystemEntityType.file) {
        try {
          final file = File(filePath);
          String fileContent = await file.readAsString();
          // Determine the path to use based on the user's preference
          String displayPath = settingsController.pathOption == PathOption.full
              ? filePath // Use the full path
              : path.relative(filePath, from: _selectedDirectory); // Or the relative path

          combinedContent +=
              '### START OF FILE: $displayPath ###\n$fileContent\n### END OF FILE: $displayPath ###\n\n';
        } catch (e) {
          // Handle the case where the file cannot be read (if necessary)
        }
      }
    }
    if (combinedContent.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: combinedContent));
      setState(() {
        _isCopied = true;
      });
      // Optionally reset _isCopied flag after a few seconds
      Future.delayed(const Duration(seconds: 2), () {
        setState(() {
          _isCopied = false;
        });
      });
    }
  }

  String _formatTokens(int tokens) {
    if (tokens >= 1000) {
      return '${(tokens / 1000).toStringAsFixed(1)}k';
    }
    return tokens.toString();
  }
}