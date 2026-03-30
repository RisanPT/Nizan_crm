import 'package:flutter/material.dart';
import '../../core/utils/responsive_builder.dart';
import 'sidebar.dart';

class MainLayout extends StatelessWidget {
  final Widget child;
  final String title;

  const MainLayout({
    super.key,
    required this.child,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveBuilder.isMobile(context);

    if (isMobile) {
      return Scaffold(
        body: SafeArea(child: child),
      );
    }

    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Sidebar(),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(24.0),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}
