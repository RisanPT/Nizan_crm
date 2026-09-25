import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nizan_crm/core/models/trial_package.dart';
import 'package:nizan_crm/core/providers/trial_package_provider.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/state/data_refresh.dart';

final _inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
String _price(double v) => v == v.roundToDouble()
    ? _inr.format(v)
    : NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2).format(v);

enum _Sort { nameAz, priceLow, priceHigh }

const _sortLabels = {
  _Sort.nameAz: 'Name A–Z',
  _Sort.priceLow: 'Price: low → high',
  _Sort.priceHigh: 'Price: high → low',
};

class TrialPackagesScreen extends ConsumerStatefulWidget {
  const TrialPackagesScreen({super.key});

  @override
  ConsumerState<TrialPackagesScreen> createState() =>
      _TrialPackagesScreenState();
}

class _TrialPackagesScreenState extends ConsumerState<TrialPackagesScreen> {
  final _searchCtrl = TextEditingController();
  String _search = '';
  _Sort _sort = _Sort.nameAz;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final asyncPackages = ref.watch(trialPackagesProvider);

    return Scaffold(
      backgroundColor: crm.background,
      body: asyncPackages.when(
        loading: () =>
            Center(child: CircularProgressIndicator(color: crm.primary)),
        error: (error, _) => AppErrorView(
          error: error,
          onRetry: () => ref.invalidate(trialPackagesProvider),
        ),
        data: (packages) {
          final q = _search.trim().toLowerCase();
          final shown = packages
              .where((p) =>
                  q.isEmpty ||
                  p.name.toLowerCase().contains(q) ||
                  p.description.toLowerCase().contains(q))
              .toList()
            ..sort((a, b) {
              switch (_sort) {
                case _Sort.nameAz:
                  return a.name.toLowerCase().compareTo(b.name.toLowerCase());
                case _Sort.priceLow:
                  return a.price.compareTo(b.price);
                case _Sort.priceHigh:
                  return b.price.compareTo(a.price);
              }
            });

          return LayoutBuilder(builder: (context, box) {
            final w = box.maxWidth;
            final narrow = w < 600;
            final pad = narrow ? 16.0 : 24.0;
            final inner = w - pad * 2;
            final cols = inner < 520 ? 1 : (inner < 820 ? 2 : (inner < 1150 ? 3 : 4));

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(trialPackagesProvider);
                try {
                  await ref.read(trialPackagesProvider.future);
                } catch (_) {
                  // Shown by the error state.
                }
              },
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(pad, pad, pad, 16),
                    sliver: SliverToBoxAdapter(
                      child: _Header(
                        packages: packages,
                        narrow: narrow,
                        searchCtrl: _searchCtrl,
                        sort: _sort,
                        onSearch: (v) => setState(() => _search = v),
                        onSort: (v) => setState(() => _sort = v),
                        onAdd: () => _showFormDialog(context, ref),
                      ),
                    ),
                  ),
                  if (packages.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _Empty(
                        title: 'No trial packages yet',
                        subtitle: 'Create your first trial package to start booking trials.',
                        actionLabel: 'Add package',
                        onAction: () => _showFormDialog(context, ref),
                      ),
                    )
                  else if (shown.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _Empty(
                        title: 'No packages match "$_search"',
                        subtitle: 'Try a different name or clear the search.',
                        actionLabel: 'Clear search',
                        onAction: () => setState(() {
                          _searchCtrl.clear();
                          _search = '';
                        }),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(pad, 0, pad, 96),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cols,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                          mainAxisExtent: 212,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, i) {
                            if (i == shown.length) {
                              return _AddCard(
                                  onTap: () => _showFormDialog(context, ref));
                            }
                            final pkg = shown[i];
                            return _PackageCard(
                              pkg: pkg,
                              index: packages.indexOf(pkg),
                              onEdit: () =>
                                  _showFormDialog(context, ref, pkg: pkg),
                              onDelete: () => _confirmDelete(context, ref, pkg),
                            );
                          },
                          // +1 for the "Add package" card at the end.
                          childCount: shown.length + (q.isEmpty ? 1 : 0),
                        ),
                      ),
                    ),
                ],
              ),
            );
          });
        },
      ),
    );
  }
  void _showFormDialog(BuildContext context, WidgetRef ref, {TrialPackage? pkg}) {
    final crmColors = context.crmColors;
    final nameCtrl = TextEditingController(text: pkg?.name ?? '');
    final priceCtrl = TextEditingController(text: pkg != null ? pkg.price.toString() : '');
    final descCtrl = TextEditingController(text: pkg?.description ?? '');
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: crmColors.surface,
              title: Text(
                pkg == null ? 'Add Trial Package' : 'Edit Trial Package',
                style: TextStyle(color: crmColors.textPrimary),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      style: TextStyle(color: crmColors.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Package Name',
                        labelStyle: TextStyle(color: crmColors.textSecondary),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: priceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(color: crmColors.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Price',
                        labelStyle: TextStyle(color: crmColors.textSecondary),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descCtrl,
                      style: TextStyle(color: crmColors.textPrimary),
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Description (Optional)',
                        labelStyle: TextStyle(color: crmColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: Text('Cancel', style: TextStyle(color: crmColors.textSecondary)),
                ),
                FilledButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final name = nameCtrl.text.trim();
                          final price = double.tryParse(priceCtrl.text.trim());
                          if (name.isEmpty || price == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Name and valid price are required')),
                            );
                            return;
                          }

                          setState(() => isSaving = true);
                          try {
                            final service = ref.read(trialPackageServiceProvider);
                            final newPkg = TrialPackage(
                              id: pkg?.id ?? '',
                              name: name,
                              price: price,
                              description: descCtrl.text.trim(),
                            );
                            if (pkg == null) {
                              await service.createTrialPackage(newPkg);
                            } else {
                              await service.updateTrialPackage(newPkg);
                            }
                            ref.refreshData.trialPackages();
                            if (context.mounted) Navigator.pop(context);
                          } catch (e) {
                            if (context.mounted) {
                              showErrorSnackBar(context, e);
                            }
                            setState(() => isSaving = false);
                          }
                        },
                  style: FilledButton.styleFrom(backgroundColor: crmColors.primary),
                  child: isSaving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(pkg == null ? 'Create' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, TrialPackage pkg) {
    final crmColors = context.crmColors;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: crmColors.surface,
        title: Text('Delete Package?', style: TextStyle(color: crmColors.textPrimary)),
        content: Text(
          'Are you sure you want to delete ${pkg.name}? This action cannot be undone.',
          style: TextStyle(color: crmColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel', style: TextStyle(color: crmColors.textSecondary)),
          ),
          TextButton(
            // Report errors on the screen's context: the dialog's own context
            // is gone once it's popped, which silently swallowed failures.
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await ref.read(trialPackageServiceProvider).deleteTrialPackage(pkg.id);
                ref.refreshData.trialPackages();
              } catch (e) {
                if (context.mounted) {
                  showErrorSnackBar(context, e);
                }
              }
            },
            child: Text('Delete', style: TextStyle(color: crmColors.destructive)),
          ),
        ],
      ),
    );
  }
}

