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

- Flutter SDK 3.47.2 stable (includes Dart 3.13)
- Java 17 and Android SDK for Android builds
- iOS/Android/Desktop/Web platform support

### Installation

```bash
git clone https://github.com/AndersKlint/hankan_chinese_reader.git
git clone https://github.com/AndersKlint/flutter_package_chinese_popup_dict.git chinese_popup_dict
git clone https://github.com/AndersKlint/dart_paddle_ocr.git dart_paddle_ocr
cd hankan_chinese_reader

flutter pub get

flutter run
```

### Sibling Packages and Android OCR

Both private packages must be checked out beside this repository under the exact directory names `chinese_popup_dict` and `dart_paddle_ocr`. Authenticate Git with an account that can read both repositories. Before building Android, install the OCR plugin's NCNN native dependencies:

```bash
bash ../dart_paddle_ocr/android/src/main/cpp/setup_ncnn_deps.sh
```

## Releases

Release version: **0.5.1-beta** (`pubspec.yaml`: `0.5.1-beta+1`). Release workflows use Flutter 3.47.2 stable. Pushing a `v*` tag builds platform assets and publishes them to the same GitHub release named `HanKan <tag>`. Tags containing `-` are prereleases. Manual workflow dispatch builds downloadable Actions artifacts only, without creating or updating a release.

Configure `PRIVATE_REPO_TOKEN` as a repository Actions secret with read access to **both** `AndersKlint/flutter_package_chinese_popup_dict` and `AndersKlint/dart_paddle_ocr` (fine-grained token: Contents read access to both repositories). The default `GITHUB_TOKEN` cannot read other private repositories.

### Android Signing

Both manual and tag Android builds require these repository Actions secrets:

| Secret | Value |
|--------|-------|
| `ANDROID_KEYSTORE_BASE64` | Base64-encoded persistent release keystore |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore password |
| `ANDROID_KEY_ALIAS` | Signing key alias |
| `ANDROID_KEY_PASSWORD` | Signing key password |

Use your existing release key if available. Otherwise create one once, outside the repository:

```bash
keytool -genkeypair -v -keystore "$HOME/hankan-release.jks" -storetype JKS -alias hankan -keyalg RSA -keysize 4096 -validity 10000
base64 -w 0 "$HOME/hankan-release.jks"
```

Save the base64 output as `ANDROID_KEYSTORE_BASE64` in GitHub **Settings → Secrets and variables → Actions**; add the passwords and alias as the other secrets. Keep a secure backup of the keystore and credentials: future updates must use the same signing key. Never commit them. Missing signing secrets fail the workflow before building.

Local release builds use environment variables `ANDROID_KEYSTORE_PATH` (absolute keystore path), `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, and `ANDROID_KEY_PASSWORD`. Release signing has no debug-key fallback.

Android produces a universal APK supporting arm64-v8a, armeabi-v7a, and x86_64, including the OCR native libraries. For `v0.5.1-beta`, the release assets are:

| Platform | Assets | Checksums |
| --- | --- | --- |
| Android | `HanKan-android-v0.5.1-beta.apk` | `SHA256SUMS-android` |
| Windows | `HanKan-windows-x64-v0.5.1-beta.zip`, `HanKan-windows-x64-setup-v0.5.1-beta.exe` | `SHA256SUMS-windows-x64` |
| Linux | `HanKan-linux-x64-v0.5.1-beta.flatpak` | `SHA256SUMS-linux-x64` |

The Actions artifact is `hankan-android`. Manual builds use the version name and build number from `pubspec.yaml`; tag builds use the exact tag in filenames, strip the leading `v` for the Android version name, and use the workflow run number as the Android version code. Verify a downloaded APK with `sha256sum -c SHA256SUMS-android`.

### Publish v0.5.1-beta

After merging the release changes and configuring secrets, run:

```bash
git tag v0.5.1-beta
git push origin v0.5.1-beta
```

The Windows installer/portable ZIP, Linux Flatpak, and Android workflows publish independently to the same non-draft release for this tag.

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
