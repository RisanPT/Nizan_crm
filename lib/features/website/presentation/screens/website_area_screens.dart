import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/auth/access_control.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/website/presentation/studio/studio_shell.dart';
import 'package:nizan_crm/features/website/presentation/studio/studio_widgets.dart';
import 'package:nizan_crm/features/website/presentation/tabs/enquiries_tab.dart';
import 'package:nizan_crm/features/website/presentation/tabs/gallery_tab.dart';
import 'package:nizan_crm/features/website/presentation/tabs/packages_tab.dart';

/// One studio page: header + the area's content, gated by its sub-permission.
class _AreaScreen extends ConsumerWidget {
  final String location;
  final String area;
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget body;

  const _AreaScreen({
    required this.location,
    required this.area,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.body,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final allowed = Access.of(
      ref.watch(authSessionProvider),
    ).canSeeWebsiteArea(area);
    return StudioShell(
      current: location,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StudioPageHeader(icon: icon, title: title, subtitle: subtitle),
          Expanded(
            child: allowed
                ? body
                : Center(
                    child: Text(
                      'You do not have access to this part of Team N Website.',
                      style: TextStyle(color: crm.textSecondary),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class WebsiteGalleryScreen extends StatelessWidget {
  const WebsiteGalleryScreen({super.key});

  @override
  Widget build(BuildContext context) => const _AreaScreen(
    location: 'gallery',
    area: 'gallery',
    icon: Icons.photo_library_outlined,
    title: 'Portfolio gallery',
    subtitle:
        'Photos on the Portfolio page. Starred photos also fill "Recent brides" on the home page. Changes go live at once.',
    body: GalleryTab(),
  );
}

class WebsitePackagesScreen extends StatelessWidget {
  const WebsitePackagesScreen({super.key});

  @override
  Widget build(BuildContext context) => const _AreaScreen(
    location: 'packages',
    area: 'packages',
    icon: Icons.sell_outlined,
    title: 'Packages & add-ons',
    subtitle:
        'Choose what the website offers and how it is described. Prices come from Services → Packages.',
    body: PackagesTab(),
  );
}

class WebsiteEnquiriesScreen extends StatelessWidget {
  const WebsiteEnquiriesScreen({super.key});

  @override
  Widget build(BuildContext context) => const _AreaScreen(
    location: 'enquiries',
    area: 'enquiries',
    icon: Icons.inbox_outlined,
    title: 'Enquiries',
    subtitle:
        'Booking requests and messages from the website. Each one is already a lead in Sales.',
    body: EnquiriesTab(),
  );
}