// ── Header ──────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.packages,
    required this.narrow,
    required this.searchCtrl,
    required this.sort,
    required this.onSearch,
    required this.onSort,
    required this.onAdd,
  });

  final List<TrialPackage> packages;
  final bool narrow;
  final TextEditingController searchCtrl;
  final _Sort sort;
  final ValueChanged<String> onSearch;
  final ValueChanged<_Sort> onSort;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final prices = packages.map((p) => p.price).toList()..sort();
    final range = prices.isEmpty
        ? ''
        : prices.first == prices.last
            ? ' · ${_price(prices.first)}'
            : ' · ${_price(prices.first)} – ${_price(prices.last)}';

    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Trial Packages',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: crm.textPrimary)),
        const SizedBox(height: 2),
        Text(
          '${packages.length} package${packages.length == 1 ? '' : 's'}$range',
          style: TextStyle(fontSize: 12.5, color: crm.textSecondary),
        ),
      ],
    );
    final addBtn = FilledButton.icon(
      onPressed: onAdd,
      icon: const Icon(Icons.add, size: 18),
      label: const Text('Add Package'),
      style: FilledButton.styleFrom(
        backgroundColor: crm.primary,
        minimumSize: const Size(0, 42),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
    final searchField = SizedBox(
      height: 44,
      child: TextField(
        controller: searchCtrl,
        onChanged: onSearch,
        decoration: InputDecoration(
          hintText: 'Search packages…',
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          filled: true,
          fillColor: crm.surface,
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: crm.border)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: crm.border)),
        ),
      ),
    );
    final sortMenu = PopupMenuButton<_Sort>(
      tooltip: 'Sort',
      onSelected: onSort,
      itemBuilder: (_) => [
        for (final e in _sortLabels.entries)
          CheckedPopupMenuItem(
              value: e.key, checked: sort == e.key, child: Text(e.value)),
      ],
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: crm.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: crm.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.swap_vert_rounded, size: 18, color: crm.textSecondary),
          const SizedBox(width: 6),
          Text(_sortLabels[sort]!,
              style: TextStyle(
                  fontWeight: FontWeight.w600, color: crm.textPrimary)),
          Icon(Icons.expand_more_rounded, size: 18, color: crm.textSecondary),
        ]),
      ),
    );

    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Expanded(child: title), addBtn]),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: searchField),
            const SizedBox(width: 10),
            sortMenu,
          ]),
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: title),
        SizedBox(width: 260, child: searchField),
        const SizedBox(width: 10),
        sortMenu,
        const SizedBox(width: 10),
        addBtn,
      ],
    );
  }
}

