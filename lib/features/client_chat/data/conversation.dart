/// A concierge chat thread between a client (bride) and the studio team.
/// Mirrors the backend `conversationView` serializer in `chatController.js`.
class ClientConversation {
  final String id;
  final String clientName;
  final String clientPhone;
  final String status; // open | closed
  final DateTime? lastMessageAt;
  final String lastMessagePreview;
  final String lastMessageSenderType; // client | staff | system
  final int unreadForStaff;
  final int unreadForClient;

  /// Who on the team holds the chat (the first to answer, or whom the CRM Head gave it to) — null when nobody does.
  final String? assignedStaffId;
  final String assignedStaffName;

  /// Since when the client has been waiting for an answer (null when nobody is waiting).
  final DateTime? awaitingSince;

  const ClientConversation({
    required this.id,
    this.clientName = '',
    this.clientPhone = '',
    this.status = 'open',
    this.lastMessageAt,
    this.lastMessagePreview = '',
    this.lastMessageSenderType = '',
    this.unreadForStaff = 0,
    this.unreadForClient = 0,
    this.assignedStaffId,
    this.assignedStaffName = '',
    this.awaitingSince,
  });

  factory ClientConversation.fromJson(Map<String, dynamic> j) =>
      ClientConversation(
        id: (j['_id'] ?? '').toString(),
        clientName: (j['clientName'] ?? '').toString(),
        clientPhone: (j['clientPhone'] ?? '').toString(),
        status: (j['status'] ?? 'open').toString(),
        lastMessageAt: DateTime.tryParse((j['lastMessageAt'] ?? '').toString())
            ?.toLocal(),
        lastMessagePreview: (j['lastMessagePreview'] ?? '').toString(),
        lastMessageSenderType:
            (j['lastMessageSenderType'] ?? '').toString(),
        unreadForStaff: (j['unreadForStaff'] as num?)?.toInt() ?? 0,
        unreadForClient: (j['unreadForClient'] as num?)?.toInt() ?? 0,
        assignedStaffId: (j['assignedStaffId'] ?? '').toString().isEmpty ? null : j['assignedStaffId'].toString(),
        assignedStaffName: (j['assignedStaffName'] ?? '').toString(),
        awaitingSince: DateTime.tryParse((j['awaitingSince'] ?? '').toString())?.toLocal(),
      );

  /// A friendly label when the client hasn't shared a name yet.
  String get displayName =>
      clientName.trim().isNotEmpty ? clientName.trim() : (clientPhone.isNotEmpty ? clientPhone : 'Client');
}
