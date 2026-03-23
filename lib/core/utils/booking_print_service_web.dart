import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../models/booking.dart';
import 'booking_print_service.dart';

String _staffWorkLabel(BookingAssignment staff) {
  if (staff.works.isNotEmpty) {
    return staff.works.join(', ');
  }
  if (staff.specialization.trim().isNotEmpty) {
    return staff.specialization.trim();
  }
  return staff.role.trim();
}

Future<void> printBookingDetails(
  Booking booking, {
  required BookingPrintVariant variant,
  List<Booking> relatedArtistBookings = const [],
  String artistName = '',
}) async {
  final content = _buildPrintableHtml(
    booking,
    variant: variant,
    relatedArtistBookings: relatedArtistBookings,
    artistName: artistName,
  );
  final blob = web.Blob(
    [content.toJS].toJS,
    web.BlobPropertyBag(type: 'text/html;charset=utf-8'),
  );
  final objectUrl = web.URL.createObjectURL(blob);
  final iframe = web.document.createElement('iframe') as web.HTMLIFrameElement
    ..style.position = 'fixed'
    ..style.right = '0'
    ..style.bottom = '0'
    ..style.width = '0'
    ..style.height = '0'
    ..style.border = '0'
    ..src = objectUrl;

  web.document.body?.append(iframe);

  iframe.onLoad.listen((_) async {
    // Small delay to ensure iframe content is fully rendered
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final frameWindow = iframe.contentWindow;
    if (frameWindow != null) {
      try {
        frameWindow.focus();
        frameWindow.print();
      } catch (_) {
        // Fallback: trigger print from main window
        try {
          web.window.print();
        } catch (_) {
          // Last resort: ignore if printing is not available
        }
      }
    }
    Future<void>.delayed(const Duration(seconds: 2), () {
      web.URL.revokeObjectURL(objectUrl);
      iframe.remove();
    });
  });
}

String _buildPrintableHtml(
  Booking booking, {
  required BookingPrintVariant variant,
  List<Booking> relatedArtistBookings = const [],
  String artistName = '',
}) {
  final isArtistCopy = variant == BookingPrintVariant.artist;
  final worksToPrint = isArtistCopy && relatedArtistBookings.isNotEmpty
      ? (relatedArtistBookings.toList()
          ..sort((a, b) => a.serviceStart.compareTo(b.serviceStart)))
      : [booking];

  final pagesHtml = worksToPrint
      .map((work) {
        return '<div class="booking-page">\n${_buildSingleBookingHtml(work, variant, relatedArtistBookings, artistName)}\n</div>';
      })
      .join('\n');

  return '''
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8" />
    <title>Booking ${_escape(booking.customerName)}</title>
    <style>
      body { font-family: Arial, sans-serif; color: #0b1b3b; padding: 32px; margin: 0; }
      h1, h2, h3, p { margin: 0; }
      .header { margin-bottom: 24px; }
      .title { font-size: 28px; font-weight: 700; margin-bottom: 6px; }
      .muted { color: #667085; font-size: 14px; }
      .grid { display: grid; grid-template-columns: 1fr 1fr; gap: 16px; margin: 24px 0; }
      .card { border: 1px solid #d9dde3; border-radius: 12px; padding: 16px; }
      .label { font-size: 12px; text-transform: uppercase; color: #667085; margin-bottom: 6px; }
      .value { font-size: 16px; font-weight: 600; }
      table { width: 100%; border-collapse: collapse; margin-top: 12px; }
      th, td { border: 1px solid #d9dde3; padding: 10px; text-align: left; font-size: 14px; }
      th { background: #f5f7fa; }
      .section { margin-top: 28px; }
      .summary { margin-top: 24px; border-top: 2px solid #0b1b3b; padding-top: 16px; }
      .summary-row { display: flex; justify-content: space-between; margin-bottom: 8px; }
      .summary-row strong { font-size: 16px; }
      .detail-table td:first-child { width: 220px; font-weight: 700; color: #44526d; }
      .schedule-note { margin-top: 8px; color: #667085; font-size: 13px; }
      .current-work-row td { background: #fff8e6; font-weight: 600; }
      .current-badge { display: inline-block; padding: 3px 8px; border-radius: 999px; background: #0b1b3b; color: white; font-size: 11px; font-weight: 700; }
      .booking-page { page-break-after: always; }
      .booking-page:last-child { page-break-after: auto; }
      .client-confirmation { border: 1px solid #d9dde3; border-radius: 18px; padding: 28px; }
      .client-brand { text-align: center; margin-bottom: 24px; }
      .client-brand h1 { font-size: 26px; margin-bottom: 6px; letter-spacing: 0.04em; }
      .client-brand p { color: #667085; font-size: 14px; }
      .client-greeting { font-size: 18px; font-weight: 700; margin-bottom: 14px; }
      .client-intro { color: #44526d; margin-bottom: 20px; line-height: 1.6; }
      .client-detail-block { border: 1px solid #d9dde3; border-radius: 14px; padding: 18px; margin-bottom: 16px; background: #fcfcfd; }
      .client-detail-block h3 { font-size: 16px; margin-bottom: 14px; }
      .client-detail-line { margin-bottom: 10px; line-height: 1.6; }
      .client-detail-line strong { color: #0b1b3b; }
      .client-finance { display: grid; grid-template-columns: 1fr 1fr; gap: 14px; margin: 20px 0; }
      .client-finance-card { border: 1px solid #d9dde3; border-radius: 14px; padding: 16px; }
      .finance-label { color: #667085; font-size: 12px; text-transform: uppercase; margin-bottom: 8px; }
      .finance-value { font-size: 20px; font-weight: 700; }
      .client-terms { margin-top: 18px; }
      .client-terms h3 { font-size: 16px; margin-bottom: 12px; }
      .client-terms ol { margin: 0; padding-left: 22px; color: #44526d; line-height: 1.7; }
      .client-terms li { margin-bottom: 8px; }
      @media print {
        body { padding: 0; }
        .booking-page { padding: 16px; margin-bottom: 24px; }
        .section { break-inside: avoid; }
        .client-confirmation, .client-detail-block, .client-finance-card { break-inside: avoid; }
      }
    </style>
  </head>
  <body>
$pagesHtml
  </body>
</html>
''';
}

