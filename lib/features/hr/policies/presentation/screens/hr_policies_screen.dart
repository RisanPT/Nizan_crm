import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/features/hr/shared/hr_ui.dart';
import '../../data/policy_models.dart';
import '../../service/policy_service.dart';

class HrPoliciesScreen extends ConsumerStatefulWidget {
  const HrPoliciesScreen({super.key});

  @override
  ConsumerState<HrPoliciesScreen> createState() => _HrPoliciesScreenState();
}

class _HrPoliciesScreenState extends ConsumerState<HrPoliciesScreen> {
  String _selectedCategory = 'All';
  String _searchQuery = '';

  static const _categories = [
    'All',
    'Company Policy',
    'HR Policy',
    'Studio & Hygiene',
    'Financial & Travel',
  ];

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final session = ref.watch(authSessionProvider);
    final currentUserId = session?.userId ?? 'emp-current';
    final policies = ref.watch(hrPoliciesProvider);

    final filtered = policies.where((p) {
      if (_selectedCategory != 'All' && p.category != _selectedCategory) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        return p.title.toLowerCase().contains(q) ||
            p.summary.toLowerCase().contains(q) ||
            p.category.toLowerCase().contains(q);
      }
      return true;
    }).toList();

    final ackCount = policies.where((p) => p.isAcknowledged(currentUserId)).length;
    final ackPercent = policies.isEmpty ? 0 : ((ackCount / policies.length) * 100).toInt();

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
                        'GOVERNANCE & WORKPLACE',
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 0.9,
                          fontWeight: FontWeight.w700,
                          color: crm.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Company & HR Policies',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: crm.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Official workplace policies, studio hygiene manuals and digital employee sign-offs',
                        style: TextStyle(fontSize: 13, color: crm.textSecondary),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: crm.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: crm.border),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.verified_user_outlined, size: 18, color: crm.primary),
                      const SizedBox(width: 8),
                      Text(
                        '$ackPercent% Signed',
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

            // ── Search & Filter Bar ──────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: crm.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: crm.border),
              ),
              child: Column(
                children: [
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search policies by title or keyword...',
                      hintStyle: TextStyle(fontSize: 13, color: crm.textSecondary),
                      prefixIcon: Icon(Icons.search_rounded, size: 20, color: crm.primary),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      filled: true,
                      fillColor: crm.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: crm.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: crm.border),
                      ),
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _categories.map((cat) {
                        final isSel = _selectedCategory == cat;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(cat),
                            selected: isSel,
                            selectedColor: crm.primary.withValues(alpha: 0.15),
                            backgroundColor: crm.background,
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                              color: isSel ? crm.primary : crm.textSecondary,
                            ),
                            side: BorderSide(
                              color: isSel ? crm.primary : crm.border,
                            ),
                            onSelected: (_) => setState(() => _selectedCategory = cat),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Policy Cards Grid ─────────────────────────────────
            if (filtered.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: crm.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: crm.border),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.search_off_rounded, size: 44, color: crm.textSecondary.withValues(alpha: 0.5)),
                      const SizedBox(height: 10),
                      Text(
                        'No policies found matching your search',
                        style: TextStyle(color: crm.textSecondary, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              )
            else
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
                      childAspectRatio: isWide ? 2.3 : 1.9,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final p = filtered[i];
                      final isAck = p.isAcknowledged(currentUserId);
                      return _PolicyCard(
                        policy: p,
                        isAcknowledged: isAck,
                        crm: crm,
                        onTap: () => _openPolicyViewer(context, p, isAck, currentUserId),
                      );
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  void _openPolicyViewer(BuildContext context, HrPolicy p, bool isAck, String currentUserId) {
    showDialog(
      context: context,
      builder: (ctx) => _PolicyViewerDialog(
        policy: p,
        isAcknowledged: isAck,
        onAcknowledge: () {
          ref.read(hrPoliciesProvider.notifier).acknowledgePolicy(p.id, currentUserId);
          Navigator.pop(ctx);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully acknowledged "${p.title}"'),
              backgroundColor: const Color(0xFF059669),
            ),
          );
        },
      ),
    );
  }
}

class _PolicyCard extends StatelessWidget {
  final HrPolicy policy;
  final bool isAcknowledged;
  final CrmTheme crm;
  final VoidCallback onTap;

  const _PolicyCard({
    required this.policy,
    required this.isAcknowledged,
    required this.crm,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: crm.border),
        boxShadow: hrCardShadow(),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: crm.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.description_outlined, size: 20, color: crm.primary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            policy.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: crm.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                '${policy.category} • ${policy.version}',
                                style: TextStyle(fontSize: 11, color: crm.textSecondary),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (isAcknowledged)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF059669).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF059669).withValues(alpha: 0.35)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_outline, size: 12, color: Color(0xFF059669)),
                            SizedBox(width: 4),
                            Text(
                              'Signed',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF059669),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD97706).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFD97706).withValues(alpha: 0.35)),
                        ),
                        child: const Text(
                          'Pending Sign',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFD97706),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Text(
                    policy.summary,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: crm.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Effective: ${policy.effectiveDate.day}/${policy.effectiveDate.month}/${policy.effectiveDate.year}',
                      style: TextStyle(fontSize: 11, color: crm.textSecondary.withValues(alpha: 0.7)),
                    ),
                    Row(
                      children: [
                        Text(
                          'Read Document',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: crm.primary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded, size: 13, color: crm.primary),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PolicyViewerDialog extends StatelessWidget {
  final HrPolicy policy;
  final bool isAcknowledged;
  final VoidCallback onAcknowledge;

  const _PolicyViewerDialog({
    required this.policy,
    required this.isAcknowledged,
    required this.onAcknowledge,
  });

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 680),
          child: Container(
            decoration: BoxDecoration(
              color: crm.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: crm.border),
              boxShadow: hrCardShadow(elevated: true),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Modal Header
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
                  decoration: BoxDecoration(
                    color: crm.background,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                    border: Border(bottom: BorderSide(color: crm.border)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: crm.primary.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.menu_book_outlined, size: 20, color: crm.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              policy.title,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: crm.textPrimary,
                              ),
                            ),
                            Text(
                              '${policy.category} • Version ${policy.version}',
                              style: TextStyle(fontSize: 11.5, color: crm.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                // Modal Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(22),
                    child: SelectableText(
                      policy.content,
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        height: 1.6,
                        color: crm.textPrimary,
                      ),
                    ),
                  ),
                ),

                // Modal Footer
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: crm.background,
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
                    border: Border(top: BorderSide(color: crm.border)),
                  ),
                  child: Row(
                    children: [
                      if (isAcknowledged)
                        const Row(
                          children: [
                            Icon(Icons.verified_rounded, size: 16, color: Color(0xFF059669)),
                            SizedBox(width: 6),
                            Text(
                              'You acknowledged this policy.',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF059669),
                              ),
                            ),
                          ],
                        )
                      else
                        Expanded(
                          child: Text(
                            'Please review carefully before confirming your digital acknowledgment.',
                            style: TextStyle(fontSize: 11.5, color: crm.textSecondary),
                          ),
                        ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                      if (!isAcknowledged) ...[
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: onAcknowledge,
                          icon: const Icon(Icons.draw_outlined, size: 16),
                          label: const Text('Acknowledge & Sign'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: crm.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
