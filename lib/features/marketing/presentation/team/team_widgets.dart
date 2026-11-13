import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/marketing/data/team_models.dart';

// The small pieces every Team Dashboard tab is built from, so they read as one family.

const kTeamGood = Color(0xFF22A06B);
const kTeamBad = Color(0xFFDC4C4C);
const kTeamWatch = Color(0xFFF5A524);
const kTeamBlue = Color(0xFF3B82F6);
const kTeamGrey = Color(0xFF9AA0A6);

Color workStatusColor(WorkStatus s) => switch (s) {
      WorkStatus.completed => kTeamGood,
      WorkStatus.inProgress => kTeamBlue,
      WorkStatus.pending => kTeamWatch,
      WorkStatus.blocked => kTeamBad,
      WorkStatus.notStarted => kTeamGrey,
    };

Color priorityColor(String p) => switch (p) {
      'high' => kTeamBad,
      'low' => kTeamGrey,
      _ => kTeamWatch,
    };

IconData kindIcon(ActivityKind k) => switch (k) {
      ActivityKind.task => Icons.task_alt_rounded,
      ActivityKind.meeting => Icons.groups_2_outlined,
      ActivityKind.shoot => Icons.videocam_outlined,
      ActivityKind.post => Icons.share_outlined,
      ActivityKind.campaign => Icons.campaign_outlined,
      ActivityKind.strategy => Icons.flag_outlined,
      ActivityKind.other => Icons.more_horiz_rounded,
    };

/// A donut / legend palette by position, so a chart and its legend agree.
const _palette = <Color>[Color(0xFF7C5CE8), Color(0xFF3B82F6), Color(0xFF22A06B), Color(0xFFF5A524), Color(0xFFE05D9A), Color(0xFF14B8A6), Color(0xFF9AA0A6)];
Color teamColor(int i) => _palette[i % _palette.length];

String shortDay(String day) {
  final d = DateTime.tryParse(day);
  return d == null ? day : DateFormat('d MMM').format(d);
}

String timeOf(DateTime? d) => d == null ? '' : DateFormat('h:mm a').format(d);

/// "2 – 8 Nov 2026".
String rangeLabel(DateTime from, DateTime to) {
  if (from.year == to.year && from.month == to.month && from.day == to.day) return DateFormat('d MMM yyyy').format(from);
  if (from.year == to.year && from.month == to.month) return '${from.day} – ${DateFormat('d MMM yyyy').format(to)}';
  return '${DateFormat('d MMM').format(from)} – ${DateFormat('d MMM yyyy').format(to)}';
}

String pctText(int? v) => v == null ? '—' : '$v%';

/// A person's initials in a tinted circle.
class MemberAvatar extends StatelessWidget {
  const MemberAvatar(this.name, {super.key, this.size = 28});
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    final initials = parts.isEmpty ? '?' : (parts.length == 1 ? parts.first[0] : parts.first[0] + parts.last[0]).toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: crm.primary.withValues(alpha: 0.12), shape: BoxShape.circle),
      child: Text(initials, style: TextStyle(fontSize: size * 0.4, fontWeight: FontWeight.w800, color: crm.primary)),
    );
  }
}

/// One headline number: label, big value, and how it moved.
class TeamKpiTile extends StatelessWidget {
  const TeamKpiTile({super.key, required this.icon, required this.label, required this.value, this.note, this.good, this.color});
  final IconData icon;
  final String label;
  final String value;
  final String? note;

  /// null = neutral, true = green, false = red.
  final bool? good;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final tint = color ?? crm.primary;
    final noteColor = good == null ? crm.textSecondary : (good! ? kTeamGood : kTeamBad);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(color: crm.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: crm.border)),
      child: Row(children: [
        Container(width: 38, height: 38, decoration: BoxDecoration(color: tint.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(11)), child: Icon(icon, size: 20, color: tint)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: crm.textPrimary, letterSpacing: -0.4))),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: crm.textSecondary, fontWeight: FontWeight.w600)),
            if (note != null && note!.isNotEmpty) Text(note!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.5, color: noteColor, fontWeight: FontWeight.w700)),
          ]),
        ),
      ]),
    );
  }
}

/// A row of tiles that wraps to as many columns as the width allows.
class TeamTileGrid extends StatelessWidget {
  const TeamTileGrid({super.key, required this.children, this.minWidth = 190});
  final List<Widget> children;
  final double minWidth;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        const gap = 10.0;
        final cols = (box.maxWidth / minWidth).floor().clamp(1, children.length.clamp(1, 6));
        final w = (box.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(spacing: gap, runSpacing: gap, children: [for (final c in children) SizedBox(width: w, child: c)]);
      });
}

/// A thin progress bar with its percentage.
class TeamBar extends StatelessWidget {
  const TeamBar({super.key, required this.pct, this.color, this.height = 8, this.showLabel = true});
  final int pct;
  final Color? color;
  final double height;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final c = color ?? crm.primary;
    return Row(children: [
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(height),
          child: LinearProgressIndicator(value: (pct.clamp(0, 100)) / 100, minHeight: height, backgroundColor: c.withValues(alpha: 0.13), valueColor: AlwaysStoppedAnimation(c)),
        ),
      ),
      if (showLabel) ...[const SizedBox(width: 8), SizedBox(width: 38, child: Text('$pct%', textAlign: TextAlign.right, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: crm.textPrimary)))],
    ]);
  }
}
