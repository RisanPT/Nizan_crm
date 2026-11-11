import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nizan_crm/core/auth/workspace.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/core/state/data_refresh.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/sales/presentation/screens/sales_leads_screen.dart' show kEventTypes;

import '../../controllers/consultation_provider.dart';
import '../../data/consultation.dart';
import '../../data/stylist_client.dart';
import '../../services/stylist_client_service.dart';
import '../widgets/consultation_ui.dart';

/// Add a client (no [clientId]): a Team N client picked from an enquiry or
/// booking — filled in automatically — or a Nizan client typed in. With
/// [clientId], edits that client's details.
class StylistClientFormScreen extends ConsumerWidget {
  const StylistClientFormScreen({super.key, this.clientId, this.returnToCaller = false});

  final String? clientId;

  /// Opened from the Schedule call form: when the client is added (or turns
  /// out to exist already), go back there with its id instead of opening it.
  final bool returnToCaller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final id = clientId;
    if (id == null) return _ClientForm(existing: null, returnToCaller: returnToCaller);
    return ref.watch(stylistClientProvider(id)).when(
          loading: () => Scaffold(
            backgroundColor: crm.background,
            appBar: AppBar(title: const Text('Edit client')),
            body: const Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Scaffold(
            backgroundColor: crm.background,
            appBar: AppBar(title: const Text('Edit client')),
            body: AppErrorView(error: e, onRetry: () => ref.invalidate(stylistClientProvider(id))),
          ),
          data: (c) => _ClientForm(key: ValueKey(c.id), existing: c),
        );
  }
}

class _ClientForm extends ConsumerStatefulWidget {
  const _ClientForm({super.key, required this.existing, this.returnToCaller = false});

  final StylistClient? existing;
  final bool returnToCaller;

  @override
  ConsumerState<_ClientForm> createState() => _ClientFormState();
}

class _ClientFormState extends ConsumerState<_ClientForm> {
  StylistClient? get _existing => widget.existing;
  bool get _editing => _existing != null;

  late String _company = _existing?.company ?? 'Team N';

  // Team N picker
  final _search = TextEditingController();
  Timer? _debounce;
  List<TeamNCandidate> _results = const [];
  bool _searching = false;
  TeamNCandidate? _picked;

