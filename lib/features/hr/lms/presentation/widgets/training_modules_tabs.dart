import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/hr/shared/hr_ui.dart';

// ══════════════════════════════════════════════════════════════════════════════
// 1. SYLLABUS & TUTORIALS TAB
// ══════════════════════════════════════════════════════════════════════════════

class SyllabusTutorialsTab extends StatefulWidget {
  final CrmTheme crm;
  final bool canManage;

  const SyllabusTutorialsTab({super.key, required this.crm, required this.canManage});

  @override
  State<SyllabusTutorialsTab> createState() => _SyllabusTutorialsTabState();
}

class _SyllabusTutorialsTabState extends State<SyllabusTutorialsTab> {
  String _selectedTrack = 'All';

  final List<Map<String, dynamic>> _tutorials = [
    {
      'id': 'tut-01',
      'title': 'Bridal HD Base & Contouring Techniques',
      'track': 'Bridal Artistry',
      'duration': '45 mins',
      'lessons': 6,
      'level': 'Advanced',
      'videoUrl': 'https://vimeo.com/sample-bridal-hd',
      'description': 'Mastering poreless HD foundation application, undertone correction and camera-ready contouring for Kerala brides.',
      'tags': ['HD Makeup', 'Base', 'Contour'],
    },
    {
      'id': 'tut-02',
      'title': 'Traditional South Indian & Modern Draping',
      'track': 'Saree Draping',
      'duration': '35 mins',
      'lessons': 4,
      'level': 'Intermediate',
      'videoUrl': 'https://vimeo.com/sample-draping',
      'description': 'Iron-box pleating, box pleating, Kanchipuram silk setting, and speed pinning under 12 minutes.',
      'tags': ['Silk Saree', 'Pleating', 'Speed'],
    },
    {
      'id': 'tut-03',
      'title': 'Airbrush Equipment Sanitation & Troubleshooting',
      'track': 'Equipment & Tooling',
      'duration': '25 mins',
      'lessons': 3,
      'level': 'All Levels',
      'videoUrl': 'https://vimeo.com/sample-airbrush',
      'description': 'Compressor maintenance, needle cleaning, clog prevention, and hospital-grade sanitization protocols.',
      'tags': ['Airbrush', 'Sanitization', 'Hygiene'],
    },
    {
      'id': 'tut-04',
      'title': 'High-Profile Client Concierge & Consultation',
      'track': 'Client Handling',
      'duration': '30 mins',
      'lessons': 5,
      'level': 'Leadership',
      'videoUrl': 'https://vimeo.com/sample-client-care',
      'description': 'Trial etiquette, wedding day timeline coordination, high-stress de-escalation, and bridal vanity prep.',
      'tags': ['Consultation', 'Soft Skills', 'Bridal Care'],
    },
  ];

