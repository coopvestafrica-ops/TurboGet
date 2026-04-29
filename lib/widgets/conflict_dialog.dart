import 'package:flutter/material.dart';

enum ConflictAction { rename, overwrite, skip }

/// Shows a Rename / Overwrite / Skip dialog when a download would
/// collide with an existing file. Returns `null` if the user dismissed
/// without picking — treat that the same as [ConflictAction.skip].
Future<ConflictAction?> showConflictDialog(
  BuildContext context,
  String filename,
) {
  return showDialog<ConflictAction>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Text('File already exists'),
      content: Text(
        '"$filename" already exists in your downloads folder. '
        'What do you want to do?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, ConflictAction.skip),
          child: const Text('Skip'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, ConflictAction.overwrite),
          child: const Text('Overwrite'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, ConflictAction.rename),
          child: const Text('Rename'),
        ),
      ],
    ),
  );
}
