import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fes_distribution/ui/app/router.dart';

/// Single app router instance — must not be recreated on locale/theme rebuilds
/// because [createRouter] uses shared [GlobalKey]s for navigators.
final routerProvider = Provider<GoRouter>((ref) => createRouter());
