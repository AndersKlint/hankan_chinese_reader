import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hankan_chinese_reader/core/models/tab_model.dart';
import 'package:hankan_chinese_reader/core/service_locator.dart';
import 'package:hankan_chinese_reader/core/services/document_history_service.dart';
import 'package:hankan_chinese_reader/core/services/file_service.dart';
import 'package:hankan_chinese_reader/core/services/tab_service.dart';
import 'package:hankan_chinese_reader/core/services/theme_service.dart';
import 'package:hankan_chinese_reader/core/widgets/unsaved_changes_dialogs.dart';
import 'package:hankan_chinese_reader/text_editor/screens/text_editor_screen.dart';
import 'package:hankan_chinese_reader/text_editor/services/text_editor_service_registry.dart';
import 'package:hankan_chinese_reader/pdf_reader/screens/pdf_reader_screen.dart';
import 'package:window_manager/window_manager.dart';

/// The main shell screen with tab bar and content area.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WindowListener {
  final Map<String, Widget> _tabBodies = <String, Widget>{};
  final TabService _tabService = getIt<TabService>();
  final ThemeService _themeService = getIt<ThemeService>();
  final DocumentHistoryService _documentHistoryService =
      getIt<DocumentHistoryService>();

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowClose() {
    final hasUnsaved = _tabService.tabs.value.any((t) => t.isModified);
    if (!hasUnsaved) {
      // Release prevent-close and close immediately instead of destroy()
      // which causes multi-second delay in release builds.
      windowManager.setPreventClose(false);
      windowManager.close();
      return;
    }

    _confirmCloseWithUnsavedChanges();
  }

  Future<void> _confirmCloseWithUnsavedChanges() async {
    final unsavedCount =
        _tabService.tabs.value.where((t) => t.isModified).length;

    final shouldExit = await showUnsavedAppCloseDialog(
      // ignore: use_build_context_synchronously
      context,
      unsavedCount: unsavedCount,
    );

    if (shouldExit) {
      windowManager.setPreventClose(false);
      windowManager.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<TabModel>>(
      valueListenable: _tabService.tabs,
      builder: (context, tabs, _) {
        return ValueListenableBuilder<int>(
          valueListenable: _tabService.activeIndex,
          builder: (context, activeIndex, _) {
            // Read the current brightness from the inherited Theme so the
            // toggle icon updates when ThemeService notifies MaterialApp.
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return PopScope(
              canPop: false,
              onPopInvokedWithResult: (didPop, result) {
                if (didPop) return;
                _confirmAppExitMobile(context);
              },
              child: Scaffold(
                appBar: AppBar(
                  toolbarHeight: 46,
                  titleSpacing: 8,
                  title: tabs.isEmpty
                      ? null
                      : _TabBar(
                          tabs: tabs,
                          activeIndex: activeIndex,
                          onSelect: _tabService.setActiveTab,
                          onClose: (index) => _handleCloseTab(context, index),
                        ),
                  actions: [
                    IconButton(
                      icon: Icon(
                        isDark
                            ? Icons.light_mode_outlined
                            : Icons.dark_mode_outlined,
                      ),
                      visualDensity: VisualDensity.compact,
                      tooltip: isDark
                          ? 'Switch to light mode'
                          : 'Switch to dark mode',
                      onPressed: _themeService.toggleTheme,
                    ),
                    const VerticalDivider(width: 1, indent: 8, endIndent: 8),
                    IconButton(
                      icon: const Icon(Icons.note_add_outlined),
                      visualDensity: VisualDensity.compact,
                      tooltip: 'New text document',
                      onPressed: _createNewDocument,
                    ),
                    const VerticalDivider(width: 1, indent: 8, endIndent: 8),
                    IconButton(
                      icon: const Icon(Icons.folder_open_outlined),
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Open file',
                      onPressed: () => _openFile(context),
                    ),
                    ListenableBuilder(
                      listenable: _documentHistoryService,
                      builder: (context, _) {
                        final recentDocuments =
                            _documentHistoryService.recentDocuments;
                        final hasRecents = recentDocuments.isNotEmpty;
                        return PopupMenuButton<RecentDocumentEntry>(
                          tooltip: 'Recent documents',
                          enabled: hasRecents,
                          onSelected: (entry) =>
                              _openRecentDocument(context, entry),
                          itemBuilder: (context) {
                            return recentDocuments
                                .map((entry) {
                                  return PopupMenuItem<RecentDocumentEntry>(
                                    value: entry,
                                    child: Tooltip(
                                      message: entry.path,
                                      waitDuration: const Duration(
                                        milliseconds: 700,
                                      ),
                                      child: SizedBox(
                                        width: 260,
                                        child: Text(
                                          entry.title,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  );
                                })
                                .toList(growable: false);
                          },
                          child: Icon(
                            Icons.history_outlined,
                            color: hasRecents
                                ? null
                                : Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.38),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 6),
                  ],
                ),
                body: _buildBody(tabs, activeIndex),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBody(List<TabModel> tabs, int activeIndex) {
    if (tabs.isEmpty) {
      return const _EmptyState();
    }
    if (activeIndex < 0 || activeIndex >= tabs.length) {
      return const SizedBox.shrink();
    }

    final activeTab = tabs[activeIndex];
    final liveIds = tabs.map((t) => t.id).toSet();
    _tabBodies.removeWhere((id, _) => !liveIds.contains(id));
    for (final tab in tabs) {
      _tabBodies.putIfAbsent(tab.id, () {
        return switch (tab.type) {
          DocumentType.text => TextEditorScreen(tabId: tab.id),
          DocumentType.pdf => PdfReaderScreen(tabId: tab.id),
        };
      });
    }

    return Stack(
      children: tabs
          .map(
            (tab) => Offstage(
              offstage: tab.id != activeTab.id,
              child: KeyedSubtree(
                key: ValueKey(tab.id),
                child: _tabBodies[tab.id]!,
              ),
            ),
          )
          .toList(growable: false),
    );
  }

  Future<void> _handleCloseTab(BuildContext context, int index) async {
    final tab = _tabService.tabs.value[index];
    if (!tab.isModified) {
      _tabService.closeTab(index);
      return;
    }

    final action = await showUnsavedTabCloseDialog(
      context,
      tabTitle: tab.title,
    );

    switch (action) {
      case UnsavedTabAction.cancel:
        return;
      case UnsavedTabAction.discard:
        _tabService.closeTab(index);
        return;
      case UnsavedTabAction.save:
        if (tab.type == DocumentType.text) {
          final service = getIt<TextEditorServiceRegistry>().getService(tab.id);
          final saved = await service?.save() ?? false;
          if (saved) _tabService.closeTab(index);
        } else {
          _tabService.closeTab(index);
        }
        return;
    }
  }

  Future<void> _confirmAppExitMobile(BuildContext context) async {
    final unsaved = _tabService.tabs.value.where((t) => t.isModified).length;
    if (unsaved == 0) {
      await SystemNavigator.pop();
      return;
    }

    final shouldExit = await showUnsavedAppCloseDialog(
      context,
      unsavedCount: unsaved,
    );

    if (shouldExit) {
      await SystemNavigator.pop();
    }
  }

  void _createNewDocument() {
    _tabService.addTab(
      title: 'Untitled',
      type: DocumentType.text,
      textContent: '',
    );
  }

  Future<void> _openFile(BuildContext context) async {
    final fileService = getIt<FileService>();
    final result = await fileService.pickFile();
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;

    // On web, path is null or a blob URL - use bytes instead
    if (file.path != null && !file.path!.startsWith('blob:')) {
      if (!context.mounted) return;
      await _openDocumentFromPath(
        context,
        path: file.path!,
        title: file.name,
        type: _documentTypeForName(file.name),
      );
      return;
    }

    if (_documentTypeForName(file.name) == DocumentType.pdf) return;

    final bytes = file.bytes ?? await file.xFile.readAsBytes();
    _tabService.addTab(
      title: file.name,
      type: DocumentType.text,
      textContent: fileService.readTextFromBytes(bytes),
    );
  }

  Future<void> _openRecentDocument(
    BuildContext context,
    RecentDocumentEntry entry,
  ) async {
    await _openDocumentFromPath(
      context,
      path: entry.path,
      title: entry.title,
      type: entry.type,
    );
  }

  Future<void> _openDocumentFromPath(
    BuildContext context, {
    required String path,
    required String title,
    required DocumentType type,
  }) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final fileService = getIt<FileService>();

    try {
      switch (type) {
        case DocumentType.pdf:
          _tabService.addTab(
            title: title,
            type: DocumentType.pdf,
            filePath: path,
          );
          break;
        case DocumentType.text:
          final content = await fileService.readTextFile(path);
          _tabService.addTab(
            title: title,
            type: DocumentType.text,
            filePath: path,
            textContent: content,
          );
          break;
      }
      unawaited(
        _documentHistoryService.noteDocumentOpened(
          path: path,
          title: title,
          type: type,
        ),
      );
    } catch (_) {
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Could not open "$title".')));
    }
  }

  DocumentType _documentTypeForName(String name) {
    return name.toLowerCase().endsWith('.pdf')
        ? DocumentType.pdf
        : DocumentType.text;
  }
}

/// Horizontally scrollable tab bar.
class _TabBar extends StatelessWidget {
  final List<TabModel> tabs;
  final int activeIndex;
  final ValueChanged<int> onSelect;
  final ValueChanged<int> onClose;

  const _TabBar({
    required this.tabs,
    required this.activeIndex,
    required this.onSelect,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 46,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemBuilder: (context, index) {
          final tab = tabs[index];
          final isActive = index == activeIndex;

          return GestureDetector(
            onTap: () => onSelect(index),
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: _TabChip(
                  tab: tab,
                  isActive: isActive,
                  colorScheme: colorScheme,
                  onClose: () => onClose(index),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Shown when no tabs are open.
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.menu_book_outlined,
            size: 64,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Welcome to Hankan Chinese Reader',
            style: textTheme.headlineSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a new document or open an existing file to get started.',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single tab chip in the tab bar.
///
/// Extracted to avoid recomputing the border color three times per tab item.
class _TabChip extends StatelessWidget {
  final TabModel tab;
  final bool isActive;
  final ColorScheme colorScheme;
  final VoidCallback onClose;

  const _TabChip({
    required this.tab,
    required this.isActive,
    required this.colorScheme,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = colorScheme.outlineVariant.withValues(alpha: 0.8);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isActive
            ? colorScheme.primaryContainer.withValues(alpha: 0.5)
            : Colors.transparent,
        border: Border(
          top: BorderSide(color: borderColor),
          left: BorderSide(color: borderColor),
          right: BorderSide(color: borderColor),
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            tab.type == DocumentType.pdf
                ? Icons.picture_as_pdf_outlined
                : Icons.description_outlined,
            size: 15,
          ),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: Text(
              '${tab.title}${tab.isModified ? ' •' : ''}',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                color: isActive
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 2),
          InkWell(
            borderRadius: BorderRadius.circular(9),
            onTap: onClose,
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: Icon(
                Icons.close,
                size: 13,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
