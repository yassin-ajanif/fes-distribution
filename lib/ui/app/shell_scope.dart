import 'package:flutter/material.dart';

/// Lets shell pages open the root drawer.
class ShellScope extends InheritedWidget {
  const ShellScope({
    super.key,
    required this.scaffoldKey,
    required super.child,
  });

  final GlobalKey<ScaffoldState> scaffoldKey;

  static ShellScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellScope>();

  static void openDrawer(BuildContext context) {
    maybeOf(context)?.scaffoldKey.currentState?.openDrawer();
  }

  @override
  bool updateShouldNotify(ShellScope oldWidget) =>
      scaffoldKey != oldWidget.scaffoldKey;
}
