import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/models/booking.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/presentation/common_widgets/reference_images.dart';

Widget _wrap(Widget child) => ProviderScope(
      child: MaterialApp(
        theme: ThemeData(extensions: [AppTheme.crmThemeExtension]),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );

void main() {
  group('Booking.referenceImages', () {
    test('round-trips through json and drops blanks', () {
      final b = Booking.fromJson({
        'customerName': 'A',
        'referenceImages': ['https://x/1.jpg', '', '  ', 'https://x/2.jpg'],
      });
      expect(b.referenceImages, ['https://x/1.jpg', 'https://x/2.jpg']);
      expect(b.toJson()['referenceImages'], b.referenceImages);
    });

    test('defaults to empty for bookings created before the feature', () {
      expect(Booking.fromJson({'customerName': 'A'}).referenceImages, isEmpty);
    });

    test('copyWith replaces the list', () {
      final b = Booking.fromJson({'customerName': 'A'});
      expect(b.copyWith(referenceImages: ['u']).referenceImages, ['u']);
    });
  });

  testWidgets('artist view is read-only — no add or remove controls',
      (tester) async {
    await tester.pumpWidget(_wrap(const ReferenceImagesPanel(
      images: ['https://example.com/a.jpg'],
    )));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Reference Looks (1)'), findsOneWidget);
    // Editing affordances must not appear without onChanged.
    expect(find.text('Add images'), findsNothing);
    expect(find.byIcon(Icons.close), findsNothing);
  });

  testWidgets('CRM view exposes add, and remove drops the image',
      (tester) async {
    List<String> images = ['https://example.com/a.jpg', 'https://example.com/b.jpg'];
    await tester.pumpWidget(_wrap(StatefulBuilder(
      builder: (context, setState) => ReferenceImagesPanel(
        images: images,
        onChanged: (next) => setState(() => images = next),
      ),
    )));
    await tester.pumpAndSettle();

    expect(find.text('Add images'), findsOneWidget);
    expect(find.text('Reference Looks (2)'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pumpAndSettle();

    expect(images, ['https://example.com/b.jpg']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty state renders its hint', (tester) async {
    await tester.pumpWidget(_wrap(const ReferenceImagesPanel(
      images: [],
      emptyHint: 'Nothing uploaded yet.',
    )));
    await tester.pumpAndSettle();
    expect(find.text('Nothing uploaded yet.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
