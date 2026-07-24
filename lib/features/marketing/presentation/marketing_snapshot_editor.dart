import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/space_extension.dart';
import '../../../core/theme/crm_theme.dart';
import '../data/marketing_models.dart';
import '../services/marketing_service.dart';
import 'widgets/marketing_widgets.dart';

/// Weekly snapshot metrics. (key, label)
const marketingMetricFields = <(String, String)>[
  ('followers', 'Followers'),
  ('weeklyGrowthPct', 'Weekly growth %'),
  ('engagementRate', 'Engagement rate %'),
  ('adCampaigns', 'Ad campaigns'),
  ('offers', 'Offers'),
  ('newServicesCount', 'New services'),
  ('postingFrequency', 'Posts / week'),
  ('seoScore', 'SEO score'),
  ('reviews', 'Reviews'),
  ('collaborations', 'Collaborations'),
];

/// Scoring flags: (key, label, default points per SRS §4.2). Preview weights;
/// the backend applies the active versioned config.
const marketingFlagFields = <(String, String, int)>[
  ('newCampaign', 'New campaign', 5),
  ('viralContent', 'Viral content', 5),
  ('qualityCreative', 'Quality creative', 5),
  ('followerGrowth', 'Follower growth', 3),
  ('engagementIncrease', 'Engagement increase', 3),
  ('newService', 'New service', 2),
  ('newPartnership', 'New partnership', 2),
];

DateTime marketingThisMonday() {
  final d = DateTime.now();
  return DateTime(d.year, d.month, d.day)
      .subtract(Duration(days: (d.weekday + 6) % 7));
}

String _weekLabel(DateTime d) {
  const m = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  return '${d.day} ${m[d.month - 1]} ${d.year}';
}

String _metricValue(CompetitorSnapshot? s, String key) {
  if (s == null) return '';
  num v;
  switch (key) {
    case 'followers':
      v = s.followers;
      break;
    case 'weeklyGrowthPct':
      v = s.weeklyGrowthPct;
      break;
    case 'engagementRate':
      v = s.engagementRate;
      break;
    case 'adCampaigns':
      v = s.adCampaigns;
      break;
    case 'offers':
      v = s.offers;
      break;
    case 'newServicesCount':
      v = s.newServicesCount;
      break;
    case 'postingFrequency':
      v = s.postingFrequency;
      break;
    case 'seoScore':
      v = s.seoScore;
      break;
    case 'reviews':
      v = s.reviews;
      break;
    case 'collaborations':
      v = s.collaborations;
      break;
    default:
      return '';
  }
  if (v == 0) return '';
  return key == 'followers' ? v.toStringAsFixed(0) : '$v';
}

bool _flagValue(CompetitorSnapshot? s, String key) {
  if (s == null) return false;
  switch (key) {
    case 'newCampaign':
      return s.newCampaign;
    case 'viralContent':
      return s.viralContent;
    case 'qualityCreative':
      return s.qualityCreative;
    case 'followerGrowth':
      return s.followerGrowth;
    case 'engagementIncrease':
      return s.engagementIncrease;
    case 'newService':
      return s.newService;
    case 'newPartnership':
      return s.newPartnership;
    default:
      return false;
  }
}

