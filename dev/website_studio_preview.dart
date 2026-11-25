// DEV ONLY — a stand-alone preview of the Website Studio screens with sample
// data: no backend, no login, nothing is saved. Run:
//   flutter run -d web-server --web-port 5190 -t dev/website_studio_preview.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nizan_crm/core/models/auth_session.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/website/data/website_models.dart';
import 'package:nizan_crm/features/website/presentation/screens/section_editor_screen.dart';
import 'package:nizan_crm/features/website/presentation/screens/website_area_screens.dart';
import 'package:nizan_crm/features/website/presentation/screens/website_home_screen.dart';
import 'package:nizan_crm/features/website/services/website_service.dart';

import 'website_studio_preview_data.dart';

Map<String, dynamic> _m(String s) => (jsonDecode(s) as Map).cast<String, dynamic>();

class _SampleWebsiteService extends WebsiteService {
  _SampleWebsiteService() : super(Dio());

  final _defaults = _m(previewDefaultsJson);
  final _statuses = {
    'hero': 'changed',
    'availabilityStrip': 'empty',
    'intro': 'empty',
    'recentBrides': 'empty',
    'packagesPreview': 'empty',
    'about': 'empty',
    'howItWorks': 'empty',
    'faq': 'published',
    'packagesPage': 'empty',
    'policies': 'empty',
    'contact': 'published',
    'seo': 'empty',
  };

  @override
  Future<WebsiteSchema> getSchema() async => WebsiteSchema.fromJson(_m(previewSchemaJson));

  @override
  Future<List<SectionSummary>> listSections() async {
    final schema = await getSchema();
    return [
      for (final s in schema.sections.values)
        SectionSummary(
          key: s.key,
          label: s.label,
          page: s.page,
          status: _statuses[s.key] ?? 'empty',
          publishedAt: _statuses[s.key] == 'empty' ? null : DateTime(2026, 11, 17, 11, 20),
        ),
    ];
  }

  @override
  Future<SectionDetail> getSection(String key) async {
    final schema = await getSchema();
    final s = schema.sections[key]!;
    final defaults = (_defaults[key] as Map?)?.cast<String, dynamic>() ?? {};
    final published = key == 'hero'
        ? {'title': 'Bridal beauty, defined.'}
        : key == 'contact'
            ? {'address': 'Tower 2, 3rd floor, Hilite Business Park, Calicut', 'phone': '+91 96454 24281'}
            : null;
    final draft = key == 'hero' ? {'title': 'Your day, your look.'} : (published ?? <String, dynamic>{});
    return SectionDetail(
      key: key,
      label: s.label,
      page: s.page,
      status: _statuses[key] ?? 'empty',
      draft: draft,
      published: published,
      defaults: defaults,
      publishedAt: published == null ? null : DateTime(2026, 11, 17, 11, 20),
      publishedBy: published == null ? null : 'Marketing Admin',
      draftUpdatedAt: key == 'hero' ? DateTime(2026, 11, 17, 12, 5) : null,
      draftUpdatedBy: key == 'hero' ? 'Marketing Admin' : null,
    );
  }

  @override
  Future<void> saveDraft(String key, Map<String, dynamic> data) async {}
  @override
  Future<void> publish(String key) async {}
  @override
  Future<void> revert(String key) async {}

  @override
  Future<List<GalleryItem>> listGallery() async => [
        for (var i = 0; i < 6; i++)
          GalleryItem(
            id: 'g$i',
            image: WebsiteImage(
              url: 'http://localhost:5173/brides/${['bride-lilac-lehenga', 'bride-magenta-saree-fence', 'bride-red-saree-garden', 'bride-white-gown-garden', 'bride-plum-gown-window', 'bride-peach-lehenga-portrait'][i]}.jpg',
              publicId: 'p$i',
              alt: 'Bride $i',
            ),
            category: ['makeup', 'hair', 'styling', 'events'][i % 4],
            title: ['Royal Bride', 'Bridal Updo', 'Saree Styling', 'Reception', 'Christian Bride', 'Fusion Look'][i],
            description: '',
            active: i != 5,
            featuredOnHome: i < 2,
            sortOrder: i,
          ),
      ];

