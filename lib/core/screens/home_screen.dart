import 'package:flutter/material.dart';
import 'package:hankan_chinese_reader/core/models/tab_model.dart';
import 'package:hankan_chinese_reader/core/service_locator.dart';
import 'package:hankan_chinese_reader/core/services/file_service.dart';
import 'package:hankan_chinese_reader/core/services/tab_service.dart';
import 'package:hankan_chinese_reader/core/services/theme_service.dart';
import 'package:hankan_chinese_reader/text_editor/screens/text_editor_screen.dart';
import 'package:hankan_chinese_reader/pdf_reader/screens/pdf_reader_screen.dart';

/// The main shell screen with tab bar and content area.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Map<String, Widget> _tabBodies = <String, Widget>{};

  @override
  Widget build(BuildContext context) {
    final tabService = getIt<TabService>();
    final themeService = getIt<ThemeService>();

    return ListenableBuilder(
      listenable: themeService,
      builder: (context, _) {
        final themeMode = themeService.value;
        return ValueListenableBuilder<List<TabModel>>(
          valueListenable: tabService.tabs,
          builder: (context, tabs, _) {
            return ValueListenableBuilder<int>(
              valueListenable: tabService.activeIndex,
              builder: (context, activeIndex, __) {
                return Scaffold(
                  appBar: AppBar(
                    title: const Text('Hankan Chinese Reader'),
                    actions: [
                      IconButton(
                        icon: Icon(
                          themeMode == ThemeMode.dark
                              ? Icons.light_mode_outlined
                              : Icons.dark_mode_outlined,
                        ),
                        tooltip: themeMode == ThemeMode.dark
                            ? 'Switch to light mode'
                            : 'Switch to dark mode',
                        onPressed: () => themeService.toggleTheme(),
                      ),
                      IconButton(
                        icon: const Icon(Icons.note_add_outlined),
                        tooltip: 'New text document',
                        onPressed: () => _createNewDocument(tabService),
                      ),
                      IconButton(
                        icon: const Icon(Icons.folder_open_outlined),
                        tooltip: 'Open file',
                        onPressed: () => _openFile(context, tabService),
                      ),
                    ],
                    bottom: tabs.isEmpty
                        ? null
                        : PreferredSize(
                            preferredSize: const Size.fromHeight(40),
                            child: _TabBar(
                              tabs: tabs,
                              activeIndex: activeIndex,
                              onSelect: tabService.setActiveTab,
                              onClose: tabService.closeTab,
                            ),
                          ),
                  ),
                  body: _buildBody(tabs, activeIndex),
                );
              },
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

  void _createNewDocument(TabService tabService) {
    tabService.addTab(
      title: 'Untitled',
      type: DocumentType.text,
      textContent: '',
    );
  }

  Future<void> _openFile(BuildContext context, TabService tabService) async {
    final fileService = getIt<FileService>();
    final result = await fileService.pickFile();
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final name = file.name;
    final path = file.path;
    final extension = name.split('.').last.toLowerCase();

    if (extension == 'pdf') {
      tabService.addTab(title: name, type: DocumentType.pdf, filePath: path);
    } else {
      // Text file.
      String content;
      if (path != null) {
        content = await fileService.readTextFile(path);
      } else if (file.bytes != null) {
        content = fileService.readTextFromBytes(file.bytes!);
      } else {
        return;
      }

      tabService.addTab(
        title: name,
        type: DocumentType.text,
        filePath: path,
        textContent: content,
      );
    }
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
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemBuilder: (context, index) {
          final tab = tabs[index];
          final isActive = index == activeIndex;

          return GestureDetector(
            onTap: () => onSelect(index),
            child: Container(
              margin: const EdgeInsets.only(right: 2),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isActive
                    ? colorScheme.primaryContainer.withValues(alpha: 0.5)
                    : Colors.transparent,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(8),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    tab.type == DocumentType.pdf
                        ? Icons.picture_as_pdf_outlined
                        : Icons.description_outlined,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${tab.title}${tab.isModified ? ' •' : ''}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isActive
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: isActive
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => onClose(index),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Icon(
                        Icons.close,
                        size: 14,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
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
