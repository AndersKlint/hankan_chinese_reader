# Hankan Chinese Reader

A Flutter application for reading Chinese text with an integrated popup dictionary. Tap any Chinese character to see its definition, pronunciation, and related words instantly.

## Features

- **Popup Dictionary**: Tap any Chinese character to see definitions from CC-CEDICT dictionary
- **Word Segmentation**: Automatically identifies multi-character words for better definitions
- **Tone Colors**: Pinyin tones are color-coded for easier learning
- **PDF Support**: Open Chinese PDFs and tap words for definitions
- **Text Import**: Paste or type Chinese text for reading
- **Dark Mode**: Full dark theme support with proper contrast
- **Multiple Tabs**: Open multiple documents simultaneously

## Screenshots

(Screenshots coming soon)

## Architecture

The app follows **Domain-Driven Design** with a clean separation of concerns:

```
lib/
├── main.dart                          # App entry point
├── core/
│   ├── models/                        # Shared models (TabModel)
│   ├── screens/home_screen.dart       # Main tabbed shell
│   ├── services/
│   │   ├── file_service.dart          # File I/O operations
│   │   └── tab_service.dart           # Tab management
│   ├── theme/app_theme.dart           # Material 3 theming
│   └── service_locator.dart           # Dependency injection
├── pdf_reader/                        # PDF domain
│   ├── screens/pdf_reader_screen.dart
│   └── widgets/pdf_text_overlay.dart  # Tappable text layer
└── text_editor/                      # Text editor domain
    ├── screens/text_editor_screen.dart
    ├── services/text_editor_service.dart
    └── widgets/
        ├── text_read_view.dart        # Read mode with popup dict
        └── text_edit_view.dart        # Edit mode
```

### Key Patterns

- **Services**: Contain all business logic
- **Widgets**: Dumb UI components that forward events to services
- **Repositories**: Handle data persistence (via Hive boxes)
- **Reactive State**: Using `ValueNotifier` and `watch_it`

## Dependencies

| Package | Purpose |
|---------|---------|
| `chinese_popup_dict` | Popup dictionary for Chinese text |
| `pdfrx` | PDF rendering |
| `file_picker` | Cross-platform file picking |
| `get_it` | Dependency injection |
| `watch_it` | Reactive state watching |
| `google_fonts` | Noto Sans SC for Chinese text |
| `logging` | Structured logging |

## Getting Started

### Prerequisites

- Flutter SDK 3.11.0 or later
- iOS/Android/Desktop/Web platform support

### Installation

```bash
# Clone the repository
git clone https://github.com/anders/hankan_chinese_reader.git
cd hankan_chinese_reader

# Get dependencies
flutter pub get

# Run the app
flutter run
```

### Setup the Popup Dictionary Package

This app uses `chinese_popup_dict` as a local dependency. Ensure the sibling package is available:

```bash
cd ../chinese_popup_dict
flutter pub get
```

## Usage

### Reading Text

1. Create a new text tab
2. Paste or type Chinese text
3. Switch to read mode (if not auto-detected)
4. Tap any Chinese character for its definition

### Reading PDFs

1. Open a PDF file using the file picker
2. Navigate to a page with text (PDFs with text layers are supported)
3. Tap any Chinese word to see its definition
4. Use the page indicator at the bottom to jump to specific pages

### Dark Mode

The app automatically follows your system theme preference. You can also manually toggle dark/light mode in your system settings.

## Customization

### Font Sizes

The popup dictionary tooltip font sizes can be configured in `lib/core/theme/app_theme.dart`.

### Dictionary Source

The app uses the CC-CEDICT dictionary. For information about the dictionary format and how entries are processed, see the `chinese_popup_dict` package.

## Development

### Code Generation

The project uses `build_runner` for code generation:

```bash
dart run build_runner build --delete-conflicting-outputs
```

### Running Tests

```bash
flutter test
```

### Architecture Guidelines

When contributing to this codebase:

1. **Business logic** lives in services, not widgets
2. **Data access** goes through repositories
3. **UI is reactive** - widgets observe service state
4. **Widgets are dumb** - they render UI and forward events
5. **Organize by domain** - each feature has its own folder structure

## License

This project is proprietary software. All rights reserved.

## Acknowledgments

- [CC-CEDICT](https://cc-cedict.org/) - Chinese-English dictionary data
- [Noto Sans SC](https://fonts.google.com/specimen/Noto+Sans+SC) - Chinese font by Google
- [pdfrx](https://pub.dev/packages/pdfrx) - PDF rendering for Flutter
