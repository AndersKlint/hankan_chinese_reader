## 1. Project Setup & Dependencies

- [x] 1.1 Update `pubspec.yaml` with all dependencies: `chinese_popup_dict` (path), `get_it`, `watch_it`, `pdfrx`, `file_picker`, `google_fonts`
- [x] 1.2 Run `flutter pub get` and resolve any dependency conflicts
- [x] 1.3 Create folder structure: `lib/core/`, `lib/text_editor/`, `lib/pdf_reader/`

## 2. Core / App Shell

- [x] 2.1 Create `lib/core/theme/app_theme.dart` — Material 3 theme with light/dark mode, Google Font
- [x] 2.2 Create `lib/core/models/tab_model.dart` — data model for open document tabs (enum for type, file path, title, modified flag)
- [x] 2.3 Create `lib/core/services/tab_service.dart` — manages open tabs via `ValueNotifier<List<TabModel>>` and active index
- [x] 2.4 Create `lib/core/services/file_service.dart` — open/save file dialogs, read/write file contents
- [x] 2.5 Create `lib/core/service_locator.dart` — register all app services with `get_it`; call `setupChinesePopupDict()`
- [x] 2.6 Create `lib/main.dart` — app entry point with initialization, `MaterialApp`, and root shell
- [x] 2.7 Create `lib/core/screens/home_screen.dart` — tab bar, menu/toolbar, content area switching between text-editor and pdf-reader per tab

## 3. Text Editor Mode

- [ ] 3.1 Create `lib/text_editor/services/text_editor_service.dart` — manages text content, undo/redo stack, modified state per tab
- [ ] 3.2 Create `lib/text_editor/screens/text_editor_screen.dart` — edit/read toggle, toolbar with undo/redo/search/save buttons
- [ ] 3.3 Create `lib/text_editor/widgets/text_edit_view.dart` — `TextField` for editing
- [ ] 3.4 Create `lib/text_editor/widgets/text_read_view.dart` — `TappableTextWrapper` wrapping the text for popup dict reading
- [ ] 3.5 Create `lib/text_editor/widgets/search_bar.dart` — search overlay with highlight and next/previous navigation

## 4. PDF Reader Mode

- [ ] 4.1 Create `lib/pdf_reader/screens/pdf_reader_screen.dart` — PDF page rendering with `pdfrx`, page indicator, jump-to-page
- [ ] 4.2 Create `lib/pdf_reader/widgets/pdf_text_overlay.dart` — overlay `TappableTextWrapper` on PDF text layer fragments
- [ ] 4.3 Handle no-text-layer case with user notification

## 5. Platform Configuration

- [ ] 5.1 Update Android, iOS, macOS, and web platform configs for file access permissions as needed
- [ ] 5.2 Verify the app builds and runs on at least one platform (linux desktop)

## 6. Polish & Verification

- [ ] 6.1 Test opening, editing, saving, and reopening a .txt file with popup dict reading
- [ ] 6.2 Test opening a PDF and verifying popup dict works on the text layer
- [ ] 6.3 Test tab management (open multiple files, switch tabs, close tabs)
- [ ] 6.4 Verify responsive layout on different window sizes
