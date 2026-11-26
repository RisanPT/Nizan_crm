import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:nizan_crm/features/marketing/data/socials_models.dart';
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/presentation/media/clip_player.dart';
import 'package:nizan_crm/features/marketing/presentation/media/dropbox_folder_view.dart';
import 'package:nizan_crm/features/marketing/presentation/media/gallery_prefs.dart';
import 'package:nizan_crm/features/marketing/presentation/media/media_link.dart';
import 'package:nizan_crm/features/marketing/presentation/media/media_stream.dart';
import 'package:nizan_crm/features/marketing/presentation/socials/socials_widgets.dart' show AssetThumb;
import 'package:nizan_crm/features/marketing/presentation/portfolio/work_review_widgets.dart';
import 'package:nizan_crm/features/marketing/presentation/portfolio/artist_quality_tab.dart' show showArtistQuality;

/// Open an asset: a video plays in the app — a Dropbox video through our own server first (it sends Dropbox's file with the right type,
/// keeps a copy, and says why when Dropbox refuses — see media_stream.dart), then straight from Dropbox ([MediaLink]); anything else says how it
/// opens. "Autoplay previews" is this viewer's OWN choice (remembered on this device, off to begin with): when on, a video opens playing,
/// muted, because a browser only lets a video start by itself when it is muted.
Future<void> showAssetViewer(BuildContext context, Asset asset) {
  final wide = MediaQuery.sizeOf(context).width >= 760;
  final body = AssetViewer(asset: asset);
  if (wide) return showDialog<void>(context: context, builder: (_) => Dialog(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 860), child: body)));
  return showDialog<void>(context: context, useSafeArea: true, builder: (_) => Dialog.fullscreen(child: body));
}

/// The "Autoplay previews" switch — one setting for the whole Gallery, per viewer.
class AutoplayToggle extends ConsumerWidget {
  const AutoplayToggle({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(galleryAutoplayProvider);
    return Tooltip(
      message: 'When on, videos play as muted previews in the grid (a few at a time) and open playing. Your own setting.',
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Switch(key: const Key('gallery_autoplay'), value: on, onChanged: (v) => ref.read(galleryAutoplayProvider.notifier).set(v), materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
        Text(compact ? 'Autoplay' : 'Autoplay previews', style: mktText(12, weight: FontWeight.w600)),
      ]),
    );
  }
}

class AssetViewer extends ConsumerStatefulWidget {
  const AssetViewer({super.key, required this.asset});
  final Asset asset;

  @override
  ConsumerState<AssetViewer> createState() => _AssetViewerState();
}

class _AssetViewerState extends ConsumerState<AssetViewer> {
  late final MediaLink _link = MediaLink.parse(widget.asset.url);
  ClipPlayer? _player;
  ClipFailure? _failure;

  /// Dropbox refused the file (the server asked): why, in its words.
  MediaStreamLink? _refused;

  /// The server's stream address, when it gave one ("Play in a new tab" uses it too: it carries the right file type).
  String? _relayUrl;
  int _session = 0;

  /// A link the app can play itself — a video FILE (mp4, mov, m4v, webm) on Dropbox. The link decides, not the Type someone picked: a
  /// video saved as "Still" must still play.
  bool get _playable => _link.canPlayInline;

  /// Why it is not playing: it would not open (every route failed), or the platform reported an error after it opened.
  ClipFailure? get _problem => _failure ?? (_player?.errorText != null ? classifyClipError(_player!.errorText!) : null);

