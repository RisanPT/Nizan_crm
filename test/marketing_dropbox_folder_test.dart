import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/marketing/data/socials_models.dart';
import 'package:nizan_crm/features/marketing/presentation/media/asset_viewer.dart';
import 'package:nizan_crm/features/marketing/presentation/media/clip_player.dart';
import 'package:nizan_crm/features/marketing/presentation/media/dropbox_folder_view.dart';
import 'package:nizan_crm/features/marketing/presentation/media/media_stream.dart';
import 'package:nizan_crm/features/marketing/presentation/socials/socials_widgets.dart' show AssetThumb;

// A DROPBOX FOLDER LINK — what artists send for a work's footage. In the gallery it is a folder (never a video that will not play);
// opened, it lists what is inside (the server reads it through its Dropbox app) and plays a video / shows a picture right there; with no
// Dropbox app on the server it says so and still opens in Dropbox, or downloads as one .zip.

Finder _k(String key) => find.byKey(Key(key));

const _folder = 'https://www.dropbox.com/scl/fo/fzq/AD9?rlkey=xyz&st=abc&dl=0';

Map<String, dynamic> _top() => {
      'url': 'https://www.dropbox.com/scl/fo/fzq/AD9?rlkey=xyz&st=abc', 'path': '', 'zipUrl': 'https://www.dropbox.com/scl/fo/fzq/AD9?rlkey=xyz&st=abc&dl=1', 'connected': true, 'ok': true,
      'summary': '2 videos · 1 other file · 1 folder · 2.4 GB',
      'folders': [{'name': 'Stills', 'path': '/Stills'}],
      'files': [
        {'name': 'C0002.MP4', 'path': '/C0002.MP4', 'size': 1200000000, 'modifiedAt': '2026-11-18T10:00:00Z', 'media': 'video', 'showable': true},
        {'name': 'C0003.MTS', 'path': '/C0003.MTS', 'size': 900000000, 'media': 'video', 'showable': false},
        {'name': 'notes.txt', 'path': '/notes.txt', 'size': 10, 'media': 'other', 'showable': false},
      ],
    };

class _Stream extends MediaStreamService {
  _Stream() : super(null);
  final listings = <String, DropboxFolderListing?>{};
  final asked = <(String, String, bool)>[];
  final links = <(String, String)>[];
  MediaStreamLink? Function(String path)? answer;

  @override
  Future<DropboxFolderListing?> folder(String url, {String path = '', bool fresh = false}) async {
    asked.add((url, path, fresh));
    return listings[path];
  }

  @override
  Future<MediaStreamLink?> link(String url, {bool probe = false, String path = ''}) async {
    links.add((url, path));
    return answer?.call(path) ?? MediaStreamLink(url: 'https://api.test/api/marketing/media/stream/T$path');
  }
}

class _Clip extends ClipPlayer {
  _Clip(this.uri);
  final Uri uri;
  bool ready = false, playing = false, muted = false;
  @override
  Future<void> initialize() async => ready = true;
  @override
  bool get isReady => ready;
  @override
  bool get isPlaying => playing;
  @override
  bool get isMuted => muted;
  @override
  Duration get position => Duration.zero;
  @override
  Duration get duration => const Duration(seconds: 42);
  @override
  double get aspectRatio => 16 / 9;
  @override
  String? get errorText => null;
  @override
  Future<void> play() async {
    playing = true;
    notifyListeners();
  }

  @override
  Future<void> pause() async {
    playing = false;
    notifyListeners();
  }

  @override
  Future<void> setMuted(bool m) async => muted = m;
  @override
  Future<void> seekTo(Duration to) async {}
  @override
  Widget buildView() => const ColoredBox(color: Colors.black);
}