  // Details (Nizan, or editing either kind)
  late final _name = TextEditingController(text: _existing?.name ?? '');
  late final _phone = TextEditingController(text: _existing?.phone ?? '');
  late final _altPhone = TextEditingController(text: _existing?.altPhone ?? '');
  late final _email = TextEditingController(text: _existing?.email ?? '');
  late String _eventType = _existing?.eventType ?? '';
  late final List<DateTime> _eventDays = [...?_existing?.eventDays];
  late final _slot = TextEditingController(text: _existing?.eventSlot ?? '');
  late final _venue = TextEditingController(text: _existing?.venue ?? '');
  late final _district = TextEditingController(text: _existing?.district ?? '');
  late final _culture = TextEditingController(text: _existing?.culture ?? '');
  late final _package = TextEditingController(text: _existing?.packageName ?? '');
  late final _artists = TextEditingController(text: (_existing?.artistNames ?? const []).join(', '));
  late final _outfit = TextEditingController(text: _existing?.outfitDetails ?? '');
  late final _notes = TextEditingController(text: _existing?.notes ?? '');
  late int _requiredCalls = _existing?.requiredCalls ?? kDefaultRequiredCalls;
  String? _stylistId;

  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  @override
  void dispose() {
    _debounce?.cancel();
    for (final c in [
      _search, _name, _phone, _altPhone, _email, _slot, _venue, _district, _culture, _package, _artists, _outfit, _notes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Team N search ─────────────────────────────────────────────────────────
  void _onSearch(String q) {
    _debounce?.cancel();
    if (q.trim().length < 2) {
      setState(() => _results = const []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      setState(() => _searching = true);
      try {
        final found = await ref.read(stylistClientServiceProvider).searchTeamN(q.trim());
        if (mounted) setState(() => _results = found);
      } catch (e) {
        if (mounted) showErrorSnackBar(context, e);
      } finally {
        if (mounted) setState(() => _searching = false);
      }
    });
  }

  void _pick(TeamNCandidate c) {
    if (c.hasClient) {
      if (c.clientIsOwn) {
        _openClient(c.clientId);
      } else {
        showWarningSnackBar(context, '${c.name} is already a client of another stylist');
      }
      return;
    }
    setState(() {
      _picked = c;
      _results = const [];
      _search.clear();
    });
  }

  /// Back to the Schedule call form with the client, or on to the client page.
  void _openClient(String id) {
    if (widget.returnToCaller) {
      context.pop(id);
    } else {
      context.pushReplacement('/stylist/clients/$id');
    }
  }

  // ── Save ──────────────────────────────────────────────────────────────────
  Map<String, dynamic> _details() => {
        'name': _name.text.trim(),
        'phone': _phone.text.trim(),
        'altPhone': _altPhone.text.trim(),
        'email': _email.text.trim(),
        'eventType': _eventType,
        'eventDates': ([..._eventDays]..sort()).map(dayKey).toList(),
        'eventSlot': _slot.text.trim(),
        'venue': _venue.text.trim(),
        'district': _district.text.trim(),
        'culture': _culture.text.trim(),
        'packageName': _package.text.trim(),
        'artistNames': _artists.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
        'outfitDetails': _outfit.text.trim(),
        'notes': _notes.text.trim(),
        'requiredCalls': _requiredCalls,
      };

  Future<void> _save() async {
    final teamNNew = !_editing && _company == 'Team N';
    if (teamNNew && _picked == null) {
      showWarningSnackBar(context, 'Search and choose the Team N client first');
      return;
    }
    if (!teamNNew && !(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    final service = ref.read(stylistClientServiceProvider);
    try {
      final StylistClient saved;
      if (_editing) {
        saved = await service.update(_existing!.id, {
          ..._details(),
          if (_stylistId != null && _stylistId != _existing!.stylistId) 'stylistId': _stylistId,
        });
      } else if (teamNNew) {
        saved = await service.createTeamN(
          from: _picked!,
          requiredCalls: _requiredCalls,
          notes: _notes.text,
          stylistId: _stylistId,
        );
      } else {
        saved = await service.createNizan(_details(), stylistId: _stylistId);
      }
      ref.refreshData.consultations();
      if (!mounted) return;
      showSuccessSnackBar(context, _editing ? 'Client saved' : 'Client added');
      if (_editing) {
        context.pop();
      } else {
        _openClient(saved.id);
      }
    } on ClientExistsException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showWarningSnackBar(context, e.message);
      if (e.clientId.isNotEmpty) _openClient(e.clientId);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showErrorSnackBar(context, e);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final teamNNew = !_editing && _company == 'Team N';

    return Scaffold(
      backgroundColor: crm.background,
      appBar: AppBar(title: Text(_editing ? 'Edit ${_existing!.name}' : 'New client')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                if (!_editing) ...[
                  Text('Which company is this client with?',
                      style: TextStyle(fontWeight: FontWeight.w600, color: crm.textPrimary)),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'Team N', label: Text('Team N'), icon: Icon(Icons.search)),
                      ButtonSegment(value: 'Nizan', label: Text('Nizan'), icon: Icon(Icons.edit_note)),
                    ],
                    selected: {_company},
                    onSelectionChanged: (s) => setState(() => _company = s.first),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    teamNNew
                        ? 'Find the enquiry or booking — the event, package, venue and artists fill in automatically.'
                        : 'Nizan clients are not in the CRM, so enter their details here.',
                    style: TextStyle(color: crm.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                ] else if (_existing!.isTeamN) ...[
                  _note(
                    crm,
                    Icons.sync,
                    'These details came from the Team N booking. "Refresh from booking" on the client page '
                        'puts the booking\'s values back.',
                  ),
                  const SizedBox(height: 16),
                ],
                if (teamNNew) _teamNPicker(crm) else _detailsFields(crm),
                const SizedBox(height: 16),
                _seriesFields(crm),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: BoxDecoration(color: crm.surface, border: Border(top: BorderSide(color: crm.border))),
          child: Row(
            children: [
              const Spacer(),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(_editing ? Icons.save_outlined : Icons.person_add_alt_1_outlined, size: 18),
                label: Text(_editing ? 'Save' : 'Add client'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _note(CrmTheme crm, IconData icon, String text) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: crm.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: crm.primary.withValues(alpha: 0.2)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: crm.primary),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: TextStyle(fontSize: 12, color: crm.textPrimary))),
          ],
        ),
      );

  Widget _card(CrmTheme crm, String title, List<Widget> children) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: crm.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: crm.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: crm.textPrimary)),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      );

  // ── Team N picker ─────────────────────────────────────────────────────────
  Widget _teamNPicker(CrmTheme crm) {
    final picked = _picked;
    if (picked != null) {
      return _card(crm, 'Team N client', [
        Row(
          children: [
            CircleAvatar(child: Text(picked.name.isEmpty ? '?' : picked.name[0].toUpperCase())),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(picked.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(_candidateLine(picked), style: TextStyle(color: crm.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            TextButton(onPressed: () => setState(() => _picked = null), child: const Text('Change')),
          ],
        ),
        const SizedBox(height: 10),
        _note(crm, Icons.auto_awesome_outlined,
            'Event dates, time slot, venue, culture, package, outfit details and assigned artists will be copied from '
            '${picked.bookingNumber.isEmpty ? 'the enquiry' : 'booking ${picked.bookingNumber}'}.'),
      ]);
    }
    return _card(crm, 'Find the Team N client', [
      TextField(
        controller: _search,
        autofocus: true,
        onChanged: _onSearch,
        decoration: InputDecoration(
          hintText: 'Name, phone or booking number',
          prefixIcon: const Icon(Icons.search),
          border: const OutlineInputBorder(),
          isDense: true,
          suffixIcon: _searching
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : null,
        ),
      ),
      for (final r in _results)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(r.bookingNumber.isNotEmpty ? Icons.receipt_long_outlined : Icons.person_outline,
              color: crm.textSecondary),
          title: Text(r.name),
          subtitle: Text(_candidateLine(r), style: const TextStyle(fontSize: 12)),
          trailing: r.hasClient
              ? ConsultationStatusChip(r.clientIsOwn ? 'Open client' : 'Other stylist', color: crm.textSecondary)
              : const Icon(Icons.add_circle_outline),
          onTap: () => _pick(r),
        ),
      if (_results.isEmpty && _search.text.trim().length >= 2 && !_searching)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text('No Team N enquiry or booking matches. For a Nizan client, switch to Nizan above.',
              style: TextStyle(color: crm.textSecondary)),
        ),
    ]);
  }

  String _candidateLine(TeamNCandidate c) => [
        c.phone,
        if (c.eventType.isNotEmpty) c.eventType,
        if (c.eventDate != null) fmtShortDay(c.eventDate!),
        if (c.bookingNumber.isNotEmpty) c.bookingNumber,
      ].join('  ·  ');

  // ── Details ───────────────────────────────────────────────────────────────
  Widget _field(TextEditingController c, String label,
      {String? hint, bool required = false, TextInputType? type, int lines = 1, String? Function(String)? check}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        enabled: !_saving,
        keyboardType: type,
        minLines: lines,
        maxLines: lines == 1 ? 1 : lines + 4,
        textCapitalization: type == null ? TextCapitalization.sentences : TextCapitalization.none,
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          hintText: hint,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        validator: (v) {
          final s = (v ?? '').trim();
          if (required && s.isEmpty) return 'Enter the ${label.toLowerCase()}';
          return check?.call(s);
        },
      ),
    );
  }

