import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:code_fusion/src/home_view/utils.dart';
import 'package:code_fusion/src/settings/settings_controller.dart';
import 'package:code_fusion/src/settings/settings_service.dart';
import 'package:flutter/foundation.dart';
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
  // Le contrôleur est créé une seule fois et on s'assure que ses données sont chargées.
  return SettingsController(SettingsService())..loadSettings();
});

// Le chemin du dossier racine actuellement affiché.
final selectedDirectoryProvider = StateProvider<String?>((ref) => null);

// Le provider qui scanne l'arborescence des fichiers. C'est le cœur du système.
final fileTreeProvider = FutureProvider.autoDispose<FileNode?>((ref) async {
  final directoryPath = ref.watch(selectedDirectoryProvider);
  if (directoryPath == null) {
    return null;
  }

  // Récupère la liste des dossiers à ignorer depuis les paramètres.
  final ignoredFolders = ref.watch(settingsControllerProvider).ignoredFolders;

  // Exécute le scan lourd dans un Isolate (thread séparé) pour ne jamais geler l'UI.
  return compute(_scanDirectoryRecursive, {
    'path': directoryPath,
    'ignoredFolders': Set.of(ignoredFolders), // Un Set est plus rapide pour les vérifications.
  });
});

/// Fonction exécutée dans l'Isolate pour scanner l'arborescence.
Future<FileNode> _scanDirectoryRecursive(Map<String, dynamic> args) async {
  final String path = args['path'];
  final Set<String> ignoredFolders = args['ignoredFolders'];

  final directory = Directory(path);
  final List<FileNode> children = [];

  if (await directory.exists()) {
    try {
      final List<FileSystemEntity> entities = await directory.list().toList();
      for (final entity in entities) {
        final entityName = p.basename(entity.path);

        // Si le nom du fichier/dossier est dans la liste d'exclusion, on l'ignore.
        if (ignoredFolders.contains(entityName)) {
          continue;
        }

        if (entity is Directory) {
          // Appel récursif pour scanner les sous-dossiers.
          children.add(await _scanDirectoryRecursive({'path': entity.path, 'ignoredFolders': ignoredFolders}));
        } else if (entity is File) {
          children.add(FileNode(path: entity.path, name: entityName, isDirectory: false));
        }
      }
    } catch (e) {
      // Gère les erreurs (ex: dossier protégé contre la lecture).
      debugPrint("Erreur de scan sur le dossier $path: $e");
    }
  }

  // Trie les résultats : dossiers en premier, puis fichiers, le tout par ordre alphabétique.
  children.sort((a, b) {
    if (a.isDirectory && !b.isDirectory) return -1;
    if (!a.isDirectory && b.isDirectory) return 1;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });

  return FileNode(path: path, name: p.basename(path), isDirectory: true, children: children);
}

// État des dossiers qui sont dépliés (ouverts) dans l'UI.
final expandedFoldersProvider = StateProvider<Set<String>>((ref) => {});

// État des fichiers/dossiers sélectionnés par l'utilisateur.
final selectedNodesProvider = StateProvider<Set<String>>((ref) => {});

// Construit une liste "aplatie" à partir de l'arborescence pour l'affichage dans le ListView.
final flattenedListProvider = Provider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final fileTreeAsync = ref.watch(fileTreeProvider);
  final expandedFolders = ref.watch(expandedFoldersProvider);

  return fileTreeAsync.when(
    data: (fileTree) {
      if (fileTree == null) return [];

      final List<Map<String, dynamic>> flatList = [];
      void generateFlatList(FileNode node, int depth) {
        flatList.add({'node': node, 'depth': depth});
        // Si le nœud est un dossier déplié, on ajoute ses enfants à la liste.
        if (node.isDirectory && expandedFolders.contains(node.path)) {
          for (final child in node.children) {
            generateFlatList(child, depth + 1);
          }
        }
      }

      // On commence par les enfants du dossier racine.
      for (final child in fileTree.children) {
        generateFlatList(child, 0);
      }
      return flatList;
    },
    loading: () => [],
    error: (e, s) => [],
  );
});

// Calcule le nombre de tokens de manière asynchrone et uniquement quand la sélection change.
final estimatedTokenCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final selectedPaths = ref.watch(selectedNodesProvider);
  if (selectedPaths.isEmpty) {
    return 0;
  }
  int totalTokens = 0;
  final futures = <Future>[];

  for (final path in selectedPaths) {
    if (await FileSystemEntity.isDirectory(path)) continue;

    futures.add(Future(() async {
      if (await isUtf8Encoded(path)) {
        try {
          final content = await File(path).readAsString();
          totalTokens += estimateTokenCount(content);
        } catch (e) {
          // Ignore les fichiers illisibles.
        }
      }
    }));
  }
  await Future.wait(futures);
  return totalTokens;
});