import 'package:flutter/material.dart';
import 'package:fes_distribution/ui/l10n/strings_scope.dart';

/// Save action for the green app bar (white text, spinner while saving).
class AppBarSaveButton extends StatelessWidget {
  const AppBarSaveButton({
    super.key,
    required this.onPressed,
    this.saving = false,
  });

  final VoidCallback? onPressed;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: TextButton.icon(
        onPressed: saving ? null : onPressed,
        style: TextButton.styleFrom(
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white54,
        ),
        icon: saving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.check),
        label: Text(context.s.actionSave),
      ),
    );
  }
}
