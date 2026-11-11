// Rupees as people read them: ₹1,25,000 (Indian grouping), and an amount as people type it.

/// ₹1,25,000 (Indian grouping), ₹1,250.50 — and no ".00".
String rupees(double v) {
  final whole = v == v.roundToDouble();
  final fixed = whole ? v.round().toString() : v.toStringAsFixed(2);
  final parts = fixed.split('.');
  final digits = parts[0];
  final last3 = digits.length > 3 ? digits.substring(digits.length - 3) : digits;
  var rest = digits.length > 3 ? digits.substring(0, digits.length - 3) : '';
  final groups = <String>[];
  while (rest.length > 2) {
    groups.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) groups.insert(0, rest);
  final grouped = groups.isEmpty ? last3 : '${groups.join(',')},$last3';
  return '₹$grouped${parts.length > 1 ? '.${parts[1]}' : ''}';
}

/// An amount typed by a person ("1,25,000", "1250.5"), or null when it is not a number.
double? parseAmount(String text) {
  final t = text.replaceAll(',', '').replaceAll('₹', '').trim();
  if (t.isEmpty) return null;
  final v = double.tryParse(t);
  return (v == null || v.isNaN || v.isInfinite || v < 0) ? null : v;
}
