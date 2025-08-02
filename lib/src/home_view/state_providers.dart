import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:code_fusion/src/home_view/utils.dart';
import 'package:code_fusion/src/settings/settings_controller.dart';
import 'package:code_fusion/src/settings/settings_service.dart';
import 'package:flutter/foundation.dart';
// CORRECTION : Le chemin d'importation était erroné.
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

// --- MODÈLE DE DONNÉES ---
@immutable
class FileNode {
  final String path;
  final String name;
  final bool isDirectory;
  final List<FileNode> children;

  const FileNode({
    required this.path,
    required this.name,
    required this.isDirectory,
    this.children = const [],
  });
}

class CancellationToken {
  bool _isCancelled = false;
  bool get isCancelled => _isCancelled;
  void cancel() => _isCancelled = true;
}

// --- PROVIDERS ---

final fileSvgIconMetadataLoaderProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final jsonString = await rootBundle.loadString('assets/icons/files/metadata.json');
  return json.decode(jsonString) as Map<String, dynamic>;
});

final folderSvgIconMetadataLoaderProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final jsonString = await rootBundle.loadString('assets/icons/folders/metadata.json');
  return json.decode(jsonString) as Map<String, dynamic>;
});

final settingsControllerProvider = ChangeNotifierProvider<SettingsController>((ref) {
  return SettingsController(SettingsService())..loadSettings();
});

final selectedDirectoryProvider = StateProvider<String?>((ref) => null);

final fileTreeProvider = FutureProvider.autoDispose<FileNode?>((ref) async {
  final directoryPath = ref.watch(selectedDirectoryProvider);
  if (directoryPath == null) {
    return null;
  }
  final ignoredFolders = ref.watch(settingsControllerProvider).ignoredFolders;
  final cancellationToken = CancellationToken();
  ref.onDispose(() {
    cancellationToken.cancel();
  });
  return compute(_scanDirectoryRecursive, {
    'path': directoryPath,
    'ignoredFolders': Set.of(ignoredFolders),
    'token': cancellationToken,
  });
});

Future<FileNode> _scanDirectoryRecursive(Map<String, dynamic> args) async {
  final String path = args['path'];
  final Set<String> ignoredFolders = args['ignoredFolders'];
  final CancellationToken token = args['token'];

  final directory = Directory(path);
  final List<FileNode> children = [];

  if (await directory.exists()) {
    try {
      final List<FileSystemEntity> entities = await directory.list().toList();
      for (final entity in entities) {
        if (token.isCancelled) {
          debugPrint('Scan annulé pour le chemin: $path');
          throw Exception('Scan cancelled');
        }
        final entityName = p.basename(entity.path);
        if (ignoredFolders.contains(entityName)) {
          continue;
        }
        if (entity is Directory) {
          children.add(await _scanDirectoryRecursive({
            'path': entity.path,
            'ignoredFolders': ignoredFolders,
            'token': token,
          }));
        } else if (entity is File) {
          children.add(FileNode(path: entity.path, name: entityName, isDirectory: false));
        }
      }
    } catch (e) {
      if (e is Exception && e.toString().contains('Scan cancelled')) {
        rethrow;
      }
      debugPrint("Erreur de scan sur le dossier $path: $e");
    }
  }

  children.sort((a, b) {
    if (a.isDirectory && !b.isDirectory) return -1;
    if (!a.isDirectory && b.isDirectory) return 1;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });

  return FileNode(path: path, name: p.basename(path), isDirectory: true, children: children);
}

final expandedFoldersProvider = StateProvider<Set<String>>((ref) => {});
final selectedNodesProvider = StateProvider<Set<String>>((ref) => {});

final flattenedListProvider = Provider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final fileTreeAsync = ref.watch(fileTreeProvider);
  final expandedFolders = ref.watch(expandedFoldersProvider);
  return fileTreeAsync.when(
    data: (fileTree) {
      if (fileTree == null) return [];
      final List<Map<String, dynamic>> flatList = [];
      void generateFlatList(FileNode node, int depth) {
        flatList.add({'node': node, 'depth': depth});
        if (node.isDirectory && expandedFolders.contains(node.path)) {
          for (final child in node.children) {
            generateFlatList(child, depth + 1);
          }
        }
      }
      for (final child in fileTree.children) {
        generateFlatList(child, 0);
      }
      return flatList;
    },
    loading: () => [],
    error: (e, s) => [],
  );
});

final estimatedTokenCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final selectedPaths = ref.watch(selectedNodesProvider);
  if (selectedPaths.isEmpty) return 0;
  int totalTokens = 0;
  final futures = <Future>[];
  for (final path in selectedPaths) {
    if (await FileSystemEntity.isDirectory(path)) continue;
    futures.add(Future(() async {
      if (await isUtf8Encoded(path)) {
        try {
          final content = await File(path).readAsString();
          totalTokens += estimateTokenCount(content);
        } catch (e) {}
      }
    }));
  }
  await Future.wait(futures);
  return totalTokens;
});