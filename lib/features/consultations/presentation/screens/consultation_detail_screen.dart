import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:nizan_crm/core/auth/workspace.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/state/data_refresh.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../controllers/consultation_provider.dart';
import '../../data/consultation.dart';
import '../../services/consultation_service.dart';
import '../widgets/consultation_dialogs.dart';
import '../widgets/consultation_ui.dart';
import '../widgets/reference_images.dart';
import '../widgets/stylist_client_ui.dart';
import '../../data/stylist_client.dart' show parseDay;

/// Wide enough for two columns and inline action buttons.
const _wideBreakpoint = 900.0;

/// One call. The client's name is the title; a summary card shows when and
/// how; and one main button does the next step for the call's state (add the
/// link, share the invite, join, record the outcome…). Rarer actions sit in a
/// "More" menu, with Cancel last. On a phone the main button and More are
/// pinned to the bottom of the screen.
class ConsultationDetailScreen extends ConsumerWidget {
  const ConsultationDetailScreen({super.key, required this.consultationId});

  final String consultationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final async = ref.watch(consultationProvider(consultationId));
    final c = async.value;

    return LayoutBuilder(builder: (context, box) {
      final wide = box.maxWidth >= _wideBreakpoint;
      final actions = c == null ? null : _CallActions.of(c);
      return Scaffold(
        backgroundColor: crm.background,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.canPop() ? context.pop() : context.go('/consultations'),
          ),
          title: c == null
              ? const Text('Call')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.clientName.isEmpty ? 'Call' : c.clientName,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(
                      [
                        if (c.callLabel.isNotEmpty) c.callLabel,
                        if (wide || c.callLabel.isEmpty) c.consultationNo,
                      ].where((s) => s.isNotEmpty).join('  ·  '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: crm.textSecondary, fontWeight: FontWeight.w400),
                    ),
                  ],
                ),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh),
              onPressed: () => ref.invalidate(consultationProvider(consultationId)),
            ),
          ],
        ),
        bottomNavigationBar:
            !wide && actions != null && actions.hasAny ? _BottomActions(consultation: c!, actions: actions) : null,
        body: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => AppErrorView(
            error: e,
            onRetry: () => ref.invalidate(consultationProvider(consultationId)),
          ),
          data: (c) => _Body(consultation: c, actions: actions!, wide: wide),
        ),
      );
    });
  }
}

// ── Actions ──────────────────────────────────────────────────────────────────
enum _Act { addLink, share, join, complete, record, noShow, reschedule, cancel, editDetails }

/// Which actions a call offers, by its state: one [primary], at most one
/// [secondary] (shown beside it on desktop, in More on a phone) and the rest
/// in [more]. All of them call the same dialogs and endpoints as before.
class _CallActions {
  const _CallActions({this.primary, this.secondary, this.more = const [], required this.inviteSent});

  final _Act? primary;
  final _Act? secondary;
  final List<_Act> more;
  final bool inviteSent;

  bool get hasAny => primary != null || secondary != null || more.isNotEmpty;

  static _CallActions of(Consultation c) {
    final sent = c.inviteSentAt != null;
    if (c.status == 'Completed') {
      return _CallActions(primary: c.notesVisible ? _Act.editDetails : null, inviteSent: sent);
    }
    if (!c.isScheduled) return _CallActions(inviteSent: sent); // Cancelled / No-show: final

    final ended = c.endsAt.isBefore(DateTime.now());
    final noLink = c.isVideo && c.meetingLink.isEmpty;
    final _Act primary;
    _Act? secondary;
    if (ended) {
      primary = _Act.record;
      secondary = _Act.noShow;
    } else if (noLink) {
      primary = _Act.addLink;
      secondary = _Act.complete;
    } else if (!sent) {
      primary = _Act.share;
      secondary = c.isVideo ? _Act.join : _Act.complete;
    } else if (c.isVideo) {
      primary = _Act.join;
      secondary = _Act.complete;
    } else {
      primary = _Act.complete;
    }
    final taken = {primary, secondary};
    return _CallActions(
      primary: primary,
      secondary: secondary,
      inviteSent: sent,
      more: [
        if (!taken.contains(_Act.share) && !noLink) _Act.share,
        _Act.reschedule,
        if (!taken.contains(_Act.noShow)) _Act.noShow,
        if (ended && !taken.contains(_Act.complete)) _Act.complete,
        _Act.cancel,
      ],
    );
  }

