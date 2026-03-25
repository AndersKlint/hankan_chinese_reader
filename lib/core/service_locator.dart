import 'package:chinese_popup_dict/chinese_popup_dict.dart';
import 'package:get_it/get_it.dart';
import 'package:hankan_chinese_reader/core/services/file_service.dart';
import 'package:hankan_chinese_reader/core/services/tab_service.dart';
import 'package:hankan_chinese_reader/core/services/theme_service.dart';

final getIt = GetIt.instance;

/// Registers all application services and initializes the popup dictionary.
Future<void> setupServiceLocator() async {
  getIt.registerLazySingleton<TabService>(() => TabService());
  getIt.registerLazySingleton<FileService>(() => FileService());
  getIt.registerLazySingleton<ThemeService>(() => ThemeService());

  // Initialize the chinese_popup_dict package (uses its own get_it instance).
  await setupChinesePopupDict();
}
