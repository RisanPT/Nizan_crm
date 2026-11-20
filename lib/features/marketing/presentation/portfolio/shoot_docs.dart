import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/utils/file_saver.dart';
import 'package:nizan_crm/features/marketing/data/portfolio_models.dart';
import 'package:nizan_crm/features/marketing/data/team_models.dart' show TeamRefusal;
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/services/portfolio_service.dart';

// PDFs ON THE MOODBOARD AND THE STORYBOARD — a lookbook, a client's brief, a drawn storyboard, a shot list. Uploaded from the phone or
// computer (25 MB at most), and read right here, page by page: the file is fetched with the login (never by a public link) and shown
// with the same PDF reader as Company Reports. It can be renamed, saved, or taken off.

const kMaxPdfBytes = 25 * 1024 * 1024;

/// How a PDF is picked (a test puts its own here): its name and bytes, or null when nothing was picked.
final shootPdfPickerProvider = Provider<Future<({String name, Uint8List bytes})?> Function()>((ref) => () async {
      final res = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['pdf'], withData: true);
      final f = res?.files.single;
      if (f == null || f.bytes == null) return null;
      return (name: f.name, bytes: f.bytes!);
    });

/// How the pages are drawn (a test puts a plain stand-in here — the PDF renderer needs the platform).
final pdfPagesBuilderProvider = Provider<Widget Function(Uint8List bytes)>((ref) => (bytes) => PdfPreview(
      build: (_) => Future.value(bytes),
      useActions: false,
      maxPageWidth: 900,
      canChangePageFormat: false,
      canChangeOrientation: false,
      canDebug: false,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      previewPageMargin: const EdgeInsets.all(8),
      scrollViewDecoration: const BoxDecoration(color: Mkt.bg),
      pdfPreviewPageDecoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2))]),
      loadingWidget: const Center(child: CircularProgressIndicator()),
      onError: (context, _) => const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('This PDF could not be shown here. Use Download to open it on this device.', textAlign: TextAlign.center))),
    ));

/// How a PDF is saved to this device (a test records it).
final pdfSaverProvider = Provider<Future<void> Function(String name, Uint8List bytes)>((ref) => (name, bytes) async => saveFileBytes(name, bytes, mime: 'application/pdf'));

