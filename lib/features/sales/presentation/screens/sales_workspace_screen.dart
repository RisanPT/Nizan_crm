import 'package:flutter/material.dart';
import 'package:nizan_crm/core/widgets/date_pickers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/models/district.dart';
import 'package:nizan_crm/core/models/service_package.dart';
import 'package:nizan_crm/core/models/spot_invoice.dart';
import 'package:nizan_crm/core/utils/spot_invoice_service.dart';
import 'package:nizan_crm/services/package_service.dart';
import 'package:nizan_crm/services/district_service.dart';
import 'lead_calendar_tab.dart';
import 'quote_builder_tab.dart';
import 'sales_leads_screen.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/slots/data/slot_models.dart';
import 'package:nizan_crm/features/slots/services/slot_service.dart';

/// The salesperson's main workspace: Leads · Lead Calendar · Quote · Slots · Invoice.
/// The Quote tab feeds its lines (and district) into the Invoice tab, which
/// generates a shareable no-GST quotation.
class SalesWorkspaceScreen extends ConsumerStatefulWidget {
  /// Tab to open: leads | calendar | quote | slots | invoice (from ?tab=).
  final String? initialTab;

  const SalesWorkspaceScreen({super.key, this.initialTab});

  static const tabKeys = ['leads', 'calendar', 'quote', 'slots', 'invoice'];

  static int indexOf(String? tab) {
    final i = tabKeys.indexOf((tab ?? '').toLowerCase());
    return i < 0 ? 0 : i;
  }

  @override
  ConsumerState<SalesWorkspaceScreen> createState() =>
      _SalesWorkspaceScreenState();
}

