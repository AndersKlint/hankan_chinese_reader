import 'package:chinese_popup_dict/chinese_popup_dict.dart';
import 'package:get_it/get_it.dart';
import 'package:hankan_chinese_reader/core/services/document_history_service.dart';
import 'package:hankan_chinese_reader/core/services/file_service.dart';
import 'package:hankan_chinese_reader/core/services/tab_service.dart';
import 'package:hankan_chinese_reader/core/services/theme_service.dart';
import 'package:hankan_chinese_reader/pdf_reader/services/pdf_ocr_service.dart';
import 'package:hankan_chinese_reader/text_editor/services/text_editor_service.dart';
import 'package:hankan_chinese_reader/text_editor/services/text_editor_service_registry.dart';
import 'package:shared_preferences/shared_preferences.dart';

final getIt = GetIt.instance;

/// Registers all application services and initializes the popup dictionary.
Future<void> setupServiceLocator() async {
  final sharedPreferences = await SharedPreferences.getInstance();
  final documentHistoryService = DocumentHistoryService(sharedPreferences);
  await documentHistoryService.load();

  getIt.registerLazySingleton<TabService>(() => TabService());
  getIt.registerLazySingleton<FileService>(() => FileService());
  getIt.registerLazySingleton<ThemeService>(() => ThemeService());
  getIt.registerLazySingleton<PdfOcrService>(() => PdfOcrService());
  getIt.registerSingleton<DocumentHistoryService>(documentHistoryService);

  getIt.registerLazySingleton<TextEditorServiceRegistry>(
    () => TextEditorServiceRegistry(),
  );
  getIt.registerFactory<TextEditorService>(
    () => TextEditorService(
      fileService: getIt<FileService>(),
      tabService: getIt<TabService>(),
    ),
  );

  // Initialize the popup dictionary before any wrapped reader text is built.
  await initializeChinesePopupDict();
}