  @override
  Widget build(BuildContext context) {
    final crm = widget.crm;
    final filtered = _selectedTrack == 'All'
        ? _tutorials
        : _tutorials.where((t) => t['track'] == _selectedTrack).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Track filters
        Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['All', 'Bridal Artistry', 'Saree Draping', 'Equipment & Tooling', 'Client Handling']
                      .map((track) {
                    final sel = _selectedTrack == track;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(track),
                        selected: sel,
                        selectedColor: crm.primary.withValues(alpha: 0.15),
                        backgroundColor: crm.surface,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                          color: sel ? crm.primary : crm.textSecondary,
                        ),
                        side: BorderSide(color: sel ? crm.primary : crm.border),
                        onSelected: (_) => setState(() => _selectedTrack = track),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            if (widget.canManage)
              ElevatedButton.icon(
                onPressed: () => _showAddTutorialDialog(context, crm),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add Tutorial'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: crm.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),

        // Grid of Tutorials
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 700;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isWide ? 2 : 1,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: isWide ? 2.1 : 1.8,
              ),
              itemCount: filtered.length,
              itemBuilder: (context, i) {
                final t = filtered[i];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: crm.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: crm.border),
                    boxShadow: hrCardShadow(),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: crm.primary.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.play_circle_outline_rounded, size: 20, color: crm.primary),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t['title'] as String,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5,
                                    color: crm.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${t['track']} • ${t['duration']} • ${t['lessons']} Lessons',
                                  style: TextStyle(fontSize: 11, color: crm.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFC9A66B).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              t['level'] as String,
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFC9A66B)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: Text(
                          t['description'] as String,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, height: 1.4, color: crm.textSecondary),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: (t['tags'] as List<String>).map((tag) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: crm.background,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: crm.border),
                                  ),
                                  child: Text(tag, style: TextStyle(fontSize: 9.5, color: crm.textSecondary)),
                                ),
                              );
                            }).toList(),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Opening tutorial video: ${t['title']}')),
                              );
                            },
                            icon: const Icon(Icons.open_in_new_rounded, size: 14),
                            label: const Text('Open Tutorial'),
                            style: TextButton.styleFrom(
                              foregroundColor: crm.primary,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  void _showAddTutorialDialog(BuildContext context, CrmTheme crm) {
    final titleCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Syllabus Tutorial'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Tutorial Title')),
            const SizedBox(height: 10),
            TextField(controller: urlCtrl, decoration: const InputDecoration(labelText: 'Video or Resource URL')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (titleCtrl.text.isNotEmpty) {
                setState(() {
                  _tutorials.insert(0, {
                    'id': 'tut-${DateTime.now().millisecondsSinceEpoch}',
                    'title': titleCtrl.text.trim(),
                    'track': 'Bridal Artistry',
                    'duration': '30 mins',
                    'lessons': 3,
                    'level': 'All Levels',
                    'videoUrl': urlCtrl.text.trim(),
                    'description': 'New training module added by department lead.',
                    'tags': ['Syllabus', 'New'],
                  });
                });
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 2. MENTOR & TRAINER FLOW TAB
// ══════════════════════════════════════════════════════════════════════════════

class MentorTrainerFlowTab extends StatefulWidget {
  final CrmTheme crm;
  final bool canManage;

  const MentorTrainerFlowTab({super.key, required this.crm, required this.canManage});

  @override
  State<MentorTrainerFlowTab> createState() => _MentorTrainerFlowTabState();
}

class _MentorTrainerFlowTabState extends State<MentorTrainerFlowTab> {
  final List<Map<String, dynamic>> _pairs = [
    {
      'trainee': 'Kavya S. Nair',
      'mentor': 'Farhana M. (Senior Bridal Artist)',
      'role': 'Junior Makeup Artist',
      'sessionsCompleted': 8,
      'totalSessions': 12,
      'status': 'Active',
      'recentTopic': 'Waterproof Airbrush Eye Application',
      'lastLog': '14 Oct 2026',
    },
    {
      'trainee': 'Ananya Krishna',
      'mentor': 'Nizan (Creative Director)',
      'role': 'Bridal Hair Stylist',
      'sessionsCompleted': 10,
      'totalSessions': 10,
      'status': 'Signed Off',
      'recentTopic': 'Gajra Floral Architecture & Pin Stability',
      'lastLog': '12 Oct 2026',
    },
    {
      'trainee': 'Meera Pillai',
      'mentor': 'Sujata R. (Lead Stylist)',
      'role': 'Saree Draper',
      'sessionsCompleted': 4,
      'totalSessions': 8,
      'status': 'Active',
      'recentTopic': 'Tissue Silk Speed Draping',
      'lastLog': '15 Oct 2026',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final crm = widget.crm;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Active Mentor-Trainee Pairings',
                  style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: crm.textPrimary),
                ),
                Text('1-on-1 shadow sessions, practical drills and trainer milestone sign-offs', style: TextStyle(fontSize: 12, color: crm.textSecondary)),
              ],
            ),
            if (widget.canManage)
              ElevatedButton.icon(
                onPressed: () => _showLogSessionDialog(context, crm),
                icon: const Icon(Icons.edit_calendar_outlined, size: 16),
                label: const Text('Log Mentor Session'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: crm.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),

        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _pairs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final p = _pairs[i];
            final pct = ((p['sessionsCompleted'] as int) / (p['totalSessions'] as int) * 100).toInt();
            final isDone = p['status'] == 'Signed Off';

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: crm.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: crm.border),
                boxShadow: hrCardShadow(),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: crm.primary.withValues(alpha: 0.12),
                    child: Icon(Icons.supervised_user_circle_outlined, color: crm.primary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p['trainee'] as String,
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14, color: crm.textPrimary),
                        ),
                        Text('Role: ${p['role']}', style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
                        const SizedBox(height: 2),
                        Text('Mentor: ${p['mentor']}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: crm.primary)),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Latest Topic: ${p['recentTopic']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text('Last Recorded: ${p['lastLog']}', style: TextStyle(fontSize: 11, color: crm.textSecondary)),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${p['sessionsCompleted']} / ${p['totalSessions']} Sessions', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                            Text('$pct%', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: crm.primary)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: pct / 100.0,
                          backgroundColor: crm.border,
                          valueColor: AlwaysStoppedAnimation<Color>(isDone ? const Color(0xFF059669) : crm.primary),
                          borderRadius: BorderRadius.circular(4),
                          minHeight: 6,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDone ? const Color(0xFF059669).withValues(alpha: 0.12) : const Color(0xFF2563EB).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: (isDone ? const Color(0xFF059669) : const Color(0xFF2563EB)).withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      p['status'] as String,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isDone ? const Color(0xFF059669) : const Color(0xFF2563EB),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  void _showLogSessionDialog(BuildContext context, CrmTheme crm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log 1-on-1 Mentor Session'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(decoration: InputDecoration(labelText: 'Trainee Name')),
            SizedBox(height: 10),
            TextField(decoration: InputDecoration(labelText: 'Topic Practiced')),
            SizedBox(height: 10),
            TextField(decoration: InputDecoration(labelText: 'Trainer Feedback / Notes')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Record Session')),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 3. EVALUATION & SCORING TAB
// ══════════════════════════════════════════════════════════════════════════════

class EvaluationScoringTab extends StatefulWidget {
  final CrmTheme crm;
  final bool canManage;

  const EvaluationScoringTab({super.key, required this.crm, required this.canManage});

  @override
  State<EvaluationScoringTab> createState() => _EvaluationScoringTabState();
}

class _EvaluationScoringTabState extends State<EvaluationScoringTab> {
  final List<Map<String, dynamic>> _evals = [
    {
      'candidate': 'Kavya S. Nair',
      'test': 'Bridal HD Base Practical Test',
      'score': 94,
      'evaluatedBy': 'Farhana M.',
      'status': 'Passed',
      'date': '14 Oct 2026',
      'remarks': 'Flawless finish, excellent neck & shoulder blending.',
    },
    {
      'candidate': 'Ananya Krishna',
      'test': 'Speed Pinning & Saree Draping Exam',
      'score': 88,
      'evaluatedBy': 'Nizan',
      'status': 'Passed',
      'date': '12 Oct 2026',
      'remarks': 'Completed in 11 minutes. Pleats aligned precisely.',
    },
    {
      'candidate': 'Sanjay Varma',
      'test': 'Camera Lighting & Color Correction Theory',
      'score': 72,
      'evaluatedBy': 'Tech Lead',
      'status': 'Retake Required',
      'date': '10 Oct 2026',
      'remarks': 'Needs review of tungsten vs 5600K daylight balances.',
    },
    {
      'candidate': 'Meera Pillai',
      'test': 'Hygiene & Tool Sterilization Audit',
      'score': 100,
      'evaluatedBy': 'Lead Auditor',
      'status': 'Passed',
      'date': '08 Oct 2026',
      'remarks': 'Zero contamination infractions. Exemplary sanitization.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final crm = widget.crm;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Training Assessments & Scoring Sheets',
                  style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: crm.textPrimary),
                ),
                Text('Practical drill scorecards, threshold evaluations and evaluator sign-offs', style: TextStyle(fontSize: 12, color: crm.textSecondary)),
              ],
            ),
            if (widget.canManage)
              ElevatedButton.icon(
                onPressed: () => _showRecordScoreDialog(context, crm),
                icon: const Icon(Icons.add_task_rounded, size: 16),
                label: const Text('Record Assessment'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: crm.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),

        // Assessments Table
        Container(
          decoration: BoxDecoration(
            color: crm.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: crm.border),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  color: crm.background,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                  border: Border(bottom: BorderSide(color: crm.border)),
                ),
                child: const Row(
                  children: [
                    Expanded(flex: 2, child: Text('TRAINEE', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                    Expanded(flex: 3, child: Text('ASSESSMENT TEST', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                    Expanded(flex: 1, child: Text('SCORE', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                    Expanded(flex: 2, child: Text('STATUS', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                    Expanded(flex: 2, child: Text('EVALUATOR', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                  ],
                ),
              ),
              ..._evals.map((e) {
                final isPass = e['status'] == 'Passed';
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: crm.border.withValues(alpha: 0.5))),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          e['candidate'] as String,
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13, color: crm.textPrimary),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e['test'] as String, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
                            Text(e['remarks'] as String, style: TextStyle(fontSize: 11, color: crm.textSecondary)),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text('${e['score']}%', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: isPass ? const Color(0xFF059669) : const Color(0xFFDC2626))),
                      ),
                      Expanded(
                        flex: 2,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: (isPass ? const Color(0xFF059669) : const Color(0xFFDC2626)).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              e['status'] as String,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isPass ? const Color(0xFF059669) : const Color(0xFFDC2626),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text('${e['evaluatedBy']}\n${e['date']}', style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  void _showRecordScoreDialog(BuildContext context, CrmTheme crm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Record Assessment Score'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(decoration: InputDecoration(labelText: 'Trainee Name')),
            SizedBox(height: 10),
            TextField(decoration: InputDecoration(labelText: 'Assessment Test Name')),
            SizedBox(height: 10),
            TextField(decoration: InputDecoration(labelText: 'Score Percentage (0-100)')),
            SizedBox(height: 10),
            TextField(decoration: InputDecoration(labelText: 'Remarks / Observations')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Save Score')),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 4. QUALITY INDEX TAB
// ══════════════════════════════════════════════════════════════════════════════

class QualityIndexTab extends StatelessWidget {
  final CrmTheme crm;

  const QualityIndexTab({super.key, required this.crm});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Overall KPI Score Banner
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: crm.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: crm.border),
            boxShadow: hrCardShadow(),
          ),
          child: Row(
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: crm.primary.withValues(alpha: 0.12),
                  border: Border.all(color: crm.primary, width: 3),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '94%',
                        style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w900, color: crm.primary),
                      ),
                      Text('INDEX', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: crm.textSecondary)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Academy & Studio Quality Index',
                      style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: crm.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Calculated continuously across practical evaluations (40%), tool sanitization audits (30%), punctuality (20%) and client shadow feedback (10%).',
                      style: TextStyle(fontSize: 12.5, color: crm.textSecondary, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Pillar Gauges Grid
        Row(
          children: [
            Expanded(child: _QualityMetricPill(crm: crm, label: 'Practical Artistry', pct: 96, icon: Icons.brush_outlined)),
            const SizedBox(width: 12),
            Expanded(child: _QualityMetricPill(crm: crm, label: 'Kit Sanitization', pct: 99, icon: Icons.clean_hands_outlined)),
            const SizedBox(width: 12),
            Expanded(child: _QualityMetricPill(crm: crm, label: 'Punctuality Rate', pct: 92, icon: Icons.access_time_outlined)),
            const SizedBox(width: 12),
            Expanded(child: _QualityMetricPill(crm: crm, label: 'Client Feedback', pct: 95, icon: Icons.sentiment_very_satisfied_outlined)),
          ],
        ),
        const SizedBox(height: 20),

        // Readiness Roster
        Text(
          'Trainee Studio Deployment Readiness',
          style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700, color: crm.textPrimary),
        ),
        const SizedBox(height: 10),
        ListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _ReadinessRow(crm: crm, name: 'Kavya S. Nair', role: 'Bridal Artist', qi: 94, readiness: 'Ready for Live Bookings'),
            _ReadinessRow(crm: crm, name: 'Ananya Krishna', role: 'Hair Stylist', qi: 91, readiness: 'Ready for Live Bookings'),
            _ReadinessRow(crm: crm, name: 'Meera Pillai', role: 'Saree Draper', qi: 86, readiness: 'Supervised Shadow Only'),
            _ReadinessRow(crm: crm, name: 'Sanjay Varma', role: 'Photo & Lighting Assis.', qi: 76, readiness: 'In Intensive Academy Training'),
          ],
        ),
      ],
    );
  }
}

class _QualityMetricPill extends StatelessWidget {
  final CrmTheme crm;
  final String label;
  final int pct;
  final IconData icon;

  const _QualityMetricPill({required this.crm, required this.label, required this.pct, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: crm.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 18, color: crm.primary),
              Text('$pct%', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 14, color: crm.primary)),
            ],
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: crm.textPrimary)),
        ],
      ),
    );
  }
}

