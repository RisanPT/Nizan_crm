import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/utils/file_saver.dart';
import 'package:nizan_crm/features/reports/data/company_report.dart';
import 'package:nizan_crm/features/reports/services/company_report_service.dart';
import 'package:nizan_crm/providers/dio_provider.dart';

/// In-app viewer for a company report. Renders PDFs and images inline; CSV as
/// text; other types (Excel/Word) offer download / open-in-browser.
class ReportViewerScreen extends ConsumerStatefulWidget {
  final CompanyReport report;
  const ReportViewerScreen({super.key, required this.report});

  @override
  ConsumerState<ReportViewerScreen> createState() => _ReportViewerScreenState();
}

class _ReportViewerScreenState extends ConsumerState<ReportViewerScreen> {
  Uint8List? _bytes;
  Object? _error;
  bool _loading = true;

  bool get _renderable =>
      const {'pdf', 'image', 'csv'}.contains(widget.report.fileType);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Non-renderable types don't need the bytes up front — the action buttons
    // fetch on demand.
    if (!_renderable) {
      setState(() => _loading = false);
      return;
    }
    try {
      final bytes =
          await ref.read(companyReportServiceProvider).downloadBytes(widget.report.id);
      if (mounted) {
        setState(() {
          _bytes = Uint8List.fromList(bytes);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  String get _inlineUrl {
    final token = ref.read(authSessionProvider)?.token ?? '';
    return '$apiBaseUrl/company-reports/${widget.report.id}/download?inline=1&token=$token';
  }

  Future<void> _openExternally() async {
    final uri = Uri.parse(_inlineUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the file')),
        );
      }
    }
  }

  Future<void> _download() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = _bytes ??
          Uint8List.fromList(
              await ref.read(companyReportServiceProvider).downloadBytes(widget.report.id));
      await saveFileBytes(widget.report.downloadName, bytes);
      messenger.showSnackBar(
        SnackBar(content: Text('Downloaded ${widget.report.downloadName}')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
            content: Text(friendlyErrorMessage(e)),
            backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _print() async {
    final bytes = _bytes;
    if (bytes == null) return;
    try {
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: widget.report.downloadName,
      );
    } catch (_) {/* user cancelled or platform unsupported */}
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final isPdf = widget.report.fileType == 'pdf';
    return Scaffold(
      backgroundColor: crm.background,
      appBar: AppBar(
        backgroundColor: crm.surface,
        foregroundColor: crm.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 15,
              backgroundColor: crm.primary.withValues(alpha: 0.1),
              child: Icon(_typeIcon, size: 16, color: crm.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.report.title,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  if (widget.report.department.isNotEmpty ||
                      widget.report.folderName.isNotEmpty)
                    Text(
                      [
                        widget.report.department,
                        if (widget.report.folderName.isNotEmpty) widget.report.folderName,
                      ].where((s) => s.isNotEmpty).join('  ·  '),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: crm.textSecondary),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (isPdf && _bytes != null)
            IconButton(
              tooltip: 'Print',
              icon: const Icon(Icons.print_outlined),
              onPressed: _print,
            ),
          IconButton(
            tooltip: 'Open in browser',
            icon: const Icon(Icons.open_in_new),
            onPressed: _openExternally,
          ),
          IconButton(
            tooltip: 'Download',
            icon: const Icon(Icons.download_outlined),
            onPressed: _download,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _buildBody(crm),
    );
  }

  IconData get _typeIcon {
    switch (widget.report.fileType) {
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      case 'excel':
        return Icons.table_chart_outlined;
      case 'csv':
        return Icons.grid_on_outlined;
      case 'word':
        return Icons.description_outlined;
      case 'image':
        return Icons.image_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  Widget _buildBody(CrmTheme crm) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return AppErrorView(error: _error!, onRetry: () {
        setState(() {
          _loading = true;
          _error = null;
        });
        _load();
      });
    }

    switch (widget.report.fileType) {
      case 'pdf':
        return PdfPreview(
          build: (format) => Future.value(_bytes!),
          // Our own actions live in the AppBar — hide the built-in bottom bar.
          useActions: false,
          maxPageWidth: 900,
          canChangePageFormat: false,
          canChangeOrientation: false,
          canDebug: false,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          previewPageMargin: const EdgeInsets.all(8),
          scrollViewDecoration: BoxDecoration(color: crm.background),
          pdfPreviewPageDecoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 3)),
            ],
          ),
          loadingWidget: const Center(child: CircularProgressIndicator()),
          onError: (context, error) => _RenderFailed(
            crm: crm,
            icon: Icons.picture_as_pdf_outlined,
            onOpen: _openExternally,
          ),
        );
      case 'image':
        return Container(
          color: Colors.black,
          child: InteractiveViewer(
            maxScale: 5,
            child: Center(child: Image.memory(_bytes!)),
          ),
        );
      case 'csv':
        return _CsvTable(bytes: _bytes!, crm: crm);
      default:
        return _UnsupportedType(
          report: widget.report,
          crm: crm,
          onOpen: _openExternally,
          onDownload: _download,
        );
    }
  }
}

// A single CSV line → fields, honouring double-quoted fields with commas.
List<String> _parseCsvLine(String line) {
  final out = <String>[];
  final sb = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < line.length; i++) {
    final c = line[i];
    if (c == '"') {
      if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
        sb.write('"');
        i++;
      } else {
        inQuotes = !inQuotes;
      }
    } else if (c == ',' && !inQuotes) {
      out.add(sb.toString());
      sb.clear();
    } else {
      sb.write(c);
    }
  }
  out.add(sb.toString());
  return out;
}

