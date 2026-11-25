import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/website/data/website_models.dart';
import 'package:nizan_crm/features/website/services/website_service.dart';
import 'package:nizan_crm/features/website/presentation/widgets/website_image_field.dart';

/// Portfolio gallery: add, edit, hide, order and remove photos.
/// Changes go live straight away (no draft step).
class GalleryTab extends ConsumerStatefulWidget {
  const GalleryTab({super.key});

  @override
  ConsumerState<GalleryTab> createState() => _GalleryTabState();
}

class _GalleryTabState extends ConsumerState<GalleryTab> {
  String _filter = 'all';
  bool _busy = false;

  Future<void> _act(Future<void> Function() action, [String? success]) async {
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(websiteGalleryProvider);
      if (success != null && mounted) showSuccessSnackBar(context, success);
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _move(List<GalleryItem> all, int index, int delta) async {
    final ids = all.map((g) => g.id).toList();
    final to = index + delta;
    if (to < 0 || to >= ids.length) return;
    final id = ids.removeAt(index);
    ids.insert(to, id);
    await _act(() => ref.read(websiteServiceProvider).reorderGallery(ids));
  }

  Future<void> _edit(WebsiteSchema schema, [GalleryItem? item]) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _GalleryItemDialog(schema: schema, item: item),
    );
    if (saved == true) {
      ref.invalidate(websiteGalleryProvider);
      if (mounted) {
        showSuccessSnackBar(
          context,
          item == null ? 'Photo added to the website.' : 'Photo updated.',
        );
      }
    }
  }

  Future<void> _delete(GalleryItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove this photo?'),
        content: const Text('It disappears from the website straight away.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _act(
        () => ref.read(websiteServiceProvider).deleteGalleryItem(item.id),
        'Photo removed.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final schemaAsync = ref.watch(websiteSchemaProvider);
    final galleryAsync = ref.watch(websiteGalleryProvider);

    return schemaAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => AppErrorView(
        error: e,
        onRetry: () => ref.invalidate(websiteSchemaProvider),
      ),
      data: (schema) => galleryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AppErrorView(
          error: e,
          onRetry: () => ref.invalidate(websiteGalleryProvider),
        ),
        data: (all) {
          final shown = _filter == 'all'
              ? all
              : all.where((g) => g.category == _filter).toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ChoiceChip(
                      label: Text('All (${all.length})'),
                      selected: _filter == 'all',
                      onSelected: (_) => setState(() => _filter = 'all'),
                    ),
                    for (final c in schema.galleryCategories)
                      ChoiceChip(
                        label: Text(
                          '${c.label} (${all.where((g) => g.category == c.key).length})',
                        ),
                        selected: _filter == c.key,
                        onSelected: (_) => setState(() => _filter = c.key),
                      ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: _busy ? null : () => _edit(schema),
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: const Text('Add photo'),
                    ),
                  ],
                ),
              ),
              if (_filter != 'all')
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Switch to "All" to change the order.',
                    style: TextStyle(fontSize: 12, color: crm.textSecondary),
                  ),
                ),
              if (_busy) const LinearProgressIndicator(),
              Expanded(
                child: shown.isEmpty
                    ? Center(
                        child: Text(
                          'No photos yet. The website shows its built-in photos until you add some.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: crm.textSecondary),
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 240,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 0.58,
                            ),
                        itemCount: shown.length,
                        itemBuilder: (_, i) {
                          final g = shown[i];
                          final index = all.indexOf(g);
                          return _GalleryCard(
                            item: g,
                            categoryLabel: schema.categoryLabel(g.category),
                            canReorder: _filter == 'all' && !_busy,
                            isFirst: index == 0,
                            isLast: index == all.length - 1,
                            onMove: (delta) => _move(all, index, delta),
                            onEdit: () => _edit(schema, g),
                            onDelete: () => _delete(g),
                            onToggleActive: () => _act(
                              () => ref
                                  .read(websiteServiceProvider)
                                  .updateGalleryItem(g.id, {
                                    'active': !g.active,
                                  }),
                            ),
                            onToggleHome: () => _act(
                              () => ref
                                  .read(websiteServiceProvider)
                                  .updateGalleryItem(g.id, {
                                    'featuredOnHome': !g.featuredOnHome,
                                  }),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GalleryCard extends StatelessWidget {
  final GalleryItem item;
  final String categoryLabel;
  final bool canReorder;
  final bool isFirst;
  final bool isLast;
  final ValueChanged<int> onMove;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleActive;
  final VoidCallback onToggleHome;

  const _GalleryCard({
    required this.item,
    required this.categoryLabel,
    required this.canReorder,
    required this.isFirst,
    required this.isLast,
    required this.onMove,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleActive,
    required this.onToggleHome,
  });

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      color: crm.surface,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: crm.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Opacity(
              opacity: item.active ? 1 : 0.4,
              child: InkWell(
                onTap: onEdit,
                child: Image.network(
                  item.image.url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Icon(
                    Icons.broken_image_outlined,
                    color: crm.textSecondary,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title.isEmpty ? '(no title)' : item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  item.active ? categoryLabel : '$categoryLabel · hidden',
                  style: TextStyle(fontSize: 12, color: crm.textSecondary),
                ),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                tooltip: 'Move earlier',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.chevron_left),
                onPressed: canReorder && !isFirst ? () => onMove(-1) : null,
              ),
              IconButton(
                tooltip: item.featuredOnHome
                    ? 'Shown in Recent brides (home page)'
                    : 'Show in Recent brides',
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  item.featuredOnHome ? Icons.star : Icons.star_border,
                  color: item.featuredOnHome ? crm.warning : null,
                ),
                onPressed: onToggleHome,
              ),
              IconButton(
                tooltip: item.active ? 'Hide from website' : 'Show on website',
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  item.active
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: onToggleActive,
              ),
              IconButton(
                tooltip: 'Remove',
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.delete_outline, color: crm.destructive),
                onPressed: onDelete,
              ),
              IconButton(
                tooltip: 'Move later',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.chevron_right),
                onPressed: canReorder && !isLast ? () => onMove(1) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GalleryItemDialog extends ConsumerStatefulWidget {
  final WebsiteSchema schema;
  final GalleryItem? item;
  const _GalleryItemDialog({required this.schema, this.item});

  @override
  ConsumerState<_GalleryItemDialog> createState() => _GalleryItemDialogState();
}

class _GalleryItemDialogState extends ConsumerState<_GalleryItemDialog> {
  late Map<String, dynamic>? _image = widget.item?.image.toJson();
  late String _category =
      widget.item?.category ??
      (widget.schema.galleryCategories.isNotEmpty
          ? widget.schema.galleryCategories.first.key
          : '');
  late String _title = widget.item?.title ?? '';
  late String _description = widget.item?.description ?? '';
  late bool _active = widget.item?.active ?? true;
  late bool _home = widget.item?.featuredOnHome ?? false;
  bool _busy = false;
  List<String> _errors = const [];

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _errors = const [];
    });
    final body = {
      'image': _image,
      'category': _category,
      'title': _title,
      'description': _description,
      'active': _active,
      'featuredOnHome': _home,
    };
    try {
      final svc = ref.read(websiteServiceProvider);
      if (widget.item == null) {
        await svc.createGalleryItem(body);
      } else {
        await svc.updateGalleryItem(widget.item!.id, body);
      }
      if (mounted) Navigator.pop(context, true);
    } on WebsiteValidationException catch (e) {
      if (mounted) {
        setState(() => _errors = e.errors.isEmpty ? [e.message] : e.errors);
      }
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final rule = widget.schema.galleryUpload;
    final hasImage = WebsiteImage.tryParse(_image) != null;

    return AlertDialog(
      title: Text(widget.item == null ? 'Add photo' : 'Edit photo'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (rule != null)
                WebsiteImageField(
                  label: 'Photo',
                  required: true,
                  rule: rule,
                  section: 'gallery',
                  field: 'image',
                  value: _image,
                  onChanged: (v) => setState(() => _image = v),
                ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _category.isEmpty ? null : _category,
                decoration: const InputDecoration(
                  labelText: 'Category *',
                  isDense: true,
                ),
                items: [
                  for (final c in widget.schema.galleryCategories)
                    DropdownMenuItem(value: c.key, child: Text(c.label)),
                ],
                onChanged: (v) => setState(() => _category = v ?? _category),
              ),
              const SizedBox(height: 8),
              TextFormField(
                initialValue: _title,
                maxLength: 60,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  isDense: true,
                ),
                onChanged: (v) => _title = v,
              ),
              TextFormField(
                initialValue: _description,
                maxLength: 200,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  isDense: true,
                ),
                onChanged: (v) => _description = v,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Show on website'),
                value: _active,
                onChanged: (v) => setState(() => _active = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Also show in "Recent brides" on the home page',
                ),
                value: _home,
                onChanged: (v) => setState(() => _home = v),
              ),
              if (_errors.isNotEmpty)
                Text(
                  _errors.map((e) => '• $e').join('\n'),
                  style: TextStyle(color: crm.destructive),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy || !hasImage ? null : _save,
          child: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
