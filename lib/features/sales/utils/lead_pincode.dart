/// A 6-digit Indian pincode written inside some text — "Beach Road, Calicut 673001", "673 001" —
/// or null when there is none. A run of digits that is part of a longer number (a phone number, an
/// amount) is not a pincode.
String? pincodeIn(String text) {
  final m = RegExp(r'(?<!\d)([1-9]\d{2})\s?(\d{3})(?!\d)').firstMatch(text);
  return m == null ? null : '${m[1]}${m[2]}';
}

/// Is this a label for a pincode in a pasted "Label: value" line? ("Pincode", "PIN code", "Pin",
/// "Zip", "Postal code".) "Pinterest" or "mapping" are not.
bool isPincodeLabel(String label) {
  final k = label.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
  return const {
    'pincode',
    'pin',
    'zip',
    'zipcode',
    'postalcode',
    'postcode',
  }.contains(k);
}
