with open('lib/core/utils/booking_print_service_mobile.dart', 'r') as f:
    content = f.read()

# Replace BookingPrintVariant.client with BookingPrintVariant.clientInvoice where appropriate
content = content.replace(
    "variant == BookingPrintVariant.client ? 'TAX INVOICE & CONFIRMATION' : 'Artist Copy - Assignment Sheet'",
    "variant == BookingPrintVariant.clientConfirmation ? 'BOOKING CONFIRMATION' : variant == BookingPrintVariant.clientInvoice ? 'TAX INVOICE & CONFIRMATION' : 'Artist Copy - Assignment Sheet'"
)

# For the subtitle, we should show it for both client variants but change text
content = content.replace(
    "if (variant == BookingPrintVariant.client) ...[",
    "if (variant == BookingPrintVariant.clientInvoice || variant == BookingPrintVariant.clientConfirmation) ...["
)

content = content.replace(
    "'GST INVOICE — ORIGINAL COPY',",
    "variant == BookingPrintVariant.clientConfirmation ? 'BOOKING CONFIRMATION' : 'GST INVOICE — ORIGINAL COPY',"
)

# Hide GST table if clientConfirmation
# Find where GST table is generated. Usually "pw.Table" after "Service/Items"
# Or just hide the CGST / SGST columns. 
# It's probably easier to hide the GST columns in the table headers and rows.
# Let's see the GST table logic first...
with open('lib/core/utils/booking_print_service_mobile.dart', 'w') as f:
    f.write(content)
