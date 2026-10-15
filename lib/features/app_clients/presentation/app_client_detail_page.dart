import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/app_clients/controllers/app_clients_service.dart';
import 'package:nizan_crm/features/app_clients/data/app_client.dart';

final _date = DateFormat('d MMM yyyy');

/// One bride's full app profile: preferences, saved looks and bookings, with a
/// shortcut into her concierge chat.
class AppClientDetailPage extends ConsumerWidget {
  const AppClientDetailPage({super.key, required this.clientId});
  final String clientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final async = ref.watch(appClientDetailProvider(clientId));
    return SelectionArea(
      child: Scaffold(
        backgroundColor: crm.background,
        appBar: AppBar(
          title: const Text('Client'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.canPop()
                ? context.pop()
                : context.go('/app-clients'),
          ),
        ),
        body: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => AppErrorView(
            error: e,
            onRetry: () => ref.invalidate(appClientDetailProvider(clientId)),
          ),
          data: (d) => _body(context, crm, d),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, CrmTheme crm, AppClientDetail d) {
    final c = d.client;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        // Profile header.
        _card(crm, Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: crm.primary.withValues(alpha: 0.12),
              child: Text(_initials(c.displayName),
                  style: TextStyle(
                      color: crm.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 18)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.displayName,
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: crm.textPrimary)),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (c.phone.isNotEmpty) c.phone,
                      if (c.email.isNotEmpty) c.email,
                    ].join('  ·  '),
                    style: TextStyle(color: crm.textSecondary, fontSize: 12.5),
                  ),
                  if (c.lastLoginAt != null)
                    Text('Last active ${_date.format(c.lastLoginAt!)}',
                        style: TextStyle(
                            color: crm.textSecondary, fontSize: 11.5)),
                ],
              ),
            ),
            if (d.conversationId != null)
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: crm.primary),
                onPressed: () =>
                    context.go('/client-chat/${d.conversationId}'),
                icon: const Icon(Icons.forum_outlined, size: 18),
                label: const Text('Chat'),
              ),
          ],
        )),
        const SizedBox(height: 16),

        // Preferences.
        _sectionTitle(crm, 'Preferences'),
        const SizedBox(height: 8),
        if (d.preferences.isEmpty)
          _muted(crm, 'No preferences submitted yet.')
        else
          _card(
            crm,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final entry in d.preferences.entries)
                  if (entry.value.isNotEmpty) ...[
                    Text(_prettyKey(entry.key),
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: crm.textSecondary)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final v in entry.value)
                          _chip(crm, entry.key == 'tradition' ? _traditionName(v) : v),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
              ],
            ),
          ),
        const SizedBox(height: 16),

        // Look plan: what she wants for each function.
        _sectionTitle(crm, 'Look plan'),
        const SizedBox(height: 8),
        if (d.lookPlan.isEmpty)
          _muted(crm, 'No look plan built yet.')
        else
          ..._lookPlan(crm, d.lookPlan),
        const SizedBox(height: 16),

        // Saved looks.
        _sectionTitle(crm, 'Saved looks (Look Board)'),
        const SizedBox(height: 8),
        if (d.savedLooks.isEmpty)
          _muted(crm, 'No looks saved yet.')
        else
          _card(
            crm,
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final l in d.savedLooks)
                  _chip(crm, '${l.look} · ${l.culture}'),
              ],
            ),
          ),
        const SizedBox(height: 16),

        // Bookings & trials.
        _sectionTitle(crm, 'Bookings & trials'),
        const SizedBox(height: 8),
        if (d.bookings.isEmpty)
          _muted(crm, 'No bookings yet.')
        else
          for (final b in d.bookings) _bookingRow(crm, b),
      ],
    );
  }

  /// One card per function, grouped under its tradition.
  List<Widget> _lookPlan(CrmTheme crm, List<LookPlanEntry> plan) {
    final out = <Widget>[];
    String? current;
    for (final e in plan) {
      if (e.traditionName != current) {
        current = e.traditionName;
        out.add(Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: Text(e.traditionName,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: crm.textSecondary)),
        ));
      }
      out.add(Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: crm.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: crm.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(e.function,
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: crm.textPrimary)),
            const SizedBox(height: 8),
            for (final c in _lookCategories)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 84,
                      child: Text(c.$2,
                          style: TextStyle(
                              color: crm.textSecondary, fontSize: 12.5)),
                    ),
                    Expanded(
                      child: Text(e.pick(c.$1)?.name ?? '—',
                          style: TextStyle(
                              color: crm.textPrimary,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ));
    }
    return out;
  }

  Widget _bookingRow(CrmTheme crm, AppClientBooking b) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
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
            children: [
              if (b.isTrial)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: crm.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('Trial',
                      style: TextStyle(
                          color: crm.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ),
              Expanded(
                child: Text(
                  b.bookingNumber.isNotEmpty
                      ? '#${b.bookingNumber}'
                      : (b.service.isEmpty ? 'Booking' : b.service),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: crm.textPrimary),
                ),
              ),
              _statusChip(crm, b.status),
            ],
          ),
          if (b.service.isNotEmpty && b.bookingNumber.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(b.service,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: crm.textSecondary, fontSize: 12.5)),
          ],
          if (b.brief.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: crm.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(b.brief,
                  style: TextStyle(
                      color: crm.textPrimary, fontSize: 12.5, height: 1.4)),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            [
              if (b.bookingDate != null) _date.format(b.bookingDate!),
              'Total ₹${b.totalPrice.toStringAsFixed(0)}',
              if (b.balanceDue > 0)
                'Balance ₹${b.balanceDue.toStringAsFixed(0)}',
            ].join('  ·  '),
            style: TextStyle(color: crm.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(CrmTheme crm, String status) {
    Color col;
    switch (status.toLowerCase()) {
      case 'confirmed':
        col = crm.success;
        break;
      case 'cancelled':
        col = crm.destructive;
        break;
      case 'completed':
        col = crm.primary;
        break;
      default:
        col = crm.warning;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: col.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(status,
          style: TextStyle(
              color: col, fontSize: 11.5, fontWeight: FontWeight.w700)),
    );
  }

  Widget _card(CrmTheme crm, Widget child) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: crm.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: crm.border),
        ),
        child: child,
      );

  Widget _sectionTitle(CrmTheme crm, String t) => Text(t,
      style: TextStyle(
          fontSize: 15, fontWeight: FontWeight.w700, color: crm.textPrimary));

  Widget _muted(CrmTheme crm, String t) => Text(t,
      style: TextStyle(color: crm.textSecondary, fontSize: 13));

  Widget _chip(CrmTheme crm, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: crm.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: crm.border),
        ),
        child: Text(label,
            style: TextStyle(fontSize: 12, color: crm.textPrimary)),
      );
}

