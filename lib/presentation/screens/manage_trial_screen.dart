import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/extensions/space_extension.dart';
import '../../core/models/trial.dart';
import '../../core/models/booking.dart' show BookingAssignment;
import '../../core/models/employee.dart';
import '../../core/providers/trial_provider.dart';
import '../../core/models/trial_package.dart';
import '../../core/providers/trial_package_provider.dart';
import '../../core/theme/crm_theme.dart';
import '../../services/employee_service.dart';
import '../../services/trial_service.dart';

// ── Outcome config ─────────────────────────────────────────────────────────
const _outcomes = [
  ('pending', 'Pending', Color(0xFF6B7280), Icons.hourglass_empty_outlined),
  ('approved', 'Approved', Color(0xFF10B981), Icons.check_circle_outline),
  ('needs_revision', 'Needs Revision', Color(0xFFF59E0B), Icons.edit_outlined),
  ('rejected', 'Rejected', Color(0xFFEF4444), Icons.cancel_outlined),
];

const _statusOptions = [
  ('scheduled', 'Scheduled', Color(0xFF6366F1), Icons.event_available_outlined),
  ('completed', 'Completed', Color(0xFF10B981), Icons.check_circle_outline),
  ('postponed', 'Postponed', Color(0xFFF59E0B), Icons.schedule_outlined),
  ('cancelled', 'Cancelled', Color(0xFFEF4444), Icons.cancel_outlined),
];

const _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

// ── Screen ─────────────────────────────────────────────────────────────────
class ManageTrialScreen extends ConsumerStatefulWidget {
  final String trialId; // 'new' for creation

  const ManageTrialScreen({super.key, required this.trialId});

  @override
  ConsumerState<ManageTrialScreen> createState() => _ManageTrialScreenState();
}

class _ManageTrialScreenState extends ConsumerState<ManageTrialScreen> {
  bool _isNew = false;
  bool _isSaving = false;
  bool _isDeleting = false;
  bool _loaded = false;

  // Client
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  // Appointment
  DateTime _trialDate = DateTime.now();
  String _startTime = '';
  String _endTime = '';
  final _notesCtrl = TextEditingController();

  // Status
  String _status = 'scheduled';

  // Trial items
  final List<TextEditingController> _packageNameCtrls = [];
  final List<TextEditingController> _lookLabelCtrls = [];
  final List<TextEditingController> _itemNotesCtrls = [];
  final List<TextEditingController> _itemPriceCtrls = [];
  final List<String> _outcomes = [];

  // Assigned artists (exact booking-style flow).
  List<BookingAssignment> _assigned = [];
  String _assignType = 'lead'; // lead | assistant
  String? _assignArtistId;

  @override
  void initState() {
    super.initState();
    _isNew = widget.trialId == 'new';
    if (_isNew) {
      _loaded = true;
      _addItem(); // start with one empty item
    }
  }

  void _populate(Trial t) {
    _nameCtrl.text = t.clientName;
    _phoneCtrl.text = t.phone;
    _emailCtrl.text = t.email;
    _trialDate = t.trialDate;
    _startTime = t.startTime;
    _endTime = t.endTime;
    _notesCtrl.text = t.notes;
    _status = t.status;
    _assigned = List.of(t.assignedStaff);
    _assignType =
        _assigned.any((a) => a.roleType.toLowerCase() == 'lead')
            ? 'assistant'
            : 'lead';

    // Clear existing item controllers
    for (final c in _packageNameCtrls) { c.dispose(); }
    for (final c in _lookLabelCtrls) { c.dispose(); }
    for (final c in _itemNotesCtrls) { c.dispose(); }
    for (final c in _itemPriceCtrls) { c.dispose(); }
    _packageNameCtrls.clear();
    _lookLabelCtrls.clear();
    _itemNotesCtrls.clear();
    _itemPriceCtrls.clear();
    _outcomes.clear();

    if (t.trialItems.isEmpty) {
      _addItem();
    } else {
      for (final item in t.trialItems) {
        _packageNameCtrls.add(TextEditingController(text: item.packageName));
        _lookLabelCtrls.add(TextEditingController(text: item.lookLabel));
        _itemNotesCtrls.add(TextEditingController(text: item.notes));
        _itemPriceCtrls.add(TextEditingController(text: item.price > 0 ? item.price.toString() : ''));
        _outcomes.add(item.outcome);
      }
    }
  }

