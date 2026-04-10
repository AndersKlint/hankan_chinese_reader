import 'package:flutter/material.dart';
import 'package:hankan_chinese_reader/core/service_locator.dart';
import 'package:hankan_chinese_reader/core/screens/home_screen.dart';
import 'package:hankan_chinese_reader/core/services/theme_service.dart';
import 'package:hankan_chinese_reader/core/theme/app_theme.dart';
import 'package:logging/logging.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((record) {
    debugPrint('${record.level.name}: ${record.loggerName}: ${record.message}');
  });

  await setupServiceLocator();

  runApp(const HankanApp());
}

/// Root application widget.
class HankanApp extends StatelessWidget {
  const HankanApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = getIt<ThemeService>();

    return ListenableBuilder(
      listenable: themeService,
      builder: (context, _) {
        return MaterialApp(
          title: 'HanKan - Chinese Reader',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeService.value,
          home: const HomeScreen(),
        );
      },
    );
  }
}
