import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/hr_shared/hr_ui.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/auth/access_control.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/features/hr_engagement/data/announcement_models.dart';
import 'package:nizan_crm/features/hr_engagement/service/engagement_service.dart';
import 'package:nizan_crm/services/employee_service.dart';
import 'package:nizan_crm/features/hr_engagement/presentation/widgets/celebration_popup_dialog.dart';

String _fmt(DateTime? d) {
  if (d == null) return '';
  const m = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day.toString().padLeft(2, '0')} ${m[d.month]} ${d.year}';
}

String _dayMonth(DateTime? d) {
  if (d == null) return '';
  const m = ['', 'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
  return '${m[d.month]}\n${d.day}';
}

IconData _iconFor(String c) {
  switch (c) {
    case 'event':
      return Icons.event_available_rounded;
    case 'celebration':
      return Icons.celebration_rounded;
    case 'policy':
      return Icons.policy_rounded;
    default:
      return Icons.campaign_rounded;
  }
}

Color _badgeColorFor(String c, CrmTheme crm) {
  switch (c) {
    case 'event':
      return const Color(0xFF0D9488); // Teal
    case 'celebration':
      return const Color(0xFFC9A66B); // Gold
    case 'policy':
      return const Color(0xFF4F46E5); // Indigo
    default:
      return const Color(0xFF601A29); // Maroon
  }
}

/// HR Engagement & Internal Events — SRS §3.6 compliance.
/// Features company announcements, internal events calendar/feed, celebration
/// milestones (birthdays & work anniversaries), policy notices, and department filters.
class HrEngagementScreen extends ConsumerStatefulWidget {
  const HrEngagementScreen({super.key});

  @override
  ConsumerState<HrEngagementScreen> createState() => _HrEngagementScreenState();
}

class _HrEngagementScreenState extends ConsumerState<HrEngagementScreen> {
  String _selectedTab = 'all'; // 'all', 'announcement', 'event', 'celebration', 'policy'
  String _searchQuery = '';
  bool _hasCheckedCelebrationPopup = false;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final access = Access.of(ref.watch(authSessionProvider));
    final canPost = access.isFullAccess ||
        access.isDepartmentHead ||
        access.has('engagement', false) ||
        access.has('staff', false);
    final feedAsync = ref.watch(announcementsProvider);
    final employeesAsync = ref.watch(employeesProvider);

    // Compute upcoming employee celebrations (Birthdays & Work Anniversaries within 7 days)
    final upcomingMilestones = employeesAsync.maybeWhen(
      data: (staff) => findUpcomingMilestones(staff, windowDays: 7),
      orElse: () => const <CelebrationMilestone>[],
    );

    // Auto-trigger the celebration animation popup once per screen session if any event is upcoming within 7 days
    if (!_hasCheckedCelebrationPopup && upcomingMilestones.isNotEmpty) {
      _hasCheckedCelebrationPopup = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          CelebrationPopupDialog.show(
            context,
            milestones: upcomingMilestones,
            onWish: (milestone) {
              _edit(
                context,
                ref,
                null,
                initialCategory: 'celebration',
                initialTitle: milestone.type == MilestoneType.birthday
                    ? '🎉 Happy Birthday, ${milestone.employee.name}!'
                    : '🏆 Happy ${milestone.yearsCompleted} Year Work Anniversary, ${milestone.employee.name}!',
                initialBody: milestone.celebrationMessage,
                initialEventDate: milestone.eventDate,
              );
            },
          );
        }
      });
    }

    return Scaffold(
      backgroundColor: crm.background,
      floatingActionButton: canPost
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFF601A29),
              foregroundColor: const Color(0xFFF5F3EF),
              elevation: 4,
              onPressed: () => _edit(context, ref, null),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Post Update', style: TextStyle(fontWeight: FontWeight.w700)),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(announcementsProvider);
          ref.invalidate(employeesProvider);
        },
        child: feedAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [
            AppErrorView(error: e, onRetry: () => ref.invalidate(announcementsProvider))
          ]),
          data: (allPosts) {
            // Apply category filter
            var filtered = allPosts;
            if (_selectedTab != 'all') {
              filtered = filtered.where((p) => p.category == _selectedTab).toList();
            }
            if (_searchQuery.trim().isNotEmpty) {
              final q = _searchQuery.toLowerCase();
              filtered = filtered.where((p) =>
                  p.title.toLowerCase().contains(q) ||
                  p.body.toLowerCase().contains(q) ||
                  p.postedByName.toLowerCase().contains(q)).toList();
            }

            // Stats metrics
            final eventCount = allPosts.where((p) => p.category == 'event').length;
            final celebrationCount = allPosts.where((p) => p.category == 'celebration').length;
            final policyCount = allPosts.where((p) => p.category == 'policy').length;

            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 90),
              children: [
                // Header Title
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Company Engagement',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: crm.textPrimary,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Announcements, team events, milestones & workplace notices',
                            style: TextStyle(fontSize: 12.5, color: crm.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        if (upcomingMilestones.isNotEmpty) ...[
                          FilledButton.tonalIcon(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFC9A66B).withValues(alpha: 0.18),
                              foregroundColor: const Color(0xFF601A29),
                              side: const BorderSide(color: Color(0xFFC9A66B), width: 1.2),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            onPressed: () => CelebrationPopupDialog.show(
                              context,
                              milestones: upcomingMilestones,
                              onWish: (milestone) {
                                _edit(
                                  context,
                                  ref,
                                  null,
                                  initialCategory: 'celebration',
                                  initialTitle: milestone.type == MilestoneType.birthday
                                      ? '🎉 Happy Birthday, ${milestone.employee.name}!'
                                      : '🏆 Happy ${milestone.yearsCompleted} Year Work Anniversary, ${milestone.employee.name}!',
                                  initialBody: milestone.celebrationMessage,
                                  initialEventDate: milestone.eventDate,
                                );
                              },
                            ),
                            icon: const Icon(Icons.celebration_rounded, size: 18, color: Color(0xFF601A29)),
                            label: Text(
                              'Celebrations (${upcomingMilestones.length})',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (canPost)
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF601A29),
                              foregroundColor: const Color(0xFFF5F3EF),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            ),
                            onPressed: () => _edit(context, ref, null),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('New Post', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // KPI Stat Cards Row
                LayoutBuilder(builder: (ctx, constraints) {
                  final isNarrow = constraints.maxWidth < 640;
                  final cards = [
                    _kpiCard(crm, 'Total Posts', '${allPosts.length}', Icons.dynamic_feed_rounded, const Color(0xFF601A29)),
                    _kpiCard(crm, 'Events & Activities', '$eventCount', Icons.event_available_rounded, const Color(0xFF0D9488)),
                    _kpiCard(crm, 'Celebrations', '$celebrationCount', Icons.celebration_rounded, const Color(0xFFC9A66B)),
                    _kpiCard(crm, 'Policy Notices', '$policyCount', Icons.policy_rounded, const Color(0xFF4F46E5)),
                  ];
                  if (isNarrow) {
                    return Wrap(spacing: 10, runSpacing: 10, children: cards);
                  }
                  return Row(
                    children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 5), child: c))).toList(),
                  );
                }),
                const SizedBox(height: 18),

                // Upcoming Celebrations Spotlight (Real computed milestones within 7 days)
                if (upcomingMilestones.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF601A29).withValues(alpha: 0.08),
                          const Color(0xFFC9A66B).withValues(alpha: 0.16),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFC9A66B).withValues(alpha: 0.45), width: 1.2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF601A29),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.celebration_rounded, size: 16, color: Color(0xFFC9A66B)),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'This Week\'s Team Celebrations & Milestones',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF601A29),
                                  ),
                                ),
                              ],
                            ),
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF601A29),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              ),
                              onPressed: () => CelebrationPopupDialog.show(
                                context,
                                milestones: upcomingMilestones,
                                onWish: (milestone) {
                                  _edit(
                                    context,
                                    ref,
                                    null,
                                    initialCategory: 'celebration',
                                    initialTitle: milestone.type == MilestoneType.birthday
                                        ? '🎉 Happy Birthday, ${milestone.employee.name}!'
                                        : '🏆 Happy ${milestone.yearsCompleted} Year Work Anniversary, ${milestone.employee.name}!',
                                    initialBody: milestone.celebrationMessage,
                                    initialEventDate: milestone.eventDate,
                                  );
                                },
                              ),
                              icon: const Icon(Icons.fullscreen_rounded, size: 16),
                              label: const Text('Open Celebration View', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 10,
                          children: upcomingMilestones.map((m) {
                            return InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () => CelebrationPopupDialog.show(
                                context,
                                milestones: [m],
                                onWish: (milestone) {
                                  _edit(
                                    context,
                                    ref,
                                    null,
                                    initialCategory: 'celebration',
                                    initialTitle: milestone.type == MilestoneType.birthday
                                        ? '🎉 Happy Birthday, ${milestone.employee.name}!'
                                        : '🏆 Happy ${milestone.yearsCompleted} Year Work Anniversary, ${milestone.employee.name}!',
                                    initialBody: milestone.celebrationMessage,
                                    initialEventDate: milestone.eventDate,
                                  );
                                },
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: m.isToday ? const Color(0xFFC9A66B) : crm.border,
                                    width: m.isToday ? 1.5 : 1.0,
                                  ),
                                  boxShadow: hrCardShadow(),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircleAvatar(
                                      radius: 15,
                                      backgroundColor: const Color(0xFF601A29).withValues(alpha: 0.12),
                                      backgroundImage: m.employee.profileImage.isNotEmpty
                                          ? NetworkImage(m.employee.profileImage)
                                          : null,
                                      child: m.employee.profileImage.isEmpty
                                          ? Text(
                                              m.employee.name.isNotEmpty ? m.employee.name[0].toUpperCase() : '?',
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF601A29)),
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 9),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          m.employee.name,
                                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: crm.textPrimary),
                                        ),
                                        Text(
                                          m.type == MilestoneType.birthday ? 'Birthday' : '${m.yearsCompleted}y Anniversary',
                                          style: TextStyle(fontSize: 10.5, color: crm.textSecondary, fontWeight: FontWeight.w500),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: m.isToday
                                            ? const Color(0xFF1E7E34)
                                            : const Color(0xFFC9A66B).withValues(alpha: 0.22),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        m.isToday ? 'TODAY! 🎉' : m.countdownText,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: m.isToday ? Colors.white : const Color(0xFF601A29),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),

                // Category Lens Bar + Search Field
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: hrCardDecoration(crm),
                  child: LayoutBuilder(builder: (ctx, constraints) {
                    final isSmall = constraints.maxWidth < 680;
                    final tabs = SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _lensItem('all', 'All Updates', Icons.apps_rounded, crm),
                          _lensItem('announcement', 'Announcements', Icons.campaign_rounded, crm),
                          _lensItem('event', 'Events', Icons.event_available_rounded, crm),
                          _lensItem('celebration', 'Celebrations', Icons.celebration_rounded, crm),
                          _lensItem('policy', 'Policies', Icons.policy_rounded, crm),
                        ],
                      ),
                    );

                    final searchBox = SizedBox(
                      width: isSmall ? double.infinity : 240,
                      height: 38,
                      child: TextField(
                        onChanged: (v) => setState(() => _searchQuery = v),
                        decoration: InputDecoration(
                          hintText: 'Search feed...',
                          hintStyle: TextStyle(fontSize: 12, color: crm.textSecondary),
                          prefixIcon: const Icon(Icons.search_rounded, size: 16),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: crm.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: crm.border),
                          ),
                        ),
                      ),
                    );

                    if (isSmall) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          tabs,
                          const SizedBox(height: 8),
                          searchBox,
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: tabs),
                        searchBox,
                      ],
                    );
                  }),
                ),
                const SizedBox(height: 16),

                // Posts Feed
                if (filtered.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(48),
                    decoration: hrCardDecoration(crm),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inbox_rounded, size: 48, color: crm.textSecondary.withValues(alpha: 0.4)),
                          const SizedBox(height: 12),
                          Text(
                            _selectedTab == 'all'
                                ? 'No announcements posted yet.'
                                : 'No ${_selectedTab}s found.',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: crm.textSecondary),
                          ),
                          if (canPost) ...[
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () => _edit(context, ref, null),
                              icon: const Icon(Icons.add_rounded, size: 16),
                              label: const Text('Post the first update'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  )
                else
                  ...filtered.map((post) => _postCard(context, ref, post, canPost, crm)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _lensItem(String key, String label, IconData icon, CrmTheme crm) {
    final selected = _selectedTab == key;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: () => setState(() => _selectedTab = key),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF601A29) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: selected ? const Color(0xFFC9A66B) : crm.textSecondary),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? Colors.white : crm.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kpiCard(CrmTheme crm, String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: hrCardDecoration(crm),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: crm.textPrimary)),
                Text(label, style: TextStyle(fontSize: 11, color: crm.textSecondary, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _postCard(BuildContext context, WidgetRef ref, Announcement a, bool canPost, CrmTheme crm) {
    final hasDate = a.eventDate != null;
    final badgeColor = _badgeColorFor(a.category, crm);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: hrCardDecoration(
        crm,
        borderColor: a.pinned ? const Color(0xFFC9A66B) : crm.border,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Category tag, audience, pinned pill, actions
            Row(
              children: [
                // Category Chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_iconFor(a.category), size: 13, color: badgeColor),
                      const SizedBox(width: 5),
                      Text(
                        announcementCategoryLabel(a.category).toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: badgeColor,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
                if (a.audience.isNotEmpty && a.audience != 'all') ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: crm.surface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: crm.border),
                    ),
                    child: Text(
                      'Dept: ${a.audience}',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: crm.textSecondary),
                    ),
                  ),
                ],
                if (a.pinned) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF601A29),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.push_pin_rounded, size: 11, color: Color(0xFFC9A66B)),
                        SizedBox(width: 4),
                        Text('PINNED', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFFF5F3EF))),
                      ],
                    ),
                  ),
                ],
                const Spacer(),
                if (canPost)
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_horiz_rounded, size: 20, color: crm.textSecondary),
                    onSelected: (v) {
                      if (v == 'edit') {
                        _edit(context, ref, a);
                      } else if (v == 'delete') {
                        _delete(context, ref, a);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 16),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, size: 16, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Content Row with optional Event Date Box
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasDate) ...[
                  Container(
                    width: 52,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _dayMonth(a.eventDate).split('\n')[0],
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: badgeColor),
                        ),
                        Text(
                          _dayMonth(a.eventDate).split('\n')[1],
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: badgeColor),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: crm.textPrimary,
                        ),
                      ),
                      if (a.body.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          a.body,
                          style: TextStyle(
                            fontSize: 13.5,
                            height: 1.45,
                            color: crm.textPrimary.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Footer metadata
            Divider(height: 1, color: crm.border.withValues(alpha: 0.5)),
            const SizedBox(height: 8),
            Row(
              children: [
                if (a.postedByName.isNotEmpty) ...[
                  Icon(Icons.person_outline_rounded, size: 13, color: crm.textSecondary),
                  const SizedBox(width: 4),
                  Text(a.postedByName, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: crm.textSecondary)),
                  const SizedBox(width: 12),
                ],
                if (a.createdAt != null) ...[
                  Icon(Icons.access_time_rounded, size: 13, color: crm.textSecondary),
                  const SizedBox(width: 4),
                  Text(_fmt(a.createdAt), style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
                ],
                if (hasDate) ...[
                  const Spacer(),
                  Icon(Icons.event_rounded, size: 13, color: badgeColor),
                  const SizedBox(width: 4),
                  Text(
                    'Event: ${_fmt(a.eventDate)}',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: badgeColor),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Announcement a) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete update'),
        content: Text('Are you sure you want to delete "${a.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ref.read(engagementServiceProvider).delete(a.id);
      ref.invalidate(announcementsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Update deleted')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
      }
    }
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    Announcement? existing, {
    String? initialCategory,
    String? initialTitle,
    String? initialBody,
    DateTime? initialEventDate,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _PostEditorDialog(
        existing: existing,
        initialCategory: initialCategory,
        initialTitle: initialTitle,
        initialBody: initialBody,
        initialEventDate: initialEventDate,
      ),
    );
    if (ok == true) ref.invalidate(announcementsProvider);
  }
}

class _PostEditorDialog extends ConsumerStatefulWidget {
  const _PostEditorDialog({
    this.existing,
    this.initialCategory,
    this.initialTitle,
    this.initialBody,
    this.initialEventDate,
  });
  final Announcement? existing;
  final String? initialCategory;
  final String? initialTitle;
  final String? initialBody;
  final DateTime? initialEventDate;

  @override
  ConsumerState<_PostEditorDialog> createState() => _PostEditorDialogState();
}

class _PostEditorDialogState extends ConsumerState<_PostEditorDialog> {
  late final TextEditingController _title;
  late final TextEditingController _body;
  late final TextEditingController _audience;
  String _category = 'announcement';
  DateTime? _eventDate;
  bool _pinned = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? widget.initialTitle ?? '');
    _body = TextEditingController(text: e?.body ?? widget.initialBody ?? '');
    _audience = TextEditingController(text: e?.audience == 'all' ? '' : (e?.audience ?? ''));
    _category = e?.category ?? widget.initialCategory ?? 'announcement';
    _eventDate = e?.eventDate ?? widget.initialEventDate;
    _pinned = e?.pinned ?? false;
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _audience.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Title is required')));
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(engagementServiceProvider).save({
        'title': _title.text.trim(),
        'body': _body.text.trim(),
        'category': _category,
        'audience': _audience.text.trim().isEmpty ? 'all' : _audience.text.trim(),
        'pinned': _pinned,
        if (_eventDate != null) 'eventDate': _eventDate!.toIso8601String(),
      }, id: widget.existing?.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.existing == null ? 'New Post' : 'Edit Post',
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _title,
                decoration: const InputDecoration(
                  labelText: 'Title *',
                  hintText: 'e.g. Q4 Town Hall / Welcome our new team members',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _category,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Category'),
                items: kAnnouncementCategories.map((c) {
                  return DropdownMenuItem(
                    value: c,
                    child: Row(
                      children: [
                        Icon(_iconFor(c), size: 16),
                        const SizedBox(width: 8),
                        Text(announcementCategoryLabel(c)),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (v) => setState(() => _category = v ?? 'announcement'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _audience,
                decoration: const InputDecoration(
                  labelText: 'Target Department (optional)',
                  hintText: 'Leave empty for all company',
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final now = DateTime.now();
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _eventDate ?? now,
                    firstDate: DateTime(now.year - 1),
                    lastDate: DateTime(now.year + 2),
                  );
                  if (d != null) setState(() => _eventDate = d);
                },
                icon: const Icon(Icons.event_outlined, size: 18),
                label: Text(_eventDate == null ? 'Set event/celebration date' : 'Date: ${_fmt(_eventDate)}'),
              ),
              if (_eventDate != null)
                TextButton(
                  onPressed: () => setState(() => _eventDate = null),
                  child: const Text('Clear date', style: TextStyle(fontSize: 12, color: Colors.red)),
                ),
              const SizedBox(height: 10),
              TextField(
                controller: _body,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Details / Description',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _pinned,
                title: const Text('Pin to top of feed', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                subtitle: const Text('Featured announcement with gold badge', style: TextStyle(fontSize: 11)),
                onChanged: (v) => setState(() => _pinned = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF601A29),
            foregroundColor: const Color(0xFFF5F3EF),
          ),
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Publish'),
        ),
      ],
    );
  }
}
