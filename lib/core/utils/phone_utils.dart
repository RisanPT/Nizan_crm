/// Phone numbers are typed with spaces and dashes ("70341 09552", "+91 98954
/// 99872"), which breaks equality checks and the lead↔booking matching that
/// links a converted lead to the work it produced.
///
/// [normalizePhone] strips all whitespace while preserving a leading country
/// code, mirroring the setter applied on the backend models.
String normalizePhone(String? raw) =>
    (raw ?? '').replaceAll(RegExp(r'\s+'), '').trim();

/// The comparable form of a number: digits only, last 10 kept, so that
/// "+91 70341 09552", "070341-09552" and "7034109552" all match.
String phoneMatchKey(String? raw) {
  final digits = (raw ?? '').replaceAll(RegExp(r'\D'), '');
  return digits.length > 10 ? digits.substring(digits.length - 10) : digits;
}
