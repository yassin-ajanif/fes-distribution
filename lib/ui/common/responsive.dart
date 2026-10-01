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

/// Column count for the product card grid.
///
/// Two per row on a phone, three from tablet width up. Three is the cap:
/// more columns than that makes the photo and the price too small to read.
int produitGridColumns(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width >= AppBreakpoints.mobile) return 3;
  return 2;
}
