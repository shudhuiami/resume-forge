import 'package:flutter/material.dart';

/// The one confirmation the app shows before it throws work away.
///
/// There are three destructive actions in this app — delete a resume, replace
/// everything with the sample, clear every field — and each of them used to
/// hand-build the same `AlertDialog`: same title shape, same sentence of
/// consequence, same `Cancel` text button, same error-coloured confirm. They
/// matched because they were copied from one another, and nothing kept them
/// matching.
///
/// Everything about the shape comes from `dialogTheme`; the only thing stated
/// here is the part that is specific to destruction — the confirm button wears
/// the error colour so it can never be mistaken for the safe answer, and
/// `Cancel` is the plain, unemphasised one. Returns false when the dialog is
/// dismissed by tapping outside or by the back gesture, so "did not answer" is
/// treated as "do not do it".
Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
}) async {
  final answer = await showDialog<bool>(
    context: context,
    builder: (context) {
      final scheme = Theme.of(context).colorScheme;
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return answer ?? false;
}
