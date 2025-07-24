// lib/src/home_view/state_providers.dart

import 'dart:async'; // AJOUT : Nécessaire pour Completer
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:code_fusion/src/home_view/utils.dart'; // AJOUT : Nécessaire pour les fonctions utilitaires
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

// --- PROVIDERS D'ICÔNES ET DE SETTINGS (INCHANGÉS) ---
final fileSvgIconMetadataLoaderProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final jsonString = await rootBundle.loadString('assets/icons/files/metadata.json');
  return json.decode(jsonString) as Map<String, dynamic>;
});

final folderSvgIconMetadataLoaderProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final jsonString = await rootBundle.loadString('assets/icons/folders/metadata.json');
  return json.decode(jsonString) as Map<String, dynamic>;
});

final settingsControllerProvider = ChangeNotifierProvider<SettingsController>((ref) {
  final controller = SettingsController(SettingsService());
  controller.loadSettings(); // Charger les settings au démarrage
  return controller;
});

// --- NOUVELLE ARCHITECTURE DE GESTION DE L'ARBORESCENCE ---

final selectedDirectoryProvider = StateProvider<String?>((ref) => null);

// OPTIMISATION: Scanne l'arborescence complète dans un Isolate.
final fileTreeProvider = FutureProvider.autoDispose<FileNode?>((ref) async {
  final directoryPath = ref.watch(selectedDirectoryProvider);
  if (directoryPath == null) {
    return null;
  }
  // Exécute la fonction de scan lourd dans un Isolate pour ne pas geler l'UI.
  return compute(_scanDirectoryRecursive, directoryPath);
});

// CORRECTION : La fonction est maintenant réellement récursive pour scanner tous les sous-dossiers.
Future<FileNode> _scanDirectoryRecursive(String path) async {
  final directory = Directory(path);
  final List<FileNode> children = [];

  if (await directory.exists()) {
    final List<FileSystemEntity> entities = await directory.list().toList();
    for (final entity in entities) {
      if (entity is Directory) {
        // Appel récursif pour scanner les sous-dossiers.
        children.add(await _scanDirectoryRecursive(entity.path));
      } else if (entity is File) {
        children.add(FileNode(
          path: entity.path,
          name: p.basename(entity.path),
          isDirectory: false,
        ));
      }
    }
  }

  // Trier les enfants: dossiers d'abord, puis fichiers, le tout alphabétiquement.
  children.sort((a, b) {
    if (a.isDirectory && !b.isDirectory) return -1;
    if (!a.isDirectory && b.isDirectory) return 1;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });

  return FileNode(
    path: path,
    name: p.basename(path),
    isDirectory: true,
    children: children,
  );
}

final expandedFoldersProvider = StateProvider<Set<String>>((ref) => {});

final selectedNodesProvider = StateProvider<Set<String>>((ref) => {});

// OPTIMISATION: Calcule la liste aplatie à afficher.
final flattenedListProvider = Provider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final fileTreeAsync = ref.watch(fileTreeProvider);
  final expandedFolders = ref.watch(expandedFoldersProvider);

  // CORRECTION : Simplification de la logique, suppression de l'anti-pattern ref.watch en boucle.
  return fileTreeAsync.when(
    data: (fileTree) {
      if (fileTree == null) return [];

      final List<Map<String, dynamic>> flatList = [];

      // La fonction de construction est maintenant correcte et utilise le modèle chargé.
      void generateFlatList(FileNode node, int depth) {
        flatList.add({'node': node, 'depth': depth});
        if (node.isDirectory && expandedFolders.contains(node.path)) {
          for (final child in node.children) {
            generateFlatList(child, depth + 1);
          }
        }
      }

      // On affiche les enfants du noeud racine, mais pas le noeud racine lui-même.
      for (final child in fileTree.children) {
        generateFlatList(child, 0);
      }

      return flatList;
    },
    loading: () => [],
    error: (e, s) => [],
  );
});

// OPTIMISATION: Calcule le nombre de tokens de manière asynchrone.
final estimatedTokenCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final selectedPaths = ref.watch(selectedNodesProvider);
  if (selectedPaths.isEmpty) {
    return 0;
  }

  int totalTokens = 0;
  final List<Future<void>> futures = [];

  for (final path in selectedPaths.toList()) {
    if (await FileSystemEntity.isDirectory(path)) continue;

    futures.add(Future(() async {
      // Les fonctions isUtf8Encoded et estimateTokenCount sont maintenant accessibles grâce à l'import.
      if (await isUtf8Encoded(path)) {
        try {
          final content = await File(path).readAsString();
          totalTokens += estimateTokenCount(content);
        } catch (e) {
          // Ignorer les fichiers illisibles
        }
      }
    }));
  }

  await Future.wait(futures);
  return totalTokens;
});