void _say(BuildContext context, String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

Future<bool> _try(BuildContext context, Future<void> Function() job) async {
  try {
    await job();
    return true;
  } on TeamRefusal catch (r) {
    if (context.mounted) _say(context, r.message);
  } catch (e) {
    if (context.mounted) showErrorSnackBar(context, e);
  }
  return false;
}

/// The PDF, read in the app: its pages, with Download and Close.
Future<void> showShootPdf(BuildContext context, {required String shootId, required ShootDocument doc}) {
  final wide = MediaQuery.sizeOf(context).width >= 760;
  final body = _PdfReader(shootId: shootId, doc: doc);
  if (wide) {
    return showDialog<void>(context: context, builder: (_) => Dialog(clipBehavior: Clip.antiAlias, child: ConstrainedBox(constraints: BoxConstraints(maxWidth: 1000, maxHeight: MediaQuery.sizeOf(context).height * 0.9), child: body)));
  }
  return showDialog<void>(context: context, useSafeArea: true, builder: (_) => Dialog.fullscreen(child: body));
}

class _PdfReader extends ConsumerStatefulWidget {
  const _PdfReader({required this.shootId, required this.doc});
  final String shootId;
  final ShootDocument doc;

  @override
  ConsumerState<_PdfReader> createState() => _PdfReaderState();
}

class _PdfReaderState extends ConsumerState<_PdfReader> {
  late Future<Uint8List> _bytes = _load();

  Future<Uint8List> _load() => ref.read(marketingPortfolioServiceProvider).documentBytes(widget.shootId, widget.doc.key);

  Future<void> _download(Uint8List bytes) async {
    await ref.read(pdfSaverProvider)(widget.doc.name.isEmpty ? 'document.pdf' : widget.doc.name, bytes);
    if (mounted) _say(context, 'Saved ${widget.doc.name}.');
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.doc;
    return Material(
      key: const Key('pf_pdf_reader'),
      color: Colors.white,
      child: FutureBuilder<Uint8List>(
        future: _bytes,
        builder: (context, snap) {
          final bytes = snap.data;
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(children: [
                const Icon(Icons.picture_as_pdf_rounded, color: Mkt.bad),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(d.title, key: const Key('pf_pdf_title'), maxLines: 2, overflow: TextOverflow.ellipsis, style: mktText(14.5, weight: FontWeight.w800)),
                    Text([d.facts, if (d.addedByName.isNotEmpty) 'added by ${d.addedByName}', if (d.label.isNotEmpty && d.name.isNotEmpty) d.name].where((x) => x.isNotEmpty).join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(11, color: Mkt.inkSoft)),
                  ]),
                ),
                if (bytes != null) TextButton.icon(key: const Key('pf_pdf_download'), onPressed: () => _download(bytes), icon: const Icon(Icons.download_rounded, size: 18), label: const Text('Download')),
                IconButton(key: const Key('pf_pdf_close'), tooltip: 'Close', onPressed: () => Navigator.maybePop(context), icon: const Icon(Icons.close_rounded)),
              ]),
            ),
            const Divider(height: 1),
            Expanded(
              child: snap.connectionState != ConnectionState.done
                  ? const Center(child: CircularProgressIndicator())
                  : snap.hasError || bytes == null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(mainAxisSize: MainAxisSize.min, children: [
                              Text(friendlyErrorMessage(snap.error ?? 'empty', fallback: 'The PDF could not be opened just now.'), key: const Key('pf_pdf_error'), textAlign: TextAlign.center, style: mktText(12.5, color: Mkt.inkSoft)),
                              const SizedBox(height: 10),
                              OutlinedButton.icon(key: const Key('pf_pdf_retry'), onPressed: () => setState(() {
                                  _bytes = _load();
                                }), icon: const Icon(Icons.refresh_rounded, size: 16), label: const Text('Try again')),
                            ]),
                          ),
                        )
                      : KeyedSubtree(key: const Key('pf_pdf_pages'), child: ref.read(pdfPagesBuilderProvider)(bytes)),
            ),
          ]);
        },
      ),
    );
  }
}

/// The PDFs of one part of the shoot ([part]: 'moodboard' or 'storyboard'): Upload PDF, and each PDF as a card that opens in the reader.
class ShootPdfs extends ConsumerStatefulWidget {
  const ShootPdfs({super.key, required this.detail, required this.part, this.hint = ''});
  final ShootDetail detail;
  final String part;

  /// What fits here, said under the button while there is none ("A lookbook, a client's brief…").
  final String hint;

  @override
  ConsumerState<ShootPdfs> createState() => _ShootPdfsState();
}

class _ShootPdfsState extends ConsumerState<ShootPdfs> {
  bool _uploading = false;

  String get _id => widget.detail.summary.id;

  Future<void> _upload() async {
    final picked = await ref.read(shootPdfPickerProvider)();
    if (picked == null || !mounted) return;
    if (picked.bytes.length > kMaxPdfBytes) {
      _say(context, 'That PDF is over 25 MB — make it smaller, or add it as a link.');
      return;
    }
    setState(() => _uploading = true);
    final ok = await _try(context, () => ref.read(marketingPortfolioServiceProvider).uploadDocument(_id, widget.part, fileName: picked.name, bytes: picked.bytes));
    if (!mounted) return;
    setState(() => _uploading = false);
    if (ok) {
      refreshPortfolio(ref);
      _say(context, '${picked.name} added.');
    }
  }

  Future<void> _rename(ShootDocument d) async {
    final label = await showDialog<String>(context: context, builder: (_) => _PdfLabelDialog(label: d.label, hint: d.name));
    if (label == null || !mounted) return;
    if (await _try(context, () => ref.read(marketingPortfolioServiceProvider).renameDocument(_id, d.key, label))) refreshPortfolio(ref);
  }