// ── Cards ───────────────────────────────────────────────────────────────────

/// Maroon → rose accents, cycled per package so cards are easy to tell apart.
const _accents = [
  Color(0xFF6E1423),
  Color(0xFF9E2B43),
  Color(0xFFB76E79),
  Color(0xFF8F1D33),
  Color(0xFFC96578),
];

class _PackageCard extends StatefulWidget {
  const _PackageCard({
    required this.pkg,
    required this.index,
    required this.onEdit,
    required this.onDelete,
  });

  final TrialPackage pkg;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<_PackageCard> createState() => _PackageCardState();
}

class _PackageCardState extends State<_PackageCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final pkg = widget.pkg;
    final accent = _accents[(widget.index < 0 ? 0 : widget.index) % _accents.length];

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        transform: Matrix4.translationValues(0, _hover ? -3 : 0, 0),
        decoration: BoxDecoration(
          color: crm.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: _hover ? accent.withValues(alpha: 0.5) : crm.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _hover ? 0.08 : 0.03),
              blurRadius: _hover ? 18 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onEdit,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Accent strip
                Container(
                  height: 5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [accent, accent.withValues(alpha: 0.45)]),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 8, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.auto_awesome_outlined,
                                  size: 20, color: accent),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                pkg.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 15,
                                    height: 1.25,
                                    fontWeight: FontWeight.w700,
                                    color: crm.textPrimary),
                              ),
                            ),
                            PopupMenuButton<String>(
                              tooltip: 'More',
                              icon: Icon(Icons.more_vert_rounded,
                                  size: 20, color: crm.textSecondary),
                              onSelected: (v) {
                                if (v == 'edit') widget.onEdit();
                                if (v == 'delete') widget.onDelete();
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                    value: 'edit',
                                    child: Row(children: [
                                      Icon(Icons.edit_outlined, size: 18),
                                      SizedBox(width: 10),
                                      Text('Edit'),
                                    ])),
                                PopupMenuItem(
                                    value: 'delete',
                                    child: Row(children: [
                                      Icon(Icons.delete_outline,
                                          size: 18, color: crm.destructive),
                                      const SizedBox(width: 10),
                                      Text('Delete',
                                          style: TextStyle(
                                              color: crm.destructive)),
                                    ])),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(
                              pkg.description.isNotEmpty
                                  ? pkg.description
                                  : 'No description added.',
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                height: 1.4,
                                fontStyle: pkg.description.isEmpty
                                    ? FontStyle.italic
                                    : FontStyle.normal,
                                color: crm.textSecondary,
                              ),
                            ),
                          ),
                        ),
                        Divider(height: 16, color: crm.border),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('TRIAL PRICE',
                                      style: TextStyle(
                                          fontSize: 10,
                                          letterSpacing: 0.6,
                                          fontWeight: FontWeight.w700,
                                          color: crm.textSecondary)),
                                  const SizedBox(height: 2),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(_price(pkg.price),
                                        style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w800,
                                            color: accent)),
                                  ),
                                ],
                              ),
                            ),
                            TextButton.icon(
                              onPressed: widget.onEdit,
                              icon: const Icon(Icons.edit_outlined, size: 16),
                              label: const Text('Edit'),
                              style: TextButton.styleFrom(
                                  foregroundColor: crm.primary,
                                  visualDensity: VisualDensity.compact),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddCard extends StatelessWidget {
  const _AddCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: CustomPaint(
        painter: _DashedBorder(color: crm.primary.withValues(alpha: 0.35)),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                    color: crm.primary.withValues(alpha: 0.08),
                    shape: BoxShape.circle),
                child: Icon(Icons.add_rounded, color: crm.primary),
              ),
              const SizedBox(height: 10),
              Text('Add trial package',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: crm.primary)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedBorder extends CustomPainter {
  _DashedBorder({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Offset.zero & size, const Radius.circular(16)));
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 7), paint);
        d += 12;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) => old.color != color;
}

class _Empty extends StatelessWidget {
  const _Empty({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome_outlined,
                size: 52, color: crm.textSecondary.withValues(alpha: 0.45)),
            const SizedBox(height: 14),
            Text(title,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: crm.textPrimary)),
            const SizedBox(height: 6),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(color: crm.textSecondary)),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}