import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// The Marketing ERP's design system — the look of the marketing team's UX document ("Marketing ERP: UX design and requirements"):
// a warm, light page; white rounded cards with a hairline border; a violet accent for tabs, links and charts; the maroon of the brand for
// the sidebar and the main button; pastel icon tiles; small, quiet type. Every Marketing screen is built from these pieces so they read
// as one product.

class Mkt {
  Mkt._();

  static const violet = Color(0xFF5B3FD9);
  static const violet2 = Color(0xFF7C5CE8);
  static const violetSoft = Color(0xFFEDE8FB);
  static const bg = Color(0xFFF7F4FA);
  static const card = Colors.white;
  static const border = Color(0xFFE9E3F1);
  static const ink = Color(0xFF2A1A24);
  static const inkSoft = Color(0xFF7B6F82);
  static const maroon = Color(0xFF5A1030);
  static const maroonDeep = Color(0xFF3F0B22);

  static const good = Color(0xFF22A06B);
  static const bad = Color(0xFFE5484D);
  static const warn = Color(0xFFF5A524);
  static const blue = Color(0xFF3B82F6);
  static const pink = Color(0xFFE05D9A);
  static const teal = Color(0xFF14B8A6);
  static const grey = Color(0xFF9AA0A6);

  /// Chart / legend colours by position, so a chart and its legend always agree.
  static const palette = <Color>[violet2, blue, good, warn, pink, teal, grey];
  static Color series(int i) => palette[i % palette.length];

  static Color tint(Color c, [double a = 0.12]) => c.withValues(alpha: a);
}

TextStyle mktText(
  double size, {
  FontWeight weight = FontWeight.w500,
  Color color = Mkt.ink,
  double? height,
  double? spacing,
}) => TextStyle(
  fontSize: size,
  fontWeight: weight,
  color: color,
  height: height,
  letterSpacing: spacing,
);

/// The page behind everything: fills the area, light and warm.
class MktPage extends StatelessWidget {
  const MktPage({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => ColoredBox(color: Mkt.bg, child: child);
}

// ── header ───────────────────────────────────────────────────────────────────

/// Icon tile · title · subtitle on the left; filters and the main button on the right (wrapping under on a phone).
class MktHeader extends StatelessWidget {
  const MktHeader({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.breadcrumb,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? breadcrumb;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final left = Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Mkt.violetSoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Mkt.violet, size: 22),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    if (breadcrumb != null)
                      TextSpan(
                        text: '$breadcrumb  ›  ',
                        style: mktText(
                          wide ? 20 : 17,
                          weight: FontWeight.w600,
                          color: Mkt.inkSoft,
                        ),
                      ),
                    TextSpan(text: title),
                  ],
                ),
                key: const Key('mkt_title'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: mktText(
                  wide ? 20 : 17,
                  weight: FontWeight.w800,
                  spacing: -0.3,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: mktText(12, color: Mkt.inkSoft),
                ),
            ],
          ),
        ),
      ],
    );
    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: left),
          const SizedBox(width: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: actions,
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        left,
        if (actions.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: actions,
          ),
        ],
      ],
    );
  }
}

/// A rounded white "pill" that opens something: the date range, a brand picker.
class MktPill extends StatelessWidget {
  const MktPill({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.trailing = true,
  });
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool trailing;

