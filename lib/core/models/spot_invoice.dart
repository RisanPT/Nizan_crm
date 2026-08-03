/// A single line on a spot quotation/invoice.
class SpotInvoiceLine {
  final String label;
  final double amount;

  const SpotInvoiceLine({required this.label, required this.amount});
}

/// Data for a salesperson's on-the-spot quotation/invoice (no GST).
class SpotInvoiceData {
  final String invoiceNo;
  final String customerName;
  final String customerPhone;
  final List<SpotInvoiceLine> lines;
  final DateTime date;
  final String note;

  const SpotInvoiceData({
    required this.invoiceNo,
    required this.customerName,
    this.customerPhone = '',
    required this.lines,
    required this.date,
    this.note = '',
  });

  double get total => lines.fold<double>(0, (s, l) => s + l.amount);
}
