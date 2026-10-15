/// A single message inside a concierge chat thread.
/// Mirrors the backend `messageView` serializer in `chatController.js`.
class ChatAttachment {
  final String url;
  final String type; // image | audio
  final int durationMs; // voice notes only
  const ChatAttachment(
      {this.url = '', this.type = 'image', this.durationMs = 0});

  bool get isImage => type == 'image';
  bool get isAudio => type == 'audio';
  Duration get duration => Duration(milliseconds: durationMs);

  factory ChatAttachment.fromJson(Map<String, dynamic> j) => ChatAttachment(
        url: (j['url'] ?? '').toString(),
        type: (j['type'] ?? 'image').toString(),
        durationMs: (j['durationMs'] as num?)?.toInt() ?? 0,
      );
}

class ChatMessage {
  final String id;
  final String conversationId;
  final String senderType; // client | staff | system
  final String senderName;
  final String text;
  final List<ChatAttachment> attachments;
  final DateTime? createdAt;
  final DateTime? readByStaffAt;
  final DateTime? readByClientAt;

  const ChatMessage({
    required this.id,
    this.conversationId = '',
    this.senderType = 'client',
    this.senderName = '',
    this.text = '',
    this.attachments = const [],
    this.createdAt,
    this.readByStaffAt,
    this.readByClientAt,
  });

  bool get fromStaff => senderType == 'staff';
  bool get fromSystem => senderType == 'system';

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: (j['_id'] ?? '').toString(),
        conversationId: (j['conversationId'] ?? '').toString(),
        senderType: (j['senderType'] ?? 'client').toString(),
        senderName: (j['senderName'] ?? '').toString(),
        text: (j['text'] ?? '').toString(),
        attachments: ((j['attachments'] as List?) ?? const [])
            .map((e) => ChatAttachment.fromJson(e as Map<String, dynamic>))
            .toList(),
        createdAt:
            DateTime.tryParse((j['createdAt'] ?? '').toString())?.toLocal(),
        readByStaffAt:
            DateTime.tryParse((j['readByStaffAt'] ?? '').toString())?.toLocal(),
        readByClientAt: DateTime.tryParse((j['readByClientAt'] ?? '').toString())
            ?.toLocal(),
      );
}