  @override
  Widget build(BuildContext context) => Material(
    color: Mkt.card,
    borderRadius: BorderRadius.circular(9),
    child: InkWell(
      borderRadius: BorderRadius.circular(9),
      onTap: onTap,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: Mkt.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: Mkt.inkSoft),
              const SizedBox(width: 7),
            ],
            Text(label, style: mktText(12.5, weight: FontWeight.w600)),
            if (trailing) ...[
              const SizedBox(width: 6),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 17,
                color: Mkt.inkSoft,
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

/// A pill that drops a menu of choices.
class MktDropdownPill<T> extends StatelessWidget {
  const MktDropdownPill({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.icon,
  });
  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final label = options
        .firstWhere((o) => o.$1 == value, orElse: () => options.first)
        .$2;
    return PopupMenuButton<T>(
      tooltip: '',
      position: PopupMenuPosition.under,
      onSelected: onChanged,
      itemBuilder: (_) => [
        for (final o in options)
          PopupMenuItem<T>(
            value: o.$1,
            child: Text(
              o.$2,
              style: mktText(
                13,
                weight: o.$1 == value ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ),
      ],
      child: IgnorePointer(
        child: MktPill(label: label, icon: icon),
      ),
    );
  }
}

/// The date range pill ("2 – 8 Nov 2026").
class MktDateRangePill extends StatelessWidget {
  const MktDateRangePill({
    super.key,
    required this.from,
    required this.to,
    required this.onTap,
  });
  final DateTime from;
  final DateTime to;
  final VoidCallback onTap;

  static String label(DateTime from, DateTime to) {
    if (from.year == to.year && from.month == to.month && from.day == to.day) {
      return DateFormat('d MMM yyyy').format(from);
    }
    if (from.year == to.year && from.month == to.month) {
      return '${from.day} – ${DateFormat('d MMM yyyy').format(to)}';
    }
    return '${DateFormat('d MMM').format(from)} – ${DateFormat('d MMM yyyy').format(to)}';
  }

  @override
  Widget build(BuildContext context) => MktPill(
    key: const Key('mkt_date_range'),
    label: label(from, to),
    icon: Icons.calendar_today_outlined,
    onTap: onTap,
  );
}

/// The main button of a page: maroon, white text ("+ Log Activity").
class MktPrimaryButton extends StatelessWidget {
  const MktPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.add_rounded,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: onPressed,
    style: FilledButton.styleFrom(
      backgroundColor: Mkt.maroon,
      foregroundColor: Colors.white,
      minimumSize: const Size(0, 38),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      textStyle: mktText(13, weight: FontWeight.w700),
    ),
    icon: Icon(icon, size: 17),
    label: Text(label),
  );
}

// ── tabs ─────────────────────────────────────────────────────────────────────

class MktTabSpec {
  const MktTabSpec(this.id, this.label, this.icon);
  final String id;
  final String label;
  final IconData icon;
}

/// The row of pill tabs under the header: even-width pills with an icon, the open one filled in violet.
class MktTabPills extends StatelessWidget {
  const MktTabPills({
    super.key,
    required this.tabs,
    required this.selected,
    required this.onSelect,
    this.keyPrefix = 'mkt_tab',
  });
  final List<MktTabSpec> tabs;
  final String selected;
  final ValueChanged<String> onSelect;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    Widget pill(MktTabSpec t, {required bool fill}) {
      final on = t.id == selected;
      final body = Container(
        key: Key('${keyPrefix}_${t.id}'),
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: on
              ? const LinearGradient(colors: [Mkt.violet, Mkt.violet2])
              : null,
          color: on ? null : Mkt.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: on ? Colors.transparent : Mkt.border),
          boxShadow: on
              ? [
                  BoxShadow(
                    color: Mkt.violet.withValues(alpha: 0.28),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(t.icon, size: 16, color: on ? Colors.white : Mkt.inkSoft),
            const SizedBox(width: 7),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  t.label,
                  maxLines: 1,
                  style: mktText(
                    12.5,
                    weight: FontWeight.w700,
                    color: on ? Colors.white : Mkt.ink,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onSelect(t.id),
        child: body,
      );
    }

    return LayoutBuilder(
      builder: (context, box) {
        final roomy = box.maxWidth >= tabs.length * 128;
        if (roomy) {
          return Row(
            children: [
              for (var i = 0; i < tabs.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: pill(tabs[i], fill: true)),
              ],
            ],
          );
        }
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < tabs.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                pill(tabs[i], fill: false),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ── cards ────────────────────────────────────────────────────────────────────

/// A white rounded card: a small violet icon, a bold title, a "View All →" link on the right, then the content.
class MktCard extends StatelessWidget {
  const MktCard({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.subtitle,
    this.link,
    this.onLink,
    this.linkKey,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(14, 12, 14, 14),
    this.iconColor = Mkt.violet,
  });
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color iconColor;
  final String? link;
  final VoidCallback? onLink;

  /// Pins the link for tests / deep links when a page has several "View All" links.
  final Key? linkKey;
  final Widget? trailing;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: Mkt.card,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Mkt.border),
      boxShadow: [
        BoxShadow(
          color: Mkt.violet.withValues(alpha: 0.035),
          blurRadius: 14,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    // a transparent Material over the white: taps and list tiles inside a card show their ink on the card, not behind it
    child: Material(
      type: MaterialType.transparency,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 17, color: iconColor),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: mktText(13.5, weight: FontWeight.w800),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: mktText(11, color: Mkt.inkSoft),
                      ),
                  ],
                ),
              ),
              ?trailing,
              if (link != null)
                InkWell(
                  key:
                      linkKey ??
                      Key(
                        'mkt_link_${link!.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}',
                      ),
                  onTap: onLink,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Text(
                      '$link  →',
                      style: mktText(
                        11.5,
                        weight: FontWeight.w700,
                        color: Mkt.violet,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    ),
  );
}

/// One headline number: a pastel icon tile, the value, its label and how it moved (green up, red down).
class MktKpiCard extends StatelessWidget {
  const MktKpiCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.note,
    this.good,
    this.tint = Mkt.violet,
    this.spark,
    this.onTap,
  });
  final IconData icon;
  final String value;
  final String label;
  final String? note;

  /// null = neutral grey, true = green, false = red.
  final bool? good;
  final Color tint;
  final List<double>? spark;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final noteColor = good == null ? Mkt.inkSoft : (good! ? Mkt.good : Mkt.bad);
    final body = Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 10),
      decoration: BoxDecoration(
        color: Mkt.card,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Mkt.border),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Mkt.tint(tint, 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 20, color: tint),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: mktText(20, weight: FontWeight.w800, spacing: -0.4),
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: mktText(
                    11,
                    weight: FontWeight.w600,
                    color: Mkt.inkSoft,
                  ),
                ),
                // the change line shrinks to fit the card instead of being cut ("↑ +200% vs last week")
                if (note != null && note!.isNotEmpty)
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      note!,
                      maxLines: 1,
                      style: mktText(
                        10.5,
                        weight: FontWeight.w700,
                        color: noteColor,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (spark != null && spark!.length > 1)
            SizedBox(
              width: 44,
              height: 26,
              child: MktSparkline(values: spark!, color: tint),
            ),
        ],
      ),
    );
    return onTap == null
        ? body
        : InkWell(
            borderRadius: BorderRadius.circular(13),
            onTap: onTap,
            child: body,
          );
  }
}

