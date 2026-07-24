import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/extensions/space_extension.dart';
import '../../../../core/theme/crm_theme.dart';
import '../../../../core/utils/responsive_builder.dart';
import '../../../../presentation/screens/inventory/inventory_widgets.dart';
import '../../data/marketing_models.dart';
import '../../services/marketing_service.dart';
import '../widgets/csv_upload.dart';
import '../widgets/marketing_widgets.dart';
import '../marketing_snapshot_editor.dart';

/// Marketing → Competitor master database. Track competitors, enter weekly data
/// manually, or bulk-import from CSV. Scores are computed server-side.
class CompetitorsScreen extends ConsumerStatefulWidget {
  const CompetitorsScreen({super.key});

  @override
  ConsumerState<CompetitorsScreen> createState() => _CompetitorsScreenState();
}

// Numeric snapshot fields: (key, label).
class _CompetitorsScreenState extends ConsumerState<CompetitorsScreen> {
  String _query = '';

  DateTime get _thisMonday {
    final d = DateTime.now();
    return DateTime(d.year, d.month, d.day)
        .subtract(Duration(days: (d.weekday + 6) % 7));
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);
    final async = ref.watch(competitorsProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Failed to load competitors:\n$e',
              textAlign: TextAlign.center,
              style: TextStyle(color: crm.textSecondary)),
        ),
      ),
      data: (all) {
        final monday = _thisMonday;
        final tracked = all
            .where((c) =>
                c.latestSnapshot != null &&
                _sameWeek(c.latestSnapshot!.weekOf, monday))
            .length;
        final scored = all.where((c) => c.score > 0).toList();
        final avg = scored.isEmpty
            ? 0
            : (scored.fold<int>(0, (s, c) => s + c.score) / scored.length)
                .round();
        final top = all.isEmpty
            ? 0
            : all.map((c) => c.score).fold<int>(0, (a, b) => a > b ? a : b);

        final filtered = all.where((c) {
          if (_query.isEmpty) return true;
          final q = _query.toLowerCase();
          return c.name.toLowerCase().contains(q) ||
              c.city.toLowerCase().contains(q) ||
              c.category.toLowerCase().contains(q);
        }).toList();

        return ListView(
          padding: EdgeInsets.fromLTRB(
              isMobile ? 16 : 24, 16, isMobile ? 16 : 24, 28),
          children: [
            _header(crm, isMobile),
            16.h,
            InvStatGrid(
              isMobile: isMobile,
              stats: [
                InvStat('${all.length}', 'Competitors',
                    Icons.groups_2_outlined, crm.primary),
                InvStat('$tracked', 'Tracked this week',
                    Icons.event_available_outlined, crm.accent),
                InvStat('$avg', 'Avg score', Icons.speed_outlined,
                    marketingScoreColor(avg)),
                InvStat('$top', 'Top score', Icons.emoji_events_outlined,
                    marketingScoreColor(top)),
              ],
            ),
            18.h,
            _toolbar(crm, isMobile),
            14.h,
            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: Column(children: [
                    Icon(Icons.groups_outlined,
                        size: 42, color: crm.textSecondary),
                    10.h,
                    Text('No competitors yet — add one or import a CSV',
                        style: TextStyle(color: crm.textSecondary)),
                  ]),
                ),
              )
            else
              ...filtered.map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _competitorCard(crm, c),
                  )),
          ],
        );
      },
    );
  }

  bool _sameWeek(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _header(CrmTheme crm, bool isMobile) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Competitor Master Database',
              style: TextStyle(
                  fontSize: isMobile ? 21 : 27,
                  fontWeight: FontWeight.w800,
                  color: crm.textPrimary)),
          4.h,
          Text('Track competitors and record weekly growth signals.',
              style: TextStyle(fontSize: 13, color: crm.textSecondary)),
        ],
      );

  Widget _toolbar(CrmTheme crm, bool isMobile) => Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: isMobile ? double.infinity : 280,
            child: TextField(
              onChanged: (v) => setState(() => _query = v.trim()),
              decoration: InputDecoration(
                hintText: 'Search name, city, category',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          FilledButton.icon(
            onPressed: () => _editCompetitor(null),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add competitor'),
          ),
          OutlinedButton.icon(
            onPressed: _importCsv,
            icon: const Icon(Icons.upload_file, size: 18),
            label: const Text('Import CSV'),
          ),
        ],
      );

  Widget _competitorCard(CrmTheme crm, Competitor c) {
    final snap = c.latestSnapshot;
    final socials = [
      if (c.instagram.isNotEmpty) 'IG',
      if (c.facebook.isNotEmpty) 'FB',
      if (c.youtube.isNotEmpty) 'YT',
      if (c.linkedin.isNotEmpty) 'IN',
    ].join(' · ');
    return Container(
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: crm.border),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(c.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              color: crm.textPrimary)),
                    ),
                    8.w,
                    ScoreBadge(score: c.score),
                  ],
                ),
                4.h,
                Text(
                  [
                    if (c.city.isNotEmpty) c.city,
                    if (c.category.isNotEmpty) c.category,
                    if (socials.isNotEmpty) socials,
                  ].join('  ·  '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: crm.textSecondary),
                ),
                if (snap != null) ...[
                  10.h,
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _pill(crm, 'Followers', _compact(snap.followers)),
                      _pill(crm, 'Growth',
                          '${snap.weeklyGrowthPct.toStringAsFixed(1)}%'),
                      _pill(crm, 'Engmt',
                          '${snap.engagementRate.toStringAsFixed(1)}%'),
                      _pill(crm, 'Ads', '${snap.adCampaigns}'),
                      _pill(crm, 'Week', _weekLabel(snap.weekOf)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Column(
            children: [
              _menu(c),
              FilledButton.tonalIcon(
                onPressed: () => _editSnapshot(c),
                icon: const Icon(Icons.insights_outlined, size: 16),
                label: const Text('Weekly'),
                style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _menu(Competitor c) => PopupMenuButton<String>(
        icon: Icon(Icons.more_vert, color: context.crmColors.textSecondary),
        onSelected: (v) {
          if (v == 'edit') _editCompetitor(c);
          if (v == 'delete') _deleteCompetitor(c);
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'edit', child: Text('Edit details')),
          PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      );

  Widget _pill(CrmTheme crm, String k, String v) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: crm.input,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: crm.border),
        ),
        child: RichText(
          text: TextSpan(children: [
            TextSpan(
                text: '$k  ',
                style: TextStyle(
                    color: crm.textSecondary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600)),
            TextSpan(
                text: v,
                style: TextStyle(
                    color: crm.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800)),
          ]),
        ),
      );

  // ── Add / edit competitor ──────────────────────────────────────────────
  Future<void> _editCompetitor(Competitor? existing) async {
    final ctrls = {
      for (final k in [
        'name', 'city', 'website', 'category',
        'instagram', 'facebook', 'youtube', 'linkedin', 'notes'
      ])
        k: TextEditingController(text: _fieldOf(existing, k)),
    };
    var saving = false;

    await showDialog<void>(
      context: context,
      builder: (dctx) => StatefulBuilder(builder: (dctx, setLocal) {
        Widget f(String key, String label, {int max = 1}) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextField(
                controller: ctrls[key],
                maxLines: max,
                decoration: InputDecoration(
                    labelText: label,
                    isDense: true,
                    border: const OutlineInputBorder()),
              ),
            );
        Future<void> save() async {
          if (ctrls['name']!.text.trim().isEmpty) return;
          setLocal(() => saving = true);
          final messenger = ScaffoldMessenger.of(context);
          final svc = ref.read(marketingServiceProvider);
          final model = Competitor(
            id: existing?.id ?? '',
            name: ctrls['name']!.text.trim(),
            city: ctrls['city']!.text.trim(),
            website: ctrls['website']!.text.trim(),
            category: ctrls['category']!.text.trim(),
            instagram: ctrls['instagram']!.text.trim(),
            facebook: ctrls['facebook']!.text.trim(),
            youtube: ctrls['youtube']!.text.trim(),
            linkedin: ctrls['linkedin']!.text.trim(),
            notes: ctrls['notes']!.text.trim(),
          );
          try {
            if (existing == null) {
              await svc.createCompetitor(model);
            } else {
              await svc.updateCompetitor(existing.id, model);
            }
            ref.invalidate(competitorsProvider);
            if (dctx.mounted) Navigator.pop(dctx);
            messenger.showSnackBar(
                SnackBar(content: Text(existing == null ? 'Added' : 'Updated')));
          } catch (e) {
            setLocal(() => saving = false);
            messenger.showSnackBar(SnackBar(content: Text('$e')));
          }
        }

        return AlertDialog(
          title: Text(existing == null ? 'Add competitor' : 'Edit competitor'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                f('name', 'Name *'),
                Row(children: [
                  Expanded(child: f('city', 'City')),
                  10.w,
                  Expanded(child: f('category', 'Category')),
                ]),
                f('website', 'Website'),
                Row(children: [
                  Expanded(child: f('instagram', 'Instagram')),
                  10.w,
                  Expanded(child: f('facebook', 'Facebook')),
                ]),
                Row(children: [
                  Expanded(child: f('youtube', 'YouTube')),
                  10.w,
                  Expanded(child: f('linkedin', 'LinkedIn')),
                ]),
                f('notes', 'Notes', max: 2),
              ]),
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
                  : Text(existing == null ? 'Add' : 'Save'),
            ),
          ],
        );
      }),
    );
    for (final c in ctrls.values) {
      c.dispose();
    }
  }

  String _fieldOf(Competitor? c, String k) {
    if (c == null) return '';
    switch (k) {
      case 'name':
        return c.name;
      case 'city':
        return c.city;
      case 'website':
        return c.website;
      case 'category':
        return c.category;
      case 'instagram':
        return c.instagram;
      case 'facebook':
        return c.facebook;
      case 'youtube':
        return c.youtube;
      case 'linkedin':
        return c.linkedin;
      case 'notes':
        return c.notes;
      default:
        return '';
    }
  }

  // ── Weekly snapshot (manual data entry) ─────────────────────────────────
  // The weekly scoring form now lives in one place (marketing_snapshot_editor)
  // so the Competitors and Weekly Score screens stay in sync.
  Future<void> _editSnapshot(Competitor c) async {
    await showSnapshotEditor(context, ref, c);
  }

  Future<void> _deleteCompetitor(Competitor c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('Delete competitor'),
        content: Text(
            'Delete "${c.name}" and all its weekly data? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dctx, false),
              child: const Text('Cancel')),
          FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: context.crmColors.destructive),
              onPressed: () => Navigator.pop(dctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(marketingServiceProvider).deleteCompetitor(c.id);
      ref.invalidate(competitorsProvider);
      messenger.showSnackBar(const SnackBar(content: Text('Deleted')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  // ── CSV import ──────────────────────────────────────────────────────────
  Future<void> _importCsv() async {
    final crm = context.crmColors;
    final textCtrl = TextEditingController();
    var busy = false;
    String? summary;

    await showDialog<void>(
      context: context,
      builder: (dctx) => StatefulBuilder(builder: (dctx, setLocal) {
        Future<void> runImport() async {
          final raw = textCtrl.text.trim();
          if (raw.isEmpty) return;
          setLocal(() => busy = true);
          try {
            final rows = _parseCsv(raw);
            if (rows.isEmpty) {
              setLocal(() {
                busy = false;
                summary = 'No data rows found. Check the header row.';
              });
              return;
            }
            final res = await ref
                .read(marketingServiceProvider)
                .importRows(rows, weekOf: _thisMonday);
            ref.invalidate(competitorsProvider);
            final errs = (res['errors'] as List?)?.length ?? 0;
            setLocal(() {
              busy = false;
              summary =
                  '✓ ${res['created']} added · ${res['updated']} updated · '
                  '${res['snapshots']} weekly rows${errs > 0 ? ' · $errs skipped' : ''}';
            });
          } catch (e) {
            setLocal(() {
              busy = false;
              summary = 'Import failed: $e';
            });
          }
        }

        return AlertDialog(
          title: const Text('Import competitors from CSV'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'First row = headers. Recognised columns: name, city, website, '
                  'category, instagram, facebook, youtube, linkedin, followers, '
                  'weeklyGrowthPct, engagementRate, adCampaigns, offers, '
                  'postingFrequency, seoScore, reviews, collaborations, '
                  'contentThemes, and yes/no flags: newCampaign, viralContent, '
                  'qualityCreative, followerGrowth, engagementIncrease, '
                  'newService, newPartnership. "name" is required.',
                  style: TextStyle(fontSize: 12, color: crm.textSecondary),
                ),
                12.h,
                Row(children: [
                  OutlinedButton.icon(
                    onPressed: busy
                        ? null
                        : () async {
                            final text = await pickCsvFileText();
                            if (text != null) {
                              textCtrl.text = text;
                              setLocal(() => summary = null);
                            }
                          },
                    icon: const Icon(Icons.folder_open, size: 18),
                    label: const Text('Choose file'),
                  ),
                  10.w,
                  Text('or paste below',
                      style: TextStyle(color: crm.textSecondary, fontSize: 12)),
                ]),
                12.h,
                TextField(
                  controller: textCtrl,
                  maxLines: 8,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  decoration: InputDecoration(
                    hintText:
                        'name,city,followers,newCampaign\nGlow Studio,Kochi,12000,yes',
                    isDense: true,
                    border:
                        OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                if (summary != null) ...[
                  12.h,
                  Text(summary!,
                      style: TextStyle(
                          color: summary!.startsWith('✓')
                              ? crm.success
                              : crm.destructive,
                          fontWeight: FontWeight.w600)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dctx),
                child: const Text('Close')),
            FilledButton.icon(
              onPressed: busy ? null : runImport,
              icon: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.upload, size: 18),
              label: const Text('Import'),
            ),
          ],
        );
      }),
    );
    textCtrl.dispose();
  }

  // Parse CSV text → list of {canonicalKey: value} maps keyed by header.
  List<Map<String, dynamic>> _parseCsv(String raw) {
    final table = const CsvDecoder(dynamicTyping: false, skipEmptyLines: true)
        .convert(raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n'));
    if (table.isEmpty) return [];
    final headers = table.first
        .map((h) => _canonicalHeader(h.toString()))
        .toList();
    final rows = <Map<String, dynamic>>[];
    for (var r = 1; r < table.length; r++) {
      final cells = table[r];
      if (cells.every((c) => c.toString().trim().isEmpty)) continue;
      final map = <String, dynamic>{};
      for (var i = 0; i < headers.length && i < cells.length; i++) {
        if (headers[i].isEmpty) continue;
        map[headers[i]] = cells[i].toString().trim();
      }
      if ((map['name'] ?? '').toString().isNotEmpty) rows.add(map);
    }
    return rows;
  }

  static const _headerAliases = <String, String>{
    'name': 'name', 'competitor': 'name', 'brand': 'name',
    'city': 'city', 'location': 'city',
    'website': 'website', 'site': 'website',
    'category': 'category', 'type': 'category',
    'instagram': 'instagram', 'ig': 'instagram',
    'facebook': 'facebook', 'fb': 'facebook',
    'youtube': 'youtube', 'yt': 'youtube',
    'linkedin': 'linkedin', 'in': 'linkedin',
    'followers': 'followers',
    'weeklygrowthpct': 'weeklyGrowthPct', 'growth': 'weeklyGrowthPct',
    'growthpct': 'weeklyGrowthPct', 'weeklygrowth': 'weeklyGrowthPct',
    'engagementrate': 'engagementRate', 'engagement': 'engagementRate',
    'adcampaigns': 'adCampaigns', 'ads': 'adCampaigns', 'campaigns': 'adCampaigns',
    'offers': 'offers',
    'newservicescount': 'newServicesCount', 'newservices': 'newServicesCount',
    'postingfrequency': 'postingFrequency', 'posts': 'postingFrequency',
    'seoscore': 'seoScore', 'seo': 'seoScore',
    'reviews': 'reviews',
    'collaborations': 'collaborations', 'collabs': 'collaborations',
    'contentthemes': 'contentThemes', 'themes': 'contentThemes',
    'newcampaign': 'newCampaign',
    'viralcontent': 'viralContent',
    'qualitycreative': 'qualityCreative',
    'followergrowth': 'followerGrowth',
    'engagementincrease': 'engagementIncrease',
    'newservice': 'newService',
    'newpartnership': 'newPartnership',
    'weekof': 'weekOf', 'week': 'weekOf',
    'notes': 'notes',
  };

  String _canonicalHeader(String h) {
    final norm = h.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return _headerAliases[norm] ?? '';
  }

  static String _weekLabel(DateTime d) {
    const m = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${m[d.month - 1]} ${d.year}';
  }

  static String _compact(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(0);
  }
}
