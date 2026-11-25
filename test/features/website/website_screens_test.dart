import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/models/auth_session.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/website/data/website_models.dart';
import 'package:nizan_crm/features/website/presentation/screens/section_editor_screen.dart';
import 'package:nizan_crm/features/website/presentation/screens/website_home_screen.dart';
import 'package:nizan_crm/features/website/services/website_service.dart';

import 'website_models_test.dart' show loadSchemaJson;

/// Records calls instead of talking to the server.
class FakeWebsiteService extends WebsiteService {
  FakeWebsiteService() : super(Dio());
  final calls = <String>[];
  Map<String, dynamic>? lastDraft;
  List<String> publishErrors = const [];

  @override
  Future<void> saveDraft(String key, Map<String, dynamic> data) async {
    calls.add('save:$key');
    lastDraft = data;
  }

  @override
  Future<void> publish(String key) async {
    calls.add('publish:$key');
    if (publishErrors.isNotEmpty) throw WebsiteValidationException(publishErrors.first, publishErrors);
  }
}

SectionDetail _detail({String status = 'empty', Map<String, dynamic>? draft}) => SectionDetail(
      key: 'faq',
      label: 'FAQ',
      page: 'home',
      status: status,
      draft: draft ?? {},
    );

Widget _app(Widget child, List overrides) => ProviderScope(
      overrides: [...overrides],
      child: MaterialApp(theme: AppTheme.lightTheme, home: Scaffold(body: child)),
    );

