class LeadActivity {
  final String id;
  final String leadId;
  final String createdByName;
  final String type; // 'followup' | 'call' | 'activity'
  /// How a follow-up is done: 'call' | 'whatsapp' | 'visit' | 'meeting' | 'other'; '' = not said (older entries).
  final String channel;
  final DateTime scheduledDate;
  final String remark;
  final String status; // 'Pending' | 'Completed' | 'Cancelled'
  final String callResponse;
  final List<String> attachments;
  final DateTime createdAt;

  LeadActivity({
    required this.id,
    required this.leadId,
    required this.createdByName,
    required this.type,
    this.channel = '',
    required this.scheduledDate,
    required this.remark,
    required this.status,
    required this.callResponse,
    required this.attachments,
    required this.createdAt,
  });

  factory LeadActivity.fromJson(Map<String, dynamic> json) {
    final createdByMap = json['createdBy'] is Map<String, dynamic>
        ? json['createdBy'] as Map<String, dynamic>
        : null;
    return LeadActivity(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      leadId: json['leadId'] as String? ?? '',
      createdByName: createdByMap != null
          ? (createdByMap['name'] as String? ?? 'Unknown')
          : 'Unknown',
      type: json['type'] as String? ?? 'activity',
      channel: json['channel'] as String? ?? '',
      scheduledDate: json['scheduledDate'] != null
          ? DateTime.parse(json['scheduledDate'] as String).toLocal()
          : DateTime.now(),
      remark: json['remark'] as String? ?? '',
      status: json['status'] as String? ?? 'Pending',
      callResponse: json['callResponse'] as String? ?? 'N/A',
      attachments: List<String>.from(json['attachments'] ?? []),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String).toLocal()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'leadId': leadId,
      'type': type,
      if (channel.isNotEmpty) 'channel': channel,
      'scheduledDate': scheduledDate.toIso8601String(),
      'remark': remark,
      'status': status,
      'callResponse': callResponse,
      'attachments': attachments,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

/// The ways a follow-up can be done, as the CRM saves them (backend models/LeadActivity.js FOLLOWUP_CHANNELS) with their labels.
const kFollowUpChannels = [('call', 'Call'), ('whatsapp', 'WhatsApp'), ('visit', 'Visit'), ('meeting', 'Meeting'), ('other', 'Other')];

/// The label of a follow-up channel ('' when not said).
String followUpChannelName(String key) => kFollowUpChannels.firstWhere((c) => c.$1 == key, orElse: () => ('', '')).$2;
