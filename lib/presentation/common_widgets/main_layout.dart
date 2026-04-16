import 'package:flutter/material.dart';
import '../../core/utils/responsive_builder.dart';
import 'sidebar.dart';

/// Keeps Fleet-expand state alive across navigations by living above the
/// per-route widget tree that go_router rebuilds on every push.
///
/// Two flags drive the Fleet submenu:
///   [_fleetExpanded]      – the user explicitly opened it.
///   [_fleetUserCollapsed] – the user explicitly closed it (even while on a
///                           fleet route, overriding auto-open behaviour).
class MainLayout extends StatefulWidget {
  final Widget child;
  final String title;

  const MainLayout({
    super.key,
    required this.child,
    required this.title,
  });

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  bool _fleetExpanded = false;
  bool _fleetUserCollapsed = false;

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveBuilder.isMobile(context);

    if (isMobile) {
      return Scaffold(
        body: SafeArea(child: widget.child),
      );
    }

    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Sidebar(
            fleetExpanded: _fleetExpanded,
            fleetUserCollapsed: _fleetUserCollapsed,
            onFleetExpandToggle: (expanded) {
              setState(() {
                _fleetExpanded = expanded;
                // When the user manually collapses, record the intent so the
                // sidebar won't auto-reopen due to the current fleet route.
                if (!expanded) {
                  _fleetUserCollapsed = true;
                } else {
                  _fleetUserCollapsed = false;
                }
              });
            },
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(24.0),
              child: widget.child,
            ),
          ),
        ],
      ),
    );
  }
}
