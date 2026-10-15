import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/client_chat/controllers/chat_api_service.dart';
import 'package:nizan_crm/features/client_chat/controllers/live_client_chat.dart';
import 'package:nizan_crm/features/client_chat/data/conversation.dart';
import 'package:nizan_crm/features/client_chat/data/message.dart';
import 'package:nizan_crm/features/client_chat/presentation/chat_media.dart';

/// Most photos per message (mirrors the server limit) and the longest voice note.
const _maxPhotos = 6;
const _maxVoice = Duration(minutes: 5);
const _minVoice = Duration(seconds: 1);

/// A photo chosen but not yet sent. Bytes are read up front so the preview and
/// the upload both work on web, where there is no file path.
class _PendingPhoto {
  final String name;
  final Uint8List bytes;
  const _PendingPhoto(this.name, this.bytes);
}

/// Pick a MIME type from a picked file's name (XFile.mimeType is often null).
String _imageMime(String name) {
  final ext = name.toLowerCase().split('.').last;
  return switch (ext) {
    'png' => 'image/png',
    'heic' => 'image/heic',
    'heif' => 'image/heif',
    'webp' => 'image/webp',
    'gif' => 'image/gif',
    _ => 'image/jpeg',
  };
}

/// A single concierge chat thread: the full message history with the client,
/// plus a composer for the staff reply. Polls for new client messages every
/// few seconds while open (mirrors the app's 15s notification poll, tighter
/// here because an open chat should feel live).
class ClientChatThreadPage extends ConsumerStatefulWidget {
  const ClientChatThreadPage({super.key, required this.conversationId});
  final String conversationId;

  @override
  ConsumerState<ClientChatThreadPage> createState() =>
      _ClientChatThreadPageState();
}

class _ClientChatThreadPageState extends ConsumerState<ClientChatThreadPage> {
  final _composer = TextEditingController();
  final _scrollCtrl = ScrollController();
  Timer? _pollTimer;

  final _picker = ImagePicker();
  final _voice = VoiceRecorder();
  final List<_PendingPhoto> _pending = []; // photos chosen but not sent yet
  Timer? _recTimer;
  bool _recording = false;
  Duration _recElapsed = Duration.zero;

