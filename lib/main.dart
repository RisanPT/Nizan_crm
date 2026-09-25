import 'dart:async';

import 'package:alarm/alarm.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/alarm_ring_overlay.dart';
import 'core/network/connection_banner.dart';

import 'services/notification_service.dart';
import 'core/services/followup_alarm_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _installGlobalErrorHandlers();
  await NotificationService().init();
  // Android-only follow-up alarms (no-op on web/iOS).
  await FollowUpAlarmService.instance.init();
  runApp(const ProviderScope(child: MyApp()));
}

/// Last-resort safety net for errors nothing else caught:
///  • Framework (build/layout) errors are logged instead of silently lost.
///  • Uncaught async errors (a forgotten wait + failed request) are logged
///    and marked handled, so they don't take the app down.
///  • In release builds a widget that throws renders a small, friendly
///    placeholder instead of Flutter's grey/red error box.
void _installGlobalErrorHandlers() {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('Unhandled Flutter error: ${details.exceptionAsString()}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Unhandled async error: $error\n$stack');
    return true;
  };
  if (kReleaseMode) {
    ErrorWidget.builder = (details) => const Material(
          color: Colors.transparent,
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'This section could not be displayed.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
              ),
            ),
          ),
        );
  }
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  AlarmSettings? _ringing;
  StreamSubscription<Object?>? _sub;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _sub = Alarm.ringing.listen((alarmSet) {
        final active = alarmSet.alarms.isEmpty ? null : alarmSet.alarms.first;
        if (mounted) setState(() => _ringing = active);
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _stop() async {
    final s = _ringing;
    if (s != null) await Alarm.stop(s.id);
    if (mounted) setState(() => _ringing = null);
  }

  @override
  Widget build(BuildContext context) {
    final goRouter = ref.watch(goRouterProvider);

    return MaterialApp.router(
      title: 'Team N ERP',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: goRouter,
      builder: (context, child) {
        final ringing = _ringing;
        return Stack(
          children: [
            ConnectionBanner(child: child ?? const SizedBox.shrink()),
            if (ringing != null)
              AlarmRingOverlay(
                alarm: ringing,
                onStop: _stop,
                onOpenLead: () {
                  _stop();
                  goRouter.go('/sales/leads');
                },
              ),
          ],
        );
      },
    );
  }
}
