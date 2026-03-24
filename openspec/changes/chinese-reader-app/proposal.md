## Why

The project is a fresh Flutter scaffold with no functionality. The goal is to build a Chinese reading assistant app that leverages the `chinese_popup_dict` package — a tap-any-word popup dictionary for Chinese text. Users need two core workflows: editing/reading plain Chinese text with dictionary lookup, and reading Chinese PDFs with dictionary support on the text layer. The app should support desktop, mobile, and web platforms with a modern tabbed interface.

## What Changes

- Add `chinese_popup_dict` (local path dependency) and PDF rendering packages (`pdfrx` for cross-platform PDF)
- Set up app-level dependency injection via `get_it` and state management with `watch_it`
- Build a tabbed document interface supporting multiple open files
- Implement a **text editor mode**: create/open/save `.txt` files, edit with undo/redo/search, toggle to reading view with popup dictionary
- Implement a **PDF reader mode**: open PDF files, render pages with selectable text layer, wrap text layer with popup dictionary
- Add file open/save dialogs via `file_picker`
- Implement responsive layout for desktop, mobile, and web
- Apply a clean, modern Material 3 theme

## Capabilities

### New Capabilities
- `app-shell`: Top-level app structure — theming, routing, tab management, service initialization
- `text-editor`: Plain text editing with undo/redo/search, file open/save, and popup dictionary reading view
- `pdf-reader`: PDF file rendering with selectable text layer and popup dictionary integration

### Modified Capabilities
_None — this is a greenfield project._

## Impact

- **Dependencies**: Adds `chinese_popup_dict` (path), `get_it`, `watch_it`, `pdfrx`, `file_picker`, `google_fonts`
- **Platform configs**: May need file-access permissions on Android/iOS/macOS; web may need CORS headers for local PDF loading
- **Code**: All new code under `lib/` organized by domain (`core/`, `text_editor/`, `pdf_reader/`)