  void _addItem() {
    _packageNameCtrls.add(TextEditingController());
    _lookLabelCtrls.add(TextEditingController());
    _itemNotesCtrls.add(TextEditingController());
    _itemPriceCtrls.add(TextEditingController());
    _outcomes.add('pending');
    setState(() {});
  }

  void _removeItem(int i) {
    _packageNameCtrls[i].dispose();
    _lookLabelCtrls[i].dispose();
    _itemNotesCtrls[i].dispose();
    _itemPriceCtrls[i].dispose();
    _packageNameCtrls.removeAt(i);
    _lookLabelCtrls.removeAt(i);
    _itemNotesCtrls.removeAt(i);
    _itemPriceCtrls.removeAt(i);
    _outcomes.removeAt(i);
    setState(() {});
  }

  List<TrialItem> _buildTrialItems() {
    return List.generate(_packageNameCtrls.length, (i) {
      return TrialItem(
        packageName: _packageNameCtrls[i].text.trim(),
        lookLabel: _lookLabelCtrls[i].text.trim(),
        notes: _itemNotesCtrls[i].text.trim(),
        outcome: _outcomes[i],
        price: double.tryParse(_itemPriceCtrls[i].text.trim()) ?? 0.0,
      );
    }).where((item) => item.packageName.isNotEmpty || item.lookLabel.isNotEmpty).toList();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _notesCtrl.dispose();
    for (final c in _packageNameCtrls) { c.dispose(); }
    for (final c in _lookLabelCtrls) { c.dispose(); }
    for (final c in _itemNotesCtrls) { c.dispose(); }
    for (final c in _itemPriceCtrls) { c.dispose(); }
    super.dispose();
  }

  // ── Save ───────────────────────────────────────────────────────────────
  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty || _phoneCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and mobile are required')),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      final service = ref.read(trialServiceProvider);
      final trial = Trial(
        id: _isNew ? '' : widget.trialId,
        clientName: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        trialDate: _trialDate,
        startTime: _startTime,
        endTime: _endTime,
        status: _status,
        notes: _notesCtrl.text.trim(),
        trialItems: _buildTrialItems(),
        assignedStaff: _assigned,
      );

      if (_isNew) {
        await service.createTrial(trial);
      } else {
        await service.updateTrial(trial);
      }

      ref.read(trialsRefreshTriggerProvider.notifier).update((s) => s + 1);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isNew ? 'Trial created successfully' : 'Trial updated'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Delete ─────────────────────────────────────────────────────────────
  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Trial'),
        content: const Text('Are you sure you want to delete this trial? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isDeleting = true);
    try {
      await ref.read(trialServiceProvider).deleteTrial(widget.trialId);
      ref.read(trialsRefreshTriggerProvider.notifier).update((s) => s + 1);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Trial deleted'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  // ── Date picker ────────────────────────────────────────────────────────
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _trialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) setState(() => _trialDate = picked);
  }

