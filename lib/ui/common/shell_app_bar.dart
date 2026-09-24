import 'package:flutter/material.dart';
import 'package:fes_distribution/ui/app/shell_scope.dart';

/// App bar for pages inside the app shell — shows hamburger to open the drawer.
class ShellAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ShellAppBar({
    super.key,
    required this.title,
    this.actions,
  });

  final String title;
  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final hasDrawer = ShellScope.maybeOf(context) != null;

    return AppBar(
      automaticallyImplyLeading: !hasDrawer,
      leading: hasDrawer
          ? IconButton(
              icon: const Icon(Icons.menu),
              tooltip: 'Menu',
              onPressed: () => ShellScope.openDrawer(context),
            )
          : null,
      title: Text(title),
      actions: actions,
    );
  }
}
