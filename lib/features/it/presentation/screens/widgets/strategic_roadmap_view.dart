import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/auth/access_control.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/features/it/domain/models/strategic_vision_model.dart';
import 'package:nizan_crm/features/it/services/strategic_vision_service.dart';
import 'package:nizan_crm/features/it/services/it_service.dart';
import 'package:nizan_crm/features/it/data/project.dart';
import 'package:nizan_crm/features/it/domain/project_tier.dart';

enum _RoadmapViewMode { waves, timeline }

Color _horizonColor(int n) {
  switch (n) {
    case 1:
      return const Color(0xFF3B82F6); // Royal Blue
    case 2:
      return const Color(0xFF8B5CF6); // Violet / Purple
    case 3:
      return const Color(0xFFF43F5E); // Rose / Crimson
    case 4:
      return const Color(0xFF10B981); // Emerald Green
    case 5:
      return const Color(0xFFF59E0B); // Amber / Gold
    default:
      return const Color(0xFF06B6D4); // Cyan
  }
}

class StrategicRoadmapView extends ConsumerStatefulWidget {
  const StrategicRoadmapView({super.key});

  @override
  ConsumerState<StrategicRoadmapView> createState() => _StrategicRoadmapViewState();
}

class _StrategicRoadmapViewState extends ConsumerState<StrategicRoadmapView> {
  String _selectedPillarId = 'all';
  _RoadmapViewMode _viewMode = _RoadmapViewMode.waves;