  // ── Time picker ────────────────────────────────────────────────────────
  Future<void> _pickTime({required bool isStart}) async {
    final parts = (isStart ? _startTime : _endTime).split(':');
    final init = TimeOfDay(
      hour: parts.isNotEmpty ? (int.tryParse(parts[0]) ?? 9) : 9,
      minute: parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0,
    );
    final picked = await showTimePicker(context: context, initialTime: init);
    if (picked != null) {
      final formatted =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      setState(() {
        if (isStart) {
          _startTime = formatted;
        } else {
          _endTime = formatted;
        }
      });
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final crmColors = context.crmColors;
    
    // Fetch trial packages for the dropdown
    final asyncPackages = ref.watch(trialPackagesProvider);
    final trialPackages = asyncPackages.value ?? [];

    if (!_loaded && _isNew == false) {
      final asyncTrial = ref.watch(singleTrialProvider(widget.trialId));
      return Scaffold(
        backgroundColor: crmColors.background,
        // _buildAppBar returns a Container header (not a real AppBar), so it
        // lives inside the body Column — never in the appBar slot.
        body: Column(
          children: [
            _buildAppBar(context, crmColors),
            Expanded(
              child: asyncTrial.when(
                data: (trial) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && !_loaded) {
                      setState(() {
                        if (trial != null) _populate(trial);
                        _loaded = true;
                      });
                    }
                  });
                  return _loaded
                      ? _buildBody(crmColors, trialPackages)
                      : const SizedBox();
                },
                loading: () => Center(
                    child: CircularProgressIndicator(color: crmColors.primary)),
                error: (err, _) => Center(
                    child: Text('Error: $err',
                        style: TextStyle(color: crmColors.destructive))),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: crmColors.background,
      body: _buildBody(crmColors, trialPackages),
    );
  }

  Widget _buildBody(CrmTheme crmColors, List<TrialPackage> trialPackages) {
    return Column(
      children: [
        _buildAppBar(context, crmColors),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildClientSection(crmColors),
                24.h,
                _buildAppointmentSection(crmColors),
                24.h,
                _buildPackagesSection(crmColors, trialPackages),
                24.h,
                _buildAssignSection(crmColors),
                24.h,
                _buildStatusSection(crmColors),
                24.h,
                _buildActions(context, crmColors),
                32.h,
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── App bar ────────────────────────────────────────────────────────────
  Widget _buildAppBar(BuildContext context, CrmTheme crmColors) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 24, 16),
      decoration: BoxDecoration(
        color: crmColors.surface,
        border: Border(bottom: BorderSide(color: crmColors.border)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.pop(),
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                size: 20, color: crmColors.textPrimary),
          ),
          12.w,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isNew ? 'New Trial' : 'Manage Trial',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: crmColors.textPrimary,
                ),
              ),
              if (!_isNew)
                Text(
                  _nameCtrl.text,
                  style: TextStyle(
                      fontSize: 12, color: crmColors.textSecondary),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Section card wrapper ───────────────────────────────────────────────
  Widget _sectionCard(CrmTheme crmColors,
      {required String title, required IconData icon, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: crmColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: crmColors.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                Icon(icon, size: 18, color: const Color(0xFF8B5CF6)),
                10.w,
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: crmColors.textPrimary,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 24, color: crmColors.border),
          Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), child: child),
        ],
      ),
    );
  }

  // ── Input field ────────────────────────────────────────────────────────
  Widget _field(
    CrmTheme crmColors, {
    required String label,
    required TextEditingController controller,
    String? hint,
    bool required = false,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: crmColors.textSecondary,
                letterSpacing: 0.5),
            children: required
                ? [
                    const TextSpan(
                        text: ' *',
                        style: TextStyle(color: Color(0xFFEF4444)))
                  ]
                : [],
          ),
        ),
        6.h,
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: TextStyle(fontSize: 14, color: crmColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                TextStyle(color: crmColors.textSecondary.withValues(alpha: 0.6)),
            filled: true,
            fillColor: crmColors.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: crmColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: crmColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: Color(0xFF8B5CF6), width: 1.5),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }

  // ── Section 1: Client ──────────────────────────────────────────────────
  Widget _buildClientSection(CrmTheme crmColors) {
    return _sectionCard(
      crmColors,
      title: 'CLIENT DETAILS',
      icon: Icons.person_outline,
      child: Column(
        children: [
          _field(crmColors,
              label: 'Client Name',
              controller: _nameCtrl,
              hint: 'e.g. Priya Nair',
              required: true),
          16.h,
          _field(crmColors,
              label: 'Mobile',
              controller: _phoneCtrl,
              hint: '+91 9876543210',
              required: true,
              keyboardType: TextInputType.phone),
          16.h,
          _field(crmColors,
              label: 'Email',
              controller: _emailCtrl,
              hint: 'Optional',
              keyboardType: TextInputType.emailAddress),
        ],
      ),
    );
  }

  // ── Section 2: Appointment ─────────────────────────────────────────────
  Widget _buildAppointmentSection(CrmTheme crmColors) {
    return _sectionCard(
      crmColors,
      title: 'APPOINTMENT',
      icon: Icons.calendar_month_outlined,
      child: Column(
        children: [
          // Date picker
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  text: 'TRIAL DATE',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: crmColors.textSecondary,
                      letterSpacing: 0.5),
                  children: const [
                    TextSpan(
                        text: ' *',
                        style: TextStyle(color: Color(0xFFEF4444)))
                  ],
                ),
              ),
              6.h,
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: crmColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: crmColors.border),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_outlined,
                          size: 16, color: const Color(0xFF8B5CF6)),
                      10.w,
                      Text(
                        '${_trialDate.day} ${_monthNames[_trialDate.month - 1]} ${_trialDate.year}',
                        style: TextStyle(
                            fontSize: 14,
                            color: crmColors.textPrimary),
                      ),
                      const Spacer(),
                      Icon(Icons.arrow_drop_down,
                          color: crmColors.textSecondary),
                    ],
                  ),
                ),
              ),
            ],
          ),
          16.h,
          // Times
          Row(
            children: [
              Expanded(child: _timeButton(crmColors, 'START TIME', _startTime, isStart: true)),
              12.w,
              Expanded(child: _timeButton(crmColors, 'END TIME', _endTime, isStart: false)),
            ],
          ),
          16.h,
          _field(crmColors,
              label: 'Notes',
              controller: _notesCtrl,
              hint: 'Internal notes about this appointment…',
              maxLines: 3),
        ],
      ),
    );
  }

  Widget _timeButton(CrmTheme crmColors, String label, String value,
      {required bool isStart}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: crmColors.textSecondary,
              letterSpacing: 0.5),
        ),
        6.h,
        GestureDetector(
          onTap: () => _pickTime(isStart: isStart),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: crmColors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: crmColors.border),
            ),
            child: Row(
              children: [
                Icon(Icons.access_time_outlined,
                    size: 15, color: const Color(0xFF8B5CF6)),
                8.w,
                Text(
                  value.isEmpty ? 'Set time' : value,
                  style: TextStyle(
                    fontSize: 13,
                    color: value.isEmpty
                        ? crmColors.textSecondary.withValues(alpha: 0.6)
                        : crmColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Icon(Icons.arrow_drop_down,
                    color: crmColors.textSecondary, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Section 3: Trial Packages ──────────────────────────────────────────
  Widget _buildPackagesSection(CrmTheme crmColors, List<TrialPackage> trialPackages) {
    return _sectionCard(
      crmColors,
      title: 'TRIAL PACKAGES',
      icon: Icons.checkroom_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add each package/look the client will try during this appointment.',
            style: TextStyle(fontSize: 12, color: crmColors.textSecondary),
          ),
          16.h,
          ...List.generate(
            _packageNameCtrls.length,
            (i) => _PackageItemCard(
              index: i,
              total: _packageNameCtrls.length,
              packageNameCtrl: _packageNameCtrls[i],
              lookLabelCtrl: _lookLabelCtrls[i],
              notesCtrl: _itemNotesCtrls[i],
              priceCtrl: _itemPriceCtrls[i],
              outcome: _outcomes[i],
              crmColors: crmColors,
              trialPackages: trialPackages,
              onOutcomeChanged: (v) => setState(() => _outcomes[i] = v),
              onRemove: _packageNameCtrls.length > 1 ? () => _removeItem(i) : null,
              onPriceChanged: () => setState(() {}),
            ),
          ),
          16.h,
          // Total Amount row
          Builder(
            builder: (context) {
              double totalAmount = 0;
              for (final ctrl in _itemPriceCtrls) {
                totalAmount += double.tryParse(ctrl.text.trim()) ?? 0.0;
              }
              return Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Total Amount:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: crmColors.textSecondary,
                    ),
                  ),
                  12.w,
                  Text(
                    '₹${totalAmount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: crmColors.primary,
                    ),
                  ),
                ],
              );
            },
          ),
          16.h,
          // Add package button
          GestureDetector(
            onTap: _addItem,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                    style: BorderStyle.solid),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_circle_outline,
                      size: 18, color: Color(0xFF8B5CF6)),
                  SizedBox(width: 8),
                  Text(
                    'Add Package',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF8B5CF6)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Artist Assignment Flow (exact booking style) ───────────────────────
  Widget _buildAssignSection(CrmTheme crm) {
    final isNarrow = MediaQuery.of(context).size.width < 900;
    final artists = (ref.watch(employeesProvider).value ?? const <Employee>[])
        .where((e) =>
            e.status.toLowerCase() == 'active' &&
            (e.artistRole.toLowerCase() == 'artist' ||
                e.artistRole.toLowerCase() == 'assistant'))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final assignedIds = _assigned.map((a) => a.employeeId).toSet();
    final hasLead = _assigned.any((a) => a.roleType.toLowerCase() == 'lead');

    // Filter selectable staff by the chosen type + exclude already-assigned.
    final selectable = artists.where((e) {
      final role = e.artistRole.toLowerCase();
      final okForType = _assignType == 'lead' ? role == 'artist' : true;
      return okForType && !assignedIds.contains(e.id);
    }).toList();

    return _sectionCard(
      crm,
      title: 'ARTIST ASSIGNMENT FLOW',
      icon: Icons.people_alt_outlined,
      child: Flex(
        direction: isNarrow ? Axis.vertical : Axis.horizontal,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: isNarrow ? 0 : 1, child: _assignedTeamPane(crm)),
          if (isNarrow) 20.h else 24.w,
          Expanded(
              flex: isNarrow ? 0 : 1,
              child: _assignFormPane(crm, selectable, hasLead)),
        ],
      ),
    );
  }

  Widget _assignedTeamPane(CrmTheme crm) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('CURRENT ASSIGNED TEAM',
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: crm.textSecondary,
                letterSpacing: 1.2)),
        16.h,
        if (_assigned.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              border: Border.all(color: crm.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text('NO ARTISTS ASSIGNED YET',
                  style: TextStyle(
                      color: crm.textSecondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            ),
          )
        else
          ..._assigned.map((a) => _assignmentBlock(crm, a)),
      ],
    );
  }

  Widget _assignmentBlock(CrmTheme crm, BookingAssignment a) {
    final isLead = a.roleType.toLowerCase() == 'lead';
    final accent = isLead ? Colors.amber : Colors.indigo;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: crm.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border(left: BorderSide(color: accent, width: 4)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(a.artistName,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  8.w,
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(isLead ? 'LEAD' : 'ASSISTANT',
                        style: TextStyle(
                            fontSize: 9,
                            color: accent,
                            fontWeight: FontWeight.bold)),
                  ),
                ]),
                4.h,
                Text(a.phone.isNotEmpty ? a.phone : 'Artist',
                    style: TextStyle(
                        fontSize: 10,
                        color: crm.textSecondary,
                        fontWeight: FontWeight.bold)),
              ],
            ),
            TextButton(
              onPressed: () => setState(() {
                _assigned.removeWhere((x) => x.employeeId == a.employeeId);
                if (isLead) _assignType = 'lead';
              }),
              child: const Text('REMOVE',
                  style: TextStyle(
                      color: Colors.red,
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _assignFormPane(CrmTheme crm, List<Employee> selectable, bool hasLead) {
    final isLead = _assignType == 'lead';
    final accent = isLead ? Colors.amber : Colors.indigo;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: crm.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(width: 4, height: 16, color: Colors.indigo),
            8.w,
            Text('ASSIGN TEAM MEMBER',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: crm.textSecondary,
                    letterSpacing: 1.2)),
          ]),
          16.h,
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accent.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(isLead ? 'ASSIGN LEAD ARTIST' : 'ADD ASSISTANT',
                        style: TextStyle(
                            fontSize: 9,
                            color: accent,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2)),
                    Row(children: [
                      _typeChip('LEAD', 'lead', Colors.amber, enabled: !hasLead),
                      8.w,
                      _typeChip('ASST', 'assistant', Colors.indigo,
                          enabled: hasLead),
                    ]),
                  ],
                ),
                12.h,
                if (selectable.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: crm.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: crm.border),
                    ),
                    child: Text(
                        isLead
                            ? 'No active artists available as lead.'
                            : 'No staff available to add.',
                        style: TextStyle(
                            color: crm.textSecondary, fontSize: 12)),
                  )
                else
                  DropdownButtonFormField<String>(
                    key: ValueKey(
                        'assign-$_assignType-${selectable.map((e) => e.id).join(',')}'),
                    initialValue: null,
                    isExpanded: true,
                    items: selectable
                        .map((e) => DropdownMenuItem(
                            value: e.id, child: Text(e.name)))
                        .toList(),
                    onChanged: (v) => setState(() => _assignArtistId = v),
                    decoration: InputDecoration(
                        hintText: isLead
                            ? 'Select lead artist…'
                            : 'Select assistant…',
                        isDense: true,
                        border: const OutlineInputBorder()),
                  ),
                12.h,
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _assignArtistId == null
                        ? null
                        : () => _addAssignment(selectable),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(isLead ? 'Assign lead' : 'Add assistant'),
                  ),
                ),
              ],
            ),
          ),
          16.h,
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: crm.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: crm.border),
            ),
            child: Text(
                'Note: a trial must have one Lead Artist before Assistants can be added.',
                style: TextStyle(
                    fontSize: 10,
                    color: crm.textSecondary,
                    fontStyle: FontStyle.italic)),
          ),
        ],
      ),
    );
  }

  Widget _typeChip(String label, String value, Color color,
      {bool enabled = true}) {
    final selected = _assignType == value;
    return GestureDetector(
      onTap: enabled
          ? () => setState(() {
                _assignType = value;
                _assignArtistId = null;
              })
          : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: selected ? color : color.withValues(alpha: 0.3)),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: color)),
        ),
      ),
    );
  }

  void _addAssignment(List<Employee> selectable) {
    final e = selectable.cast<Employee?>().firstWhere(
        (x) => x?.id == _assignArtistId,
        orElse: () => null);
    if (e == null) return;
    setState(() {
      _assigned.add(BookingAssignment(
        employeeId: e.id,
        artistName: e.name,
        phone: e.phone,
        role: _assignType == 'lead' ? 'Lead Artist' : 'Assistant',
        type: 'artist',
        roleType: _assignType,
      ));
      _assignArtistId = null;
      // After adding the lead, default the next add to assistant.
      if (_assignType == 'lead') _assignType = 'assistant';
    });
  }

  // ── Section 4: Status ──────────────────────────────────────────────────
  Widget _buildStatusSection(CrmTheme crmColors) {
    return _sectionCard(
      crmColors,
      title: 'OVERALL STATUS',
      icon: Icons.flag_outlined,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _statusOptions.map((opt) {
          final (value, label, color, icon) = opt;
          final isSelected = _status == value;
          return GestureDetector(
            onTap: () => setState(() => _status = value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? color.withValues(alpha: 0.15)
                    : crmColors.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? color : crmColors.border,
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon,
                      size: 15, color: isSelected ? color : crmColors.textSecondary),
                  8.w,
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? color : crmColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Actions ────────────────────────────────────────────────────────────
  Widget _buildActions(BuildContext context, CrmTheme crmColors) {
    return Row(
      children: [
        if (!_isNew) ...[
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _isDeleting ? null : _delete,
              icon: _isDeleting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.red))
                  : const Icon(Icons.delete_outline, size: 18),
              label: const Text('Delete'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFEF4444),
                side: const BorderSide(color: Color(0xFFEF4444)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          16.w,
        ],
        Expanded(
          flex: 2,
          child: FilledButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save_outlined, size: 18),
            label: Text(_isNew ? 'Create Trial' : 'Save Changes'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Package Item Card ─────────────────────────────────────────────────────
class _PackageItemCard extends StatelessWidget {
  final int index;
  final int total;
  final TextEditingController packageNameCtrl;
  final TextEditingController lookLabelCtrl;
  final TextEditingController notesCtrl;
  final TextEditingController priceCtrl;
  final String outcome;
  final CrmTheme crmColors;
  final List<TrialPackage> trialPackages;
  final ValueChanged<String> onOutcomeChanged;
  final VoidCallback? onRemove;
  final VoidCallback? onPriceChanged;

  const _PackageItemCard({
    required this.index,
    required this.total,
    required this.packageNameCtrl,
    required this.lookLabelCtrl,
    required this.notesCtrl,
    required this.priceCtrl,
    required this.outcome,
    required this.crmColors,
    required this.trialPackages,
    required this.onOutcomeChanged,
    this.onRemove,
    this.onPriceChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: index < total - 1 ? 12 : 0),
      decoration: BoxDecoration(
        color: const Color(0xFF8B5CF6).withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Package ${index + 1}',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                ),
                const Spacer(),
                if (onRemove != null)
                  GestureDetector(
                    onTap: onRemove,
                    child: Icon(Icons.close,
                        size: 18, color: crmColors.textSecondary),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Package name
                _label('PACKAGE NAME'),
                6.h,
                DropdownButtonFormField<String>(
                  initialValue: trialPackages.any((p) => p.name == packageNameCtrl.text)
                      ? packageNameCtrl.text
                      : (packageNameCtrl.text.isEmpty ? null : packageNameCtrl.text),
                  items: trialPackages.map((pkg) {
                    return DropdownMenuItem(
                      value: pkg.name,
                      child: Text(pkg.name),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      packageNameCtrl.text = val;
                      final selectedPkg = trialPackages.firstWhere((p) => p.name == val);
                      priceCtrl.text = selectedPkg.price.toString();
                      if (onPriceChanged != null) onPriceChanged!();
                    }
                  },
                  style: TextStyle(fontSize: 13, color: crmColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Select a Trial Package',
                    hintStyle: TextStyle(
                        color: crmColors.textSecondary.withValues(alpha: 0.6),
                        fontSize: 13),
                    filled: true,
                    fillColor: crmColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: crmColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: crmColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: crmColors.primary),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                12.h,
                // Look label & Price row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('LOOK LABEL'),
                          6.h,
                          _textField(context, lookLabelCtrl,
                              hint: 'e.g. Bridal Look, Reception Look'),
                        ],
                      ),
                    ),
                    12.w,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('PRICE (₹)'),
                          6.h,
                          _textField(context, priceCtrl,
                              hint: '0.00',
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              onChanged: (_) {
                                if (onPriceChanged != null) onPriceChanged!();
                              }),
                        ],
                      ),
                    ),
                  ],
                ),
                12.h,
                // Notes
                _label('NOTES'),
                6.h,
                _textField(context, notesCtrl,
                    hint: 'Feedback, adjustments needed…', maxLines: 2),
                12.h,
                // Outcome buttons
                _label('OUTCOME'),
                8.h,
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _outcomes.map((opt) {
                    final (value, label, color, icon) = opt;
                    final isSelected = outcome == value;
                    return GestureDetector(
                      onTap: () => onOutcomeChanged(value),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? color.withValues(alpha: 0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? color : crmColors.border,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon,
                                size: 12,
                                color: isSelected
                                    ? color
                                    : crmColors.textSecondary),
                            5.w,
                            Text(
                              label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isSelected
                                    ? color
                                    : crmColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: crmColors.textSecondary,
            letterSpacing: 0.6),
      );

  Widget _textField(
    BuildContext context,
    TextEditingController ctrl, {
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    ValueChanged<String>? onChanged,
  }) {
    final crmColors = context.crmColors;
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: TextStyle(fontSize: 13, color: crmColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
            color: crmColors.textSecondary.withValues(alpha: 0.6),
            fontSize: 13),
        filled: true,
        fillColor: crmColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: crmColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: crmColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:
              const BorderSide(color: Color(0xFF8B5CF6), width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}