class _SalesWorkspaceScreenState extends ConsumerState<SalesWorkspaceScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: 5,
    vsync: this,
    initialIndex: SalesWorkspaceScreen.indexOf(widget.initialTab),
  );

  // Arriving again with a different ?tab= (e.g. from the Menu) switches tab.
  @override
  void didUpdateWidget(covariant SalesWorkspaceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTab != oldWidget.initialTab) {
      _tabs.animateTo(SalesWorkspaceScreen.indexOf(widget.initialTab));
    }
  }

  // Handoff from Quote → Invoice.
  List<SpotInvoiceLine> _prefillLines = const [];
  String _prefillCustomer = '';
  String _prefillPhone = '';
  String? _prefillDistrictId;
  int _prefillNonce = 0;

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _sendToInvoice(
    String customer,
    String phone,
    String? districtId,
    List<SpotInvoiceLine> lines,
  ) {
    setState(() {
      _prefillCustomer = customer;
      _prefillPhone = phone;
      _prefillDistrictId = districtId;
      _prefillLines = lines;
      _prefillNonce++;
    });
    _tabs.animateTo(4);
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Scaffold(
      backgroundColor: crm.background,
      body: Column(
        children: [
          Material(
            color: crm.surface,
            child: TabBar(
              controller: _tabs,
              // Five tabs don't fit a phone's width; let them scroll there.
              isScrollable: MediaQuery.sizeOf(context).width < 600,
              tabAlignment: MediaQuery.sizeOf(context).width < 600
                  ? TabAlignment.start
                  : null,
              labelColor: crm.primary,
              unselectedLabelColor: crm.textSecondary,
              indicatorColor: crm.primary,
              labelStyle: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
              indicatorSize: TabBarIndicatorSize.label,
              indicatorWeight: 2.5,
              tabs: const [
                Tab(icon: Icon(Icons.groups_rounded), text: 'Leads'),
                Tab(icon: Icon(Icons.calendar_month_rounded), text: 'Lead Calendar'),
                Tab(icon: Icon(Icons.calculate_rounded), text: 'Quote'),
                Tab(icon: Icon(Icons.event_available_rounded), text: 'Slots'),
                Tab(icon: Icon(Icons.receipt_long_rounded), text: 'Invoice'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                const SalesLeadsScreen(),
                const LeadCalendarTab(),
                QuoteBuilderTab(onCreateInvoice: _sendToInvoice),
                const _AvailabilityTab(),
                _SpotInvoiceTab(
                  key: ValueKey(_prefillNonce),
                  initialCustomer: _prefillCustomer,
                  initialPhone: _prefillPhone,
                  initialDistrictId: _prefillDistrictId,
                  initialLines: _prefillLines,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
//  Shared building blocks
// ─────────────────────────────────────────────────────────────────────────
const _wideBreakpoint = 900.0;
const _maxPageWidth = 1320.0;
const _sidePanelWidth = 380.0;
const _darkWine = Color(0xFF3A101A);
const _gold = Color(0xFFC9A66B);

String _rupees(double v) {
  final s = v.toStringAsFixed(0);
  // Indian digit grouping: 12,34,567
  if (s.length <= 3) return '₹$s';
  final last3 = s.substring(s.length - 3);
  var rest = s.substring(0, s.length - 3);
  final parts = <String>[];
  while (rest.length > 2) {
    parts.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) parts.insert(0, rest);
  return '₹${parts.join(',')},$last3';
}

String? _districtNameFor(List<District> districts, String? id) {
  if (id == null || id.isEmpty) return null;
  return districts.where((d) => d.id == id).map((d) => d.name).firstOrNull;
}

/// Responsive tab layout.
///  • Wide (≥ [_wideBreakpoint]): form on the left, a fixed summary panel on
///    the right holding the total and the primary action.
///  • Narrow: full-width single column with a pinned total bar.
class _TabScaffold extends StatelessWidget {
  final List<Widget> Function(bool wide) builder;
  final Widget sidePanel;
  final Widget bottomBar;

  const _TabScaffold({
    required this.builder,
    required this.sidePanel,
    required this.bottomBar,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= _wideBreakpoint;
        final form = SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(wide ? 24 : 16, 20, wide ? 12 : 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: builder(wide),
          ),
        );
        if (!wide) {
          return Column(
            children: [
              Expanded(child: form),
              bottomBar,
            ],
          );
        }
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxPageWidth),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: form),
                SizedBox(
                  width: _sidePanelWidth,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(12, 20, 24, 24),
                    child: sidePanel,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Receipt-style summary card shown in the right-hand pane on wide screens.
class _SummaryPanel extends StatelessWidget {
  final String title;
  final double total;
  final String caption;
  final List<(String, String)> details;
  final List<SpotInvoiceLine> lines;
  final String emptyMessage;
  final String actionLabel;
  final IconData actionIcon;
  final VoidCallback? onPressed;
  final bool busy;
  final Widget? footer;

  const _SummaryPanel({
    required this.title,
    required this.total,
    required this.caption,
    required this.lines,
    required this.emptyMessage,
    required this.actionLabel,
    required this.actionIcon,
    required this.onPressed,
    this.details = const [],
    this.busy = false,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: crm.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header — title + big total
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [crm.primary, _darkWine],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w800,
                    color: _gold,
                  ),
                ),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _rupees(total),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.1,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  caption,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (details.isNotEmpty) ...[
                  for (final (k, v) in details)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 78,
                            child: Text(
                              k,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: crm.textSecondary,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              v,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: crm.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  _DashedDivider(color: crm.border),
                  const SizedBox(height: 12),
                ],
                if (lines.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      emptyMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: crm.textSecondary,
                      ),
                    ),
                  )
                else ...[
                  for (final l in lines)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              l.label,
                              style: TextStyle(
                                fontSize: 13,
                                color: crm.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _rupees(l.amount),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: crm.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 4),
                  _DashedDivider(color: crm.border),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        'Total',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: crm.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _rupees(total),
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: crm.primary,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: busy ? null : onPressed,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(actionIcon, size: 20),
                  label: Text(actionLabel),
                ),
                if (footer != null) ...[const SizedBox(height: 10), footer!],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedDivider extends StatelessWidget {
  final Color color;
  const _DashedDivider({required this.color});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final n = (c.maxWidth / 8).floor();
        return Row(
          children: List.generate(
            n,
            (_) => Expanded(
              child: Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                color: color,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TabHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _TabHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [crm.primary, _darkWine],
              ),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: _gold, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: crm.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(color: crm.textSecondary, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A titled card grouping related fields.
class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget? trailing;
  final Widget child;

  const _Section({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: crm.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 36,
            child: Row(
              children: [
                Icon(icon, size: 17, color: crm.primary),
                const SizedBox(width: 8),
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11.5,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w800,
                    color: crm.textSecondary,
                  ),
                ),
                const Spacer(),
                ?trailing,
              ],
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

/// Lays two fields side by side on wide screens, stacked on phones.
class _TwoUp extends StatelessWidget {
  final Widget a;
  final Widget b;
  const _TwoUp(this.a, this.b);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth >= 520) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: a),
              const SizedBox(width: 12),
              Expanded(child: b),
            ],
          );
        }
        return Column(children: [a, const SizedBox(height: 12), b]);
      },
    );
  }
}

/// District picker shared by the Quote and Invoice tabs.
class _DistrictField extends StatelessWidget {
  final List<District> districts;
  final String? value;
  final String label;
  final String noneLabel;
  final ValueChanged<String?> onChanged;

  const _DistrictField({
    required this.districts,
    required this.value,
    required this.onChanged,
    this.label = 'District',
    this.noneLabel = 'No district',
  });

  @override
  Widget build(BuildContext context) {
    final sorted = [...districts.where((d) => d.isActive || d.id == value)]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    // Until districts load, a preset id has no matching item — show "none"
    // and re-seed (via the key) once the list arrives.
    final effective = sorted.any((d) => d.id == value) ? value! : '';
    return DropdownButtonFormField<String>(
      key: ValueKey('district-${sorted.length}-$effective'),
      isExpanded: true,
      initialValue: effective,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.location_on_outlined),
      ),
      items: [
        DropdownMenuItem(value: '', child: Text(noneLabel)),
        for (final d in sorted)
          DropdownMenuItem(
            value: d.id,
            child: Text(
              d.regionName.isNotEmpty
                  ? '${d.name}  ·  ${d.regionName}'
                  : d.name,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (id) => onChanged((id == null || id.isEmpty) ? null : id),
    );
  }
}

/// Pinned footer: running total on the left, primary action on the right.
class _TotalBar extends StatelessWidget {
  final double total;
  final String caption;
  final String actionLabel;
  final IconData actionIcon;
  final VoidCallback? onPressed;
  final bool busy;

  const _TotalBar({
    required this.total,
    required this.caption,
    required this.actionLabel,
    required this.actionIcon,
    required this.onPressed,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [crm.primary, _darkWine],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      caption,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _rupees(total),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: busy ? null : onPressed,
                style: FilledButton.styleFrom(
                  backgroundColor: _gold,
                  foregroundColor: _darkWine,
                  disabledBackgroundColor: Colors.white.withValues(alpha: 0.18),
                  disabledForegroundColor: Colors.white.withValues(alpha: 0.6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(actionIcon, size: 20),
                label: Text(actionLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  const _EmptyHint({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: crm.input,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: crm.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: crm.textSecondary, size: 26),
          const SizedBox(height: 6),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: crm.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: crm.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Numbered line items with a total row. Optional edit/remove callbacks turn
/// it into the editable list used by the Invoice tab.
class _LineList extends StatelessWidget {
  final List<SpotInvoiceLine> lines;
  final double total;
  final void Function(int index)? onEdit;
  final void Function(int index)? onRemove;

  const _LineList({
    required this.lines,
    required this.total,
    this.onEdit,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < lines.length; i++) ...[
          if (i > 0) Divider(height: 1, color: crm.border),
          InkWell(
            onTap: onEdit == null ? null : () => onEdit!(i),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: EdgeInsets.symmetric(
                vertical: onRemove == null ? 10 : 4,
                horizontal: 2,
              ),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: crm.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: crm.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      lines[i].label,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: crm.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _rupees(lines[i].amount),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: crm.textPrimary,
                    ),
                  ),
                  if (onRemove != null)
                    IconButton(
                      tooltip: 'Remove',
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: crm.destructive,
                      ),
                      onPressed: () => onRemove!(i),
                    ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: crm.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Text(
                'Total',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: crm.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                _rupees(total),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: crm.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
//  Invoice tab
// ─────────────────────────────────────────────────────────────────────────
class _SpotInvoiceTab extends ConsumerStatefulWidget {
  final String initialCustomer;
  final String initialPhone;
  final String? initialDistrictId;
  final List<SpotInvoiceLine> initialLines;

  const _SpotInvoiceTab({
    super.key,
    this.initialCustomer = '',
    this.initialPhone = '',
    this.initialDistrictId,
    this.initialLines = const [],
  });

  @override
  ConsumerState<_SpotInvoiceTab> createState() => _SpotInvoiceTabState();
}

class _SpotInvoiceTabState extends ConsumerState<_SpotInvoiceTab> {
  late final TextEditingController _customerCtrl = TextEditingController(
    text: widget.initialCustomer,
  );
  late final TextEditingController _phoneCtrl = TextEditingController(
    text: widget.initialPhone,
  );
  final _noteCtrl = TextEditingController();
  late final List<SpotInvoiceLine> _lines = [...widget.initialLines];
  late String? _districtId = widget.initialDistrictId;
  bool _generating = false;

  @override
  void dispose() {
    _customerCtrl.dispose();
    _phoneCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  /// Add a custom line, or edit line [index] when given.
  Future<void> _lineDialog({int? index}) async {
    final existing = index == null ? null : _lines[index];
    final labelCtrl = TextEditingController(text: existing?.label ?? '');
    final amountCtrl = TextEditingController(
      text: existing == null ? '' : existing.amount.toStringAsFixed(0),
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Add line item' : 'Edit line item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelCtrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Amount (₹)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(existing == null ? 'Add' : 'Save'),
          ),
        ],
      ),
    );
    final label = labelCtrl.text.trim();
    final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
    labelCtrl.dispose();
    amountCtrl.dispose();
    if (ok != true || label.isEmpty) return;
    final line = SpotInvoiceLine(label: label, amount: amount);
    setState(() {
      if (index == null) {
        _lines.add(line);
      } else {
        _lines[index] = line;
      }
    });
  }

  /// Pick an existing service package and add it as a line item. The price
  /// follows the selected district, same as the Quote tab.
  Future<void> _addPackageDialog(String? districtName) async {
    final List<ServicePackage> packages;
    try {
      packages = await ref.read(packagesProvider.future);
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
      return;
    }
    if (!mounted) return;
    if (packages.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No packages available')));
      return;
    }
    final districtId = _districtId;
    final picked = await showModalBottomSheet<ServicePackage>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        var q = '';
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            final crm = ctx.crmColors;
            final filtered = q.isEmpty
                ? packages
                : packages
                      .where(
                        (p) => p.name.toLowerCase().contains(q.toLowerCase()),
                      )
                      .toList();
            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                0,
                16,
                16 + MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Add a package',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    districtName == null
                        ? 'Standard prices — pick a district for local pricing.'
                        : 'Prices for $districtName',
                    style: TextStyle(fontSize: 12, color: crm.textSecondary),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Search packages…',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (v) => setSheet(() => q = v.trim()),
                  ),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(ctx).size.height * 0.45,
                    ),
                    child: filtered.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(24),
                            child: Text('No matching packages.'),
                          )
                        : ListView(
                            shrinkWrap: true,
                            children: [
                              for (final p in filtered)
                                ListTile(
                                  leading: Icon(
                                    Icons.inventory_2_outlined,
                                    color: crm.primary,
                                  ),
                                  title: Text(p.name),
                                  trailing: Text(
                                    _rupees(
                                      p.effectivePriceForDistrict(districtId),
                                    ),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  onTap: () => Navigator.pop(ctx, p),
                                ),
                            ],
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (picked != null) {
      final where = districtName != null ? ' · $districtName' : '';
      setState(
        () => _lines.add(
          SpotInvoiceLine(
            label: '${picked.name}$where',
            amount: picked.effectivePriceForDistrict(districtId),
          ),
        ),
      );
    }
  }

  Future<void> _generate(String? districtName) async {
    if (_customerCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a customer name')));
      return;
    }
    if (_lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one line item')),
      );
      return;
    }
    setState(() => _generating = true);
    try {
      final now = DateTime.now();
      final invoiceNo =
          'QT-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.millisecondsSinceEpoch % 100000}';
      await printSpotInvoice(
        SpotInvoiceData(
          invoiceNo: invoiceNo,
          customerName: _customerCtrl.text.trim(),
          customerPhone: _phoneCtrl.text.trim(),
          district: districtName ?? '',
          lines: List.of(_lines),
          date: now,
          note: _noteCtrl.text.trim(),
        ),
      );
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, e);
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final districts = ref.watch(districtsProvider).value ?? const <District>[];
    final districtName = _districtNameFor(districts, _districtId);
    final total = _lines.fold<double>(0, (s, l) => s + l.amount);

    final caption = _lines.isEmpty
        ? 'Invoice total · no GST'
        : 'Invoice total · ${_lines.length} item${_lines.length == 1 ? '' : 's'} · no GST';
    final actionLabel = _generating ? 'Generating…' : 'Generate & Share';
    final customer = _customerCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();

    return _TabScaffold(
      bottomBar: _TotalBar(
        total: total,
        caption: caption,
        actionLabel: actionLabel,
        actionIcon: Icons.ios_share_rounded,
        busy: _generating,
        onPressed: () => _generate(districtName),
      ),
      sidePanel: _SummaryPanel(
        title: 'Invoice preview',
        total: total,
        caption: caption,
        details: [
          ('Billed to', customer.isEmpty ? '—' : customer),
          if (phone.isNotEmpty) ('Phone', phone),
          ('District', districtName ?? '—'),
        ],
        lines: _lines,
        emptyMessage: 'Line items you add will appear here.',
        actionLabel: actionLabel,
        actionIcon: Icons.ios_share_rounded,
        busy: _generating,
        onPressed: () => _generate(districtName),
        footer: Text(
          'A shareable PDF quotation, no GST.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11.5, color: crm.textSecondary),
        ),
      ),
      builder: (wide) => [
        const _TabHeader(
          icon: Icons.receipt_long_rounded,
          title: 'Invoice',
          subtitle:
              'Generate a quotation and share it with the customer (no GST).',
        ),

        _Section(
          title: 'Billed to',
          icon: Icons.person_outline_rounded,
          child: Column(
            children: [
              _TwoUp(
                TextField(
                  controller: _customerCtrl,
                  onChanged: (_) => setState(() {}),
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Customer name *',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                TextField(
                  controller: _phoneCtrl,
                  onChanged: (_) => setState(() {}),
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone (optional)',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _DistrictField(
                districts: districts,
                value: _districtId,
                label: 'District',
                noneLabel: 'Select district',
                onChanged: (id) => setState(() => _districtId = id),
              ),
            ],
          ),
        ),

        _Section(
          title: 'Line items',
          icon: Icons.list_alt_rounded,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton.icon(
                onPressed: () => _addPackageDialog(districtName),
                icon: const Icon(Icons.inventory_2_outlined, size: 17),
                label: const Text('Package'),
              ),
              TextButton.icon(
                onPressed: () => _lineDialog(),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Custom'),
              ),
            ],
          ),
          child: _lines.isEmpty
              ? const _EmptyHint(
                  icon: Icons.playlist_add_rounded,
                  title: 'No items yet',
                  message:
                      'Add a package or a custom line, or build one in the Quote tab.',
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _LineList(
                      lines: _lines,
                      total: total,
                      onEdit: (i) => _lineDialog(index: i),
                      onRemove: (i) => setState(() => _lines.removeAt(i)),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tap an item to edit it.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: crm.textSecondary,
                      ),
                    ),
                  ],
                ),
        ),

        _Section(
          title: 'Note',
          icon: Icons.notes_rounded,
          child: TextField(
            controller: _noteCtrl,
            maxLines: 3,
            minLines: 2,
            decoration: const InputDecoration(
              hintText: 'Anything the customer should know (optional)',
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
//  Slots tab
// ─────────────────────────────────────────────────────────────────────────
// Read-only calendar of the month's morning/evening slot availability so a
// salesperson can see which days still have room before promising a date.
const _monthNames = [
  '',
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
const _weekdays = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _weekdaysLong = [
  '',
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

enum _DayState { open, low, full, blocked }

_DayState _stateOf(DaySlot d) {
  if (d.blocked) return _DayState.blocked;
  if (d.total.isFull) return _DayState.full;
  if (d.total.capacity > 0 && d.total.available / d.total.capacity <= 0.25) {
    return _DayState.low;
  }
  return _DayState.open;
}

class _AvailabilityTab extends ConsumerStatefulWidget {
  const _AvailabilityTab();
  @override
  ConsumerState<_AvailabilityTab> createState() => _AvailabilityTabState();
}

class _AvailabilityTabState extends ConsumerState<_AvailabilityTab> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  int? _selectedDay;

  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  bool get _isCurrentMonth =>
      _month.year == _today.year && _month.month == _today.month;

  void _setMonth(DateTime m) => setState(() {
    _month = DateTime(m.year, m.month);
    _selectedDay = null;
  });

  Color _colorFor(_DayState s, CrmTheme crm) => switch (s) {
    _DayState.open => crm.success,
    _DayState.low => crm.warning,
    _DayState.full => crm.destructive,
    _DayState.blocked => crm.textSecondary,
  };

  @override
  Widget build(BuildContext context) {
    final key = (year: _month.year, month: _month.month);
    final async = ref.watch(monthAvailabilityProvider(key));

    return Column(
      children: [
        _monthBar(context),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => AppErrorView(
              error: e,
              onRetry: () => ref.invalidate(monthAvailabilityProvider(key)),
            ),
            data: (m) {
              final byDay = {for (final d in m.days) d.date.day: d};
              final sel =
                  _selectedDay ??
                  (_isCurrentMonth ? _today.day : m.days.firstOrNull?.date.day);
              final detail = sel != null && byDay[sel] != null
                  ? _dayDetail(context, byDay[sel]!)
                  : null;
              return RefreshIndicator(
                onRefresh: () async =>
                    ref.invalidate(monthAvailabilityProvider(key)),
                child: LayoutBuilder(
                  builder: (context, c) {
                    final wide = c.maxWidth >= _wideBreakpoint;
                    final Widget body = wide
                        // Calendar on the left; month summary + selected day
                        // stay beside it on the right.
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _calendar(context, byDay, sel)),
                              const SizedBox(width: 20),
                              SizedBox(
                                width: _sidePanelWidth,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _summary(context, m),
                                    const SizedBox(height: 14),
                                    ?detail,
                                  ],
                                ),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _summary(context, m),
                              const SizedBox(height: 14),
                              _calendar(context, byDay, sel),
                              const SizedBox(height: 14),
                              ?detail,
                            ],
                          );
                    return ListView(
                      padding: EdgeInsets.fromLTRB(
                        wide ? 24 : 16,
                        wide ? 20 : 4,
                        wide ? 24 : 16,
                        28,
                      ),
                      children: [
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: _maxPageWidth,
                            ),
                            child: body,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _monthBar(BuildContext context) {
    final crm = context.crmColors;
    return Container(
      color: crm.surface,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxPageWidth),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Previous month',
                onPressed: () =>
                    _setMonth(DateTime(_month.year, _month.month - 1)),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final picked = await showMonthPicker(
                      context,
                      initial: _month,
                    );
                    if (picked != null) _setMonth(picked);
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.calendar_month_rounded,
                          size: 18,
                          color: crm.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_monthNames[_month.month]} ${_month.year}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: crm.textPrimary,
                          ),
                        ),
                        Icon(
                          Icons.arrow_drop_down_rounded,
                          size: 22,
                          color: crm.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (!_isCurrentMonth)
                TextButton(
                  onPressed: () => _setMonth(_today),
                  child: const Text('Today'),
                ),
              IconButton(
                tooltip: 'Next month',
                onPressed: () =>
                    _setMonth(DateTime(_month.year, _month.month + 1)),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summary(BuildContext context, MonthAvailability m) {
    final crm = context.crmColors;
    final pct = m.totalCapacity == 0
        ? 0.0
        : (m.totalBooked / m.totalCapacity).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [crm.primary, _darkWine],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: crm.primary.withValues(alpha: 0.24),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${m.totalAvailable}',
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  'slots open',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ),
              const Spacer(),
              _heroStat('${m.totalBooked}', 'Booked'),
              const SizedBox(width: 18),
              _heroStat('${m.totalCapacity}', 'Capacity'),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 7,
              backgroundColor: Colors.white.withValues(alpha: 0.22),
              valueColor: const AlwaysStoppedAnimation(_gold),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(pct * 100).round()}% booked  ·  ${m.defaultMorning} morning + ${m.defaultEvening} evening per day',
            style: TextStyle(
              fontSize: 11.5,
              color: Colors.white.withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroStat(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _calendar(
    BuildContext context,
    Map<int, DaySlot> byDay,
    int? selected,
  ) {
    final crm = context.crmColors;
    final first = DateTime(_month.year, _month.month, 1);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final leading = first.weekday - 1; // Monday-first grid
    final cellCount = ((leading + daysInMonth + 6) ~/ 7) * 7;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: crm.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              for (var w = 1; w <= 7; w++)
                Expanded(
                  child: Center(
                    child: Text(
                      _weekdays[w],
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: w >= 6 ? crm.primary : crm.textSecondary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth >= 480;
              final roomy = c.maxWidth >= 640;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: cellCount,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  childAspectRatio: wide ? 1.15 : 0.82,
                ),
                itemBuilder: (context, i) {
                  final day = i - leading + 1;
                  if (day < 1 || day > daysInMonth) return const SizedBox();
                  return _dayCell(
                    context,
                    day,
                    byDay[day],
                    day == selected,
                    roomy: roomy,
                  );
                },
              );
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              _legend(crm.success, 'Open'),
              _legend(crm.warning, 'Filling up'),
              _legend(crm.destructive, 'Full'),
              _legend(crm.textSecondary, 'Blocked'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dayCell(
    BuildContext context,
    int day,
    DaySlot? d,
    bool selected, {
    bool roomy = false,
  }) {
    final crm = context.crmColors;
    final date = DateTime(_month.year, _month.month, day);
    final isPast = date.isBefore(_today);
    final isToday = date == _today;
    final state = d == null ? null : _stateOf(d);
    final color = state == null ? crm.textSecondary : _colorFor(state, crm);
    final sub = d == null
        ? ''
        : switch (state!) {
            _DayState.blocked => '—',
            _DayState.full => 'Full',
            _ => '${d.total.available}',
          };

    return Opacity(
      opacity: isPast ? 0.45 : 1,
      child: Material(
        color: selected ? crm.primary : color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: d == null ? null : () => setState(() => _selectedDay = day),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: isToday && !selected
                  ? Border.all(color: crm.primary, width: 1.5)
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$day',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: selected ? Colors.white : crm.textPrimary,
                    decoration: state == _DayState.blocked
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                if (sub.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: selected ? _gold : color,
                    ),
                  ),
                ],
                // Big desktop cells also show the morning / evening split.
                if (roomy && d != null && !d.blocked) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.wb_sunny_rounded,
                        size: 11,
                        color: selected ? Colors.white70 : crm.textSecondary,
                      ),
                      Text(
                        ' ${d.morning.available}  ',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: selected ? Colors.white70 : crm.textSecondary,
                        ),
                      ),
                      Icon(
                        Icons.nightlight_round,
                        size: 11,
                        color: selected ? Colors.white70 : crm.textSecondary,
                      ),
                      Text(
                        ' ${d.evening.available}',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: selected ? Colors.white70 : crm.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _legend(Color c, String label) {
    final crm = context.crmColors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: c),
          ),
        ),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 11, color: crm.textSecondary)),
      ],
    );
  }

  Widget _dayDetail(BuildContext context, DaySlot d) {
    final crm = context.crmColors;
    final state = _stateOf(d);
    final color = _colorFor(state, crm);
    final status = switch (state) {
      _DayState.blocked => 'Blocked',
      _DayState.full => 'Fully booked',
      _ => '${d.total.available} of ${d.total.capacity} left',
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: crm.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _weekdaysLong[d.date.weekday],
                      style: TextStyle(fontSize: 12, color: crm.textSecondary),
                    ),
                    Text(
                      '${d.date.day} ${_monthNames[d.date.month]} ${d.date.year}',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: crm.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          if (d.isOverride) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.push_pin_rounded,
                  size: 14,
                  color: crm.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  'HR set a custom limit for this day',
                  style: TextStyle(fontSize: 11.5, color: crm.textSecondary),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          if (d.blocked)
            Text(
              'Blocked by HR — no bookings on this day.',
              style: TextStyle(fontSize: 13, color: crm.destructive),
            )
          else
            Row(
              children: [
                Expanded(
                  child: _halfTile(
                    context,
                    Icons.wb_sunny_rounded,
                    'Morning',
                    d.morning,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _halfTile(
                    context,
                    Icons.nightlight_round,
                    'Evening',
                    d.evening,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _halfTile(
    BuildContext context,
    IconData icon,
    String label,
    SlotHalf h,
  ) {
    final crm = context.crmColors;
    final color = h.isFull ? crm.destructive : crm.success;
    final pct = h.capacity == 0 ? 0.0 : (h.booked / h.capacity).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: crm.input,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: crm.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: crm.textSecondary),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: crm.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            h.isFull ? 'Full' : '${h.available} open',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 5,
              backgroundColor: color.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${h.booked}/${h.capacity} booked',
            style: TextStyle(fontSize: 11, color: crm.textSecondary),
          ),
        ],
      ),
    );
  }
}