/// Category key (as stored by the app) and its label, in display order.
const _lookCategories = [
  ('outfit', 'Outfit'),
  ('jewellery', 'Jewellery'),
  ('hair', 'Hair'),
  ('makeup', 'Makeup'),
];

/// The app stores the chosen tradition as an id; show its name.
String _traditionName(String id) =>
    const {
      'south_indian': 'South Indian',
      'malayali': 'Malayali Hindu',
      'muslim': 'Muslim · Nikah',
      'north_indian': 'North Indian',
      'christian': 'Christian',
      'bengali': 'Bengali',
    }[id] ??
    id;

String _prettyKey(String key) {
  const map = {
    'tradition': 'Wedding tradition',
    'interests': 'Interests',
    'fit_focus': 'Fitness focus',
    'fit_activity': 'Activity level',
    'fit_enjoy': 'Enjoys',
    'fit_time': 'Time per day',
    'fit_when': 'Preferred time',
    'fit_consistent': 'Consistency',
    'sty_style': 'Style',
    'sty_help': 'Help styling',
    'sty_colors': 'Colours',
    'sty_outfits': 'Outfits',
    'sty_priority': 'Priorities',
    'sty_recos': 'Recommendations',
  };
  return map[key] ?? key;
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    final p = parts.first;
    return p.substring(0, p.length >= 2 ? 2 : 1).toUpperCase();
  }
  return (parts.first[0] + parts.last[0]).toUpperCase();
}
