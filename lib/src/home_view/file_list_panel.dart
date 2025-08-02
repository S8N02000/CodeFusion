import 'dart:io';
import 'package:code_fusion/src/home_view/state_providers.dart';
import 'package:code_fusion/src/home_view/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    final flatList = ref.watch(flattenedListProvider);
    final selectedPaths = ref.watch(selectedNodesProvider);

    if (flatList.isEmpty) {
        return const Center(child: CircularProgressIndicator());
    }

    return ListView.builder(
      itemCount: flatList.length,
      itemBuilder: (context, index) {
        final item = flatList[index];
        final FileNode node = item['node'];
        final int depth = item['depth'];
        final isSelected = selectedPaths.contains(node.path);
        final isExpanded = ref.watch(expandedFoldersProvider).contains(node.path);

        return Focus(
          onKeyEvent: (focusNode, event) {
            if (event is KeyDownEvent) {
              if (event.logicalKey == LogicalKeyboardKey.enter) {
                if (node.isDirectory) {
                  _toggleFolderExpansion(ref, node.path);
                  return KeyEventResult.handled;
                }
              }
              else if (event.logicalKey == LogicalKeyboardKey.space) {
                _handleSelection(ref, node);
                return KeyEventResult.handled;
              }
              else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                if (node.isDirectory && !isExpanded) {
                  _toggleFolderExpansion(ref, node.path);
                  return KeyEventResult.handled;
                }
              }
              else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                if (node.isDirectory && isExpanded) {
                  _toggleFolderExpansion(ref, node.path);
                  return KeyEventResult.handled;
                }
              }
            }
            return KeyEventResult.ignored;
          },
          child: Builder(
            builder: (context) {
              final hasFocus = Focus.of(context).hasFocus;
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
                          splashRadius: 20,
                        )
                      else
                        const SizedBox(width: 48),

                      node.isDirectory
                          ? folderIconWidget(node.name, folderSvgIconMetadata)
                          : fileIconWidget(node.name, fileSvgIconMetadata),
                    ],
                  ),
                ),
                tileColor: hasFocus ? Theme.of(context).focusColor : (isSelected ? Colors.green.withOpacity(0.3) : null),
                onTap: () => _handleSelection(ref, node),
              );
            }
          ),
        );
      },
    );
  }

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