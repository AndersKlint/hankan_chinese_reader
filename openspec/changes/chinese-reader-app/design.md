## Context

The project is a blank Flutter scaffold (from `flutter create`). We are building a Chinese reading assistant that wraps the `chinese_popup_dict` package — a local path dependency at `~/git/chinese_popup_dict`. The package provides `TappableTextWrapper` which wraps `Text`/`SelectableText`/`RichText` widgets and shows a popup dictionary on tap. It is initialized via `setupChinesePopupDict()` which registers services in its own `get_it` instance.

The app targets desktop, mobile, and web.

## Goals / Non-Goals

**Goals:**
- Tabbed document interface for opening multiple text/PDF files simultaneously
- Text editor mode with undo/redo, search, and save — toggleable to a reading view with popup dictionary
- PDF reader mode with rendered pages and popup dictionary on the text layer
- Clean Material 3 design, responsive across platforms
- Proper dependency injection following existing project conventions (`get_it` + `watch_it`)

**Non-Goals:**
- Rich text editing (bold, italic, formatting) — plain text only
- PDF annotation or editing
- Cloud storage / sync
- OCR for scanned PDFs (rely on the PDF's existing text layer)
- Translation features beyond what `chinese_popup_dict` provides

## Decisions

### 1. PDF rendering: `pdfrx`
**Choice**: Use `pdfrx` for PDF rendering.
**Rationale**: Cross-platform (Android, iOS, macOS, Windows, Linux, Web), supports text selection layers, maintained, and has a permissive license. Alternatives considered:
- `syncfusion_flutter_pdfviewer` — commercial license, heavy
- `flutter_pdfview` — uses native views, poor text layer access
- `pdfx` — less maintained

### 2. Tab management: Custom `TabService` with `ValueNotifier`
**Choice**: A `TabService` holding a `ValueNotifier<List<TabModel>>` and `ValueNotifier<int>` for the active index.
**Rationale**: Follows the project's `watch_it` / `ValueNotifier` state pattern. Alternatives:
- `flutter_bloc` — adds a large dependency, not aligned with project conventions
- Provider — project already uses `get_it` + `watch_it`

### 3. File I/O: `file_picker` + `dart:io` / web fallback
**Choice**: `file_picker` for open/save dialogs, `dart:io` File for desktop/mobile, `dart:html` for web save (download).
**Rationale**: `file_picker` is the standard cross-platform file dialog. No single package covers save perfectly on web, so we download via anchor element on web.

### 4. Text editor undo/redo: `TextEditingController` + manual undo stack
**Choice**: Implement a simple undo/redo stack wrapping `TextEditingController`.
**Rationale**: Flutter's `TextEditingController` doesn't provide built-in undo/redo. A manual stack of text snapshots on debounced changes is simple and sufficient for plain text. Alternatives:
- `UndoHistoryController` (Flutter 3.x built-in) — if available, prefer this; it integrates with `TextField` natively

### 5. App architecture
**Choice**: Domain-organized folders: `core/`, `text_editor/`, `pdf_reader/`.
**Rationale**: Follows the project's AGENTS.md conventions. Shared services (tab management, theme) live in `core/`.

### 6. Popup dict on PDF
**Choice**: Extract text per visible page from `pdfrx`'s text layer fragments and render as positioned `TappableTextWrapper` overlays on top of the rendered page image.
**Rationale**: `pdfrx` exposes `PdfPageText` with positioned text fragments. We overlay transparent `TappableTextWrapper` widgets matching each text fragment's position so taps trigger the popup dictionary.

## Risks / Trade-offs

- **PDF text layer quality varies** → If a PDF has no text layer, popup dict won't work. Mitigation: show a message to the user indicating no text layer is found.
- **`pdfrx` text positions may not perfectly align** → Mitigation: allow minor alignment adjustments; accept imperfect overlay as an initial trade-off.
- **`chinese_popup_dict` uses its own `get_it` instance** → No conflict with the app's `get_it`. We call `setupChinesePopupDict()` at app startup.
- **Web file save limitations** → Web can only "download" files, not save in-place. Mitigation: clearly indicate this via UI.
