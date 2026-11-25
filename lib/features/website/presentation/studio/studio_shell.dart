import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nizan_crm/core/auth/access_control.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/website/data/website_models.dart';
import 'package:nizan_crm/features/website/data/website_pages.dart';
import 'package:nizan_crm/features/website/services/website_service.dart';
import 'package:nizan_crm/features/website/presentation/studio/studio_widgets.dart';
import 'package:nizan_crm/features/website/presentation/studio/website_links.dart';

/// Which page of the studio is open: 'overview', 'gallery', 'packages',
/// 'enquiries', or `section:KEY` (e.g. `section:hero`).
typedef StudioLocation = String;

const _pageGroups = websitePageNames;

/// Website Studio frame: navigation on the left (wide screens) or a
/// "Jump to…" menu on top (narrow screens), the page on the right.
class StudioShell extends ConsumerWidget {
  final StudioLocation current;
  final Widget child;
  const StudioShell({super.key, required this.current, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 980;
        return Container(
          color: crm.background,
          child: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: 272, child: StudioNav(current: current)),
                    VerticalDivider(width: 1, thickness: 1, color: crm.border),
                    Expanded(child: child),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _CompactBar(current: current),
                    Expanded(child: child),
                  ],
                ),
        );
      },
    );
  }
}

class _CompactBar extends StatelessWidget {
  final StudioLocation current;
  const _CompactBar({required this.current});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Material(
      color: crm.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: [
            Icon(Icons.language, color: crm.primary),
            const SizedBox(width: 8),
            Text(
              'Website Studio',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: crm.textPrimary,
              ),
            ),
            const Spacer(),
            OutlinedButton.icon(
              icon: const Icon(Icons.menu, size: 18),
              label: const Text('Jump to…'),
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => SizedBox(
                  height: MediaQuery.of(context).size.height * 0.8,
                  child: StudioNav(
                    current: current,
                    onNavigate: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The studio's navigation: the whole website as a list, with live/draft dots.
class StudioNav extends ConsumerWidget {
  final StudioLocation current;
  final VoidCallback? onNavigate;
  const StudioNav({super.key, required this.current, this.onNavigate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final access = Access.of(ref.watch(authSessionProvider));
    final canContent = access.canSeeWebsiteArea('content');
    final canGallery = access.canSeeWebsiteArea('gallery');
    final canPackages = access.canSeeWebsiteArea('packages');
    final canEnquiries = access.canSeeWebsiteArea('enquiries');

    final sections = canContent
        ? ref.watch(websiteSectionsProvider).value ?? const <SectionSummary>[]
        : const <SectionSummary>[];
    final newEnquiries = canEnquiries
        ? ref
                  .watch(websiteEnquiriesProvider((status: 'new', page: 1)))
                  .value
                  ?.counts['new'] ??
              0
        : 0;

    void go(String path) {
      onNavigate?.call();
      context.go(path);
    }

    final byPage = <String, List<SectionSummary>>{};
    for (final s in sections) {
      byPage.putIfAbsent(s.page, () => []).add(s);
    }

    return Material(
      color: crm.surface,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
        children: [
          // Brand block
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: crm.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.language,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Website Studio',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: crm.textPrimary,
                        ),
                      ),
                      InkWell(
                        onTap: () => openWebsite(context),
                        child: Text(
                          Uri.parse(websiteBaseUrl).host.isEmpty
                              ? websiteBaseUrl
                              : Uri.parse(websiteBaseUrl).host,
                          style: TextStyle(
                            fontSize: 12,
                            color: crm.accent,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _NavItem(
            icon: Icons.dashboard_outlined,
            label: 'Overview',
            selected: current == 'overview',
            onTap: () => go('/website'),
          ),
          if (canContent)
            for (final page in _pageGroups.keys)
              if (byPage[page]?.isNotEmpty ?? false) ...[
                _NavHeading(_pageGroups[page]!),
                for (final s in byPage[page]!)
                  _NavItem(
                    label: s.label,
                    dot: s.status,
                    dense: true,
                    selected: current == 'section:${s.key}',
                    onTap: () => go('/website/section/${s.key}'),
                  ),
              ],
          if (canGallery || canPackages) const _NavHeading('Photos & services'),
          if (canGallery)
            _NavItem(
              icon: Icons.photo_library_outlined,
              label: 'Portfolio gallery',
              selected: current == 'gallery',
              onTap: () => go('/website/gallery'),
            ),
          if (canPackages)
            _NavItem(
              icon: Icons.sell_outlined,
              label: 'Packages & add-ons',
              selected: current == 'packages',
              onTap: () => go('/website/packages'),
            ),
          if (canEnquiries) ...[
            const _NavHeading('Inbox'),
            _NavItem(
              icon: Icons.inbox_outlined,
              label: 'Enquiries',
              badge: newEnquiries > 0 ? '$newEnquiries new' : null,
              selected: current == 'enquiries',
              onTap: () => go('/website/enquiries'),
            ),
          ],
          if (canContent) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  for (final st in ['published', 'changed', 'empty'])
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        StatusDot(status: st, size: 7),
                        const SizedBox(width: 4),
                        Text(
                          sectionStatusStyle(context, st).label,
                          style: TextStyle(
                            fontSize: 11,
                            color: crm.textSecondary,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NavHeading extends StatelessWidget {
  final String text;
  const _NavHeading(this.text);

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 18, 10, 6),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w700,
          color: crm.textSecondary,
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData? icon;
  final String label;
  final String? dot;
  final String? badge;
  final bool selected;
  final bool dense;
  final VoidCallback onTap;

  const _NavItem({
    required this.label,
    required this.onTap,
    this.icon,
    this.dot,
    this.badge,
    this.selected = false,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final fg = selected ? crm.primary : crm.textPrimary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: selected
            ? crm.primary.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 10,
              vertical: dense ? 8 : 10,
            ),
            child: Row(
              children: [
                if (icon != null)
                  Icon(icon, size: 18, color: fg)
                else
                  SizedBox(
                    width: 18,
                    child: Center(child: StatusDot(status: dot ?? 'empty')),
                  ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: fg,
                    ),
                  ),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: crm.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      badge!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
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
