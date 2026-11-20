import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/marketing/data/footage_models.dart';
import 'package:nizan_crm/features/marketing/data/portfolio_models.dart';
import 'package:nizan_crm/features/marketing/data/team_models.dart' show TeamRefusal;
import 'package:nizan_crm/features/marketing/presentation/footage/work_footage_card.dart';
import 'package:nizan_crm/features/marketing/presentation/media/dropbox_folder_view.dart';
import 'package:nizan_crm/features/marketing/presentation/media/media_stream.dart';
import 'package:nizan_crm/features/marketing/presentation/portfolio/footage_tab.dart';
import 'package:nizan_crm/features/marketing/presentation/portfolio/shoot_board.dart';
import 'package:nizan_crm/features/marketing/presentation/portfolio/shoot_docs.dart';
import 'package:nizan_crm/features/marketing/presentation/portfolio/shoot_planner_tab.dart';
import 'package:nizan_crm/features/marketing/services/footage_service.dart';
import 'package:nizan_crm/features/marketing/services/portfolio_service.dart';
import 'package:nizan_crm/services/upload_service.dart';

// The Shoot Planner's Moodboard (pictures from the phone, links; named, made the cover, removed — from its own tab), its preview on the
// Brief, Crew & Logistics (call time, map, a checklist ticked off), the work's raw footage on the Content Plan; the artist's footage card
// (the work's folder name, the steps, the Dropbox link — or the Dropbox upload page); Marketing's Footage tab (to an editor, edited).

Finder _k(String key) => find.byKey(Key(key));

Map<String, dynamic> _detail({List<Map<String, dynamic>>? refs, Map<String, dynamic>? logistics, List<Map<String, dynamic>>? footage}) => {
      'id': 's1', 'title': 'Diya reception film', 'brand': 'kerala', 'category': 'Reception', 'shootType': 'Full Shoot', 'status': 'planned', 'shootDate': '2026-11-20', 'startTime': '09:00', 'endTime': '17:00',
      'location': 'Kumarakom', 'coverUrl': '', 'crewCount': 1, 'progress': 20, 'planned': {'reels': 2}, 'plannedTotal': 2, 'delivered': {}, 'deliveredTotal': 0, 'rescheduleCount': 0, 'delayed': false,
      'brief': {'objective': 'The reception look', 'audience': 'Brides', 'notes': ''},
      'crew': [{'memberId': 'm1', 'name': 'Ashique', 'role': 'Videographer'}],
      'references': refs ?? [
        {'url': 'https://res.cloudinary.com/x/image/upload/v1/a.jpg', 'label': 'Look', 'kind': 'image', 'addedByName': 'Shahala'},
        {'url': 'https://www.pinterest.com/pin/9/', 'label': 'Hair idea', 'kind': 'link', 'addedByName': 'Shahala'},
      ],
      'logistics': logistics ?? {'callTime': '06:30', 'mapUrl': 'https://maps.app.goo.gl/x', 'notes': 'Gate 2', 'checklist': [{'text': 'Ring light', 'done': false}, {'text': 'Steamer', 'done': true, 'byName': 'Faies'}]},
      'milestones': [for (final k in ['brief', 'pre_production', 'production', 'post_production', 'distribution']) {'key': k, 'label': k, 'date': '2026-11-20', 'doneAt': null}],
      'documents': [
        {'key': 'd1', 'part': 'moodboard', 'name': 'Lookbook Nov.pdf', 'label': 'Bridal lookbook', 'sizeBytes': 1258291, 'pages': 3, 'addedByName': 'Shahala', 'addedAt': '2026-11-18T05:00:00Z'},
        {'key': 'd2', 'part': 'storyboard', 'name': 'storyboard-v2.pdf', 'sizeBytes': 40960, 'pages': 12, 'addedByName': 'Salmaan'},
      ],
      'storyboard': [
        {'key': 'fk1', 'shotNo': '1', 'description': 'Bride walks in', 'shotType': 'Wide', 'durationSec': 8, 'imageUrl': 'https://res.cloudinary.com/x/image/upload/v1/sketch1.jpg', 'shotAt': '2026-11-20T04:10:00Z', 'shotByName': 'Ashique'},
        {'key': 'fk2', 'shotNo': '2', 'description': 'Close-up of the eyes', 'shotType': 'Close-up', 'durationSec': 4},
      ],
      'currentMilestone': 'brief',
      'booking': {'id': 'b2', 'bookingNumber': 'BK-1002', 'customerName': 'Diya', 'service': 'Reception'},
      'footage': footage ?? [{'id': 'f1', 'day': '2026-11-18', 'folderName': '2026-11-18 · BK-1002 · Diya · Reception', 'state': 'new', 'size': '1.6 GB', 'links': [{'url': 'https://www.dropbox.com/scl/fo/a/b', 'label': '', 'kind': 'folder', 'addedByName': 'Bina'}]}],
    };

