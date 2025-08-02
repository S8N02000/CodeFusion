import 'package:code_fusion/src/settings/settings_view.dart';
import 'package:code_fusion/src/home_view/home_view.dart';
import 'package:flutter/material.dart';
import 'settings/settings_controller.dart';

class App extends StatelessWidget {
  const App({
    super.key,
    required this.settingsController,
  });

  final SettingsController settingsController;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settingsController,
      builder: (BuildContext context, Widget? child) {
        // Définition de notre thème sombre personnalisé "Developer Pro"
        final developerDarkTheme = ThemeData(
          brightness: Brightness.dark,
          primaryColor: const Color(0xFF0D63F8), // Un bleu électrique pour l'accent
          scaffoldBackgroundColor: const Color(0xFF121212), // Un fond très sombre mais pas noir pur
          
          // Palette de couleurs moderne
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF0D63F8),
            secondary: Color(0xFF0D63F8),
            background: Color(0xFF1E1E1E), // Couleur de fond principale des panneaux
            surface: Color(0xFF252526), // Couleur pour les cartes, dialogues, etc.
            onPrimary: Colors.white,
            onSecondary: Colors.white,
            onBackground: Color(0xFFCCCCCC), // Texte principal (blanc cassé)
            onSurface: Color(0xFFCCCCCC),
            error: Colors.redAccent,
            onError: Colors.white,
          ),

          // Style du texte
          textTheme: const TextTheme(
            bodyMedium: TextStyle(color: Color(0xFFCCCCCC)),
            bodyLarge: TextStyle(color: Color(0xFFCCCCCC)),
            titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),

          // Style des icônes
          iconTheme: const IconThemeData(color: Color(0xFFCCCCCC)),
          
          // Style des boutons
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: const Color(0xFF0D63F8), // Fond bleu
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFCCCCCC),
              side: const BorderSide(color: Color(0xFF333333)), // Bordure subtile
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          
          // Style de la barre d'application
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF121212), // Assorti au fond du scaffold
            elevation: 0, // Pas d'ombre pour un look plat
            titleTextStyle: TextStyle(color: Color(0xFFCCCCCC), fontSize: 16),
          ),
          
          // Style des tuiles de la liste
          listTileTheme: const ListTileThemeData(
            iconColor: Color(0xFFCCCCCC),
          ),
        );

        return MaterialApp(
          restorationScopeId: 'app',
          title: 'Code_Fusion',
          
          // On n'utilise que notre thème sombre personnalisé
          theme: developerDarkTheme,
          darkTheme: developerDarkTheme,
          themeMode: ThemeMode.dark,

          debugShowCheckedModeBanner: false,

          onGenerateRoute: (RouteSettings routeSettings) {
            switch (routeSettings.name) {
              case HomeView.routeName:
                return MaterialPageRoute<void>(
                  builder: (context) => HomeView(controller: settingsController),
                );
              case SettingsView.routeName:
                return MaterialPageRoute<void>(
                  builder: (context) => SettingsView(controller: settingsController),
                );
              default:
                return MaterialPageRoute<void>(
                  builder: (context) =>
                  const Scaffold(body: Center(child: Text('Page not found!'))),
                );
            }
          },
        );
      },
    );
  }
}