import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/presentation/media/clip_player.dart';
import 'package:nizan_crm/features/marketing/presentation/media/media_stream.dart';

// A DROPBOX FOLDER LINK, opened in the app — what artists send for a work's footage ("Share → Copy link" on a folder). The link alone
// shows nothing here: Dropbox only lists a folder on its own page. So the server reads the folder through its Dropbox app
// (backend /api/marketing/media/folder) and this view lists what is inside — sub-folders, videos, pictures — and plays a video (or shows
// a picture) right here, through the server's relay, one at a time. With no Dropbox app on the server it says so, and the folder still
// opens in Dropbox, or downloads as one .zip.

/// Opens a link outside the app (tests replace it).
final dropboxLinkOpenerProvider = Provider<Future<bool> Function(Uri)>((ref) => (uri) => launchUrl(uri, mode: LaunchMode.externalApplication));

/// The folder [url] in a dialog (full screen on a phone).
Future<void> showDropboxFolder(BuildContext context, {required String url, String title = ''}) {
  final wide = MediaQuery.sizeOf(context).width >= 760;
  final body = DropboxFolderView(url: url, title: title);
  if (wide) return showDialog<void>(context: context, builder: (_) => Dialog(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 860, maxHeight: 760), child: body)));
  return showDialog<void>(context: context, useSafeArea: true, builder: (_) => Dialog.fullscreen(child: body));
}

String _size(int bytes) {
  if (bytes <= 0) return '';
  if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).round().clamp(1, 1 << 30)} MB';
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

class DropboxFolderView extends ConsumerStatefulWidget {
  const DropboxFolderView({super.key, required this.url, this.title = '', this.below});

  /// Shown under the files, in the same scroll (the gallery puts the work the footage is from and its client's review here).
  final Widget? below;

  /// The folder link as it was sent ("Open in Dropbox" opens exactly this).
  final String url;
  final String title;

  @override
  ConsumerState<DropboxFolderView> createState() => _DropboxFolderViewState();
}

class _DropboxFolderViewState extends ConsumerState<DropboxFolderView> {
  /// Where we are inside the folder: '' (its top), '/Stills', …
  String _path = '';
  DropboxFolderListing? _listing;
  bool _loading = true;
  bool _unreachable = false;
  int _session = 0;

