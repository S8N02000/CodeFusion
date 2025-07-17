# Compilation de CodeFusion pour Linux, Windows et macOS

Ce guide explique comment compiler l'application **CodeFusion**, un outil Flutter pour fusionner des fichiers de code pour ChatGPT, sur Linux, Windows, et macOS (Intel et Apple Silicon, y compris M4). CodeFusion est conçu pour fonctionner sur plusieurs plateformes grâce à la nature multiplateforme de Flutter, mais chaque système d'exploitation nécessite des outils spécifiques pour compiler une version release. Ce README détaille les prérequis, les étapes de compilation, et les instructions pour exécuter l'application sur chaque plateforme.

## Prérequis généraux

Avant de compiler, assurez-vous d'avoir installé :
- **Flutter SDK** : Téléchargez et configurez depuis [flutter.dev](https://flutter.dev/docs/get-started/install). La version minimale requise pour CodeFusion est Flutter 3.3.3 (comme spécifié dans `pubspec.yaml` avec `sdk: '>=3.3.3 <4.0.0'`).
- **Dart SDK** : Inclus avec Flutter.
- **Git** : Pour cloner le dépôt.

Vérifiez votre configuration avec :
```bash
flutter doctor
```
Résolvez les erreurs signalées (par exemple, installez les dépendances manquantes). Assurez-vous que `flutter doctor` indique un environnement valide pour la plateforme cible.

### Tableau des prérequis par plateforme

| Plateforme       | Prérequis                                                                 | Commande d'installation (si applicable)                     |
|------------------|---------------------------------------------------------------------------|------------------------------------------------------------|
| **Linux**        | Bibliothèques système : `libgtk-3-0`, `libblkid1`, `liblzma5`            | `sudo apt-get install libgtk-3-0 libblkid1 liblzma5`       |
| **Windows**      | Visual Studio avec la charge de travail "Desktop development with C++"    | Téléchargez depuis [visualstudio.microsoft.com](https://visualstudio.microsoft.com/) |
| **macOS (Intel)**| Xcode                                                                    | Téléchargez depuis l'App Store                             |
| **macOS (Apple Silicon, y compris M4)** | Xcode, Rosetta 2 (si dépendances non-ARM) | `sudo softwareupdate --install-rosetta --agree-to-license` |

## Étapes de compilation

### 1. Cloner le dépôt
Clonez le dépôt GitHub de CodeFusion :
```bash
git clone https://github.com/dclipca/CodeFusion.git
cd CodeFusion
```

### 2. Récupérer les dépendances
Exécutez la commande suivante pour installer toutes les dépendances listées dans `pubspec.yaml` (comme `flutter_riverpod`, `file_picker`, etc.) :
```bash
flutter pub get
```

Si des erreurs surviennent (par exemple, des dépendances manquantes), essayez :
```bash
flutter clean
flutter pub get
```

### 3. Compiler pour chaque plateforme

#### Linux
- **Prérequis** : Assurez-vous que les bibliothèques système sont installées (voir tableau ci-dessus). Vérifiez avec `flutter doctor` que le support Linux est activé.
- **Commande de build** :
  ```bash
  flutter build linux --release
  ```
- **Sortie** : L'exécutable se trouve dans `build/linux/x64/release/bundle`. Vous y trouverez `code_fusion` et les bibliothèques nécessaires.
- **Exécution** :
  ```bash
  cd build/linux/x64/release/bundle
  ./code_fusion
  ```
- **Notes** : Le build est spécifique à l'architecture x64. Pour d'autres architectures (par exemple, ARM sur Linux), des ajustements supplémentaires peuvent être nécessaires via CMake.

#### Windows
- **Prérequis** : Installez Visual Studio Community avec la charge de travail "Desktop development with C++" (nécessaire pour CMake et la compilation native). Vérifiez avec `flutter doctor` que le support Windows est activé.
- **Commande de build** :
  ```bash
  flutter build windows --release
  ```
- **Sortie** : L'exécutable se trouve dans `build/windows/runner/Release`, avec `code_fusion.exe` et les DLL nécessaires.
- **Exécution** :
  ```bash
  cd build/windows/runner/Release
  .\code_fusion.exe
  ```
- **Notes** : Pour distribuer l'application, incluez toutes les DLL dans le dossier Release. Pour un package MSIX, utilisez le package [msix](https://pub.dev/packages/msix) et suivez [ce guide](https://medium.com/@fluttergems/packaging-and-distributing-flutter-desktop-apps-the-missing-guide-part-2-windows-0b468d5e9e70).

#### macOS (Intel et Apple Silicon, y compris M4)
- **Prérequis** : Installez Xcode depuis l'App Store. Pour les Macs Apple Silicon (M1, M2, M3, M4), installez Rosetta 2 si des dépendances non-ARM sont utilisées (par exemple, certains plugins). Vérifiez avec `flutter doctor` que le support macOS est activé.
- **Commande de build** :
  ```bash
  flutter build macos --release
  ```
- **Sortie** : L'application se trouve dans `build/macos/Build/Products/Release`, sous la forme `code_fusion.app`.
- **Exécution** :
  ```bash
  open build/macos/Build/Products/Release/code_fusion.app
  ```
- **Notes sur les binaires universels** :
   - Par défaut, le build est pour l'architecture de votre Mac (Intel ou ARM).
   - Pour un binaire universel (Intel + Apple Silicon), après le build, ouvrez `macos/Runner.xcworkspace` dans Xcode :
      1. Sélectionnez le target **Runner** dans le navigateur de projet.
      2. Dans **Build Settings**, cherchez **Architectures** et définissez **Architectures** à `$(ARCHS_STANDARD)` (inclut x86_64 et arm64).
      3. Archivez le projet (Product > Archive) pour créer un binaire universel.
      4. Consultez [Apple's documentation](https://developer.apple.com/documentation/apple-silicon/building-a-universal-macos-binary) pour plus de détails.
- **Distribution** : Pour distribuer hors App Store, notarisez l'application via Xcode (nécessite un compte Apple Developer). Suivez [ce guide](https://developer.apple.com/documentation/xcode/notarizing_macos_software_before_distribution).

### Résolution des problèmes
- **Erreurs de build** : Si le build échoue, exécutez :
  ```bash
  flutter clean
  flutter pub get
  ```
  Puis réessayez la commande de build.
- **Dépendances manquantes** : Vérifiez les erreurs avec :
  ```bash
  flutter doctor -v
  ```
  Installez les outils manquants signalés (par exemple, CMake pour Linux/Windows, ou Xcode pour macOS).
- **Problèmes de plugins** : CodeFusion utilise des plugins comme `file_picker` et `path_provider`. Assurez-vous qu'ils sont compatibles avec la plateforme cible (vérifiez dans `pubspec.yaml` et sur [pub.dev](https://pub.dev)).
- **Problèmes spécifiques à Linux** : Si le watcher de fichiers (via `watcher`) ne détecte pas les changements, vérifiez les permissions du dossier ou installez `inotify-tools` :
  ```bash
  sudo apt-get install inotify-tools
  ```
- **Problèmes de performance** : Pour les gros volumes de code (>200K tokens), utilisez la fonctionnalité "Export to File" pour éviter les limites du clipboard système.

### Ressources supplémentaires
- [Documentation Flutter : Desktop Support](https://docs.flutter.dev/platform-integration/desktop)
- [Building Linux Apps](https://docs.flutter.dev/platform-integration/linux/building)
- [Building Windows Apps](https://docs.flutter.dev/platform-integration/windows/building)
- [Building macOS Apps](https://docs.flutter.dev/platform-integration/macos/building)
- [Apple : Building a Universal macOS Binary](https://developer.apple.com/documentation/apple-silicon/building-a-universal-macos-binary)
- [Packaging Windows Apps](https://medium.com/@fluttergems/packaging-and-distributing-flutter-desktop-apps-the-missing-guide-part-2-windows-0b468d5e9e70)
- [Packaging Linux Apps](https://medium.com/@fluttergems/packaging-and-distributing-flutter-desktop-apps-the-missing-guide-part-3-linux-24ef8d30a5b4)