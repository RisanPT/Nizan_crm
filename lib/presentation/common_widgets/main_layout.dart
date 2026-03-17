import 'package:flutter/material.dart';
import '../../core/utils/responsive_builder.dart';
import 'sidebar.dart';
import 'top_app_bar.dart';

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
      // Mobile: uses standard Scaffold with Drawer for Sidebar
      return Scaffold(
        appBar: TopAppBar(title: title),
        drawer: const Drawer(
          child: Sidebar(),
        ),
        body: child,
      );
    }

    // Tablet/Desktop: Sidebar sits alongside the content body
    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Sidebar(),
          Expanded(
            child: Column(
              children: [
                TopAppBar(title: title),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(24.0),
                    // We wrap child in SingleChildScrollView or let individual screens handle scrolling.
                    // For the CRM, it's better if individual screens handle their own scroll logic 
                    // (e.g., DataTables with sticky headers).
                    child: child,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
