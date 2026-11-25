import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/marketing/data/asset_search.dart';
import 'package:nizan_crm/features/marketing/data/socials_models.dart';
import 'package:nizan_crm/features/marketing/data/team_models.dart';
import 'package:nizan_crm/features/marketing/presentation/media/asset_viewer.dart' show showAssetViewer;
import 'package:nizan_crm/features/marketing/presentation/media/media_stream.dart';
import 'package:nizan_crm/features/marketing/presentation/portfolio/artist_quality_tab.dart';
import 'package:nizan_crm/features/marketing/presentation/portfolio/portfolio_gallery_tab.dart';
import 'package:nizan_crm/features/marketing/presentation/portfolio/work_review_widgets.dart';
import 'package:nizan_crm/features/marketing/presentation/socials/asset_editor.dart';
import 'package:nizan_crm/features/marketing/services/portfolio_service.dart';
import 'package:nizan_crm/features/marketing/services/socials_service.dart';
import 'package:nizan_crm/features/marketing/services/team_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The gallery's link to the WORK behind each photo / video (the booking: client, day, artists) and the client's review of it — sent
// the morning after the work and matched by the booking. Each card says it; the viewer shows it in full; the gallery filters by the
// artist on the work and by the review; Artist Quality shows each artist's ratings (every artist on a work gets its rating), the
// works needing a look first, with their photos and videos.

Finder _k(String key) => find.byKey(Key(key));

const _nihala = {'key': 'e1', 'id': 'e1', 'name': 'Nihala', 'role': 'Lead Artist'};
const _sana = {'key': 'e2', 'id': 'e2', 'name': 'Sana', 'role': 'Assistant'};

Map<String, dynamic> _work(String b, String number, String client, String day, List<Map<String, dynamic>> artists, Map<String, dynamic>? review) =>
    {'bookingId': b, 'bookingNumber': number, 'client': client, 'eventDay': day, 'workDay': day, 'services': ['Bridal Makeup'], 'place': 'Kozhikode', 'artists': artists, 'review': review};

final _complaint = {
  'id': 'r1',
  'status': 'submitted',
  'submittedAt': '2026-11-02T05:30:00.000Z',
  'score': 2,
  'band': 'low',
  'overall': 2,
  'nps': 4,
  'areas': [
    {'key': 'makeup', 'label': 'Makeup', 'value': 4},
    {'key': 'hair', 'label': 'Hair', 'value': 2},
  ],
  'answers': [
    {'label': 'The look matched what she wanted', 'value': 'Mostly as expected'},
  ],
  'likedMost': 'The base was flawless',
  'couldBeBetter': 'The hair came loose before the reception',
  'complaint': true,
  'needsAttention': true,
};
final _great = {'id': 'r2', 'status': 'submitted', 'score': 5, 'band': 'great', 'overall': 5, 'nps': 10, 'testimonial': 'Best day ever', 'marketingConsent': true, 'areas': const [], 'answers': const []};

final _w1 = _work('b1', 'BK-1001', 'Amina K', '2026-11-01', [_nihala, _sana], _complaint);
final _w2 = _work('b2', 'BK-1002', 'Fathima R', '2026-11-05', [_nihala], _great);
final _w3 = _work('b3', 'BK-1003', 'Hiba S', '2026-11-08', [
  {'key': 'e3', 'id': 'e3', 'name': 'Riya', 'role': 'Lead Artist'},
], {'id': 'r3', 'status': 'pending', 'sentAt': '2026-11-09T03:30:00.000Z'});
final _w4 = _work('b4', 'BK-1004', 'Nisha P', '2026-11-09', [_sana], null);

Map<String, dynamic> _asset(String id, String title, {Map<String, dynamic>? work, String? bookingId}) => {
      'id': id,
      'title': title,
      'brand': 'main',
      'kind': 'still',
      'media': 'image',
      'stage': 'raw',
      'url': 'https://d.test/$id.jpg',
      'portfolio': 'Main (Company)',
      'page': 'Airbrush',
      'tags': const <String>[],
      'createdAt': '2026-11-10T05:00:00.000Z',
      'bookingId': bookingId,
      'work': work,
    };

