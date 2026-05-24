import 'dart:io' show Platform;

/// Whether the app is running on a desktop platform (Linux, macOS, Windows).
bool get isDesktop =>
    Platform.isMacOS || Platform.isLinux || Platform.isWindows;
