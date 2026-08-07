class AccountReport {
  final String id;
  final String title;
  final String fileUrl;
  final String fileType;
  final String uploadedByName;
  final DateTime createdAt;

  const AccountReport({
    required this.id,
    required this.title,
    required this.fileUrl,
    required this.fileType,
    required this.uploadedByName,
    required this.createdAt,
  });

  /// `uploadedBy` may come back populated (`{name, email}`) from the list
  /// endpoint, or as a bare ObjectId string right after an upload. Handle both
  /// so parsing never throws.
  static String _uploaderName(dynamic v) {
    if (v is Map) return v['name'] as String? ?? 'Unknown';
    return 'Unknown';
  }

  factory AccountReport.fromJson(Map<String, dynamic> json) {
    return AccountReport(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled',
      fileUrl: json['fileUrl'] as String? ?? '',
      fileType: json['fileType'] as String? ?? 'other',
      uploadedByName: _uploaderName(json['uploadedBy']),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String).toLocal()
          : DateTime.now(),
    );
  }
}
