import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nizan_crm/core/services/whatsapp_service.dart';

/// The PDF plus the fields TeamN Chat needs, built only when a button is
/// pressed (so screens don't render a PDF up front). Give either [pdf], or
/// [html] — a print page the server turns into the PDF with headless Chrome.
class WhatsAppDocument {
  final Uint8List? pdf;
  final String? html;
  final String filename;
  final String kind; // quotation | invoice
  final String? bookingId;
  final String? reference;
  final String? customerName;
  final String? phone;

  const WhatsAppDocument({
    this.pdf,
    this.html,
    required this.filename,
    required this.kind,
    this.bookingId,
    this.reference,
    this.customerName,
    this.phone,
  });
}

/// "Send to WhatsApp team" + "Send to customer now", as TeamN Chat specified:
/// both disabled while a request runs (no double sends), a confirmation
/// before sending straight to the customer, and TeamN Chat's own error text
/// on failure.
class WhatsAppSendButtons extends ConsumerStatefulWidget {
  /// Builds the document when a button is pressed. Throw to abort with a message.
  final Future<WhatsAppDocument> Function() buildDocument;

  /// Name used in the "Send this to … on WhatsApp now?" confirmation.
  final String customerName;

  /// False → both buttons disabled (e.g. no invoice number yet).
  final bool enabled;
  final String? disabledReason;

  /// Render as compact icon buttons (narrow dialogs / phones).
  final bool dense;

  const WhatsAppSendButtons({
    super.key,
    required this.buildDocument,
    required this.customerName,
    this.enabled = true,
    this.disabledReason,
    this.dense = false,
  });

  @override
  ConsumerState<WhatsAppSendButtons> createState() =>
      _WhatsAppSendButtonsState();
}

class _WhatsAppSendButtonsState extends ConsumerState<WhatsAppSendButtons> {
  static const _whatsAppGreen = Color(0xFF128C7E);

  WhatsAppSendMode? _running;

  Future<void> _send(WhatsAppSendMode mode) async {
    if (_running != null) return;
    final messenger = ScaffoldMessenger.of(context);

    if (mode == WhatsAppSendMode.send) {
      final name = widget.customerName.trim().isEmpty
          ? 'the customer'
          : widget.customerName.trim();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Send on WhatsApp'),
          content: Text('Send this to $name on WhatsApp now?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: _whatsAppGreen,
                foregroundColor: Colors.white,
              ),
              child: const Text('Send now'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() => _running = mode);
    WhatsAppSendResult result;
    try {
      final doc = await widget.buildDocument();
      result = await ref.read(whatsAppServiceProvider).sendDocument(
            mode: mode,
            kind: doc.kind,
            pdf: doc.pdf,
            html: doc.html,
            filename: doc.filename,
            bookingId: doc.bookingId,
            reference: doc.reference,
            customerName: doc.customerName,
            phone: doc.phone,
          );
    } catch (e) {
      result = WhatsAppSendResult.failure('Could not prepare the PDF: $e');
    }
    if (!mounted) return;
    setState(() => _running = null);

    messenger.showSnackBar(
      SnackBar(
        content: Text(result.ok
            ? (mode == WhatsAppSendMode.send
                ? 'Sent on WhatsApp ✓'
                : 'Sent to WhatsApp team ✓')
            : result.error),
        backgroundColor: result.ok ? const Color(0xFF10B981) : Colors.red.shade700,
        duration: Duration(seconds: result.ok ? 3 : 6),
      ),
    );
  }

  Widget _spinner() => const SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
      );

  @override
  Widget build(BuildContext context) {
    final busy = _running != null;
    final canPress = widget.enabled && !busy;
    final tip = widget.enabled ? '' : (widget.disabledReason ?? '');

    Widget button(WhatsAppSendMode mode, IconData icon, String label) {
      final running = _running == mode;
      final onPressed = canPress ? () => _send(mode) : null;
      if (widget.dense) {
        return IconButton.filled(
          tooltip: tip.isNotEmpty ? tip : label,
          onPressed: onPressed,
          style: IconButton.styleFrom(
            backgroundColor: _whatsAppGreen,
            foregroundColor: Colors.white,
          ),
          icon: running ? _spinner() : Icon(icon, size: 18),
        );
      }
      return Tooltip(
        message: tip,
        child: ElevatedButton.icon(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: _whatsAppGreen,
            foregroundColor: Colors.white,
          ),
          icon: running ? _spinner() : Icon(icon, size: 16),
          label: Text(label),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        button(WhatsAppSendMode.handover, Icons.forum_outlined,
            'Send to WhatsApp team'),
        button(WhatsAppSendMode.send, Icons.send_rounded,
            'Send to customer now'),
      ],
    );
  }
}
