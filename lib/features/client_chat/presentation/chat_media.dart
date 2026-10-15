import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/client_chat/data/message.dart';

/// "1:07" for a duration — used by the recorder and the voice bubbles.
String formatClock(Duration d) {
  final m = d.inMinutes;
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

// ── Recording ────────────────────────────────────────────────────────────────

class RecordedVoice {
  final String path; // a file path on mobile, a blob: URL on web
  final Duration duration;
  final String mime;
  final String fileName;
  const RecordedVoice(this.path, this.duration, this.mime, this.fileName);

  /// The recorded audio as bytes, on any platform.
  Future<Uint8List> readBytes() async {
    if (kIsWeb) {
      // On web the recorder hands back a blob: URL; XHR can read it.
      final res = await Dio().get<List<int>>(path,
          options: Options(responseType: ResponseType.bytes));
      return Uint8List.fromList(res.data ?? const []);
    }
    return File(path).readAsBytes();
  }

  Future<void> deleteQuietly() async {
    if (kIsWeb) return;
    try {
      await File(path).delete();
    } catch (_) {/* already gone */}
  }
}

/// Thin wrapper over the `record` plugin. Phones capture mono AAC (.m4a); a
/// browser can't encode AAC in most cases, so on web it falls back to Opus
/// (.webm). The server converts every voice note to MP3 for delivery, so the
/// client's iPhone plays it regardless of how it was recorded.
class VoiceRecorder {
  final AudioRecorder _rec = AudioRecorder();
  DateTime? _startedAt;
  AudioEncoder _encoder = AudioEncoder.aacLc;

  Future<AudioEncoder> _pickEncoder() async {
    if (!kIsWeb) return AudioEncoder.aacLc;
    for (final e in [AudioEncoder.opus, AudioEncoder.aacLc, AudioEncoder.wav]) {
      if (await _rec.isEncoderSupported(e)) return e;
    }
    return AudioEncoder.wav;
  }

  (String mime, String ext) get _format => switch (_encoder) {
        AudioEncoder.aacLc => ('audio/mp4', 'm4a'),
        AudioEncoder.opus => ('audio/webm', 'webm'),
        _ => ('audio/wav', 'wav'),
      };

  /// Starts recording. Returns false if the microphone permission was denied.
  Future<bool> start() async {
    if (!await _rec.hasPermission()) return false;
    _encoder = await _pickEncoder();
    var path = ''; // ignored on web
    if (!kIsWeb) {
      final dir = await getTemporaryDirectory();
      path =
          '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.${_format.$2}';
    }
    await _rec.start(
      RecordConfig(
        encoder: _encoder,
        bitRate: 64000,
        sampleRate: 44100,
        numChannels: 1,
      ),
      path: path,
    );
    _startedAt = DateTime.now();
    return true;
  }

  /// Stops and returns the finished recording (null if nothing was captured).
  Future<RecordedVoice?> stop() async {
    final path = await _rec.stop();
    final started = _startedAt;
    _startedAt = null;
    if (path == null || started == null) return null;
    final (mime, ext) = _format;
    return RecordedVoice(
        path, DateTime.now().difference(started), mime, 'voice.$ext');
  }

  /// Stops and discards the recording.
  Future<void> cancel() async {
    _startedAt = null;
    await _rec.cancel();
  }

  Future<void> dispose() => _rec.dispose();
}

// ── Playback ─────────────────────────────────────────────────────────────────

class ChatAudioState {
  final String? url; // the voice note currently loaded (null = none)
  final bool loading;
  final bool playing;
  final Duration position;
  final Duration duration;

  const ChatAudioState({
    this.url,
    this.loading = false,
    this.playing = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
  });

  ChatAudioState copyWith({
    bool? loading,
    bool? playing,
    Duration? position,
    Duration? duration,
  }) =>
      ChatAudioState(
        url: url,
        loading: loading ?? this.loading,
        playing: playing ?? this.playing,
        position: position ?? this.position,
        duration: duration ?? this.duration,
      );
}

/// One shared player for the whole thread, so starting a voice note stops the
/// previous one. Auto-disposes (and stops playing) when the thread page closes.
class ChatAudioController extends Notifier<ChatAudioState> {
  late final AudioPlayer _player;

  @override
  ChatAudioState build() {
    _player = AudioPlayer();
    final subs = <StreamSubscription<dynamic>>[
      _player.onPlayerStateChanged.listen((s) {
        state = state.copyWith(
          playing: s == PlayerState.playing,
          loading: s == PlayerState.playing ? false : state.loading,
        );
      }),
      _player.onPositionChanged.listen((p) {
        state = state.copyWith(position: p);
      }),
      _player.onDurationChanged.listen((d) {
        state = state.copyWith(duration: d);
      }),
      _player.onPlayerComplete.listen((_) {
        state = state.copyWith(playing: false, position: Duration.zero);
      }),
      // A bad URL / dropped connection surfaces here — reset instead of leaving
      // the bubble stuck on a spinner.
      _player.eventStream.listen((_) {},
          onError: (Object _) => state = const ChatAudioState()),
    ];
    ref.onDispose(() {
      for (final s in subs) {
        s.cancel();
      }
      _player.dispose();
    });
    return const ChatAudioState();
  }

  /// Play / pause the voice note at [url]; switches over if another is playing.
  Future<void> toggle(String url) async {
    if (state.url == url) {
      if (state.playing) {
        await _player.pause();
        return;
      }
      if (state.position > Duration.zero) {
        await _player.resume();
        return;
      }
    }
    state = ChatAudioState(url: url, loading: true);
    try {
      await _player.stop();
      await _player.play(UrlSource(url));
    } catch (_) {
      state = const ChatAudioState();
      rethrow;
    }
  }

  Future<void> seek(String url, Duration to) async {
    if (state.url != url) return;
    await _player.seek(to);
  }
}

final chatAudioProvider =
    NotifierProvider.autoDispose<ChatAudioController, ChatAudioState>(
        ChatAudioController.new);

// ── Bubble widgets ───────────────────────────────────────────────────────────

/// A voice-note bubble body: play/pause, scrubber and elapsed / total time.
/// [onDark] is true when the bubble background is the primary colour.
class AudioMessage extends ConsumerWidget {
  const AudioMessage(
      {super.key, required this.attachment, required this.onDark});
  final ChatAttachment attachment;
  final bool onDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Only the bubble that is actually playing rebuilds on position ticks.
    final active = ref.watch(chatAudioProvider
        .select((s) => s.url == attachment.url ? s : null));
    final fg = onDark ? Colors.white : context.crmColors.textPrimary;
    final playing = active?.playing ?? false;
    final loading = active?.loading ?? false;

    final known = attachment.duration;
    final total = (active != null && active.duration > Duration.zero)
        ? active.duration
        : known;
    final position = active?.position ?? Duration.zero;
    final progress = total.inMilliseconds == 0
        ? 0.0
        : (position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);

    return SizedBox(
      width: 230,
      child: Row(
        children: [
          InkWell(
            customBorder: const CircleBorder(),
            onTap: () async {
              try {
                await ref
                    .read(chatAudioProvider.notifier)
                    .toggle(attachment.url);
              } catch (e) {
                if (context.mounted) {
                  showErrorSnackBar(context, e,
                      fallback: "Couldn't play that voice message.");
                }
              }
            },
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: fg.withValues(alpha: onDark ? 0.22 : 0.08),
              ),
              child: loading
                  ? Padding(
                      padding: const EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: fg),
                    )
                  : Icon(playing ? Icons.pause : Icons.play_arrow,
                      color: fg, size: 22),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 5),
                    overlayShape: SliderComponentShape.noOverlay,
                    activeTrackColor: fg,
                    inactiveTrackColor: fg.withValues(alpha: 0.25),
                    thumbColor: fg,
                  ),
                  child: Slider(
                    value: progress,
                    onChanged: active == null || total == Duration.zero
                        ? null
                        : (v) => ref.read(chatAudioProvider.notifier).seek(
                            attachment.url,
                            Duration(
                                milliseconds:
                                    (v * total.inMilliseconds).round())),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 2),
                  child: Text(
                    playing || position > Duration.zero
                        ? '${formatClock(position)} / ${formatClock(total)}'
                        : formatClock(total),
                    style: TextStyle(
                        fontSize: 11, color: fg.withValues(alpha: 0.75)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A message's photos: one large thumbnail, or a 2-up grid. Click to open full screen.
class ImageAttachments extends StatelessWidget {
  const ImageAttachments({super.key, required this.images});
  final List<ChatAttachment> images;

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) return const SizedBox.shrink();
    final crm = context.crmColors;
    final single = images.length == 1;
    final size = single ? 224.0 : 108.0;
    return Wrap(
      spacing: 3,
      runSpacing: 3,
      children: [
        for (var i = 0; i < images.length; i++)
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                fullscreenDialog: true,
                builder: (_) => ImageViewerPage(
                    urls: [for (final a in images) a.url], initialIndex: i),
              )),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: size,
                  height: size,
                  child: Image.network(
                    images[i].url,
                    fit: BoxFit.cover,
                    loadingBuilder: (_, child, progress) => progress == null
                        ? child
                        : ColoredBox(
                            color: crm.border.withValues(alpha: 0.4),
                            child: const Center(
                                child: SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))),
                          ),
                    errorBuilder: (_, _, _) => ColoredBox(
                      color: crm.border.withValues(alpha: 0.4),
                      child: Center(
                          child: Icon(Icons.broken_image_outlined,
                              color: crm.textSecondary)),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Full-screen, swipeable, pinch-to-zoom photo viewer.
class ImageViewerPage extends StatefulWidget {
  const ImageViewerPage(
      {super.key, required this.urls, this.initialIndex = 0});
  final List<String> urls;
  final int initialIndex;

  @override
  State<ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<ImageViewerPage> {
  late final PageController _pages =
      PageController(initialPage: widget.initialIndex);

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: PageView.builder(
        controller: _pages,
        itemCount: widget.urls.length,
        itemBuilder: (_, i) => InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          child: Center(
            child: Image.network(
              widget.urls[i],
              fit: BoxFit.contain,
              loadingBuilder: (_, child, progress) => progress == null
                  ? child
                  : const Center(
                      child: CircularProgressIndicator(color: Colors.white)),
              errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined,
                  color: Colors.white54, size: 48),
            ),
          ),
        ),
      ),
    );
  }
}