class _ReadinessRow extends StatelessWidget {
  final CrmTheme crm;
  final String name;
  final String role;
  final int qi;
  final String readiness;

  const _ReadinessRow({
    required this.crm,
    required this.name,
    required this.role,
    required this.qi,
    required this.readiness,
  });

  @override
  Widget build(BuildContext context) {
    final isReady = readiness.contains('Live');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: crm.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13, color: crm.textPrimary),
            ),
          ),
          Expanded(
            child: Text(role, style: TextStyle(fontSize: 12, color: crm.textSecondary)),
          ),
          Expanded(
            child: Text('QI: $qi%', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: crm.primary)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: (isReady ? const Color(0xFF059669) : const Color(0xFFD97706)).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              readiness,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isReady ? const Color(0xFF059669) : const Color(0xFFD97706),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 5. GALP & AMO BUNDLE TAB
// ══════════════════════════════════════════════════════════════════════════════

class GalpAmoBundleTab extends StatelessWidget {
  final CrmTheme crm;
  final bool canManage;

  const GalpAmoBundleTab({super.key, required this.crm, required this.canManage});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Specialized Certification & Artistry Bundles',
          style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: crm.textPrimary),
        ),
        Text('Curated mastery curriculums for Team N Artists and Studio Operations Personnel', style: TextStyle(fontSize: 12, color: crm.textSecondary)),
        const SizedBox(height: 18),

        // GALP Card
        _BundleCard(
          crm: crm,
          badgeTitle: 'GALP BUNDLE',
          badgeColor: const Color(0xFF831843),
          programTitle: 'Grooming & Artistry Leadership Program (GALP)',
          duration: '6-Week Intensive Track',
          enrolledCount: 8,
          graduatedCount: 14,
          modules: const [
            'Module 1: Advanced HD Base, Contouring & Pigmentation Correction',
            'Module 2: Eye Architecture (Smokey, Cut-Crease & South Indian Bridal)',
            'Module 3: Airbrush Mastery, Needle Tuning & Speed Application',
            'Module 4: Client Consultation, Crisis Handling & Signature Styling',
          ],
          description: 'The premier artistry curriculum turning raw talent into signature bridal artists qualified for luxury assignments.',
        ),
        const SizedBox(height: 18),

        // AMO Card
        _BundleCard(
          crm: crm,
          badgeTitle: 'AMO BUNDLE',
          badgeColor: const Color(0xFF0284C7),
          programTitle: 'Advanced Makeover Operations (AMO)',
          duration: '4-Week Executive Track',
          enrolledCount: 5,
          graduatedCount: 9,
          modules: const [
            'Module 1: High-Stress Wedding Day Timeline Coordination',
            'Module 2: Studio & Mobile Vanity Kit Logistics & Sanitation Audit',
            'Module 3: Rapid Pleating, Box Draping & Emergency Touchup Kits',
            'Module 4: Client Relationship Management & CRM Review Handling',
          ],
          description: 'Comprehensive operations and logistics bundle certifying personnel in on-time delivery, emergency response, and client satisfaction.',
        ),
      ],
    );
  }
}

class _BundleCard extends StatelessWidget {
  final CrmTheme crm;
  final String badgeTitle;
  final Color badgeColor;
  final String programTitle;
  final String duration;
  final int enrolledCount;
  final int graduatedCount;
  final List<String> modules;
  final String description;

  const _BundleCard({
    required this.crm,
    required this.badgeTitle,
    required this.badgeColor,
    required this.programTitle,
    required this.duration,
    required this.enrolledCount,
    required this.graduatedCount,
    required this.modules,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: crm.border),
        boxShadow: hrCardShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  badgeTitle,
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: badgeColor, letterSpacing: 0.8),
                ),
              ),
              const SizedBox(width: 10),
              Text(duration, style: TextStyle(fontSize: 12, color: crm.textSecondary)),
              const Spacer(),
              Text('$enrolledCount Active Enrolled • $graduatedCount Certified', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            programTitle,
            style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: crm.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(fontSize: 12.5, color: crm.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: crm.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: crm.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CORE MODULES IN THIS BUNDLE:', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: crm.textSecondary, letterSpacing: 0.5)),
                const SizedBox(height: 8),
                ...modules.map((m) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF059669)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(m, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
                    ],
                  ),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
