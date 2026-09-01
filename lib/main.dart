import 'dart:async';

import 'package:alarm/alarm.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/alarm_ring_overlay.dart';

import 'services/notification_service.dart';
import 'core/services/followup_alarm_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().init();
  // Android-only follow-up alarms (no-op on web/iOS).
  await FollowUpAlarmService.instance.init();
  runApp(const ProviderScope(child: MyApp()));
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
    // Show the full-screen ring UI whenever a follow-up alarm sounds while the
    // app is in the foreground. `ringing` is a value-stream, so it also replays
    // the current state on subscribe — catching an alarm that's already ringing
    // when the app is launched. (Locked/background is handled by the alarm's own
    // full-screen notification + Stop action.)
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
            child ?? const SizedBox.shrink(),
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
