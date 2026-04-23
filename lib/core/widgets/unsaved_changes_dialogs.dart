import 'package:flutter/material.dart';

/// Actions available when closing a single unsaved tab.
enum UnsavedTabAction { cancel, discard, save }

/// Shows a dialog prompting the user what to do with unsaved changes
/// when closing a single tab.
Future<UnsavedTabAction> showUnsavedTabCloseDialog(
  BuildContext context, {
  required String tabTitle,
}) async {
  final result = await showDialog<UnsavedTabAction>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Unsaved Changes'),
      content: Text(
        '"$tabTitle" has unsaved changes. Do you want to save them before closing?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(UnsavedTabAction.cancel),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(UnsavedTabAction.discard),
          child: const Text('Discard'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(UnsavedTabAction.save),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  return result ?? UnsavedTabAction.cancel;
}

/// Shows a dialog warning the user that closing the app will discard
/// unsaved changes. Returns `true` if the user chooses to close anyway.
Future<bool> showUnsavedAppCloseDialog(
  BuildContext context, {
  required int unsavedCount,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Unsaved Changes'),
      content: Text(
        'You have $unsavedCount unsaved document${unsavedCount == 1 ? '' : 's'}. '
        'If you close the app now, your changes will be lost.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Close Anyway'),
        ),
      ],
    ),
  );
  return result ?? false;
}
