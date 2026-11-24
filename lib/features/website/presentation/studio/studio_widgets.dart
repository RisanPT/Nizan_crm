import 'package:flutter/material.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';

/// Shared building blocks for the Website Studio screens, so every page has
/// the same header, card style and status colours.

/// Colour + label for a section status (draft / published / changed / empty).
({String label, Color color}) sectionStatusStyle(
  BuildContext context,
  String status,
) {
  final crm = context.crmColors;
  return switch (status) {
    'published' => (label: 'Live', color: crm.success),
    'changed' => (label: 'Unpublished changes', color: crm.warning),
    'draft' => (label: 'Draft — not live', color: crm.warning),
    _ => (label: 'Website text', color: crm.textSecondary),
  };
}

/// A small coloured dot for a section's status (used in the navigation).
class StatusDot extends StatelessWidget {
  final String status;
  final double size;
  const StatusDot({super.key, required this.status, this.size = 8});

  @override
  Widget build(BuildContext context) {
    final s = sectionStatusStyle(context, status);
    final hollow = status == 'empty' || status.isEmpty;
    return Tooltip(
      message: s.label,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: hollow ? Colors.transparent : s.color,
          border: Border.all(color: s.color, width: 1.4),
        ),
      ),
    );
  }
}

/// White card with the CRM's warm hairline border and a soft radius.
class StudioCard extends StatelessWidget {
  final Widget child;
  final String? title;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  final Color? color;

  const StudioCard({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.all(16),
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    // A Material (not a coloured box) so taps on rows inside show their ripple.
    return Material(
      color: color ?? crm.surface,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: crm.border),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title!,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: crm.textPrimary,
                          ),
                        ),
                        if (subtitle != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              subtitle!,
                              style: TextStyle(
                                fontSize: 12,
                                color: crm.textSecondary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  ?trailing,
                ],
              ),
              const SizedBox(height: 14),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

/// Page header used by every studio page: title, one-line description, actions.
class StudioPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? badge;
  final List<Widget> actions;
  final IconData? icon;

  const StudioPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.badge,
    this.actions = const [],
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Container(
      decoration: BoxDecoration(
        color: crm.surface,
        border: Border(bottom: BorderSide(color: crm.border)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 12,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: crm.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: crm.primary, size: 20),
                ),
                const SizedBox(width: 12),
              ],
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Wrap(
                      spacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: crm.textPrimary,
                          ),
                        ),
                        ?badge,
                      ],
                    ),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 13,
                            color: crm.textSecondary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (actions.isNotEmpty)
            Wrap(spacing: 8, runSpacing: 8, children: actions),
        ],
      ),
    );
  }
}

/// Status pill: "Live", "Unpublished changes"…
class StatusPill extends StatelessWidget {
  final String status;
  final String? labelOverride;
  const StatusPill({super.key, required this.status, this.labelOverride});

  @override
  Widget build(BuildContext context) {
    final s = sectionStatusStyle(context, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: s.color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          StatusDot(status: status, size: 7),
          const SizedBox(width: 6),
          Text(
            labelOverride ?? s.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: s.color,
            ),
          ),
        ],
      ),
    );
  }
}

/// A number tile on the overview ("Sections live 8 / 12").
class StudioStatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? note;
  final Color? accent;
  final VoidCallback? onTap;
  final double width;

  const StudioStatTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.note,
    this.accent,
    this.onTap,
    this.width = 220,
  });

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final color = accent ?? crm.primary;
    return Material(
      color: crm.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: width,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: crm.border),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: crm.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                value,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: crm.textPrimary,
                ),
              ),
              if (note != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    note!,
                    style: TextStyle(fontSize: 12, color: color),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Centers page content and limits its width so long forms stay readable.
class StudioBody extends StatelessWidget {
  final List<Widget> children;
  final double maxWidth;
  const StudioBody({super.key, required this.children, this.maxWidth = 1180});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ],
    );
  }
}
