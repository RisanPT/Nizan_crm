import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/features/marketing/data/socials_models.dart';
import 'package:nizan_crm/features/marketing/presentation/media/clip_player.dart';
import 'package:nizan_crm/features/marketing/presentation/media/gallery_prefs.dart';
import 'package:nizan_crm/features/marketing/presentation/media/media_link.dart';
import 'package:nizan_crm/features/marketing/presentation/media/media_stream.dart';
import 'package:nizan_crm/features/marketing/presentation/socials/socials_widgets.dart' show AssetThumb;

// "Autoplay previews" in the Gallery GRID. When the viewer has it on, a card whose link the app can play (a Dropbox video file) plays a
// muted, looping preview in place of its picture. It streams through our server first (which keeps a copy, so Dropbox is not asked for
// the same video again and again — see media_stream.dart), else from Dropbox. Three limits keep that cheap:
//   • only a card that is actually on screen (at least half of it) wants to play,
//   • at most [kMaxCardPreviews] play at the same time — the first ones that came on screen; the rest wait for a free place,
//   • a preview only loops the first [kPreviewLength] of the video, so a 30-minute file is never streamed whole.
// A browser only lets a video start by itself when it is muted, so previews are always muted; opening the card plays it with sound.

const kMaxCardPreviews = 3;
const kPreviewLength = Duration(seconds: 8);

/// The cards that are on screen and want to play, in the order they came on screen. The first [kMaxCardPreviews] get to play.
class CardPreviewPool extends Notifier<List<String>> {
  @override
  List<String> build() => const [];

  void want(String id) {
    if (!state.contains(id)) state = [...state, id];
  }

  void drop(String id) {
    if (state.contains(id)) state = [for (final x in state) if (x != id) x];
  }
}

final cardPreviewPoolProvider = NotifierProvider<CardPreviewPool, List<String>>(CardPreviewPool.new);

/// Whether [id] holds one of the playing places.
bool previewGranted(List<String> wanting, String id) {
  final i = wanting.indexOf(id);
  return i >= 0 && i < kMaxCardPreviews;
}

/// The picture of an asset card: the still tile, with the play badge when the link plays in the app, and — with Autoplay on and a free
/// place — the muted looping preview over it.
class AssetCardPicture extends ConsumerStatefulWidget {
  const AssetCardPicture({super.key, required this.asset, this.height = 130});
  final Asset asset;
  final double height;

  @override
  ConsumerState<AssetCardPicture> createState() => _AssetCardPictureState();
}

class _AssetCardPictureState extends ConsumerState<AssetCardPicture> {
  late final CardPreviewPool _pool;
  ScrollPosition? _position;
  bool _onScreen = false;
  ClipPlayer? _player;
  bool _live = false;
  bool _failed = false;
  bool _opening = false;
  int _session = 0;

  MediaLink get _link => MediaLink.parse(widget.asset.url);
  bool get _eligible => _link.canPlayInline && !_failed;

  @override
  void initState() {
    super.initState();
    _pool = ref.read(cardPreviewPoolProvider.notifier);
    _afterFrame();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final p = Scrollable.maybeOf(context)?.position;
    if (p != _position) {
      _position?.removeListener(_check);
      _position = p;
      _position?.addListener(_check);
    }
  }

  @override
  void didUpdateWidget(covariant AssetCardPicture old) {
    super.didUpdateWidget(old);
    if (old.asset.id != widget.asset.id) {
      // the same widget now shows another asset: let go of the old one's place and start over
      _pool.drop(old.asset.id);
      _onScreen = false;
    }
    if (old.asset.url != widget.asset.url || old.asset.id != widget.asset.id) {
      _stop();
      _failed = false;
    }
    _afterFrame();
  }

  @override
  void dispose() {
    _position?.removeListener(_check);
    _session++;
    _disposePlayer();
    final pool = _pool;
    final id = widget.asset.id;
    // letting go of the place changes provider state: not while the tree is being torn down
    scheduleMicrotask(() {
      try {
        pool.drop(id);
      } catch (_) {
        // the container is already gone
      }
    });
    super.dispose();
  }

  void _afterFrame() => WidgetsBinding.instance.addPostFrameCallback((_) => _check());

