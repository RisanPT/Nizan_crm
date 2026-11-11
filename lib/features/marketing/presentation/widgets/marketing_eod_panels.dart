import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import '../../data/marketing_eod_models.dart';
import '../../services/marketing_eod_service.dart';

// Manager-facing panels for the Marketing EOD module's Setup tab (FR-1, FR-2,
// FR-3, FR-4, FR-17), the Weekly Stats tab (FR-18) and the audit viewer (FR-15).

void _snack(BuildContext context, String message, {bool error = false}) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), backgroundColor: error ? Colors.red : Colors.green),
  );
}

String _fmtNum(num v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

Widget _panelCard(CrmTheme crm, {required String title, String? subtitle, Widget? trailing, required Widget child}) {
  return Card(
    elevation: 0,
    color: crm.surface,
    margin: const EdgeInsets.only(bottom: 12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: crm.border),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // On narrow screens the trailing action drops under the title.
          LayoutBuilder(builder: (context, constraints) {
            final heading = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: crm.textPrimary)),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(subtitle, style: TextStyle(fontSize: 12, color: crm.textSecondary)),
                  ),
              ],
            );
            if (trailing != null && constraints.maxWidth < 600) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [heading, const SizedBox(height: 8), trailing],
              );
            }
            return Row(
              children: [
                Expanded(child: heading),
                ?trailing,
              ],
            );
          }),
          const SizedBox(height: 12),
          child,
        ],
      ),
    ),
  );
}

/// Role of [memberId] in [month] from the role history (latest row starting on
/// or before the month).
String _roleNameFor(MarketingSetupData setup, String memberId, String month) {
  String bestFrom = '';
  String name = '';
  for (final r in setup.memberRoles) {
    if (r['memberId']?.toString() != memberId) continue;
    final from = r['fromMonth']?.toString() ?? '';
    if (from.compareTo(month) > 0 || from.compareTo(bestFrom) < 0) continue;
    final role = r['roleId'];
    bestFrom = from;
    name = role is Map ? (role['name']?.toString() ?? '') : '';
  }
  return name;
}

String? _roleIdFor(MarketingSetupData setup, String memberId, String month) {
  String bestFrom = '';
  String? id;
  for (final r in setup.memberRoles) {
    if (r['memberId']?.toString() != memberId) continue;
    final from = r['fromMonth']?.toString() ?? '';
    if (from.compareTo(month) > 0 || from.compareTo(bestFrom) < 0) continue;
    final role = r['roleId'];
    bestFrom = from;
    id = role is Map ? role['_id']?.toString() : role?.toString();
  }
  return id;
}

// ============================================================================
// Settings: calendar, edit window, reminder time, status colours (FR-4, FR-11)
// ============================================================================

class EodSettingsPanel extends ConsumerStatefulWidget {
  final MarketingSetupData setup;
  const EodSettingsPanel({super.key, required this.setup});

  @override
  ConsumerState<EodSettingsPanel> createState() => _EodSettingsPanelState();
}

class _EodSettingsPanelState extends ConsumerState<EodSettingsPanel> {
  late int _weeklyOff;
  late final TextEditingController _hours;
  late final TextEditingController _window;
  late final TextEditingController _reminder;
  late final TextEditingController _green;
  late final TextEditingController _amber;
  bool _saving = false;

  static const _days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

  @override
  void initState() {
    super.initState();
    final c = widget.setup.calendarSettings;
    final t = widget.setup.thresholds;
    _weeklyOff = (c['weeklyOff'] as num?)?.toInt() ?? 0;
    _hours = TextEditingController(text: _fmtNum((c['standardHours'] as num?) ?? 8));
    _window = TextEditingController(text: _fmtNum((c['editWindowDays'] as num?) ?? 2));
    _reminder = TextEditingController(text: c['reminderTime']?.toString() ?? '19:00');
    _green = TextEditingController(text: _fmtNum((t['greenMin'] as num?) ?? 100));
    _amber = TextEditingController(text: _fmtNum((t['amberMin'] as num?) ?? 70));
  }

