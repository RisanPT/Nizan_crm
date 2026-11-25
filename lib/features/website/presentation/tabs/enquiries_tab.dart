import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/website/data/website_models.dart';
import 'package:nizan_crm/features/website/services/website_service.dart';

const _statuses = {
  'new': 'New',
  'contacted': 'Contacted',
  'closed': 'Closed',
  'spam': 'Spam',
};
const _slots = {
  'morning': 'Morning',
  'day': 'Church Wedding / Daytime',
  'evening': 'Evening',
  'fullday': 'Full Day',
};

/// Booking requests and messages sent from the website. Each one is already a
/// Lead in Sales (new number) or a note on the existing Lead (known number).
class EnquiriesTab extends ConsumerStatefulWidget {
  const EnquiriesTab({super.key});

  @override
  ConsumerState<EnquiriesTab> createState() => _EnquiriesTabState();
}

class _EnquiriesTabState extends ConsumerState<EnquiriesTab> {
  String _status = 'new';
  int _page = 1;

  ({String status, int page}) get _key => (status: _status, page: _page);

  Future<void> _update(WebsiteEnquiry e, {String? status, String? note}) async {
    try {
      await ref
          .read(websiteServiceProvider)
          .updateEnquiry(e.id, status: status, note: note);
      ref.invalidate(websiteEnquiriesProvider);
    } catch (err) {
      if (mounted) showErrorSnackBar(context, err);
    }
  }

  Future<void> _editNote(WebsiteEnquiry e) async {
    final ctrl = TextEditingController(text: e.note);
    final note = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Note — ${e.name}'),
        content: TextField(
          controller: ctrl,
          maxLength: 500,
          maxLines: 4,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (note != null) await _update(e, note: note);
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final async = ref.watch(websiteEnquiriesProvider(_key));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in [..._statuses.keys, ''])
                ChoiceChip(
                  label: Text(
                    s.isEmpty
                        ? 'All'
                        : '${_statuses[s]}${async.value?.counts[s] != null ? ' (${async.value!.counts[s]})' : ''}',
                  ),
                  selected: _status == s,
                  onSelected: (_) => setState(() {
                    _status = s;
                    _page = 1;
                  }),
                ),
            ],
          ),
        ),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => AppErrorView(
              error: e,
              onRetry: () => ref.invalidate(websiteEnquiriesProvider),
            ),
            data: (page) {
              if (page.items.isEmpty) {
                return Center(
                  child: Text(
                    _status == 'new'
                        ? 'No new enquiries. Website requests appear here.'
                        : 'Nothing here.',
                    style: TextStyle(color: crm.textSecondary),
                  ),
                );
              }
              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(websiteEnquiriesProvider),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final e in page.items)
                      _EnquiryCard(
                        enquiry: e,
                        onStatus: (s) => _update(e, status: s),
                        onNote: () => _editNote(e),
                      ),
                    if (page.pages > 1)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: _page > 1
                                ? () => setState(() => _page -= 1)
                                : null,
                            icon: const Icon(Icons.chevron_left),
                          ),
                          Text('Page ${page.page} of ${page.pages}'),
                          IconButton(
                            onPressed: _page < page.pages
                                ? () => setState(() => _page += 1)
                                : null,
                            icon: const Icon(Icons.chevron_right),
                          ),
                        ],
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _EnquiryCard extends StatelessWidget {
  final WebsiteEnquiry enquiry;
  final ValueChanged<String> onStatus;
  final VoidCallback onNote;

  const _EnquiryCard({
    required this.enquiry,
    required this.onStatus,
    required this.onNote,
  });

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final e = enquiry;
    final when = e.createdAt == null
        ? ''
        : DateFormat('d MMM, h:mm a').format(e.createdAt!);
    final (leadText, leadColor) = switch (e.leadAction) {
      'created' => ('New lead created in Sales', crm.success),
      'existing' => (
        'Added to existing lead${e.leadName != null ? ' "${e.leadName}"' : ''}',
        crm.primary,
      ),
      'failed' => ('Lead not created — add it in Sales', crm.destructive),
      _ => ('', crm.textSecondary),
    };

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      color: crm.surface,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: crm.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  e.type == 'booking'
                      ? Icons.event_available_outlined
                      : Icons.mail_outline,
                  size: 18,
                  color: crm.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    e.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                Text(
                  when,
                  style: TextStyle(fontSize: 12, color: crm.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SelectableText(
                  e.phone,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                IconButton(
                  tooltip: 'Copy number',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.copy, size: 16),
                  onPressed: () =>
                      Clipboard.setData(ClipboardData(text: e.phone)),
                ),
                if (e.email.isNotEmpty)
                  SelectableText(
                    e.email,
                    style: TextStyle(color: crm.textSecondary),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              [
                e.type == 'booking' ? 'Booking request' : 'Contact message',
                if (e.eventDate != null) 'Wedding ${e.eventDate}',
                if (_slots[e.slot] != null) _slots[e.slot]!,
                if (e.packageName.isNotEmpty) e.packageName,
                if (e.addonNames.isNotEmpty) '+ ${e.addonNames.join(', ')}',
                if (e.district.isNotEmpty)
                  [e.district, if (e.region.isNotEmpty) e.region].join(', '),
                if (e.quotedTotal != null)
                  'Total shown ₹${NumberFormat.decimalPattern('en_IN').format(e.quotedTotal)}',
                if (e.venue.isNotEmpty) e.venue,
              ].join(' · '),
              style: TextStyle(fontSize: 13, color: crm.textPrimary),
            ),
            if (e.message.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '"${e.message}"',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: crm.textSecondary,
                  ),
                ),
              ),
            if (e.utm.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'From ad: ${e.utm.entries.map((x) => '${x.key}=${x.value}').join(', ')}',
                  style: TextStyle(fontSize: 12, color: crm.textSecondary),
                ),
              ),
            if (e.note.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Note: ${e.note}${e.handledBy != null ? ' — ${e.handledBy}' : ''}',
                  style: TextStyle(fontSize: 12, color: crm.textPrimary),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (leadText.isNotEmpty)
                  Expanded(
                    child: Text(
                      leadText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: leadColor,
                      ),
                    ),
                  )
                else
                  const Spacer(),
                TextButton.icon(
                  onPressed: onNote,
                  icon: const Icon(Icons.sticky_note_2_outlined, size: 18),
                  label: const Text('Note'),
                ),
                const SizedBox(width: 4),
                DropdownButton<String>(
                  value: _statuses.containsKey(e.status) ? e.status : 'new',
                  underline: const SizedBox.shrink(),
                  items: [
                    for (final s in _statuses.entries)
                      DropdownMenuItem(value: s.key, child: Text(s.value)),
                  ],
                  onChanged: (s) {
                    if (s != null && s != e.status) onStatus(s);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
