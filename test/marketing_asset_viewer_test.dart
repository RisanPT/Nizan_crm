import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:nizan_crm/core/theme/app_theme.dart';
import 'package:nizan_crm/features/marketing/data/asset_search.dart';
import 'package:nizan_crm/features/marketing/data/socials_models.dart';
import 'package:nizan_crm/features/marketing/data/team_models.dart';
import 'package:nizan_crm/features/marketing/presentation/media/asset_viewer.dart';
import 'package:nizan_crm/features/marketing/presentation/media/card_preview.dart';
import 'package:nizan_crm/features/marketing/presentation/media/clip_player.dart';
import 'package:nizan_crm/features/marketing/presentation/media/gallery_prefs.dart';
import 'package:nizan_crm/features/marketing/presentation/media/media_stream.dart';
import 'package:nizan_crm/features/marketing/presentation/portfolio/portfolio_gallery_tab.dart';
import 'package:nizan_crm/features/marketing/presentation/socials/asset_editor.dart';
import 'package:nizan_crm/features/marketing/presentation/socials/socials_assets_tab.dart';
import 'package:nizan_crm/features/marketing/services/socials_service.dart';
import 'package:nizan_crm/features/marketing/services/team_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The asset viewer (a Dropbox video plays in the app) and the per-viewer "Autoplay previews" setting.

class _FakeClip extends ClipPlayer {
  _FakeClip(this.uri, {this.failOpen = false, this.openError, this.failPlays = 0});
  final Uri uri;
  final bool failOpen;
  final Object? openError;

  /// How many of the first play() calls the "browser" refuses (autoplay policy).
  int failPlays;
  bool ready = false;
  bool playing = false;
  bool muted = false;
  bool disposed = false;
  bool looping = false;
  final seeks = <Duration>[];
  Duration pos = Duration.zero;
  String? failure;

  @override
  Future<void> initialize() async {
    if (failOpen) throw openError ?? UnimplementedError('no player on this platform');
    ready = true;
    notifyListeners();
  }

  @override
  bool get isReady => ready;
  @override
  bool get isPlaying => playing;
  @override
  bool get isMuted => muted;
  @override
  Duration get position => pos;
  @override
  Duration get duration => const Duration(seconds: 42);
  @override
  double get aspectRatio => 16 / 9;
  @override
  String? get errorText => failure;
  @override
  Future<void> play() async {
    if (failPlays > 0) {
      failPlays -= 1;
      throw StateError('NotAllowedError: play() was blocked');
    }
    playing = true;
    notifyListeners();
  }

  @override
  Future<void> pause() async {
    playing = false;
    notifyListeners();
  }

  @override
  Future<void> setMuted(bool m) async {
    muted = m;
    notifyListeners();
  }

  @override
  Future<void> seekTo(Duration to) async {
    seeks.add(to);
    pos = to;
    notifyListeners();
  }

  @override
  Future<void> setLooping(bool loop) async => looping = loop;

  @override
  Widget buildView() => const ColoredBox(color: Colors.black);

  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}

Asset _asset(String url, {String media = 'video', String kind = 'reel', String id = 'a1', String thumb = ''}) => Asset(id: id, title: 'Bridal Reel', kind: kind, media: media, stage: 'approved', url: url, thumbUrl: thumb);

const _dropbox = 'https://www.dropbox.com/scl/fi/abc/Bridal%20Reel.mp4?rlkey=KEY&dl=0';

class _HangingClip extends _FakeClip {
  _HangingClip(super.uri);
  @override
  Future<void> initialize() => Completer<void>().future;
}

class _Opener extends StatelessWidget {
  const _Opener(this.asset);
  final Asset asset;

  @override
  Widget build(BuildContext context) => Center(child: ElevatedButton(key: const Key('open_viewer'), onPressed: () => showAssetViewer(context, asset), child: const Text('open')));
}

class _World {
  _World(this.clips, this.container);
  final List<_FakeClip> clips;
  final ProviderContainer container;
}

Future<_World> _open(WidgetTester tester, Asset asset, {bool autoplay = false, bool failOpen = false, bool Function(Uri)? failFor, Object? openError, int failPlays = 0, Size size = const Size(1280, 900), MediaStreamService? stream}) async {
  SharedPreferences.setMockInitialValues({if (autoplay) 'marketing.gallery.autoplay': true});
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final clips = <_FakeClip>[];
  final overrides = <Override>[mediaStreamServiceProvider.overrideWithValue(stream ?? NoMediaStream()), clipPlayerFactoryProvider.overrideWithValue((uri) {
    final c = _FakeClip(uri, failOpen: failOpen || (failFor?.call(uri) ?? false), openError: openError, failPlays: failPlays);
    clips.add(c);
    return c;
  })];
  final container = ProviderContainer(overrides: overrides);
  addTearDown(container.dispose);
  container.read(galleryAutoplayProvider);
  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: MaterialApp(theme: AppTheme.lightTheme, home: Scaffold(body: _Opener(asset)))));
  await tester.pump(const Duration(milliseconds: 50)); // the saved choice loads
  await tester.tap(find.byKey(const Key('open_viewer')));
  await tester.pumpAndSettle();
  return _World(clips, container);
}

Finder _k(String key) => find.byKey(Key(key));