  static String label(_Act a, {bool inviteSent = false}) => switch (a) {
        _Act.addLink => 'Add meeting link',
        _Act.share => inviteSent ? 'Share invite again' : 'Share invite',
        _Act.join => 'Join call',
        _Act.complete => 'Complete',
        _Act.record => 'Record outcome',
        _Act.noShow => 'Mark no-show',
        _Act.reschedule => 'Reschedule',
        _Act.cancel => 'Cancel call',
        _Act.editDetails => 'Edit call details',
      };

  static IconData icon(_Act a) => switch (a) {
        _Act.addLink => Icons.add_link,
        _Act.share => Icons.send_outlined,
        _Act.join => Icons.videocam_outlined,
        _Act.complete => Icons.check_circle_outline,
        _Act.record => Icons.edit_note_outlined,
        _Act.noShow => Icons.person_off_outlined,
        _Act.reschedule => Icons.update,
        _Act.cancel => Icons.cancel_outlined,
        _Act.editDetails => Icons.edit_outlined,
      };
}

Future<void> _run(BuildContext context, WidgetRef ref, Consultation c, _Act a, bool isLead) async {
  switch (a) {
    case _Act.addLink:
      await showEditMeetingDialog(context, c);
    case _Act.share:
      await _shareInvite(context, ref, c);
    case _Act.join:
      await launchUrl(Uri.parse(c.meetingLink), mode: LaunchMode.externalApplication);
    case _Act.complete:
    case _Act.record:
      context.push('/consultations/${c.id}/details?complete=1');
    case _Act.editDetails:
      context.push('/consultations/${c.id}/details');
    case _Act.noShow:
      await _noShow(context, ref, c);
    case _Act.reschedule:
      await showRescheduleDialog(context, c, isLead: isLead);
    case _Act.cancel:
      await showCancelDialog(context, c);
  }
}

Future<void> _shareInvite(BuildContext context, WidgetRef ref, Consultation c) async {
  if (c.isVideo && c.meetingLink.isEmpty) {
    showWarningSnackBar(context, 'Add the meeting link before sharing the invite');
    await showEditMeetingDialog(context, c);
    return;
  }
  try {
    final opened = await openWhatsAppInvite(c);
    if (!opened) {
      if (context.mounted) showWarningSnackBar(context, 'Could not open WhatsApp for this number');
      return;
    }
    await ref.read(consultationServiceProvider).markInviteSent(c.id);
    ref.refreshData.consultations();
  } catch (e) {
    if (context.mounted) showErrorSnackBar(context, e);
  }
}

Future<void> _noShow(BuildContext context, WidgetRef ref, Consultation c) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Mark as no-show?'),
      content: Text('${c.clientName} did not join the consultation.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Back')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Mark no-show')),
      ],
    ),
  );
  if (ok != true) return;
  try {
    await ref.read(consultationServiceProvider).markNoShow(c.id);
    ref.refreshData.consultations();
    if (context.mounted) showSuccessSnackBar(context, 'Marked as no-show');
  } catch (e) {
    if (context.mounted) showErrorSnackBar(context, e);
  }
}

/// The main button, styled filled.
Widget _primaryButton(BuildContext context, WidgetRef ref, Consultation c, _CallActions a, bool isLead,
        {bool expand = false}) =>
    FilledButton.icon(
      onPressed: () => _run(context, ref, c, a.primary!, isLead),
      style: expand ? FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)) : null,
      icon: Icon(_CallActions.icon(a.primary!), size: 18),
      label: Text(_CallActions.label(a.primary!, inviteSent: a.inviteSent)),
    );

/// "More ▾": the remaining actions, Cancel last and in red.
class _MoreButton extends ConsumerWidget {
  const _MoreButton({required this.consultation, required this.items, this.up = false});

  final Consultation consultation;
  final List<_Act> items;
  final bool up;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final isLead = ref.watch(effectiveAccessProvider).canSeeConsultationReports;
    final sent = consultation.inviteSentAt != null;
    return PopupMenuButton<_Act>(
      tooltip: 'More actions',
      position: up ? PopupMenuPosition.over : PopupMenuPosition.under,
      onSelected: (a) => _run(context, ref, consultation, a, isLead),
      itemBuilder: (_) => [
        for (final a in items) ...[
          if (a == _Act.cancel && items.length > 1) const PopupMenuDivider(),
          PopupMenuItem(
            value: a,
            child: Row(
              children: [
                Icon(_CallActions.icon(a), size: 18, color: a == _Act.cancel ? crm.destructive : crm.textSecondary),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(_CallActions.label(a, inviteSent: sent),
                      style: TextStyle(color: a == _Act.cancel ? crm.destructive : crm.textPrimary)),
                ),
              ],
            ),
          ),
        ],
      ],
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: crm.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: crm.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('More', style: TextStyle(color: crm.primary, fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            Icon(up ? Icons.expand_less : Icons.expand_more, size: 18, color: crm.primary),
          ],
        ),
      ),
    );
  }
}