  @override
  Future<WebsitePackagesData> listPackages() async => WebsitePackagesData([
        WebsitePackage.fromJson({'id': 'p1', 'name': 'Airbrush', 'price': 35000, 'website': {'show': true, 'tagline': 'Waterproof & camera-ready'}}),
        WebsitePackage.fromJson({'id': 'p2', 'name': 'Platinum', 'price': 50000, 'website': {'show': true, 'highlighted': true, 'tagline': 'By Feeniya Nizan'}}),
        WebsitePackage.fromJson({'id': 'p3', 'name': 'Engagement Glam', 'price': 18000, 'website': {'show': false}}),
      ], [
        WebsiteAddon.fromJson({'id': 'a1', 'name': 'Bridal Trial', 'price': 8000, 'status': 'active', 'website': {'show': true}}),
        WebsiteAddon.fromJson({'id': 'a2', 'name': 'Saree Pre-pleating', 'price': 2500, 'status': 'inactive', 'website': {'show': false}}),
      ]);

  @override
  Future<WebsiteEnquiryPage> listEnquiries({String status = '', int page = 1}) async {
    final all = [
      WebsiteEnquiry.fromJson({'id': 'e1', 'type': 'booking', 'name': 'Anjali Nair', 'phone': '+91 98765 43210', 'email': 'anjali@example.com', 'venue': 'Kozhikode', 'eventDate': '2027-01-20', 'slot': 'evening', 'packageName': 'Platinum', 'addonNames': ['Bridal Trial'], 'utm': {'source': 'instagram', 'campaign': 'jan'}, 'leadAction': 'created', 'status': 'new', 'createdAt': '2026-11-17T05:40:00Z'}),
      WebsiteEnquiry.fromJson({'id': 'e2', 'type': 'contact', 'name': 'Fathima Rahman', 'phone': '+91 90000 11111', 'message': 'Do you travel to Kannur?', 'lead': {'id': 'L2', 'name': 'Fathima Rahman', 'status': 'Contacted'}, 'leadAction': 'existing', 'status': 'new', 'createdAt': '2026-11-17T03:10:00Z'}),
      WebsiteEnquiry.fromJson({'id': 'e3', 'type': 'booking', 'name': 'Meera Thomas', 'phone': '+91 91111 22222', 'eventDate': '2027-02-02', 'slot': 'day', 'packageName': 'Airbrush', 'leadAction': 'created', 'status': 'contacted', 'createdAt': '2026-11-16T10:00:00Z'}),
    ];
    final items = status.isEmpty ? all : all.where((e) => e.status == status).toList();
    return WebsiteEnquiryPage(items, 1, 1, items.length, const {'new': 2, 'contacted': 1});
  }

  @override
  Future<String> getPreviewToken() async => 'preview';
  @override
  Future<WebsiteImage> uploadImage({
    required String section,
    required String field,
    required Uint8List bytes,
    required String filename,
    required String mime,
  }) async =>
      throw UnimplementedError('Uploads are off in the preview');
}

final _router = GoRouter(initialLocation: '/website', routes: [
  GoRoute(path: '/website', builder: (c, s) => const _Frame(WebsiteHomeScreen())),
  GoRoute(path: '/website/gallery', builder: (c, s) => const _Frame(WebsiteGalleryScreen())),
  GoRoute(path: '/website/packages', builder: (c, s) => const _Frame(WebsitePackagesScreen())),
  GoRoute(path: '/website/enquiries', builder: (c, s) => const _Frame(WebsiteEnquiriesScreen())),
  GoRoute(
    path: '/website/section/:key',
    builder: (c, s) => _Frame(SectionEditorScreen(sectionKey: s.pathParameters['key']!)),
  ),
]);

class _Frame extends StatelessWidget {
  final Widget child;
  const _Frame(this.child);
  @override
  Widget build(BuildContext context) => Scaffold(body: child);
}

void main() {
  runApp(ProviderScope(
    overrides: [
      websiteServiceProvider.overrideWithValue(_SampleWebsiteService()),
      authSessionProvider.overrideWithValue(const AuthSession(
          token: 'preview', userId: 'u', name: 'Preview', email: 'preview@example.com', role: 'admin')),
    ],
    child: MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: _router,
    ),
  ));
}