void main() {
  final schema = WebsiteSchema.fromJson(loadSchemaJson());

  testWidgets('section editor builds fields from the schema, saves and publishes what is on screen',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final fake = FakeWebsiteService();
    await tester.pumpWidget(_app(const SectionEditorScreen(sectionKey: 'faq'), [
      websiteServiceProvider.overrideWithValue(fake),
      websiteSchemaProvider.overrideWith((ref) async => schema),
      websiteSectionProvider.overrideWith((ref, key) async => _detail()),
      websiteSectionsProvider.overrideWith((ref) async => const []),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('Website text'), findsWidgets); // nothing saved yet: the website's own text
    expect(find.text('Questions  (0/20)'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Heading'), 'Questions brides ask');
    await tester.tap(find.widgetWithText(OutlinedButton, 'Add'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Question *'), 'Is a trial included?');
    await tester.enterText(find.widgetWithText(TextFormField, 'Answer *'), 'Yes, with Platinum.');
    await tester.pump();
    expect(find.text('Unsaved edits'), findsOneWidget);

    await tester.tap(find.text('Publish'));
    await tester.pumpAndSettle();
    expect(find.text('Publish to the website?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Publish').last);
    await tester.pumpAndSettle();

    expect(fake.calls, ['save:faq', 'publish:faq']);
    expect(fake.lastDraft, {
      'title': 'Questions brides ask',
      'items': [
        {'question': 'Is a trial included?', 'answer': 'Yes, with Platinum.'}
      ],
    });
  });

  testWidgets('not set up yet: starts from the website text; change only the title and publish',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final fake = FakeWebsiteService();
    const websiteText = {
      'eyebrow': 'FAQs',
      'title': 'Frequently asked questions',
      'items': [
        {'question': 'How do I book a slot?', 'answer': 'Pick a date.'}
      ],
    };
    await tester.pumpWidget(_app(const SectionEditorScreen(sectionKey: 'faq'), [
      websiteServiceProvider.overrideWithValue(fake),
      websiteSchemaProvider.overrideWith((ref) async => schema),
      websiteSectionProvider.overrideWith((ref, key) async => const SectionDetail(
          key: 'faq', label: 'FAQ', page: 'home', status: 'empty', draft: {}, defaults: websiteText)),
      websiteSectionsProvider.overrideWith((ref) async => const []),
    ]));
    await tester.pumpAndSettle();

    // The form shows what the website shows now, with nothing to save yet.
    expect(find.textContaining("Showing the website's current text"), findsOneWidget);
    expect(find.text('Frequently asked questions'), findsOneWidget);
    expect(find.text('How do I book a slot?'), findsOneWidget);
    expect(find.text('Unsaved edits'), findsNothing);

    await tester.enterText(find.widgetWithText(TextFormField, 'Frequently asked questions'), 'Questions brides ask');
    await tester.pump();
    await tester.tap(find.text('Publish'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Publish').last);
    await tester.pumpAndSettle();

    expect(fake.calls, ['save:faq', 'publish:faq']);
    expect(fake.lastDraft, {
      'eyebrow': 'FAQs',
      'title': 'Questions brides ask', // the one change
      'items': [
        {'question': 'How do I book a slot?', 'answer': 'Pick a date.'}
      ],
    });
  });

  testWidgets('partly saved section: empty fields show the website text, saved ones win', (tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(const SectionEditorScreen(sectionKey: 'faq'), [
      websiteServiceProvider.overrideWithValue(FakeWebsiteService()),
      websiteSchemaProvider.overrideWith((ref) async => schema),
      websiteSectionProvider.overrideWith((ref, key) async => const SectionDetail(
            key: 'faq',
            label: 'FAQ',
            page: 'home',
            status: 'published',
            draft: {'title': 'Saved title'},
            published: {'title': 'Saved title'},
            defaults: {'eyebrow': 'FAQs', 'title': 'Website title'},
          )),
      websiteSectionsProvider.overrideWith((ref) async => const []),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('Saved title'), findsOneWidget);
    expect(find.text('Website title'), findsNothing);
    expect(find.text('FAQs'), findsOneWidget); // empty in the CRM → the website's own text is shown
  });

  testWidgets('publish problems from the server are listed', (tester) async {
    tester.view.physicalSize = const Size(1200, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final fake = FakeWebsiteService()..publishErrors = ['title is required'];
    await tester.pumpWidget(_app(const SectionEditorScreen(sectionKey: 'faq'), [
      websiteServiceProvider.overrideWithValue(fake),
      websiteSchemaProvider.overrideWith((ref) async => schema),
      websiteSectionProvider.overrideWith((ref, key) async => _detail(status: 'draft', draft: {'eyebrow': 'FAQ'})),
      websiteSectionsProvider.overrideWith((ref) async => const []),
    ]));
    await tester.pumpAndSettle();
    expect(find.text('Draft — not live'), findsWidgets);

    await tester.tap(find.text('Publish'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Publish').last);
    await tester.pumpAndSettle();

    expect(fake.calls, ['publish:faq']); // nothing unsaved, so no extra save
    expect(find.text('Please fix these first:'), findsOneWidget);
    expect(find.text('• title is required'), findsOneWidget);
  });

  testWidgets('studio navigation and overview follow the website sub-permissions', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(const WebsiteHomeScreen(), [
      authSessionProvider.overrideWithValue(const AuthSession(
          token: 't', userId: 'u', name: 'U', email: 'u@x', role: 'custom', permissions: ['website.gallery'])),
      websiteSchemaProvider.overrideWith((ref) async => schema),
      websiteGalleryProvider.overrideWith((ref) async => const []),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('Portfolio gallery'), findsOneWidget); // nav
    expect(find.text('Packages & add-ons'), findsNothing);
    expect(find.text('Enquiries'), findsNothing);
    expect(find.text('HOME PAGE'), findsNothing); // no page sections without website.content
    expect(find.text('Gallery photos shown'), findsOneWidget); // overview tile
    expect(find.textContaining('Mark 4 gallery photos'), findsOneWidget); // needs attention
    expect(find.text('Preview drafts'), findsNothing); // previews are for content editors
  });

  testWidgets('overview for a full editor: page list with status dots, attention, latest enquiries',
      (tester) async {
    tester.view.physicalSize = const Size(1500, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(const WebsiteHomeScreen(), [
      authSessionProvider.overrideWithValue(const AuthSession(
          token: 't', userId: 'u', name: 'U', email: 'u@x', role: 'marketing_admin', permissions: ['website'])),
      websiteSectionsProvider.overrideWith((ref) async => const [
            SectionSummary(key: 'hero', label: 'Hero (top of home page)', page: 'home', status: 'changed'),
            SectionSummary(key: 'faq', label: 'FAQ', page: 'home', status: 'published'),
            SectionSummary(key: 'contact', label: 'Contact & Footer', page: 'global', status: 'empty'),
          ]),
      websiteGalleryProvider.overrideWith((ref) async => const []),
      websitePackagesProvider.overrideWith((ref) async => const WebsitePackagesData([], [])),
      websiteEnquiriesProvider.overrideWith((ref, key) async => WebsiteEnquiryPage([
            WebsiteEnquiry.fromJson({'id': 'e1', 'type': 'booking', 'name': 'Anjali Nair', 'phone': '1', 'status': 'new', 'eventDate': '2027-01-20'}),
          ], 1, 1, 1, const {'new': 1})),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('HOME PAGE'), findsOneWidget); // nav group
    expect(find.text('1 new'), findsOneWidget); // enquiries badge
    expect(find.text('2 / 3'), findsOneWidget); // sections managed here (live + changed)
    expect(find.textContaining('Hero (top of home page): edits not published yet'), findsOneWidget);
    expect(find.textContaining('No CRM package is switched on'), findsOneWidget);
    expect(find.text('Anjali Nair'), findsOneWidget);
    expect(find.text('Open website'), findsOneWidget);
    expect(find.text('Preview drafts'), findsOneWidget);
  });
}
