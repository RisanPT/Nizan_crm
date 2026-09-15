import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/widgets/employee_picker.dart';
import 'package:nizan_crm/services/upload_service.dart';
import 'package:nizan_crm/features/it/domain/models/okr_model.dart';
import 'package:nizan_crm/features/it/presentation/controllers/okr_notifier.dart';
import 'package:nizan_crm/features/it/services/it_service.dart';

Future<bool?> showOKREditorDialog(
  BuildContext context,
  WidgetRef ref, {
  required String? projectId,
  OKRModel? existing,
  String? parentObjectiveId,
  // When provided (Company Planning Dashboard), the editor shows a "Scope"
  // dropdown (Company-wide + these departments) and writes `department` on the
  // OKR. projectId stays null for these planning objectives.
  List<String>? planningDepartments,
}) {
  final width = MediaQuery.of(context).size.width;
  final isDesktop = width >= 720;

  return showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isDesktop ? 680 : width * 0.95),
        child: _OKREditorForm(
          projectId: projectId,
          existing: existing,
          parentObjectiveId: parentObjectiveId,
          planningDepartments: planningDepartments,
        ),
      ),
    ),
  );
}

const _companyScopeValue = 'Company';

class _OKREditorForm extends HookConsumerWidget {
  final String? projectId;
  final OKRModel? existing;
  final String? parentObjectiveId;
  final List<String>? planningDepartments;

