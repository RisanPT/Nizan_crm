import 'package:flutter/material.dart';

import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';

/// Color for a 1-25 Weekly Growth Score (red → amber → green).
Color marketingScoreColor(int score) {
  if (score >= 18) return Mkt.good; // strong
  if (score >= 10) return Mkt.warn; // moderate
  if (score >= 4) return Mkt.bad; // low
  return Mkt.grey; // dormant
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
      padding: EdgeInsets.symmetric(horizontal: large ? 14 : 10, vertical: large ? 8 : 5),
      decoration: BoxDecoration(
        color: Mkt.tint(c),
        borderRadius: BorderRadius.circular(large ? 12 : 20),
        border: Border.all(color: Mkt.tint(c, 0.4)),
      ),
      child: RichText(
        text: TextSpan(children: [
          TextSpan(text: '$score', style: mktText(large ? 22 : 14, weight: FontWeight.w800, color: c)),
          TextSpan(text: ' /25', style: mktText(large ? 12 : 10, weight: FontWeight.w700, color: c.withValues(alpha: 0.7))),
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
    if (movement == null) {
      return Text('new', style: mktText(11, weight: FontWeight.w700, color: Mkt.inkSoft));
    }
    final m = movement!;
    final Color c = m > 0 ? Mkt.good : (m < 0 ? Mkt.bad : Mkt.inkSoft);
    final IconData icon = m > 0 ? Icons.arrow_upward : (m < 0 ? Icons.arrow_downward : Icons.remove);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: c),
        const SizedBox(width: 2),
        Text('${m.abs()}', style: mktText(12, weight: FontWeight.w800, color: c)),
      ],
    );
  }
}