void main() {
  group('why a clip would not play', () {
    test('errors are sorted into the few kinds a person can act on', () {
      expect(classifyClipError(TimeoutException('x')), ClipFailure.timeout);
      expect(classifyClipError(UnimplementedError()), ClipFailure.unsupported);
      expect(classifyClipError(Exception('MissingPluginException(No implementation found)')), ClipFailure.unsupported);
      expect(classifyClipError(Exception('MEDIA_ERR_SRC_NOT_SUPPORTED')), ClipFailure.format);
      expect(classifyClipError(Exception('MEDIA_ERR_DECODE')), ClipFailure.format);
      expect(classifyClipError(Exception('MEDIA_ERR_NETWORK')), ClipFailure.network);
      expect(classifyClipError(Exception('SocketException: connection reset')), ClipFailure.network);
      expect(classifyClipError(Exception('something odd')), ClipFailure.unknown);
    });

    test('every kind has plain words and a short code, and none shows a raw error', () {
      for (final f in ClipFailure.values) {
        expect(clipFailureText(f).length, greaterThan(20));
        expect(clipFailureText(f), isNot(contains('Exception')));
        expect(clipFailureCode(f), f.name);
      }
    });

    test('openClip takes the first route that opens, lets go of the ones that failed, and reports the last reason when none does', () async {
      final made = <_FakeClip>[];
      final ok = await openClip((u) {
        final c = _FakeClip(u, failOpen: u.path == '/a', openError: Exception('MEDIA_ERR_NETWORK'));
        made.add(c);
        return c;
      }, ['https://x.test/a', 'https://x.test/b', 'https://x.test/c']);
      expect(ok.isReady, isTrue);
      expect(made, hasLength(2), reason: 'the third was never needed');
      expect(made.first.disposed, isTrue);
      final all = <_FakeClip>[];
      await expectLater(
        openClip((u) {
          final c = _FakeClip(u, failOpen: true, openError: Exception('MEDIA_ERR_SRC_NOT_SUPPORTED'));
          all.add(c);
          return c;
        }, ['https://x.test/a', 'https://x.test/b']),
        throwsA(isA<ClipOpenException>().having((e) => e.failure, 'failure', ClipFailure.format)),
      );
      expect(all.every((c) => c.disposed), isTrue);
    });

    test('a player that never answers times out instead of waiting for ever', () async {
      await expectLater(
        openClip((u) => _HangingClip(u), ['https://x.test/a'], timeout: const Duration(milliseconds: 30)),
        throwsA(isA<ClipOpenException>().having((e) => e.failure, 'failure', ClipFailure.timeout)),
      );
    });
  });

  group('a Dropbox video', () {
    testWidgets('plays in the app from the direct file link (raw=1, no dl), paused until you press play', (tester) async {
      final w = await _open(tester, _asset(_dropbox));
      expect(w.clips, hasLength(1));
      final u = w.clips.single.uri;
      expect(u.host, 'www.dropbox.com');
      expect(u.queryParameters, {'rlkey': 'KEY', 'raw': '1'});
      expect(w.clips.single.playing, isFalse, reason: 'autoplay is off by default');
      expect(_k('viewer_play'), findsOneWidget);
      await tester.tap(_k('viewer_play'));
      await tester.pumpAndSettle();
      expect(w.clips.single.playing, isTrue);
      await tester.tap(_k('viewer_play'));
      await tester.pumpAndSettle();
      expect(w.clips.single.playing, isFalse);
    });

    testWidgets('tapping the picture plays and pauses; mute and seek work; the clock shows the length', (tester) async {
      final w = await _open(tester, _asset(_dropbox));
      await tester.tap(_k('viewer_surface'));
      await tester.pumpAndSettle();
      expect(w.clips.single.playing, isTrue);
      await tester.tap(_k('viewer_mute'));
      await tester.pumpAndSettle();
      expect(w.clips.single.muted, isTrue);
      await tester.tap(_k('viewer_mute'));
      await tester.pumpAndSettle();
      expect(w.clips.single.muted, isFalse);
      expect(tester.widget<Text>(_k('viewer_time')).data, '0:00 / 0:42');
      await tester.drag(_k('viewer_seek'), const Offset(2000, 0));
      await tester.pumpAndSettle();
      expect(w.clips.single.pos, const Duration(seconds: 42));
    });

    testWidgets('closing the viewer lets go of the player', (tester) async {
      final w = await _open(tester, _asset(_dropbox));
      expect(w.clips.single.disposed, isFalse);
      await tester.tap(_k('viewer_close'));
      await tester.pumpAndSettle();
      expect(w.clips.single.disposed, isTrue);
    });
  });

  group('autoplay is each viewer\'s own choice', () {
    testWidgets('on: the video opens playing, and muted', (tester) async {
      final w = await _open(tester, _asset(_dropbox), autoplay: true);
      expect(w.clips.single.playing, isTrue);
      expect(w.clips.single.muted, isTrue, reason: 'a browser only lets a muted video start by itself');
      expect(tester.widget<Switch>(_k('gallery_autoplay')).value, isTrue);
    });

    testWidgets('off: nothing starts by itself, and the switch says off', (tester) async {
      final w = await _open(tester, _asset(_dropbox));
      expect(w.clips.single.playing, isFalse);
      expect(w.clips.single.muted, isFalse);
      expect(tester.widget<Switch>(_k('gallery_autoplay')).value, isFalse);
    });

    testWidgets('turning it on in the viewer is remembered, and starts a paused video muted right away; turning it off is remembered too', (tester) async {
      final w = await _open(tester, _asset(_dropbox));
      await tester.tap(_k('gallery_autoplay'));
      await tester.pumpAndSettle();
      expect((await SharedPreferences.getInstance()).getBool('marketing.gallery.autoplay'), isTrue);
      expect(w.clips.single.playing, isTrue);
      expect(w.clips.single.muted, isTrue);
      await tester.tap(_k('viewer_play')); // pause it
      await tester.pumpAndSettle();
      await tester.tap(_k('gallery_autoplay')); // off
      await tester.pumpAndSettle();
      expect((await SharedPreferences.getInstance()).getBool('marketing.gallery.autoplay'), isFalse);
      expect(w.clips.single.playing, isFalse, reason: 'turning it off does not start or stop anything');
    });
  });

  group('what cannot play in the app', () {
    testWidgets('a platform with no player says so in plain words and offers Dropbox; both routes were tried; nothing crashes', (tester) async {
      final w = await _open(tester, _asset(_dropbox), failOpen: true);
      expect(w.clips, hasLength(2), reason: 'the share link as a file, then Dropbox\'s direct host');
      expect(find.textContaining('no built-in video player'), findsOneWidget);
      expect(tester.widget<Text>(_k('viewer_reason')).data, contains('Reason: unsupported'));
      expect(find.text('Open in Dropbox'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a playback error reported after it opened is explained the same way', (tester) async {
      final w = await _open(tester, _asset(_dropbox));
      w.clips.single.failure = 'MEDIA_ERR_SRC_NOT_SUPPORTED';
      w.clips.single.notifyListeners();
      await tester.pumpAndSettle();
      expect(find.textContaining('could not play what came back'), findsOneWidget);
      expect(tester.widget<Text>(_k('viewer_reason')).data, contains('Reason: format'));
      expect(_k('viewer_open'), findsOneWidget);
      expect(_k('viewer_retry'), findsOneWidget);
    });

    testWidgets('when the share link will not stream, Dropbox\'s direct host is tried — and plays', (tester) async {
      final w = await _open(tester, _asset(_dropbox), failFor: (u) => u.host == 'www.dropbox.com', openError: Exception('MEDIA_ERR_NETWORK'));
      expect(w.clips.map((c) => c.uri.host), ['www.dropbox.com', 'dl.dropboxusercontent.com']);
      expect(w.clips.last.uri.queryParameters, {'rlkey': 'KEY'}, reason: 'the direct form carries the key and no dl / raw');
      expect(w.clips.first.disposed, isTrue, reason: 'the route that failed was let go');
      expect(_k('viewer_play'), findsOneWidget);
      expect(_k('viewer_message'), findsNothing);
    });

    testWidgets('a network refusal is explained, with its reason code and every way out', (tester) async {
      await _open(tester, _asset(_dropbox), failOpen: true, openError: Exception('MEDIA_ERR_NETWORK'));
      expect(find.textContaining('Dropbox did not send the video'), findsOneWidget);
      expect(tester.widget<Text>(_k('viewer_reason')).data, contains('Reason: network'));
      expect(find.textContaining('Exception'), findsNothing, reason: 'never the raw error');
      for (final k in ['viewer_retry', 'viewer_newtab', 'viewer_open']) {
        expect(_k(k), findsOneWidget, reason: k);
      }
    });

    testWidgets('Try again opens it once more — and plays when the link now answers', (tester) async {
      var failing = true;
      final w = await _open(tester, _asset(_dropbox), failFor: (_) => failing, openError: Exception('MEDIA_ERR_NETWORK'));
      expect(find.textContaining('Dropbox did not send the video'), findsOneWidget);
      failing = false;
      await tester.tap(_k('viewer_retry'));
      await tester.pumpAndSettle();
      expect(_k('viewer_message'), findsNothing);
      expect(_k('viewer_play'), findsOneWidget);
      expect(w.clips.last.ready, isTrue);
    });

    testWidgets('a browser that holds the autoplay back is not a broken file: the player waits, paused, for Play', (tester) async {
      final w = await _open(tester, _asset(_dropbox), autoplay: true, failPlays: 1);
      expect(_k('viewer_message'), findsNothing, reason: 'no failure message');
      expect(w.clips.single.playing, isFalse);
      expect(_k('viewer_play'), findsOneWidget);
      await tester.tap(_k('viewer_play'));
      await tester.pumpAndSettle();
      expect(w.clips.single.playing, isTrue);
    });

    testWidgets('a playable link always offers "Play in a new tab" (the browser\'s own player), and Open in Dropbox', (tester) async {
      await _open(tester, _asset(_dropbox));
      expect(_k('viewer_newtab'), findsOneWidget);
      expect(_k('viewer_open'), findsOneWidget);
      expect(_k('viewer_retry'), findsNothing, reason: 'nothing to retry while it plays');
    });

    testWidgets('a link that cannot play in the app has no "new tab" player button', (tester) async {
      await _open(tester, _asset('https://drive.google.com/file/d/abc/view'));
      expect(_k('viewer_newtab'), findsNothing);
    });

    testWidgets('a Dropbox folder: no player is created; it opens as a folder (what is inside — dropbox_folder_view.dart), Open in Dropbox there', (tester) async {
      final w = await _open(tester, _asset('https://www.dropbox.com/scl/fo/abc/Reels?rlkey=K&dl=0', media: 'video'));
      expect(w.clips, isEmpty);
      expect(_k('folder_view'), findsOneWidget);
      expect(_k('folder_open'), findsOneWidget);
      expect(_k('folder_zip'), findsOneWidget, reason: 'all of it as one .zip');
      expect(_k('gallery_autoplay'), findsNothing);
    });

    for (final c in [
      ('a Dropbox file that is not a video', 'https://www.dropbox.com/s/a/Deck.pdf?dl=0', 'document', 'opens in Dropbox'),
      ('a Dropbox video the app cannot play (mkv)', 'https://www.dropbox.com/s/a/Footage.mkv?dl=0', 'video', 'mp4, mov, m4v, webm'),
      ('a Drive link', 'https://drive.google.com/file/d/abc/view', 'video', 'cannot play this link itself'),
    ]) {
      testWidgets('${c.$1}: no player is created, it says how it opens, and Open is there', (tester) async {
        final w = await _open(tester, _asset(c.$2, media: c.$3));
        expect(w.clips, isEmpty);
        expect(find.textContaining(c.$4), findsOneWidget);
        expect(_k('viewer_open'), findsOneWidget);
        expect(_k('gallery_autoplay'), findsNothing, reason: 'autoplay only matters for a video that can play');
      });
    }

    testWidgets('a video link saved with the Type "Still" (counted as a photo) still plays in the app — the link decides, not the Type', (tester) async {
      final w = await _open(tester, _asset(_dropbox, media: 'image', kind: 'still'));
      expect(w.clips, hasLength(1), reason: 'a player is made for the video link');
      expect(_k('viewer_play'), findsOneWidget);
      expect(_k('gallery_autoplay'), findsOneWidget);
    });

    testWidgets('and with autoplay on, that same asset opens playing, muted', (tester) async {
      final w = await _open(tester, _asset(_dropbox, media: 'image', kind: 'still'), autoplay: true);
      expect(w.clips.single.playing, isTrue);
      expect(w.clips.single.muted, isTrue);
    });

    testWidgets('an image asset shows its picture area and no message', (tester) async {
      final w = await _open(tester, _asset('https://cdn.example.com/still.jpg', media: 'image', kind: 'still'));
      expect(w.clips, isEmpty);
      expect(_k('viewer_message'), findsNothing);
      expect(_k('viewer_open'), findsOneWidget);
      expect(find.text('Open file'), findsOneWidget);
    });
  });

  group('the asset form and a video link', () {
    Future<_FakeSocials> openForm(WidgetTester tester, {Asset? asset}) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1280, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final fake = _FakeSocials([]);
      await tester.pumpWidget(ProviderScope(
        overrides: [marketingSocialsServiceProvider.overrideWithValue(fake), marketingTeamServiceProvider.overrideWithValue(_NoTeam())],
        child: MaterialApp(theme: AppTheme.lightTheme, home: Scaffold(body: Consumer(builder: (context, ref, _) => Center(child: ElevatedButton(key: const Key('open_form'), onPressed: () => showAssetEditor(context, ref, asset: asset), child: const Text('form')))))),
      ));
      await tester.tap(_k('open_form'));
      await tester.pumpAndSettle();
      return fake;
    }

    String kindShown(WidgetTester t) => t.widget<DropdownButtonFormField<String>>(_k('asset_kind')).initialValue!;

    testWidgets('a new asset starts as a Still; pasting a Dropbox video link makes it a Reel and says it plays in the app', (tester) async {
      await openForm(tester);
      expect(kindShown(tester), 'still');
      expect(_k('asset_link_hint'), findsNothing);
      await tester.enterText(_k('asset_url'), _dropbox);
      await tester.pumpAndSettle();
      expect(kindShown(tester), 'reel');
      expect(find.text('This is a video file — it plays in the app.'), findsOneWidget);
    });

    testWidgets('a link that is not a playable video changes nothing', (tester) async {
      await openForm(tester);
      await tester.enterText(_k('asset_url'), 'https://drive.google.com/file/d/abc/view');
      await tester.pumpAndSettle();
      expect(kindShown(tester), 'still');
      expect(_k('asset_link_hint'), findsNothing);
    });

    testWidgets('saving sends the Reel type, so the asset counts as a video', (tester) async {
      final fake = await openForm(tester);
      await tester.enterText(_k('asset_title'), 'Vodcast');
      await tester.enterText(_k('asset_url'), _dropbox);
      await tester.pumpAndSettle();
      await tester.tap(_k('asset_save'));
      await tester.pumpAndSettle();
      expect(fake.saved.single['kind'], 'reel');
      expect(fake.saved.single['url'], _dropbox);
    });

    testWidgets('a Type the person picked is not changed behind their back — they get a hint instead', (tester) async {
      await openForm(tester);
      await tester.tap(_k('asset_kind'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Still').last);
      await tester.pumpAndSettle();
      await tester.enterText(_k('asset_url'), _dropbox);
      await tester.pumpAndSettle();
      expect(kindShown(tester), 'still');
      expect(find.textContaining('set the Type to Reel, Film or BTS'), findsOneWidget);
    });

    testWidgets('an existing asset typed as a Still gets the hint, and picking Film clears it', (tester) async {
      await openForm(tester, asset: _asset(_dropbox, media: 'image', kind: 'still'));
      expect(kindShown(tester), 'still');
      expect(find.textContaining('set the Type to Reel, Film or BTS'), findsOneWidget);
      await tester.tap(_k('asset_kind'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Film').last);
      await tester.pumpAndSettle();
      expect(kindShown(tester), 'film');
      expect(find.text('This is a video file — it plays in the app.'), findsOneWidget);
    });
  });

  group('autoplay previews in the grid', () {
    Asset video(String id) => _asset(_dropbox, id: id);

    Future<({List<_FakeClip> clips, ProviderContainer container})> grid(WidgetTester tester, Widget child, {bool autoplay = true, Size size = const Size(1280, 900), bool failOpen = false}) async {
      SharedPreferences.setMockInitialValues({if (autoplay) 'marketing.gallery.autoplay': true});
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final clips = <_FakeClip>[];
      final container = ProviderContainer(overrides: [
        mediaStreamServiceProvider.overrideWithValue(NoMediaStream()), clipPlayerFactoryProvider.overrideWithValue((u) {
          final c = _FakeClip(u, failOpen: failOpen);
          clips.add(c);
          return c;
        }),
      ]);
      addTearDown(container.dispose);
      container.read(galleryAutoplayProvider);
      await tester.pumpWidget(UncontrolledProviderScope(container: container, child: MaterialApp(theme: AppTheme.lightTheme, home: Scaffold(body: child))));
      await tester.pump(const Duration(milliseconds: 50)); // the saved choice loads
      await tester.pumpAndSettle();
      return (clips: clips, container: container);
    }

    Widget scrolling(List<Asset> assets) => SingleChildScrollView(child: AssetGrid(items: assets));

    test('the pool gives places in the order cards came on screen; a place that is let go passes to the next', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final pool = c.read(cardPreviewPoolProvider.notifier);
      for (final id in ['a', 'b', 'c', 'd']) {
        pool.want(id);
      }
      pool.want('a'); // twice is once
      expect(c.read(cardPreviewPoolProvider), ['a', 'b', 'c', 'd']);
      expect([for (final id in ['a', 'b', 'c', 'd', 'zz']) previewGranted(c.read(cardPreviewPoolProvider), id)], [true, true, true, false, false]);
      pool.drop('b');
      pool.drop('nobody');
      expect(previewGranted(c.read(cardPreviewPoolProvider), 'd'), isTrue, reason: 'the waiting card takes the free place');
      expect(kMaxCardPreviews, 3);
    });

    testWidgets('off to begin with: no player is made for a playable card, and it wears the badge', (tester) async {
      final w = await grid(tester, scrolling([video('v1')]), autoplay: false);
      expect(w.clips, isEmpty);
      expect(find.descendant(of: _k('asset_v1'), matching: _k('asset_play_badge')), findsOneWidget);
      expect(_k('asset_preview'), findsNothing);
    });

    testWidgets('on: a playable card plays a muted, looping preview in place, and the badge steps aside', (tester) async {
      final w = await grid(tester, scrolling([video('v1')]));
      expect(w.clips, hasLength(1));
      expect(w.clips.single.playing, isTrue);
      expect(w.clips.single.muted, isTrue, reason: 'a browser only lets a muted video start by itself');
      expect(w.clips.single.looping, isTrue);
      expect(find.descendant(of: _k('asset_v1'), matching: _k('asset_preview')), findsOneWidget);
      expect(find.descendant(of: _k('asset_v1'), matching: _k('asset_play_badge')), findsNothing);
    });

    testWidgets('turning Autoplay off stops every preview, lets go of the players and brings the badge back', (tester) async {
      final w = await grid(tester, scrolling([video('v1'), video('v2')]));
      expect(w.clips, hasLength(2));
      await w.container.read(galleryAutoplayProvider.notifier).set(false);
      await tester.pumpAndSettle();
      expect(w.clips.every((c) => c.disposed), isTrue);
      expect(_k('asset_preview'), findsNothing);
      expect(find.byKey(const Key('asset_play_badge')), findsNWidgets(2));
    });

    testWidgets('at most three play at once; the others wait as stills', (tester) async {
      final w = await grid(tester, scrolling([for (var i = 1; i <= 6; i++) video('v$i')]));
      expect(w.clips, hasLength(kMaxCardPreviews));
      expect(w.clips.every((c) => c.playing), isTrue);
      expect(find.byKey(const Key('asset_preview')), findsNWidgets(kMaxCardPreviews));
      expect(find.byKey(const Key('asset_play_badge')), findsNWidgets(3));
    });

    testWidgets('a card that is removed gives its place to a waiting card', (tester) async {
      final items = ValueNotifier<List<Asset>>([for (var i = 1; i <= 4; i++) video('v$i')]);
      addTearDown(items.dispose);
      final w = await grid(tester, SingleChildScrollView(child: ValueListenableBuilder<List<Asset>>(valueListenable: items, builder: (_, list, _) => AssetGrid(items: list))));
      expect(w.clips, hasLength(3));
      expect(find.descendant(of: _k('asset_v4'), matching: _k('asset_preview')), findsNothing);
      items.value = [video('v2'), video('v3'), video('v4')]; // v1 is gone
      await tester.pumpAndSettle();
      expect(find.descendant(of: _k('asset_v4'), matching: _k('asset_preview')), findsOneWidget);
      expect(w.clips.where((c) => c.disposed), hasLength(1));
    });

    testWidgets('cards that cannot play in the app never make a player', (tester) async {
      final w = await grid(tester, scrolling([_asset('https://cdn.example.com/still.jpg', id: 'i1', media: 'image', kind: 'still'), _asset('https://drive.google.com/file/d/abc/view', id: 'd1'), _asset('https://www.dropbox.com/s/a/Deck.pdf?dl=0', id: 'p1', media: 'document', kind: 'document'), _asset('https://www.dropbox.com/scl/fo/abc/Reels?rlkey=K&dl=0', id: 'f1')]));
      expect(w.clips, isEmpty);
      expect(find.byKey(const Key('asset_play_badge')), findsNothing);
    });

    testWidgets('a preview only loops the first eight seconds', (tester) async {
      final w = await grid(tester, scrolling([video('v1')]));
      w.clips.single.pos = const Duration(seconds: 3);
      w.clips.single.notifyListeners();
      expect(w.clips.single.seeks, isEmpty);
      w.clips.single.pos = kPreviewLength + const Duration(milliseconds: 200);
      w.clips.single.notifyListeners();
      await tester.pump();
      expect(w.clips.single.seeks, [Duration.zero]);
    });

    testWidgets('only a card on screen plays: scrolled out of view it waits, scrolled in it starts, scrolled away again it lets go', (tester) async {
      final w = await grid(tester, SingleChildScrollView(child: Column(children: [const SizedBox(height: 1200), AssetGrid(items: [video('v1')]), const SizedBox(height: 600)])), size: const Size(1280, 700));
      expect(w.clips, isEmpty, reason: 'it is below the fold');
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -800));
      await tester.pumpAndSettle();
      expect(w.clips, hasLength(1));
      expect(w.clips.single.playing, isTrue);
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, 800));
      await tester.pumpAndSettle();
      expect(w.clips.single.disposed, isTrue);
      expect(_k('asset_preview'), findsNothing);
    });

    testWidgets('a player that will not open leaves the card a still, hands its place on, and nothing crashes', (tester) async {
      final w = await grid(tester, scrolling([for (var i = 1; i <= 4; i++) video('v$i')]), failOpen: true);
      expect(tester.takeException(), isNull);
      expect(w.clips, hasLength(8), reason: 'each card tried both routes — the fourth got a place the failed ones gave up');
      expect(find.byKey(const Key('asset_preview')), findsNothing);
      expect(find.byKey(const Key('asset_play_badge')), findsNWidgets(4));
    });

    testWidgets('a preview whose share link will not stream falls back to the direct host', (tester) async {
      SharedPreferences.setMockInitialValues({'marketing.gallery.autoplay': true});
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final clips = <_FakeClip>[];
      final container = ProviderContainer(overrides: [
        mediaStreamServiceProvider.overrideWithValue(NoMediaStream()), clipPlayerFactoryProvider.overrideWithValue((u) {
          final c = _FakeClip(u, failOpen: u.host == 'www.dropbox.com', openError: Exception('MEDIA_ERR_NETWORK'));
          clips.add(c);
          return c;
        }),
      ]);
      addTearDown(container.dispose);
      container.read(galleryAutoplayProvider);
      await tester.pumpWidget(UncontrolledProviderScope(container: container, child: MaterialApp(theme: AppTheme.lightTheme, home: Scaffold(body: SingleChildScrollView(child: AssetGrid(items: [video('v1')]))))));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();
      expect(clips.map((c) => c.uri.host), ['www.dropbox.com', 'dl.dropboxusercontent.com']);
      expect(clips.last.playing, isTrue);
      expect(find.byKey(const Key('asset_preview')), findsOneWidget);
    });

    testWidgets('tapping a card that is playing a preview still opens the viewer', (tester) async {
      final w = await grid(tester, scrolling([video('v1')]));
      expect(w.clips, hasLength(1));
      await tester.tap(find.descendant(of: _k('asset_v1'), matching: _k('asset_thumb')));
      await tester.pumpAndSettle();
      expect(_k('viewer_title'), findsOneWidget);
      expect(w.clips, hasLength(2), reason: 'the viewer makes its own player');
    });

    testWidgets('the grid with previews on fits a 390-wide screen without overflow', (tester) async {
      await grid(tester, scrolling([for (var i = 1; i <= 4; i++) video('v$i')]), size: const Size(390, 800));
      expect(tester.takeException(), isNull);
    });
  });

  group('a phone', () {
    testWidgets('the viewer fits a 390-wide screen without overflow, playing or not', (tester) async {
      await _open(tester, _asset(_dropbox), autoplay: true, size: const Size(390, 800));
      expect(tester.takeException(), isNull);
      expect(_k('viewer_seek'), findsOneWidget);
      expect(_k('gallery_autoplay'), findsOneWidget);
    });
  });

  group('in the Gallery', () {
    Future<_FakeSocials> pumpCards(WidgetTester tester, List<Asset> assets, {Size size = const Size(1280, 900)}) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final clips = <_FakeClip>[];
      final fake = _FakeSocials(clips);
      await tester.pumpWidget(ProviderScope(
        overrides: [marketingSocialsServiceProvider.overrideWithValue(fake), marketingTeamServiceProvider.overrideWithValue(_NoTeam()), mediaStreamServiceProvider.overrideWithValue(NoMediaStream()), clipPlayerFactoryProvider.overrideWithValue((u) {
          final c = _FakeClip(u);
          clips.add(c);
          return c;
        })],
        child: MaterialApp(theme: AppTheme.lightTheme, home: Scaffold(body: SingleChildScrollView(child: AssetGrid(items: assets)))),
      ));
      await tester.pumpAndSettle();
      return fake;
    }

    Future<void> pumpTab(WidgetTester tester, Widget tab, {Map<String, Object> saved = const {}, Size size = const Size(1280, 1400)}) async {
      SharedPreferences.setMockInitialValues(saved);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final clips = <_FakeClip>[];
      await tester.pumpWidget(ProviderScope(
        overrides: [marketingSocialsServiceProvider.overrideWithValue(_FakeSocials(clips)), marketingTeamServiceProvider.overrideWithValue(_NoTeam()), mediaStreamServiceProvider.overrideWithValue(NoMediaStream()), clipPlayerFactoryProvider.overrideWithValue((u) => _FakeClip(u))],
        child: MaterialApp(theme: AppTheme.lightTheme, home: Scaffold(body: tab)),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('the Creative Portfolio Gallery has the Autoplay switch, off to begin with; turning it on is remembered on this device', (tester) async {
      await pumpTab(tester, const PortfolioGalleryTab());
      expect(find.text('Autoplay previews'), findsOneWidget);
      expect(tester.widget<Switch>(_k('gallery_autoplay')).value, isFalse);
      await tester.tap(_k('gallery_autoplay'));
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(_k('gallery_autoplay')).value, isTrue);
      expect((await SharedPreferences.getInstance()).getBool('marketing.gallery.autoplay'), isTrue);
    });

    testWidgets('a viewer who turned it on earlier finds it on when the Gallery opens (their own setting, per device)', (tester) async {
      await pumpTab(tester, const PortfolioGalleryTab(), saved: {'marketing.gallery.autoplay': true});
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.widget<Switch>(_k('gallery_autoplay')).value, isTrue);
    });

    testWidgets('Socials → Content & Assets has the same switch, and it is the same setting', (tester) async {
      await pumpTab(tester, const SocialsAssetsTab());
      expect(_k('gallery_autoplay'), findsOneWidget);
      await tester.tap(_k('gallery_autoplay'));
      await tester.pumpAndSettle();
      expect((await SharedPreferences.getInstance()).getBool('marketing.gallery.autoplay'), isTrue);
    });

    testWidgets('both tabs fit a 390-wide screen without overflow with the switch in place', (tester) async {
      await pumpTab(tester, const PortfolioGalleryTab(), size: const Size(390, 2400));
      expect(tester.takeException(), isNull);
      await pumpTab(tester, const SocialsAssetsTab(), size: const Size(390, 2400));
      expect(tester.takeException(), isNull);
    });

    testWidgets('opening a Dropbox video from the Gallery card plays it in the app and keeps "Open file" for the original link', (tester) async {
      await pumpTab(tester, const SocialsAssetsTab());
      expect(find.descendant(of: _k('asset_v1'), matching: _k('asset_play_badge')), findsOneWidget);
      await tester.tap(find.descendant(of: _k('asset_v1'), matching: _k('asset_thumb')));
      await tester.pumpAndSettle();
      expect(_k('viewer_play'), findsOneWidget);
      await tester.tap(_k('viewer_close'));
      await tester.pumpAndSettle();
      await tester.tap(_k('asset_menu_v1'));
      await tester.pumpAndSettle();
      expect(find.text('Open file'), findsOneWidget);
    });

    testWidgets('a video link typed as a Still still wears the play badge and opens the player from its card', (tester) async {
      final fake = await pumpCards(tester, [_asset(_dropbox, id: 's1', media: 'image', kind: 'still')]);
      expect(find.descendant(of: _k('asset_s1'), matching: _k('asset_play_badge')), findsOneWidget);
      await tester.tap(find.descendant(of: _k('asset_s1'), matching: _k('asset_thumb')));
      await tester.pumpAndSettle();
      expect(_k('viewer_play'), findsOneWidget);
      expect(fake.clips, hasLength(1));
    });

    testWidgets('a card of a playable video wears a play badge; others do not; tapping the picture opens the viewer', (tester) async {
      final fake = await pumpCards(tester, [_asset(_dropbox, id: 'v1'), _asset('https://www.dropbox.com/s/a/Deck.pdf?dl=0', id: 'd1', media: 'document', kind: 'document')]);
      expect(find.descendant(of: _k('asset_v1'), matching: _k('asset_play_badge')), findsOneWidget);
      expect(find.descendant(of: _k('asset_d1'), matching: _k('asset_play_badge')), findsNothing);
      await tester.tap(find.descendant(of: _k('asset_v1'), matching: _k('asset_thumb')));
      await tester.pumpAndSettle();
      expect(_k('viewer_title'), findsOneWidget);
      expect(fake.clips, hasLength(1));
    });
  });

  group('through our own server (it fetches the Dropbox file, with the right type, and keeps a copy)', () {
    const relay = 'https://api.test/api/marketing/media/stream/T0K.SIG';

    testWidgets('a Dropbox video plays from the server\'s stream first; whether Dropbox will send it is asked once', (tester) async {
      final stream = _Stream(const MediaStreamLink(url: relay));
      final w = await _open(tester, _asset(_dropbox), stream: stream);
      expect(stream.asks, [(_dropbox, true)], reason: 'the original link, with the probe');
      expect(w.clips.map((c) => c.uri.toString()), [relay], reason: 'it opened: Dropbox itself was not needed');
      expect(_k('viewer_play'), findsOneWidget);
    });

    testWidgets('when the server\'s stream will not open, Dropbox\'s own routes are tried next — and play', (tester) async {
      final w = await _open(tester, _asset(_dropbox), stream: _Stream(const MediaStreamLink(url: relay)), failFor: (u) => u.host == 'api.test', openError: Exception('MEDIA_ERR_SRC_NOT_SUPPORTED'));
      expect(w.clips.map((c) => c.uri.host), ['api.test', 'www.dropbox.com']);
      expect(w.clips.first.disposed, isTrue);
      expect(_k('viewer_play'), findsOneWidget);
    });

    testWidgets('Dropbox paused the link: it says why at once, makes no player, and Try again asks again', (tester) async {
      final stream = _Stream(const MediaStreamLink(ok: false, code: 'limit', message: 'Dropbox has paused this link for now because it was opened too often.'));
      final w = await _open(tester, _asset(_dropbox), stream: stream);
      expect(w.clips, isEmpty, reason: 'no point trying: Dropbox would refuse the player too');
      expect(tester.widget<Text>(_k('viewer_message')).data, 'Dropbox has paused this link for now because it was opened too often.');
      expect(tester.widget<Text>(_k('viewer_reason')).data, contains('dropbox_limit'));
      expect(_k('viewer_open'), findsOneWidget, reason: 'Open in Dropbox stays');
      stream.answer = const MediaStreamLink(url: relay);
      await tester.tap(_k('viewer_retry'));
      await tester.pumpAndSettle();
      expect(stream.asks, hasLength(2));
      expect(w.clips.map((c) => c.uri.toString()), [relay]);
      expect(_k('viewer_message'), findsNothing);
    });

    testWidgets('the server could not reach Dropbox: this device tries Dropbox itself', (tester) async {
      final w = await _open(tester, _asset(_dropbox), stream: _Stream(const MediaStreamLink(ok: false, code: 'unreachable', message: 'x', retryDirect: true)));
      expect(w.clips.map((c) => c.uri.host), ['www.dropbox.com']);
      expect(_k('viewer_play'), findsOneWidget);
    });

    testWidgets('a link that is not on Dropbox never asks the server', (tester) async {
      final stream = _Stream(const MediaStreamLink(url: relay));
      final w = await _open(tester, _asset('https://cdn.example.com/reel.mp4'), stream: stream);
      expect(stream.asks, isEmpty);
      expect(w.clips.map((c) => c.uri.toString()), ['https://cdn.example.com/reel.mp4']);
    });

    testWidgets('a grid preview streams from the server too (no probe — a card only needs the address)', (tester) async {
      SharedPreferences.setMockInitialValues({'marketing.gallery.autoplay': true});
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final clips = <_FakeClip>[];
      final stream = _Stream(const MediaStreamLink(url: relay));
      final container = ProviderContainer(overrides: [
        mediaStreamServiceProvider.overrideWithValue(stream),
        clipPlayerFactoryProvider.overrideWithValue((u) {
          final c = _FakeClip(u);
          clips.add(c);
          return c;
        }),
      ]);
      addTearDown(container.dispose);
      container.read(galleryAutoplayProvider);
      await tester.pumpWidget(UncontrolledProviderScope(container: container, child: MaterialApp(theme: AppTheme.lightTheme, home: Scaffold(body: SingleChildScrollView(child: AssetGrid(items: [_asset(_dropbox, id: 'v1')]))))));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();
      expect(stream.asks, [(_dropbox, false)]);
      expect(clips.map((c) => c.uri.toString()), [relay]);
      expect(clips.single.playing, isTrue);
      expect(find.byKey(const Key('asset_preview')), findsOneWidget);
    });
  });
}