/// Phone: the main button and More, pinned to the bottom.
class _BottomActions extends ConsumerWidget {
  const _BottomActions({required this.consultation, required this.actions});

  final Consultation consultation;
  final _CallActions actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final isLead = ref.watch(effectiveAccessProvider).canSeeConsultationReports;
    final more = [?actions.secondary, ...actions.more];
    return Container(
      decoration: BoxDecoration(color: crm.surface, border: Border(top: BorderSide(color: crm.border))),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              if (actions.primary != null)
                Expanded(child: _primaryButton(context, ref, consultation, actions, isLead, expand: true)),
              if (actions.primary != null && more.isNotEmpty) const SizedBox(width: 10),
              if (more.isNotEmpty) _MoreButton(consultation: consultation, items: more, up: true),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Body ─────────────────────────────────────────────────────────────────────
class _Body extends ConsumerWidget {
  const _Body({required this.consultation, required this.actions, required this.wide});

  final Consultation consultation;
  final _CallActions actions;
  final bool wide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final c = consultation;
    final ended = c.isScheduled && c.endsAt.isBefore(DateTime.now());

    final banner = ended
        ? Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: crm.destructive.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: crm.destructive.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: crm.destructive, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('This call ended. Record what was discussed, or mark a no-show.',
                      style: TextStyle(color: crm.textPrimary)),
                ),
              ],
            ),
          )
        : null;
    final summary = _SummaryCard(consultation: c, actions: actions, wide: wide);
    final meeting = _MeetingCard(consultation: c);
    final details = c.notesVisible ? _DetailsCard(consultation: c) : null;
    final client = wide ? _ClientCard(consultation: c) : null;
    final history = c.history.isEmpty ? null : _HistoryCard(consultation: c);

    List<Widget> spaced(List<Widget?> items) => [
          for (final (i, w) in items.nonNulls.indexed) ...[if (i > 0) const SizedBox(height: 16), w],
        ];

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(consultationProvider(c.id)),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: wide ? 1100 : 760),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: wide
                ? [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: Column(children: spaced([banner, summary, details]))),
                        const SizedBox(width: 16),
                        Expanded(flex: 2, child: Column(children: spaced([meeting, client, history]))),
                      ],
                    ),
                  ]
                : spaced([banner, summary, meeting, details, history]),
          ),
        ),
      ),
    );
  }
}

Widget _card(CrmTheme crm, {String? title, Widget? trailing, required Widget child}) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: crm.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: crm.textPrimary)),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 10),
          ],
          child,
        ],
      ),
    );

// ── Summary: status, when, how, and the actions ──────────────────────────────
class _SummaryCard extends ConsumerWidget {
  const _SummaryCard({required this.consultation, required this.actions, required this.wide});

  final Consultation consultation;
  final _CallActions actions;
  final bool wide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final c = consultation;
    final isLead = ref.watch(effectiveAccessProvider).canSeeConsultationReports;
    final eventDate = c.client.isEmpty
        ? c.lead.eventDate
        : c.client.eventDates.map(parseDay).whereType<DateTime>().firstOrNull;
    final how = [
      c.isVideo ? 'Video' : 'In-person',
      if (c.isVideo && c.meetingProvider.isNotEmpty) c.meetingProvider,
      '${c.durationMins} min',
      c.stylistName.isEmpty ? 'Unassigned' : 'Stylist ${c.stylistName}',
      if (eventDate != null) '${c.client.eventType.isNotEmpty ? c.client.eventType : 'Event'} ${fmtShortDay(eventDate)}',
    ].join('  ·  ');

