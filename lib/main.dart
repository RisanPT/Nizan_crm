import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/routing/app_router.dart';
import 'core/theme/crm_theme.dart';

void main() {
  runApp(
    // Wrapping the top level with ProviderScope so Riverpod works inside the app
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goRouter = ref.watch(goRouterProvider);

    return MaterialApp.router(
      title: 'Nizan CRM',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,

        useMaterial3: true,
        extensions: const [
          CrmTheme(
            primary: Color(0xFF2C3E50),      // Deep Blue/Slate
            secondary: Color(0xFFE67E22),    // Warm Orange
            background: Color(0xFFF5F7FA),   // Light Grayish Blue
            surface: Colors.white,           // White
            textPrimary: Color(0xFF2C3E50),  // Deep Blue
            textSecondary: Color(0xFF7F8C8D),// Medium Gray
            border: Color(0xFFE0E6ED),       // Light Gray Border
            success: Color(0xFF27AE60),      // Green
            warning: Color(0xFFF1C40F),      // Yellow
          ),
        ],
      ),
      routerConfig: goRouter,
    );
  }
}
