import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/sales/services/enquiry_count_service.dart';
import 'package:nizan_crm/features/sales/services/sales_eod_service.dart';
import 'package:nizan_crm/features/sales/services/sales_overview_service.dart';

/// "Today's enquiries" — the TEAM'S shared count: each morning someone in
/// sales types how many enquiries came in on each channel (Instagram,
/// WhatsApp, …). It is one number for the whole team — if Safana enters it,
/// Malavika sees the same and can correct it. Next to each count we show how
/// many leads the sales team actually saved, so a missing lead stands out.
/// The Sales EOD uses these counts for its lead figures. Any past day can be
/// edited; every change is logged.
class EnquiryCountCard extends ConsumerStatefulWidget {
  const EnquiryCountCard({super.key});

  @override
  ConsumerState<EnquiryCountCard> createState() => _EnquiryCountCardState();
}

class _EnquiryCountCardState extends ConsumerState<EnquiryCountCard> {
  DateTime _day = DateTime.now();
  final Map<String, TextEditingController> _ctrls = {};
  String? _loadedFor; // date key the controllers were filled from
  bool _saving = false;
  bool _expanded = false;
  bool _showHistory = false;

  String get _key => enquiryDateKey(_day);

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Field text as loaded from the server — used to send only what this
  /// person changed, so two people editing at once don't overwrite each
  /// other's channels with stale numbers.
  final Map<String, String> _loadedText = {};
  bool _loadedEntered = false;

  void _fill(MyEnquiryCounts data) {
    if (_loadedFor == data.date) return;
    _loadedFor = data.date;
    _loadedEntered = data.entered;
    for (final ch in data.channels) {
      final c = _ctrls.putIfAbsent(ch, TextEditingController.new);
      final v = data.counts[ch] ?? 0;
      c.text = data.entered ? '$v' : '';
      _loadedText[ch] = c.text;
    }
  }

  Future<void> _pickDay() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(now.year - 1, now.month, 1),
      lastDate: now, // never a future day
    );
    if (picked != null && mounted) {
      setState(() {
        _day = picked;
        _loadedFor = null;
      });
    }
  }

  Future<void> _save(List<String> channels) async {
    // First entry of the day: save every channel (blank = 0). Afterwards:
    // only the channels this person actually changed.
    final counts = <String, int>{
      for (final ch in channels)
        if (!_loadedEntered || (_ctrls[ch]?.text.trim() ?? '') != (_loadedText[ch] ?? '').trim())
          ch: int.tryParse(_ctrls[ch]?.text.trim() ?? '') ?? 0,
    };
    if (counts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nothing changed')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(enquiryCountServiceProvider).saveMine(_key, counts);
      _loadedFor = null;
      ref.invalidate(myEnquiryCountsProvider(_key));
      // Everything that shows the shared count: every verification range
      // (dashboard card, any period) and every cached Sales EOD (screen, PDF,
      // CSV, WhatsApp text).
      ref.invalidate(enquiryVerificationProvider);
      ref.invalidate(salesEodReportProvider);
      ref.invalidate(salesOverviewProvider); // Sales Dashboard
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Team enquiry counts saved — everyone in sales now sees these numbers')),
        );
      }
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final asyncMine = ref.watch(myEnquiryCountsProvider(_key));
    final asyncCheck = ref.watch(enquiryVerificationProvider((from: _key, to: _key)));
    final isToday = enquiryDateKey(DateTime.now()) == _key;

    // Leads the sales team saved that day, per channel (team-wide, like the
    // count itself).
    final savedByChannel = <String, int>{
      for (final c in asyncCheck.value?.channels ?? const <EnquiryChannelCheck>[]) c.channel: c.leads,
    };

    return Container(
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: crm.border),
      ),
      padding: const EdgeInsets.all(16),
      child: asyncMine.when(
        loading: () => const SizedBox(
          height: 80,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        error: (e, _) => Text(friendlyErrorMessage(e),
            style: TextStyle(color: crm.destructive, fontSize: 12)),
        data: (data) {
          _fill(data);
          final savedTotal = savedByChannel.values.fold(0, (s, v) => s + v);
          // Main channels first; the rest behind "More channels".
          const main = ['IG Leads — Main Page', 'IG Leads — Kerala Page', 'WhatsApp (Organic)'];
          final shown = _expanded
              ? data.channels
              : data.channels.where(main.contains).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.forum_outlined, size: 18, color: crm.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isToday ? "Today's enquiries (team)" : 'Team enquiries',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 15, color: crm.textPrimary),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _pickDay,
                    icon: const Icon(Icons.calendar_today_outlined, size: 14),
                    label: Text(DateFormat('d MMM yyyy').format(_day)),
                  ),
                ],
              ),
              Text(
                'One shared count for the whole sales team — anyone can enter or correct it. '
                'It is used for the EOD lead counts and checked against the leads saved in the CRM.',
                style: TextStyle(fontSize: 11.5, color: crm.textSecondary),
              ),
              const SizedBox(height: 12),
              for (final ch in shown)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(ch,
                            style: TextStyle(fontSize: 13, color: crm.textPrimary)),
                      ),
                      SizedBox(
                        width: 72,
                        child: TextField(
                          controller: _ctrls.putIfAbsent(ch, TextEditingController.new),
                          enabled: data.canEdit && !_saving,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(5),
                          ],
                          textAlign: TextAlign.center,
                          decoration: const InputDecoration(
                            isDense: true,
                            hintText: '0',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 78,
                        child: Text(
                          'saved: ${savedByChannel[ch] ?? 0}',
                          style: TextStyle(fontSize: 11.5, color: crm.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => setState(() => _expanded = !_expanded),
                  child: Text(_expanded ? 'Fewer channels' : 'More channels'),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      data.entered
                          ? 'Entered ${data.total} · saved as leads $savedTotal'
                              '${data.updatedAt != null ? ' · updated ${data.updatedByName.isNotEmpty ? 'by ${data.updatedByName} ' : ''}${DateFormat('d MMM, h:mm a').format(data.updatedAt!)}' : ''}'
                          : 'Not entered yet for this day',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: data.entered ? crm.textSecondary : crm.warning,
                        fontWeight: data.entered ? FontWeight.normal : FontWeight.w600,
                      ),
                    ),
                  ),
                  if (data.canEdit)
                    FilledButton(
                      onPressed: _saving ? null : () => _save(data.channels),
                      child: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Save'),
                    ),
                ],
              ),
              // Who changed the shared count, and when.
              if (data.history.isNotEmpty) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _showHistory = !_showHistory),
                    icon: Icon(_showHistory ? Icons.expand_less : Icons.history, size: 16),
                    label: Text(_showHistory
                        ? 'Hide change history'
                        : 'Change history (${data.history.length})'),
                  ),
                ),
                if (_showHistory)
                  for (final h in data.history)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '${h.at != null ? DateFormat('d MMM, h:mm a').format(h.at!) : ''} · '
                        '${h.byName.isEmpty ? 'Someone' : h.byName}: ${h.channel} '
                        '${h.from == null ? 'set to ${h.to}' : '${h.from} → ${h.to}'}',
                        style: TextStyle(fontSize: 11.5, color: crm.textSecondary),
                      ),
                    ),
              ],
            ],
          );
        },
      ),
    );
  }
}