    return _card(
      crm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ConsultationStatusChip(c.status),
              CompanyTag(c.client.company),
              if (c.isScheduled && c.inviteSentAt != null)
                Text('Invite shared ${fmtDateTime(c.inviteSentAt!)}',
                    style: TextStyle(color: crm.textSecondary, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 10),
          Text('${DateFormat('EEE d MMM').format(c.scheduledAt)}  ·  ${fmtRange(c)}',
              style: TextStyle(fontSize: wide ? 22 : 18, fontWeight: FontWeight.bold, color: crm.textPrimary)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(c.isVideo ? Icons.videocam_outlined : Icons.place_outlined,
                    size: 16, color: crm.textSecondary),
              ),
              const SizedBox(width: 6),
              Expanded(child: Text(how, style: TextStyle(color: crm.textSecondary, fontSize: 13))),
            ],
          ),
          if (c.rescheduleCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Rescheduled ${c.rescheduleCount}×', style: TextStyle(color: crm.textSecondary, fontSize: 12)),
            ),
          if (c.status == 'Cancelled' && c.cancelReason.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Cancelled: ${c.cancelReason}',
                  style: TextStyle(color: consultationStatusColor('Cancelled'), fontWeight: FontWeight.w500)),
            ),
          if (!wide) ...[
            const SizedBox(height: 12),
            _ContactButtons(consultation: c, compact: true),
          ],
          if (wide && actions.hasAny) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (actions.primary != null) _primaryButton(context, ref, c, actions, isLead),
                if (actions.secondary != null)
                  OutlinedButton.icon(
                    onPressed: () => _run(context, ref, c, actions.secondary!, isLead),
                    icon: Icon(_CallActions.icon(actions.secondary!), size: 18),
                    label: Text(_CallActions.label(actions.secondary!, inviteSent: actions.inviteSent)),
                  ),
                if (actions.more.isNotEmpty) _MoreButton(consultation: c, items: actions.more),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Call / WhatsApp / Client page / Enquiry. [compact] (phone) uses icon
/// buttons for Call and WhatsApp.
class _ContactButtons extends ConsumerWidget {
  const _ContactButtons({required this.consultation, this.compact = false});

  final Consultation consultation;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = consultation;
    final access = ref.watch(effectiveAccessProvider);
    final phone = c.clientPhone;
    final crm = context.crmColors;
    final iconStyle = IconButton.styleFrom(
      foregroundColor: crm.primary,
      backgroundColor: crm.surface,
      side: BorderSide(color: crm.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
    void call() => launchUrl(Uri.parse('tel:$phone'));
    void chat() =>
        launchUrl(Uri.https('wa.me', '/${whatsAppNumber(phone)}'), mode: LaunchMode.externalApplication);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (phone.isNotEmpty && compact) ...[
          IconButton.outlined(
              tooltip: 'Call', style: iconStyle, onPressed: call, icon: const Icon(Icons.call_outlined, size: 20)),
          IconButton.outlined(
              tooltip: 'WhatsApp', style: iconStyle, onPressed: chat, icon: const Icon(Icons.chat_outlined, size: 20)),
        ],
        if (phone.isNotEmpty && !compact) ...[
          OutlinedButton.icon(onPressed: call, icon: const Icon(Icons.call_outlined, size: 18), label: const Text('Call')),
          OutlinedButton.icon(
              onPressed: chat, icon: const Icon(Icons.chat_outlined, size: 18), label: const Text('WhatsApp')),
        ],
        if (!c.client.isEmpty)
          OutlinedButton.icon(
            onPressed: () => context.push('/stylist/clients/${c.client.id}'),
            icon: const Icon(Icons.folder_shared_outlined, size: 18),
            label: const Text('Client page'),
          ),
        if (c.lead.id.isNotEmpty && access.canSeeSub('sales.leads'))
          OutlinedButton.icon(
            onPressed: () => context.push('/sales/leads/${c.lead.id}'),
            icon: const Icon(Icons.person_outline, size: 18),
            label: const Text('Enquiry'),
          ),
      ],
    );
  }
}

// ── Meeting link / location ──────────────────────────────────────────────────
class _MeetingCard extends StatelessWidget {
  const _MeetingCard({required this.consultation});

  final Consultation consultation;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final c = consultation;
    final editable = c.status != 'Cancelled';
    final Widget body;
    if (!c.isVideo) {
      body = Text(c.location.isEmpty ? 'No location set.' : c.location,
          style: TextStyle(color: c.location.isEmpty ? crm.textSecondary : crm.textPrimary));
    } else if (c.meetingLink.isEmpty) {
      body = Text('No meeting link yet. Add the Meet or Zoom link.', style: TextStyle(color: crm.textSecondary));
    } else {
      body = Container(
        padding: const EdgeInsets.only(left: 12),
        decoration: BoxDecoration(color: crm.background, borderRadius: BorderRadius.circular(8)),
        child: Row(
          children: [
            Expanded(child: SelectableText(c.meetingLink, maxLines: 1, style: const TextStyle(fontSize: 13))),
            IconButton(
              tooltip: 'Copy link',
              icon: const Icon(Icons.copy, size: 18),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: c.meetingLink));
                if (context.mounted) showSuccessSnackBar(context, 'Link copied');
              },
            ),
          ],
        ),
      );
    }
    return _card(
      crm,
      title: c.isVideo ? 'Meeting link' : 'Location',
      trailing: editable
          ? TextButton(
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              onPressed: () => showEditMeetingDialog(context, c),
              child: Text(c.isVideo && c.meetingLink.isEmpty ? 'Add link' : 'Edit'),
            )
          : null,
      child: body,
    );
  }
}

