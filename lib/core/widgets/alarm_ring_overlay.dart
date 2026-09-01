import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';

/// Full-screen "follow-up is due" ring UI shown while an alarm is sounding in
/// the foreground. (On the lock screen the alarm's own full-screen notification
/// — with its Stop action — handles this.)
class AlarmRingOverlay extends StatelessWidget {
  final AlarmSettings alarm;
  final VoidCallback onStop;
  final VoidCallback? onOpenLead;

  const AlarmRingOverlay({
    super.key,
    required this.alarm,
    required this.onStop,
    this.onOpenLead,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF7B1E3B),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _PulsingBell(),
                const SizedBox(height: 28),
                Text(
                  alarm.notificationSettings.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                Text(
                  alarm.notificationSettings.body,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 15),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF7B1E3B),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                    onPressed: onStop,
                    icon: const Icon(Icons.alarm_off_rounded),
                    label: const Text('Stop'),
                  ),
                ),
                if (onOpenLead != null) ...[
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: onOpenLead,
                    child: const Text('Open the lead', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PulsingBell extends StatefulWidget {
  const _PulsingBell();
  @override
  State<_PulsingBell> createState() => _PulsingBellState();
}

class _PulsingBellState extends State<_PulsingBell> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 700))
        ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween(begin: 0.9, end: 1.12).animate(
        CurvedAnimation(parent: _c, curve: Curves.easeInOut),
      ),
      child: Container(
        width: 110,
        height: 110,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 58),
      ),
    );
  }
}