  @override
  void initState() {
    super.initState();
    if (_playable) _open();
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  /// Opens the first route that plays: our server's stream (a Dropbox video), then Dropbox's share link as a file, then its direct host.
  /// When the server finds Dropbox refuses the file (a paused, deleted or private link), it says so at once instead of trying.
  /// Whether it then starts by itself is this viewer's own choice — and it starts muted. A browser that holds the start back is not a
  /// broken file: it just waits, paused, for Play.
  Future<void> _open() async {
    final session = ++_session;
    final old = _player;
    _player = null;
    old?.removeListener(_onTick);
    old?.dispose();
    setState(() {
      _failure = null;
      _refused = null;
    });
    var urls = _link.playUrls;
    if (_link.isDropbox) {
      final s = await ref.read(mediaStreamServiceProvider).link(_link.original, probe: true);
      if (!mounted || session != _session) return;
      if (s != null && !s.ok && !s.retryDirect) {
        setState(() => _refused = s);
        return;
      }
      if (s != null && s.ok && s.url.isNotEmpty) {
        _relayUrl = s.url;
        // straight from Dropbox first (the company's own files), then through the server, then Dropbox's plain routes
        urls = [...s.sources, ...urls];
      }
    }
    final ClipPlayer p;
    try {
      p = await openClip(ref.read(clipPlayerFactoryProvider), urls);
    } on ClipOpenException catch (e) {
      if (mounted && session == _session) {
        setState(() => _failure = e.failure);
      }
      return;
    }
    if (!mounted || session != _session) {
      p.dispose();
      return;
    }
    p.addListener(_onTick);
    setState(() => _player = p);
    if (ref.read(galleryAutoplayProvider)) {
      try {
        await p.setMuted(true);
        await p.play();
      } catch (_) {
        // held back by the browser: paused, with the play button
      }
    }
  }

  void _retry() => _open();

  @override
  void dispose() {
    _session++;
    _player?.removeListener(_onTick);
    _player?.dispose();
    super.dispose();
  }

  Future<void> _openOriginal() => launchUrl(Uri.parse(_link.original), mode: LaunchMode.externalApplication);

  String get _openLabel => _link.isDropbox ? 'Open in Dropbox' : 'Open file';

  String _why() {
    if (_link.isFolder) return 'This is a Dropbox folder — it holds many files, so it opens in Dropbox.';
    if (widget.asset.media != 'video') return widget.asset.media == 'image' ? '' : 'This file opens in ${_link.isDropbox ? 'Dropbox' : 'a new tab'}.';
    if (_link.isDropbox) return 'This Dropbox file is not a video the app can play (mp4, mov, m4v, webm), so it opens in Dropbox.';
    return 'The app cannot play this link itself, so it opens in a new tab.';
  }

  Future<void> _openDirect() => launchUrl(Uri.parse(_relayUrl ?? _link.playUrl!), mode: LaunchMode.externalApplication);

  Widget _stage(BuildContext context) {
    final p = _player;
    final problem = _problem;
    final refused = _refused;
    if (refused != null) {
      return Column(children: [
        AssetThumb(asset: widget.asset, height: 220),
        Padding(padding: const EdgeInsets.only(top: 10), child: Text(refused.message.isEmpty ? 'Dropbox would not send this video.' : refused.message, key: const Key('viewer_message'), textAlign: TextAlign.center, style: mktText(12.5, color: Mkt.inkSoft))),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('Reason: dropbox_${refused.code.isEmpty ? 'refused' : refused.code} · you can try again later, or open it in Dropbox.', key: const Key('viewer_reason'), textAlign: TextAlign.center, style: mktText(11, color: Mkt.inkSoft)),
        ),
      ]);
    }
    if (_playable && problem == null) {
      if (p == null || !p.isReady) return const AspectRatio(aspectRatio: 16 / 9, child: Center(child: CircularProgressIndicator()));
      return AspectRatio(
        aspectRatio: p.aspectRatio,
        child: Stack(alignment: Alignment.center, children: [
          ColoredBox(color: Colors.black, child: SizedBox.expand(child: p.buildView())),
          GestureDetector(key: const Key('viewer_surface'), behavior: HitTestBehavior.opaque, onTap: () => p.isPlaying ? p.pause() : p.play()),
          if (!p.isPlaying) const IgnorePointer(child: Icon(Icons.play_circle_fill_rounded, size: 64, color: Colors.white70)),
        ]),
      );
    }
    final message = problem != null ? clipFailureText(problem) : _why();
    return Column(children: [
      AssetThumb(asset: widget.asset, height: 220),
      if (message.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text(message, key: const Key('viewer_message'), textAlign: TextAlign.center, style: mktText(12.5, color: Mkt.inkSoft))),
      if (problem != null)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('Reason: ${clipFailureCode(problem)} · you can try again, play it in a new tab, or open it in ${_link.isDropbox ? 'Dropbox' : 'its own page'}.', key: const Key('viewer_reason'), textAlign: TextAlign.center, style: mktText(11, color: Mkt.inkSoft)),
        ),
    ]);
  }

  String _clock(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final a = widget.asset;
    // a Dropbox FOLDER (an artist's footage): what is inside, each video playing here (dropbox_folder_view.dart)
    if (_link.isFolder) return DropboxFolderView(url: a.url, title: a.title, below: a.work == null ? null : WorkDetailsPanel(work: a.work!, onArtist: (artist) => showArtistQuality(context, artistKey: artist.key, name: artist.name)));
    final p = _player;
    final live = p != null && _problem == null && p.isReady;
    // turning Autoplay on while a video is open and paused starts it, muted
    ref.listen<bool>(galleryAutoplayProvider, (prev, next) async {
      if (next && prev == false && live && !p.isPlaying) {
        try {
          await p.setMuted(true);
          await p.play();
        } catch (_) {
          // held back by the browser: it stays paused
        }
      }
    });
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(a.title, key: const Key('viewer_title'), maxLines: 2, overflow: TextOverflow.ellipsis, style: mktText(16, weight: FontWeight.w800))),
          IconButton(key: const Key('viewer_close'), tooltip: 'Close', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
        ]),
        const SizedBox(height: 8),
        Flexible(
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _stage(context),
              // the work it came from and the client's review of it; an artist opens their Artist Quality
              if (a.work != null) WorkDetailsPanel(work: a.work!, onArtist: (artist) => showArtistQuality(context, artistKey: artist.key, name: artist.name)),
            ]),
          ),
        ),
        if (live) ...[
          const SizedBox(height: 8),
          Row(children: [
            IconButton(key: const Key('viewer_play'), tooltip: p.isPlaying ? 'Pause' : 'Play', onPressed: () => p.isPlaying ? p.pause() : p.play(), icon: Icon(p.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded)),
            Expanded(
              child: Slider(
                key: const Key('viewer_seek'),
                value: p.duration.inMilliseconds == 0 ? 0 : p.position.inMilliseconds.clamp(0, p.duration.inMilliseconds).toDouble(),
                max: p.duration.inMilliseconds == 0 ? 1 : p.duration.inMilliseconds.toDouble(),
                onChanged: (v) => p.seekTo(Duration(milliseconds: v.round())),
              ),
            ),
            Text('${_clock(p.position)} / ${_clock(p.duration)}', key: const Key('viewer_time'), style: mktText(11, color: Mkt.inkSoft)),
            IconButton(key: const Key('viewer_mute'), tooltip: p.isMuted ? 'Unmute' : 'Mute', onPressed: () => p.setMuted(!p.isMuted), icon: Icon(p.isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded)),
          ]),
        ],
        const SizedBox(height: 4),
        Wrap(spacing: 12, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
          if (_playable) const AutoplayToggle(),
          if (_problem != null || _refused != null) TextButton.icon(key: const Key('viewer_retry'), onPressed: _retry, icon: const Icon(Icons.refresh_rounded, size: 16), label: const Text('Try again')),
          // the browser's own player, on the file itself: plays when the in-app one is held back (an extension, a network rule)
          if (_playable) TextButton.icon(key: const Key('viewer_newtab'), onPressed: _openDirect, icon: const Icon(Icons.open_in_browser_rounded, size: 16), label: const Text('Play in a new tab')),
          TextButton.icon(key: const Key('viewer_open'), onPressed: _openOriginal, icon: const Icon(Icons.open_in_new_rounded, size: 16), label: Text(_openLabel)),
        ]),
      ]),
    );
  }
}
