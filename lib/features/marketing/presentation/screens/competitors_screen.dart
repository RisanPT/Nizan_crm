import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/extensions/space_extension.dart';
import 'package:nizan_crm/core/models/service_region.dart';
import 'package:nizan_crm/services/region_service.dart';
import '../../data/marketing_models.dart';
import '../../services/marketing_service.dart';
import '../kit/mkt_kit.dart';
import '../widgets/csv_upload.dart';
import '../widgets/marketing_widgets.dart';
import '../marketing_snapshot_editor.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/state/data_refresh.dart';

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
  // '' = all regions; otherwise a region id from our geographics. Empty-string
  // sentinel '__none__' isolates competitors with no region assigned.
  String _regionFilter = '';

  DateTime get _thisMonday {
    final d = DateTime.now();
    return DateTime(d.year, d.month, d.day)
        .subtract(Duration(days: (d.weekday + 6) % 7));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(competitorsProvider);
    // Preload our geographics regions for the filter + add/edit dropdown.
    final regions = ref.watch(regionsProvider).value ?? const <ServiceRegion>[];

    return MktPage(
      child: Material(
        type: MaterialType.transparency,
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => AppErrorView(error: e, onRetry: () => ref.invalidate(competitorsProvider)),
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
              // Region filter: '' = all, '__none__' = unassigned, else a region id.
              if (_regionFilter == '__none__') {
                if (c.regionId.isNotEmpty) return false;
              } else if (_regionFilter.isNotEmpty && c.regionId != _regionFilter) {
                return false;
              }
              if (_query.isEmpty) return true;
              final q = _query.toLowerCase();
              return c.name.toLowerCase().contains(q) ||
                  c.city.toLowerCase().contains(q) ||
                  c.region.toLowerCase().contains(q) ||
                  c.category.toLowerCase().contains(q);
            }).toList();

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              children: [
                _header(regions),
                const SizedBox(height: 14),
                MktKpiRow(
                  children: [
                    MktKpiCard(icon: Icons.groups_2_outlined, value: '${all.length}', label: 'Competitors', tint: Mkt.primary),
                    MktKpiCard(icon: Icons.event_available_outlined, value: '$tracked', label: 'Tracked this week', tint: Mkt.blue),
                    MktKpiCard(icon: Icons.speed_outlined, value: '$avg', label: 'Avg score', tint: marketingScoreColor(avg)),
                    MktKpiCard(icon: Icons.emoji_events_outlined, value: '$top', label: 'Top score', tint: marketingScoreColor(top)),
                  ],
                ),
                const SizedBox(height: 12),
                MktCard(
                  title: 'All competitors',
                  icon: Icons.radar_outlined,
                  subtitle: '${filtered.length} of ${all.length}',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _searchField(),
                      const SizedBox(height: 6),
                      if (filtered.isEmpty)
                        const MktEmpty('No competitors yet — add one or import a CSV', icon: Icons.groups_outlined, height: 140)
                      else
                        for (var i = 0; i < filtered.length; i++) _competitorRow(filtered[i], last: i == filtered.length - 1),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  bool _sameWeek(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _header(List<ServiceRegion> regions) => MktHeader(
        icon: Icons.radar_outlined,
        title: 'Competitors',
        subtitle: 'Track competitors and record weekly growth signals.',
        actions: [
          // Region filter — sourced from our geographics.
          MktDropdownPill<String>(
            value: _regionFilter,
            icon: Icons.public,
            options: [
              ('', 'All regions'),
              ('__none__', 'No region'),
              for (final r in regions) (r.id, r.name),
            ],
            onChanged: (v) => setState(() => _regionFilter = v),
          ),
          MktPill(label: 'Import CSV', icon: Icons.upload_file, trailing: false, onTap: _importCsv),
          MktPrimaryButton(label: 'Add competitor', onPressed: () => _editCompetitor(null)),
        ],
      );

  Widget _searchField() => SizedBox(
        height: 38,
        child: TextField(
          onChanged: (v) => setState(() => _query = v.trim()),
          style: mktText(13),
          decoration: InputDecoration(
            hintText: 'Search name, city, region',
            hintStyle: mktText(13, color: Mkt.inkSoft),
            prefixIcon: const Icon(Icons.search, size: 18, color: Mkt.inkSoft),
            isDense: true,
            filled: true,
            fillColor: Mkt.bg,
            contentPadding: const EdgeInsets.symmetric(vertical: 9),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: Mkt.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: Mkt.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: Mkt.primary)),
          ),
        ),
      );

  Widget _competitorRow(Competitor c, {required bool last}) {
    final snap = c.latestSnapshot;
    final socials = [
      if (c.instagram.isNotEmpty) 'IG',
      if (c.facebook.isNotEmpty) 'FB',
      if (c.youtube.isNotEmpty) 'YT',
      if (c.linkedin.isNotEmpty) 'IN',
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 12),
      decoration: BoxDecoration(
        border: last ? null : const Border(bottom: BorderSide(color: Mkt.border)),
      ),
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
                          style: mktText(14.5, weight: FontWeight.w800)),
                    ),
                    8.w,
                    ScoreBadge(score: c.score),
                  ],
                ),
                4.h,
                Text(
                  [
                    if (c.region.isNotEmpty) '📍 ${c.region}',
                    if (c.city.isNotEmpty) c.city,
                    if (c.category.isNotEmpty) c.category,
                    if (socials.isNotEmpty) socials,
                  ].join('  ·  '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: mktText(12, color: Mkt.inkSoft),
                ),
                if (snap != null) ...[
                  10.h,
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _pill('Followers', _compact(snap.followers)),
                      _pill('Growth', '${snap.weeklyGrowthPct.toStringAsFixed(1)}%'),
                      _pill('Engmt', '${snap.engagementRate.toStringAsFixed(1)}%'),
                      _pill('Ads', '${snap.adCampaigns}'),
                      _pill('Week', _weekLabel(snap.weekOf)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          8.w,
          Column(
            children: [
              _menu(c),
              MktPill(label: 'Weekly', icon: Icons.insights_outlined, trailing: false, onTap: () => _editSnapshot(c)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _menu(Competitor c) => PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, color: Mkt.inkSoft),
        onSelected: (v) {
          if (v == 'edit') _editCompetitor(c);
          if (v == 'delete') _deleteCompetitor(c);
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'edit', child: Text('Edit details')),
          PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      );

  Widget _pill(String k, String v) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: Mkt.bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Mkt.border),
        ),
        child: RichText(
          text: TextSpan(children: [
            TextSpan(text: '$k  ', style: mktText(10.5, weight: FontWeight.w600, color: Mkt.inkSoft)),
            TextSpan(text: v, style: mktText(12, weight: FontWeight.w800)),
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
    final regions = ref.read(regionsProvider).value ?? const <ServiceRegion>[];
    // Only offer a region that still exists in our geographics.
    var selectedRegionId =
        regions.any((r) => r.id == existing?.regionId) ? existing!.regionId : '';
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
          final regionName = selectedRegionId.isEmpty
              ? ''
              : regions
                  .firstWhere((r) => r.id == selectedRegionId,
                      orElse: () => const ServiceRegion(
                          id: '', name: '', status: '', stateId: '', stateName: ''))
                  .name;
          final model = Competitor(
            id: existing?.id ?? '',
            name: ctrls['name']!.text.trim(),
            city: ctrls['city']!.text.trim(),
            regionId: selectedRegionId,
            region: regionName,
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
            ref.refreshData.competitors();
            if (dctx.mounted) Navigator.pop(dctx);
            messenger.showSnackBar(
                SnackBar(content: Text(existing == null ? 'Added' : 'Updated')));
          } catch (e) {
            setLocal(() => saving = false);
            messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
          }
        }

        return AlertDialog(
          title: Text(existing == null ? 'Add competitor' : 'Edit competitor'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                f('name', 'Name *'),
                // Region from our geographics — the primary geo dimension.
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DropdownButtonFormField<String>(
                    initialValue: selectedRegionId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Region',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('— None —')),
                      for (final r in regions)
                        DropdownMenuItem(value: r.id, child: Text(r.name)),
                    ],
                    onChanged: (v) =>
                        setLocal(() => selectedRegionId = v ?? ''),
                  ),
                ),
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
                  backgroundColor: Mkt.bad),
              onPressed: () => Navigator.pop(dctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(marketingServiceProvider).deleteCompetitor(c.id);
      ref.refreshData.competitors();
      messenger.showSnackBar(const SnackBar(content: Text('Deleted')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
    }
  }

  // ── CSV import ──────────────────────────────────────────────────────────
  Future<void> _importCsv() async {
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
            ref.refreshData.competitors();
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
              summary = 'Import failed: ${friendlyErrorMessage(e)}';
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
                  'First row = headers. Recognised columns: name, city, region, '
                  'website, category, instagram, facebook, youtube, linkedin, followers, '
                  'weeklyGrowthPct, engagementRate, adCampaigns, offers, '
                  'postingFrequency, seoScore, reviews, collaborations, '
                  'contentThemes, and yes/no flags: newCampaign, viralContent, '
                  'qualityCreative, followerGrowth, engagementIncrease, '
                  'newService, newPartnership. "name" is required.',
                  style: mktText(12, color: Mkt.inkSoft),
                ),
                12.h,
                Row(children: [
                  OutlinedButton.icon(
                    onPressed: busy
                        ? null
                        : () async {
                            String? text;
                            try {
                              text = await pickCsvFileText();
                            } catch (_) {
                              // Picker unavailable on this platform: the
                              // paste box below still works.
                              setLocal(() => summary = "Couldn't open the file picker. Paste the CSV below instead.");
                              return;
                            }
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
                      style: mktText(12, color: Mkt.inkSoft)),
                ]),
                12.h,
                TextField(
                  controller: textCtrl,
                  maxLines: 8,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  decoration: InputDecoration(
                    hintText:
                        'name,city,region,followers,newCampaign\nGlow Studio,Kochi,Ernakulam,12000,yes',
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
                              ? Mkt.good
                              : Mkt.bad,
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
    'region': 'region', 'zone': 'region',
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
