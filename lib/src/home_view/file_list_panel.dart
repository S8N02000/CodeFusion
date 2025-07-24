// lib/src/home_view/file_list_panel.dart

import 'dart:io';
import 'package:code_fusion/src/home_view/state_providers.dart';
import 'package:code_fusion/src/home_view/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;

class FileListPanel extends ConsumerWidget {
  final Map<String, dynamic> fileSvgIconMetadata;
  final Map<String, dynamic> folderSvgIconMetadata;

  const FileListPanel({
    super.key,
    required this.fileSvgIconMetadata,
    required this.folderSvgIconMetadata,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // OPTIMISATION: On surveille la liste aplatie pré-calculée. C'est tout.
    // L'UI est maintenant "stupide", elle ne fait qu'afficher ce qu'on lui donne.
    final flatList = ref.watch(flattenedListProvider);
    final selectedPaths = ref.watch(selectedNodesProvider);

    if (flatList.isEmpty) {
        // Affiche un indicateur pendant le scan initial
        return const Center(child: CircularProgressIndicator());
    }

    // OPTIMISATION: ListView.builder est parfait pour la virtualisation.
    return ListView.builder(
      itemCount: flatList.length,
      itemBuilder: (context, index) {
        final item = flatList[index];
        final FileNode node = item['node'];
        final int depth = item['depth'];
        final isSelected = selectedPaths.contains(node.path);
        final isExpanded = ref.watch(expandedFoldersProvider).contains(node.path);
        
        return ListTile(
          dense: true,
          key: ValueKey(node.path),
          title: Text(node.name),
          leading: Padding(
            padding: EdgeInsets.only(left: 20.0 * depth),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (node.isDirectory)
                  IconButton(
                    icon: Icon(isExpanded ? Icons.expand_more : Icons.chevron_right),
                    onPressed: () => _toggleFolderExpansion(ref, node.path),
                  )
                else
                  // Placeholder pour aligner les fichiers
                  const SizedBox(width: 40), 
                
                node.isDirectory
                    ? folderIconWidget(node.name, folderSvgIconMetadata)
                    : fileIconWidget(node.name, fileSvgIconMetadata),
              ],
            ),
          ),
          tileColor: isSelected ? Colors.green.withOpacity(0.3) : null,
          onTap: () => _handleSelection(ref, node),
        );
      },
    );
  }

  // OPTIMISATION: Ces fonctions manipulent seulement l'état en mémoire. Plus d'accès disque !
  void _toggleFolderExpansion(WidgetRef ref, String path) {
    ref.read(expandedFoldersProvider.notifier).update((state) {
      final newSet = {...state};
      if (newSet.contains(path)) {
        newSet.remove(path);
      } else {
        newSet.add(path);
      }
      return newSet;
    });
  }

  void _handleSelection(WidgetRef ref, FileNode node) {
    final selected = ref.read(selectedNodesProvider);
    final isCurrentlySelected = selected.contains(node.path);

    // OPTIMISATION: La logique de sélection récursive se fait sur le modèle en mémoire. C'est instantané.
    Set<String> affectedPaths = _getAllChildPaths(node);

    ref.read(selectedNodesProvider.notifier).update((state) {
      final newSet = {...state};
      if (isCurrentlySelected) {
        newSet.removeAll(affectedPaths);
      } else {
        newSet.addAll(affectedPaths);
      }
      return newSet;
    });
  }
  
  // Fonction utilitaire pour obtenir tous les chemins d'un noeud et de ses enfants.
  Set<String> _getAllChildPaths(FileNode node) {
    final paths = <String>{node.path};
    if (node.isDirectory) {
      for (final child in node.children) {
        paths.addAll(_getAllChildPaths(child));
      }
    }
    return paths;
  }
}