final _items = [
  _asset('a1', '2026-11-01 · BK-1001 · Amina K · Bridal Makeup', work: _w1, bookingId: 'b1'),
  _asset('a2', 'Fathima — reel', work: _w2),
  _asset('a3', 'Hiba — portrait', work: _w3, bookingId: 'b3'),
  _asset('a4', 'Nisha — reel', work: _w4, bookingId: 'b4'),
  _asset('a5', 'Logo sheet'),
];

class _Socials extends MarketingSocialsService {
  _Socials() : super(Dio());
  final searches = <AssetSearch>[];
  final saved = <Map<String, dynamic>>[];

  @override
  Future<AssetPage> searchAssets(AssetSearch s, {int pageNo = 1, int limit = kGalleryPageSize}) async {
    searches.add(s);
    return AssetPage.fromJson({
      'items': _items,
      'total': _items.length,
      'pageNo': 1,
      'pages': 1,
      'counts': {'total': 5, 'photos': 5, 'videos': 0},
      'facets': {
        'media': {'image': 5},
        'artists': [
          {'key': 'e1', 'name': 'Nihala', 'count': 2},
          {'key': 'e2', 'name': 'Sana', 'count': 2},
          {'key': 'e3', 'name': 'Riya', 'count': 1},
        ],
        'reviews': {'great': 1, 'good': 0, 'low': 1, 'complaint': 1, 'waiting': 1},
      },
    });
  }

  @override
  Future<Asset> saveAsset(Map<String, dynamic> body, {String? id}) async {
    saved.add(body);
    return Asset.fromJson({'id': id ?? 'new', ...body});
  }
}

class _Portfolio extends MarketingPortfolioService {
  _Portfolio() : super(Dio());
  final asked = <String>[];

  @override
  Future<QualityReport> quality({required String from, required String to}) async {
    asked.add('$from..$to');
    return QualityReport.fromJson({
      'from': from,
      'to': to,
      'totals': {'works': 4, 'reviewed': 3, 'waiting': 1, 'avgScore': 3.3, 'nps': 0, 'complaints': 1, 'low': 1, 'great': 1},
      'artists': [
        {'key': 'e2', 'id': 'e2', 'name': 'Sana', 'works': 1, 'reviewed': 1, 'avgScore': 2, 'complaints': 1, 'low': 1, 'assets': 2, 'weakest': {'key': 'hair', 'label': 'Hair', 'avg': 2, 'count': 1}, 'lastIssueDay': '2026-11-01', 'needsAttention': true, 'areas': [{'key': 'hair', 'label': 'Hair', 'avg': 2, 'count': 1}]},
        {'key': 'e1', 'id': 'e1', 'name': 'Nihala', 'works': 2, 'reviewed': 2, 'avgScore': 3.5, 'nps': 0, 'complaints': 1, 'low': 1, 'great': 1, 'assets': 3, 'needsAttention': true},
        {'key': 'e4', 'id': 'e4', 'name': 'Anagha', 'works': 1, 'reviewed': 1, 'avgScore': 4.9, 'great': 1, 'assets': 1},
        {'key': 'e3', 'id': 'e3', 'name': 'Riya', 'works': 1, 'reviewed': 0, 'waiting': 1},
      ],
    });
  }

  @override
  Future<ArtistQualityDetail> artistQuality(String key, {required String from, required String to}) async {
    asked.add('artist $key');
    return ArtistQualityDetail.fromJson({
      'artist': {'key': key, 'id': key, 'name': key == 'e1' ? 'Nihala' : 'Sana', 'works': 2, 'reviewed': 2, 'avgScore': 3.5, 'complaints': 1, 'low': 1, 'areas': [{'key': 'makeup', 'label': 'Makeup', 'avg': 4.5, 'count': 2}, {'key': 'hair', 'label': 'Hair', 'avg': 2, 'count': 1}]},
      'works': [
        {..._w1, 'items': [_asset('a1', '2026-11-01 · BK-1001 · Amina K · Bridal Makeup', bookingId: 'b1')]},
        {..._w2, 'items': const []},
      ],
    });
  }
}

