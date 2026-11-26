import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/models/employee.dart';
import 'package:nizan_crm/services/employee_service.dart';

/// Add an outside ASSOCIATE artist while assigning a work (Operations) — or pick up the one already on that phone number. The server makes an
/// outsource artist: no login, no payroll; they are paid per work through Artist Payouts and listed in the Associate Works report.
/// Pops `({Employee employee, bool existing})`, or null when cancelled.
Future<({Employee employee, bool existing})?> showAddAssociateDialog(BuildContext context) =>
    showDialog<({Employee employee, bool existing})>(context: context, builder: (_) => const AddAssociateDialog());

class AddAssociateDialog extends ConsumerStatefulWidget {
  const AddAssociateDialog({super.key});

  @override
  ConsumerState<AddAssociateDialog> createState() => _AddAssociateDialogState();
}

class _AddAssociateDialogState extends ConsumerState<AddAssociateDialog> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _spec = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _spec.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.length < 2) {
      setState(() => _error = 'Give the associate’s name.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final r = await ref.read(employeeServiceProvider).addAssociate(name: name, phone: _phone.text, specialization: _spec.text);
      ref.invalidate(employeesProvider); // the staff lists now include them
      if (mounted) Navigator.pop(context, r);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = friendlyErrorMessage(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Add associate artist'),
        content: SizedBox(
          width: 380,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('An outside artist who works this event with your team. Paid per work by Accounts; no login.', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 14),
              TextField(key: const Key('assoc_name'), controller: _name, autofocus: true, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder(), isDense: true)),
              const SizedBox(height: 10),
              TextField(key: const Key('assoc_phone'), controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone (so they are not added twice)', border: OutlineInputBorder(), isDense: true)),
              const SizedBox(height: 10),
              TextField(key: const Key('assoc_spec'), controller: _spec, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Does (optional)', hintText: 'Hair, saree draping…', border: OutlineInputBorder(), isDense: true)),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, key: const Key('assoc_error'), style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ]),
          ),
        ),
        actions: [
          TextButton(key: const Key('assoc_cancel'), onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(key: const Key('assoc_save'), onPressed: _saving ? null : _save, child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Add & assign')),
        ],
      );
}