  @override
  void dispose() {
    for (final c in [_hours, _window, _reminder, _green, _amber]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(marketingEodServiceProvider).saveSettings({
        'weeklyOff': _weeklyOff,
        'standardHours': double.tryParse(_hours.text.trim()),
        'editWindowDays': int.tryParse(_window.text.trim()),
        'reminderTime': _reminder.text.trim(),
        'greenMin': double.tryParse(_green.text.trim()),
        'amberMin': double.tryParse(_amber.text.trim()),
      });
      ref.invalidate(marketingEodSetupProvider);
      if (!mounted) return;
      _snack(context, 'Settings saved.');
    } catch (e) {
      if (!mounted) return;
      _snack(context, 'Could not save settings: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(TextEditingController c, String label, {String? hint, double width = 150}) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: c,
        decoration: InputDecoration(labelText: label, hintText: hint, isDense: true, border: const OutlineInputBorder()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return _panelCard(
      crm,
      title: 'Calendar, edit window & status colours',
      subtitle: 'Weekly off, standard hours, how many days back members may edit, reminder time (IST), Green / Amber cut-offs.',
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 170,
            child: DropdownButtonFormField<int>(
              initialValue: _weeklyOff,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Weekly off', isDense: true, border: OutlineInputBorder()),
              items: [
                for (var i = 0; i < 7; i++)
                  DropdownMenuItem(value: i, child: Text(_days[i], maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) => setState(() => _weeklyOff = v ?? 0),
            ),
          ),
          _field(_hours, 'Standard hours / day'),
          _field(_window, 'Edit window (days)'),
          _field(_reminder, 'Reminder time', hint: '19:00'),
          _field(_green, 'Green from %', width: 120),
          _field(_amber, 'Amber from %', width: 120),
          ElevatedButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save, size: 18),
            label: const Text('Save settings'),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Monthly targets grid (FR-3)
// ============================================================================

class EodTargetsPanel extends ConsumerStatefulWidget {
  final MarketingSetupData setup;
  final String month;
  const EodTargetsPanel({super.key, required this.setup, required this.month});

  @override
  ConsumerState<EodTargetsPanel> createState() => _EodTargetsPanelState();
}

class _EodTargetsPanelState extends ConsumerState<EodTargetsPanel> {
  final Map<String, TextEditingController> _ctrls = {}; // 'memberId|metricId'
  final Map<String, String> _original = {};
  final Map<String, Set<String>> _applicable = {}; // memberId -> metricIds
  bool _loading = true;
  bool _saving = false;
  String? _error;

  List<MarketingTeamMemberModel> get _members => widget.setup.members.where((m) => m.isActive).toList();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant EodTargetsPanel old) {
    super.didUpdateWidget(old);
    if (old.month != widget.month || old.setup.members.length != widget.setup.members.length) {
      _load();
    }
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final svc = ref.read(marketingEodServiceProvider);
      final applicable = <String, Set<String>>{};
      for (final m in _members) {
        final metrics = await svc.getMemberMetrics(m.id, widget.month);
        applicable[m.id] = metrics.map((x) => x.id).toSet();
      }
      final targets = await svc.getTargets(widget.month);
      final byKey = <String, String>{};
      for (final t in targets) {
        final v = t['targetValue'];
        byKey['${t['memberId']}|${t['metricId']}'] = v is num ? _fmtNum(v) : '';
      }
      for (final c in _ctrls.values) {
        c.dispose();
      }
      _ctrls.clear();
      _original.clear();
      for (final m in _members) {
        for (final metricId in applicable[m.id] ?? <String>{}) {
          final key = '${m.id}|$metricId';
          final text = byKey[key] ?? '';
          _original[key] = text;
          _ctrls[key] = TextEditingController(text: text);
        }
      }
      if (!mounted) return;
      setState(() {
        _applicable
          ..clear()
          ..addAll(applicable);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    final changes = <Map<String, dynamic>>[];
    for (final entry in _ctrls.entries) {
      final text = entry.value.text.trim();
      if (text == _original[entry.key]) continue;
      if (text.isNotEmpty && double.tryParse(text) == null) {
        _snack(context, 'Targets must be numbers (or blank).', error: true);
        return;
      }
      final parts = entry.key.split('|');
      changes.add({'memberId': parts[0], 'metricId': parts[1], 'targetValue': text});
    }
    if (changes.isEmpty) {
      _snack(context, 'No target changes to save.');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(marketingEodServiceProvider).saveTargets(widget.month, changes);
      if (!mounted) return;
      _snack(context, 'Saved ${changes.length} target(s) for ${widget.month}.');
      await _load();
    } catch (e) {
      if (!mounted) return;
      _snack(context, 'Could not save targets: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _copyPrevious() async {
    final parts = widget.month.split('-');
    final y = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    final prev = m == 1 ? '${y - 1}-12' : '$y-${(m - 1).toString().padLeft(2, '0')}';
    try {
      await ref.read(marketingEodServiceProvider).copyTargets(prev, widget.month);
      if (!mounted) return;
      _snack(context, 'Targets copied from $prev.');
      await _load();
    } catch (e) {
      if (!mounted) return;
      _snack(context, 'Could not copy targets: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final members = _members;
    final groupOrder = {for (final g in widget.setup.groups) g.id: g.sortOrder};
    final groupName = {for (final g in widget.setup.groups) g.id: g.name};
    final metrics = widget.setup.metrics.where((m) {
      return m.isActive && _applicable.values.any((s) => s.contains(m.id));
    }).toList()
      ..sort((a, b) {
        final g = (groupOrder[a.groupId] ?? 0).compareTo(groupOrder[b.groupId] ?? 0);
        return g != 0 ? g : a.sortOrder.compareTo(b.sortOrder);
      });

    return _panelCard(
      crm,
      title: 'Monthly targets — ${widget.month}',
      subtitle: 'Blank = tracked, no target. A cell shows — where the activity is not in that member\'s set.',
      trailing: Wrap(
        spacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: _loading ? null : _copyPrevious,
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy from previous month'),
          ),
          ElevatedButton.icon(
            onPressed: (_loading || _saving) ? null : _save,
            icon: const Icon(Icons.save, size: 16),
            label: const Text('Save targets'),
          ),
        ],
      ),
      child: _loading
          ? const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
          : _error != null
              ? Text('Could not load targets: $_error', style: TextStyle(color: crm.destructive))
              : metrics.isEmpty
                  ? Text('No activities are assigned to any member for this month.', style: TextStyle(color: crm.textSecondary))
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Table(
                        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                        columnWidths: {
                          0: const FixedColumnWidth(260),
                          for (var i = 0; i < members.length; i++) i + 1: const FixedColumnWidth(86),
                        },
                        children: [
                          TableRow(
                            decoration: BoxDecoration(color: crm.background),
                            children: [
                              const Padding(padding: EdgeInsets.all(8), child: Text('Activity', style: TextStyle(fontWeight: FontWeight.bold))),
                              for (final m in members)
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Text(m.shortName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                ),
                            ],
                          ),
                          for (final metric in metrics)
                            TableRow(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  child: Text(
                                    '${groupName[metric.groupId] ?? ''} · ${metric.name}',
                                    style: TextStyle(fontSize: 12.5, color: crm.textPrimary),
                                  ),
                                ),
                                for (final m in members)
                                  _ctrls.containsKey('${m.id}|${metric.id}')
                                      ? Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                                          child: TextField(
                                            controller: _ctrls['${m.id}|${metric.id}'],
                                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                            textAlign: TextAlign.center,
                                            decoration: const InputDecoration(
                                              isDense: true,
                                              contentPadding: EdgeInsets.all(8),
                                              border: OutlineInputBorder(),
                                            ),
                                          ),
                                        )
                                      : Center(child: Text('—', style: TextStyle(color: crm.textSecondary))),
                              ],
                            ),
                        ],
                      ),
                    ),
    );
  }
}

// ============================================================================
// Groups & activities (FR-2)
// ============================================================================

class EodCataloguePanel extends ConsumerWidget {
  final MarketingSetupData setup;
  const EodCataloguePanel({super.key, required this.setup});

  Future<void> _editGroup(BuildContext context, WidgetRef ref, MarketingGroupModel? group) async {
    final name = TextEditingController(text: group?.name ?? '');
    var active = group?.isActive ?? true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(group == null ? 'Add activity group' : 'Edit activity group'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Group name')),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active'),
                value: active,
                onChanged: (v) => setLocal(() => active = v),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    final text = name.text.trim();
    name.dispose();
    if (ok != true || text.isEmpty) return;
    try {
      await ref.read(marketingEodServiceProvider).saveGroup({
        if (group != null) 'id': group.id,
        'name': text,
        'sortOrder': group?.sortOrder ?? setup.groups.length + 1,
        'isActive': active,
      });
      ref.invalidate(marketingEodSetupProvider);
    } catch (e) {
      if (!context.mounted) return;
      _snack(context, 'Could not save group: $e', error: true);
    }
  }

  Future<void> _editMetric(BuildContext context, WidgetRef ref, MarketingMetricModel? metric) async {
    if (setup.groups.isEmpty) {
      _snack(context, 'Add an activity group first.', error: true);
      return;
    }
    final name = TextEditingController(text: metric?.name ?? '');
    final ceiling = TextEditingController(text: metric?.maxPerDay == null ? '' : _fmtNum(metric!.maxPerDay!));
    var groupId = metric?.groupId ?? setup.groups.first.id;
    var unit = metric?.unitType ?? 'count';
    var inTotal = metric?.inTotalOutput ?? true;
    var active = metric?.isActive ?? true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(metric == null ? 'Add activity' : 'Edit activity'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Activity name')),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: setup.groups.any((g) => g.id == groupId) ? groupId : setup.groups.first.id,
                  decoration: const InputDecoration(labelText: 'Group'),
                  items: [for (final g in setup.groups) DropdownMenuItem(value: g.id, child: Text(g.name))],
                  onChanged: (v) => setLocal(() => groupId = v ?? groupId),
                ),
                DropdownButtonFormField<String>(
                  initialValue: unit,
                  decoration: const InputDecoration(labelText: 'Unit'),
                  items: const [
                    DropdownMenuItem(value: 'count', child: Text('Count')),
                    DropdownMenuItem(value: 'currency', child: Text('Currency (₹)')),
                  ],
                  onChanged: (v) => setLocal(() => unit = v ?? unit),
                ),
                TextField(
                  controller: ceiling,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Usual daily maximum (optional)',
                    helperText: 'Entries above this show a warning',
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Counts toward Total Output'),
                  value: inTotal,
                  onChanged: (v) => setLocal(() => inTotal = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active'),
                  value: active,
                  onChanged: (v) => setLocal(() => active = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    final text = name.text.trim();
    final ceilingText = ceiling.text.trim();
    name.dispose();
    ceiling.dispose();
    if (ok != true || text.isEmpty) return;
    try {
      final nextCode = setup.metrics.fold<int>(0, (m, x) => x.code > m ? x.code : m) + 1;
      await ref.read(marketingEodServiceProvider).saveMetric({
        if (metric != null) 'id': metric.id,
        'groupId': groupId,
        'code': metric?.code ?? nextCode,
        'name': text,
        'unitType': unit,
        'inTotalOutput': inTotal,
        'isActive': active,
        'sortOrder': metric?.sortOrder ?? nextCode,
        'maxPerDay': ceilingText.isEmpty ? null : double.tryParse(ceilingText),
      });
      ref.invalidate(marketingEodSetupProvider);
    } catch (e) {
      if (!context.mounted) return;
      _snack(context, 'Could not save activity: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    return _panelCard(
      crm,
      title: 'Activity groups & catalogue (${setup.metrics.length} activities in ${setup.groups.length} groups)',
      subtitle: 'Tap a group or activity to rename or change it. Past months keep their recorded values.',
      trailing: Wrap(
        spacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: () => _editGroup(context, ref, null),
            icon: const Icon(Icons.create_new_folder_outlined, size: 16),
            label: const Text('Add group'),
          ),
          ElevatedButton.icon(
            onPressed: () => _editMetric(context, ref, null),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add activity'),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final g in setup.groups) ...[
            InkWell(
              onTap: () => _editGroup(context, ref, g),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        g.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.bold, color: g.isActive ? crm.primary : crm.textSecondary),
                      ),
                    ),
                    if (!g.isActive) Text('  (inactive)', style: TextStyle(fontSize: 11, color: crm.textSecondary)),
                    const SizedBox(width: 4),
                    Icon(Icons.edit, size: 13, color: crm.textSecondary),
                  ],
                ),
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final m in setup.metrics.where((m) => m.groupId == g.id))
                  ActionChip(
                    onPressed: () => _editMetric(context, ref, m),
                    label: Text(
                      '${m.code}. ${m.name}${m.unitType == 'currency' ? ' (₹)' : ''}${m.isActive ? '' : ' · inactive'}${m.inTotalOutput ? '' : ' · not in total'}',
                      style: TextStyle(fontSize: 12, color: m.isActive ? crm.textPrimary : crm.textSecondary),
                    ),
                    backgroundColor: crm.background,
                  ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// Roles & role profiles (FR-1, FR-17)
// ============================================================================

class EodRoleProfilesPanel extends ConsumerStatefulWidget {
  final MarketingSetupData setup;
  final String month;
  const EodRoleProfilesPanel({super.key, required this.setup, required this.month});

  @override
  ConsumerState<EodRoleProfilesPanel> createState() => _EodRoleProfilesPanelState();
}

class _EodRoleProfilesPanelState extends ConsumerState<EodRoleProfilesPanel> {
  String? _roleId;
  Set<String> _ticked = {};
  bool _applyToMembers = false;
  bool _saving = false;

  Set<String> _profileFor(String roleId) {
    return widget.setup.roleMetrics
        .where((rm) => rm['roleId']?.toString() == roleId)
        .map((rm) => rm['metricId']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  void _selectRole(String? roleId) {
    setState(() {
      _roleId = roleId;
      _ticked = roleId == null ? {} : _profileFor(roleId);
      _applyToMembers = false;
    });
  }

  Future<void> _addRole() async {
    final name = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add role'),
        content: TextField(controller: name, decoration: const InputDecoration(labelText: 'Role name (e.g. Graphic Designer)')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
        ],
      ),
    );
    final text = name.text.trim();
    name.dispose();
    if (ok != true || text.isEmpty) return;
    try {
      await ref.read(marketingEodServiceProvider).saveRole({
        'name': text,
        'sortOrder': widget.setup.roles.length + 1,
        'isActive': true,
      });
      ref.invalidate(marketingEodSetupProvider);
    } catch (e) {
      if (!mounted) return;
      _snack(context, 'Could not add role: $e', error: true);
    }
  }

  Future<void> _save() async {
    final roleId = _roleId;
    if (roleId == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(marketingEodServiceProvider).saveRoleProfile(
            roleId: roleId,
            metricIds: _ticked.toList(),
            applyToExistingFromMonth: _applyToMembers ? widget.month : null,
          );
      ref.invalidate(marketingEodSetupProvider);
      if (!mounted) return;
      _snack(context, _applyToMembers
          ? 'Profile saved and applied to members with this role from ${widget.month}.'
          : 'Role profile saved. Existing members are unchanged.');
    } catch (e) {
      if (!mounted) return;
      _snack(context, 'Could not save role profile: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final setup = widget.setup;
    final roleId = setup.roles.any((r) => r.id == _roleId) ? _roleId : null;

    return _panelCard(
      crm,
      title: 'Role profiles',
      subtitle: 'The default activities each role reports. Editing a profile never changes existing members unless you choose to apply it.',
      trailing: OutlinedButton.icon(
        onPressed: _addRole,
        icon: const Icon(Icons.badge_outlined, size: 16),
        label: const Text('Add role'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 320,
            child: DropdownButtonFormField<String>(
              initialValue: roleId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Role', isDense: true, border: OutlineInputBorder()),
              items: [
                for (final r in setup.roles)
                  DropdownMenuItem(value: r.id, child: Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: _selectRole,
            ),
          ),
          if (roleId != null) ...[
            const SizedBox(height: 12),
            for (final g in setup.groups)
              if (setup.metrics.any((m) => m.groupId == g.id && m.isActive)) ...[
                Text(g.name, style: TextStyle(fontWeight: FontWeight.bold, color: crm.primary)),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final m in setup.metrics.where((m) => m.groupId == g.id && m.isActive))
                      FilterChip(
                        label: Text(m.name, style: const TextStyle(fontSize: 12)),
                        selected: _ticked.contains(m.id),
                        onSelected: (v) => setState(() => v ? _ticked.add(m.id) : _ticked.remove(m.id)),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text('Also apply to members with this role from ${widget.month} onward'),
              subtitle: const Text('Replaces their activity set from that month; earlier months stay as they were.'),
              value: _applyToMembers,
              onChanged: (v) => setState(() => _applyToMembers = v ?? false),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save, size: 16),
                label: const Text('Save role profile'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// Team members & their activity sets (FR-1, FR-17)
// ============================================================================

class EodMembersPanel extends ConsumerWidget {
  final MarketingSetupData setup;
  final String month;
  const EodMembersPanel({super.key, required this.setup, required this.month});

  Future<void> _editMember(BuildContext context, WidgetRef ref, MarketingTeamMemberModel? member) async {
    if (setup.roles.isEmpty) {
      _snack(context, 'Add a role first.', error: true);
      return;
    }
    List<Map<String, dynamic>> users = const [];
    try {
      users = await ref.read(marketingEodServiceProvider).getLinkableUsers();
    } catch (e) {
      if (!context.mounted) return;
      _snack(context, 'Could not load ERP users (you can still save without a link): $e', error: true);
    }
    if (!context.mounted) return;
    String linkedUserId = member?.userId ?? '';
    final name = TextEditingController(text: member?.name ?? '');
    final shortName = TextEditingController(text: member?.shortName ?? '');
    var roleId = (member == null ? null : _roleIdFor(setup, member.id, month)) ?? setup.roles.first.id;
    var active = member?.isActive ?? true;
    var joined = DateTime.now();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(member == null ? 'Add team member' : 'Edit team member'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Full name')),
                TextField(controller: shortName, decoration: const InputDecoration(labelText: 'Short name (tab label)')),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: setup.roles.any((r) => r.id == roleId) ? roleId : setup.roles.first.id,
                  decoration: InputDecoration(labelText: member == null ? 'Role' : 'Role (from $month)'),
                  items: [for (final r in setup.roles) DropdownMenuItem(value: r.id, child: Text(r.name))],
                  onChanged: (v) => setLocal(() => roleId = v ?? roleId),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: users.any((u) => u['_id']?.toString() == linkedUserId) ? linkedUserId : '',
                  decoration: const InputDecoration(
                    labelText: 'Linked ERP user',
                    helperText: 'Needed for reminders and for the person to see their own EOD',
                  ),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('Not linked')),
                    for (final u in users)
                      DropdownMenuItem(
                        value: u['_id']?.toString() ?? '',
                        child: Text(
                          '${u['name'] ?? ''}  ·  ${u['email'] ?? u['role'] ?? ''}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) => setLocal(() => linkedUserId = v ?? ''),
                ),
                if (member == null)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Joining date'),
                    subtitle: Text(DateFormat('d MMM yyyy').format(joined)),
                    trailing: const Icon(Icons.calendar_today, size: 18),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: joined,
                        firstDate: DateTime(2024),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setLocal(() => joined = picked);
                    },
                  )
                else
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Active'),
                    subtitle: const Text('Turning off keeps all past EODs and dashboards.'),
                    value: active,
                    onChanged: (v) => setLocal(() => active = v),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    final fullName = name.text.trim();
    final short = shortName.text.trim();
    name.dispose();
    shortName.dispose();
    if (ok != true || fullName.isEmpty) return;
    try {
      await ref.read(marketingEodServiceProvider).saveTeamMember({
        if (member != null) 'id': member.id,
        'name': fullName,
        'shortName': short.isEmpty ? fullName : short,
        'roleId': roleId,
        'userId': linkedUserId,
        'month': month,
        if (member == null) 'activeFrom': joined.toIso8601String(),
        if (member == null) 'sortOrder': setup.members.length + 1,
        if (member != null) 'isActive': active,
        // Leaving: stamp the date so later months drop the member automatically.
        if (member != null && !active && member.isActive) 'activeTo': DateTime.now().toIso8601String(),
      });
      ref.invalidate(marketingEodSetupProvider);
    } catch (e) {
      if (!context.mounted) return;
      _snack(context, 'Could not save member: $e', error: true);
    }
  }

  Future<void> _editActivities(BuildContext context, WidgetRef ref, MarketingTeamMemberModel member) async {
    final svc = ref.read(marketingEodServiceProvider);
    List<MarketingMetricModel> current;
    try {
      current = await svc.getMemberMetrics(member.id, month);
    } catch (e) {
      if (!context.mounted) return;
      _snack(context, 'Could not load activities: $e', error: true);
      return;
    }
    if (!context.mounted) return;
    final ticked = current.map((m) => m.id).toSet();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('${member.shortName} — activities from $month'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Applies from $month onward; earlier months are not changed.',
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  for (final g in setup.groups)
                    if (setup.metrics.any((m) => m.groupId == g.id && m.isActive)) ...[
                      Text(g.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Wrap(
                        spacing: 6,
                        children: [
                          for (final m in setup.metrics.where((m) => m.groupId == g.id && m.isActive))
                            FilterChip(
                              label: Text(m.name, style: const TextStyle(fontSize: 12)),
                              selected: ticked.contains(m.id),
                              onSelected: (v) => setLocal(() => v ? ticked.add(m.id) : ticked.remove(m.id)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await svc.saveMemberMetrics(memberId: member.id, metricIds: ticked.toList(), month: month);
      if (!context.mounted) return;
      _snack(context, 'Activity set saved from $month.');
    } catch (e) {
      if (!context.mounted) return;
      _snack(context, 'Could not save activities: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    return _panelCard(
      crm,
      title: 'Team members',
      subtitle: 'Add people, change a role, or set exactly which activities one person reports.',
      trailing: ElevatedButton.icon(
        onPressed: () => _editMember(context, ref, null),
        icon: const Icon(Icons.person_add_alt, size: 16),
        label: const Text('Add member'),
      ),
      child: Column(
        children: [
          for (final m in setup.members)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(
                m.name,
                style: TextStyle(fontWeight: FontWeight.w600, color: m.isActive ? crm.textPrimary : crm.textSecondary),
              ),
              subtitle: Text(
                '${m.shortName} · ${_roleNameFor(setup, m.id, month).isEmpty ? 'No role' : _roleNameFor(setup, m.id, month)}${m.isActive ? '' : ' · inactive'}${m.userId == null || m.userId!.isEmpty ? ' · not linked to a user' : ''}',
              ),
              trailing: Wrap(
                spacing: 4,
                children: [
                  TextButton(onPressed: () => _editActivities(context, ref, m), child: const Text('Activities')),
                  IconButton(
                    tooltip: 'Edit member',
                    icon: const Icon(Icons.edit, size: 18),
                    onPressed: () => _editMember(context, ref, m),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// Audit log viewer (FR-15)
// ============================================================================

Future<void> showEodAuditLog(BuildContext context, WidgetRef ref) async {
  List<Map<String, dynamic>> logs;
  try {
    logs = await ref.read(marketingEodServiceProvider).getAuditLog(limit: 150);
  } catch (e) {
    if (!context.mounted) return;
    _snack(context, 'Could not load the audit log: $e', error: true);
    return;
  }
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('EOD audit log (latest 150)'),
      content: SizedBox(
        width: 720,
        height: 480,
        child: logs.isEmpty
            ? const Center(child: Text('No changes recorded yet.'))
            : ListView.separated(
                itemCount: logs.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final l = logs[i];
                  final at = DateTime.tryParse(l['at']?.toString() ?? '')?.toLocal();
                  final when = at == null ? '' : DateFormat('d MMM yyyy, h:mm a').format(at);
                  final field = l['field']?.toString() ?? '';
                  final reason = l['reason']?.toString() ?? '';
                  return ListTile(
                    dense: true,
                    title: Text('${l['table']}${field.isEmpty || field == 'general' ? '' : ' · $field'}'),
                    subtitle: Text('${l['userName'] ?? 'System'} · $when${reason.isEmpty ? '' : '\n$reason'}'),
                    isThreeLine: reason.isNotEmpty,
                  );
                },
              ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
    ),
  );
}

// ============================================================================
// Weekly page performance (FR-18)
// ============================================================================

class EodWeeklyStatsPanel extends ConsumerStatefulWidget {
  final String month;
  final MarketingEodAccess access;
  const EodWeeklyStatsPanel({super.key, required this.month, required this.access});

  @override
  ConsumerState<EodWeeklyStatsPanel> createState() => _EodWeeklyStatsPanelState();
}

class _EodWeeklyStatsPanelState extends ConsumerState<EodWeeklyStatsPanel> {
  static const _weeks = ['W1', 'W2', 'W3', 'W4', 'W5'];
  static const _pages = [
    ('makeovers', 'Team N Makeovers (Organic)'),
    ('kerala', 'Team N Kerala (Paid / Availability)'),
  ];
  static const _fields = ['postsPublished', 'reach', 'engagement'];

  final Map<String, TextEditingController> _ctrls = {}; // 'page|week|field'
  String? _memberId;
  String _loadedKey = '';
  bool _loading = false;
  String? _error;

  String? get _effectiveMemberId => _memberId ?? widget.access.memberId;

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _ctrl(String key) => _ctrls.putIfAbsent(key, () => TextEditingController());

  Future<void> _load() async {
    final memberId = _effectiveMemberId;
    if (memberId == null) return;
    final key = '$memberId|${widget.month}';
    if (key == _loadedKey || _loading) return;
    _loadedKey = key;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final stats = await ref.read(marketingEodServiceProvider).getWeeklyPageStats(memberId: memberId, month: widget.month);
      for (final c in _ctrls.values) {
        c.text = '';
      }
      for (final s in stats) {
        final base = '${s['page']}|${s['weekBlock']}';
        for (final f in _fields) {
          final v = s[f];
          if (v is num && v > 0) _ctrl('$base|$f').text = _fmtNum(v);
        }
      }
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
        _loadedKey = '';
      });
    }
  }

  Future<void> _saveWeek(String page, String week) async {
    final memberId = _effectiveMemberId;
    if (memberId == null) return;
    int val(String f) => int.tryParse(_ctrl('$page|$week|$f').text.trim()) ?? 0;
    try {
      await ref.read(marketingEodServiceProvider).saveWeeklyPageStats({
        'memberId': memberId,
        'month': widget.month,
        'weekBlock': week,
        'page': page,
        'postsPublished': val('postsPublished'),
        'reach': val('reach'),
        'engagement': val('engagement'),
      });
      if (!mounted) return;
      _snack(context, '$week saved.');
    } catch (e) {
      if (!mounted) return;
      _snack(context, 'Could not save $week: $e', error: true);
    }
  }

  Widget _numField(String key, String label) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: TextField(
          controller: _ctrl(key),
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: label, isDense: true, border: const OutlineInputBorder()),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final setup = ref.watch(marketingEodSetupProvider).value;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });

    if (_effectiveMemberId == null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'No marketing team member is linked to your login, so there is nothing to enter here.',
          style: TextStyle(color: crm.textSecondary),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.access.isManager && setup != null && setup.members.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SizedBox(
              width: 260,
              child: DropdownButtonFormField<String>(
                initialValue: setup.members.any((m) => m.id == _effectiveMemberId) ? _effectiveMemberId : setup.members.first.id,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Member', isDense: true, border: OutlineInputBorder()),
                items: [
                  for (final m in setup.members)
                    DropdownMenuItem(value: m.id, child: Text(m.shortName, maxLines: 1, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) {
                  setState(() {
                    _memberId = v;
                    _loadedKey = '';
                  });
                },
              ),
            ),
          ),
        if (_error != null) Text('Could not load weekly stats: $_error', style: TextStyle(color: crm.destructive)),
        if (_loading) const LinearProgressIndicator(),
        for (final (pageKey, pageTitle) in _pages)
          _panelCard(
            crm,
            title: pageTitle,
            subtitle: '${widget.month} · weekly blocks W1 = 1–7, W2 = 8–14, W3 = 15–21, W4 = 22–28, W5 = 29–end',
            child: Column(
              children: [
                for (final week in _weeks)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        SizedBox(width: 36, child: Text(week, style: const TextStyle(fontWeight: FontWeight.bold))),
                        _numField('$pageKey|$week|postsPublished', 'Posts published'),
                        _numField('$pageKey|$week|reach', 'Reach'),
                        _numField('$pageKey|$week|engagement', 'Engagement'),
                        IconButton(
                          tooltip: 'Save $week',
                          icon: Icon(Icons.save, color: crm.primary),
                          onPressed: () => _saveWeek(pageKey, week),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