class _FakePortfolio extends MarketingPortfolioService {
  _FakePortfolio() : super(Dio());
  Map<String, dynamic> detail = _detail();
  final added = <List<Map<String, dynamic>>>[];
  final renamed = <(String, String)>[];
  final removed = <String>[];
  final logistics = <Map<String, dynamic>>[];
  final saved = <Map<String, dynamic>>[];

  @override
  Future<ShootDetail> shoot(String id) async => ShootDetail.fromJson(detail);
  @override
  Future<int> addMoodboard(String shootId, List<Map<String, dynamic>> items) async {
    added.add(items);
    return items.length;
  }

  @override
  Future<void> renameMoodboardItem(String shootId, String url, String label) async => renamed.add((url, label));
  @override
  Future<void> removeMoodboardItem(String shootId, String url) async => removed.add(url);
  @override
  Future<void> saveLogistics(String shootId, Map<String, dynamic> body) async => logistics.add(body);
  final ticks = <(String, bool)>[];
  @override
  Future<void> tickChecklist(String shootId, String text, bool done) async => ticks.add((text, done));
  final shots = <(String, bool)>[];
  @override
  Future<void> markFrameShot(String shootId, String frameKey, bool shot) async => shots.add((frameKey, shot));
  final uploads = <(String, String, int)>[];
  @override
  Future<ShootDocument> uploadDocument(String shootId, String part, {required String fileName, required List<int> bytes, String label = ''}) async {
    uploads.add((part, fileName, bytes.length));
    return ShootDocument(key: 'new', part: part, name: fileName);
  }

  final fetched = <String>[];
  bool failFetch = false;
  @override
  Future<Uint8List> documentBytes(String shootId, String key) async {
    fetched.add(key);
    if (failFetch) throw Exception('offline');
    return Uint8List.fromList([37, 80, 68, 70, 45, 49]);
  }

  final docRenames = <(String, String)>[];
  @override
  Future<void> renameDocument(String shootId, String key, String label) async => docRenames.add((key, label));
  final docRemovals = <String>[];
  @override
  Future<void> removeDocument(String shootId, String key) async => docRemovals.add(key);
  @override
  Future<ShootSummary> saveShoot(Map<String, dynamic> body, {String? id}) async {
    saved.add(body);
    return ShootSummary.fromJson(detail);
  }

  @override
  Future<ShootSetup> setup() async => ShootSetup.fromJson({'members': [{'id': 'm1', 'name': 'Ashique', 'role': 'Video Editor'}, {'id': 'm2', 'name': 'Faies', 'role': 'Video Editor'}]});
}

class _FakeUpload extends UploadService {
  _FakeUpload() : super(Dio());
  final names = <String>[];
  @override
  Future<String> uploadImage(XFile file) async {
    names.add(file.name);
    return 'https://res.cloudinary.com/x/image/upload/v1/${file.name}';
  }
}

Map<String, dynamic> _booking({bool dropbox = false, bool needsContent = true, List<Map<String, dynamic>>? links, String state = 'waiting', bool due = true}) => {
      'bookingId': 'b1', 'bookingNumber': 'BK-1001', 'client': 'Amina K', 'service': 'Bridal Makeup', 'needsContent': needsContent, 'dropbox': {'enabled': dropbox}, 'canAdd': true, 'isMarketing': false,
      'days': [
        {'day': '2026-11-18', 'folderName': '2026-11-18 · BK-1001 · Amina K · Bridal Makeup', 'state': state, 'due': due, 'links': links ?? [], 'files': [], 'size': ''},
        {'day': '2026-11-20', 'folderName': '2026-11-20 · BK-1001 · Amina K · Bridal Makeup', 'state': 'waiting', 'due': false, 'links': [], 'files': [], 'size': ''},
      ],
    };