// ── Client (desktop) ─────────────────────────────────────────────────────────
class _ClientCard extends StatelessWidget {
  const _ClientCard({required this.consultation});

  final Consultation consultation;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final c = consultation;
    return _card(
      crm,
      title: 'Client',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (c.clientPhone.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.phone_outlined, size: 16, color: crm.textSecondary),
                const SizedBox(width: 8),
                SelectableText(c.clientPhone),
              ],
            ),
            const SizedBox(height: 12),
          ],
          _ContactButtons(consultation: c),
        ],
      ),
    );
  }
}

// ── After-call details ───────────────────────────────────────────────────────
class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.consultation});

  final Consultation consultation;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final c = consultation;
    return _card(
      crm,
      title: 'Call details',
      trailing: c.status == 'Cancelled'
          ? null
          : TextButton(
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              onPressed: () => context.push('/consultations/${c.id}/details'),
              child: Text(c.hasAfterCallDetails ? 'Edit' : 'Add'),
            ),
      child: !c.hasAfterCallDetails
          ? Text(
              c.isScheduled
                  ? "Nothing recorded yet. You'll add requirements, the look, notes and images when you complete the call."
                  : 'Nothing recorded for this call.',
              style: TextStyle(color: crm.textSecondary))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final f in kAfterCallFields)
                  if ((c.afterCallText[f.key] ?? '').isNotEmpty)
                    _labelled(crm, f.label, c.afterCallText[f.key]!, icon: f.icon),
                if (c.referenceImages.isNotEmpty) ...[
                  Text('Reference images (${c.referenceImages.length})',
                      style: TextStyle(fontSize: 12, color: crm.textSecondary)),
                  const SizedBox(height: 8),
                  ReferenceImageGrid(images: c.referenceImages),
                ],
              ],
            ),
    );
  }

  Widget _labelled(CrmTheme crm, String label, String value, {IconData? icon}) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(icon, size: 16, color: crm.primary),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 12, color: crm.textSecondary)),
                  const SizedBox(height: 2),
                  SelectableText(value),
                ],
              ),
            ),
          ],
        ),
      );
}

// ── History (closed until opened) ────────────────────────────────────────────
class _HistoryCard extends StatefulWidget {
  const _HistoryCard({required this.consultation});

  final Consultation consultation;

  @override
  State<_HistoryCard> createState() => _HistoryCardState();
}

class _HistoryCardState extends State<_HistoryCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final history = widget.consultation.history;
    final n = history.length;
    return Container(
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: crm.border),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text('History',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: crm.textPrimary)),
                  ),
                  Text('$n ${n == 1 ? 'change' : 'changes'}', style: TextStyle(color: crm.textSecondary, fontSize: 12)),
                  const SizedBox(width: 6),
                  Icon(_open ? Icons.expand_less : Icons.expand_more, color: crm.textSecondary),
                ],
              ),
            ),
          ),
          if (_open)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Column(children: [for (final h in history.reversed) _tile(crm, h)]),
            ),
        ],
      ),
    );
  }

  Widget _tile(CrmTheme crm, ConsultationHistoryEntry h) {
    final detail = <String>[
      if (h.fromAt != null && h.toAt != null) '${fmtDateTime(h.fromAt!)} → ${fmtDateTime(h.toAt!)}',
      if (h.fromAt == null && h.toAt != null) fmtDateTime(h.toAt!),
      if (h.fields.isNotEmpty) 'changed ${h.fields.map(afterCallFieldLabel).join(', ')}',
      if (h.reason.isNotEmpty) h.reason,
      if (h.overrodeConflict) 'booked over a clash',
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(consultationStatusIcon(h.status), size: 18, color: consultationStatusColor(h.status)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(h.action, style: const TextStyle(fontWeight: FontWeight.w600)),
                if (detail.isNotEmpty)
                  Text(detail.join('  ·  '), style: TextStyle(color: crm.textSecondary, fontSize: 12)),
                Text(
                  '${h.byName.isEmpty ? '' : '${h.byName}  ·  '}${h.at == null ? '' : fmtDateTime(h.at!)}',
                  style: TextStyle(color: crm.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
