import 'package:flutter/material.dart';

class ResponsiveBreakpoints {
  static const double mobile = 600;
  static const double tablet = 1024;
  // A large / expanded window (wide desktop, unfolded large foldable in
  // landscape). Screens may show an extra column above this.
  static const double expanded = 1440;
  // At/above this width a list+detail two-pane layout fits comfortably — the
  // sweet spot for an unfolded foldable's inner display. Screens opt in.
  static const double twoPane = 840;
}

/// A utility widget that returns different layouts based on screen constraints.
class ResponsiveBuilder extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget desktop;

  const ResponsiveBuilder({
    super.key,
    required this.mobile,
    this.tablet,
    required this.desktop,
  });

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < ResponsiveBreakpoints.mobile;

  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= ResponsiveBreakpoints.mobile &&
      MediaQuery.sizeOf(context).width < ResponsiveBreakpoints.tablet;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= ResponsiveBreakpoints.tablet;

  /// A wide / expanded window (wide desktop or a large foldable unfolded in
  /// landscape) — screens can show an extra column here.
  static bool isExpanded(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= ResponsiveBreakpoints.expanded;

  /// True when the window is wide enough for a comfortable list+detail
  /// two-pane layout (unfolded foldables, tablets, desktop).
  static bool isTwoPane(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= ResponsiveBreakpoints.twoPane;

  /// A sensible responsive column count for grids/cards, capped at [max].
  /// 1 on phones, 2 on tablets/foldables, 3 on desktop, 4 when expanded.
  static int columns(BuildContext context, {int max = 4}) {
    final w = MediaQuery.sizeOf(context).width;
    var n = 1;
    if (w >= ResponsiveBreakpoints.expanded) {
      n = 4;
    } else if (w >= ResponsiveBreakpoints.tablet) {
      n = 3;
    } else if (w >= ResponsiveBreakpoints.mobile) {
      n = 2;
    }
    return n > max ? max : n;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= ResponsiveBreakpoints.tablet) {
          return desktop;
        } else if (constraints.maxWidth >= ResponsiveBreakpoints.mobile) {
          return tablet ?? mobile;
        } else {
          return mobile;
        }
      },
    );
  }
}