class _NoTeam extends MarketingTeamService {
  _NoTeam() : super(Dio());
  @override
  Future<LogSetup> logSetup({required String date, String? memberId}) async => throw Exception('no team in this test');
}

Future<({_Socials socials, _Portfolio portfolio})> _pump(WidgetTester t, Widget child, {Size size = const Size(1400, 2600)}) async {
  SharedPreferences.setMockInitialValues({});
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final s = _Socials();
  final p = _Portfolio();
  await t.pumpWidget(ProviderScope(
    overrides: [
      marketingSocialsServiceProvider.overrideWithValue(s),
      marketingPortfolioServiceProvider.overrideWithValue(p),
      marketingTeamServiceProvider.overrideWithValue(_NoTeam()),
      mediaStreamServiceProvider.overrideWithValue(NoMediaStream()),
    ],
    child: MaterialApp(theme: AppTheme.lightTheme, home: Scaffold(body: child)),
  ));
  await t.pumpAndSettle();
  return (socials: s, portfolio: p);
}

Future<void> _tap(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.tap(f);
  await t.pumpAndSettle();
}

String _texts(WidgetTester t, Finder of) => t.widgetList<Text>(find.descendant(of: of, matching: find.byType(Text))).map((x) => x.data ?? x.textSpan?.toPlainText() ?? '').join(' | ');

