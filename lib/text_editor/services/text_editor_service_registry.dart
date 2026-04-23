import 'package:hankan_chinese_reader/text_editor/services/text_editor_service.dart';

/// Holds references to active [TextEditorService] instances keyed by tab ID.
///
/// This allows business logic outside the widget tree (e.g. tab-close
/// confirmation) to reach the live service for a given tab.
class TextEditorServiceRegistry {
  final Map<String, TextEditorService> _services = {};

  /// Registers [service] under [tabId].
  void register(String tabId, TextEditorService service) {
    _services[tabId] = service;
  }

  /// Removes the registration for [tabId].
  void unregister(String tabId) {
    _services.remove(tabId);
  }

  /// Returns the service for [tabId], or `null` if none is registered.
  TextEditorService? getService(String tabId) => _services[tabId];
}