  /// Is at least half of this card inside the scrolling area it sits in?
  void _check() {
    if (!mounted) return;
    var visible = false;
    if (_eligible && ref.read(galleryAutoplayProvider)) {
      final box = context.findRenderObject();
      if (box is RenderBox && box.attached && box.hasSize) {
        final scroller = Scrollable.maybeOf(context)?.context.findRenderObject();
        final view = scroller is RenderBox && scroller.attached && scroller.hasSize ? scroller.localToGlobal(Offset.zero) & scroller.size : Offset.zero & MediaQuery.sizeOf(context);
        final mine = box.localToGlobal(Offset.zero) & box.size;
        final seen = mine.intersect(view);
        visible = !seen.isEmpty && seen.height >= mine.height * 0.5;
      }
    }
    _setOnScreen(visible);
  }

  void _setOnScreen(bool v) {
    if (v == _onScreen) return;
    _onScreen = v;
    if (v) {
      _pool.want(widget.asset.id);
    } else {
      _pool.drop(widget.asset.id);
    }
  }

  Future<void> _start() async {
    if (_player != null || _opening || !_eligible || !mounted) return;
    final session = ++_session;
    _opening = true;
    ClipPlayer? p;
    try {
      var urls = _link.playUrls;
      if (_link.isDropbox) {
        final s = await ref.read(mediaStreamServiceProvider).link(_link.original);
        if (!mounted || session != _session) return; // stopped while it was asking
        if (s != null && s.sources.isNotEmpty) urls = [...s.sources, ...urls]; // straight from Dropbox first when it can
      }
      p = await openClip(ref.read(clipPlayerFactoryProvider), urls);
      if (!mounted || session != _session) {
        p.dispose(); // stopped while it was opening
        return;
      }
      await p.setMuted(true);
      await p.setLooping(true);
      if (!mounted || session != _session) {
        p.dispose();
        return;
      }
      _player = p;
      p.addListener(_tick);
      await p.play();
      if (mounted && session == _session) setState(() => _live = true);
    } catch (_) {
      // no player on this platform, or no route would stream: the card just stays a still, and gives its place to another
      if (_player == null) p?.dispose();
      if (session == _session) {
        _disposePlayer();
        _failed = true;
        _setOnScreen(false);
        if (mounted) setState(() => _live = false);
      }
    } finally {
      if (session == _session) _opening = false;
    }
  }

  /// A preview only loops its first seconds.
  void _tick() {
    final p = _player;
    if (p != null && p.position >= kPreviewLength) p.seekTo(Duration.zero);
  }

  void _stop() {
    _session++;
    _opening = false;
    _disposePlayer();
    if (_live) {
      _live = false;
      if (mounted) setState(() {});
    }
  }

  void _disposePlayer() {
    final p = _player;
    _player = null;
    p?.removeListener(_tick);
    p?.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.asset.id;
    ref.listen<bool>(galleryAutoplayProvider, (_, on) {
      if (on) {
        _afterFrame();
      } else {
        _setOnScreen(false);
        _stop();
      }
    });
    ref.listen<bool>(cardPreviewPoolProvider.select((s) => previewGranted(s, id)), (_, granted) {
      if (granted) {
        _start();
      } else {
        _stop();
      }
    });
    final p = _player;
    final showVideo = _live && p != null && p.isReady;
    return Stack(children: [
      AssetThumb(asset: widget.asset, height: widget.height),
      if (showVideo)
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: IgnorePointer(
              child: ColoredBox(
                key: const Key('asset_preview'),
                color: Colors.black,
                child: FittedBox(fit: BoxFit.cover, clipBehavior: Clip.hardEdge, child: SizedBox(width: 160 * p.aspectRatio, height: 160, child: p.buildView())),
              ),
            ),
          ),
        ),
      // a dark disc with a white triangle: this one plays right here (the plain pink tile means it opens elsewhere); hidden while it plays
      if (_link.canPlayInline && !showVideo)
        const Positioned.fill(child: IgnorePointer(child: Center(child: DecoratedBox(key: Key('asset_play_badge'), decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: Padding(padding: EdgeInsets.all(6), child: Icon(Icons.play_arrow_rounded, size: 28, color: Colors.white)))))),
    ]);
  }
}
