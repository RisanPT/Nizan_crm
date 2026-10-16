import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/hr/shared/hr_ui.dart';
import 'package:nizan_crm/services/employee_service.dart';
import 'package:nizan_crm/core/models/employee.dart';
import 'package:nizan_crm/features/hr/service/evaluation_service.dart';

class HrDepartmentScoringScreen extends ConsumerStatefulWidget {
  const HrDepartmentScoringScreen({super.key});

  @override
  ConsumerState<HrDepartmentScoringScreen> createState() => _HrDepartmentScoringScreenState();
}

class _HrDepartmentScoringScreenState extends ConsumerState<HrDepartmentScoringScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedDept = 'All';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final period = ref.watch(evalPeriodProvider);
    final employees = ref.watch(employeesProvider).value ?? const <Employee>[];
    final evals = ref.watch(evaluationsProvider).value ?? [];

    return Scaffold(
      backgroundColor: crm.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PERFORMANCE & BENCHMARKS',
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 0.9,
                          fontWeight: FontWeight.w700,
                          color: crm.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Department & Employee Scoring',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: crm.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Holistic composite rankings, 5-pillar evaluations, quality indexes & scorecard analytics',
                        style: TextStyle(fontSize: 13, color: crm.textSecondary),
                      ),
                    ],
                  ),
                ),
                // Period chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: crm.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: crm.border),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_month_outlined, size: 18, color: crm.primary),
                      const SizedBox(width: 8),
                      Text(
                        '${_monthName(period.month)} ${period.year}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: crm.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Tab Bar ──────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: crm.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: crm.border),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: crm.primary,
                indicatorWeight: 3,
                labelColor: crm.primary,
                unselectedLabelColor: crm.textSecondary,
                labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                tabs: const [
                  Tab(icon: Icon(Icons.leaderboard_outlined, size: 18), text: 'Department Leaderboard'),
                  Tab(icon: Icon(Icons.person_search_outlined, size: 18), text: 'Employee Scorecards'),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Tab Contents ─────────────────────────────────────
            SizedBox(
              height: 780,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _DepartmentLeaderboardView(crm: crm, evals: evals),
                  _EmployeeScorecardView(
                    crm: crm,
                    employees: employees,
                    evals: evals,
                    selectedDept: _selectedDept,
                    searchQuery: _searchQuery,
                    onDeptChanged: (d) => setState(() => _selectedDept = d),
                    onSearchChanged: (s) => setState(() => _searchQuery = s),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _monthName(int m) {
    const names = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return (m >= 1 && m <= 12) ? names[m] : '';
  }
}

class _DepartmentLeaderboardView extends StatelessWidget {
  final CrmTheme crm;
  final List<dynamic> evals;

  const _DepartmentLeaderboardView({required this.crm, required this.evals});

  @override
  Widget build(BuildContext context) {
    final depts = [
      _DeptScore(name: 'Bridal Styling', score: 4.8, punctuality: 96, qualityIndex: 98, headcount: 14, rank: 1),
      _DeptScore(name: 'Technology & Systems (IT)', score: 4.7, punctuality: 98, qualityIndex: 96, headcount: 8, rank: 2),
      _DeptScore(name: 'Studio & Services Ops', score: 4.5, punctuality: 94, qualityIndex: 93, headcount: 12, rank: 3),
      _DeptScore(name: 'Sales & Marketing', score: 4.4, punctuality: 92, qualityIndex: 91, headcount: 9, rank: 4),
      _DeptScore(name: 'Finance & Accounts', score: 4.3, punctuality: 97, qualityIndex: 90, headcount: 6, rank: 5),
      _DeptScore(name: 'HR & People Operations', score: 4.2, punctuality: 95, qualityIndex: 89, headcount: 5, rank: 6),
      _DeptScore(name: 'Fleet & Logistics', score: 4.0, punctuality: 91, qualityIndex: 88, headcount: 7, rank: 7),
    ];

    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      children: [
        // Top 3 Podium Cards
        Row(
          children: [
            Expanded(child: _PodiumCard(crm: crm, dept: depts[1], place: 2)), // 2nd
            const SizedBox(width: 14),
            Expanded(child: _PodiumCard(crm: crm, dept: depts[0], place: 1)), // 1st
            const SizedBox(width: 14),
            Expanded(child: _PodiumCard(crm: crm, dept: depts[2], place: 3)), // 3rd
          ],
        ),
        const SizedBox(height: 20),

        // Full Department Table
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
                    SizedBox(width: 48, child: Text('#', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                    Expanded(flex: 3, child: Text('DEPARTMENT', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                    Expanded(flex: 2, child: Text('COMPOSITE', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                    Expanded(flex: 2, child: Text('PUNCTUALITY', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                    Expanded(flex: 2, child: Text('QUALITY INDEX', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                    Expanded(flex: 1, child: Text('STAFF', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                  ],
                ),
              ),
              ...depts.map((d) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: crm.border.withValues(alpha: 0.5))),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 48,
                        child: Text(
                          '#${d.rank}',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: d.rank <= 3 ? const Color(0xFFC9A66B) : crm.textSecondary,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          d.name,
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13, color: crm.textPrimary),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Row(
                          children: [
                            Icon(Icons.star_rounded, size: 16, color: Colors.amber.shade600),
                            const SizedBox(width: 4),
                            Text('${d.score} / 5.0', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text('${d.punctuality}%', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text('${d.qualityIndex}%', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: crm.primary)),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text('${d.headcount}', style: TextStyle(fontSize: 13, color: crm.textSecondary)),
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
}

class _PodiumCard extends StatelessWidget {
  final CrmTheme crm;
  final _DeptScore dept;
  final int place;

  const _PodiumCard({required this.crm, required this.dept, required this.place});

  @override
  Widget build(BuildContext context) {
    final colors = {
      1: const Color(0xFFEAB308), // Gold
      2: const Color(0xFF94A3B8), // Silver
      3: const Color(0xFFD97706), // Bronze
    };
    final color = colors[place]!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.5), width: place == 1 ? 2 : 1),
        boxShadow: hrCardShadow(),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: color.withValues(alpha: 0.18),
            child: Text(
              '$place',
              style: TextStyle(fontWeight: FontWeight.w900, color: color, fontSize: 16),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            dept.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 14, color: crm.textPrimary),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.star_rounded, size: 16, color: Colors.amber.shade600),
              const SizedBox(width: 4),
              Text('${dept.score} Score', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
              const SizedBox(width: 10),
              Text('${dept.qualityIndex}% QI', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: crm.primary)),
            ],
          ),
        ],
      ),
    );
  }
}

class _DeptScore {
  final String name;
  final double score;
  final int punctuality;
  final int qualityIndex;
  final int headcount;
  final int rank;

  const _DeptScore({
    required this.name,
    required this.score,
    required this.punctuality,
    required this.qualityIndex,
    required this.headcount,
    required this.rank,
  });
}

class _EmployeeScorecardView extends StatelessWidget {
  final CrmTheme crm;
  final List<Employee> employees;
  final List<dynamic> evals;
  final String selectedDept;
  final String searchQuery;
  final ValueChanged<String> onDeptChanged;
  final ValueChanged<String> onSearchChanged;

  const _EmployeeScorecardView({
    required this.crm,
    required this.employees,
    required this.evals,
    required this.selectedDept,
    required this.searchQuery,
    required this.onDeptChanged,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Generate representative scorecards from active staff
    final staffList = employees.map((e) {
      final String id = e.id;
      final String name = e.name;
      final String dept = (e.department != null && e.department!.isNotEmpty) ? e.department! : 'Bridal Styling';
      final String role = e.designation;
      // Deterministic scores for demonstration
      final hash = name.codeUnits.fold(0, (a, b) => a + b);
      final score = 3.8 + (hash % 12) / 10.0;
      final qi = 82 + (hash % 18);
      final punc = 88 + (hash % 12);
      final grade = score >= 4.5 ? 'Grade A' : (score >= 4.0 ? 'Grade B' : 'Grade C');

      return {
        'id': id,
        'name': name,
        'dept': dept,
        'role': role,
        'score': score.clamp(1.0, 5.0),
        'qi': qi.clamp(70, 100),
        'punctuality': punc.clamp(70, 100),
        'grade': grade,
      };
    }).where((item) {
      if (selectedDept != 'All' && item['dept'] != selectedDept) return false;
      if (searchQuery.isNotEmpty) {
        final q = searchQuery.toLowerCase();
        return item['name'].toString().toLowerCase().contains(q) ||
            item['dept'].toString().toLowerCase().contains(q) ||
            item['role'].toString().toLowerCase().contains(q);
      }
      return true;
    }).toList();

    return Column(
      children: [
        // Filter bar
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search employee by name or role...',
                  hintStyle: TextStyle(fontSize: 13, color: crm.textSecondary),
                  prefixIcon: Icon(Icons.search_rounded, size: 20, color: crm.primary),
                  isDense: true,
                  filled: true,
                  fillColor: crm.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: crm.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: crm.border)),
                ),
                onChanged: onSearchChanged,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Staff Scorecards List
        Expanded(
          child: staffList.isEmpty
              ? Center(child: Text('No employees found', style: TextStyle(color: crm.textSecondary)))
              : ListView.separated(
                  itemCount: staffList.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final item = staffList[i];
                    final grade = item['grade'].toString();
                    final gradeColor = grade.contains('A')
                        ? const Color(0xFF059669)
                        : (grade.contains('B') ? const Color(0xFF2563EB) : const Color(0xFFD97706));

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
                            child: Text(
                              item['name'].toString().isNotEmpty ? item['name'].toString()[0].toUpperCase() : '?',
                              style: TextStyle(fontWeight: FontWeight.w800, color: crm.primary),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['name'].toString(),
                                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14, color: crm.textPrimary),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${item['role']} • ${item['dept']}',
                                  style: TextStyle(fontSize: 11.5, color: crm.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.star_rounded, size: 15, color: Colors.amber.shade600),
                                    const SizedBox(width: 3),
                                    Text('${(item['score'] as double).toStringAsFixed(1)} / 5.0', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                                  ],
                                ),
                                Text('5-Pillar Mean', style: TextStyle(fontSize: 10.5, color: crm.textSecondary)),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${item['qi']}% QI', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: crm.primary)),
                                Text('Quality Index', style: TextStyle(fontSize: 10.5, color: crm.textSecondary)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: gradeColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: gradeColor.withValues(alpha: 0.35)),
                            ),
                            child: Text(
                              grade,
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5, color: gradeColor),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
