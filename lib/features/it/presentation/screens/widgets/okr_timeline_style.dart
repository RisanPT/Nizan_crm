import 'package:flutter/material.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/it/domain/models/okr_model.dart';
import 'package:nizan_crm/features/it/domain/okr_pace.dart';

// Colours and small pieces shared by the OKR timeline, its phone list and the detail sheet, so
// "at risk" and "company objective" look the same everywhere.

Color okrHealthColor(OkrHealth h) => switch (h) {
      OkrHealth.done => const Color(0xFF0F766E),
      OkrHealth.onTrack => const Color(0xFF16A34A),
      OkrHealth.atRisk => const Color(0xFFD97706),
      OkrHealth.offTrack => const Color(0xFFDC2626),
      OkrHealth.blocked => const Color(0xFF9F1239),
      OkrHealth.notStarted => const Color(0xFF64748B),
      OkrHealth.unscheduled => const Color(0xFF64748B),
    };

/// The key result colour: blue while in progress, the "done" teal once finished.
Color okrKeyResultColor(KeyResultItem kr) => kr.completed ? okrHealthColor(OkrHealth.done) : const Color(0xFF2563EB);

String okrLevelName(String level) => switch (level) {
      'company' => 'Company objective',
      'department' => 'Department objective',
      _ => 'Project objective',
    };

Color okrLevelColor(CrmTheme crm, String level) => switch (level) {
      'company' => crm.primary,
      'department' => const Color(0xFF2563EB),
      _ => const Color(0xFF7C3AED),
    };

/// A small square with C / D / P — where the objective sits in the alignment.
class OkrLevelChip extends StatelessWidget {
  const OkrLevelChip({super.key, required this.level, this.size = 18});

  final String level;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = okrLevelColor(context.crmColors, level);
    return Tooltip(
      message: okrLevelName(level),
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(5), border: Border.all(color: color.withValues(alpha: 0.5))),
        child: Text(
          level.isEmpty ? 'P' : level[0].toUpperCase(),
          style: TextStyle(fontSize: size * 0.58, fontWeight: FontWeight.w800, color: color, height: 1),
        ),
      ),
    );
  }
}

/// "At risk" / "On track" … as a pill, with the sentence beside it when there is one.
class OkrHealthChip extends StatelessWidget {
  const OkrHealthChip({super.key, required this.pace, this.withNote = false});

  final OkrPace pace;
  final bool withNote;

  @override
  Widget build(BuildContext context) {
    final color = okrHealthColor(pace.health);
    final note = withNote ? okrPaceNote(pace) : '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
      child: Text(
        note.isEmpty ? pace.health.label : '${pace.health.label} · $note',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

/// A ring with the percentage inside (the phone list).
class OkrProgressRing extends StatelessWidget {
  const OkrProgressRing({super.key, required this.percent, required this.color, this.size = 44});

  final int percent;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(alignment: Alignment.center, children: [
        SizedBox.expand(
          child: CircularProgressIndicator(value: percent / 100, strokeWidth: 4.5, backgroundColor: color.withValues(alpha: 0.15), valueColor: AlwaysStoppedAnimation(color)),
        ),
        Text('$percent%', style: TextStyle(fontSize: size * 0.27, fontWeight: FontWeight.w800, color: crm.textPrimary)),
      ]),
    );
  }
}

/// A horizontal bar with the objective's progress and, when it has dates, a tick for where
/// the calendar says it should be today.
class OkrProgressBar extends StatelessWidget {
  const OkrProgressBar({super.key, required this.pace, this.height = 8});

  final OkrPace pace;
  final double height;

  @override
  Widget build(BuildContext context) {
    final color = okrHealthColor(pace.health);
    final crm = context.crmColors;
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      final tick = pace.expected;
      return SizedBox(
        height: height + 6,
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned(
            left: 0,
            right: 0,
            top: 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(height),
              child: SizedBox(
                height: height,
                child: Stack(children: [
                  Container(color: crm.border.withValues(alpha: 0.7)),
                  FractionallySizedBox(widthFactor: (pace.progress / 100).clamp(0.0, 1.0), child: Container(color: color)),
                ]),
              ),
            ),
          ),
          if (tick != null && pace.health != OkrHealth.done)
            Positioned(
              left: (w * tick).clamp(0.0, w) - 1,
              top: 0,
              child: Tooltip(
                message: 'Should be at ${pace.expectedPercent}% by today',
                child: Container(width: 2, height: height + 6, color: crm.textPrimary.withValues(alpha: 0.75)),
              ),
            ),
        ]),
      );
    });
  }
}
