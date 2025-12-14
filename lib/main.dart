import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'config/service_locator.dart';
import 'stores/app_store.dart';
import 'presentation/theme/app_theme.dart';
import 'presentation/screens/home/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Flutter Gemma (no token needed - using bundled models)
  await FlutterGemma.initialize();

  // Setup dependency injection
  await setupServiceLocator();

  // Load persisted user preferences
  final appStore = getIt<AppStore>();
  await appStore.loadPreferences();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final appStore = getIt<AppStore>();

    return Observer(
      builder: (_) => MaterialApp(
        title: 'EduMate Lite',
        theme: AppTheme.lightTheme(),
        darkTheme: AppTheme.darkTheme(),
        themeMode: appStore.themeMode,
        home: const HomeScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
