import 'package:flutter/material.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/models/salary.dart';
import 'package:nizan_crm/features/accounts/utils/payslip_pdf.dart';

/// "Download payslip" action for payslip view dialogs and lists.
/// Builds the shared payslip PDF and downloads (web) / shares (mobile) it.
class PayslipDownloadButton extends StatefulWidget {
  final Salary salary;
  final bool filled;
  const PayslipDownloadButton({super.key, required this.salary, this.filled = true});

  @override
  State<PayslipDownloadButton> createState() => _PayslipDownloadButtonState();
}

class _PayslipDownloadButtonState extends State<PayslipDownloadButton> {
  bool _busy = false;

  Future<void> _download() async {
    setState(() => _busy = true);
    try {
      await downloadPayslipPdf(widget.salary);
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final icon = _busy
        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
        : const Icon(Icons.download_rounded, size: 18);
    const label = Text('Download payslip');
    return widget.filled
        ? FilledButton.icon(onPressed: _busy ? null : _download, icon: icon, label: label)
        : OutlinedButton.icon(onPressed: _busy ? null : _download, icon: icon, label: label);
  }
}
