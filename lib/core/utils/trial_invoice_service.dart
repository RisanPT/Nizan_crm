import 'package:nizan_crm/core/models/trial.dart';

import 'trial_invoice_stub.dart'
    if (dart.library.io) 'trial_invoice_mobile.dart'
    if (dart.library.html) 'trial_invoice_web.dart' as impl;

/// Generates a printable trial invoice (no GST). Web → browser print dialog;
/// mobile → PDF share sheet.
Future<void> printTrialInvoice(Trial trial) => impl.printTrialInvoice(trial);