/// KPI cards in one row on a laptop (six across, like the document), two or three across on smaller screens.
class MktKpiRow extends StatelessWidget {
  const MktKpiRow({super.key, required this.children, this.minWidth = 168});
  final List<Widget> children;
  final double minWidth;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      const gap = 10.0;
      final cols = (box.maxWidth / minWidth).floor().clamp(
        1,
        children.length.clamp(1, 8),
      );
      final w = (box.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [for (final c in children) SizedBox(width: w, child: c)],
      );
    },
  );
}

class MktSparkline extends StatelessWidget {
  const MktSparkline({
    super.key,
    required this.values,
    this.color = Mkt.violet,
  });
  final List<double> values;
  final Color color;

  @override
  Widget build(BuildContext context) => LineChart(
    LineChartData(
      gridData: const FlGridData(show: false),
      borderData: FlBorderData(show: false),
      titlesData: const FlTitlesData(show: false),
      lineTouchData: const LineTouchData(enabled: false),
      minY: values.reduce((a, b) => a < b ? a : b) - 0.5,
      lineBarsData: [
        LineChartBarData(
          spots: [
            for (var i = 0; i < values.length; i++)
              FlSpot(i.toDouble(), values[i]),
          ],
          isCurved: true,
          color: color,
          barWidth: 2,
          dotData: const FlDotData(show: false),
        ),
      ],
    ),
  );
}

// ── small pieces ─────────────────────────────────────────────────────────────

/// A coloured status word in a rounded chip ("Active", "On Shoot", "High").
class MktChip extends StatelessWidget {
  const MktChip(
    this.text, {
    super.key,
    this.color = Mkt.violet,
    this.solid = false,
    this.icon,
  });
  final String text;
  final Color color;
  final bool solid;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: solid ? color : Mkt.tint(color, 0.12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 11, color: solid ? Colors.white : color),
          const SizedBox(width: 3),
        ],
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: mktText(
              10.5,
              weight: FontWeight.w700,
              color: solid ? Colors.white : color,
            ),
          ),
        ),
      ],
    ),
  );
}

/// A person's initials in a tinted circle (the document shows photos; we have none).
class MktAvatar extends StatelessWidget {
  const MktAvatar(this.name, {super.key, this.size = 26});
  final String name;
  final double size;

  static const _tints = <Color>[
    Color(0xFF7C5CE8),
    Color(0xFF3B82F6),
    Color(0xFF22A06B),
    Color(0xFFE05D9A),
    Color(0xFFF5A524),
    Color(0xFF14B8A6),
  ];