void main() {
  group('the gallery card says which work it is and what the client thought', () {
    testWidgets('day · booking · client, the artists, and the rating — a complaint in red, a testimonial, waiting, none', (t) async {
      await _pump(t, const PortfolioGalleryTab());
      final a1 = _texts(t, _k('asset_a1'));
      expect(a1, allOf(contains('Amina K'), contains('1 Nov 2026 · #BK-1001')));
      expect(a1, contains('Nihala, Sana'));
      expect(a1, contains('★ 2'));
      expect(a1, contains('Complaint'));
      expect(_texts(t, _k('asset_a2')), allOf(contains('★ 5'), contains('Testimonial')));
      expect(_texts(t, _k('asset_a3')), contains('Review waiting'));
      expect(_texts(t, _k('asset_a4')), contains('No review yet'));
      expect(find.descendant(of: _k('asset_a5'), matching: find.byKey(const Key('work_lines_b1'))), findsNothing, reason: 'no work: nothing extra');
      expect(find.byType(WorkCardLines), findsNWidgets(4));
      expect(t.takeException(), isNull);
    });

    testWidgets('the list view says it on one line', (t) async {
      await _pump(t, const PortfolioGalleryTab());
      await _tap(t, _k('asset_layout_list'));
      expect(_texts(t, _k('asset_row_a1')), allOf(contains('1 Nov 2026 · #BK-1001 · Amina K · Nihala, Sana'), contains('★ 2')));
    });

    testWidgets('on a phone the card keeps its lines without overflow', (t) async {
      await _pump(t, const PortfolioGalleryTab(), size: const Size(380, 2400));
      expect(_texts(t, _k('asset_a1')), contains('Nihala, Sana'));
      expect(t.takeException(), isNull);
    });
  });

  group('the viewer shows the work and the client\'s review in full', () {
    testWidgets('booking, client, day, service, place, every artist, the complaint and her words, the areas', (t) async {
      await _pump(t, const PortfolioGalleryTab());
      await _tap(t, find.descendant(of: _k('asset_a1'), matching: _k('asset_thumb')));
      final panel = _texts(t, _k('work_panel'));
      for (final s in ['#BK-1001', 'Amina K', 'Sun 1 Nov 2026', 'Bridal Makeup', 'Kozhikode', 'Nihala · Lead Artist', 'Sana · Assistant', 'Artists on this work — each gets its rating']) {
        expect(panel, contains(s), reason: s);
      }
      expect(_k('work_review_complaint'), findsOneWidget);
      expect(_texts(t, _k('work_review')), allOf(contains('“The hair came loose before the reception”'), contains('“The base was flawless”'), contains('The look matched what she wanted: Mostly as expected'), contains('Would recommend: 4/10')));
      expect(t.widget<Text>(_k('work_review_score')).data, '2 / 5');
      expect(_texts(t, _k('work_area_hair')), 'Hair 2★');
      expect(t.takeException(), isNull);
    });

    testWidgets('a review still waiting, and a work with none, say so', (t) async {
      await _pump(t, const PortfolioGalleryTab());
      await _tap(t, find.descendant(of: _k('asset_a3'), matching: _k('asset_thumb')));
      expect(t.widget<Text>(_k('work_review_waiting')).data, startsWith('The review form was sent on 9 Nov'));
      await _tap(t, _k('viewer_close'));
      await _tap(t, find.descendant(of: _k('asset_a4'), matching: _k('asset_thumb')));
      expect(t.widget<Text>(_k('work_review_none')).data, contains('the morning after the work'));
      await _tap(t, _k('viewer_close'));
      await _tap(t, find.descendant(of: _k('asset_a5'), matching: _k('asset_thumb')));
      expect(_k('work_panel'), findsNothing);
    });

    testWidgets('an artist\'s footage handed in as a Dropbox folder shows the work under its files', (t) async {
      final folder = Asset.fromJson({..._items[0], 'kind': 'film', 'media': 'video', 'url': 'https://www.dropbox.com/scl/fo/abc123/xyz?rlkey=k1'});
      await _pump(t, Builder(builder: (context) => TextButton(onPressed: () => showAssetViewer(context, folder), child: const Text('open'))));
      await _tap(t, find.text('open'));
      expect(_k('folder_view'), findsOneWidget);
      expect(find.descendant(of: _k('folder_view'), matching: _k('work_panel')), findsOneWidget);
      expect(_texts(t, _k('work_panel')), allOf(contains('Amina K'), contains('Nihala · Lead Artist')));
      expect(t.takeException(), isNull);
    });

    testWidgets('tapping an artist opens their quality: figures, areas, the works with their photos', (t) async {
      final f = await _pump(t, const PortfolioGalleryTab());
      await _tap(t, find.descendant(of: _k('asset_a1'), matching: _k('asset_thumb')));
      await _tap(t, _k('work_artist_e1'));
      expect(f.portfolio.asked.last, 'artist e1');
      expect(_k('artist_quality'), findsOneWidget);
      expect(_texts(t, _k('artist_quality_areas')), allOf(contains('Hair'), contains('2★ (1)')));
      expect(_k('quality_work_b1'), findsOneWidget);
      expect(_k('quality_item_a1'), findsOneWidget);
    });
  });

  group('filters: the artist on the work, the client\'s review', () {
    testWidgets('both shown first with their numbers; a kind no item has is left out', (t) async {
      await _pump(t, const PortfolioGalleryTab());
      expect(find.text('Client review of the work'), findsOneWidget);
      expect(find.text('Artist on the work'), findsOneWidget);
      expect(_texts(t, _k('gl_review_low')), contains('★ below 3.5'));
      expect(_k('gl_review_good'), findsNothing, reason: 'no item is rated 3.5 – 4.4');
      expect(_texts(t, _k('gl_artist_e1')), contains('Nihala'));
      final reviewY = t.getTopLeft(find.text('Client review of the work')).dy;
      expect(reviewY, lessThan(t.getTopLeft(find.text('Media type')).dy), reason: 'before the other filters');
    });

    testWidgets('picking an artist and a kind of review asks the server for them; the chips say the name', (t) async {
      final f = await _pump(t, const PortfolioGalleryTab());
      await _tap(t, _k('gl_artist_e1'));
      await _tap(t, _k('gl_review_complaint'));
      final s = f.socials.searches.last;
      expect(s.facet('artist'), {'e1'});
      expect(s.facet('review'), {'complaint'});
      expect(s.query()['artist'], ['e1']);
      expect(s.query()['review'], ['complaint']);
      expect(_texts(t, _k('gl_active_artist_e1')), 'Nihala');
      expect(_texts(t, _k('gl_active_review_complaint')), 'Complaint');
    });
  });

  group('Artist Quality', () {
    testWidgets('the figures; the artists needing a look first, with their weakest area', (t) async {
      final f = await _pump(t, const ArtistQualityTab());
      expect(f.portfolio.asked.single, '${qualityPeriod(90).from}..${qualityPeriod(90).to}', reason: 'the last 90 days');
      expect(_texts(t, _k('quality_kpi_reviewed')), allOf(contains('3'), contains('1 waiting for the client')));
      expect(_texts(t, _k('quality_kpi_avg')), contains('3.3 ★'));
      expect(_texts(t, _k('quality_kpi_complaints')), contains('1'));
      final order = t.widgetList<InkWell>(find.byWidgetPredicate((w) => w is InkWell && (w.key?.toString().contains('quality_artist_') ?? false))).map((w) => (w.key! as ValueKey<String>).value).toList();
      expect(order, ['quality_artist_e2', 'quality_artist_e1', 'quality_artist_e4', 'quality_artist_e3']);
      expect(_texts(t, _k('quality_weakest_e2')), 'Weakest: Hair 2★');
      expect(_texts(t, _k('quality_artist_e2')), allOf(contains('1 complaint'), contains('★ 2'), contains('Last issue 1 Nov')));
    });

    testWidgets('only those needing a look; another period; sorted by name', (t) async {
      final f = await _pump(t, const ArtistQualityTab());
      await _tap(t, _k('quality_attention_only'));
      expect(_k('quality_artist_e4'), findsNothing);
      expect(_k('quality_artist_e2'), findsOneWidget);
      await _tap(t, _k('quality_period_365'));
      expect(f.portfolio.asked.last, '${qualityPeriod(365).from}..${qualityPeriod(365).to}');
    });

    testWidgets('an artist opens their works, the complaint first; a photo plays with the work beside it', (t) async {
      await _pump(t, const ArtistQualityTab());
      await _tap(t, _k('quality_artist_e1'));
      expect(_k('artist_quality'), findsOneWidget);
      final first = t.getTopLeft(_k('quality_work_b1')).dy;
      final list = find.descendant(of: _k('artist_quality'), matching: find.byType(Scrollable)).first;
      await t.scrollUntilVisible(_k('quality_work_b2'), 300, scrollable: list);
      expect(_texts(t, _k('quality_work_b2')), contains('No photo or video of this work in the gallery yet.'));
      await t.scrollUntilVisible(_k('quality_work_b1'), -300, scrollable: list);
      expect(t.getTopLeft(_k('quality_work_b1')).dy, lessThan(t.getTopLeft(_k('quality_work_b2')).dy), reason: 'the complaint first');
      expect(first, greaterThan(0));
      await _tap(t, _k('quality_item_a1'));
      expect(find.descendant(of: find.byType(Dialog).last, matching: _k('work_panel')), findsOneWidget, reason: 'the item carries its work');
    });

    testWidgets('on a phone it fits', (t) async {
      await _pump(t, const ArtistQualityTab(), size: const Size(380, 1800));
      expect(_k('quality_artist_e2'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  });

  group('the asset editor links a work', () {
    testWidgets('an item\'s booking is shown, can be taken off, and is sent with the save', (t) async {
      final f = await _pump(
        t,
        Consumer(builder: (context, ref, _) => TextButton(onPressed: () => showAssetEditor(context, ref, asset: Asset.fromJson(_items[3]), manager: true), child: const Text('edit'))),
      );
      await _tap(t, find.text('edit'));
      expect(_texts(t, _k('asset_booking')), allOf(contains('#BK-1004 · Nisha P'), contains("the client's review of it show with this item")));
      await _tap(t, find.descendant(of: _k('asset_booking'), matching: find.byIcon(Icons.close_rounded)));
      expect(_texts(t, _k('asset_booking')), contains('No booking'));
      await _tap(t, find.text('Save'));
      expect(f.socials.saved.single['bookingId'], isNull);
      expect(f.socials.saved.single.containsKey('bookingId'), isTrue);
    });

    testWidgets('an item whose work comes from its shoot says so', (t) async {
      await _pump(
        t,
        Consumer(builder: (context, ref, _) => TextButton(onPressed: () => showAssetEditor(context, ref, asset: Asset.fromJson(_items[1]), manager: true), child: const Text('edit'))),
      );
      await _tap(t, find.text('edit'));
      expect(_texts(t, _k('asset_booking')), contains('From the shoot: #BK-1002 · Fathima R'));
    });
  });
}
