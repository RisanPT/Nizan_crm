import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/marketing/data/socials_models.dart';
import 'package:nizan_crm/features/marketing/data/team_models.dart';
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/presentation/socials/socials_widgets.dart';
import 'package:nizan_crm/features/marketing/services/socials_service.dart';

/// Create a post (on [day], in [status]) or change [post]. Where a post is planned, moved through the pipeline, and — once it is out —
/// where its numbers are typed (from the platform's own insights: no platform API is connected).
Future<void> showPostEditor(BuildContext context, WidgetRef ref, {SocialPost? post, DateTime? day, String status = 'planned'}) {
  final form = _PostForm(post: post, day: day, status: status);
  if (MediaQuery.sizeOf(context).width >= 700) {
    return showDialog<void>(context: context, builder: (_) => Dialog(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 600), child: form)));
  }
  return showModalBottomSheet<void>(context: context, isScrollControlled: true, useSafeArea: true, showDragHandle: true, builder: (_) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom), child: form));
}

const _metricFields = [
  ('reach', 'Reach'),
  ('impressions', 'Impressions'),
  ('views', 'Video views'),
  ('likes', 'Likes'),
  ('comments', 'Comments'),
  ('reposts', 'Reposts'),
  ('shares', 'Shares'),
  ('saves', 'Saves'),
  ('linkClicks', 'Link clicks'),
];

class _PostForm extends ConsumerStatefulWidget {
  const _PostForm({this.post, this.day, required this.status});
  final SocialPost? post;
  final DateTime? day;
  final String status;

  @override
  ConsumerState<_PostForm> createState() => _PostFormState();
}

