import 'dart:io' show Platform;

import 'package:alarm/alarm.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// A single follow-up to alarm on. Decoupled from the Lead model so this service
/// has no dependency on the sales feature (pass the primitive fields in).
class FollowUpReminder {
  final String leadId;
  final String name;
  final String phone;

  /// The scheduled follow-up date/time.
  final DateTime followUpAt;

  /// Optional lead-time — fire the alarm this many minutes BEFORE [followUpAt].
  final int reminderMinutes;

  const FollowUpReminder({
    required this.leadId,
    required this.name,
    required this.followUpAt,
    this.phone = '',
    this.reminderMinutes = 0,
  });
}

/// Rings a real, looping full-screen alarm when a lead follow-up is due — even
/// when the phone is locked, idle, or the app was killed. Backed by the `alarm`
/// package (AlarmManager + a foreground alarm service), which is far more
/// reliable than a scheduled local notification.
///
/// Android-only; every method is a safe no-op on web/iOS.
class FollowUpAlarmService {
  FollowUpAlarmService._();
  static final FollowUpAlarmService instance = FollowUpAlarmService._();

  /// Bundled alarm tone (see assets/audio/). Loops until the user stops it.
  static const String _asset = 'assets/audio/alarm.mp3';

  bool _ready = false;
  bool get _supported => !kIsWeb && Platform.isAndroid;

  /// Initialise the alarm engine. Safe to call repeatedly.
  Future<void> init() async {
    if (_ready || !_supported) return;
    await Alarm.init();
    _ready = true;
  }

  /// Ask for the permissions a reliable alarm needs: notifications, exact-alarm
  /// scheduling, and — crucially — a battery-optimisation exemption so Doze /
  /// OEM battery savers don't defer or kill the alarm while the screen is off.
  /// (The alarm package requests notification + full-screen-intent itself too.)
  Future<void> requestPermissions() async {
    if (!_supported) return;
    await init();
    if (!await Permission.notification.isGranted) {
      await Permission.notification.request();
    }
    if (!await Permission.scheduleExactAlarm.isGranted) {
      await Permission.scheduleExactAlarm.request();
    }
    if (!await Permission.ignoreBatteryOptimizations.isGranted) {
      await Permission.ignoreBatteryOptimizations.request();
    }
  }

  // Stable positive 31-bit id from the lead id, so re-scheduling replaces (not
  // duplicates) the alarm and [cancelForLead] can find it.
  int _idFor(String leadId) => leadId.hashCode & 0x7fffffff;

  /// Schedule (or reschedule) the alarm for one follow-up. Past-due times are
  /// skipped.
  Future<void> scheduleForLead(FollowUpReminder r) async {
    if (!_supported) return;
    await init();

    final fireAt = r.followUpAt.subtract(Duration(minutes: r.reminderMinutes));
    if (!fireAt.isAfter(DateTime.now())) return;

    await Alarm.set(
      alarmSettings: AlarmSettings(
        id: _idFor(r.leadId),
        dateTime: fireAt,
        assetAudioPath: _asset,
        loopAudio: true,
        vibrate: true,
        androidFullScreenIntent: true,
        warningNotificationOnKill: true,
        volumeSettings: VolumeSettings.fade(
          fadeDuration: const Duration(seconds: 3),
          volume: 0.9,
          volumeEnforced: true,
        ),
        notificationSettings: NotificationSettings(
          title: 'Follow-up due: ${r.name}',
          body: r.phone.isEmpty ? 'Open the lead to follow up' : 'Call ${r.phone}',
          stopButton: 'Stop',
        ),
        payload: r.leadId,
      ),
    );
  }

  /// Cancel a lead's pending alarm (call when the follow-up is completed, its
  /// date changes, the lead leaves the Follow-up stage, or it's deleted).
  Future<void> cancelForLead(String leadId) async {
    if (!_supported) return;
    await Alarm.stop(_idFor(leadId));
  }

  /// Re-arm the full set of upcoming follow-ups. Clears everything first so
  /// stale alarms (completed / rescheduled leads) never fire. Call on app start
  /// and after the leads list loads.
  Future<void> reconcile(List<FollowUpReminder> upcoming) async {
    if (!_supported) return;
    await init();
    await Alarm.stopAll();
    for (final r in upcoming) {
      await scheduleForLead(r);
    }
  }
}
