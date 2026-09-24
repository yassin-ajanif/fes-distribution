import 'package:flutter/material.dart';

/// Mobile-first breakpoints.
class AppBreakpoints {
  AppBreakpoints._();

  static const mobile = 600.0;
  static const tablet = 900.0;
}

bool isMobile(BuildContext context) =>
    MediaQuery.sizeOf(context).width < AppBreakpoints.mobile;

bool isTabletOrWider(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= AppBreakpoints.mobile;

bool isDesktop(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= AppBreakpoints.tablet;
