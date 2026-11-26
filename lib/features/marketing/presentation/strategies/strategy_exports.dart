import 'package:intl/intl.dart';

import 'package:nizan_crm/features/marketing/data/strategy_models.dart';

// The rows of every CSV the Strategies & Developments screens export (pure, so they can be checked): the first row is the heading.

List<List<Object?>> workCsv(List<WorkItem> items, {required bool project}) => [
      [project ? 'Project' : 'Initiative', project ? 'Category' : 'Focus area', if (!project) 'Impact', 'Brand', 'Owner', 'Progress %', 'Progress from', 'Status', 'Start', 'Due', if (!project) 'Hours logged'],
      for (final i in items)
        [
          i.title,
          project ? i.category : i.focusArea,
          if (!project) impactLabel(i.impact),
          i.brand,
          i.ownerName,
          i.hasProgress ? i.progress : '', // no progress is blank, never 0
          i.progressNote,
          workStatusLabel(i.status),
          i.start,
          i.due ?? '',
          if (!project) (i.minutes / 60).toStringAsFixed(1),
        ],
    ];

List<List<Object?>> plansCsv(List<PlanItem> plans) => [
      ['Plan', 'Focus area', 'Year', 'Brand', 'Status', 'Owner', 'Initiatives', 'Projects', 'Goals'],
      for (final p in plans) [p.title, p.focusArea, p.year, p.brand, planStatusLabel(p.status), p.ownerName, p.initiativeCount, p.projectCount, p.goals.join(' | ')],
    ];

List<List<Object?>> roadmapCsv(RoadmapData d) => [
      ['Type', 'Quarter', 'Theme', 'Title', 'Done', 'Done by', 'Done on', 'Start', 'End', 'Progress %', 'Status', 'Owner'],
      for (final q in d.quarters)
        for (final it in q.items) ['Milestone', 'Q${it.quarter}', it.theme.isEmpty ? q.theme : it.theme, it.title, it.done ? 'Yes' : 'No', it.doneBy, it.doneAt == null ? '' : DateFormat('yyyy-MM-dd').format(it.doneAt!), '', '', '', '', ''],
      for (final b in [...d.bars, ...d.undated]) [b.kind == 'project' ? 'Project' : 'Initiative', '', '', b.title, '', '', '', b.start, b.end ?? '', b.progressSource == 'none' ? '' : b.progress, workStatusLabel(b.status), b.owner],
    ];

List<List<Object?>> findingsCsv(List<Finding> items) => [
      ['Finding', 'Kind', 'Date', 'Brand', 'Added by', 'Link', 'Tags', 'Summary'],
      for (final f in items) [f.title, findingKindLabel(f.kind), f.date, f.brand, f.author, f.link, f.tags.join(' '), f.summary],
    ];

List<List<Object?>> actionItemsCsv(StrategyReview r) => [
      ['Review', 'Action item', 'Owner', 'Priority', 'Target date', 'Status'],
      for (final a in r.actionItems) ['${r.periodLabel} (${reviewTypeLabel(r.type)})', a.text, a.ownerName, actionPriorityLabel(a.priority), a.targetDate ?? '', actionStatusLabel(a.status)],
    ];

/// The Overview as a CSV: the KPI strip, the focus areas, the key initiatives and projects, the performance by focus area, the strategy work
/// logged, the latest review's outcomes. A figure nobody can know is blank, never 0.
List<List<Object?>> overviewCsv(StrategyOverview o) => [
      ['Section', 'Item', 'Value', 'Detail'],
      ['KPI', 'Active strategies', o.kpis.activeStrategies, ''],
      ['KPI', 'Development projects', o.kpis.developmentProjects, ''],
      ['KPI', 'Total initiatives', o.kpis.totalInitiatives, ''],
      ['KPI', 'On track', o.kpis.onTrack, ''],
      ['KPI', 'At risk', o.kpis.atRisk, ''],
      ['KPI', 'New this week', o.kpis.newThisWeek, ''],
      for (final f in o.focus) ['Focus area', f.focusArea, f.count, ''],
      for (final w in [...o.initiatives, ...o.projects]) [w.isProject ? 'Project' : 'Initiative', w.title, w.hasProgress ? '${w.progress}%' : '', '${workStatusLabel(w.status)} · ${w.progressNote}${w.due == null ? '' : ' · due ${w.due}'}'],
      for (final p in o.performance) ['Performance', p.focusArea, p.progress == null ? '' : '${p.progress}%', '${p.measured} of ${p.initiatives} initiatives measured'],
      if (o.strategyWork.tracked)
        for (final t in o.strategyWork.types.isEmpty ? o.strategyWork.counts.map((c) => c.metric).toList() : o.strategyWork.types) ['Strategy work logged', t, o.strategyWork.of(t), ''],
      if (o.keyOutcomes != null)
        for (final out in o.keyOutcomes!.outcomes) ['Latest review: ${o.keyOutcomes!.periodLabel}', out.text, out.state, ''],
    ];

