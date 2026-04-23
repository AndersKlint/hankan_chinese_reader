/// Stub implementation of [WindowListener] and [windowManager] for web builds
/// where the real `window_manager` package is not available.
mixin WindowListener {
  /// Called when the window is being closed.
  void onWindowClose() {}

  /// Called when the window gains focus.
  void onWindowFocus() {}

  /// Called when the window loses focus.
  void onWindowBlur() {}

  /// Called when the window is maximized.
  void onWindowMaximize() {}

  /// Called when the window is unmaximized.
  void onWindowUnmaximize() {}

  /// Called when the window is minimized.
  void onWindowMinimize() {}

  /// Called when the window is restored from minimized.
  void onWindowRestore() {}

  /// Called when the window is resized.
  void onWindowResize() {}

  /// Called when the window is moved.
  void onWindowMove() {}

  /// Called when the window enters fullscreen.
  void onWindowEnterFullScreen() {}

  /// Called when the window leaves fullscreen.
  void onWindowLeaveFullScreen() {}

  /// Called for any window event.
  void onWindowEvent(String eventName) {}
}

/// No-op stub of [WindowManager].
class _NoOpWindowManager {
  /// No-op implementation.
  Future<void> ensureInitialized() async {}

  /// No-op implementation.
  Future<void> setPreventClose(bool value) async {}

  /// No-op implementation.
  Future<void> close() async {}

  /// No-op implementation.
  void addListener(WindowListener listener) {}

  /// No-op implementation.
  void removeListener(WindowListener listener) {}
}

/// Singleton no-op [WindowManager] instance for web.
final _NoOpWindowManager windowManager = _NoOpWindowManager();