  const _OKREditorForm({
    this.projectId,
    this.existing,
    this.parentObjectiveId,
    this.planningDepartments,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final isEdit = existing != null;
    final employees = ref.watch(projectEmployeesProvider(projectId));

    final objectiveCtrl = useTextEditingController(text: existing?.objective ?? '');
    final descCtrl = useTextEditingController(text: existing?.description ?? '');
    final krInputCtrl = useTextEditingController();

    final status = useState<OKRStatus>(existing?.status ?? OKRStatus.inProgress);
    final priority = useState<OKRPriority>(existing?.priority ?? OKRPriority.high);
    final progress = useState<int>(existing?.progress ?? 0);
    final projectHeadId = useState<String?>(existing?.projectHeadId);
    final projectHeadName = useState<String>(existing?.projectHeadName ?? '');

    final startDate = useState<DateTime?>(existing?.startDate);
    final deadline = useState<DateTime?>(existing?.deadline);

    // Planning scope (company-wide vs a department) — dashboard mode only.
    final planningMode = planningDepartments != null;
    final scope = useState<String>(
      (existing?.department.isNotEmpty ?? false) ? existing!.department : _companyScopeValue,
    );

    final keyResults = useState<List<KeyResultItem>>(
      existing?.keyResults ?? const [],
    );
    final documents = useState<List<OKRDocument>>(
      existing?.documents ?? const [],
    );

    final isSaving = useState<bool>(false);
    final isUploading = useState<bool>(false);
    final messenger = ScaffoldMessenger.of(context);

    Future<void> save() async {
      final title = objectiveCtrl.text.trim();
      if (title.isEmpty) {
        messenger.showSnackBar(const SnackBar(content: Text('Please enter an objective title')));
        return;
      }

      isSaving.value = true;
      try {
        final payload = {
          'objective': title,
          'description': descCtrl.text.trim(),
          'status': status.value.slug,
          'priority': priority.value.slug,
          'progress': progress.value,
          'projectHeadId': projectHeadId.value,
          'projectHeadName': projectHeadName.value,
          'startDate': startDate.value?.toIso8601String(),
          'deadline': deadline.value?.toIso8601String(),
          'keyResults': keyResults.value.map((e) => e.toJson()).toList(),
          'documents': documents.value.map((e) => e.toJson()).toList(),
          if (parentObjectiveId != null) 'parentObjectiveId': parentObjectiveId,
          if (planningMode) 'department': scope.value,
        };

        final notifier = ref.read(projectOKRsNotifierProvider(projectId).notifier);
        if (isEdit) {
          await notifier.updateOKRField(existing!.id, payload);
        } else {
          await notifier.addOKR(payload);
        }

        if (context.mounted) {
          Navigator.of(context).pop(true);
          messenger.showSnackBar(
            SnackBar(content: Text(isEdit ? 'Objective updated' : 'Objective created')),
          );
        }
      } catch (e) {
        isSaving.value = false;
        if (context.mounted) {
          messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
        }
      }
    }

    void addKeyResult() {
      final text = krInputCtrl.text.trim();
      if (text.isEmpty) return;
      keyResults.value = [
        ...keyResults.value,
        KeyResultItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: text,
          metric: text,
        ),
      ];
      krInputCtrl.clear();
    }

    return Container(
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: crm.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: crm.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text('🎯', style: TextStyle(fontSize: 18)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEdit ? 'Edit Objective & KR' : 'New Objective & Key Result',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: crm.textPrimary,
                        ),
                      ),
                      Text(
                        'Set measurable targets and track project outcomes',
                        style: TextStyle(fontSize: 12, color: crm.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Close',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Objective Title
            TextField(
              controller: objectiveCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Objective *',
                hintText: 'e.g., Pan India 25-26, 2.5K Shoots, 2.5 Cr',
                prefixIcon: const Icon(Icons.flag_outlined, size: 18),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 12),

            // Scope (Company Planning Dashboard only): company-wide or a department.
            if (planningMode) ...[
              DropdownButtonFormField<String>(
                initialValue: [_companyScopeValue, ...planningDepartments!].contains(scope.value)
                    ? scope.value
                    : _companyScopeValue,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Scope',
                  prefixIcon: const Icon(Icons.hub_outlined, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                items: [
                  const DropdownMenuItem(value: _companyScopeValue, child: Text('Company-wide')),
                  for (final d in planningDepartments!) DropdownMenuItem(value: d, child: Text(d)),
                ],
                onChanged: (v) {
                  if (v != null) scope.value = v;
                },
              ),
              const SizedBox(height: 12),
            ],

            // Project Head / Assignee
            EmployeePickerField(
              employees: employees,
              selectedId: projectHeadId.value,
              selectedName: projectHeadName.value,
              label: 'Project Head',
              icon: Icons.person_outline,
              onChanged: (e) {
                projectHeadId.value = e?.id;
                projectHeadName.value = e?.name ?? '';
              },
            ),
            const SizedBox(height: 12),

            // Status, Priority & Progress Row
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<OKRStatus>(
                    initialValue: status.value,
                    decoration: InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    items: [
                      for (final s in OKRStatus.values)
                        DropdownMenuItem(
                          value: s,
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(shape: BoxShape.circle, color: s.color),
                              ),
                              const SizedBox(width: 8),
                              Text(s.label),
                            ],
                          ),
                        ),
                    ],
                    onChanged: (v) {
                      if (v != null) status.value = v;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<OKRPriority>(
                    initialValue: priority.value,
                    decoration: InputDecoration(
                      labelText: 'Priority',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    items: [
                      for (final p in OKRPriority.values)
                        DropdownMenuItem(
                          value: p,
                          child: Row(
                            children: [
                              Icon(Icons.traffic_rounded, size: 15, color: p.color),
                              const SizedBox(width: 8),
                              Text(p.label),
                            ],
                          ),
                        ),
                    ],
                    onChanged: (v) {
                      if (v != null) priority.value = v;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Dates (Starting Date & Deadline)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: startDate.value ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                        builder: (ctx, child) => Theme(
                          data: Theme.of(ctx).copyWith(
                            colorScheme: ColorScheme.light(
                              primary: crm.primary,
                              onPrimary: Colors.white,
                              onSurface: crm.textPrimary,
                              surface: crm.surface,
                            ),
                          ),
                          child: child!,
                        ),
                      );
                      if (picked != null) startDate.value = picked;
                    },
                    icon: const Icon(Icons.calendar_today_outlined, size: 16),
                    label: Text(
                      startDate.value == null
                          ? 'Starting Date'
                          : 'Start: ${DateFormat('dd/MM/yyyy').format(startDate.value!)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: deadline.value ?? startDate.value ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                        builder: (ctx, child) => Theme(
                          data: Theme.of(ctx).copyWith(
                            colorScheme: ColorScheme.light(
                              primary: crm.primary,
                              onPrimary: Colors.white,
                              onSurface: crm.textPrimary,
                              surface: crm.surface,
                            ),
                          ),
                          child: child!,
                        ),
                      );
                      if (picked != null) deadline.value = picked;
                    },
                    icon: const Icon(Icons.event_outlined, size: 16),
                    label: Text(
                      deadline.value == null
                          ? 'Deadline'
                          : 'Due: ${DateFormat('dd/MM/yyyy').format(deadline.value!)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Progress Slider
            Row(
              children: [
                const Text('Progress:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: crm.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${progress.value}%',
                    style: TextStyle(fontWeight: FontWeight.w800, color: crm.primary, fontSize: 12),
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: progress.value.toDouble(),
                    min: 0,
                    max: 100,
                    divisions: 100,
                    activeColor: crm.primary,
                    onChanged: (v) => progress.value = v.round(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Key Results Section
            Text(
              "Key Results (KR's)",
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: crm.textPrimary),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: krInputCtrl,
                    decoration: InputDecoration(
                      hintText: 'e.g., Number of Branches, Sales Turnover, Traction...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    onSubmitted: (_) => addKeyResult(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: addKeyResult,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add KR'),
                  style: FilledButton.styleFrom(
                    backgroundColor: crm.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
            if (keyResults.value.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (int i = 0; i < keyResults.value.length; i++)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: crm.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🎯', style: TextStyle(fontSize: 11)),
                          const SizedBox(width: 5),
                          Text(keyResults.value[i].title, style: const TextStyle(fontSize: 12)),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () {
                              final list = List<KeyResultItem>.from(keyResults.value);
                              list.removeAt(i);
                              keyResults.value = list;
                            },
                            child: const Icon(Icons.close, size: 14, color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 16),

            // Documents / Attachments
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: isUploading.value
                      ? null
                      : () async {
                          final picker = ImagePicker();
                          final file = await picker.pickImage(source: ImageSource.gallery);
                          if (file == null) return;
                          isUploading.value = true;
                          try {
                            final url = await ref.read(uploadServiceProvider).uploadImage(file);
                            documents.value = [
                              ...documents.value,
                              OKRDocument(name: file.name.isNotEmpty ? file.name : 'Attachment', url: url),
                            ];
                          } catch (e) {
                            messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
                          } finally {
                            isUploading.value = false;
                          }
                        },
                  icon: isUploading.value
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.attach_file, size: 16),
                  label: Text(isUploading.value ? 'Uploading…' : 'Attach Document / PDF'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
            if (documents.value.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (int i = 0; i < documents.value.length; i++)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.picture_as_pdf, size: 14, color: Colors.blue),
                          const SizedBox(width: 5),
                          Text(
                            documents.value[i].name,
                            style: const TextStyle(fontSize: 11.5, color: Colors.blue, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () {
                              final list = List<OKRDocument>.from(documents.value);
                              list.removeAt(i);
                              documents.value = list;
                            },
                            child: const Icon(Icons.close, size: 13, color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 22),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 44,
              child: FilledButton(
                onPressed: isSaving.value ? null : save,
                style: FilledButton.styleFrom(
                  backgroundColor: crm.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: isSaving.value
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        isEdit ? 'Save Changes' : 'Create Objective',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
