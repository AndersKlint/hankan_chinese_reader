import 'package:flutter_test/flutter_test.dart';
import 'package:hankan_chinese_reader/text_editor/services/text_editor_service.dart';

void main() {
  group('TextEditorService.applyUserEdit', () {
    test('merges rapid single-character inserts into one undo step', () {
      final service = TextEditorService();
      final start = DateTime(2026);

      service.initialize('', isReadMode: false);
      service.applyUserEdit('a', timestamp: start);
      service.applyUserEdit(
        'ab',
        timestamp: start.add(const Duration(milliseconds: 200)),
      );
      service.applyUserEdit(
        'abc',
        timestamp: start.add(const Duration(milliseconds: 400)),
      );

      service.undo();

      expect(service.content.value, '');
      expect(service.canUndo, isFalse);
      expect(service.canRedo, isTrue);
    });

    test('starts a new undo step after the typing pause window', () {
      final service = TextEditorService();
      final start = DateTime(2026);

      service.initialize('', isReadMode: false);
      service.applyUserEdit('a', timestamp: start);
      service.applyUserEdit(
        'ab',
        timestamp: start.add(const Duration(milliseconds: 900)),
      );

      service.undo();
      expect(service.content.value, 'a');

      service.undo();
      expect(service.content.value, '');
    });

    test(
      'starts a new undo step during continuous typing after burst window',
      () {
        final service = TextEditorService();
        final start = DateTime(2026);

        service.initialize('', isReadMode: false);
        service.applyUserEdit('a', timestamp: start);
        service.applyUserEdit(
          'ab',
          timestamp: start.add(const Duration(milliseconds: 200)),
        );
        service.applyUserEdit(
          'abc',
          timestamp: start.add(const Duration(milliseconds: 700)),
        );
        service.applyUserEdit(
          'abcd',
          timestamp: start.add(const Duration(milliseconds: 900)),
        );

        service.undo();
        expect(service.content.value, 'abc');

        service.undo();
        expect(service.content.value, '');
      },
    );

    test('continues merging after a new typing burst starts', () {
      final service = TextEditorService();
      final start = DateTime(2026);

      service.initialize('', isReadMode: false);
      service.applyUserEdit('a', timestamp: start);
      service.applyUserEdit(
        'ab',
        timestamp: start.add(const Duration(milliseconds: 200)),
      );
      service.applyUserEdit(
        'abc',
        timestamp: start.add(const Duration(milliseconds: 900)),
      );
      service.applyUserEdit(
        'abcd',
        timestamp: start.add(const Duration(milliseconds: 1100)),
      );

      service.undo();
      expect(service.content.value, 'ab');

      service.undo();
      expect(service.content.value, '');
    });

    test('does not merge paste edits with typing', () {
      final service = TextEditorService();
      final start = DateTime(2026);

      service.initialize('', isReadMode: false);
      service.applyUserEdit('a', timestamp: start);
      service.applyUserEdit(
        'abcdef',
        timestamp: start.add(const Duration(milliseconds: 200)),
      );

      service.undo();
      expect(service.content.value, 'a');

      service.undo();
      expect(service.content.value, '');
    });

    test('does not merge deletions with typing', () {
      final service = TextEditorService();
      final start = DateTime(2026);

      service.initialize('', isReadMode: false);
      service.applyUserEdit('a', timestamp: start);
      service.applyUserEdit(
        'ab',
        timestamp: start.add(const Duration(milliseconds: 200)),
      );
      service.applyUserEdit(
        'a',
        timestamp: start.add(const Duration(milliseconds: 300)),
      );

      service.undo();
      expect(service.content.value, 'ab');

      service.undo();
      expect(service.content.value, '');
    });
  });
}
