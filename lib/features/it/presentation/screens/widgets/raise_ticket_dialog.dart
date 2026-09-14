import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:image_picker/image_picker.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/services/upload_service.dart';
import 'package:nizan_crm/features/it/services/ticket_service.dart';

/// Opens a responsive ticket raising dialog (centered modal on desktop, bottom sheet on mobile).
Future<bool?> showRaiseTicketDialog(
  BuildContext context,
  WidgetRef ref, {
  String? defaultModule,
}) {
  final width = MediaQuery.of(context).size.width;
  final isDesktop = width >= 700;

  if (isDesktop) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: _RaiseTicketCard(defaultModule: defaultModule, isSheet: false),
        ),
      ),
    );
  } else {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _RaiseTicketCard(defaultModule: defaultModule, isSheet: true),
    );
  }
}

class _RaiseTicketCard extends HookConsumerWidget {
  final String? defaultModule;
  final bool isSheet;

  const _RaiseTicketCard({this.defaultModule, this.isSheet = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final titleCtrl = useTextEditingController();
    final descCtrl = useTextEditingController();
    final moduleCtrl = useTextEditingController(text: defaultModule ?? '');
    final selectedType = useState<String>('bug');
    final selectedPriority = useState<String>('medium');
    final screenshots = useState<List<String>>([]);
    final isUploading = useState<bool>(false);
    final isSubmitting = useState<bool>(false);
    final messenger = ScaffoldMessenger.of(context);

    Future<void> submit() async {
      final title = titleCtrl.text.trim();
      if (title.isEmpty) {
        messenger.showSnackBar(const SnackBar(content: Text('Please enter a ticket title')));
        return;
      }

      isSubmitting.value = true;
      try {
        await ref.read(ticketServiceProvider).createTicket({
          'title': title,
          'description': descCtrl.text.trim(),
          'type': selectedType.value,
          'priority': selectedPriority.value,
          'module': moduleCtrl.text.trim(),
          'screenshots': screenshots.value,
        });

        ref.invalidate(ticketsProvider);
        ref.invalidate(ticketStatsProvider);

        if (context.mounted) {
          Navigator.of(context).pop(true);
          messenger.showSnackBar(
            const SnackBar(content: Text('Ticket raised successfully — IT team has been notified')),
          );
        }
      } catch (e) {
        isSubmitting.value = false;
        if (context.mounted) {
          messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
        }
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(isSheet ? 20 : 16),
        border: Border.all(color: crm.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        22,
        18,
        22,
        22 + (isSheet ? MediaQuery.of(context).viewInsets.bottom : 0),
      ),
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
                  child: Icon(Icons.confirmation_number_outlined, color: crm.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Raise a Support Ticket',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: crm.textPrimary,
                        ),
                      ),
                      Text(
                        'Report a bug, request a feature, or ask for IT assistance',
                        style: TextStyle(fontSize: 12, color: crm.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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

            // Title field
            TextField(
              controller: titleCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Title *',
                hintText: 'Short summary of the issue or request',
                prefixIcon: const Icon(Icons.title, size: 18),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 12),

            // Type and Priority Selector in a clean row
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: selectedType.value,
                    decoration: InputDecoration(
                      labelText: 'Type',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'bug',
                        child: Row(children: [
                          Icon(Icons.bug_report_outlined, size: 16, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Bug Report'),
                        ]),
                      ),
                      DropdownMenuItem(
                        value: 'feature',
                        child: Row(children: [
                          Icon(Icons.lightbulb_outline, size: 16, color: Colors.amber),
                          SizedBox(width: 8),
                          Text('Feature Request'),
                        ]),
                      ),
                      DropdownMenuItem(
                        value: 'support',
                        child: Row(children: [
                          Icon(Icons.help_outline, size: 16, color: Colors.blue),
                          SizedBox(width: 8),
                          Text('IT Support'),
                        ]),
                      ),
                    ],
                    onChanged: (v) => selectedType.value = v ?? 'bug',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: selectedPriority.value,
                    decoration: InputDecoration(
                      labelText: 'Priority',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'critical',
                        child: Row(children: [
                          Icon(Icons.circle, size: 12, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Critical (P0)'),
                        ]),
                      ),
                      DropdownMenuItem(
                        value: 'high',
                        child: Row(children: [
                          Icon(Icons.circle, size: 12, color: Colors.orange),
                          SizedBox(width: 8),
                          Text('High (P1)'),
                        ]),
                      ),
                      DropdownMenuItem(
                        value: 'medium',
                        child: Row(children: [
                          Icon(Icons.circle, size: 12, color: Colors.amber),
                          SizedBox(width: 8),
                          Text('Medium (P2)'),
                        ]),
                      ),
                      DropdownMenuItem(
                        value: 'low',
                        child: Row(children: [
                          Icon(Icons.circle, size: 12, color: Colors.green),
                          SizedBox(width: 8),
                          Text('Low (P3)'),
                        ]),
                      ),
                    ],
                    onChanged: (v) => selectedPriority.value = v ?? 'medium',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Module / Area
            TextField(
              controller: moduleCtrl,
              decoration: InputDecoration(
                labelText: 'Module / Area (Optional)',
                hintText: 'e.g., Bookings, Finance, Marketing, IT',
                prefixIcon: const Icon(Icons.grid_view_outlined, size: 18),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 12),

            // Description field
            TextField(
              controller: descCtrl,
              minLines: 3,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Description',
                hintText: 'Steps to reproduce, what you expected, what happened...',
                alignLabelWithHint: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
            const SizedBox(height: 14),

            // Attachment Bar & Thumbnail Previews
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: isUploading.value
                      ? null
                      : () async {
                          final picker = ImagePicker();
                          final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
                          if (file == null) return;
                          isUploading.value = true;
                          try {
                            final url = await ref.read(uploadServiceProvider).uploadImage(file);
                            screenshots.value = [...screenshots.value, url];
                          } catch (e) {
                            messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
                          } finally {
                            isUploading.value = false;
                          }
                        },
                  icon: isUploading.value
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.attach_file, size: 18),
                  label: Text(isUploading.value ? 'Uploading…' : 'Attach Screenshot'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                  ),
                ),
                const SizedBox(width: 12),
                if (screenshots.value.isNotEmpty)
                  Text(
                    '${screenshots.value.length} attached',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: crm.textSecondary),
                  ),
              ],
            ),

            if (screenshots.value.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (int i = 0; i < screenshots.value.length; i++)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: crm.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: crm.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.image, size: 16, color: Colors.blueGrey),
                          const SizedBox(width: 6),
                          Text('Screenshot #${i + 1}', style: const TextStyle(fontSize: 11.5)),
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: () {
                              final list = List<String>.from(screenshots.value);
                              list.removeAt(i);
                              screenshots.value = list;
                            },
                            child: const Padding(
                              padding: EdgeInsets.all(2),
                              child: Icon(Icons.close, size: 14, color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],

            const SizedBox(height: 20),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 44,
              child: FilledButton(
                onPressed: isSubmitting.value ? null : submit,
                style: FilledButton.styleFrom(
                  backgroundColor: crm.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: isSubmitting.value
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        'Submit Ticket',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
