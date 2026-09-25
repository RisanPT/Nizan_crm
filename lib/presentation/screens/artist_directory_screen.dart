import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/utils/responsive_builder.dart';
import 'package:nizan_crm/core/models/employee.dart';
import 'package:nizan_crm/services/employee_service.dart';
import 'package:nizan_crm/features/bookings/controllers/booking_provider.dart';
import 'package:nizan_crm/features/bookings/data/booking.dart';
import 'package:nizan_crm/features/reviews/services/review_service.dart';

/// Artist Directory — the Artist Head's roster control. Lists every artist with
/// live stats (bookings, active load, client rating) and drills into a single
/// artist's profile. Search + status/type filters.
class ArtistDirectoryScreen extends ConsumerStatefulWidget {
  const ArtistDirectoryScreen({super.key});

  @override
  ConsumerState<ArtistDirectoryScreen> createState() =>
      _ArtistDirectoryScreenState();
}

class _ArtistDirectoryScreenState extends ConsumerState<ArtistDirectoryScreen> {
  final _searchCtrl = TextEditingController();
  String _search = '';
  String _status = 'active'; // active | inactive | all
  String _type = 'all'; // all | in-house | outsource

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);

    final asyncEmployees = ref.watch(employeesProvider);
    final employees = asyncEmployees.value ?? const <Employee>[];
    final bookings = ref.watch(bookingProvider).value ?? const <Booking>[];
    final reviews = ref.watch(reviewAnalyticsProvider).value;

    // Rating lookup by name (perArtist is keyed by artistName).
    final ratingByName = <String, ArtistStat>{};
    for (final s in (reviews?.perArtist ?? const <ArtistStat>[])) {
      ratingByName[s.artistName.trim().toLowerCase()] = s;
    }

    // All artists (any status), then filter.
    var artists = employees.where((e) => e.isArtist).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    if (_status != 'all') {
      artists = artists
          .where((e) => _status == 'active' ? e.isActive : !e.isActive)
          .toList();
    }
    if (_type != 'all') {
      artists = artists.where((e) => e.type == _type).toList();
    }
    if (_search.trim().isNotEmpty) {
      final q = _search.trim().toLowerCase();
      artists = artists
          .where((e) =>
              e.name.toLowerCase().contains(q) ||
              e.phone.toLowerCase().contains(q) ||
              e.specialization.toLowerCase().contains(q) ||
              e.regionName.toLowerCase().contains(q))
          .toList();
    }

    return Scaffold(
      backgroundColor: crm.background,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(employeesProvider);
          ref.invalidate(bookingProvider);
          ref.invalidate(reviewAnalyticsProvider);
        },
        child: ListView(
          padding: EdgeInsets.fromLTRB(
              isMobile ? 14 : 24, 18, isMobile ? 14 : 24, 32),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => context.canPop()
                      ? context.pop()
                      : context.go('/artist-head'),
                  icon: const Icon(Icons.arrow_back),
                ),
                8.wg,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Artists',
                          style: TextStyle(
                              fontSize: isMobile ? 22 : 26,
                              fontWeight: FontWeight.w800,
                              color: crm.textPrimary)),
                      Text('${artists.length} shown · tap an artist to manage',
                          style: TextStyle(
                              fontSize: 12, color: crm.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            16.hg,

            // Search
            TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'Search by name, phone, skill, region…',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                filled: true,
                fillColor: crm.surface,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: crm.border)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: crm.border)),
              ),
            ),
            12.hg,

            // Filters
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _filterChip(crm, 'Active', _status == 'active',
                    () => setState(() => _status = 'active')),
                _filterChip(crm, 'Inactive', _status == 'inactive',
                    () => setState(() => _status = 'inactive')),
                _filterChip(crm, 'All statuses', _status == 'all',
                    () => setState(() => _status = 'all')),
                _dot(crm),
                _filterChip(crm, 'All types', _type == 'all',
                    () => setState(() => _type = 'all')),
                _filterChip(crm, 'In-house', _type == 'in-house',
                    () => setState(() => _type = 'in-house')),
                _filterChip(crm, 'Outsource', _type == 'outsource',
                    () => setState(() => _type = 'outsource')),
              ],
            ),
            18.hg,

            if (artists.isEmpty && asyncEmployees.hasError)
              AppErrorView(
                error: asyncEmployees.error,
                onRetry: () => ref.invalidate(employeesProvider),
              )
            else if (artists.isEmpty && asyncEmployees.isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (artists.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text('No artists match these filters.',
                      style: TextStyle(color: crm.textSecondary)),
                ),
              )
            else
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  for (final a in artists)
                    SizedBox(
                      width: isMobile ? double.infinity : 340,
                      child: _artistCard(
                        crm,
                        a,
                        bookings,
                        ratingByName[a.name.trim().toLowerCase()],
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _artistCard(
      CrmTheme crm, Employee a, List<Booking> bookings, ArtistStat? rating) {
    var total = 0, active = 0;
    for (final b in bookings) {
      if (!_onBooking(b, a.id)) continue;
      total++;
      final s = b.status.toLowerCase();
      if (s != 'completed' && s != 'cancelled') active++;
    }
    final isActive = a.isActive;
    return InkWell(
      onTap: () => context.push('/artist-head/artist/${a.id}'),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: crm.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: crm.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: crm.primary.withValues(alpha: 0.12),
                  backgroundImage: a.profileImage.isNotEmpty
                      ? NetworkImage(a.profileImage)
                      : null,
                  child: a.profileImage.isEmpty
                      ? Text(
                          a.name.isNotEmpty ? a.name[0].toUpperCase() : '?',
                          style: TextStyle(
                              color: crm.primary, fontWeight: FontWeight.w800))
                      : null,
                ),
                10.wg,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: crm.textPrimary)),
                      Text(
                          '${a.artistRole.isEmpty ? 'Artist' : _cap(a.artistRole)}'
                          '${a.regionName.isNotEmpty ? ' · ${a.regionName}' : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11.5, color: crm.textSecondary)),
                    ],
                  ),
                ),
                _pill(
                  isActive ? 'Active' : 'Inactive',
                  isActive
                      ? const Color(0xFF16A34A)
                      : const Color(0xFF6B7280),
                ),
              ],
            ),
            12.hg,
            Row(
              children: [
                _pill(
                  a.type == 'in-house' ? 'In-house' : 'Outsource',
                  a.type == 'in-house'
                      ? const Color(0xFF6D5DF6)
                      : const Color(0xFFEA580C),
                ),
                const Spacer(),
                if (rating != null && rating.count > 0) ...[
                  Icon(Icons.star_rounded, size: 16, color: crm.primary),
                  2.wg,
                  Text(rating.avgTeamScore.toStringAsFixed(1),
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  2.wg,
                  Text('(${rating.count})',
                      style: TextStyle(
                          fontSize: 11, color: crm.textSecondary)),
                ] else
                  Text('No reviews',
                      style:
                          TextStyle(fontSize: 11, color: crm.textSecondary)),
              ],
            ),
            10.hg,
            Divider(height: 1, color: crm.border),
            10.hg,
            Row(
              children: [
                _mini(crm, '$total', 'Bookings'),
                _mini(crm, '$active', 'Active'),
                _mini(
                    crm,
                    a.specialization.isEmpty ? '—' : a.specialization,
                    'Specialty',
                    flexible: true),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _mini(CrmTheme crm, String value, String label,
          {bool flexible = false}) =>
      Expanded(
        flex: flexible ? 2 : 1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontWeight: FontWeight.w800, color: crm.textPrimary)),
            Text(label,
                style: TextStyle(fontSize: 10.5, color: crm.textSecondary)),
          ],
        ),
      );

  Widget _pill(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(100)),
        child: Text(text,
            style: TextStyle(
                fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
      );

  Widget _filterChip(
          CrmTheme crm, String label, bool selected, VoidCallback onTap) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? crm.primary : crm.surface,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: selected ? crm.primary : crm.border),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : crm.textSecondary)),
        ),
      );

  Widget _dot(CrmTheme crm) => Container(
        width: 1,
        height: 30,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        color: crm.border,
      );

  static String _cap(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  /// True when the artist is assigned to the booking at either the booking level
  /// or on any of its per-package items.
  static bool _onBooking(Booking b, String id) {
    if (id.isEmpty) return false;
    if (b.assignedStaff.any((s) => s.employeeId == id)) return true;
    for (final item in b.bookingItems) {
      if (item.assignedStaff.any((s) => s.employeeId == id)) return true;
    }
    return false;
  }
}

extension _Gap on num {
  Widget get hg => SizedBox(height: toDouble());
  Widget get wg => SizedBox(width: toDouble());
}
