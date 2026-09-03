class ReportViewer {
  final String id;
  final String name;
  const ReportViewer({required this.id, required this.name});

  factory ReportViewer.fromJson(dynamic j) {
    if (j is Map) {
      return ReportViewer(
        id: (j['_id'] ?? j['id'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
      );
    }
    return ReportViewer(id: j.toString(), name: '');
  }
}

/// A company report document filed under a department.
class CompanyReport {
  final String id;
  final String title;
  final String description;
  final String department;
  final String folderId;
  final String folderName;
  final String period;
  final String fileUrl;
  final String fileType; // pdf | excel | csv | word | image | other
  final String fileName;
  final String uploadedByName;
  final String uploadedById;
  final List<String> visibleToRoles;
  final List<ReportViewer> sharedWith;
  final DateTime createdAt;

  const CompanyReport({
    required this.id,
    required this.title,
    this.description = '',
    required this.department,
    this.folderId = '',
    this.folderName = '',
    this.period = '',
    required this.fileUrl,
    required this.fileType,
    this.fileName = '',
    this.uploadedByName = '',
    this.uploadedById = '',
    this.visibleToRoles = const [],
    this.sharedWith = const [],
    required this.createdAt,
  });

  factory CompanyReport.fromJson(Map<String, dynamic> j) {
    final up = j['uploadedBy'];
    final folder = j['folder'];
    return CompanyReport(
      id: (j['_id'] ?? j['id'] ?? '').toString(),
      title: (j['title'] ?? '').toString(),
      description: (j['description'] ?? '').toString(),
      department: (j['department'] ?? '').toString(),
      folderId: folder is Map
          ? (folder['_id'] ?? '').toString()
          : (folder ?? '').toString(),
      folderName: folder is Map ? (folder['name'] ?? '').toString() : '',
      period: (j['period'] ?? '').toString(),
      fileUrl: (j['fileUrl'] ?? '').toString(),
      fileType: (j['fileType'] ?? 'other').toString(),
      fileName: (j['fileName'] ?? '').toString(),
      uploadedByName: up is Map ? (up['name'] ?? '').toString() : '',
      uploadedById: up is Map ? (up['_id'] ?? '').toString() : (up ?? '').toString(),
      visibleToRoles: ((j['visibleToRoles'] as List?) ?? const []).map((e) => e.toString()).toList(),
      sharedWith: ((j['sharedWith'] as List?) ?? const []).map(ReportViewer.fromJson).toList(),
      createdAt: DateTime.tryParse((j['createdAt'] ?? '').toString()) ?? DateTime.now(),
    );
  }

  /// A safe filename for saving the download.
  String get downloadName {
    if (fileName.trim().isNotEmpty) return fileName.trim();
    const ext = {'pdf': 'pdf', 'excel': 'xlsx', 'csv': 'csv', 'word': 'docx', 'image': 'jpg'};
    final base = title.trim().isEmpty ? 'report' : title.trim().replaceAll(RegExp(r'[^\w.-]+'), '_');
    return '$base.${ext[fileType] ?? 'bin'}';
  }
}
