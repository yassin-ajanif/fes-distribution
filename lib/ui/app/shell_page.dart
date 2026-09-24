import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fes_distribution/ui/app/app_drawer.dart';
import 'package:fes_distribution/ui/app/shell_scope.dart';
import 'package:fes_distribution/ui/common/responsive.dart';
import 'package:fes_distribution/ui/theme/app_theme.dart';

class AppShellPage extends StatefulWidget {
  const AppShellPage({super.key, required this.child});

  final Widget child;

  @override
  State<AppShellPage> createState() => _AppShellPageState();
}

class _AppShellPageState extends State<AppShellPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final mobile = isMobile(context);

    if (mobile) {
      return ShellScope(
        scaffoldKey: _scaffoldKey,
        child: Scaffold(
          key: _scaffoldKey,
          drawer: AppDrawer(currentLocation: location),
          body: widget.child,
        ),
      );
    }

    return Row(
      children: [
        Material(
          color: AppColors.card,
          child: SizedBox(
            width: 280,
            child: AppMenuPanel(
              currentLocation: location,
              onNavigate: (route) => context.go(route),
            ),
          ),
        ),
        const VerticalDivider(width: 1, thickness: 1),
        Expanded(child: widget.child),
      ],
    );
  }
}