class _FakeFootage extends FootageService {
  _FakeFootage() : super(Dio());
  Map<String, dynamic> bookingJson = _booking();
  TeamRefusal? refuse;
  final links = <(String, String)>[];
  final removed = <String>[];
  final statuses = <(String, String, String?)>[];
  int checks = 0;

  @override
  Future<BookingFootage> booking(String bookingId) async => BookingFootage.fromJson(bookingJson);
  @override
  Future<BookingFootage> addLink(String bookingId, {required String day, required String url, String label = ''}) async {
    if (refuse != null) throw refuse!;
    links.add((day, url));
    bookingJson = _booking(state: 'new', due: false, links: [{'id': 'l1', 'url': url, 'label': label, 'kind': 'folder', 'addedByName': 'Anu', 'mine': true}]);
    return BookingFootage.fromJson(bookingJson);
  }

  @override
  Future<BookingFootage> removeLink(String bookingId, String linkId) async {
    removed.add(linkId);
    return BookingFootage.fromJson(bookingJson);
  }

  @override
  Future<String> uploadPage(String bookingId, String day) async => 'https://www.dropbox.com/request/fr1';
  @override
  Future<(BookingFootage, int)> checkUpload(String bookingId, String day) async {
    checks += 1;
    return (BookingFootage.fromJson(bookingJson), 2);
  }

  @override
  Future<FootageInbox> inbox({String status = 'all'}) async => FootageInbox.fromJson({
        'counts': {'new': 1, 'in_edit': 1, 'edited': 0, 'waiting': 1},
        'dropbox': {'enabled': false},
        'items': [
          {'id': 'f1', 'bookingNumber': 'BK-1001', 'day': '2026-11-18', 'folderName': '2026-11-18 · BK-1001 · Amina K · Bridal Makeup', 'status': 'new', 'links': [{'id': 'l1', 'url': 'https://www.dropbox.com/scl/fo/a/b', 'kind': 'folder', 'summary': '3 videos · 1.6 GB'}], 'fileCount': 2, 'size': '1.6 GB', 'uploaders': ['Anu']},
          {'id': 'f2', 'bookingNumber': 'BK-1003', 'day': '2026-11-17', 'folderName': '2026-11-17 · BK-1003 · Neha · Party', 'status': 'in_edit', 'links': [{'id': 'l2', 'url': 'https://www.dropbox.com/scl/fi/c/d.mp4', 'kind': 'file'}], 'editorName': 'Faies'},
        ],
        'waiting': [{'bookingId': 'b2', 'bookingNumber': 'BK-1002', 'client': 'Diya', 'service': 'Reception', 'day': '2026-11-18', 'artists': ['Bina']}],
      });
  @override
  Future<void> setStatus(String id, String status, {String? editorMemberId}) async => statuses.add((id, status, editorMemberId));
}

final _savedPdfs = <(String, int)>[];
Uint8List _pickedPdf = Uint8List.fromList([37, 80, 68, 70, 45, 49, 46, 52]);

Future<({_FakePortfolio p, _FakeUpload u, _FakeFootage f, List<Uri> opened})> _pump(WidgetTester t, Widget child, {_FakePortfolio? p, _FakeFootage? f, Size size = const Size(1200, 1800)}) async {
  _savedPdfs.clear();
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final portfolio = p ?? _FakePortfolio();
  final upload = _FakeUpload();
  final footage = f ?? _FakeFootage();
  final opened = <Uri>[];
  await t.pumpWidget(ProviderScope(
    overrides: [
      marketingPortfolioServiceProvider.overrideWithValue(portfolio),
      uploadServiceProvider.overrideWithValue(upload),
      footageServiceProvider.overrideWithValue(footage),
      moodboardPickerProvider.overrideWithValue(() async => [XFile.fromData(Uint8List(3), name: 'look1.jpg', path: 'look1.jpg'), XFile.fromData(Uint8List(3), name: 'look2.jpg', path: 'look2.jpg')]),
      footageLinkOpenerProvider.overrideWithValue((uri) async {
        opened.add(uri);
        return true;
      }),
      dropboxLinkOpenerProvider.overrideWithValue((uri) async {
        opened.add(uri);
        return true;
      }),
      mediaStreamServiceProvider.overrideWithValue(NoMediaStream()),
      shootPdfPickerProvider.overrideWithValue(() async => (name: 'Shot list.pdf', bytes: _pickedPdf)),
      pdfPagesBuilderProvider.overrideWithValue((bytes) => Text('pages of ${bytes.length} bytes', key: const Key('pdf_stand_in'))),
      pdfSaverProvider.overrideWithValue((name, bytes) async => _savedPdfs.add((name, bytes.length))),
    ],
    child: MaterialApp(theme: AppTheme.lightTheme, home: Scaffold(body: SingleChildScrollView(child: child))),
  ));
  await t.pumpAndSettle();
  return (p: portfolio, u: upload, f: footage, opened: opened);
}

