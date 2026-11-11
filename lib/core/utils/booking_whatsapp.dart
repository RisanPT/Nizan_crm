import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/services/whatsapp_service.dart';
import 'package:nizan_crm/core/utils/booking_pdf.dart';
import 'package:nizan_crm/core/utils/booking_print_service.dart';
import 'package:nizan_crm/core/widgets/whatsapp_send_buttons.dart';
import 'package:nizan_crm/features/bookings/data/booking.dart';

/// Sending a booking to the client on WhatsApp through TeamN Chat (the
/// automated WhatsApp), from the booking details page.
///
/// The document is the Booking Confirmation — the same one the WhatsApp icon
/// on the Bookings list sends. On web it is the exact "Print → Client
/// confirmation" page (rendered to PDF on the server); on mobile / Windows,
/// where that print page doesn't exist, the app's own PDF of the same
/// confirmation is attached instead.

bool isBookingCancelled(Booking b) =>
    const ['cancelled', 'canceled', 'rejected'].contains(b.status.toLowerCase());

Future<WhatsAppDocument> bookingConfirmationDocument(Booking booking) async {
  final html = bookingPrintHtml(booking, variant: BookingPrintVariant.clientConfirmation);
  final filename = 'Booking_Confirmation_${booking.displayBookingNumber}.pdf';
  if (html != null) {
    return WhatsAppDocument(
      html: html,
      filename: filename,
      kind: 'confirmation',
      bookingId: booking.id,
    );
  }
  final pdf = await buildBookingPdfBytes(
    booking,
    variant: BookingPrintVariant.clientConfirmation,
  );
  return WhatsAppDocument(
    pdf: pdf,
    filename: filename,
    kind: 'confirmation',
    bookingId: booking.id,
  );
}

/// Booking-details button: a WhatsApp menu ("Send to WhatsApp team" /
/// "Send to client now") that sends the Booking Confirmation via TeamN Chat.
class BookingWhatsAppButton extends ConsumerStatefulWidget {
  final Booking booking;
  const BookingWhatsAppButton({super.key, required this.booking});

  @override
  ConsumerState<BookingWhatsAppButton> createState() => _BookingWhatsAppButtonState();
}

class _BookingWhatsAppButtonState extends ConsumerState<BookingWhatsAppButton> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final cancelled = isBookingCancelled(widget.booking);
    final button = OutlinedButton.icon(
      onPressed: null, // the PopupMenuButton handles taps
      icon: _busy
          ? const SizedBox(
              width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.chat_outlined, size: 18),
      label: const Text('WhatsApp'),
      style: OutlinedButton.styleFrom(
        disabledForegroundColor: cancelled ? Colors.grey : Colors.green,
        side: BorderSide(color: cancelled ? Colors.grey.shade400 : Colors.green),
      ),
    );
    return PopupMenuButton<WhatsAppSendMode>(
      enabled: !cancelled && !_busy,
      tooltip: cancelled
          ? 'Cancelled booking — nothing to confirm'
          : 'Send the booking confirmation on WhatsApp',
      onSelected: (mode) => sendBookingOnWhatsApp(
        context: context,
        ref: ref,
        booking: widget.booking,
        mode: mode,
        setBusy: (b) {
          if (mounted) setState(() => _busy = b);
        },
      ),
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: WhatsAppSendMode.handover,
          child: ListTile(
            dense: true,
            leading: Icon(Icons.forum_outlined),
            title: Text('Send to WhatsApp team'),
            subtitle: Text('Staff check it in TeamN Chat, then send'),
          ),
        ),
        PopupMenuItem(
          value: WhatsAppSendMode.send,
          child: ListTile(
            dense: true,
            leading: Icon(Icons.send_rounded),
            title: Text('Send to client now'),
            subtitle: Text('Goes straight to the client'),
          ),
        ),
      ],
      child: button,
    );
  }
}

/// Sends the booking confirmation through TeamN Chat in [mode].
Future<void> sendBookingOnWhatsApp({
  required BuildContext context,
  required WidgetRef ref,
  required Booking booking,
  required WhatsAppSendMode mode,
  void Function(bool busy)? setBusy,
}) {
  return runWhatsAppSend(
    context: context,
    ref: ref,
    mode: mode,
    customerName: booking.customerName,
    buildDocument: () => bookingConfirmationDocument(booking),
    setBusy: setBusy ?? (_) {},
  );
}

/// For flows that have no button to hang a menu on (e.g. the "Booking
/// Updated" dialog): asks which way to send, then sends.
Future<void> chooseAndSendBookingOnWhatsApp(
  BuildContext context,
  WidgetRef ref,
  Booking booking,
) async {
  if (isBookingCancelled(booking)) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cancelled booking — nothing to confirm on WhatsApp.')),
    );
    return;
  }
  final mode = await showDialog<WhatsAppSendMode>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: const Text('Send booking on WhatsApp'),
      children: [
        SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx, WhatsAppSendMode.handover),
          child: const ListTile(
            leading: Icon(Icons.forum_outlined),
            title: Text('Send to WhatsApp team'),
            subtitle: Text('Staff check it in TeamN Chat, then send'),
          ),
        ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx, WhatsAppSendMode.send),
          child: const ListTile(
            leading: Icon(Icons.send_rounded),
            title: Text('Send to client now'),
            subtitle: Text('Goes straight to the client'),
          ),
        ),
      ],
    ),
  );
  if (mode == null || !context.mounted) return;
  await sendBookingOnWhatsApp(context: context, ref: ref, booking: booking, mode: mode);
}
