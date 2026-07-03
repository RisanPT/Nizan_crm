import re

with open('lib/core/utils/booking_print_service_mobile.dart', 'r') as f:
    mob = f.read()
mob = mob.replace(
    "'${variant == BookingPrintVariant.client ? \"Client\" : \"Artist\"}_Booking_${booking.displayBookingNumber}_$cleanName.pdf';",
    "'${(variant == BookingPrintVariant.clientInvoice || variant == BookingPrintVariant.clientConfirmation) ? \"Client\" : \"Artist\"}_Booking_${booking.displayBookingNumber}_$cleanName.pdf';"
)
# Hide GST for clientConfirmation in mobile
mob = mob.replace(
    "if (pkgCgst > 0 || pkgSgst > 0) ...[",
    "if (variant != BookingPrintVariant.clientConfirmation && (pkgCgst > 0 || pkgSgst > 0)) ...["
)
mob = mob.replace(
    "if (totalCgst > 0 || totalSgst > 0) ...[",
    "if (variant != BookingPrintVariant.clientConfirmation && (totalCgst > 0 || totalSgst > 0)) ...["
)

with open('lib/core/utils/booking_print_service_mobile.dart', 'w') as f:
    f.write(mob)


with open('lib/core/utils/booking_print_service_web.dart', 'r') as f:
    web = f.read()

# isArtistCopy
web = web.replace(
    "final isArtistCopy = variant == BookingPrintVariant.artist;",
    "final isClientCopy = variant == BookingPrintVariant.clientInvoice || variant == BookingPrintVariant.clientConfirmation;\n  if (!isClientCopy) {\n    // fallback to artist copy if not client\n  }"
)
# Wait, let's just make it simple:
web = web.replace(
    "if (!isArtistCopy) {\n    return _buildClientConfirmationHtml(booking);\n  }",
    "if (!isArtistCopy) {\n    return _buildClientConfirmationHtml(booking, variant);\n  }"
)
web = web.replace(
    "String _buildClientConfirmationHtml(Booking booking) {",
    "String _buildClientConfirmationHtml(Booking booking, BookingPrintVariant variant) {"
)
web = web.replace(
    '<div class="inv-doc-type">GST INVOICE — ORIGINAL COPY</div>',
    '<div class="inv-doc-type">${variant == BookingPrintVariant.clientConfirmation ? "BOOKING CONFIRMATION" : "GST INVOICE — ORIGINAL COPY"}</div>'
)
# Hide GST columns for web
web = web.replace(
    '<th class="right">CGST</th><th class="right">SGST</th>',
    '${variant == BookingPrintVariant.clientConfirmation ? "" : "<th class=\\"right\\">CGST</th><th class=\\"right\\">SGST</th>"}'
)
web = web.replace(
    '<td class="right">${_inr(pkgCgst)}</td>\n  <td class="right">${_inr(pkgSgst)}</td>',
    '${variant == BookingPrintVariant.clientConfirmation ? "" : "<td class=\\"right\\">${_inr(pkgCgst)}</td><td class=\\"right\\">${_inr(pkgSgst)}</td>"}'
)
web = web.replace(
    '<td class="right">${_inr(addonCgst)}</td>\n  <td class="right">${_inr(addonSgst)}</td>',
    '${variant == BookingPrintVariant.clientConfirmation ? "" : "<td class=\\"right\\">${_inr(addonCgst)}</td><td class=\\"right\\">${_inr(addonSgst)}</td>"}'
)
web = web.replace(
    '<tr class="sum-row"><td colspan="2" class="right sum-label">Add: CGST</td><td class="right sum-val">${_inr(totalCgst)}</td></tr>',
    '${variant == BookingPrintVariant.clientConfirmation ? "" : "<tr class=\\"sum-row\\"><td colspan=\\"2\\" class=\\"right sum-label\\">Add: CGST</td><td class=\\"right sum-val\\">${_inr(totalCgst)}</td></tr>"}'
)
web = web.replace(
    '<tr class="sum-row"><td colspan="2" class="right sum-label">Add: SGST</td><td class="right sum-val">${_inr(totalSgst)}</td></tr>',
    '${variant == BookingPrintVariant.clientConfirmation ? "" : "<tr class=\\"sum-row\\"><td colspan=\\"2\\" class=\\"right sum-label\\">Add: SGST</td><td class=\\"right sum-val\\">${_inr(totalSgst)}</td></tr>"}'
)
web = web.replace(
    '<tr class="sum-row gst-breakdown-row"><td colspan="2" class="right sum-label" style="font-size:12px;">Total GST</td><td class="right sum-val" style="font-size:12px;">${_inr(totalGst)}</td></tr>',
    '${variant == BookingPrintVariant.clientConfirmation ? "" : "<tr class=\\"sum-row gst-breakdown-row\\"><td colspan=\\"2\\" class=\\"right sum-label\\" style=\\"font-size:12px;\\">Total GST</td><td class=\\"right sum-val\\" style=\\"font-size:12px;\\">${_inr(totalGst)}</td></tr>"}'
)

with open('lib/core/utils/booking_print_service_web.dart', 'w') as f:
    f.write(web)
