import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/website/data/website_models.dart';
import 'package:nizan_crm/features/website/presentation/tabs/enquiries_tab.dart';
import 'package:nizan_crm/features/website/services/website_service.dart';

class _FakeService extends WebsiteService {
  _FakeService() : super(Dio());
  final updates = <String>[];

  @override
  Future<void> updateEnquiry(String id, {String? status, String? note}) async =>
      updates.add('$id:${status ?? ''}:${note ?? ''}');
}

Map<String, dynamic> _json({String leadAction = 'created', String status = 'new'}) => {
      'id': 'e1',
      'type': 'booking',
      'name': 'Anjali Nair',
      'phone': '+91 98765 43210',
      'email': 'anjali@example.com',
      'venue': 'Kozhikode',
      'message': 'Need trial too',
      'eventDate': '2027-01-20',
      'slot': 'evening',
      'packageName': 'Platinum',
      'addonNames': ['Trial'],
      'district': 'Kozhikode',
      'region': 'Malabar',
      'quotedTotal': 33000,
      'utm': {'source': 'instagram', 'medium': '', 'campaign': 'jan'},
      'lead': {'id': 'L1', 'name': 'Anjali Nair', 'status': 'New'},
      'leadAction': leadAction,
      'status': status,
      'note': '',
      'handledBy': null,
      'createdAt': '2026-11-17T06:30:00.000Z',
    };

void main() {
  test('enquiry json → model (empty ad fields dropped)', () {
    final e = WebsiteEnquiry.fromJson(_json());
    expect(e.leadId, 'L1');
    expect(e.utm, {'source': 'instagram', 'campaign': 'jan'});
    expect(e.addonNames, ['Trial']);
  });

  testWidgets('shows the request, its lead link, and changes status', (tester) async {
    tester.view.physicalSize = const Size(1100, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final fake = _FakeService();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        websiteServiceProvider.overrideWithValue(fake),
        websiteEnquiriesProvider.overrideWith((ref, key) async => WebsiteEnquiryPage(
              [WebsiteEnquiry.fromJson(_json(leadAction: key.status == 'new' ? 'created' : 'existing'))],
              1,
              1,
              1,
              const {'new': 1},
            )),
      ],
      child: MaterialApp(theme: AppTheme.lightTheme, home: const Scaffold(body: EnquiriesTab())),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Anjali Nair'), findsOneWidget);
    expect(find.textContaining('Wedding 2027-01-20 · Evening · Platinum · + Trial · Kozhikode, Malabar · Total shown ₹33,000'), findsOneWidget);
    expect(find.text('New lead created in Sales'), findsOneWidget);
    expect(find.text('From ad: source=instagram, campaign=jan'), findsOneWidget);
    expect(find.text('New (1)'), findsOneWidget);

    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Contacted').last);
    await tester.pumpAndSettle();
    expect(fake.updates, ['e1:contacted:']);

    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    expect(find.text('Added to existing lead "Anjali Nair"'), findsOneWidget);
  });
}