class _PostFormState extends ConsumerState<_PostForm> {
  late final _title = TextEditingController(text: widget.post?.title ?? '');
  late final _caption = TextEditingController(text: widget.post?.caption ?? '');
  late final _permalink = TextEditingController(text: widget.post?.permalink ?? '');
  late final _thumb = TextEditingController(text: widget.post?.thumbUrl ?? '');
  late final _campaign = TextEditingController(text: widget.post?.campaign ?? '');
  late final Map<String, TextEditingController> _metrics = {for (final f in _metricFields) f.$1: TextEditingController(text: (widget.post?.metrics[f.$1] ?? 0) == 0 ? '' : '${widget.post!.metrics[f.$1]}')};
  late String _platform = widget.post?.platform.isNotEmpty == true ? widget.post!.platform : 'instagram';
  late String _format = widget.post?.contentType.isNotEmpty == true ? widget.post!.contentType : 'reel';
  late String _brand = widget.post?.brand ?? 'main';
  late String _status = widget.post?.status ?? widget.status;
  late DateTime _date = widget.post?.day ?? widget.day ?? DateTime.now();
  late TimeOfDay _time = TimeOfDay.fromDateTime(widget.post?.scheduledDate ?? DateTime(2000, 1, 1, 10));
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_title, _caption, _permalink, _thumb, _campaign, ..._metrics.values]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(now.year - 2), lastDate: DateTime(now.year + 2));
    if (d != null) setState(() => _date = d);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: _time);
    if (t != null) setState(() => _time = t);
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Give the post a title.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final when = DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);
    final body = <String, dynamic>{
      'title': _title.text.trim(),
      'platform': _platform,
      'contentType': _format,
      'brand': _brand,
      'status': _status,
      'scheduledDate': when.toUtc().toIso8601String(),
      if (_status == 'published') 'publishedDate': when.toUtc().toIso8601String(),
      'caption': _caption.text.trim(),
      'permalink': _permalink.text.trim(),
      'thumbUrl': _thumb.text.trim(),
      'campaign': _campaign.text.trim(),
      'metrics': {for (final e in _metrics.entries) if (e.value.text.trim().isNotEmpty) e.key: int.tryParse(e.value.text.trim()) ?? 0},
    };
    try {
      await ref.read(marketingSocialsServiceProvider).savePost(body, id: widget.post?.id);
      refreshSocials(ref);
      if (mounted) Navigator.pop(context);
    } on TeamRefusal catch (r) {
      if (mounted) setState(() { _error = r.message; _saving = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showErrorSnackBar(context, e);
      }
    }
  }

  Future<void> _delete() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete this post?'),
        content: const Text('It is removed from the calendar and the pipeline.'),
        actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), FilledButton(key: const Key('post_delete_confirm'), onPressed: () => Navigator.pop(c, true), child: const Text('Delete'))],
      ),
    );
    if (yes != true || !mounted) return;
    try {
      await ref.read(marketingSocialsServiceProvider).deletePost(widget.post!.id);
      refreshSocials(ref);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    }
  }

  InputDecoration _dec(String label, {String? hint}) => InputDecoration(labelText: label, hintText: hint, isDense: true, border: const OutlineInputBorder());

  Widget _drop<T>(String label, T value, List<(T, String)> options, ValueChanged<T> on, {Key? key}) => DropdownButtonFormField<T>(
        key: key,
        isExpanded: true,
        initialValue: value,
        decoration: _dec(label),
        items: [for (final o in options) DropdownMenuItem<T>(value: o.$1, child: Text(o.$2))],
        onChanged: (v) => v == null ? null : on(v),
      );

  @override
  Widget build(BuildContext context) {
    final editing = widget.post != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(editing ? 'Edit content' : 'Create content', style: mktText(19, weight: FontWeight.w800)),
                const SizedBox(height: 12),
                TextField(key: const Key('post_title'), controller: _title, decoration: _dec('Title')),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _drop('Platform', _platform, kPlatforms, (v) => setState(() => _platform = v), key: const Key('post_platform'))),
                  const SizedBox(width: 10),
                  Expanded(child: _drop('Format', _format, kPostFormats, (v) => setState(() => _format = v), key: const Key('post_format'))),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _drop('Stage', _status, kPostStatuses, (v) => setState(() => _status = v), key: const Key('post_status'))),
                  const SizedBox(width: 10),
                  Expanded(child: _drop('Brand', _brand, const [('main', 'Main'), ('kerala', 'Kerala')], (v) => setState(() => _brand = v), key: const Key('post_brand'))),
                ]),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  MktPill(key: const Key('post_date'), label: DateFormat('EEE d MMM yyyy').format(_date), icon: Icons.calendar_today_outlined, onTap: _pickDate, trailing: false),
                  MktPill(key: const Key('post_time'), label: _time.format(context), icon: Icons.schedule_rounded, onTap: _pickTime, trailing: false),
                ]),
                const SizedBox(height: 10),
                TextField(key: const Key('post_caption'), controller: _caption, minLines: 2, maxLines: 4, decoration: _dec('Caption')),
                const SizedBox(height: 10),
                TextField(key: const Key('post_campaign'), controller: _campaign, decoration: _dec('Campaign (optional)')),
                const SizedBox(height: 10),
                TextField(key: const Key('post_thumb'), controller: _thumb, decoration: _dec('Thumbnail link (optional)', hint: 'https://…')),
                const SizedBox(height: 10),
                TextField(key: const Key('post_permalink'), controller: _permalink, decoration: _dec('Link to the post (once it is out)', hint: 'https://…')),
                const SizedBox(height: 14),
                Text('Numbers from the platform', style: mktText(13, weight: FontWeight.w800)),
                Text('Typed once the post is out — they feed Performance, Top Content and the engagement overview.', style: mktText(11.5, color: Mkt.inkSoft)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final f in _metricFields)
                      SizedBox(
                        width: 130,
                        child: TextField(key: Key('post_metric_${f.$1}'), controller: _metrics[f.$1], keyboardType: TextInputType.number, decoration: _dec(f.$2)),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Mkt.border))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_error!, key: const Key('post_error'), style: mktText(12.5, weight: FontWeight.w600, color: Mkt.bad))),
              Row(children: [
                if (editing) TextButton(key: const Key('post_delete'), onPressed: _saving ? null : _delete, child: const Text('Delete', style: TextStyle(color: Mkt.bad))),
                const Spacer(),
                OutlinedButton(key: const Key('post_cancel'), onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
                const SizedBox(width: 10),
                FilledButton(
                  key: const Key('post_save'),
                  style: FilledButton.styleFrom(backgroundColor: Mkt.maroon),
                  onPressed: _saving ? null : _save,
                  child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save'),
                ),
              ]),
            ],
          ),
        ),
      ],
    );
  }
}