String _buildSingleBookingHtml(
  Booking booking,
  BookingPrintVariant variant,
  List<Booking> relatedArtistBookings,
  String artistName,
) {
  final isArtistCopy = variant == BookingPrintVariant.artist;
  if (!isArtistCopy) {
    return _buildClientConfirmationHtml(booking);
  }
  final assignedStaffRows = booking.assignedStaff.isEmpty
      ? '<tr><td colspan="3">No staff assigned</td></tr>'
      : booking.assignedStaff
            .map(
              (staff) =>
                  '''
<tr>
  <td>${_escape(staff.artistName)}</td>
  <td>${_escape(_staffWorkLabel(staff))}</td>
  <td>${_escape(staff.type)}</td>
</tr>''',
            )
            .join();

  final addonRows = booking.addons.isEmpty
      ? '<tr><td colspan="4">No add-ons</td></tr>'
      : booking.addons
            .map(
              (addon) =>
                  '''
<tr>
  <td>${_escape(addon.service)}</td>
  <td>${addon.persons}</td>
  <td>INR ${addon.amount.toStringAsFixed(0)}</td>
  <td>INR ${(addon.amount * addon.persons).toStringAsFixed(0)}</td>
</tr>''',
            )
            .join();

  final discountLabel = booking.discountType == 'percent'
      ? '${booking.discountValue.toStringAsFixed(0)}%'
      : 'INR ${booking.discountValue.toStringAsFixed(0)}';
  final forecast =
      booking.totalPrice - booking.advanceAmount - booking.discountAmount;
  final statusLabel = booking.status.isEmpty
      ? 'Pending'
      : _titleCase(booking.status);
  final logisticsRows = [
    _detailRow('Region', booking.region),
    _detailRow('Driver', booking.driverName),
    _detailRow('Travel Mode', booking.travelMode),
    _detailRow('Travel Time', booking.travelTime),
    _detailRow(
      'Travel Distance',
      booking.travelDistanceKm > 0
          ? '${booking.travelDistanceKm.toStringAsFixed(0)} KM'
          : '',
    ),
    _detailRow('Map URL', booking.mapUrl),
    _detailRow('Room Detail', booking.requiredRoomDetail),
    _detailRow('Secondary Contact', booking.secondaryContact),
  ].where((row) => row.isNotEmpty).join();

  final serviceRows = [
    _detailRow('Outfit Details', booking.outfitDetails),
    _detailRow('Capture Staff', booking.captureStaffDetails),
    _detailRow(
      'Content Creation Required',
      booking.contentCreationRequired ? 'Yes' : 'No',
    ),
    _detailRow('Staff Instructions', booking.staffInstructions),
    _detailRow('Internal Remarks', booking.internalRemarks),
  ].where((row) => row.isNotEmpty).join();
  final clientRows = [
    _detailRow('Customer Name', booking.customerName),
    _detailRow('Primary Number', booking.phone),
    _detailRow('Alternative Number', booking.secondaryContact),
    _detailRow('Email', booking.email),
  ].where((row) => row.isNotEmpty).join();
  final artistRows = [
    _detailRow(
      'Assigned Artist(s)',
      booking.assignedStaff.isEmpty
          ? ''
          : booking.assignedStaff.map((staff) => staff.artistName).join(', '),
    ),
    _detailRow(
      'Artist Mobile Number',
      booking.assignedStaff
          .where((staff) => staff.phone.trim().isNotEmpty)
          .map((staff) => '${staff.artistName}: ${staff.phone}')
          .join(', '),
    ),
    _detailRow('Package', booking.service),
    _detailRow('Status', statusLabel),
  ].where((row) => row.isNotEmpty).join();
  final title = isArtistCopy ? 'Artist Copy' : 'Client Copy';
  final subtitle = isArtistCopy
      ? 'Complete booking sheet for assigned team'
      : 'Booking confirmation copy for client';
  final effectiveArtistName = artistName.trim().isNotEmpty
      ? artistName.trim()
      : booking.assignedStaff
            .where((staff) => staff.roleType.toLowerCase() == 'lead')
            .map((staff) => staff.artistName.trim())
            .firstWhere((name) => name.isNotEmpty, orElse: () => '');
  final sortedArtistWorks = {
    for (final item in relatedArtistBookings) item.id: item,
  }.values.toList()..sort((a, b) => a.serviceStart.compareTo(b.serviceStart));
  final artistWorkRows = sortedArtistWorks.isEmpty
      ? '<tr><td colspan="5">No other works scheduled for this artist today</td></tr>'
      : sortedArtistWorks.map((item) {
          final isCurrentBooking = item.id == booking.id;
          return '''
<tr>
  <td>${isCurrentBooking ? 'Current' : ''}</td>
  <td>${_formatTime(item.serviceStart)} - ${_formatTime(item.serviceEnd)}</td>
  <td>${_escape(item.customerName)}</td>
  <td>${_escape(item.service)}</td>
  <td>${_escape(item.region.isEmpty ? 'No region' : item.region)}</td>
</tr>''';
        }).join();
  final artistClientDetailRows = sortedArtistWorks.isEmpty
      ? '<tr><td colspan="8">No client details available for this artist today</td></tr>'
      : sortedArtistWorks.map((item) {
          final isCurrentBooking = item.id == booking.id;
          return '''
<tr${isCurrentBooking ? ' class="current-work-row"' : ''}>
  <td>${isCurrentBooking ? '<span class="current-badge">Current</span>' : ''}</td>
  <td>${_formatTime(item.serviceStart)} - ${_formatTime(item.serviceEnd)}</td>
  <td>${_escape(item.customerName)}</td>
  <td>${_escape(item.phone)}</td>
  <td>${_escape(item.secondaryContact.isEmpty ? '-' : item.secondaryContact)}</td>
  <td>${_escape(item.email.isEmpty ? '-' : item.email)}</td>
  <td>${_escape(item.service)}</td>
  <td>${_escape(item.region.isEmpty ? 'No region' : item.region)}</td>
</tr>''';
        }).join();

  return '''
    <div class="header">
      <div class="title">Booking Details - $title</div>
      <p class="muted">$subtitle</p>
    </div>

    <div class="grid">
      <div class="card">
        <div class="label">Customer</div>
        <div class="value">${_escape(booking.customerName)}</div>
        <p class="muted">${_escape(booking.phone)}${booking.email.isEmpty ? '' : ' • ${_escape(booking.email)}'}</p>
      </div>
      <div class="card">
        <div class="label">Service</div>
        <div class="value">${_escape(booking.service)}</div>
        <p class="muted">${_escape(booking.region.isEmpty ? 'No region selected' : booking.region)}${booking.driverName.isEmpty ? '' : ' • Driver: ${_escape(booking.driverName)}'}</p>
      </div>
      <div class="card">
        <div class="label">Booking Date</div>
        <div class="value">${_formatDate(booking.bookingDate)}</div>
        <p class="muted">${_formatTime(booking.serviceStart)} - ${_formatTime(booking.serviceEnd)}</p>
      </div>
      <div class="card">
        <div class="label">Booking ID</div>
        <div class="value">${_escape(booking.id)}</div>
        <p class="muted">Status: ${_escape(statusLabel)}</p>
      </div>
    </div>

    <div class="section">
      <h3>Client Details</h3>
      <table class="detail-table">
        <tbody>
          ${clientRows.isEmpty ? '<tr><td colspan="2">No client details available</td></tr>' : clientRows}
        </tbody>
      </table>
    </div>

    <div class="section">
      <h3>Artist & Package Details</h3>
      <table class="detail-table">
        <tbody>
          ${artistRows.isEmpty ? '<tr><td colspan="2">No artist/package details available</td></tr>' : artistRows}
        </tbody>
      </table>
    </div>

    ${isArtistCopy ? '''
    <div class="section">
      <h3>Logistics & Location</h3>
      <table class="detail-table">
        <tbody>
          ${logisticsRows.isEmpty ? '<tr><td colspan="2">No logistics details added</td></tr>' : logisticsRows}
        </tbody>
      </table>
    </div>

    <div class="section">
      <h3>Service Specifics</h3>
      <table class="detail-table">
        <tbody>
          ${serviceRows.isEmpty ? '<tr><td colspan="2">No service-specific details added</td></tr>' : serviceRows}
        </tbody>
      </table>
    </div>
    ''' : ''}

    ${isArtistCopy ? '''
    <div class="section">
      <h3>Assigned Team</h3>
      <table>
        <thead>
          <tr><th>Name</th><th>Role</th><th>Type</th></tr>
        </thead>
        <tbody>
          $assignedStaffRows
        </tbody>
      </table>
    </div>

    <div class="section">
      <h3>Today's Artist Works</h3>
      <p class="schedule-note">${_escape(effectiveArtistName.isEmpty ? 'Assigned artist' : effectiveArtistName)} schedule for ${_formatDate(booking.bookingDate)}, sorted by time.</p>
      <table>
        <thead>
          <tr><th>Current</th><th>Time</th><th>Client</th><th>Service</th><th>Region</th></tr>
        </thead>
        <tbody>
          ${sortedArtistWorks.isEmpty ? artistWorkRows : sortedArtistWorks.map((item) {
                final isCurrentBooking = item.id == booking.id;
                return '<tr${isCurrentBooking ? ' class="current-work-row"' : ''}><td>${isCurrentBooking ? '<span class="current-badge">Current</span>' : ''}</td><td>${_formatTime(item.serviceStart)} - ${_formatTime(item.serviceEnd)}</td><td>${_escape(item.customerName)}</td><td>${_escape(item.service)}</td><td>${_escape(item.region.isEmpty ? 'No region' : item.region)}</td></tr>';
              }).join()}
        </tbody>
      </table>
    </div>

    <div class="section">
      <h3>Today's Client Details</h3>
      <p class="schedule-note">Combined client sheet for all works assigned to ${_escape(effectiveArtistName.isEmpty ? 'this artist' : effectiveArtistName)} today.</p>
      <table>
        <thead>
          <tr><th>Current</th><th>Time</th><th>Client</th><th>Primary</th><th>Alternative</th><th>Email</th><th>Package</th><th>Region</th></tr>
        </thead>
        <tbody>
          $artistClientDetailRows
        </tbody>
      </table>
    </div>
    ''' : ''}

    <div class="section">
      <h3>Add-ons</h3>
      <table>
        <thead>
          <tr><th>Service</th><th>Persons</th><th>Rate</th><th>Total</th></tr>
        </thead>
        <tbody>
          $addonRows
        </tbody>
      </table>
    </div>

    <div class="summary">
      <div class="summary-row"><span>Total Amount</span><span>INR ${booking.totalPrice.toStringAsFixed(0)}</span></div>
      <div class="summary-row"><span>Advance Paid</span><span>INR ${booking.advanceAmount.toStringAsFixed(0)}</span></div>
      <div class="summary-row"><span>Discount</span><span>$discountLabel</span></div>
      <div class="summary-row"><span>Applied Discount Amount</span><span>INR ${booking.discountAmount.toStringAsFixed(0)}</span></div>
      <div class="summary-row"><strong>Forecast Balance</strong><strong>INR ${forecast.toStringAsFixed(0)}</strong></div>
    </div>
''';
}