/// The weekly manual scoring form for one competitor — metrics, growth signals
/// with per-signal evidence and a reel/post link, and a live 1–25 score.
///
/// Shared by the Competitors screen and the Weekly Score screen so there is a
/// single scoring form. Returns true when a snapshot was saved.
Future<bool> showSnapshotEditor(
  BuildContext context,
  WidgetRef ref,
  Competitor competitor,
) async {
  final crm = context.crmColors;
  final snap = competitor.latestSnapshot;

  final metricCtrls = {
    for (final f in marketingMetricFields)
      f.$1: TextEditingController(text: _metricValue(snap, f.$1)),
  };
  final flags = {
    for (final f in marketingFlagFields) f.$1: _flagValue(snap, f.$1),
  };
  final evidenceCtrls = {
    for (final f in marketingFlagFields)
      f.$1: TextEditingController(text: snap?.signalEvidence[f.$1] ?? ''),
  };
  final linkCtrls = {
    for (final f in marketingFlagFields)
      f.$1: TextEditingController(text: snap?.signalLinks[f.$1] ?? ''),
  };
  final themesCtrl = TextEditingController(text: snap?.contentThemes ?? '');
  var weekOf = marketingThisMonday();
  var saving = false;
  var saved = false;

  int liveScore() {
    var s = 0;
    for (final f in marketingFlagFields) {
      if (flags[f.$1] == true) s += f.$3;
    }
    return s > 25 ? 25 : (s < 1 ? 1 : s);
  }

  await showDialog<void>(
    context: context,
    builder: (dctx) => StatefulBuilder(builder: (dctx, setLocal) {
      Future<void> save() async {
        setLocal(() => saving = true);
        final messenger = ScaffoldMessenger.of(context);
        final data = <String, dynamic>{
          'weekOf': weekOf.toIso8601String(),
          'contentThemes': themesCtrl.text.trim(),
          for (final f in marketingMetricFields)
            f.$1: double.tryParse(metricCtrls[f.$1]!.text.trim()) ?? 0,
          for (final f in marketingFlagFields) f.$1: flags[f.$1],
          'signalEvidence': {
            for (final f in marketingFlagFields)
              f.$1: evidenceCtrls[f.$1]!.text.trim(),
          },
          'signalLinks': {
            for (final f in marketingFlagFields)
              f.$1: linkCtrls[f.$1]!.text.trim(),
          },
        };
        try {
          await ref
              .read(marketingServiceProvider)
              .upsertSnapshot(competitor.id, data);
          ref.invalidate(competitorsProvider);
          ref.invalidate(rankingsProvider);
          saved = true;
          if (dctx.mounted) Navigator.pop(dctx);
          messenger.showSnackBar(
              const SnackBar(content: Text('Weekly score saved')));
        } catch (e) {
          setLocal(() => saving = false);
          messenger.showSnackBar(SnackBar(content: Text('$e')));
        }
      }

      return AlertDialog(
        title: Row(children: [
          Expanded(child: Text('Weekly score · ${competitor.name}')),
          ScoreBadge(score: liveScore()),
        ]),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: dctx,
                      initialDate: weekOf,
                      firstDate: DateTime(2022),
                      lastDate: DateTime.now().add(const Duration(days: 7)),
                    );
                    if (picked != null) {
                      setLocal(() => weekOf =
                          DateTime(picked.year, picked.month, picked.day)
                              .subtract(
                                  Duration(days: (picked.weekday + 6) % 7)));
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                        labelText: 'Week of (Monday)',
                        isDense: true,
                        border: OutlineInputBorder()),
                    child: Text(_weekLabel(weekOf)),
                  ),
                ),
                14.h,
                Text('METRICS',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: crm.primary)),
                10.h,
                ...(marketingMetricFields.map((f) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TextField(
                        controller: metricCtrls[f.$1],
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                            labelText: f.$2,
                            isDense: true,
                            border: const OutlineInputBorder()),
                      ),
                    ))),
                TextField(
                  controller: themesCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Content themes',
                      isDense: true,
                      border: OutlineInputBorder()),
                ),
                16.h,
                Text('GROWTH SIGNALS (this week)',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: crm.primary)),
                6.h,
                ...(marketingFlagFields.map((f) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          value: flags[f.$1],
                          title: Text(f.$2),
                          secondary: Text('+${f.$3}',
                              style: TextStyle(
                                  color: crm.textSecondary,
                                  fontWeight: FontWeight.w700)),
                          onChanged: (v) =>
                              setLocal(() => flags[f.$1] = v ?? false),
                        ),
                        // Evidence per triggered signal (FR-2.2).
                        if (flags[f.$1] == true)
                          Padding(
                            padding: const EdgeInsets.only(left: 8, bottom: 8),
                            child: TextField(
                              controller: evidenceCtrls[f.$1],
                              style: const TextStyle(fontSize: 13),
                              decoration: InputDecoration(
                                  labelText: 'Evidence (why it scored)',
                                  isDense: true,
                                  border: const OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.notes,
                                      size: 16, color: crm.textSecondary)),
                            ),
                          ),
                        // The reel / post being scored — paste the link here.
                        if (flags[f.$1] == true)
                          Padding(
                            padding: const EdgeInsets.only(left: 8, bottom: 10),
                            child: TextField(
                              controller: linkCtrls[f.$1],
                              style: const TextStyle(fontSize: 13),
                              keyboardType: TextInputType.url,
                              decoration: InputDecoration(
                                  labelText: 'Paste reel / post link',
                                  hintText: 'https://instagram.com/reel/…',
                                  isDense: true,
                                  border: const OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.link,
                                      size: 16, color: crm.primary)),
                            ),
                          ),
                      ],
                    ))),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: saving ? null : () => Navigator.pop(dctx),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: saving ? null : save,
            child: saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Save score'),
          ),
        ],
      );
    }),
  );

  for (final c in metricCtrls.values) {
    c.dispose();
  }
  for (final c in evidenceCtrls.values) {
    c.dispose();
  }
  for (final c in linkCtrls.values) {
    c.dispose();
  }
  themesCtrl.dispose();
  return saved;
}