  Widget _pair(Widget a, Widget b) => LayoutBuilder(
        builder: (_, box) => box.maxWidth < 520
            ? Column(children: [a, b])
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [Expanded(child: a), const SizedBox(width: 12), Expanded(child: b)],
              ),
      );

  Widget _detailsFields(CrmTheme crm) {
    final types = [...kEventTypes, if (_eventType.isNotEmpty && !kEventTypes.contains(_eventType)) _eventType];
    return Column(
      children: [
        _card(crm, 'Client', [
          _field(_name, 'Name', required: true),
          _pair(
            _field(_phone, 'Phone', required: true, type: TextInputType.phone,
                check: (s) => s.replaceAll(RegExp(r'\D'), '').length < 10 ? 'Enter a valid phone number' : null),
            _field(_altPhone, 'Alternate phone', type: TextInputType.phone),
          ),
          _field(_email, 'Email', type: TextInputType.emailAddress),
        ]),
        const SizedBox(height: 16),
        _card(crm, 'Event', [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: DropdownButtonFormField<String>(
              initialValue: _eventType.isEmpty ? null : _eventType,
              decoration: const InputDecoration(labelText: 'Event type', border: OutlineInputBorder(), isDense: true),
              items: [for (final t in types) DropdownMenuItem(value: t, child: Text(t))],
              onChanged: _saving ? null : (v) => setState(() => _eventType = v ?? ''),
            ),
          ),
          _eventDaysField(crm),
          _pair(
            _field(_slot, 'Time slot', hint: 'Morning, Evening, 6 AM…'),
            _field(_culture, 'Culture / community', hint: 'Hindu, Christian, Muslim…'),
          ),
          _field(_venue, 'Venue', hint: 'Hall or address'),
          _field(_district, 'District'),
        ]),
        const SizedBox(height: 16),
        _card(crm, 'Service', [
          _field(_package, 'Package / service'),
          _field(_artists, 'Artists', hint: 'Names, separated by commas'),
          _field(_outfit, 'Outfit details', hint: 'Saree / lehenga, colours, jewellery', lines: 2),
        ]),
      ],
    );
  }

  Widget _eventDaysField(CrmTheme crm) {
    final sorted = [..._eventDays]..sort();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Event dates', style: TextStyle(fontSize: 12, color: crm.textSecondary)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final d in sorted)
                InputChip(
                  label: Text(fmtDay(d)),
                  onDeleted: _saving ? null : () => setState(() => _eventDays.remove(d)),
                ),
              ActionChip(
                avatar: const Icon(Icons.add, size: 16),
                label: const Text('Add date'),
                onPressed: _saving
                    ? null
                    : () async {
                        final now = DateTime.now();
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: sorted.isEmpty ? now : sorted.last,
                          firstDate: DateTime(now.year - 2),
                          lastDate: DateTime(now.year + 3),
                        );
                        if (picked == null) return;
                        final day = DateTime(picked.year, picked.month, picked.day);
                        if (!_eventDays.contains(day)) setState(() => _eventDays.add(day));
                      },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Series + ownership ────────────────────────────────────────────────────
  Widget _seriesFields(CrmTheme crm) {
    final access = ref.watch(effectiveAccessProvider);
    final isLead = access.canSeeConsultationReports;
    final stylists = isLead ? (ref.watch(consultationStylistsProvider).value ?? const <ConsultationStylist>[]) : const <ConsultationStylist>[];
    final myId = ref.watch(authSessionProvider)?.userId ?? '';
    final owner = _stylistId ?? _existing?.stylistId ?? myId;

    return _card(crm, 'Consultation calls', [
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Required calls', style: TextStyle(fontWeight: FontWeight.w600, color: crm.textPrimary)),
                Text('Usually 4. Calls after these show as extra calls.',
                    style: TextStyle(fontSize: 12, color: crm.textSecondary)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Fewer calls',
            onPressed: _saving || _requiredCalls <= 1 ? null : () => setState(() => _requiredCalls--),
            icon: const Icon(Icons.remove_circle_outline),
          ),
          SizedBox(
            width: 28,
            child: Text('$_requiredCalls',
                textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          IconButton(
            tooltip: 'More calls',
            onPressed: _saving || _requiredCalls >= 10 ? null : () => setState(() => _requiredCalls++),
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
      if (isLead && stylists.length > 1) ...[
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: stylists.any((s) => s.id == owner) ? owner : null,
          decoration: const InputDecoration(labelText: 'Stylist', border: OutlineInputBorder(), isDense: true),
          items: [for (final s in stylists) DropdownMenuItem(value: s.id, child: Text(s.name))],
          onChanged: _saving ? null : (v) => setState(() => _stylistId = v),
        ),
      ],
      const SizedBox(height: 12),
      _field(_notes, 'Notes about the client', hint: 'Anything the team should know', lines: 2),
    ]);
  }
}
