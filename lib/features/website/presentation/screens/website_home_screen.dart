import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/auth/access_control.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/website/data/website_models.dart';
import 'package:nizan_crm/features/website/data/website_pages.dart';
import 'package:nizan_crm/features/website/services/website_service.dart';
import 'package:nizan_crm/features/website/presentation/studio/studio_shell.dart';
import 'package:nizan_crm/features/website/presentation/studio/studio_widgets.dart';
import 'package:nizan_crm/features/website/presentation/studio/website_links.dart';
import 'package:nizan_crm/features/website/presentation/widgets/visitors_card.dart';

/// Website Studio → Overview: the state of the whole website at a glance,
/// visitors, what needs attention, and the latest enquiries.
class WebsiteHomeScreen extends ConsumerWidget {
  /// Old links (/website?tab=gallery) still land on the right page.
  final String initialTab;
  const WebsiteHomeScreen({super.key, this.initialTab = ''});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const legacy = {
      'gallery': '/website/gallery',
      'packages': '/website/packages',
      'enquiries': '/website/enquiries',
    };
    final redirect = legacy[initialTab];
    if (redirect != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go(redirect);
      });
    }
    return const StudioShell(current: 'overview', child: _Overview());
  }
}

class _Overview extends ConsumerWidget {
  const _Overview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final access = Access.of(ref.watch(authSessionProvider));
    final canContent = access.canSeeWebsiteArea('content');
    final canGallery = access.canSeeWebsiteArea('gallery');
    final canPackages = access.canSeeWebsiteArea('packages');
    final canEnquiries = access.canSeeWebsiteArea('enquiries');

    final sections = canContent ? ref.watch(websiteSectionsProvider) : null;
    final gallery = canGallery ? ref.watch(websiteGalleryProvider) : null;
    final packages = canPackages ? ref.watch(websitePackagesProvider) : null;
    final enquiries = canEnquiries
        ? ref.watch(websiteEnquiriesProvider((status: '', page: 1)))
        : null;

    final secList = sections?.value ?? const <SectionSummary>[];
    final live = secList
        .where((s) => s.status == 'published' || s.status == 'changed')
        .length;
    final pending = secList
        .where((s) => s.status == 'changed' || s.status == 'draft')
        .toList();
    final photos = gallery?.value ?? const <GalleryItem>[];
    final shownPhotos = photos.where((g) => g.active).length;
    final homePhotos = photos.where((g) => g.active && g.featuredOnHome).length;
    final pkgData = packages?.value;
    final shownPackages = pkgData?.packages.where((p) => p.show).length ?? 0;
    final enqPage = enquiries?.value;
    final newCount = enqPage?.counts['new'] ?? 0;
    final failed =
        enqPage?.items.where((e) => e.leadAction == 'failed').length ?? 0;

