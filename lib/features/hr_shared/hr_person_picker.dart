import 'package:flutter/material.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/hr_shared/hr_ui.dart';

/// One selectable person in the picker.
class PickerItem {
  final String id;
  final String name;
  final String department;
  final String designation;
  const PickerItem({required this.id, required this.name, this.department = '', this.designation = ''});

  String get subtitle =>
      [if (designation.isNotEmpty) designation, if (department.isNotEmpty) department].join(' · ');
}

/// Shows a searchable, department-filterable person picker.
/// Returns: null = cancelled (no change); '' = the "none" option was chosen;
/// otherwise the selected person's id.
Future<String?> showPersonPicker(
  BuildContext context, {
  required String title,
  required List<PickerItem> items,
  String? selectedId,
  bool allowNone = false,
  String noneLabel = 'None',
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _PersonPickerDialog(
      title: title,
      items: items,
      selectedId: selectedId,
      allowNone: allowNone,
      noneLabel: noneLabel,
    ),
  );
}

class _PersonPickerDialog extends StatefulWidget {
  const _PersonPickerDialog({
    required this.title,
    required this.items,
    required this.selectedId,
    required this.allowNone,
    required this.noneLabel,
  });
  final String title;
  final List<PickerItem> items;
  final String? selectedId;
  final bool allowNone;
  final String noneLabel;

  @override
  State<_PersonPickerDialog> createState() => _PersonPickerDialogState();
}

class _PersonPickerDialogState extends State<_PersonPickerDialog> {
  final _search = TextEditingController();
  String _query = '';
  String _dept = 'All';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final departments = <String>{for (final p in widget.items) if (p.department.isNotEmpty) p.department}.toList()..sort();
    final q = _query.trim().toLowerCase();
    var filtered = widget.items.where((p) {
      if (_dept != 'All' && p.department != _dept) return false;
      if (q.isEmpty) return true;
      return p.name.toLowerCase().contains(q) || p.designation.toLowerCase().contains(q) || p.department.toLowerCase().contains(q);
    }).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: SizedBox(
        width: 440,
        height: 520,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 12, 6),
              child: Row(
                children: [
                  Expanded(child: HrTitle(widget.title, size: 16)),
                  IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.of(context).pop()),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _search,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Search by name or title', prefixIcon: Icon(Icons.search), isDense: true),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            if (departments.isNotEmpty)
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
                  children: ['All', ...departments].map((d) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(d),
                        selected: _dept == d,
                        onSelected: (_) => setState(() => _dept = d),
                      ),
                    );
                  }).toList(),
                ),
              ),
            const SizedBox(height: 4),
            Expanded(
              child: filtered.isEmpty && !(widget.allowNone && q.isEmpty)
                  ? Center(child: Text('No matches', style: TextStyle(color: crm.textSecondary)))
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                      children: [
                        if (widget.allowNone)
                          _row(crm, id: '', name: widget.noneLabel, subtitle: '', icon: Icons.block_outlined, selected: (widget.selectedId ?? '').isEmpty),
                        ...filtered.map((p) => _row(crm, id: p.id, name: p.name, subtitle: p.subtitle, selected: p.id == widget.selectedId)),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(CrmTheme crm, {required String id, required String name, required String subtitle, IconData? icon, required bool selected}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).pop(id),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? crm.primary.withValues(alpha: 0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: crm.primary.withValues(alpha: 0.12),
                child: icon != null
                    ? Icon(icon, size: 16, color: crm.primary)
                    : Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: TextStyle(color: crm.primary, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: crm.textPrimary)),
                    if (subtitle.isNotEmpty) Text(subtitle, style: TextStyle(fontSize: 11.5, color: crm.textSecondary)),
                  ],
                ),
              ),
              if (selected) Icon(Icons.check_circle, size: 18, color: crm.primary),
            ],
          ),
        ),
      ),
    );
  }
}

/// A form field that shows the selected person and opens [showPersonPicker].
/// [onChanged] receives the picked id, or null when "none" is chosen/cleared.
class PersonPickerField extends StatelessWidget {
  const PersonPickerField({
    super.key,
    required this.label,
    required this.items,
    required this.selectedId,
    required this.onChanged,
    this.icon,
    this.allowNone = false,
    this.noneLabel = 'None',
    this.hint = 'Tap to choose',
  });
  final String label;
  final IconData? icon;
  final List<PickerItem> items;
  final String? selectedId;
  final bool allowNone;
  final String noneLabel;
  final String hint;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    PickerItem? selected;
    for (final p in items) {
      if (p.id == selectedId) {
        selected = p;
        break;
      }
    }
    final text = selected != null
        ? (selected.subtitle.isEmpty ? selected.name : '${selected.name} · ${selected.subtitle}')
        : null;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () async {
        final res = await showPersonPicker(
          context,
          title: label,
          items: items,
          selectedId: selectedId,
          allowNone: allowNone,
          noneLabel: noneLabel,
        );
        if (res != null) onChanged(res.isEmpty ? null : res);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: icon != null ? Icon(icon) : null,
          suffixIcon: const Icon(Icons.unfold_more, size: 20),
        ),
        child: Text(
          text ?? hint,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 14, color: text != null ? crm.textPrimary : crm.textSecondary),
        ),
      ),
    );
  }
}
