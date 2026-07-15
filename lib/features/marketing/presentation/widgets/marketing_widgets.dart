import 'package:flutter/material.dart';
import '../../../../core/theme/crm_theme.dart';

/// Color for a 1-25 Weekly Growth Score (red → amber → green).
Color marketingScoreColor(int score) {
  if (score >= 18) return const Color(0xFF2E7D32); // strong
  if (score >= 10) return const Color(0xFFB8860B); // moderate
  if (score >= 4) return const Color(0xFFE65100); // low
  return const Color(0xFF9E9E9E); // dormant
}

/// A rounded "score / 25" badge.
class ScoreBadge extends StatelessWidget {
  final int score;
  final bool large;
  const ScoreBadge({super.key, required this.score, this.large = false});

  @override
  Widget build(BuildContext context) {
    final c = marketingScoreColor(score);
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: large ? 14 : 10, vertical: large ? 8 : 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withValues(alpha: 0.5)),
      ),
      child: RichText(
        text: TextSpan(children: [
          TextSpan(
            text: '$score',
            style: TextStyle(
                color: c,
                fontSize: large ? 22 : 15,
                fontWeight: FontWeight.w800),
          ),
          TextSpan(
            text: ' /25',
            style: TextStyle(
                color: c.withValues(alpha: 0.7),
                fontSize: large ? 12 : 10,
                fontWeight: FontWeight.w700),
          ),
        ]),
      ),
    );
  }
}

/// Week-over-week movement chip (▲/▼/—).
class MovementChip extends StatelessWidget {
  final int? movement;
  const MovementChip({super.key, required this.movement});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    if (movement == null) {
      return Text('new',
          style: TextStyle(
              color: crm.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700));
    }
    final m = movement!;
    final Color c = m > 0
        ? const Color(0xFF2E7D32)
        : (m < 0 ? const Color(0xFFD32F2F) : crm.textSecondary);
    final IconData icon = m > 0
        ? Icons.arrow_upward
        : (m < 0 ? Icons.arrow_downward : Icons.remove);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: c),
        const SizedBox(width: 2),
        Text('${m.abs()}',
            style:
                TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w800)),
      ],
    );
  }
}
