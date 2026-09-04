import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/utils/responsive_builder.dart';
import 'package:nizan_crm/core/models/employee.dart';
import 'package:nizan_crm/services/employee_service.dart';
import 'package:nizan_crm/features/bookings/controllers/booking_provider.dart';
import 'package:nizan_crm/features/bookings/data/booking.dart';
import 'package:nizan_crm/features/reviews/services/review_service.dart';

/// Artist profile — the Artist Head's drill-down for one artist: their bookings,
/// live workload, client rating, revenue contribution, plus roster controls
/// (activate / deactivate, switch in-house ↔ outsource).
class ArtistProfileScreen extends ConsumerStatefulWidget {
  const ArtistProfileScreen({super.key, required this.artistId});
  final String artistId;

  @override
  ConsumerState<ArtistProfileScreen> createState() =>
      _ArtistProfileScreenState();
}

class _ArtistProfileScreenState extends ConsumerState<ArtistProfileScreen> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);

    final employees = ref.watch(employeesProvider).value ?? const <Employee>[];
    final bookings = ref.watch(bookingProvider).value ?? const <Booking>[];
    final perfAsync = ref.watch(artistReviewPerformanceProvider(widget.artistId));

    Employee? artist;
    for (final e in employees) {
      if (e.id == widget.artistId) {
        artist = e;
        break;
      }
    }

    if (artist == null) {
      return Scaffold(
        backgroundColor: crm.background,
        body: Center(
          child: employees.isEmpty
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Artist not found.',
                        style: TextStyle(color: crm.textSecondary)),
                    12.hg,
                    TextButton(
                      onPressed: () => context.canPop()
                          ? context.pop()
                          : context.go('/artist-head/artists'),
                      child: const Text('Back to Artists'),
                    ),
                  ],
                ),
        ),
      );
    }

    // ── Their bookings ──
    final theirs = bookings.where((b) => _onBooking(b, artist!.id)).toList()
      ..sort((a, b) => b.serviceStart.compareTo(a.serviceStart));
    final now = DateTime.now();
    var completed = 0, active = 0, upcoming = 0, thisMonth = 0;
    double revenue = 0;
    for (final b in theirs) {
      final s = b.status.toLowerCase();
      if (s == 'completed') {
        completed++;
      } else if (s != 'cancelled') {
        active++;
        if (b.serviceStart.isAfter(now)) upcoming++;
      }
      if (b.serviceStart.year == now.year && b.serviceStart.month == now.month) {
        thisMonth++;
      }
      revenue += _revenue(b, artist.id);
    }

    return Scaffold(
      backgroundColor: crm.background,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(employeesProvider);
          ref.invalidate(bookingProvider);
          ref.invalidate(artistReviewPerformanceProvider(widget.artistId));
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
                      : context.go('/artist-head/artists'),
                  icon: const Icon(Icons.arrow_back),
                ),
                8.wg,
                Text('Artist Profile',
                    style: TextStyle(
                        fontSize: isMobile ? 20 : 24,
                        fontWeight: FontWeight.w800,
                        color: crm.textPrimary)),
              ],
            ),
            14.hg,

            _profileCard(crm, artist),
            14.hg,
            _controls(crm, artist),
            18.hg,

            // KPI cards
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _kpi(crm, isMobile, Icons.event_note_outlined, '${theirs.length}',
                    'Total Bookings', const Color(0xFF6D5DF6)),
                _kpi(crm, isMobile, Icons.play_circle_outline, '$active',
                    'Active Now', const Color(0xFF16A34A)),
                _kpi(crm, isMobile, Icons.check_circle_outline, '$completed',
                    'Completed', const Color(0xFF2563EB)),
                _kpi(crm, isMobile, Icons.upcoming_outlined, '$upcoming',
                    'Upcoming', const Color(0xFFEA580C)),
                _kpi(crm, isMobile, Icons.today_outlined, '$thisMonth',
                    'This Month', const Color(0xFFDB2777)),
                _kpi(crm, isMobile, Icons.account_balance_wallet_outlined,
                    '₹${_money(revenue)}', 'Revenue', const Color(0xFF7C3AED)),
              ],
            ),
            18.hg,

            _ratingCard(crm, perfAsync),
            18.hg,

            _bookingsCard(crm, theirs),
          ],
        ),
      ),
    );
  }

  // ── profile header ──
  Widget _profileCard(CrmTheme crm, Employee a) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: crm.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: crm.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: crm.primary.withValues(alpha: 0.12),
              backgroundImage:
                  a.profileImage.isNotEmpty ? NetworkImage(a.profileImage) : null,
              child: a.profileImage.isEmpty
                  ? Text(a.name.isNotEmpty ? a.name[0].toUpperCase() : '?',
                      style: TextStyle(
                          fontSize: 24,
                          color: crm.primary,
                          fontWeight: FontWeight.w800))
                  : null,
            ),
            14.wg,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.name,
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: crm.textPrimary)),
                  4.hg,
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _pill(a.artistRole.isEmpty ? 'Artist' : _cap(a.artistRole),
                          crm.primary),
                      _pill(a.type == 'in-house' ? 'In-house' : 'Outsource',
                          a.type == 'in-house'
                              ? const Color(0xFF6D5DF6)
                              : const Color(0xFFEA580C)),
                      _pill(a.isActive ? 'Active' : 'Inactive',
                          a.isActive
                              ? const Color(0xFF16A34A)
                              : const Color(0xFF6B7280)),
                    ],
                  ),
                  10.hg,
                  if (a.phone.isNotEmpty)
                    _info(crm, Icons.phone_outlined, a.phone),
                  if (a.regionName.isNotEmpty)
                    _info(crm, Icons.place_outlined, a.regionName),
                  if (a.specialization.isNotEmpty)
                    _info(crm, Icons.brush_outlined, a.specialization),
                  if (a.works.isNotEmpty)
                    _info(crm, Icons.work_outline, a.works.join(', ')),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _info(CrmTheme crm, IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 15, color: crm.textSecondary),
            6.wg,
            Expanded(
              child: Text(text,
                  style: TextStyle(fontSize: 13, color: crm.textSecondary)),
            ),
          ],
        ),
      );

  // ── roster controls ──
  Widget _controls(CrmTheme crm, Employee a) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: crm.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: crm.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Controls',
                style: TextStyle(
                    fontWeight: FontWeight.w800, color: crm.textPrimary)),
            12.hg,
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: _saving ? null : () => _toggleStatus(a),
                  icon: Icon(
                      a.isActive
                          ? Icons.person_off_outlined
                          : Icons.person_outline,
                      size: 18),
                  label: Text(a.isActive ? 'Deactivate' : 'Activate'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: a.isActive
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF16A34A),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _saving ? null : () => _toggleType(a),
                  icon: const Icon(Icons.swap_horiz, size: 18),
                  label: Text(a.type == 'in-house'
                      ? 'Make Outsource'
                      : 'Make In-house'),
                ),
                if (_saving)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
              ],
            ),
            8.hg,
            Text(
                'Inactive artists are hidden from booking assignment pickers.',
                style: TextStyle(fontSize: 11, color: crm.textSecondary)),
          ],
        ),
      );

  // ── rating + breakdown ──
  Widget _ratingCard(
          CrmTheme crm, AsyncValue<ArtistReviewPerformance> async) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: crm.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: crm.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Client Reviews',
                style: TextStyle(
                    fontWeight: FontWeight.w800, color: crm.textPrimary)),
            14.hg,
            async.when(
              loading: () => _muted(crm, 'Loading reviews…'),
              error: (_, _) => _muted(crm, 'Reviews unavailable.'),
              data: (p) {
                if (p.reviewCount == 0) {
                  return _muted(crm, 'No client reviews yet.');
                }
                final entries = p.breakdown.entries.toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(p.avgClientRating.toStringAsFixed(1),
                            style: TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                                color: crm.textPrimary)),
                        6.wg,
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Row(
                                children: [
                                  for (var i = 0; i < 5; i++)
                                    Icon(
                                      i < p.avgClientRating.round()
                                          ? Icons.star_rounded
                                          : Icons.star_outline_rounded,
                                      size: 16,
                                      color: crm.primary,
                                    ),
                                ],
                              ),
                              Text('${p.reviewCount} reviews',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: crm.textSecondary)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (entries.isNotEmpty) ...[
                      14.hg,
                      for (final e in entries)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 120,
                                child: Text(_label(e.key),
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: crm.textSecondary)),
                              ),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(100),
                                  child: LinearProgressIndicator(
                                    value: (e.value / 5).clamp(0, 1),
                                    minHeight: 8,
                                    backgroundColor: crm.border,
                                    valueColor: AlwaysStoppedAnimation(
                                        crm.primary),
                                  ),
                                ),
                              ),
                              8.wg,
                              Text(e.value.toStringAsFixed(1),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12)),
                            ],
                          ),
                        ),
                    ],
                    if (p.testimonials.isNotEmpty) ...[
                      16.hg,
                      Text('Recent testimonials',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: crm.textPrimary)),
                      8.hg,
                      for (final t in p.testimonials.take(3))
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: crm.background,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: crm.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('"${t.text}"',
                                  style: TextStyle(
                                      fontSize: 12.5,
                                      fontStyle: FontStyle.italic,
                                      color: crm.textPrimary)),
                              if (t.bride.isNotEmpty) ...[
                                4.hg,
                                Text('— ${t.bride}',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: crm.textSecondary)),
                              ],
                            ],
                          ),
                        ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      );

  // ── their bookings ──
  Widget _bookingsCard(CrmTheme crm, List<Booking> theirs) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: crm.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: crm.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bookings (${theirs.length})',
                style: TextStyle(
                    fontWeight: FontWeight.w800, color: crm.textPrimary)),
            12.hg,
            if (theirs.isEmpty)
              _muted(crm, 'No bookings assigned to this artist yet.')
            else
              for (final b in theirs.take(25))
                InkWell(
                  onTap: () => context.push('/booking/manage/${b.id}'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  b.customerName.isEmpty
                                      ? '#${b.displayBookingNumber}'
                                      : b.customerName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              Text(b.service,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 11.5,
                                      color: crm.textSecondary)),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(_date(b.serviceStart),
                              style: TextStyle(
                                  fontSize: 12, color: crm.textSecondary)),
                        ),
                        _pill(b.status.isEmpty ? 'pending' : b.status,
                            _statusColor(b.status)),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      );

  // ── actions ──
  Future<void> _toggleStatus(Employee a) async {
    if (a.isActive) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Deactivate artist?'),
          content: Text(
              '${a.name} will be hidden from booking assignment pickers. '
              'Existing bookings are not affected. You can re-activate anytime.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626)),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Deactivate')),
          ],
        ),
      );
      if (ok != true) return;
    }
    await _save(a, status: a.isActive ? 'inactive' : 'active');
  }

  Future<void> _toggleType(Employee a) async {
    await _save(a, type: a.type == 'in-house' ? 'outsource' : 'in-house');
  }

  Future<void> _save(Employee a, {String? status, String? type}) async {
    setState(() => _saving = true);
    try {
      await ref.read(employeeServiceProvider).saveEmployee(
            id: a.id,
            name: a.name,
            email: a.email,
            type: type ?? a.type,
            artistRole: a.artistRole,
            specialization: a.specialization,
            phone: a.phone,
            status: status ?? a.status,
            regionId: a.regionId,
            category: a.category,
            department: a.department,
            role: a.role,
            works: a.works,
            zoneId: a.zoneId,
            stateId: a.stateId,
            districtId: a.districtId,
            pincodeId: a.pincodeId,
            salaryType: a.salaryType,
            baseSalary: a.baseSalary,
            allowances: a.allowances,
            deductions: a.deductions,
            hra: a.hra,
            hraDay: a.hraDay,
            bankName: a.bankName,
            accountNumber: a.accountNumber,
            ifscCode: a.ifscCode,
            upiId: a.upiId,
            panNumber: a.panNumber,
          );
      ref.invalidate(employeesProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('${a.name} updated'),
            backgroundColor: const Color(0xFF16A34A)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: const Color(0xFFDC2626)),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── small helpers ──
  Widget _kpi(CrmTheme crm, bool isMobile, IconData icon, String value,
          String label, Color color) =>
      SizedBox(
        width: isMobile ? (mediaHalf(context)) : 168,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: crm.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: crm.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 18),
              ),
              10.hg,
              Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: crm.textPrimary)),
              Text(label,
                  style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
            ],
          ),
        ),
      );

  static double mediaHalf(BuildContext context) =>
      (MediaQuery.of(context).size.width - 14 * 2 - 12) / 2;

  Widget _pill(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(100)),
        child: Text(text,
            style: TextStyle(
                fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
      );

  Widget _muted(CrmTheme crm, String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(t, style: TextStyle(color: crm.textSecondary, fontSize: 13)),
      );

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'completed':
        return const Color(0xFF16A34A);
      case 'confirmed':
        return const Color(0xFF2563EB);
      case 'cancelled':
        return const Color(0xFFDC2626);
      case 'postponed':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF6B7280);
    }
  }

  static String _cap(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  static String _label(String key) {
    final words = key
        .replaceAllMapped(RegExp('([A-Z])'), (m) => ' ${m[1]}')
        .replaceAll('_', ' ')
        .trim();
    return words.isEmpty ? key : '${words[0].toUpperCase()}${words.substring(1)}';
  }

  static const _mon = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul',
      'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  String _date(DateTime d) => '${d.day} ${_mon[d.month]} ${d.year}';

  static String _money(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}k';
    return v.toStringAsFixed(0);
  }

  static bool _onBooking(Booking b, String id) {
    if (id.isEmpty) return false;
    if (b.assignedStaff.any((s) => s.employeeId == id)) return true;
    for (final item in b.bookingItems) {
      if (item.assignedStaff.any((s) => s.employeeId == id)) return true;
    }
    return false;
  }

  static double _revenue(Booking b, String id) {
    if (b.bookingItems.isNotEmpty) {
      double sum = 0;
      for (final item in b.bookingItems) {
        if (item.assignedStaff.any((s) => s.employeeId == id)) {
          sum += item.totalPrice;
        }
      }
      if (sum == 0 && b.assignedStaff.any((s) => s.employeeId == id)) {
        sum = b.totalPrice;
      }
      return sum;
    }
    if (b.assignedStaff.any((s) => s.employeeId == id)) return b.totalPrice;
    return 0;
  }
}

extension _Gap on num {
  Widget get hg => SizedBox(height: toDouble());
  Widget get wg => SizedBox(width: toDouble());
}
