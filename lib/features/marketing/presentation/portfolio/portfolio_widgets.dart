import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/features/marketing/data/portfolio_models.dart';
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';

// The small pieces every Creative Portfolio tab is built from.

Color shootStatusColor(String s) => switch (s) {
      'completed' => Mkt.good,
      'in_production' => Mkt.warn,
      'post_production' => Mkt.blue,
      'pre_production' => Mkt.violet2,
      'cancelled' => Mkt.bad,
      _ => Mkt.grey,
    };

/// "10 Nov 2026" for a 'YYYY-MM-DD' day.
String shootDay(String day, {String pattern = 'd MMM yyyy'}) {
  final d = DateTime.tryParse(day);
  return d == null ? day : DateFormat(pattern).format(d);
}

/// A shoot's cover: its picture link, or a tinted tile with a camera.
class ShootCover extends StatelessWidget {
  const ShootCover({super.key, required this.url, this.size = 48, this.radius = 10});
  final String url;
  final double size, radius;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(width: size, height: size, color: Mkt.tint(Mkt.violet, 0.12), child: Icon(Icons.videocam_outlined, size: size * 0.45, color: Mkt.violet));
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: url.isEmpty ? fallback : Image.network(url, width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback, loadingBuilder: (_, child, p) => p == null ? child : fallback),
    );
  }
}

/// The five milestones in a row: a filled tick when done, a ring on the one in progress, an empty ring after; with their planned days.
class MilestoneStepper extends StatelessWidget {
  const MilestoneStepper({super.key, required this.milestones, this.current, this.showDates = true});
  final List<Milestone> milestones;
  final String? current;
  final bool showDates;

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (var i = 0; i < milestones.length; i++)
        Expanded(
          child: Column(children: [
            Row(children: [
              Expanded(child: Container(height: 2, color: i == 0 ? Colors.transparent : (milestones[i - 1].done ? Mkt.violet : Mkt.border))),
              _dot(milestones[i], milestones[i].key == current),
              Expanded(child: Container(height: 2, color: i == milestones.length - 1 ? Colors.transparent : (milestones[i].done ? Mkt.violet : Mkt.border))),
            ]),
            const SizedBox(height: 4),
            FittedBox(fit: BoxFit.scaleDown, child: Text(milestones[i].label, key: Key('milestone_${milestones[i].key}'), style: mktText(10.5, weight: milestones[i].done || milestones[i].key == current ? FontWeight.w800 : FontWeight.w500, color: milestones[i].done || milestones[i].key == current ? Mkt.ink : Mkt.inkSoft))),
            if (showDates && (milestones[i].date ?? '').isNotEmpty) Text(shootDay(milestones[i].date!, pattern: 'MMM d'), style: mktText(9.5, color: Mkt.inkSoft)),
          ]),
        ),
    ]);
  }

  Widget _dot(Milestone m, bool now) {
    if (m.done) return Container(width: 20, height: 20, decoration: const BoxDecoration(color: Mkt.violet, shape: BoxShape.circle), child: const Icon(Icons.check_rounded, size: 13, color: Colors.white));
    return Container(width: 20, height: 20, decoration: BoxDecoration(color: Mkt.card, shape: BoxShape.circle, border: Border.all(color: now ? Mkt.violet : Mkt.border, width: now ? 4 : 2)));
  }
}

/// A ring with the percentage inside ("40% Prepared").
class ProgressRing extends StatelessWidget {
  const ProgressRing({super.key, required this.pct, this.label = 'Prepared', this.size = 66});
  final int pct;
  final String label;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: Stack(alignment: Alignment.center, children: [
          SizedBox(width: size, height: size, child: CircularProgressIndicator(value: pct.clamp(0, 100) / 100, strokeWidth: 6, backgroundColor: Mkt.tint(Mkt.violet, 0.12), valueColor: const AlwaysStoppedAnimation(Mkt.violet))),
          Column(mainAxisSize: MainAxisSize.min, children: [Text('$pct%', key: const Key('shoot_progress_pct'), style: mktText(size * 0.24, weight: FontWeight.w800)), Text(label, style: mktText(size * 0.13, color: Mkt.inkSoft))]),
        ]),
      );
}

String hhmm(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
