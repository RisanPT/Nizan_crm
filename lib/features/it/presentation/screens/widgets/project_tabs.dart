import 'package:flutter/material.dart';

/// The tabs of a project's screen, in the order they are shown. Overview comes first: it is where a
/// project opens, and where its status, departments and next steps are read at a glance.
enum ProjectTab {
  overview('Overview', Icons.home_outlined),
  spreadsheet('Spreadsheet', Icons.table_chart_outlined),
  timeline('Timeline', Icons.timeline_outlined),
  wbs('WBS', Icons.account_tree_outlined),
  board('Board', Icons.view_kanban_outlined),
  okr("OKR's & KR's", Icons.track_changes_outlined),
  docs('Docs', Icons.description_outlined);

  const ProjectTab(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// The tab a link asks for (`?tab=okr`, `?tab=docs`, or a position), Overview when it asks for nothing
/// or something that is not a tab.
int projectTabIndex(String? tab) {
  final t = (tab ?? '').trim().toLowerCase();
  final named = switch (t) {
    'overview' => ProjectTab.overview,
    'spreadsheet' || 'sheet' => ProjectTab.spreadsheet,
    'timeline' || 'gantt' => ProjectTab.timeline,
    'wbs' => ProjectTab.wbs,
    'board' || 'kanban' => ProjectTab.board,
    'okr' || 'okrs' => ProjectTab.okr,
    'docs' || 'srs' => ProjectTab.docs,
    _ => null,
  };
  if (named != null) return named.index;
  final n = int.tryParse(t);
  return n != null && n >= 0 && n < ProjectTab.values.length ? n : ProjectTab.overview.index;
}