  Future<void> _remove(ShootDocument d) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove this PDF?'),
        content: Text('"${d.title}" comes off the ${widget.part} for everyone.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(key: const Key('pf_pdf_remove_ok'), style: FilledButton.styleFrom(backgroundColor: Mkt.bad), onPressed: () => Navigator.pop(context, true), child: const Text('Remove'))],
      ),
    );
    if (yes != true || !mounted) return;
    if (await _try(context, () => ref.read(marketingPortfolioServiceProvider).removeDocument(_id, d.key))) refreshPortfolio(ref);
  }

  Future<void> _download(ShootDocument d) async {
    await _try(context, () async {
      final bytes = await ref.read(marketingPortfolioServiceProvider).documentBytes(_id, d.key);
      await ref.read(pdfSaverProvider)(d.name.isEmpty ? 'document.pdf' : d.name, bytes);
    });
  }

  Widget _card(ShootDocument d) => SizedBox(
        width: 250,
        child: Material(
          color: Mkt.bg,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            key: Key('pf_pdf_${d.key}'),
            borderRadius: BorderRadius.circular(12),
            onTap: () => showShootPdf(context, shootId: _id, doc: d),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 2, 8),
              child: Row(children: [
                Container(
                  width: 38,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: Mkt.tint(Mkt.bad, 0.10), borderRadius: BorderRadius.circular(6)),
                  child: Text('PDF', style: mktText(10.5, weight: FontWeight.w900, color: Mkt.bad)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(d.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: mktText(12.5, weight: FontWeight.w700)),
                    Text([d.facts, if (d.addedByName.isNotEmpty) d.addedByName, if (d.addedAt != null) DateFormat('d MMM').format(d.addedAt!)].where((x) => x.isNotEmpty).join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(10.5, color: Mkt.inkSoft)),
                  ]),
                ),
                PopupMenuButton<String>(
                  key: Key('pf_pdf_menu_${d.key}'),
                  tooltip: 'More',
                  icon: const Icon(Icons.more_vert_rounded, size: 18),
                  onSelected: (v) => switch (v) {
                    'open' => showShootPdf(context, shootId: _id, doc: d),
                    'rename' => _rename(d),
                    'download' => _download(d),
                    _ => _remove(d),
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'open', child: Text('Open')),
                    PopupMenuItem(value: 'rename', child: Text('Name it')),
                    PopupMenuItem(value: 'download', child: Text('Download')),
                    PopupMenuItem(value: 'remove', child: Text('Remove')),
                  ],
                ),
              ]),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final docs = widget.detail.documentsOf(widget.part);
    return Column(key: Key('pf_pdfs_${widget.part}'), crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 10, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
        OutlinedButton.icon(
          key: Key('pf_pdf_upload_${widget.part}'),
          onPressed: _uploading ? null : _upload,
          icon: _uploading ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.picture_as_pdf_outlined, size: 18),
          label: Text(_uploading ? 'Uploading…' : 'Upload PDF'),
        ),
        if (docs.isEmpty && widget.hint.isNotEmpty) Text(widget.hint, style: mktText(11.5, color: Mkt.inkSoft)),
        if (docs.isNotEmpty) Text('${docs.length} PDF${docs.length == 1 ? '' : 's'}', style: mktText(11.5, color: Mkt.inkSoft)),
      ]),
      if (docs.isNotEmpty) ...[
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [for (final d in docs) _card(d)]),
      ],
    ]);
  }
}

/// "Name the PDF" — the dialog keeps its own text box (let go only once the dialog has gone).
class _PdfLabelDialog extends StatefulWidget {
  const _PdfLabelDialog({required this.label, required this.hint});
  final String label, hint;

  @override
  State<_PdfLabelDialog> createState() => _PdfLabelDialogState();
}

class _PdfLabelDialogState extends State<_PdfLabelDialog> {
  late final _c = TextEditingController(text: widget.label);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Name the PDF'),
        content: TextField(key: const Key('pf_pdf_label'), controller: _c, autofocus: true, decoration: InputDecoration(hintText: widget.hint, border: const OutlineInputBorder(), isDense: true)),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(key: const Key('pf_pdf_label_ok'), onPressed: () => Navigator.pop(context, _c.text.trim()), child: const Text('Save'))],
      );
}