Future<({_Stream s, List<Uri> opened, List<_Clip> clips})> _pump(WidgetTester t, Widget child, {_Stream? s, Size size = const Size(1100, 1400)}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final stream = s ?? _Stream();
  final opened = <Uri>[];
  final clips = <_Clip>[];
  await t.pumpWidget(ProviderScope(
    overrides: [
      mediaStreamServiceProvider.overrideWithValue(stream),
      dropboxLinkOpenerProvider.overrideWithValue((uri) async {
        opened.add(uri);
        return true;
      }),
      clipPlayerFactoryProvider.overrideWithValue((uri) {
        final c = _Clip(uri);
        clips.add(c);
        return c;
      }),
    ],
    child: MaterialApp(theme: AppTheme.lightTheme, home: Scaffold(body: child)),
  ));
  await t.pumpAndSettle();
  return (s: stream, opened: opened, clips: clips);
}

void main() {
  test('download all = the same folder link with dl=1 (rlkey kept); a file link has none', () {
    expect(dropboxFolderZipUrl(_folder), 'https://www.dropbox.com/scl/fo/fzq/AD9?rlkey=xyz&st=abc&dl=1');
    expect(dropboxFolderZipUrl('https://example.com/a'), '');
  });

  testWidgets('in the gallery a folder is a folder: no play sign, "Dropbox folder"', (t) async {
    await _pump(t, const SizedBox(width: 240, child: AssetThumb(asset: Asset(id: 'a1', title: 'Footage', media: 'video', kind: 'film', url: _folder))));
    expect(_k('asset_folder_thumb'), findsOneWidget);
    expect(find.text('Dropbox folder'), findsOneWidget);
    expect(find.byIcon(Icons.play_circle_outline_rounded), findsNothing);
  });

  testWidgets('opening the folder asset shows what is inside; a video plays right there through the server', (t) async {
    final s = _Stream()..listings[''] = DropboxFolderListing.fromJson(_top());
    final r = await _pump(t, const AssetViewer(asset: Asset(id: 'a1', title: '2026-11-18 · BK-1001 · Diya', media: 'video', kind: 'film', url: _folder)), s: s);
    expect(_k('folder_view'), findsOneWidget);
    expect(find.text('2026-11-18 · BK-1001 · Diya'), findsOneWidget);
    expect(find.text('2 videos · 1 other file · 1 folder · 2.4 GB'), findsOneWidget);
    expect(s.asked.single, (_folder, '', false));
    expect(_k('folder_dir_Stills'), findsOneWidget);
    expect(find.textContaining('1.1 GB'), findsOneWidget, reason: 'each file with its size');
    expect(find.textContaining('opens in Dropbox'), findsNWidgets(2), reason: 'what the app cannot play says where it opens');

    await t.tap(_k('folder_file_C0002.MP4'));
    await t.pumpAndSettle();
    expect(s.links.single, (_folder, '/C0002.MP4'));
    expect(r.clips.single.uri.toString(), 'https://api.test/api/marketing/media/stream/T/C0002.MP4');
    expect(r.clips.single.playing, isTrue, reason: 'a tapped clip starts');
    expect(_k('folder_player'), findsOneWidget);
    expect(t.widget<Text>(_k('folder_open_name')).data, 'C0002.MP4');
    await t.tap(_k('folder_play'));
    await t.pump();
    expect(r.clips.single.playing, isFalse);
    await t.tap(_k('folder_clip_close'));
    await t.pumpAndSettle();
    expect(_k('folder_player'), findsNothing);
  });

  testWidgets('a file the app cannot play opens the folder in Dropbox; a refusal is said in the server\'s words', (t) async {
    final s = _Stream()
      ..listings[''] = DropboxFolderListing.fromJson(_top())
      ..answer = (p) => const MediaStreamLink(ok: false, code: 'private', message: 'Dropbox refused the link — share it as "Anyone with the link can view".');
    final r = await _pump(t, const DropboxFolderView(url: _folder, title: 'Footage'), s: s);
    await t.tap(_k('folder_file_C0003.MTS'));
    await t.pumpAndSettle();
    expect(r.opened.single.toString(), _folder);
    expect(s.links, isEmpty, reason: 'nothing asked of the server for it');
    await t.tap(_k('folder_file_C0002.MP4'));
    await t.pumpAndSettle();
    expect(find.textContaining('Anyone with the link can view'), findsOneWidget);
    expect(r.clips, isEmpty);
  });

  testWidgets('a sub-folder opens, and the path leads back; a picture shows; Refresh lists again', (t) async {
    final s = _Stream()
      ..listings[''] = DropboxFolderListing.fromJson(_top())
      ..listings['/Stills'] = DropboxFolderListing.fromJson({'connected': true, 'ok': true, 'summary': '1 picture · 1 MB', 'path': '/Stills', 'files': [{'name': 'IMG_1.jpg', 'path': '/Stills/IMG_1.jpg', 'size': 800000, 'media': 'picture', 'showable': true}]});
    await _pump(t, const DropboxFolderView(url: _folder), s: s);
    await t.tap(_k('folder_dir_Stills'));
    await t.pumpAndSettle();
    expect(s.asked.last, (_folder, '/Stills', false));
    expect(find.text('1 picture · 1 MB'), findsOneWidget);
    expect(_k('folder_crumb_1'), findsOneWidget);
    await t.tap(_k('folder_file_IMG_1.jpg'));
    await t.pumpAndSettle();
    expect(_k('folder_picture'), findsOneWidget);
    await t.tap(_k('folder_crumb_0'));
    await t.pumpAndSettle();
    expect(s.asked.last, (_folder, '', false));
    expect(_k('folder_picture'), findsNothing, reason: 'leaving the folder closes what was open');
    await t.tap(_k('folder_refresh'));
    await t.pumpAndSettle();
    expect(s.asked.last, (_folder, '', true));
  });

  testWidgets('no Dropbox app on the server: it says so; Open in Dropbox and Download all still work', (t) async {
    final s = _Stream()..listings[''] = DropboxFolderListing.fromJson({'connected': false, 'ok': false, 'code': 'not_connected', 'zipUrl': 'https://www.dropbox.com/scl/fo/fzq/AD9?rlkey=xyz&st=abc&dl=1', 'message': 'Dropbox is not connected to the CRM yet, so the videos inside cannot be listed here. Open the folder in Dropbox, or download it all.'});
    final r = await _pump(t, const DropboxFolderView(url: _folder), s: s);
    expect(find.textContaining('Dropbox is not connected to the CRM yet'), findsOneWidget);
    expect(_k('folder_refresh'), findsNothing);
    await t.tap(_k('folder_open'));
    await t.tap(_k('folder_zip'));
    await t.pumpAndSettle();
    expect(r.opened.map((u) => u.toString()), [_folder, 'https://www.dropbox.com/scl/fo/fzq/AD9?rlkey=xyz&st=abc&dl=1']);
  });

  testWidgets('no server to ask (offline, an older server): the folder still opens in Dropbox, the zip from the link itself', (t) async {
    final r = await _pump(t, const DropboxFolderView(url: _folder), s: _Stream());
    expect(_k('folder_message'), findsOneWidget);
    await t.tap(_k('folder_zip'));
    await t.pumpAndSettle();
    expect(r.opened.single.toString(), 'https://www.dropbox.com/scl/fo/fzq/AD9?rlkey=xyz&st=abc&dl=1');
  });

  testWidgets('a folder Dropbox will not open for anyone says how to share it', (t) async {
    final s = _Stream()..listings[''] = DropboxFolderListing.fromJson({'connected': true, 'ok': false, 'code': 'private', 'message': 'Dropbox says this folder is not open to anyone with the link.'});
    await _pump(t, const DropboxFolderView(url: _folder), s: s);
    expect(find.text('Dropbox says this folder is not open to anyone with the link.'), findsOneWidget);
  });

  testWidgets('on a phone (390 wide) the folder fits — no overflow', (t) async {
    final s = _Stream()..listings[''] = DropboxFolderListing.fromJson(_top());
    await _pump(t, const DropboxFolderView(url: _folder, title: '2026-11-18 · BK-1001 · Amina K · Bridal Makeup'), s: s, size: const Size(390, 844));
    await t.tap(_k('folder_file_C0002.MP4'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(_k('folder_player'), findsOneWidget);
  });
}