/// The server's relay, as a test sets it: what it answers, and what it was asked.
class _Stream extends MediaStreamService {
  _Stream(this.answer) : super(null);
  MediaStreamLink? answer;
  final asks = <(String, bool)>[];
  @override
  Future<MediaStreamLink?> link(String url, {bool probe = false, String path = ''}) async {
    asks.add((url, probe));
    return answer;
  }
}

class _FakeSocials extends MarketingSocialsService {
  _FakeSocials(this.clips) : super(Dio());
  final List<_FakeClip> clips;
  final saved = <Map<String, dynamic>>[];

  @override
  Future<Asset> saveAsset(Map<String, dynamic> body, {String? id}) async {
    saved.add(body);
    return Asset.fromJson({'id': id ?? 'new', ...body});
  }

  @override
  Future<AssetPage> searchAssets(AssetSearch s, {int pageNo = 1, int limit = kGalleryPageSize}) async => AssetPage.fromJson({..._library(), 'total': 1});

  @override
  Future<AssetList> assets(AssetQuery q) async => AssetList.fromJson(_library());

  Map<String, dynamic> _library() => ({
        'items': [
          {'id': 'v1', 'title': 'Bridal Reel', 'brand': 'main', 'kind': 'reel', 'media': 'video', 'stage': 'approved', 'url': _dropbox, 'thumbUrl': '', 'portfolio': 'Main (Company)', 'page': 'Bridal Makeup', 'tags': [], 'durationSec': 42, 'sizeMb': 0, 'isFinal': false},
        ],
        'counts': {'total': 1, 'photos': 0, 'videos': 1, 'finals': 0, 'approved': 1, 'approvedPct': 100, 'postProducedPct': 0},
        'facets': {'portfolios': {'Main (Company)': 1}, 'pages': {'Bridal Makeup': 1}, 'stages': {'approved': 1}, 'media': {'video': 1}, 'kinds': {}},
      });
}

class _NoTeam extends MarketingTeamService {
  _NoTeam() : super(Dio());
  @override
  Future<LogSetup> logSetup({required String date, String? memberId}) async => throw Exception('no team in this test');
}