  @override
  Widget build(BuildContext context) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    final initials = parts.isEmpty
        ? '?'
        : (parts.length == 1 ? parts.first[0] : parts.first[0] + parts.last[0])
              .toUpperCase();
    final c =
        _tints[name.codeUnits.fold<int>(0, (s, u) => s + u) % _tints.length];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Mkt.tint(c, 0.16),
        shape: BoxShape.circle,
      ),
      child: Text(
        initials,
        style: mktText(size * 0.4, weight: FontWeight.w800, color: c),
      ),
    );
  }
}

/// A thin bar with the percentage after it.
class MktProgress extends StatelessWidget {
  const MktProgress({
    super.key,
    required this.pct,
    this.color = Mkt.good,
    this.height = 7,
    this.showLabel = true,
    this.labelWidth = 38,
  });
  final int pct;
  final Color color;
  final double height;
  final bool showLabel;
  final double labelWidth;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(height),
          child: LinearProgressIndicator(
            value: pct.clamp(0, 100) / 100,
            minHeight: height,
            backgroundColor: Mkt.tint(color, 0.14),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ),
      if (showLabel) ...[
        const SizedBox(width: 8),
        SizedBox(
          width: labelWidth,
          child: Text(
            '$pct%',
            textAlign: TextAlign.right,
            style: mktText(11.5, weight: FontWeight.w700),
          ),
        ),
      ],
    ],
  );
}

class MktEmpty extends StatelessWidget {
  const MktEmpty(
    this.text, {
    super.key,
    this.icon = Icons.inbox_outlined,
    this.height = 96,
  });
  final String text;
  final IconData icon;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: Mkt.inkSoft.withValues(alpha: 0.6)),
          const SizedBox(height: 6),
          Text(
            text,
            textAlign: TextAlign.center,
            style: mktText(12.5, color: Mkt.inkSoft),
          ),
        ],
      ),
    ),
  );
}

/// One column of a table: its heading, its share of the row, and how its cells line up.
class MktCol {
  const MktCol(
    this.label, {
    this.flex = 1,
    this.align = Alignment.centerLeft,
    this.width,
  });
  final String label;
  final int flex;
  final Alignment align;

  /// A fixed width instead of a share (an avatar column, a "View" link).
  final double? width;
}

/// A table drawn in rows (so it fits a card): small grey headings, rows with hairline dividers. [rows] are lists of cell widgets, one per column.
class MktTable extends StatelessWidget {
  const MktTable({
    super.key,
    required this.columns,
    required this.rows,
    this.onRowTap,
    this.rowKeys,
    this.rowHeight = 46,
    this.minWidth,
  });
  final List<MktCol> columns;
  final List<List<Widget>> rows;
  final void Function(int index)? onRowTap;
  final List<Key?>? rowKeys;
  final double rowHeight;

  /// Below this width the table scrolls sideways instead of squeezing.
  final double? minWidth;

  Widget _cells(List<Widget> cells) => Row(
    children: [
      for (var i = 0; i < columns.length; i++)
        if (columns[i].width != null)
          SizedBox(
            width: columns[i].width,
            child: Align(alignment: columns[i].align, child: cells[i]),
          )
        else
          Expanded(
            flex: columns[i].flex,
            child: Align(alignment: columns[i].align, child: cells[i]),
          ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final table = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Mkt.border)),
          ),
          child: _cells([
            for (final c in columns)
              Text(
                c.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: mktText(
                  10.5,
                  weight: FontWeight.w800,
                  color: Mkt.inkSoft,
                  spacing: 0.2,
                ),
              ),
          ]),
        ),
        for (var r = 0; r < rows.length; r++)
          InkWell(
            key: rowKeys == null || r >= rowKeys!.length ? null : rowKeys![r],
            onTap: onRowTap == null ? null : () => onRowTap!(r),
            child: Container(
              constraints: BoxConstraints(minHeight: rowHeight),
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                border: r == rows.length - 1
                    ? null
                    : const Border(bottom: BorderSide(color: Mkt.border)),
              ),
              child: _cells(rows[r]),
            ),
          ),
      ],
    );
    if (minWidth == null) return table;
    return LayoutBuilder(
      builder: (context, box) => box.maxWidth >= minWidth!
          ? table
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(width: minWidth, child: table),
            ),
    );
  }
}

