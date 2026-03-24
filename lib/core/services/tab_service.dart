import 'package:flutter/foundation.dart';
import 'package:hankan_chinese_reader/core/models/tab_model.dart';

/// Manages the collection of open document tabs.
class TabService {
  /// The list of currently open tabs.
  final ValueNotifier<List<TabModel>> tabs =
      ValueNotifier<List<TabModel>>([]);

  /// The index of the currently active tab, or -1 if none.
  final ValueNotifier<int> activeIndex = ValueNotifier<int>(-1);

  int _nextId = 1;

  /// Returns the currently active tab, or `null` if none.
  TabModel? get activeTab {
    final idx = activeIndex.value;
    final list = tabs.value;
    if (idx < 0 || idx >= list.length) return null;
    return list[idx];
  }

  /// Opens a new tab and makes it active.
  TabModel addTab({
    required String title,
    required DocumentType type,
    String? filePath,
    String? textContent,
  }) {
    final tab = TabModel(
      id: 'tab_${_nextId++}',
      title: title,
      type: type,
      filePath: filePath,
      textContent: textContent,
    );
    tabs.value = [...tabs.value, tab];
    activeIndex.value = tabs.value.length - 1;
    return tab;
  }

  /// Closes the tab at [index].
  void closeTab(int index) {
    final list = [...tabs.value];
    if (index < 0 || index >= list.length) return;
    list.removeAt(index);
    tabs.value = list;

    // Adjust active index.
    if (list.isEmpty) {
      activeIndex.value = -1;
    } else if (activeIndex.value >= list.length) {
      activeIndex.value = list.length - 1;
    } else if (activeIndex.value > index) {
      activeIndex.value = activeIndex.value - 1;
    }
  }

  /// Switches to the tab at [index].
  void setActiveTab(int index) {
    if (index >= 0 && index < tabs.value.length) {
      activeIndex.value = index;
    }
  }

  /// Marks a tab as modified or unmodified and notifies listeners.
  void setModified(String tabId, {required bool modified}) {
    final list = tabs.value;
    final tab = list.firstWhere((t) => t.id == tabId);
    tab.isModified = modified;
    // Trigger rebuild.
    tabs.value = [...list];
  }

  /// Updates the title of a tab.
  void setTitle(String tabId, String title) {
    final list = tabs.value;
    final tab = list.firstWhere((t) => t.id == tabId);
    tab.title = title;
    tabs.value = [...list];
  }
}