    // Things worth doing next, each with a button that goes there.
    final attention = <({IconData icon, Color color, String text, String action, String path})>[
      for (final s in pending)
        (
          icon: Icons.edit_note,
          color: crm.warning,
          text:
              '${s.label}: ${s.status == 'draft' ? 'draft saved, not published' : 'edits not published yet'}',
          action: 'Review',
          path: '/website/section/${s.key}',
        ),
      if (canEnquiries && newCount > 0)
        (
          icon: Icons.mark_email_unread_outlined,
          color: crm.primary,
          text:
              '$newCount new enquir${newCount == 1 ? 'y' : 'ies'} from the website',
          action: 'Open',
          path: '/website/enquiries',
        ),
      if (failed > 0)
        (
          icon: Icons.error_outline,
          color: crm.destructive,
          text:
              '$failed enquir${failed == 1 ? 'y' : 'ies'} could not become a lead — add in Sales',
          action: 'Open',
          path: '/website/enquiries',
        ),
      if (canPackages && pkgData != null && shownPackages == 0)
        (
          icon: Icons.sell_outlined,
          color: crm.warning,
          text:
              'No CRM package is switched on — the website shows no packages',
          action: 'Choose',
          path: '/website/packages',
        ),
      if (canGallery && gallery?.value != null && homePhotos < 4)
        (
          icon: Icons.star_border,
          color: crm.textSecondary,
          text:
              'Mark 4 gallery photos "Show in Recent brides" to replace the home page mosaic ($homePhotos/4)',
          action: 'Gallery',
          path: '/website/gallery',
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const StudioPageHeader(
          icon: Icons.dashboard_outlined,
          title: 'Overview',
          subtitle:
              'Everything visitors see on the website, managed from here.',
        ),
        Expanded(
          child: StudioBody(
            children: [
              _Banner(
                onPreview: canContent
                    ? () => openDraftPreview(context, ref)
                    : null,
              ),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, box) {
                  // Tiles share the row evenly (no lonely tile on a second line).
                  final n = [
                    canContent,
                    canContent,
                    canEnquiries,
                    canGallery,
                    canPackages,
                  ].where((v) => v).length;
                  final cols = ((box.maxWidth + 12) / (box.maxWidth < 600 ? 160 : 212)).floor().clamp(
                    1,
                    n == 0 ? 1 : n,
                  );
                  final tileW = (box.maxWidth - 12 * (cols - 1)) / cols;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      if (canContent)
                        StudioStatTile(
                          width: tileW,
                          icon: Icons.web_outlined,
                          label: 'Sections managed here',
                          value: '$live / ${secList.length}',
                          note: secList.isEmpty
                              ? null
                              : '${secList.length - live} still use the website text',
                          accent: crm.success,
                        ),
                      if (canContent)
                        StudioStatTile(
                          width: tileW,
                          icon: Icons.edit_note,
                          label: 'Waiting to publish',
                          value: '${pending.length}',
                          note: pending.isEmpty
                              ? 'All published'
                              : 'Open and press Publish',
                          accent: pending.isEmpty ? crm.success : crm.warning,
                        ),
                      if (canEnquiries)
                        StudioStatTile(
                          width: tileW,
                          icon: Icons.inbox_outlined,
                          label: 'New enquiries',
                          value: '$newCount',
                          note: '${enqPage?.total ?? 0} in total',
                          onTap: () => context.go('/website/enquiries'),
                        ),
                      if (canGallery)
                        StudioStatTile(
                          width: tileW,
                          icon: Icons.photo_library_outlined,
                          label: 'Gallery photos shown',
                          value: '$shownPhotos',
                          note: photos.length > shownPhotos
                              ? '${photos.length - shownPhotos} hidden'
                              : 'Portfolio page',
                          onTap: () => context.go('/website/gallery'),
                        ),
                      if (canPackages)
                        StudioStatTile(
                          width: tileW,
                          icon: Icons.sell_outlined,
                          label: 'Packages on the website',
                          value: '$shownPackages',
                          note: pkgData == null
                              ? null
                              : 'of ${pkgData.packages.length} in the CRM',
                          onTap: () => context.go('/website/packages'),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),
              const VisitorsCard(),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, c) {
                  final two = c.maxWidth >= 860;
                  final attentionCard = StudioCard(
                    title: 'Needs attention',
                    subtitle: attention.isEmpty
                        ? null
                        : 'Tap a line to go there',
                    child: attention.isEmpty
                        ? Row(
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                color: crm.success,
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Nothing waiting. The website is up to date.',
                                ),
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              for (final a in attention)
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                  leading: Icon(a.icon, color: a.color),
                                  title: Text(
                                    a.text,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  trailing: TextButton(
                                    onPressed: () => context.go(a.path),
                                    child: Text(a.action),
                                  ),
                                  onTap: () => context.go(a.path),
                                ),
                            ],
                          ),
                  );
                  final enquiriesCard = canEnquiries
                      ? StudioCard(
                          title: 'Latest enquiries',
                          trailing: TextButton(
                            onPressed: () => context.go('/website/enquiries'),
                            child: const Text('View all'),
                          ),
                          child: _LatestEnquiries(
                            page: enqPage,
                            loading: enquiries?.isLoading ?? false,
                          ),
                        )
                      : null;
                  if (!two || enquiriesCard == null) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        attentionCard,
                        if (enquiriesCard != null) ...[
                          const SizedBox(height: 16),
                          enquiriesCard,
                        ],
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 5, child: attentionCard),
                      const SizedBox(width: 16),
                      Expanded(flex: 4, child: enquiriesCard),
                    ],
                  );
                },
              ),
              if (canContent && secList.isNotEmpty) ...[
                const SizedBox(height: 18),
                StudioCard(
                  title: 'Pages',
                  subtitle: 'Every part of the website you can change',
                  child: _PagesGrid(sections: secList),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  final VoidCallback? onPreview;
  const _Banner({this.onPreview});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final host = Uri.parse(websiteBaseUrl).host;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [crm.primary, crm.sidebar],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 16,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'YOUR WEBSITE',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w700,
                  color: crm.accent,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                host.isEmpty ? websiteBaseUrl : host,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Changes go live when you press Publish. Gallery and packages update straight away.',
                style: TextStyle(fontSize: 13, color: Colors.white70),
              ),
            ],
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: crm.accent,
                  foregroundColor: crm.sidebar,
                ),
                onPressed: () => openWebsite(context),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Open website'),
              ),
              if (onPreview != null)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                  ),
                  onPressed: onPreview,
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: const Text('Preview drafts'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LatestEnquiries extends StatelessWidget {
  final WebsiteEnquiryPage? page;
  final bool loading;
  const _LatestEnquiries({required this.page, required this.loading});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    if (page == null) {
      return loading
          ? const LinearProgressIndicator()
          : Text('Could not load.', style: TextStyle(color: crm.textSecondary));
    }
    if (page!.items.isEmpty) {
      return Text(
        'No enquiries yet. Website booking requests and messages appear here.',
        style: TextStyle(color: crm.textSecondary, fontSize: 13),
      );
    }
    final fmt = DateFormat('d MMM, h:mm a');
    return Column(
      children: [
        for (final e in page!.items.take(5))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: crm.primary.withValues(alpha: 0.08),
                  child: Icon(
                    e.type == 'booking'
                        ? Icons.event_available_outlined
                        : Icons.mail_outline,
                    size: 16,
                    color: crm.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        [
                          e.type == 'booking' ? 'Booking request' : 'Message',
                          if (e.eventDate != null) 'Wedding ${e.eventDate}',
                          if (e.createdAt != null) fmt.format(e.createdAt!),
                        ].join(' · '),
                        style: TextStyle(
                          fontSize: 12,
                          color: crm.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (e.status == 'new')
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: crm.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'New',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _PagesGrid extends StatelessWidget {
  final List<SectionSummary> sections;
  const _PagesGrid({required this.sections});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    const groups = websitePageNames;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final g in groups.entries)
          if (sections.any((s) => s.page == g.key))
            Container(
              width: 260,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: crm.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    g.value,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: crm.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  for (final s in sections.where((s) => s.page == g.key))
                    InkWell(
                      onTap: () => context.go('/website/section/${s.key}'),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            StatusDot(status: s.status),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                s.label,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              size: 16,
                              color: crm.textSecondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
      ],
    );
  }
}
