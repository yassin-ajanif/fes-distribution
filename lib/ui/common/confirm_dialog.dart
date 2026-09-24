import 'package:flutter/material.dart';
import 'package:fes_distribution/ui/l10n/strings_scope.dart';

Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String? confirmLabel,
  String? cancelLabel,
}) async {
  final s = context.s;
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(cancelLabel ?? s.actionCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(confirmLabel ?? s.actionConfirm),
        ),
      ],
    ),
  );
  return result ?? false;
}

Future<void> showErrorDialog(
  BuildContext context, {
  required String title,
  required String message,
}) {
  final s = context.s;
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(s.actionOk),
        ),
      ],
    ),
  );
}

Future<bool> showStockShortageDialog(
  BuildContext context, {
  required List<String> lines,
}) async {
  final s = context.s;
  return showConfirmDialog(
    context,
    title: s.stockShortageTitle,
    message: s.stockShortageMessage(lines),
    confirmLabel: s.actionContinue,
  );
}
