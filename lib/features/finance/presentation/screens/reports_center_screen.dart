import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/extensions/space_extension.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/finance/data/report_catalog.dart';
import 'package:nizan_crm/features/finance/controllers/reports_meta_provider.dart';

String _visited(DateTime? d) => d == null ? '—' : DateFormat('dd/MM/yyyy hh:mm a').format(d);

/// Finance → Reports. A Zoho-style Reports Center: a left rail of categories
/// (plus Favorites), a searchable catalog of every finance report, and a tap to
/// open the report. Starred reports and last-visited times persist per user.
class ReportsCenterScreen extends ConsumerStatefulWidget {
  const ReportsCenterScreen({super.key});

  @override
  ConsumerState<ReportsCenterScreen> createState() => _ReportsCenterScreenState();
}

class _ReportsCenterScreenState extends ConsumerState<ReportsCenterScreen> {
  static const _all = '__all__';
  static const _favorites = '__favorites__';

  String _selected = _all;
  final _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<FinanceReport> _visibleReports(ReportsMeta meta) {
    final q = _search.trim().toLowerCase();
    return kFinanceReports.where((r) {
      if (_selected == _favorites && !meta.isFavorite(r.key)) return false;
      if (_selected != _all && _selected != _favorites && r.category != _selected) return false;
      if (q.isNotEmpty) {
        final hay = '${r.name} ${r.category} ${r.description}'.toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  String get _headerLabel {
    if (_selected == _all) return 'All Reports';
    if (_selected == _favorites) return 'Favorites';
    return _selected;
  }

  // Show the Category column only in mixed views (All / Favorites); a single
  // category makes it redundant — same as Zoho.
  bool get _showCategory => _selected == _all || _selected == _favorites;

  void _open(FinanceReport r) {
    ref.read(reportsMetaProvider.notifier).recordVisit(r.key);
    context.push(r.route);
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final meta = ref.watch(reportsMetaProvider);

    return Scaffold(
      backgroundColor: crm.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 820;
          return Column(children: [
            _topBar(crm, wide),
            Expanded(
              child: wide
                  ? Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      SizedBox(width: 240, child: _rail(crm, meta)),
                      Container(width: 1, color: crm.border.withValues(alpha: 0.6)),
                      Expanded(child: _list(crm, meta, wide)),
                    ])
                  : Column(children: [
                      _chips(crm, meta),
                      Expanded(child: _list(crm, meta, wide)),
                    ]),
            ),
          ]);
        },
      ),
    );
  }