  // the file open at the top: a video playing, or a picture
  FolderFile? _open;
  ClipPlayer? _player;
  String? _pictureUrl;
  String? _openProblem;
  bool _opening = false;
  int _clipSession = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _session++;
    _clipSession++;
    _disposePlayer();
    super.dispose();
  }

  Future<void> _load({bool fresh = false}) async {
    final session = ++_session;
    setState(() {
      _loading = true;
      _unreachable = false;
    });
    final l = await ref.read(mediaStreamServiceProvider).folder(widget.url, path: _path, fresh: fresh);
    if (!mounted || session != _session) return;
    setState(() {
      _loading = false;
      _listing = l;
      _unreachable = l == null;
    });
  }

  void _go(String path) {
    _closeFile();
    _path = path;
    _load();
  }

  void _tick() {
    if (mounted) setState(() {});
  }

  void _disposePlayer() {
    final p = _player;
    _player = null;
    p?.removeListener(_tick);
    p?.dispose();
  }

  void _closeFile() {
    _clipSession++;
    _disposePlayer();
    setState(() {
      _open = null;
      _pictureUrl = null;
      _openProblem = null;
      _opening = false;
    });
  }

  /// A file tapped: a video plays here, a picture shows here (through the server); anything else opens in Dropbox.
  Future<void> _openFile(FolderFile f) async {
    if (!f.showable) {
      await ref.read(dropboxLinkOpenerProvider)(Uri.parse(widget.url));
      return;
    }
    final session = ++_clipSession;
    _disposePlayer();
    setState(() {
      _open = f;
      _pictureUrl = null;
      _openProblem = null;
      _opening = true;
    });
    final s = await ref.read(mediaStreamServiceProvider).link(widget.url, path: f.path, probe: true);
    if (!mounted || session != _clipSession) return;
    if (s == null || !s.ok || s.url.isEmpty) {
      setState(() {
        _opening = false;
        _openProblem = (s?.message.isNotEmpty ?? false) ? s!.message : 'The server could not open this file just now. Open the folder in Dropbox.';
      });
      return;
    }
    if (f.media == 'picture') {
      setState(() {
        _opening = false;
        _pictureUrl = s.url;
      });
      return;
    }
    final ClipPlayer p;
    try {
      p = await openClip(ref.read(clipPlayerFactoryProvider), s.sources); // straight from Dropbox first when it can
    } on ClipOpenException catch (e) {
      if (mounted && session == _clipSession) {
        setState(() {
          _opening = false;
          _openProblem = clipFailureText(e.failure);
        });
      }
      return;
    }
    if (!mounted || session != _clipSession) {
      p.dispose();
      return;
    }
    p.addListener(_tick);
    setState(() {
      _opening = false;
      _player = p;
    });
    try {
      await p.play();
    } catch (_) {
      // held back by the browser: it waits, paused, for Play
    }
  }

  String _clock(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  Widget _stage() {
    final f = _open!;
    Widget body;
    if (_opening) {
      body = const AspectRatio(aspectRatio: 16 / 9, child: Center(child: CircularProgressIndicator()));
    } else if (_openProblem != null) {
      body = Padding(padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8), child: Text(_openProblem!, key: const Key('folder_clip_problem'), textAlign: TextAlign.center, style: mktText(12.5, color: Mkt.inkSoft)));
    } else if (_pictureUrl != null) {
      body = ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 420),
        child: Image.network(_pictureUrl!, key: const Key('folder_picture'), fit: BoxFit.contain, errorBuilder: (_, _, _) => Padding(padding: const EdgeInsets.all(18), child: Text('The picture could not be shown — open it in Dropbox.', style: mktText(12.5, color: Mkt.inkSoft)))),
      );
    } else {
      final p = _player;
      final problem = p?.errorText;
      if (p == null || problem != null) {
        body = Padding(padding: const EdgeInsets.all(18), child: Text(problem == null ? '' : clipFailureText(classifyClipError(problem)), key: const Key('folder_clip_problem'), textAlign: TextAlign.center, style: mktText(12.5, color: Mkt.inkSoft)));
      } else {
        body = Column(mainAxisSize: MainAxisSize.min, children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 380),
            child: AspectRatio(
              aspectRatio: p.isReady ? p.aspectRatio : 16 / 9,
              child: Stack(alignment: Alignment.center, children: [
                ColoredBox(key: const Key('folder_player'), color: Colors.black, child: SizedBox.expand(child: p.isReady ? p.buildView() : const SizedBox())),
                GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => p.isPlaying ? p.pause() : p.play()),
                if (!p.isPlaying) const IgnorePointer(child: Icon(Icons.play_circle_fill_rounded, size: 56, color: Colors.white70)),
              ]),
            ),
          ),
          Row(children: [
            IconButton(key: const Key('folder_play'), tooltip: p.isPlaying ? 'Pause' : 'Play', onPressed: () => p.isPlaying ? p.pause() : p.play(), icon: Icon(p.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded)),
            Expanded(
              child: Slider(
                value: p.duration.inMilliseconds == 0 ? 0 : p.position.inMilliseconds.clamp(0, p.duration.inMilliseconds).toDouble(),
                max: p.duration.inMilliseconds == 0 ? 1 : p.duration.inMilliseconds.toDouble(),
                onChanged: (v) => p.seekTo(Duration(milliseconds: v.round())),
              ),
            ),
            Text('${_clock(p.position)} / ${_clock(p.duration)}', style: mktText(11, color: Mkt.inkSoft)),
            IconButton(tooltip: p.isMuted ? 'Unmute' : 'Mute', onPressed: () => p.setMuted(!p.isMuted), icon: Icon(p.isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded)),
          ]),
        ]);
      }
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: Mkt.bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: Mkt.border)),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 4, 0),
          child: Row(children: [
            Icon(f.media == 'picture' ? Icons.image_outlined : Icons.movie_outlined, size: 16, color: Mkt.inkSoft),
            const SizedBox(width: 6),
            Expanded(child: Text(f.name, key: const Key('folder_open_name'), maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(12.5, weight: FontWeight.w700))),
            IconButton(key: const Key('folder_clip_close'), tooltip: 'Close', onPressed: _closeFile, icon: const Icon(Icons.close_rounded, size: 18)),
          ]),
        ),
        ClipRRect(borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)), child: body),
      ]),
    );
  }

  List<(String, String)> get _crumbs {
    final out = <(String, String)>[('Top', '')];
    var at = '';
    for (final seg in _path.split('/').where((s) => s.isNotEmpty)) {
      at = '$at/$seg';
      out.add((seg, at));
    }
    return out;
  }

  Widget _notice(IconData icon, String text, {Key? key, Color color = Mkt.inkSoft}) => Container(
        key: key,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Mkt.tint(color, 0.08), borderRadius: BorderRadius.circular(12)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: mktText(12.5, color: Mkt.ink, height: 1.4))),
        ]),
      );

  Widget _list() {
    final l = _listing;
    if (_loading && l == null) return const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()));
    if (_unreachable || l == null) {
      return _notice(Icons.cloud_off_rounded, 'The folder could not be read from the server just now. Open it in Dropbox, or try again.', key: const Key('folder_message'));
    }
    if (!l.ok) {
      final icon = l.code == 'not_connected' ? Icons.folder_rounded : Icons.lock_outline_rounded;
      return _notice(icon, l.message.isEmpty ? 'Dropbox could not open the folder. Open it in Dropbox.' : l.message, key: const Key('folder_message'), color: l.code == 'not_connected' ? Mkt.blue : Mkt.warn);
    }
    if (l.folders.isEmpty && l.files.isEmpty) return _notice(Icons.folder_open_rounded, 'This folder is empty.', key: const Key('folder_message'));
    final dateFmt = DateFormat('d MMM, h:mm a');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final d in l.folders)
        ListTile(
          key: Key('folder_dir_${d.name}'),
          dense: true,
          leading: const Icon(Icons.folder_rounded, color: Mkt.blue),
          title: Text(d.name, style: mktText(13, weight: FontWeight.w700)),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => _go(d.path),
        ),
      for (final f in l.files)
        ListTile(
          key: Key('folder_file_${f.name}'),
          dense: true,
          selected: _open?.path == f.path,
          selectedTileColor: Mkt.primarySoft,
          leading: Icon(
            f.media == 'video' ? Icons.movie_outlined : (f.media == 'picture' ? Icons.image_outlined : Icons.insert_drive_file_outlined),
            color: f.media == 'video' ? Mkt.pink : (f.media == 'picture' ? Mkt.blue : Mkt.grey),
          ),
          title: Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(13, weight: FontWeight.w600)),
          subtitle: Text([_size(f.size), if (f.modifiedAt != null) dateFmt.format(f.modifiedAt!), if (!f.showable) 'opens in Dropbox'].where((s) => s.isNotEmpty).join(' · '), style: mktText(11, color: Mkt.inkSoft)),
          trailing: Icon(f.showable ? (f.media == 'picture' ? Icons.visibility_outlined : Icons.play_circle_outline_rounded) : Icons.open_in_new_rounded, size: 20, color: f.showable ? Mkt.primary : Mkt.inkSoft),
          onTap: () => _openFile(f),
        ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final l = _listing;
    final zip = (l?.zipUrl.isNotEmpty ?? false) ? l!.zipUrl : dropboxFolderZipUrl(widget.url);
    final crumbs = _crumbs;
    return Material(
      key: const Key('folder_view'),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Mkt.tint(Mkt.blue), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.folder_rounded, color: Mkt.blue, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.title.isEmpty ? 'Dropbox folder' : widget.title, key: const Key('folder_title'), maxLines: 2, overflow: TextOverflow.ellipsis, style: mktText(15, weight: FontWeight.w800)),
                Text((l?.ok ?? false) ? l!.summary : 'Dropbox folder', key: const Key('folder_summary'), style: mktText(11.5, color: Mkt.inkSoft)),
              ]),
            ),
            IconButton(key: const Key('folder_close'), tooltip: 'Close', onPressed: () => Navigator.maybePop(context), icon: const Icon(Icons.close_rounded)),
          ]),
          if (crumbs.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
                for (final (i, (name, path)) in crumbs.indexed) ...[
                  if (i > 0) const Icon(Icons.chevron_right_rounded, size: 16, color: Mkt.inkSoft),
                  TextButton(
                    key: Key('folder_crumb_$i'),
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6), minimumSize: const Size(0, 30), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    onPressed: i == crumbs.length - 1 ? null : () => _go(path),
                    child: Text(name, style: mktText(12, weight: FontWeight.w700, color: i == crumbs.length - 1 ? Mkt.ink : Mkt.primary)),
                  ),
                ],
              ]),
            ),
          const SizedBox(height: 10),
          Flexible(
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (_open != null) _stage(),
                _list(),
                ?widget.below,
              ]),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
            FilledButton.icon(
              key: const Key('folder_open'),
              style: FilledButton.styleFrom(backgroundColor: Mkt.primary),
              onPressed: () => ref.read(dropboxLinkOpenerProvider)(Uri.parse(widget.url)),
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: const Text('Open in Dropbox'),
            ),
            if (zip.isNotEmpty)
              OutlinedButton.icon(
                key: const Key('folder_zip'),
                onPressed: () => ref.read(dropboxLinkOpenerProvider)(Uri.parse(zip)),
                icon: const Icon(Icons.download_rounded, size: 16),
                label: const Text('Download all (.zip)'),
              ),
            if (l?.connected ?? false)
              TextButton.icon(key: const Key('folder_refresh'), onPressed: _loading ? null : () => _load(fresh: true), icon: const Icon(Icons.refresh_rounded, size: 16), label: const Text('Refresh')),
          ]),
        ]),
      ),
    );
  }
}
