import 'dart:io';
import 'dart:convert';

import 'dart:async';
import 'package:watcher/watcher.dart'; // Pour surveiller les fichiers
import 'package:code_fusion/src/home_view/utils.dart';
import 'package:code_fusion/src/settings/settings_controller.dart';
import 'package:code_fusion/src/settings/settings_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final isLoadingProvider = StateProvider<bool>((ref) => false);
final fileSvgIconMetadataProvider =
StateProvider<Map<String, dynamic>>((ref) => {});
final folderSvgIconMetadataProvider =
StateProvider<Map<String, dynamic>>((ref) => {});
final fileSvgIconMetadataLoaderProvider =
FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final jsonString =
  await rootBundle.loadString('assets/icons/files/metadata.json');
  return json.decode(jsonString) as Map<String, dynamic>;
});
final folderSvgIconMetadataLoaderProvider =
FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final jsonString =
  await rootBundle.loadString('assets/icons/folders/metadata.json');
  return json.decode(jsonString) as Map<String, dynamic>;
});
final directoriesProvider = StateProvider<List<String>>((ref) => []);
final selectedDirectoryProvider = StateProvider<String?>((ref) => null);
final selectedFilesProvider = StateProvider<Set<String>>((ref) => {});
final directoryContentsLoaderProvider =
FutureProvider.family<List<String>, String>((ref, directoryPath) async {
  List<String> contents = await loadDirectoryContents(directoryPath);
  return contents;
});
final directoryContentsProvider =
StateNotifierProvider.autoDispose.family<DirectoryContentsNotifier,
    List<String>,
    String>(
        (ref, directoryPath) {
      return DirectoryContentsNotifier(ref, directoryPath);
    });

class DirectoryContentsNotifier extends StateNotifier<List<String>> {
  final String directoryPath;
  Watcher? _watcher;
  StreamSubscription? _subscription; // Pour annuler l'écoute
  final Ref ref; // Pour accéder à Riverpod

  DirectoryContentsNotifier(this.ref, this.directoryPath) : super([]) {
    _loadContents(); // Charge initial
    _startWatching(); // Démarre la surveillance
  }

  Future<void> _loadContents() async {
    print('Rafraîchissement de la liste pour $directoryPath'); // Log pour debug
    final newContents = await loadDirectoryContents(directoryPath);
    if (mounted) { // Vérifie si encore actif
      state = newContents; // Mise à jour seulement si mounted
    } else {
      print('Notifier disposé, ignore update pour $directoryPath');
    }
  }

  void _startWatching() {
    _watcher = DirectoryWatcher(directoryPath);
    _subscription = _watcher!.events.listen((event) {
      print('Watcher event détecté: ${event.type} sur ${event
          .path}'); // Log pour debug
      if (event.type == ChangeType.ADD || event.type == ChangeType.REMOVE ||
          event.type == ChangeType.MODIFY) {
        _loadContents(); // Rafraîchit sur changement
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel(); // Arrête l'écoute des événements
    _watcher = null; // Arrête la surveillance
    super.dispose();
  }
}

final expandedFoldersProvider = StateProvider<Set<String>>((ref) {
  return {};
});
final folderContentsProvider =
FutureProvider.family<List<String>, String>((ref, folderPath) async {
  return await loadDirectoryContents(folderPath);
});
final estimatedTokenCountProvider = StateProvider<int>((ref) {
  return 0;
});
final settingsControllerProvider = ChangeNotifierProvider<SettingsController>((
    ref) {
  return SettingsController(SettingsService());
});