  ClientConversation? _conversation;
  List<ChatMessage> _messages = const [];
  bool _loading = true;
  Object? _error;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load(initial: true);
    _pollTimer = Timer.periodic(
        const Duration(seconds: 6), (_) => _load(initial: false));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _recTimer?.cancel();
    _voice.dispose();
    _composer.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({required bool initial}) async {
    if (!mounted) return;
    final api = ref.read(clientChatApiServiceProvider);
    try {
      final thread = await api.getThread(widget.conversationId);
      final hadMessages = _messages.length;
      if (!mounted) return;
      setState(() {
        _conversation = thread.conversation;
        _messages = thread.messages;
        _loading = false;
        _error = null;
      });
      // Clear the unread badge for this thread and keep it clear.
      if (initial || thread.conversation.unreadForStaff > 0) {
        await api.markRead(widget.conversationId);
        if (mounted) {
          ref.invalidate(clientChatUnreadProvider);
          ref.invalidate(clientConversationsProvider);
        }
      }
      if (initial || _messages.length != hadMessages) _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      if (initial) {
        setState(() {
          _loading = false;
          _error = e;
        });
      }
      // Non-initial poll errors are transient — keep the current view.
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
      }
    });
  }

  /// Sends the typed text and/or the chosen photos as one reply.
  Future<void> _send() async {
    final text = _composer.text.trim();
    if ((text.isEmpty && _pending.isEmpty) || _sending) return;
    setState(() => _sending = true);
    try {
      final api = ref.read(clientChatApiServiceProvider);
      final ChatMessage msg;
      if (_pending.isEmpty) {
        msg = await api.sendMessage(widget.conversationId, text);
      } else {
        msg = await api.sendMedia(
          widget.conversationId,
          text: text,
          files: [
            for (final p in _pending)
              OutgoingFile(
                  name: p.name, bytes: p.bytes, mime: _imageMime(p.name)),
          ],
        );
      }
      _composer.clear();
      if (!mounted) return;
      setState(() {
        _messages = [..._messages, msg];
        _pending.clear();
        _sending = false;
      });
      _scrollToBottom();
      ref.invalidate(clientConversationsProvider);
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      showErrorSnackBar(context, e);
    }
  }

  // ── Photos ────────────────────────────────────────────────────────────────

  Future<void> _pickPhotos(ImageSource source) async {
    final room = _maxPhotos - _pending.length;
    if (room <= 0) {
      showWarningSnackBar(
          context, 'You can attach up to $_maxPhotos photos at a time.');
      return;
    }
    try {
      final List<XFile> picked;
      if (source == ImageSource.camera) {
        final x = await _picker.pickImage(
            source: source, maxWidth: 1600, imageQuality: 85);
        picked = x == null ? const [] : [x];
      } else {
        picked = await _picker.pickMultiImage(
            maxWidth: 1600, imageQuality: 85, limit: room);
      }
      if (picked.isEmpty) return;
      final photos = <_PendingPhoto>[
        for (final x in picked.take(room))
          _PendingPhoto(x.name, await x.readAsBytes()),
      ];
      if (!mounted) return;
      setState(() => _pending.addAll(photos));
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, e, fallback: "Couldn't open those photos.");
    }
  }

  /// Web has only a file chooser; phones offer camera or library.
  void _onAttach() {
    if (kIsWeb) {
      _pickPhotos(ImageSource.gallery);
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pickPhotos(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from library'),
              onTap: () {
                Navigator.pop(ctx);
                _pickPhotos(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Voice ─────────────────────────────────────────────────────────────────

  Future<void> _startRecording() async {
    if (_sending || _recording) return;
    try {
      if (!await _voice.start()) {
        if (mounted) {
          showWarningSnackBar(
              context,
              kIsWeb
                  ? 'Allow microphone access for this site (lock icon in the '
                      'address bar) to send voice messages.'
                  : 'Allow microphone access in Settings to send voice messages.');
        }
        return;
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, e, fallback: "Couldn't start recording.");
      }
      return;
    }
    if (!mounted) {
      await _voice.cancel();
      return;
    }
    setState(() {
      _recording = true;
      _recElapsed = Duration.zero;
    });
    _recTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _recElapsed += const Duration(seconds: 1));
      if (_recElapsed >= _maxVoice) _finishRecording(); // auto-send at the cap
    });
  }

  Future<void> _cancelRecording() async {
    _recTimer?.cancel();
    await _voice.cancel();
    if (mounted) setState(() => _recording = false);
  }

  Future<void> _finishRecording() async {
    if (!_recording) return;
    _recTimer?.cancel();
    final rec = await _voice.stop();
    if (mounted) setState(() => _recording = false);
    if (rec == null) return;
    if (rec.duration < _minVoice) {
      await rec.deleteQuietly();
      if (mounted) {
        showWarningSnackBar(
            context, 'That was too short — click the mic and speak for a moment.');
      }
      return;
    }
    await _sendVoice(rec);
  }

  Future<void> _sendVoice(RecordedVoice rec) async {
    if (!mounted) return;
    setState(() => _sending = true);
    try {
      final bytes = await rec.readBytes();
      final msg = await ref.read(clientChatApiServiceProvider).sendMedia(
        widget.conversationId,
        files: [OutgoingFile(name: rec.fileName, bytes: bytes, mime: rec.mime)],
        durationMs: rec.duration.inMilliseconds,
      );
      rec.deleteQuietly();
      if (!mounted) return;
      setState(() {
        _messages = [..._messages, msg];
        _sending = false;
      });
      _scrollToBottom();
      ref.invalidate(clientConversationsProvider);
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      // Keep the recording so a flaky connection doesn't cost the reply.
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(friendlyErrorMessage(e)),
          backgroundColor: context.crmColors.destructive,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () => _sendVoice(rec),
          ),
        ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final convo = _conversation;

    return Scaffold(
      backgroundColor: crm.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go('/client-chat'),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              child: Text(
                convo == null ? '?' : _initials(convo.displayName),
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    convo?.displayName ?? 'Client chat',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  if (convo != null && convo.clientPhone.isNotEmpty)
                    Text(
                      convo.clientPhone,
                      style: const TextStyle(fontSize: 11),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? AppErrorView(
                  error: _error,
                  onRetry: () {
                    setState(() => _loading = true);
                    _load(initial: true);
                  },
                )
              : Column(
                  children: [
                    Expanded(child: _buildMessageList(crm)),
                    _buildComposer(crm),
                  ],
                ),
    );
  }

  Widget _buildMessageList(CrmTheme crm) {
    if (_messages.isEmpty) {
      return Center(
        child: Text(
          'No messages yet. Say hello 👋',
          style: TextStyle(color: crm.textSecondary),
        ),
      );
    }
    return SelectionArea(
      child: ListView.builder(
        controller: _scrollCtrl,
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
        itemCount: _messages.length,
        itemBuilder: (context, i) {
          final m = _messages[i];
          final showDateHeader = i == 0 ||
              !_sameDay(_messages[i - 1].createdAt, m.createdAt);
          return Column(
            children: [
              if (showDateHeader) _DateChip(date: m.createdAt),
              _MessageBubble(message: m),
            ],
          );
        },
      ),
    );
  }

  Widget _buildComposer(CrmTheme crm) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
        decoration: BoxDecoration(
          color: crm.surface,
          border: Border(top: BorderSide(color: crm.border)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_pending.isNotEmpty && !_recording) _buildPendingStrip(),
            _recording ? _buildRecordingBar(crm) : _buildInputRow(crm),
          ],
        ),
      ),
    );
  }

  /// Round primary button used for send / mic.
  Widget _roundButton(
    CrmTheme crm, {
    required IconData icon,
    required VoidCallback? onTap,
    String? tooltip,
    bool busy = false,
  }) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: crm.primary,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildInputRow(CrmTheme crm) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        IconButton(
          tooltip: 'Attach photos',
          icon: const Icon(Icons.add_photo_alternate_outlined),
          color: crm.textSecondary,
          onPressed: _sending ? null : _onAttach,
        ),
        Expanded(
          child: TextField(
            controller: _composer,
            minLines: 1,
            maxLines: 5,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              hintText: _pending.isEmpty ? 'Type a reply…' : 'Add a caption…',
              isDense: true,
              filled: true,
              fillColor: crm.background,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: BorderSide(color: crm.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: BorderSide(color: crm.border),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Mic when there's nothing to send, send button otherwise.
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _composer,
          builder: (context, value, _) {
            final canSend =
                value.text.trim().isNotEmpty || _pending.isNotEmpty;
            if (_sending) {
              return _roundButton(crm,
                  icon: Icons.send, onTap: null, busy: true);
            }
            return canSend
                ? _roundButton(crm,
                    icon: Icons.send, onTap: _send, tooltip: 'Send')
                : _roundButton(crm,
                    icon: Icons.mic,
                    onTap: _startRecording,
                    tooltip: 'Record a voice message');
          },
        ),
      ],
    );
  }

  Widget _buildRecordingBar(CrmTheme crm) {
    return Row(
      children: [
        IconButton(
          tooltip: 'Discard',
          icon: const Icon(Icons.delete_outline),
          color: crm.textSecondary,
          onPressed: _cancelRecording,
        ),
        const Icon(Icons.fiber_manual_record,
            color: Color(0xFFD32F2F), size: 14),
        const SizedBox(width: 8),
        Text(formatClock(_recElapsed),
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFeatures: [FontFeature.tabularFigures()])),
        const SizedBox(width: 10),
        Expanded(
          child: Text('Recording… click send when done',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: crm.textSecondary, fontSize: 13)),
        ),
        const SizedBox(width: 8),
        _roundButton(crm,
            icon: Icons.send, onTap: _finishRecording, tooltip: 'Send'),
      ],
    );
  }

  /// Thumbnails of the photos about to be sent, each removable.
  Widget _buildPendingStrip() {
    return SizedBox(
      height: 76,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(8, 0, 0, 8),
        itemCount: _pending.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) => Stack(
          clipBehavior: Clip.none,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(_pending[i].bytes,
                  width: 68, height: 68, fit: BoxFit.cover),
            ),
            Positioned(
              top: -6,
              right: -6,
              child: GestureDetector(
                onTap: () => setState(() => _pending.removeAt(i)),
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                      color: Colors.black87, shape: BoxShape.circle),
                  child: const Icon(Icons.close, size: 14, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;

    if (message.fromSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: crm.border.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              message.text,
              style: TextStyle(fontSize: 11, color: crm.textSecondary),
            ),
          ),
        ),
      );
    }

    final fromStaff = message.fromStaff;
    final bubbleColor = fromStaff ? crm.primary : crm.surface;
    final textColor = fromStaff ? Colors.white : crm.textPrimary;
    final images = message.attachments.where((a) => a.isImage).toList();
    final voice = message.attachments.where((a) => a.isAudio).toList();

    return Align(
      alignment: fromStaff ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.fromLTRB(14, 9, 14, 7),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(fromStaff ? 16 : 4),
            bottomRight: Radius.circular(fromStaff ? 4 : 16),
          ),
          border: fromStaff ? null : Border.all(color: crm.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (images.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(
                    bottom: (message.text.isNotEmpty || voice.isNotEmpty) ? 6 : 0),
                child: ImageAttachments(images: images),
              ),
            for (final a in voice)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: AudioMessage(attachment: a, onDark: fromStaff),
              ),
            if (message.text.isNotEmpty)
              Text(
                message.text,
                style: TextStyle(color: textColor, fontSize: 14, height: 1.3),
              ),
            const SizedBox(height: 2),
            Text(
              _hhmm(message.createdAt),
              style: TextStyle(
                fontSize: 10,
                color: fromStaff
                    ? Colors.white.withValues(alpha: 0.7)
                    : crm.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({required this.date});
  final DateTime? date;

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: crm.border.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          _dateLabel(date),
          style: TextStyle(fontSize: 11, color: crm.textSecondary),
        ),
      ),
    );
  }
}

bool _sameDay(DateTime? a, DateTime? b) =>
    a != null &&
    b != null &&
    a.year == b.year &&
    a.month == b.month &&
    a.day == b.day;

String _hhmm(DateTime? dt) {
  if (dt == null) return '';
  final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final m = dt.minute.toString().padLeft(2, '0');
  final ampm = dt.hour < 12 ? 'AM' : 'PM';
  return '$h:$m $ampm';
}

String _dateLabel(DateTime? dt) {
  if (dt == null) return '';
  final now = DateTime.now();
  if (_sameDay(dt, now)) return 'Today';
  if (_sameDay(dt, now.subtract(const Duration(days: 1)))) return 'Yesterday';
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    final p = parts.first;
    return p.substring(0, p.length >= 2 ? 2 : 1).toUpperCase();
  }
  return (parts.first[0] + parts.last[0]).toUpperCase();
}
