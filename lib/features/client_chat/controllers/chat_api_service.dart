import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:nizan_crm/providers/dio_provider.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/client_chat/data/conversation.dart';
import 'package:nizan_crm/features/client_chat/data/message.dart';

/// Messages plus their parent conversation, returned by the thread endpoint.
typedef ChatThread = ({ClientConversation conversation, List<ChatMessage> messages});

/// A photo or voice note waiting to be uploaded with a reply.
class OutgoingFile {
  final String name;
  final Uint8List bytes;
  final String mime; // image/jpeg, audio/mp4, audio/webm, ...
  const OutgoingFile(
      {required this.name, required this.bytes, required this.mime});
}

/// Staff-side client/concierge chat API. Wraps the shared `/api/chat` staff
/// endpoints (behind `protect` + the chat-staff guard on the backend).
class ClientChatApiService {
  final Dio _dio;
  ClientChatApiService(this._dio);

  Future<List<ClientConversation>> getConversations({
    String status = 'all',
    String search = '',
  }) async {
    try {
      final qp = <String, dynamic>{};
      if (status.isNotEmpty && status != 'all') qp['status'] = status;
      if (search.trim().isNotEmpty) qp['search'] = search.trim();
      final res = await _dio.get('/chat/conversations',
          queryParameters: qp.isEmpty ? null : qp);
      return (res.data as List)
          .map((e) => ClientConversation.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppException(e, action: 'load conversations');
    }
  }

  Future<ChatThread> getThread(String conversationId) async {
    try {
      final res = await _dio.get('/chat/conversations/$conversationId/messages');
      final data = res.data as Map<String, dynamic>;
      final convo = ClientConversation.fromJson(
          (data['conversation'] as Map<String, dynamic>?) ?? const {});
      final messages = ((data['messages'] as List?) ?? const [])
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList();
      return (conversation: convo, messages: messages);
    } catch (e) {
      throw AppException(e, action: 'load this chat');
    }
  }

  Future<ChatMessage> sendMessage(String conversationId, String text) async {
    try {
      final res = await _dio.post(
        '/chat/conversations/$conversationId/messages',
        data: {'text': text},
      );
      return ChatMessage.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw AppException(e, action: 'send your message');
    }
  }

  /// Reply with photos and/or one voice note (optionally with text). Sent as
  /// multipart to the same endpoint as plain text; the server stores the files
  /// and returns the finished message. [durationMs] is the voice note's length.
  Future<ChatMessage> sendMedia(
    String conversationId, {
    String text = '',
    required List<OutgoingFile> files,
    int durationMs = 0,
  }) async {
    try {
      final form = FormData();
      if (text.trim().isNotEmpty) {
        form.fields.add(MapEntry('text', text.trim()));
      }
      if (durationMs > 0) {
        form.fields.add(MapEntry('durationMs', '$durationMs'));
      }
      for (final f in files) {
        // The field name must be exactly `files` (multer `.array('files')`).
        form.files.add(MapEntry(
          'files',
          MultipartFile.fromBytes(f.bytes,
              filename: f.name, contentType: DioMediaType.parse(f.mime)),
        ));
      }
      final res = await _dio.post(
        '/chat/conversations/$conversationId/messages',
        data: form,
      );
      return ChatMessage.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      throw AppException(e, action: 'send your attachment');
    }
  }

  Future<void> markRead(String conversationId) async {
    try {
      await _dio.post('/chat/conversations/$conversationId/read');
    } catch (e) {
      throw AppException(e, action: 'update this chat');
    }
  }

  /// Total unread (client → staff) messages across all threads, for the badge.
  /// Non-fatal: a badge that can't load just shows nothing.
  Future<int> getUnreadCount() async {
    try {
      final res = await _dio.get('/chat/unread-count');
      return (res.data?['count'] as num?)?.toInt() ?? 0;
    } on DioException {
      return 0;
    }
  }
}

final clientChatApiServiceProvider = Provider<ClientChatApiService>(
    (ref) => ClientChatApiService(ref.watch(dioProvider)));

// ── Inbox filter + list ──────────────────────────────────────────────────────
class ClientChatFilter {
  final String status; // all | open | closed
  final String search;
  const ClientChatFilter({this.status = 'all', this.search = ''});

  ClientChatFilter copyWith({String? status, String? search}) =>
      ClientChatFilter(
        status: status ?? this.status,
        search: search ?? this.search,
      );

  @override
  bool operator ==(Object other) =>
      other is ClientChatFilter &&
      other.status == status &&
      other.search == search;
  @override
  int get hashCode => Object.hash(status, search);
}

final clientChatFilterProvider =
    StateProvider<ClientChatFilter>((ref) => const ClientChatFilter());

final clientConversationsProvider =
    FutureProvider.autoDispose<List<ClientConversation>>((ref) async {
  final f = ref.watch(clientChatFilterProvider);
  return ref
      .watch(clientChatApiServiceProvider)
      .getConversations(status: f.status, search: f.search);
});