/// A dot-and-line timeline of dated items (Today's Team Activity).
class MktTimeline extends StatelessWidget {
  const MktTimeline({super.key, required this.items});
  final List<MktTimelineItem> items;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var i = 0; i < items.length; i++)
        KeyedSubtree(
          key: items[i].key,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 56,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      items[i].time,
                      style: mktText(10.5, color: Mkt.inkSoft),
                    ),
                  ),
                ),
                Column(
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      margin: const EdgeInsets.only(top: 3),
                      decoration: BoxDecoration(
                        color: items[i].color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    if (i < items.length - 1)
                      Expanded(child: Container(width: 1.5, color: Mkt.border)),
                  ],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          items[i].title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: mktText(12, weight: FontWeight.w700),
                        ),
                        if (items[i].subtitle.isNotEmpty)
                          Text(
                            items[i].subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: mktText(11, color: Mkt.inkSoft),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
    ],
  );
}

class MktTimelineItem {
  const MktTimelineItem({
    required this.time,
    required this.title,
    this.subtitle = '',
    this.color = Mkt.violet,
    this.key,
  });
  final String time;
  final String title;
  final String subtitle;
  final Color color;
  final Key? key;
}

/// A donut with a total in the middle and a legend beside it.
class MktDonut extends StatelessWidget {
  const MktDonut({
    super.key,
    required this.slices,
    required this.centerValue,
    required this.centerLabel,
    this.centerKey,
    this.colors,
    this.size = 112,
    this.sideBySideFrom = 330,
  });
  final List<({String label, double value, String trailing})> slices;
  final String centerValue;
  final String centerLabel;
  final Key? centerKey;

  /// A colour for each slice (same order); the palette by position when null.
  final List<Color>? colors;
  final double size;

  /// The legend sits beside the donut when the card is at least this wide, and under it when narrower (so labels are never cut).
  final double sideBySideFrom;

  Color _colorAt(int i) =>
      colors != null && i < colors!.length ? colors![i] : Mkt.series(i);

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) =>
        _build(context, legendRight: box.maxWidth >= sideBySideFrom),
  );

  Widget _build(BuildContext context, {required bool legendRight}) {
    final donut = SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: size * 0.33,
              sections: [
                for (var i = 0; i < slices.length; i++)
                  PieChartSectionData(
                    value: slices[i].value <= 0 ? 0.0001 : slices[i].value,
                    color: _colorAt(i),
                    radius: size * 0.15,
                    showTitle: false,
                  ),
              ],
            ),
          ),
          // the middle of the ring is small: a long value (270h 38m) shrinks to fit instead of running over the ring
          SizedBox(
            width: size * 0.56,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    centerValue,
                    key: centerKey,
                    style: mktText(size * 0.19, weight: FontWeight.w800),
                  ),
                  Text(centerLabel, style: mktText(9.5, color: Mkt.inkSoft)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
    final legend = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < slices.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _colorAt(i),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    slices[i].label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: mktText(11.5),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  slices[i].trailing,
                  style: mktText(11, color: Mkt.inkSoft),
                ),
              ],
            ),
          ),
      ],
    );
    return legendRight
        ? Row(
            children: [
              donut,
              const SizedBox(width: 14),
              Expanded(child: legend),
            ],
          )
        : Column(children: [donut, const SizedBox(height: 10), legend]);
  }
}

/// Lays the cards of a dashboard out in columns on a laptop and one under another on a phone. [rows]: each row is a list of (flex, card).
class MktGrid extends StatelessWidget {
  const MktGrid({
    super.key,
    required this.rows,
    this.breakpoint = 1000,
    this.gap = 12,
  });
  final List<List<(int, Widget)>> rows;
  final double breakpoint;
  final double gap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final wide = box.maxWidth >= breakpoint;
      final children = <Widget>[];
      for (final row in rows) {
        if (wide) {
          children.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < row.length; i++) ...[
                  if (i > 0) SizedBox(width: gap),
                  Expanded(flex: row[i].$1, child: row[i].$2),
                ],
              ],
            ),
          );
        } else {
          for (final c in row) {
            children.add(c.$2);
          }
        }
      }
      return Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(height: gap),
            children[i],
          ],
        ],
      );
    },
  );
}

/// A rounded toggle for filtering a list by kind or status: violet-tinted when on.
class MktFilterChip extends StatelessWidget {
  const MktFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(20),
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? Mkt.violetSoft : Mkt.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: selected ? Mkt.violet : Mkt.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: mktText(
              12,
              weight: selected ? FontWeight.w800 : FontWeight.w600,
              color: selected ? Mkt.violet : Mkt.ink,
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: 6),
            Text(
              '$count',
              style: mktText(
                11,
                weight: FontWeight.w700,
                color: selected ? Mkt.violet : Mkt.inkSoft,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
