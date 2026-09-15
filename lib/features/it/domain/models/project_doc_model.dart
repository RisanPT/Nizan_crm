import 'package:flutter/material.dart';

/// The kind of document attached to a project.
enum ProjectDocType {
  srs('srs', 'SRS', Icons.description_outlined, Color(0xFF1D4E89)),
  design('design', 'Design Doc', Icons.brush_outlined, Color(0xFF3E7C8B)),
  api('api', 'API Spec', Icons.api_outlined, Color(0xFFC1622D)),
  other('other', 'Other', Icons.insert_drive_file_outlined, Color(0xFF5B3E8B));

  const ProjectDocType(this.slug, this.label, this.icon, this.color);
  final String slug;
  final String label;
  final IconData icon;
  final Color color;

  static ProjectDocType fromString(String? s) =>
      ProjectDocType.values.firstWhere((e) => e.slug == s, orElse: () => ProjectDocType.other);
}

/// One revision of a document — bundles the editable DOC and/or the PDF.
class ProjectDocVersion {
  final int version;
  final String pdfUrl;
  final String pdfName;
  final String docUrl;
  final String docName;
  final String notes;
  final String uploadedByName;
  final DateTime? uploadedAt;

  const ProjectDocVersion({
    required this.version,
    this.pdfUrl = '',
    this.pdfName = '',
    this.docUrl = '',
    this.docName = '',
    this.notes = '',
    this.uploadedByName = '',
    this.uploadedAt,
  });

  bool get hasPdf => pdfUrl.isNotEmpty;
  bool get hasDoc => docUrl.isNotEmpty;

  factory ProjectDocVersion.fromJson(Map<String, dynamic> j) => ProjectDocVersion(
        version: (j['version'] as num?)?.toInt() ?? 0,
        pdfUrl: (j['pdfUrl'] ?? '').toString(),
        pdfName: (j['pdfName'] ?? '').toString(),
        docUrl: (j['docUrl'] ?? '').toString(),
        docName: (j['docName'] ?? '').toString(),
        notes: (j['notes'] ?? '').toString(),
        uploadedByName: (j['uploadedByName'] ?? '').toString(),
        uploadedAt: (j['uploadedAt'] == null || j['uploadedAt'] == '')
            ? null
            : DateTime.tryParse(j['uploadedAt'].toString())?.toLocal(),
      );
}

/// A versioned project document (SRS, design doc, API spec, …).
class ProjectDocModel {
  final String id;
  final String projectId;
  final String title;
  final String description;
  final String createdByName;
  final ProjectDocType docType;
  final List<ProjectDocVersion> versions; // newest first
  final DateTime? createdAt;

  const ProjectDocModel({
    required this.id,
    required this.projectId,
    required this.title,
    this.description = '',
    this.createdByName = '',
    this.docType = ProjectDocType.srs,
    this.versions = const [],
    this.createdAt,
  });

  ProjectDocVersion? get latest => versions.isEmpty ? null : versions.first;

  factory ProjectDocModel.fromJson(Map<String, dynamic> j) {
    final proj = j['projectId'];
    final list = ((j['versions'] as List?) ?? const [])
        .map((e) => ProjectDocVersion.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList()
      ..sort((a, b) => b.version.compareTo(a.version));
    return ProjectDocModel(
      id: (j['_id'] ?? j['id'] ?? '').toString(),
      projectId: proj is Map ? (proj['_id'] ?? '').toString() : (proj ?? '').toString(),
      title: (j['title'] ?? '').toString(),
      description: (j['description'] ?? '').toString(),
      createdByName: (j['createdByName'] ?? '').toString(),
      docType: ProjectDocType.fromString((j['docType'] ?? 'srs').toString()),
      versions: list,
      createdAt: (j['createdAt'] == null || j['createdAt'] == '')
          ? null
          : DateTime.tryParse(j['createdAt'].toString())?.toLocal(),
    );
  }
}
