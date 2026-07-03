/// GST calculation utilities for Team N Makeovers invoices.
///
/// The business uses **GST Inclusive @ 5%** (CGST 2.5% + SGST 2.5%).
/// This means the price paid by the customer ALREADY contains GST inside it.
///
/// Formulas (for a given [totalInclusive]):
///   Base Amount  = total × 100 / 105
///   CGST @ 2.5%  = total × 2.5  / 105
///   SGST @ 2.5%  = total × 2.5  / 105
///   Total GST    = CGST + SGST   (= total × 5 / 105)
///
/// All results are rounded to 2 decimal places.
class GstCalculator {
  GstCalculator._(); // prevent instantiation

  static const double gstRatePercent  = 5.0;
  static const double cgstRatePercent = 2.5;
  static const double sgstRatePercent = 2.5;

  /// Default SAC (Service Accounting Code) for beauty & wellness services.
  static const String defaultSacCode = '998361';

  // ── Core formulas ───────────────────────────────────────────────────────────

  /// Base/taxable amount (exclusive of GST) derived from an inclusive total.
  static double baseAmount(double totalInclusive) =>
      _r(totalInclusive * 100.0 / 105.0);

  /// CGST component (2.5%) from an inclusive total.
  static double cgst(double totalInclusive) =>
      _r(totalInclusive * 2.5 / 105.0);

  /// SGST component (2.5%) from an inclusive total.
  static double sgst(double totalInclusive) =>
      _r(totalInclusive * 2.5 / 105.0);

  /// Combined GST (CGST + SGST) from an inclusive total.
  static double totalGst(double totalInclusive) =>
      _r(cgst(totalInclusive) + sgst(totalInclusive));

  // ── Batch helpers ───────────────────────────────────────────────────────────

  /// Returns a [GstBreakdown] for [totalInclusive].
  static GstBreakdown breakdown(double totalInclusive) =>
      GstBreakdown(totalInclusive: totalInclusive);

  // ── Private helpers ─────────────────────────────────────────────────────────

  /// Rounds [value] to 2 decimal places.
  static double _r(double value) =>
      double.parse(value.toStringAsFixed(2));
}

/// Holds a pre-computed GST breakdown for a single inclusive amount.
class GstBreakdown {
  final double totalInclusive;
  late final double base;
  late final double cgst;
  late final double sgst;
  late final double totalGst;

  GstBreakdown({required this.totalInclusive}) {
    base     = GstCalculator.baseAmount(totalInclusive);
    cgst     = GstCalculator.cgst(totalInclusive);
    sgst     = GstCalculator.sgst(totalInclusive);
    totalGst = GstCalculator.totalGst(totalInclusive);
  }
}