  // Masterplan Configuration Dialog (Supports 5-year, 10-year, 15-year, 20-year, or custom spans)
  void _showMasterplanConfigDialog(BuildContext context, StrategicVisionModel vision) {
    final titleCtrl = TextEditingController(text: vision.title);
    final statementCtrl = TextEditingController(text: vision.visionStatement);
    int startYear = vision.startYear;
    int targetYear = vision.targetYear;
    int duration = vision.totalYears;

    // Clone horizons list for editing
    var horizons = vision.horizons.map((h) => h.toJson()).toList();

    void applyPreset(int years, void Function(void Function()) setDialogState) {
      setDialogState(() {
        duration = years;
        targetYear = startYear + years;
        titleCtrl.text = 'Vision $targetYear: $years-Year Master Strategy';

        if (years <= 5) {
          horizons = [
            {
              'horizonNumber': 1,
              'name': 'Horizon 1: Foundation & Quick Wins',
              'subtitle': 'Years 1 – 2 ($startYear – ${startYear + 2})',
              'startYear': startYear,
              'endYear': startYear + 2,
              'primaryFocus': 'Streamline operations, modernize digital tools, and achieve positive cash flow.',
              'status': 'active',
            },
            {
              'horizonNumber': 2,
              'name': 'Horizon 2: Market Expansion & Scale',
              'subtitle': 'Years 3 – $years (${startYear + 3} – $targetYear)',
              'startYear': startYear + 3,
              'endYear': targetYear,
              'primaryFocus': 'Scale operations, double revenue, and achieve regional market leadership.',
              'status': 'upcoming',
            },
          ];
        } else if (years <= 10) {
          horizons = [
            {
              'horizonNumber': 1,
              'name': 'Horizon 1: Core Foundation & Digital Backbone',
              'subtitle': 'Years 1 – 3 ($startYear – ${startYear + 2})',
              'startYear': startYear,
              'endYear': startYear + 2,
              'primaryFocus': 'Solidify internal ERP systems, standard operating procedures, and talent retention.',
              'status': 'active',
            },
            {
              'horizonNumber': 2,
              'name': 'Horizon 2: Geographic & Multi-State Expansion',
              'subtitle': 'Years 4 – 7 (${startYear + 3} – ${startYear + 6})',
              'startYear': startYear + 3,
              'endYear': startYear + 6,
              'primaryFocus': 'Expand studios into adjacent states and establish regional logistics hubs.',
              'status': 'upcoming',
            },
            {
              'horizonNumber': 3,
              'name': 'Horizon 3: National Footprint & Flagship Excellence',
              'subtitle': 'Years 8 – 10 (${startYear + 7} – $targetYear)',
              'startYear': startYear + 7,
              'endYear': targetYear,
              'primaryFocus': 'National brand recognition, high-margin premium offerings, and IPO readiness.',
              'status': 'future',
            },
          ];
        } else if (years <= 15) {
          horizons = [
            {
              'horizonNumber': 1,
              'name': 'Horizon 1: Foundation & Digital Core',
              'subtitle': 'Years 1 – 3 ($startYear – ${startYear + 2})',
              'startYear': startYear,
              'endYear': startYear + 2,
              'primaryFocus': 'Complete automated ERP operations, solidify studio dominance, and establish regional hubs.',
              'status': 'active',
            },
            {
              'horizonNumber': 2,
              'name': 'Horizon 2: Multi-State Scale & Academy',
              'subtitle': 'Years 4 – 7 (${startYear + 3} – ${startYear + 7})',
              'startYear': startYear + 3,
              'endYear': startYear + 7,
              'primaryFocus': 'Pan-South India expansion, launching the Artistry Academy, and scaling B2B partnerships.',
              'status': 'upcoming',
            },
            {
              'horizonNumber': 3,
              'name': 'Horizon 3: National Footprint & Global Hubs',
              'subtitle': 'Years 8 – 15+ (${startYear + 8} – $targetYear)',
              'startYear': startYear + 8,
              'endYear': targetYear,
              'primaryFocus': 'Pan-India presence in all metro hubs, international NRI studio lounges, and IPO readiness.',
              'status': 'future',
            },
          ];
        } else {
          // 20+ years
          horizons = [
            {
              'horizonNumber': 1,
              'name': 'Horizon 1: Foundation',
              'subtitle': 'Years 1 – 3 ($startYear – ${startYear + 2})',
              'startYear': startYear,
              'endYear': startYear + 2,
              'primaryFocus': 'Core business automation and stabilization.',
              'status': 'active',
            },
            {
              'horizonNumber': 2,
              'name': 'Horizon 2: Expansion',
              'subtitle': 'Years 4 – 7 (${startYear + 3} – ${startYear + 6})',
              'startYear': startYear + 3,
              'endYear': startYear + 6,
              'primaryFocus': 'Domestic multi-state presence.',
              'status': 'upcoming',
            },
            {
              'horizonNumber': 3,
              'name': 'Horizon 3: Transformation',
              'subtitle': 'Years 8 – 14 (${startYear + 7} – ${startYear + 13})',
              'startYear': startYear + 7,
              'endYear': startYear + 13,
              'primaryFocus': 'Global brand lounges and institutional scale.',
              'status': 'future',
            },
            {
              'horizonNumber': 4,
              'name': 'Horizon 4: Industry Vanguard',
              'subtitle': 'Years 15 – $years (${startYear + 14} – $targetYear)',
              'startYear': startYear + 14,
              'endYear': targetYear,
              'primaryFocus': 'Global category leadership, multi-brand luxury conglomerate.',
              'status': 'future',
            },
          ];
        }
      });
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final crm = ctx.crmColors;
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.tune_rounded, color: crm.primary, size: 22),
                const SizedBox(width: 10),
                const Text('Configure Strategic Masterplan', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              ],
            ),
            content: SizedBox(
              width: 640,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select Planning Horizon Span',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: crm.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    // Quick duration presets
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final preset in [5, 10, 15, 20])
                          ChoiceChip(
                            label: Text('$preset-Year Plan ($startYear–${startYear + preset})'),
                            selected: duration == preset,
                            onSelected: (_) => applyPreset(preset, setDialogState),
                            selectedColor: crm.primary,
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: duration == preset ? Colors.white : crm.textSecondary,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Custom Years
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: startYear,
                            decoration: const InputDecoration(labelText: 'Start Year'),
                            items: [for (var y = 2024; y <= 2035; y++) DropdownMenuItem(value: y, child: Text('$y'))],
                            onChanged: (v) {
                              if (v != null) {
                                setDialogState(() {
                                  startYear = v;
                                  targetYear = startYear + duration;
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: targetYear,
                            decoration: const InputDecoration(labelText: 'Target Horizon Year'),
                            items: [
                              for (var y = startYear + 1; y <= startYear + 30; y++)
                                DropdownMenuItem(value: y, child: Text('$y (${y - startYear} yrs)')),
                            ],
                            onChanged: (v) {
                              if (v != null) {
                                setDialogState(() {
                                  targetYear = v;
                                  duration = targetYear - startYear;
                                  titleCtrl.text = 'Vision $targetYear: $duration-Year Master Strategy';
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(labelText: 'Masterplan Title', hintText: 'e.g. Vision 2040: Master Strategy'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: statementCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'North Star Strategic Statement',
                        hintText: 'Describe the overarching vision for the company...',
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Horizons Overview
                    Row(
                      children: [
                        Icon(Icons.waves_rounded, size: 16, color: crm.primary),
                        const SizedBox(width: 6),
                        Text(
                          'Configured Horizon Waves (${horizons.length})',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: crm.textPrimary),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () {
                            setDialogState(() {
                              final nextNum = horizons.length + 1;
                              horizons.add({
                                'horizonNumber': nextNum,
                                'name': 'Horizon $nextNum',
                                'subtitle': 'Wave $nextNum',
                                'startYear': targetYear - 2,
                                'endYear': targetYear,
                                'primaryFocus': 'Strategic growth initiative.',
                                'status': 'future',
                              });
                            });
                          },
                          icon: const Icon(Icons.add, size: 15),
                          label: const Text('Add Horizon', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    for (var i = 0; i < horizons.length; i++) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: crm.background,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: crm.border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _horizonColor(horizons[i]['horizonNumber'] as int).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'H${horizons[i]['horizonNumber']}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                  color: _horizonColor(horizons[i]['horizonNumber'] as int),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    horizons[i]['name'].toString(),
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '${horizons[i]['startYear']} – ${horizons[i]['endYear']} · ${horizons[i]['subtitle']}',
                                    style: TextStyle(fontSize: 11, color: crm.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            if (horizons.length > 1)
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                tooltip: 'Remove Horizon',
                                onPressed: () {
                                  setDialogState(() {
                                    horizons.removeAt(i);
                                    // renumber
                                    for (var idx = 0; idx < horizons.length; idx++) {
                                      horizons[idx]['horizonNumber'] = idx + 1;
                                    }
                                  });
                                },
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(
                onPressed: () async {
                  if (titleCtrl.text.trim().isEmpty) return;
                  Navigator.pop(ctx);
                  try {
                    await ref.read(strategicVisionServiceProvider).updateVision({
                      'title': titleCtrl.text.trim(),
                      'visionStatement': statementCtrl.text.trim(),
                      'startYear': startYear,
                      'targetYear': targetYear,
                      'horizons': horizons,
                    });
                    ref.invalidate(strategicVisionProvider);
                    ref.invalidate(strategicAlignmentProvider);
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('Strategic plan updated to $duration-Year Horizon ($startYear–$targetYear)')));
                    }
                  } catch (e) {
                    if (context.mounted) showErrorSnackBar(context, e);
                  }
                },
                child: const Text('Save Masterplan'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showMilestoneEditor({StrategicMilestone? existing, required StrategicVisionModel vision}) {
    final title = TextEditingController(text: existing?.title ?? '');
    final desc = TextEditingController(text: existing?.description ?? '');
    final targetYear = TextEditingController(text: '${existing?.targetYear ?? vision.startYear + 2}');
    final metricLabel = TextEditingController(text: existing?.metricLabel ?? '');
    final targetMetric = TextEditingController(text: '${existing?.targetMetric ?? 100}');
    final currentMetric = TextEditingController(text: '${existing?.currentMetric ?? 0}');
    final metricUnit = TextEditingController(text: existing?.metricUnit ?? '%');

    int horizon = existing?.horizonNumber ?? (vision.horizons.isNotEmpty ? vision.horizons.first.horizonNumber : 1);
    String pillarId = existing?.pillarId ?? (vision.pillars.isNotEmpty ? vision.pillars.first.id : 'expansion');
    String status = existing?.status ?? 'planned';
    String quarter = existing?.targetQuarter ?? 'Q4';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: (existing != null ? existing.statusColor : const Color(0xFF3B82F6)).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  existing == null ? Icons.add_task_rounded : Icons.edit_note_rounded,
                  color: existing != null ? existing.statusColor : const Color(0xFF3B82F6),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                existing == null ? 'Add Gateway Milestone' : 'Edit Gateway Milestone',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: title,
                    decoration: const InputDecoration(labelText: 'Milestone Title *', hintText: 'e.g. Establish 10 Regional South India Hubs'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: desc,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Description / Context',
                      hintText: 'Detail the strategic deliverable and expected organizational impact...',
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: horizon,
                          decoration: const InputDecoration(labelText: 'Horizon Wave'),
                          items: [
                            for (final h in vision.horizons)
                              DropdownMenuItem(
                                value: h.horizonNumber,
                                child: Text('H${h.horizonNumber} (${h.startYear}–${h.endYear})', overflow: TextOverflow.ellipsis),
                              ),
                          ],
                          onChanged: (v) => setDialog(() => horizon = v ?? horizon),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: vision.pillars.any((p) => p.id == pillarId)
                              ? pillarId
                              : (vision.pillars.isNotEmpty ? vision.pillars.first.id : null),
                          decoration: const InputDecoration(labelText: 'Strategic Pillar'),
                          items: [
                            for (final p in vision.pillars)
                              DropdownMenuItem(
                                value: p.id,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(color: p.color, shape: BoxShape.circle),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(child: Text(p.name, overflow: TextOverflow.ellipsis)),
                                  ],
                                ),
                              ),
                          ],
                          onChanged: (v) => setDialog(() => pillarId = v ?? pillarId),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: targetYear,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(labelText: 'Target Year', hintText: '${vision.startYear + 2}'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          initialValue: quarter,
                          decoration: const InputDecoration(labelText: 'Quarter'),
                          items: const [
                            DropdownMenuItem(value: 'Q1', child: Text('Q1')),
                            DropdownMenuItem(value: 'Q2', child: Text('Q2')),
                            DropdownMenuItem(value: 'Q3', child: Text('Q3')),
                            DropdownMenuItem(value: 'Q4', child: Text('Q4')),
                          ],
                          onChanged: (v) => setDialog(() => quarter = v ?? 'Q4'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<String>(
                          initialValue: status,
                          decoration: const InputDecoration(labelText: 'Status'),
                          items: const [
                            DropdownMenuItem(value: 'planned', child: Text('Planned')),
                            DropdownMenuItem(value: 'in-flight', child: Text('In-Flight')),
                            DropdownMenuItem(value: 'achieved', child: Text('Achieved')),
                            DropdownMenuItem(value: 'at-risk', child: Text('At Risk')),
                          ],
                          onChanged: (v) => setDialog(() => status = v ?? 'planned'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: ctx.crmColors.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: ctx.crmColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Target Metric & Measurement Gauge',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ctx.crmColors.textSecondary),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextField(
                                controller: metricLabel,
                                decoration: const InputDecoration(labelText: 'Metric Label', hintText: 'Active Hubs'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: currentMetric,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: 'Current'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: targetMetric,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: 'Target'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: metricUnit,
                                decoration: const InputDecoration(labelText: 'Unit', hintText: 'Hubs'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            if (existing != null)
              TextButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await ref.read(strategicVisionServiceProvider).deleteMilestone(existing.id);
                  ref.invalidate(strategicVisionProvider);
                  ref.invalidate(strategicAlignmentProvider);
                },
                icon: const Icon(Icons.delete_outline, size: 16),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                label: const Text('Delete'),
              ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (title.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                final data = {
                  if (existing != null) 'id': existing.id,
                  'title': title.text.trim(),
                  'description': desc.text.trim(),
                  'horizonNumber': horizon,
                  'pillarId': pillarId,
                  'targetYear': int.tryParse(targetYear.text.trim()) ?? vision.startYear + 2,
                  'targetQuarter': quarter,
                  'status': status,
                  'metricLabel': metricLabel.text.trim(),
                  'currentMetric': double.tryParse(currentMetric.text.trim()) ?? 0,
                  'targetMetric': double.tryParse(targetMetric.text.trim()) ?? 100,
                  'metricUnit': metricUnit.text.trim(),
                };
                try {
                  await ref.read(strategicVisionServiceProvider).addOrUpdateMilestone(data);
                  ref.invalidate(strategicVisionProvider);
                  ref.invalidate(strategicAlignmentProvider);
                } catch (e) {
                  if (mounted) showErrorSnackBar(context, e);
                }
              },
              child: const Text('Save Milestone'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final access = Access.of(ref.watch(authSessionProvider));
    final canManage = access.isFullAccess || access.isDepartmentHead || access.canManageAllPlanning;

    final visionAsync = ref.watch(strategicVisionProvider);
    final projectsAsync = ref.watch(companyProjectsProvider(null));

    return visionAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => AppErrorView(error: e, onRetry: () => ref.invalidate(strategicVisionProvider)),
      data: (vision) {
        // Only main projects (3+ months major strategic initiatives) are shown on the strategic roadmap
        final mainProjects = (projectsAsync.value ?? const <Project>[]).where((p) => projectTierOf(p) == ProjectTier.main).toList();

        final filteredMilestones = vision.milestones.where((m) {
          if (_selectedPillarId != 'all' && m.pillarId != _selectedPillarId) return false;
          return true;
        }).toList();

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(strategicVisionProvider);
            ref.invalidate(strategicAlignmentProvider);
            ref.invalidate(companyProjectsProvider(null));
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 50),
            children: [
              // Redesigned Top Hero Masterplan Card
              _buildVisionHeroCard(crm, vision, canManage, mainProjects),
              const SizedBox(height: 18),

              // Redesigned Strategic Pillars Navigation Strip
              _buildPillarsFilter(crm, vision.pillars, vision.milestones),
              const SizedBox(height: 18),

              // Action Bar & View Switcher
              _buildActionBar(crm, vision, canManage),
              const SizedBox(height: 16),

              // Main Roadmap Body (Cascading Waves or Multi-Year Timeline)
              if (_viewMode == _RoadmapViewMode.waves)
                _buildWavesView(crm, vision, filteredMilestones, mainProjects, canManage)
              else
                _buildTimelineView(crm, vision, filteredMilestones, mainProjects, canManage),
            ],
          ),
        );
      },
    );
  }

  // ── Executive Hero Card ─────────────────────────────────────────────────────────────

  Widget _buildVisionHeroCard(CrmTheme crm, StrategicVisionModel vision, bool canManage, List<Project> mainProjects) {
    // Executive Metrics
    final totalMilestones = vision.milestones.length;
    final achievedCount = vision.milestones.where((m) => m.status.toLowerCase() == 'achieved').length;
    final inFlightCount = vision.milestones.where((m) => m.status.toLowerCase() == 'in-flight').length;
    final overallProgress = totalMilestones == 0 ? 0.0 : (vision.milestones.map((m) => m.progress).reduce((a, b) => a + b) / totalMilestones);
    final overallPct = (overallProgress * 100).round();

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0F172A), // Slate 900
            Color(0xFF1E1B4B), // Deep Indigo
            Color(0xFF312E81), // Rich Indigo
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [BoxShadow(color: const Color(0xFF1E1B4B).withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 8))],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Strategic Plan Badge + Years + Frosted Action Button
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.stars_rounded, size: 14, color: Color(0xFFFBBF24)),
                    const SizedBox(width: 6),
                    Text(
                      '${vision.totalYears}-YEAR STRATEGIC MASTERPLAN',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(6)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(color: Color(0xFFF59E0B), shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${vision.startYear} – ${vision.targetYear}',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (canManage)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _showMasterplanConfigDialog(context, vision),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.tune_rounded, size: 15, color: Colors.white),
                          SizedBox(width: 7),
                          Text(
                            'Configure Masterplan',
                            style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700, letterSpacing: 0.2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Masterplan Title
          Text(
            vision.title,
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5, height: 1.2),
          ),
          const SizedBox(height: 10),

          // North Star Vision Statement in Glassmorphic Quote Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.format_quote_rounded, color: Color(0xFFFBBF24), size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    vision.visionStatement,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.95), fontSize: 13, height: 1.45, fontWeight: FontWeight.w400),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Executive Strategy Stat Chips
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              _buildHeroMetricTile(
                icon: Icons.track_changes_rounded,
                label: 'Strategy Progress',
                value: '$overallPct%',
                subtitle: '$achievedCount achieved · $inFlightCount active',
                color: const Color(0xFF10B981),
                progress: overallProgress,
              ),
              _buildHeroMetricTile(
                icon: Icons.hub_rounded,
                label: 'Cascading Waves',
                value: '${vision.horizons.length} Horizons',
                subtitle: '${vision.totalYears} years roadmap span',
                color: const Color(0xFF8B5CF6),
              ),
              _buildHeroMetricTile(
                icon: Icons.workspaces_filled,
                label: 'Aligned Projects',
                value: '${mainProjects.length}',
                subtitle: 'Main strategic initiatives',
                color: const Color(0xFFF59E0B),
              ),
            ],
          ),
          const SizedBox(height: 20),

          Divider(color: Colors.white.withValues(alpha: 0.16)),
          const SizedBox(height: 14),

          // Dynamic Horizon Breakdown Waves Strip
          Row(
            children: [
              const Icon(Icons.waves_rounded, size: 16, color: Colors.white70),
              const SizedBox(width: 8),
              Text(
                'ROADMAP HORIZON PHASES',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8),
              ),
            ],
          ),
          const SizedBox(height: 10),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < vision.horizons.length; i++) ...[
                  if (i > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Icon(Icons.arrow_forward_rounded, color: Colors.white.withValues(alpha: 0.35), size: 18),
                    ),
                  _buildHorizonWavePill(
                    horizon: vision.horizons[i],
                    milestones: vision.milestones.where((m) => m.horizonNumber == vision.horizons[i].horizonNumber).toList(),
                    color: _horizonColor(vision.horizons[i].horizonNumber),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroMetricTile({
    required IconData icon,
    required String label,
    required String value,
    required String subtitle,
    required Color color,
    double? progress,
  }) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900, letterSpacing: -0.5),
          ),
          if (progress != null) ...[
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: Colors.white.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 10.5, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildHorizonWavePill({required StrategicHorizon horizon, required List<StrategicMilestone> milestones, required Color color}) {
    final count = milestones.length;
    final progress = count == 0 ? 0.0 : (milestones.map((m) => m.progress).reduce((a, b) => a + b) / count);
    final pct = (progress * 100).round();
    final isActive = horizon.status.toLowerCase() == 'active';

    return Container(
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 280),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: isActive ? 0.14 : 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isActive ? color.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.15), width: isActive ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(6)),
                child: Text(
                  'Wave ${horizon.horizonNumber}',
                  style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                child: Text(
                  '${horizon.startYear}–${horizon.endYear}',
                  style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 10.5, fontWeight: FontWeight.w800),
                ),
              ),
              const Spacer(),
              if (isActive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, size: 6, color: Color(0xFF10B981)),
                      SizedBox(width: 4),
                      Text(
                        'ACTIVE',
                        style: TextStyle(color: Color(0xFF10B981), fontSize: 9.5, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            horizon.name,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (horizon.primaryFocus.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              horizon.primaryFocus,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 4,
                    backgroundColor: Colors.white.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$pct% ($count)',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 10.5, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Strategic Pillars Filter Strip ─────────────────────────────────────────────────────────────

  Widget _buildPillarsFilter(CrmTheme crm, List<StrategicPillar> pillars, List<StrategicMilestone> allMilestones) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // "All Pillars" pill
          _buildPillarChip(
            crm: crm,
            label: 'All Strategic Pillars',
            count: allMilestones.length,
            color: crm.primary,
            isSelected: _selectedPillarId == 'all',
            onTap: () => setState(() => _selectedPillarId = 'all'),
          ),
          const SizedBox(width: 8),
          for (final p in pillars) ...[
            _buildPillarChip(
              crm: crm,
              label: p.name,
              count: allMilestones.where((m) => m.pillarId == p.id).length,
              color: p.color,
              isSelected: _selectedPillarId == p.id,
              onTap: () => setState(() => _selectedPillarId = p.id),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildPillarChip({
    required CrmTheme crm,
    required String label,
    required int count,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? color : crm.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isSelected ? color : crm.border, width: isSelected ? 1.5 : 1),
            boxShadow: isSelected ? [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))] : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: isSelected ? Colors.white : color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: isSelected ? Colors.white : crm.textPrimary),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white.withValues(alpha: 0.25) : crm.background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: isSelected ? Colors.white : crm.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Action Bar & View Switcher ─────────────────────────────────────────────────────────────

  Widget _buildActionBar(CrmTheme crm, StrategicVisionModel vision, bool canManage) {
    return Row(
      children: [
        const Icon(Icons.explore_rounded, size: 20, color: Color(0xFF3B82F6)),
        const SizedBox(width: 8),
        Text(
          '${vision.totalYears}-Year Cascading Horizons',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: crm.textPrimary),
        ),
        const Spacer(),

        // Segmented View Switcher: [ Waves ] vs [ Timeline ]
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: crm.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: crm.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildViewSwitchButton(
                icon: Icons.waves_rounded,
                label: 'Waves View',
                isSelected: _viewMode == _RoadmapViewMode.waves,
                crm: crm,
                onTap: () => setState(() => _viewMode = _RoadmapViewMode.waves),
              ),
              _buildViewSwitchButton(
                icon: Icons.timeline_rounded,
                label: 'Roadmap Timeline',
                isSelected: _viewMode == _RoadmapViewMode.timeline,
                crm: crm,
                onTap: () => setState(() => _viewMode = _RoadmapViewMode.timeline),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),

        if (canManage)
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: crm.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 2,
            ),
            onPressed: () => _showMilestoneEditor(vision: vision),
            icon: const Icon(Icons.add_task_rounded, size: 16),
            label: const Text('Add Gateway Milestone', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
          ),
      ],
    );
  }

  Widget _buildViewSwitchButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required CrmTheme crm,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(color: isSelected ? crm.primary : Colors.transparent, borderRadius: BorderRadius.circular(8)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: isSelected ? Colors.white : crm.textSecondary),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: isSelected ? Colors.white : crm.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Cascading Waves View ─────────────────────────────────────────────────────────────

  Widget _buildWavesView(
    CrmTheme crm,
    StrategicVisionModel vision,
    List<StrategicMilestone> filteredMilestones,
    List<Project> mainProjects,
    bool canManage,
  ) {
    if (vision.horizons.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: crm.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: crm.border),
        ),
        child: Column(
          children: [
            Icon(Icons.waves_rounded, size: 48, color: crm.textSecondary.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text(
              'No horizon waves configured',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: crm.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              'Click "Configure Masterplan" on the top banner to define horizon waves.',
              style: TextStyle(fontSize: 12.5, color: crm.textSecondary),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        for (final horizon in vision.horizons) ...[
          _buildHorizonSection(
            crm: crm,
            horizon: horizon,
            pillars: vision.pillars,
            milestones: filteredMilestones.where((m) => m.horizonNumber == horizon.horizonNumber).toList(),
            projects: mainProjects.where((p) => p.horizonNumber == horizon.horizonNumber).toList(),
            accentColor: _horizonColor(horizon.horizonNumber),
            tagText: 'Wave ${horizon.horizonNumber} (${horizon.startYear}–${horizon.endYear})',
            canManage: canManage,
            onEditMilestone: (m) => _showMilestoneEditor(existing: m, vision: vision),
          ),
          const SizedBox(height: 18),
        ],
      ],
    );
  }

  Widget _buildHorizonSection({
    required CrmTheme crm,
    required StrategicHorizon horizon,
    required List<StrategicPillar> pillars,
    required List<StrategicMilestone> milestones,
    required List<Project> projects,
    required Color accentColor,
    required String tagText,
    required bool canManage,
    required void Function(StrategicMilestone m) onEditMilestone,
  }) {
    final count = milestones.length;
    final progress = count == 0 ? 0.0 : (milestones.map((m) => m.progress).reduce((a, b) => a + b) / count);
    final pct = (progress * 100).round();
    final isActive = horizon.status.toLowerCase() == 'active';

    return Container(
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isActive ? accentColor.withValues(alpha: 0.45) : crm.border, width: isActive ? 1.5 : 1),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Horizon Header Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              border: Border(bottom: BorderSide(color: crm.border.withValues(alpha: 0.6))),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: accentColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                  alignment: Alignment.center,
                  child: Text(
                    'H${horizon.horizonNumber}',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: accentColor),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              horizon.name,
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: crm.textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: accentColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                            child: Text(
                              tagText,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: accentColor),
                            ),
                          ),
                          if (isActive) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'ACTIVE CORE',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF10B981)),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (horizon.primaryFocus.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(horizon.primaryFocus, style: TextStyle(fontSize: 12, color: crm.textSecondary)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),

                // Horizon Progress Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: crm.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: crm.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$pct%',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: accentColor),
                          ),
                          const SizedBox(width: 4),
                          Text('attainment', style: TextStyle(fontSize: 10, color: crm.textSecondary)),
                        ],
                      ),
                      const SizedBox(height: 3),
                      SizedBox(
                        width: 80,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 4,
                            backgroundColor: crm.border,
                            valueColor: AlwaysStoppedAnimation(accentColor),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Milestones Body
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (milestones.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    alignment: Alignment.center,
                    child: Text(
                      'No gateway milestones defined for this horizon wave yet.',
                      style: TextStyle(fontSize: 12.5, color: crm.textSecondary),
                    ),
                  )
                else
                  for (final m in milestones) ...[
                    _buildMilestoneCard(
                      crm: crm,
                      milestone: m,
                      pillar: pillars.cast<StrategicPillar?>().firstWhere((p) => p?.id == m.pillarId, orElse: () => null),
                      accentColor: accentColor,
                      onEdit: onEditMilestone,
                    ),
                    const SizedBox(height: 12),
                  ],

                // Contributing Executing Projects (Only Main Projects)
                if (projects.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.hub_rounded, size: 14, color: crm.textSecondary),
                      const SizedBox(width: 6),
                      Text(
                        'Aligned Main Projects (${projects.length})',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: crm.textSecondary, letterSpacing: 0.2),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final p in projects)
                        InkWell(
                          onTap: () => context.go('/projects/${p.id}'),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: crm.background,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: crm.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.rocket_launch_rounded, size: 13, color: crm.primary),
                                const SizedBox(width: 6),
                                Text(
                                  p.name,
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: crm.textPrimary),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'MAIN',
                                    style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: Color(0xFFD97706)),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(color: crm.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
                                  child: Text(
                                    '${p.progress}%',
                                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: crm.primary),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Milestone Card ─────────────────────────────────────────────────────────────

  Widget _buildMilestoneCard({
    required CrmTheme crm,
    required StrategicMilestone milestone,
    required StrategicPillar? pillar,
    required Color accentColor,
    required void Function(StrategicMilestone m) onEdit,
  }) {
    final m = milestone;
    final pct = (m.progress * 100).round();

    return Container(
      decoration: BoxDecoration(
        color: crm.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: crm.border),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top metadata strip: Status + Pillar + Target Date + Edit
          Row(
            children: [
              // Status Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: m.statusColor.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(6)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(color: m.statusColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      m.status.toUpperCase(),
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: m.statusColor, letterSpacing: 0.3),
                    ),
                  ],
                ),
              ),

              // Pillar Tag
              if (pillar != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: pillar.color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                  child: Text(
                    pillar.name,
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: pillar.color),
                  ),
                ),
              ],

              const Spacer(),

              // Target Year & Quarter Tag
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: const Color(0xFFF59E0B).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 11, color: Color(0xFFD97706)),
                    const SizedBox(width: 5),
                    Text(
                      'Year ${m.targetYear} (${m.targetQuarter})',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFD97706)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Quick Edit Button
              InkWell(
                onTap: () => onEdit(m),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: crm.surface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: crm.border),
                  ),
                  child: Icon(Icons.edit_outlined, size: 14, color: crm.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Title & Description
          Text(
            m.title,
            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: crm.textPrimary, height: 1.25),
          ),
          if (m.description.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(m.description, style: TextStyle(fontSize: 12.5, color: crm.textSecondary, height: 1.35)),
          ],
          const SizedBox(height: 12),

          // Metric Progress Gauge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: crm.surface,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: crm.border.withValues(alpha: 0.7)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            m.metricLabel.isNotEmpty ? m.metricLabel : 'Target Metric',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: crm.textSecondary),
                          ),
                          Text(
                            '${m.currentMetric.toStringAsFixed(0)} / ${m.targetMetric.toStringAsFixed(0)} ${m.metricUnit} ($pct%)',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: crm.textPrimary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: m.progress,
                          minHeight: 7,
                          backgroundColor: crm.border,
                          valueColor: AlwaysStoppedAnimation(m.statusColor),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Multi-Year Timeline View ─────────────────────────────────────────────────────────────

  Widget _buildTimelineView(
    CrmTheme crm,
    StrategicVisionModel vision,
    List<StrategicMilestone> filteredMilestones,
    List<Project> mainProjects,
    bool canManage,
  ) {
    // Generate years range from startYear to targetYear
    final years = [for (var y = vision.startYear; y <= vision.targetYear; y++) y];

    return Container(
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: crm.border),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timeline_rounded, color: Color(0xFF3B82F6), size: 18),
              const SizedBox(width: 8),
              Text(
                'Chronological Multi-Year Strategic Trajectory (${vision.startYear} – ${vision.targetYear})',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: crm.textPrimary),
              ),
              const Spacer(),
              Text('Scroll horizontally to explore all ${vision.totalYears} years →', style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
            ],
          ),
          const SizedBox(height: 16),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final year in years) ...[
                  _buildYearColumn(
                    crm: crm,
                    year: year,
                    vision: vision,
                    milestones: filteredMilestones.where((m) => m.targetYear == year).toList(),
                    canManage: canManage,
                  ),
                  if (year != vision.targetYear)
                    Container(width: 1, height: 480, color: crm.border.withValues(alpha: 0.6), margin: const EdgeInsets.symmetric(horizontal: 10)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYearColumn({
    required CrmTheme crm,
    required int year,
    required StrategicVisionModel vision,
    required List<StrategicMilestone> milestones,
    required bool canManage,
  }) {
    // Find corresponding horizon
    final horizon = vision.horizons.cast<StrategicHorizon?>().firstWhere(
      (h) => h != null && year >= h.startYear && year <= h.endYear,
      orElse: () => null,
    );
    final accent = horizon != null ? _horizonColor(horizon.horizonNumber) : crm.primary;
    final isCurrentYear = year == DateTime.now().year;

    return Container(
      width: 250,
      constraints: const BoxConstraints(minHeight: 460),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Year Header
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isCurrentYear ? accent.withValues(alpha: 0.14) : crm.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isCurrentYear ? accent : crm.border),
            ),
            child: Row(
              children: [
                Text(
                  '$year',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: isCurrentYear ? accent : crm.textPrimary),
                ),
                if (isCurrentYear) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(4)),
                    child: const Text(
                      'CURRENT',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                  ),
                ],
                const Spacer(),
                if (horizon != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                    child: Text(
                      'H${horizon.horizonNumber}',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: accent),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Milestones in this year
          if (milestones.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              alignment: Alignment.center,
              child: Text('No milestones targeted', style: TextStyle(fontSize: 11, color: crm.textSecondary)),
            )
          else
            for (final m in milestones) ...[
              InkWell(
                onTap: () => _showMilestoneEditor(existing: m, vision: vision),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: crm.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: crm.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(color: m.statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                            child: Text(
                              m.status.toUpperCase(),
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: m.statusColor),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            m.targetQuarter,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFD97706)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        m.title,
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: crm.textPrimary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: m.progress,
                          minHeight: 4,
                          backgroundColor: crm.border,
                          valueColor: AlwaysStoppedAnimation(m.statusColor),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
        ],
      ),
    );
  }
}