String _buildClientConfirmationHtml(Booking booking) {
  final addonSummary = booking.addons.isEmpty
      ? 'Nil'
      : booking.addons
            .map((addon) => '${addon.service} x${addon.persons}')
            .join(', ');
  final outfitSummary = booking.outfitDetails.trim().isEmpty
      ? 'To be confirmed'
      : booking.outfitDetails.trim();
  final remainingBalance =
      booking.totalPrice - booking.advanceAmount - booking.discountAmount;

  return '''
    <div class="client-confirmation">
      <div class="client-brand">
        <h1>Team N Makeovers</h1>
        <p>Client Booking Confirmation</p>
      </div>

      <div class="client-greeting">Dear ${_escape(booking.customerName)},</div>
      <p class="client-intro">
        We are delighted to confirm your booking with Team N Makeovers for your upcoming event. Here are the basic details:
      </p>

      <div class="client-detail-block">
        <h3>Basic Details</h3>
        <div class="client-detail-line"><strong>Bride's Name :</strong> ${_escape(booking.customerName)}</div>
        <div class="client-detail-line"><strong>Booking Date :</strong> ${_escape(_formatMonthYear(booking.bookingDate))}</div>
        <div class="client-detail-line"><strong>Event Date &amp; Time :</strong> ${_escape(_formatLongDate(booking.serviceStart))}</div>
        <div class="client-detail-line"><strong>Get Ready Time :</strong> ${_escape('${_formatTime(booking.serviceStart)} - ${_formatTime(booking.serviceEnd)}')}</div>
        <div class="client-detail-line"><strong>Location :</strong> ${_escape(booking.region.isEmpty ? 'To be confirmed' : booking.region)}</div>
        <div class="client-detail-line"><strong>Package :</strong> ${_escape(booking.service)}</div>
        <div class="client-detail-line"><strong>Outfit :</strong> ${_escape(outfitSummary)}</div>
        <div class="client-detail-line"><strong>Add Ons :</strong> ${_escape(addonSummary)}</div>
        <div class="client-detail-line"><strong>Phone :</strong> ${_escape(booking.phone)}</div>
        <div class="client-detail-line"><strong>Email :</strong> ${_escape(booking.email)}</div>
      </div>

      <div class="client-finance">
        <div class="client-finance-card">
          <div class="finance-label">Advance Paid</div>
          <div class="finance-value">INR ${booking.advanceAmount.toStringAsFixed(0)}</div>
        </div>
        <div class="client-finance-card">
          <div class="finance-label">Total Amount</div>
          <div class="finance-value">INR ${booking.totalPrice.toStringAsFixed(0)}</div>
        </div>
        <div class="client-finance-card">
          <div class="finance-label">Discount</div>
          <div class="finance-value">INR ${booking.discountAmount.toStringAsFixed(0)}</div>
        </div>
        <div class="client-finance-card">
          <div class="finance-label">Remaining Payment Due</div>
          <div class="finance-value">INR ${remainingBalance.toStringAsFixed(0)}</div>
        </div>
      </div>

      <div class="client-terms">
        <h3>Terms and Conditions</h3>
        <ol>
          <li>Addon Services: Any additional services beyond the package will be discussed separately and added to the final invoice accordingly.</li>
          <li>Time and Date Change: Any request for changes in time or date should be discussed and confirmed with us in advance. We will do our best to accommodate changes, subject to availability.</li>
          <li>Change in Outfit: If there is a change in the chosen outfit, please inform us at the earliest convenience. This helps our team plan and execute the styling properly for the revised look.</li>
        </ol>
      </div>
    </div>
''';
}

String _formatDate(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  return '$day/$month/${value.year}';
}

String _formatMonthYear(DateTime value) {
  const months = [
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];
  return '${months[value.month - 1]} ${value.year}';
}

String _formatLongDate(DateTime value) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${months[value.month - 1]} ${value.day}, ${value.year}';
}

String _formatTime(DateTime value) {
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  final meridiem = value.hour < 12 ? 'AM' : 'PM';
  return '$hour:$minute $meridiem';
}

String _escape(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');
}

String _detailRow(String label, String value) {
  if (value.trim().isEmpty) return '';
  return '<tr><td>${_escape(label)}</td><td>${_escape(value)}</td></tr>';
}

String _titleCase(String value) {
  if (value.isEmpty) return value;
  return value[0].toUpperCase() + value.substring(1).toLowerCase();
}