class _CsvTable extends StatelessWidget {
  final Uint8List bytes;
  final CrmTheme crm;
  const _CsvTable({required this.bytes, required this.crm});

  @override
  Widget build(BuildContext context) {
    String text;
    try {
      text = utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      text = String.fromCharCodes(bytes);
    }
    final rows = const LineSplitter()
        .convert(text)
        .where((l) => l.trim().isNotEmpty)
        .map(_parseCsvLine)
        .toList();

    if (rows.isEmpty) {
      return Center(
        child: Text('Empty file', style: TextStyle(color: crm.textSecondary)),
      );
    }

    final header = rows.first;
    final body = rows.skip(1).toList();
    final cols = header.length;

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor:
              WidgetStatePropertyAll(crm.primary.withValues(alpha: 0.08)),
          border: TableBorder.all(color: crm.border, width: 0.6),
          columns: [
            for (final h in header)
              DataColumn(
                label: Text(
                  h,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: crm.textPrimary,
                  ),
                ),
              ),
          ],
          rows: [
            for (final r in body)
              DataRow(
                cells: [
                  for (var i = 0; i < cols; i++)
                    DataCell(
                      Text(
                        i < r.length ? r[i] : '',
                        style: TextStyle(color: crm.textPrimary),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _RenderFailed extends StatelessWidget {
  final CrmTheme crm;
  final IconData icon;
  final VoidCallback onOpen;
  const _RenderFailed({
    required this.crm,
    required this.icon,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: crm.textSecondary),
            const SizedBox(height: 12),
            Text(
              "Couldn't render this file in the app.",
              style: TextStyle(color: crm.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onOpen,
              style: FilledButton.styleFrom(backgroundColor: crm.primary),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Open in browser'),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnsupportedType extends StatelessWidget {
  final CompanyReport report;
  final CrmTheme crm;
  final VoidCallback onOpen;
  final VoidCallback onDownload;
  const _UnsupportedType({
    required this.report,
    required this.crm,
    required this.onOpen,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    IconData icon;
    switch (report.fileType) {
      case 'excel':
        icon = Icons.table_chart_outlined;
        break;
      case 'word':
        icon = Icons.description_outlined;
        break;
      default:
        icon = Icons.insert_drive_file_outlined;
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: crm.textSecondary),
            const SizedBox(height: 16),
            Text(
              report.fileName.isNotEmpty ? report.fileName : report.title,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: crm.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              "This file type can't be previewed inside the app. Open it in your browser or download it.",
              textAlign: TextAlign.center,
              style: TextStyle(color: crm.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: onOpen,
                  style: FilledButton.styleFrom(backgroundColor: crm.primary),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Open in browser'),
                ),
                OutlinedButton.icon(
                  onPressed: onDownload,
                  icon: const Icon(Icons.download_outlined, size: 18),
                  label: const Text('Download'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