  Widget _topBar(CrmTheme crm, bool wide) {
    final search = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: wide ? 420 : double.infinity),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _search = v),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Search reports',
          prefixIcon: const Icon(Icons.search, size: 18),
          suffixIcon: _search.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _search = '');
                  },
                ),
          filled: true,
          fillColor: crm.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: crm.surface,
        border: Border(bottom: BorderSide(color: crm.border.withValues(alpha: 0.6))),
      ),
      child: wide
          ? Row(children: [
              Text('Reports Center',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: crm.textPrimary)),
              const Spacer(),
              Flexible(child: search),
            ])
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Reports Center',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: crm.textPrimary)),
              10.h,
              search,
            ]),
    );
  }

  // ── Wide: left rail ──
  Widget _rail(CrmTheme crm, ReportsMeta meta) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      children: [
        _railItem(crm, 'All Reports', Icons.grid_view_outlined, _all, kFinanceReports.length),
        _railItem(crm, 'Favorites', Icons.star_border_rounded, _favorites, meta.favorites.length),
        14.h,
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Text('REPORT CATEGORY',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: crm.textSecondary)),
        ),
        for (final cat in kReportCategories)
          _railItem(crm, cat, Icons.folder_outlined, cat,
              kFinanceReports.where((r) => r.category == cat).length),
      ],
    );
  }

  Widget _railItem(CrmTheme crm, String label, IconData icon, String value, int count) {
    final on = _selected == value;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: on ? crm.primary.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() => _selected = value),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              Icon(icon, size: 18, color: on ? crm.primary : crm.textSecondary),
              10.w,
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: on ? FontWeight.w800 : FontWeight.w600,
                        color: on ? crm.primary : crm.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              if (count > 0)
                Text('$count', style: TextStyle(fontSize: 12, color: crm.textSecondary)),
            ]),
          ),
        ),
      ),
    );
  }

  // ── Narrow: category chips ──
  Widget _chips(CrmTheme crm, ReportsMeta meta) {
    Widget chip(String label, String value) {
      final on = _selected == value;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: on,
          onSelected: (_) => setState(() => _selected = value),
        ),
      );
    }

    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          chip('All', _all),
          chip('★ Favorites', _favorites),
          for (final cat in kReportCategories) chip(cat, cat),
        ],
      ),
    );
  }

  // ── The report list ──
  Widget _list(CrmTheme crm, ReportsMeta meta, bool wide) {
    final reports = _visibleReports(meta);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        Row(children: [
          Text(_headerLabel,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: crm.textPrimary)),
          8.w,
          Text('${reports.length}', style: TextStyle(fontSize: 13, color: crm.textSecondary)),
        ]),
        12.h,
        if (reports.isEmpty)
          _empty(crm)
        else ...[
          if (wide) _tableHeader(crm),
          for (final r in reports) _reportRow(crm, meta, r, wide),
        ],
      ],
    );
  }

  Widget _tableHeader(CrmTheme crm) => Padding(
        padding: const EdgeInsets.fromLTRB(44, 4, 12, 8),
        child: Row(children: [
          Expanded(flex: 4, child: Text('REPORT NAME', style: _hdr(crm))),
          if (_showCategory) Expanded(flex: 3, child: Text('CATEGORY', style: _hdr(crm))),
          Expanded(flex: 2, child: Text('CREATED BY', style: _hdr(crm))),
          Expanded(flex: 3, child: Text('LAST VISITED', style: _hdr(crm))),
        ]),
      );

  Widget _reportRow(CrmTheme crm, ReportsMeta meta, FinanceReport r, bool wide) {
    final fav = meta.isFavorite(r.key);
    final star = IconButton(
      visualDensity: VisualDensity.compact,
      tooltip: fav ? 'Remove from favorites' : 'Add to favorites',
      onPressed: () => ref.read(reportsMetaProvider.notifier).toggleFavorite(r.key),
      icon: Icon(fav ? Icons.star_rounded : Icons.star_border_rounded,
          size: 20, color: fav ? const Color(0xFFF59E0B) : crm.textSecondary),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: crm.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _open(r),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: wide
                ? Row(children: [
                    star,
                    Expanded(
                      flex: 4,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(r.name,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: crm.primary)),
                        2.h,
                        Text(r.description,
                            style: TextStyle(fontSize: 11.5, color: crm.textSecondary),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ]),
                    ),
                    if (_showCategory)
                      Expanded(flex: 3, child: Text(r.category, style: TextStyle(fontSize: 13, color: crm.textPrimary))),
                    Expanded(flex: 2, child: Text('System Generated', style: TextStyle(fontSize: 12.5, color: crm.textSecondary))),
                    Expanded(
                        flex: 3,
                        child: Text(_visited(meta.visitedAt(r.key)),
                            style: TextStyle(fontSize: 12.5, color: crm.textSecondary))),
                  ])
                : Row(children: [
                    star,
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: crm.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(9)),
                      child: Icon(r.icon, size: 18, color: crm.primary),
                    ),
                    10.w,
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(r.name,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: crm.textPrimary),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        2.h,
                        Text('${r.category} · ${_visited(meta.visitedAt(r.key))}',
                            style: TextStyle(fontSize: 11.5, color: crm.textSecondary),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ]),
                    ),
                    Icon(Icons.chevron_right, size: 18, color: crm.textSecondary),
                  ]),
          ),
        ),
      ),
    );
  }

  Widget _empty(CrmTheme crm) => Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Center(
          child: Column(children: [
            Icon(_selected == _favorites ? Icons.star_border_rounded : Icons.search_off,
                size: 52, color: crm.border),
            12.h,
            Text(
                _selected == _favorites
                    ? 'No favorites yet'
                    : 'No reports match your search',
                style: TextStyle(fontWeight: FontWeight.w700, color: crm.textPrimary)),
            6.h,
            Text(
                _selected == _favorites
                    ? 'Tap the ☆ on any report to pin it here.'
                    : 'Try a different search or category.',
                style: TextStyle(fontSize: 12.5, color: crm.textSecondary)),
          ]),
        ),
      );

  TextStyle _hdr(CrmTheme crm) =>
      TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.4, color: crm.textSecondary);
}
