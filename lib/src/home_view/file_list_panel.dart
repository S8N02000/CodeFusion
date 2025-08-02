import 'dart:io';
import 'package:code_fusion/src/home_view/state_providers.dart';
import 'package:code_fusion/src/home_view/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    final flatList = ref.watch(flattenedListProvider);

    if (flatList.isEmpty) {
        return const Center(child: Text("Ce dossier est vide.", style: TextStyle(color: Colors.grey)));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      itemCount: flatList.length,
      itemBuilder: (context, index) {
        final item = flatList[index];
        final FileNode node = item['node'];

        // On passe toutes les données nécessaires à notre nouvel item stylisé
        return _FileListItem(
          node: node,
          depth: item['depth'],
          fileSvgIconMetadata: fileSvgIconMetadata,
          folderSvgIconMetadata: folderSvgIconMetadata,
        );
      },
    );
  }
}

// NOUVEAU WIDGET DÉDIÉ pour chaque ligne de la liste.
// Il est `Stateful` pour gérer son propre état de survol (hover).
class _FileListItem extends ConsumerStatefulWidget {
  final FileNode node;
  final int depth;
  final Map<String, dynamic> fileSvgIconMetadata;
  final Map<String, dynamic> folderSvgIconMetadata;

  const _FileListItem({
    required this.node,
    required this.depth,
    required this.fileSvgIconMetadata,
    required this.folderSvgIconMetadata,
  });

  @override
  ConsumerState<_FileListItem> createState() => _FileListItemState();
}

class _FileListItemState extends ConsumerState<_FileListItem> {
  // État local pour le survol de la souris
  bool _isHovered = false;

  void _toggleFolderExpansion(String path) {
    ref.read(expandedFoldersProvider.notifier).update((state) {
      final newSet = {...state};
      if (newSet.contains(path)) newSet.remove(path);
      else newSet.add(path);
      return newSet;
    });
  }

  void _handleSelection(FileNode node) {
    final selected = ref.read(selectedNodesProvider);
    final isCurrentlySelected = selected.contains(node.path);
    Set<String> affectedPaths = _getAllChildPaths(node);

    ref.read(selectedNodesProvider.notifier).update((state) {
      final newSet = {...state};
      if (isCurrentlySelected) newSet.removeAll(affectedPaths);
      else newSet.addAll(affectedPaths);
      return newSet;
    });
  }

  Set<String> _getAllChildPaths(FileNode node) {
    final paths = <String>{node.path};
    if (node.isDirectory) {
      for (final child in node.children) {
        paths.addAll(_getAllChildPaths(child));
      }
    }
    return paths;
  }

  @override
  Widget build(BuildContext context) {
    final selectedPaths = ref.watch(selectedNodesProvider);
    final expandedFolders = ref.watch(expandedFoldersProvider);

    final isSelected = selectedPaths.contains(widget.node.path);
    final isExpanded = expandedFolders.contains(widget.node.path);

    final primaryColor = Theme.of(context).primaryColor;

    return Focus(
      onKeyEvent: (focusNode, event) {
        if (event is KeyDownEvent) {
          final key = event.logicalKey;
          if (key == LogicalKeyboardKey.enter && widget.node.isDirectory) {
            _toggleFolderExpansion(widget.node.path);
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.space) {
            _handleSelection(widget.node);
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.arrowRight && widget.node.isDirectory && !isExpanded) {
            _toggleFolderExpansion(widget.node.path);
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.arrowLeft && widget.node.isDirectory && isExpanded) {
            _toggleFolderExpansion(widget.node.path);
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) {
          final hasFocus = Focus.of(context).hasFocus;

          return MouseRegion(
            onEnter: (_) => setState(() => _isHovered = true),
            onExit: (_) => setState(() => _isHovered = false),
            cursor: SystemMouseCursors.click,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.symmetric(vertical: 2),
              decoration: BoxDecoration(
                // NOUVEAU : Logique de décoration beaucoup plus riche
                color: isSelected
                    ? primaryColor.withOpacity(0.2)
                    : _isHovered
                        ? Colors.white.withOpacity(0.08)
                        : hasFocus
                           ? Colors.white.withOpacity(0.12)
                           : Colors.transparent,
                border: Border(
                  left: BorderSide(
                    color: isSelected ? primaryColor : Colors.transparent,
                    width: 3,
                  ),
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: ListTile(
                dense: true,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                key: ValueKey(widget.node.path),
                title: Text(
                  widget.node.name,
                  style: TextStyle(
                    // NOUVEAU : Texte blanc vif pour la sélection, pour un meilleur contraste
                    color: isSelected ? Colors.white : Theme.of(context).colorScheme.onBackground,
                    fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                  ),
                ),
                leading: Padding(
                  padding: EdgeInsets.only(left: 20.0 * widget.depth),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.node.isDirectory)
                        IconButton(
                          icon: Icon(isExpanded ? Icons.expand_more : Icons.chevron_right),
                          onPressed: () => _toggleFolderExpansion(widget.node.path),
                          splashRadius: 20,
                          color: isSelected ? Colors.white : null,
                        )
                      else
                        const SizedBox(width: 48),

                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: widget.node.isDirectory
                            ? folderIconWidget(widget.node.name, widget.folderSvgIconMetadata)
                            : fileIconWidget(widget.node.name, widget.fileSvgIconMetadata),
                      ),
                    ],
                  ),
                ),
                onTap: () => _handleSelection(widget.node),
              ),
            ),
          );
        }
      ),
    );
  }
}