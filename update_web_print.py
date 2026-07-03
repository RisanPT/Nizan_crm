with open('lib/core/utils/booking_print_service_web.dart', 'r') as f:
    content = f.read()

content = content.replace(
    "BookingPrintVariant.client",
    "BookingPrintVariant.clientInvoice"
)
content = content.replace(
    "variant == BookingPrintVariant.artist",
    "variant == BookingPrintVariant.artist"
)
# We also need to handle clientConfirmation. Let's see how the web variant works.
# Actually, the user doesn't print confirmation from Web often, but manage_booking_screen uses the web stub on web.
# Let's fix the occurrences properly.
