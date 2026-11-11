// What staff type into a booking's map field → something a browser can open.

/// A browsable link for what staff typed into the booking's map field: a full
/// link as it is, or plain "lat, lng" coordinates as a Google Maps search.
Uri? mapLaunchUri(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;
  if (RegExp(r'^https?://', caseSensitive: false).hasMatch(text)) return Uri.tryParse(text);
  final m = RegExp(r'^(-?\d{1,3}(?:\.\d+)?)\s*,\s*(-?\d{1,3}(?:\.\d+)?)$').firstMatch(text);
  if (m == null) return null;
  return Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': '${m[1]},${m[2]}'});
}