void main() {
  group('the Shoot Planner\'s moodboard', () {
    testWidgets('the Brief shows the moodboard preview; View All opens the Moodboard tab with pictures and link cards', (t) async {
      await _pump(t, const ShootDetailCard(id: 's1'));
      expect(_k('pf_moodboard_preview'), findsOneWidget);
      await t.tap(_k('pf_moodboard_view_all'));
      await t.pumpAndSettle();
      expect(_k('pf_moodboard'), findsOneWidget);
      expect(find.text('2 items · 1 picture'), findsOneWidget);
      expect(find.text('Hair idea'), findsWidgets);
      expect(find.text('Pinterest'), findsWidgets, reason: 'a link card names its site');
      expect(find.text('Added by Shahala'), findsOneWidget);
    });

    testWidgets('pictures from the phone are uploaded, then put on the board in one go', (t) async {
      final r = await _pump(t, const ShootDetailCard(id: 's1'));
      await t.tap(_k('pf_part_moodboard'));
      await t.pumpAndSettle();
      await t.tap(_k('pf_moodboard_add_pictures'));
      await t.pumpAndSettle();
      expect(r.u.names, ['look1.jpg', 'look2.jpg']);
      expect(r.p.added.single.map((x) => x['url']), ['https://res.cloudinary.com/x/image/upload/v1/look1.jpg', 'https://res.cloudinary.com/x/image/upload/v1/look2.jpg']);
      expect(find.text('2 pictures added.'), findsOneWidget);
    });

    testWidgets('a link is added with its name; a bad link is refused in the dialog', (t) async {
      final r = await _pump(t, const ShootDetailCard(id: 's1'));
      await t.tap(_k('pf_part_moodboard'));
      await t.pumpAndSettle();
      await t.tap(_k('pf_moodboard_add_link'));
      await t.pumpAndSettle();
      await t.enterText(_k('pf_mood_link_url'), 'not a link');
      await t.tap(_k('pf_mood_link_ok'));
      await t.pumpAndSettle();
      expect(find.text('Paste a link starting with https://'), findsOneWidget);
      await t.enterText(_k('pf_mood_link_url'), 'https://www.instagram.com/p/abc/');
      await t.enterText(_k('pf_mood_link_label'), 'Saree drape');
      await t.tap(_k('pf_mood_link_ok'));
      await t.pumpAndSettle();
      expect(r.p.added.single, [{'url': 'https://www.instagram.com/p/abc/', 'label': 'Saree drape'}]);
    });

    testWidgets('an item is named, made the cover (pictures only), removed', (t) async {
      final r = await _pump(t, const ShootDetailCard(id: 's1'));
      await t.tap(_k('pf_part_moodboard'));
      await t.pumpAndSettle();
      await t.tap(_k('pf_mood_menu_0'));
      await t.pumpAndSettle();
      await t.tap(find.text('Use as the cover'));
      await t.pumpAndSettle();
      expect(r.p.saved.single, {'coverUrl': 'https://res.cloudinary.com/x/image/upload/v1/a.jpg'});
      await t.tap(_k('pf_mood_menu_1'));
      await t.pumpAndSettle();
      expect(find.text('Use as the cover'), findsNothing, reason: 'a link is not a picture');
      await t.tap(find.text('Name it'));
      await t.pumpAndSettle();
      await t.enterText(_k('pf_mood_label'), 'Bun idea');
      await t.tap(_k('pf_mood_label_ok'));
      await t.pumpAndSettle();
      expect(r.p.renamed.single, ('https://www.pinterest.com/pin/9/', 'Bun idea'));
      await t.tap(_k('pf_mood_menu_1'));
      await t.pumpAndSettle();
      await t.tap(find.text('Remove'));
      await t.pumpAndSettle();
      expect(r.p.removed.single, 'https://www.pinterest.com/pin/9/');
    });

    testWidgets('a phone: the Brief\'s preview and the moodboard fit', (t) async {
      final p = _FakePortfolio()..detail = _detail(refs: [for (var i = 0; i < 6; i++) {'url': 'https://www.pinterest.com/pin/$i/', 'kind': 'link'}]);
      await _pump(t, const ShootDetailCard(id: 's1'), p: p, size: const Size(390, 1800));
      expect(t.takeException(), isNull);
      expect(find.text('+2'), findsOneWidget, reason: 'four shown, two more');
      await t.tap(_k('pf_part_moodboard'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });
  });

  group('Crew & Logistics, and the work\'s footage', () {
    testWidgets('call time, map, the checklist with who ticked it; a tick sends only that line (never the whole list)', (t) async {
      final r = await _pump(t, const ShootDetailCard(id: 's1'));
      await t.tap(_k('pf_part_crew'));
      await t.pumpAndSettle();
      expect(find.text('Crew call 06:30'), findsOneWidget);
      expect(_k('pf_logistics_map'), findsOneWidget);
      expect(find.text('Checklist · 1 of 2 done'), findsOneWidget);
      expect(find.text('by Faies'), findsOneWidget);
      await t.tap(_k('pf_check_0'));
      await t.pumpAndSettle();
      expect(r.p.ticks.single, ('Ring light', true));
      expect(r.p.logistics, isEmpty, reason: 'the whole list is not sent: another person\'s tick at the same moment is never undone');
    });

    testWidgets('editing the logistics keeps the ticks of the lines that stay', (t) async {
      final r = await _pump(t, const ShootDetailCard(id: 's1'));
      await t.tap(_k('pf_part_crew'));
      await t.pumpAndSettle();
      await t.tap(_k('pf_logistics_edit'));
      await t.pumpAndSettle();
      await t.enterText(_k('pf_log_items'), 'Steamer\nBridal set');
      await t.enterText(_k('pf_log_call'), '07:00');
      await t.tap(_k('pf_log_save'));
      await t.pumpAndSettle();
      expect(r.p.logistics.single['checklist'], [{'text': 'Steamer', 'done': true}, {'text': 'Bridal set', 'done': false}]);
      expect(r.p.logistics.single['callTime'], '07:00');
    });

    testWidgets('the Content Plan shows the raw footage the artists handed in for the work', (t) async {
      await _pump(t, const ShootDetailCard(id: 's1'));
      await t.tap(_k('pf_part_plan'));
      await t.pumpAndSettle();
      expect(_k('pf_footage_2026-11-18'), findsOneWidget);
      expect(find.text('Dropbox folder · from Bina'), findsOneWidget);
      expect(find.text('1.6 GB'), findsOneWidget);
    });
  });

  group('PDFs on the moodboard and the storyboard', () {
    testWidgets('the moodboard lists its PDF (name, pages, size, who); Upload PDF puts one on the moodboard', (t) async {
      final r = await _pump(t, const ShootDetailCard(id: 's1'));
      await t.tap(_k('pf_part_moodboard'));
      await t.pumpAndSettle();
      expect(_k('pf_pdf_d1'), findsOneWidget);
      expect(_k('pf_pdf_d2'), findsNothing, reason: 'the storyboard\'s PDF stays on the storyboard');
      expect(find.text('Bridal lookbook'), findsOneWidget);
      expect(find.textContaining('3 pages · 1.2 MB · Shahala'), findsOneWidget);
      await t.tap(_k('pf_pdf_upload_moodboard'));
      await t.pumpAndSettle();
      expect(r.p.uploads.single, ('moodboard', 'Shot list.pdf', 8));
      expect(find.text('Shot list.pdf added.'), findsOneWidget);
    });

    testWidgets('a PDF opens in the app: its pages, Download saves it, Close', (t) async {
      final r = await _pump(t, const ShootDetailCard(id: 's1'));
      await t.tap(_k('pf_part_moodboard'));
      await t.pumpAndSettle();
      await t.tap(_k('pf_pdf_d1'));
      await t.pumpAndSettle();
      expect(_k('pf_pdf_reader'), findsOneWidget);
      expect(r.p.fetched, ['d1']);
      expect(find.text('pages of 6 bytes'), findsOneWidget, reason: 'the file\'s pages are shown');
      expect(t.widget<Text>(_k('pf_pdf_title')).data, 'Bridal lookbook');
      await t.tap(_k('pf_pdf_download'));
      await t.pumpAndSettle();
      expect(_savedPdfs.single, ('Lookbook Nov.pdf', 6));
      await t.tap(_k('pf_pdf_close'));
      await t.pumpAndSettle();
      expect(_k('pf_pdf_reader'), findsNothing);
    });

    testWidgets('a PDF that cannot be fetched says so, and Try again fetches it again', (t) async {
      final p = _FakePortfolio()..failFetch = true;
      await _pump(t, const ShootDetailCard(id: 's1'), p: p);
      await t.tap(_k('pf_part_moodboard'));
      await t.pumpAndSettle();
      await t.tap(_k('pf_pdf_d1'));
      await t.pumpAndSettle();
      expect(_k('pf_pdf_error'), findsOneWidget);
      expect(_k('pf_pdf_download'), findsNothing);
      p.failFetch = false;
      await t.tap(_k('pf_pdf_retry'));
      await t.pumpAndSettle();
      expect(_k('pdf_stand_in'), findsOneWidget);
      expect(p.fetched, ['d1', 'd1']);
    });

    testWidgets('the storyboard has its own PDFs; one is named and one removed (after asking)', (t) async {
      final r = await _pump(t, const ShootDetailCard(id: 's1'));
      await t.tap(_k('pf_part_storyboard'));
      await t.pumpAndSettle();
      expect(_k('pf_pdf_d2'), findsOneWidget);
      expect(_k('pf_pdf_d1'), findsNothing);
      expect(find.textContaining('12 pages · 40 KB'), findsOneWidget);
      await t.tap(_k('pf_pdf_upload_storyboard'));
      await t.pumpAndSettle();
      expect(r.p.uploads.single.$1, 'storyboard');
      await t.tap(_k('pf_pdf_menu_d2'));
      await t.pumpAndSettle();
      await t.tap(find.text('Name it'));
      await t.pumpAndSettle();
      await t.enterText(_k('pf_pdf_label'), 'Director\'s storyboard');
      await t.tap(_k('pf_pdf_label_ok'));
      await t.pumpAndSettle();
      expect(r.p.docRenames.single, ('d2', 'Director\'s storyboard'));
      await t.tap(_k('pf_pdf_menu_d2'));
      await t.pumpAndSettle();
      await t.tap(find.text('Remove'));
      await t.pumpAndSettle();
      expect(r.p.docRemovals, isEmpty, reason: 'it asks first');
      await t.tap(_k('pf_pdf_remove_ok'));
      await t.pumpAndSettle();
      expect(r.p.docRemovals.single, 'd2');
    });

    testWidgets('a PDF over 25 MB is refused before it is sent', (t) async {
      _pickedPdf = Uint8List(25 * 1024 * 1024 + 1);
      addTearDown(() => _pickedPdf = Uint8List.fromList([37, 80, 68, 70, 45, 49, 46, 52]));
      final r = await _pump(t, const ShootDetailCard(id: 's1'));
      await t.tap(_k('pf_part_moodboard'));
      await t.pumpAndSettle();
      await t.tap(_k('pf_pdf_upload_moodboard'));
      await t.pumpAndSettle();
      expect(r.p.uploads, isEmpty);
      expect(find.textContaining('over 25 MB'), findsOneWidget);
    });

    testWidgets('a phone (390 wide): the PDFs fit on the moodboard and the storyboard, and the reader opens full screen', (t) async {
      await _pump(t, const ShootDetailCard(id: 's1'), size: const Size(390, 1800));
      await t.tap(_k('pf_part_moodboard'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await t.tap(_k('pf_part_storyboard'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await t.tap(_k('pf_pdf_d2'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(t.getSize(_k('pf_pdf_reader')).width, 390);
    });
  });

  group('the storyboard', () {
    testWidgets('frames with their pictures; "1 of 2 shot", who ticked it; a tick sends only that frame', (t) async {
      final r = await _pump(t, const ShootDetailCard(id: 's1'));
      await t.tap(_k('pf_part_storyboard'));
      await t.pumpAndSettle();
      expect(_k('pf_storyboard'), findsOneWidget);
      expect(t.widget<Text>(_k('pf_storyboard_progress')).data, '1 of 2 shot');
      expect(_k('pf_frame_img_0'), findsOneWidget, reason: 'the frame\'s picture');
      expect(_k('pf_frame_img_1'), findsNothing, reason: 'no picture: a placeholder');
      expect(t.widget<Text>(_k('pf_frame_by_0')).data, startsWith('by Ashique'));
      await t.tap(_k('pf_frame_shot_1'));
      await t.pumpAndSettle();
      expect(r.p.shots.single, ('fk2', true));
      expect(r.p.saved, isEmpty, reason: 'a tick never saves the whole storyboard');
      await t.tap(_k('pf_frame_shot_0'));
      await t.pumpAndSettle();
      expect(r.p.shots.last, ('fk1', false), reason: 'a tick can be taken back');
    });

    testWidgets('the editor: a picture from the moodboard or uploaded; the frames go back with their keys (ticks stay), never the tick', (t) async {
      final r = await _pump(t, const ShootDetailCard(id: 's1'));
      await t.tap(_k('pf_part_storyboard'));
      await t.pumpAndSettle();
      await t.tap(_k('pf_storyboard_edit'));
      await t.pumpAndSettle();
      expect(_k('sb_pic_0'), findsOneWidget);
      // frame 2 takes a moodboard picture
      await t.ensureVisible(_k('sb_mood_1'));
      await t.tap(_k('sb_mood_1'));
      await t.pumpAndSettle();
      await t.tap(_k('sb_mood_pick_0'));
      await t.pumpAndSettle();
      // a new frame gets an uploaded picture
      await t.ensureVisible(_k('sb_add'));
      await t.tap(_k('sb_add'));
      await t.pumpAndSettle();
      await t.enterText(_k('sb_desc_2'), 'The jewellery');
      await t.ensureVisible(_k('sb_upload_2'));
      await t.tap(_k('sb_upload_2'));
      await t.pumpAndSettle();
      expect(r.u.names, ['look1.jpg'], reason: 'one picture for the frame');
      await t.ensureVisible(_k('sb_save'));
      await t.tap(_k('sb_save'));
      await t.pumpAndSettle();
      final frames = (r.p.saved.single['storyboard'] as List).cast<Map<String, dynamic>>();
      expect(frames.map((f) => f['key']), ['fk1', 'fk2', null]);
      expect(frames.map((f) => f['imageUrl']), ['https://res.cloudinary.com/x/image/upload/v1/sketch1.jpg', 'https://res.cloudinary.com/x/image/upload/v1/a.jpg', 'https://res.cloudinary.com/x/image/upload/v1/look1.jpg']);
      expect(frames.every((f) => !f.containsKey('shotAt') && !f.containsKey('shotByName')), isTrue, reason: 'the tick is the server\'s own');
    });

    testWidgets('a phone (390 wide): the frames fit, one per row', (t) async {
      await _pump(t, const ShootDetailCard(id: 's1'), size: const Size(390, 1800));
      await t.tap(_k('pf_part_storyboard'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(t.getSize(_k('pf_frame_0')).width, greaterThan(300));
    });
  });

  group('the artist\'s footage card', () {
    testWidgets('a day that has come: the folder to use, the steps, Marketing waiting; a day to come is not shown', (t) async {
      await _pump(t, const WorkFootageCard(bookingId: 'b1', today: '2026-11-19'));
      expect(_k('footage_day_2026-11-18'), findsOneWidget);
      expect(_k('footage_day_2026-11-20'), findsNothing);
      expect(find.text('2026-11-18 · BK-1001 · Amina K · Bridal Makeup'), findsOneWidget);
      expect(_k('footage_due_2026-11-18'), findsOneWidget);
      expect(_k('footage_steps'), findsOneWidget, reason: 'Dropbox not connected: how to do it by hand');
      expect(_k('footage_upload_2026-11-18'), findsNothing);
    });

    testWidgets('the Dropbox link is sent; a refusal is said; then it shows as sent, with a way to take it off', (t) async {
      final f = _FakeFootage()..refuse = const TeamRefusal('Only Dropbox (or Google Drive) links are taken for footage.');
      await _pump(t, const WorkFootageCard(bookingId: 'b1', today: '2026-11-19'), f: f);
      await t.tap(_k('footage_add_2026-11-18'));
      await t.pumpAndSettle();
      await t.enterText(_k('footage_link_url'), 'https://wetransfer.com/x');
      await t.tap(_k('footage_link_ok'));
      await t.pumpAndSettle();
      expect(find.text('Only Dropbox (or Google Drive) links are taken for footage.'), findsOneWidget);
      f.refuse = null;
      await t.tap(_k('footage_add_2026-11-18'));
      await t.pumpAndSettle();
      await t.enterText(_k('footage_link_url'), 'https://www.dropbox.com/scl/fo/a/b');
      await t.tap(_k('footage_link_ok'));
      await t.pumpAndSettle();
      expect(f.links.single, ('2026-11-18', 'https://www.dropbox.com/scl/fo/a/b'));
      expect(t.widget<Text>(_k('footage_state_2026-11-18')).data, 'Sent to Marketing');
      await t.tap(_k('footage_remove_l1'));
      await t.pumpAndSettle();
      expect(f.removed.single, 'l1');
    });

    testWidgets('Dropbox connected: Upload opens the work\'s upload page; "I\'ve uploaded" checks the folder', (t) async {
      final f = _FakeFootage()..bookingJson = _booking(dropbox: true);
      final r = await _pump(t, const WorkFootageCard(bookingId: 'b1', today: '2026-11-19'), f: f);
      expect(_k('footage_steps'), findsNothing);
      await t.tap(_k('footage_upload_2026-11-18'));
      await t.pumpAndSettle();
      expect(r.opened.single.toString(), 'https://www.dropbox.com/request/fr1');
      await t.tap(_k('footage_check_2026-11-18'));
      await t.pumpAndSettle();
      expect(f.checks, 1);
      expect(find.text('Found 2 files — sent to Marketing.'), findsOneWidget);
    });

    testWidgets('a work that needs no content shows only a small "add footage" line', (t) async {
      final f = _FakeFootage()..bookingJson = _booking(needsContent: false, due: false);
      await _pump(t, const WorkFootageCard(bookingId: 'b1', today: '2026-11-19'), f: f);
      expect(_k('footage_day_2026-11-18'), findsNothing);
      expect(_k('footage_add_optional_b1'), findsOneWidget);
    });
  });

  group('Marketing\'s Footage tab', () {
    testWidgets('the counts, the footage in, the works owing it; to an editor; marked edited', (t) async {
      final r = await _pump(t, const SizedBox(height: 1600, child: FootageTab()));
      expect(find.descendant(of: _k('ft_kpi_waiting'), matching: find.text('1')), findsOneWidget);
      expect(_k('ft_item_f1'), findsOneWidget);
      expect(_k('ft_waiting_b2_2026-11-18'), findsOneWidget);
      expect(find.textContaining('from Anu'), findsOneWidget);
      // a Dropbox folder opens in the app's folder view (here no server to list it: it still opens in Dropbox from there)
      expect(find.text('Dropbox folder · 3 videos · 1.6 GB'), findsOneWidget, reason: 'what was in the folder when it was handed in');
      await t.tap(_k('ft_link_l1'));
      await t.pumpAndSettle();
      expect(_k('folder_view'), findsOneWidget);
      await t.tap(_k('folder_open'));
      await t.pumpAndSettle();
      expect(r.opened.single.toString(), 'https://www.dropbox.com/scl/fo/a/b');
      await t.tap(_k('folder_close'));
      await t.pumpAndSettle();
      expect(_k('folder_view'), findsNothing);
      // a single video file still opens straight away
      await t.tap(_k('ft_link_l2'));
      await t.pumpAndSettle();
      expect(r.opened.last.toString(), 'https://www.dropbox.com/scl/fi/c/d.mp4');
      await t.tap(_k('ft_to_editor_f1'));
      await t.pumpAndSettle();
      await t.tap(_k('footage_editor_m2'));
      await t.pumpAndSettle();
      expect(r.f.statuses.single, ('f1', 'in_edit', 'm2'));
      await t.tap(_k('ft_edited_f2'));
      await t.pumpAndSettle();
      expect(r.f.statuses.last, ('f2', 'edited', null));
    });
  });
}
