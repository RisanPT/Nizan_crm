import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/features/marketing/data/coordination_models.dart';
import 'package:nizan_crm/features/marketing/presentation/coordinations/coord_widgets.dart';
import 'package:nizan_crm/features/marketing/services/coordination_service.dart';
import 'package:nizan_crm/features/marketing/services/team_service.dart' show TeamFilter;

/// Add a follow-up (what, related to, owner, team, due day, a reminder) or change [followUp]. With the reminder on, the owner is told in the
/// app when it falls due (backend services/marketingCoordReminders.js — once per due day); the Overdue panel still calls late ones out.
Future<void> showFollowUpEditor(BuildContext context, WidgetRef ref, {FollowUpRow? followUp}) => showCoordForm<void>(context, _FollowUpForm(followUp: followUp));

class _FollowUpForm extends ConsumerStatefulWidget {
  const _FollowUpForm({this.followUp});
  final FollowUpRow? followUp;

  @override
  ConsumerState<_FollowUpForm> createState() => _FollowUpFormState();
}

class _FollowUpFormState extends ConsumerState<_FollowUpForm> {
  late final _item = TextEditingController(text: widget.followUp?.item ?? '');
  late final _related = TextEditingController(text: widget.followUp?.relatedTo ?? '');
  late String _owner = widget.followUp?.ownerId ?? '';
  late String _dept = widget.followUp?.department ?? 'Marketing';
  late String _brand = widget.followUp?.brand ?? 'main';
  late String _status = widget.followUp?.status ?? 'open';
  late bool _reminder = widget.followUp?.reminder ?? false;
  late DateTime? _due = DateTime.tryParse(widget.followUp?.dueDate ?? '');
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _item.dispose();
    _related.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_item.text.trim().length < 2) {
      setState(() => _error = 'Say what needs following up.');
      return;
    }
    if (_due == null) {
      setState(() => _error = 'Choose the day it is due.');
      return;
    }
    final editing = widget.followUp != null;
    final body = <String, dynamic>{
      'item': _item.text.trim(),
      'relatedTo': _related.text.trim(),
      if (_owner.isNotEmpty || editing) 'ownerId': _owner.isEmpty ? null : _owner,
      'department': _dept,
      'dueDate': TeamFilter.day(_due!),
      'reminder': _reminder,
      'brand': _brand,
      if (editing && _status != widget.followUp!.status) 'status': _status,
    };
    setState(() {
      _saving = true;
      _error = null;
    });
    final err = await coordWrite(context, ref, () => ref.read(marketingCoordinationServiceProvider).saveFollowUp(body, id: widget.followUp?.id));
    if (!mounted) return;
    if (err == null) {
      Navigator.pop(context);
    } else {
      setState(() {
        _error = err;
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final setup = ref.watch(coordSetupProvider).maybeWhen(data: (s) => s, orElse: () => const CoordSetup());
    final editing = widget.followUp != null;
    // a new follow-up is yours until you say otherwise
    final ownerValue = _owner.isEmpty && !editing && setup.meId != null ? setup.meId! : _owner;
    return CoordFormFrame(
      title: editing ? 'Edit follow-up' : 'Add follow-up',
      keyPrefix: 'co_fu',
      saving: _saving,
      error: _error,
      saveLabel: editing ? 'Save' : 'Add follow-up',
      onSave: () {
        if (_owner.isEmpty && !editing && setup.meId != null) _owner = setup.meId!;
        _save();
      },
      children: [
        TextField(key: const Key('co_fu_item'), controller: _item, decoration: coordDec('Follow-up item', hint: 'Get final content approval')),
        const SizedBox(height: 10),
        TextField(key: const Key('co_fu_related'), controller: _related, decoration: coordDec('Related to (optional)', hint: 'Bridal Campaign')),
        const SizedBox(height: 10),
        CoordPair(
          DropdownButtonFormField<String>(
            key: const Key('co_fu_owner'),
            isExpanded: true,
            initialValue: setup.members.any((m) => m.id == ownerValue) || ownerValue.isEmpty ? ownerValue : null,
            decoration: coordDec('Owner'),
            items: [const DropdownMenuItem(value: '', child: Text('Nobody yet')), for (final m in setup.members) DropdownMenuItem(value: m.id, child: Text(m.name, overflow: TextOverflow.ellipsis))],
            onChanged: (v) => setState(() => _owner = v ?? ''),
          ),
          DropdownButtonFormField<String>(key: const Key('co_fu_dept'), isExpanded: true, initialValue: _dept, decoration: coordDec('Department'), items: [for (final d in setup.departments) DropdownMenuItem(value: d, child: Text(d))], onChanged: (v) => setState(() => _dept = v ?? _dept)),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
          DatePill(pillKey: const Key('co_fu_due'), label: 'Due date', value: _due, onPick: (d) => setState(() => _due = d)),
          SizedBox(width: 150, child: DropdownButtonFormField<String>(key: const Key('co_fu_brand'), isExpanded: true, initialValue: _brand, decoration: coordDec('Brand'), items: const [DropdownMenuItem(value: 'main', child: Text('Main')), DropdownMenuItem(value: 'kerala', child: Text('Kerala'))], onChanged: (v) => setState(() => _brand = v ?? _brand))),
        ]),
        const SizedBox(height: 6),
        SwitchListTile(key: const Key('co_fu_reminder'), contentPadding: EdgeInsets.zero, dense: true, title: const Text('Reminder'), subtitle: const Text('The owner is told in the app when it falls due — once (again if the day moves)'), value: _reminder, onChanged: (v) => setState(() => _reminder = v)),
        if (editing) DropdownButtonFormField<String>(key: const Key('co_fu_status'), isExpanded: true, initialValue: _status, decoration: coordDec('Status'), items: const [DropdownMenuItem(value: 'open', child: Text('Open')), DropdownMenuItem(value: 'done', child: Text('Done'))], onChanged: (v) => setState(() => _status = v ?? _status)),
      ],
    );
  }
}
