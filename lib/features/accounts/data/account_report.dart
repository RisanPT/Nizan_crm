/// A user who has been granted view access to a report.
class ReportViewer {
  final String id;
  final String name;
  const ReportViewer({required this.id, required this.name});
}

class AccountReport {
  final String id;
  final String title;
  final String fileUrl;
  final String fileType;
  final String fileName;
  final String uploadedByName;
  final String uploadedById;
  /// Users (besides the owner + admins) allowed to view this report.
  final List<ReportViewer> sharedWith;
  final DateTime createdAt;

  const AccountReport({
    required this.id,
    required this.title,
    required this.fileUrl,
    required this.fileType,
    this.fileName = '',
    required this.uploadedByName,
    this.uploadedById = '',
    this.sharedWith = const [],
    required this.createdAt,
  });

  /// A sensible download filename with extension.
  String get downloadName {
    if (fileName.trim().isNotEmpty) return fileName.trim();
    final ext = fileType == 'pdf'
        ? 'pdf'
        : fileType == 'excel'
            ? 'xlsx'
            : fileType == 'csv'
                ? 'csv'
                : 'bin';
    final base = title.trim().isEmpty ? 'report' : title.trim().replaceAll(RegExp(r'[^\w.-]+'), '_');
    return '$base.$ext';
  }

  /// `uploadedBy` may come back populated (`{name, email}`) from the list
  /// endpoint, or as a bare ObjectId string right after an upload. Handle both
  /// so parsing never throws.
  static String _uploaderName(dynamic v) {
    if (v is Map) return v['name'] as String? ?? 'Unknown';
    return 'Unknown';
  }

  static String _id(dynamic v) {
    if (v is Map) return v['_id'] as String? ?? v['id'] as String? ?? '';
    return v as String? ?? '';
  }

  static List<ReportViewer> _viewers(dynamic v) {
    if (v is! List) return const [];
    return v
        .map((e) => e is Map
            ? ReportViewer(
                id: e['_id'] as String? ?? e['id'] as String? ?? '',
                name: e['name'] as String? ?? 'Unknown',
              )
            : ReportViewer(id: e as String? ?? '', name: 'Unknown'))
        .where((r) => r.id.isNotEmpty)
        .toList();
  }

  factory AccountReport.fromJson(Map<String, dynamic> json) {
    return AccountReport(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled',
      fileUrl: json['fileUrl'] as String? ?? '',
      fileType: json['fileType'] as String? ?? 'other',
      fileName: json['fileName'] as String? ?? '',
      uploadedByName: _uploaderName(json['uploadedBy']),
      uploadedById: _id(json['uploadedBy']),
      sharedWith: _viewers(json['sharedWith']),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String).toLocal()
          : DateTime.now(),
    );
  }
}
