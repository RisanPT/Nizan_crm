import 'package:flutter/material.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/state/data_refresh.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nizan_crm/features/fleet/controllers/fleet_controller.dart';
import 'package:nizan_crm/features/fleet/data/fleet_models.dart';
import 'accident_report_screen.dart';
import 'driver_day.dart';

class ActiveJobScreen extends ConsumerStatefulWidget {
  final String jobId;
  const ActiveJobScreen({super.key, required this.jobId});

  @override
  ConsumerState<ActiveJobScreen> createState() => _ActiveJobScreenState();
}

class _ActiveJobScreenState extends ConsumerState<ActiveJobScreen> {
  bool _isCompleting = false;

  // Artist trip OTP — verified during the trip once the artist is in the car;
  // required before the trip can be closed.
  final _otpCtrl = TextEditingController();
  bool _verifyingOtp = false;
  String? _otpError;

  @override
  void dispose() {
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _verifyOtp(FleetJob job) async {
    final otp = _otpCtrl.text.trim();
    if (otp.length != 4) {
      setState(() => _otpError = 'Enter all 4 digits');
      return;
    }
    setState(() {
      _verifyingOtp = true;
      _otpError = null;
    });
    try {
      await ref.read(fleetServiceProvider).verifyArtistOtp(job.id, otp);
      ref.refreshData
        ..fleetJobs()
        ..bookings(); // the artist's schedule shows "verified"
      if (mounted) {
        _otpCtrl.clear();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Artist OTP verified ✓'),
          backgroundColor: Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) setState(() => _otpError = friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _verifyingOtp = false);
    }
  }

  Widget _buildOtpCard(FleetJob job) {
    const brand = Color(0xFF4A1942);
    const green = Color(0xFF2E7D32);
    final verified = job.artistOtpVerifiedAt != null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: verified
              ? green.withValues(alpha: 0.5)
              : Colors.orange.withValues(alpha: 0.6),
          width: 1.3,
        ),
      ),
      child: verified
          ? Row(children: [
              const Icon(Icons.verified_rounded, color: green),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Artist OTP verified · ${TimeOfDay.fromDateTime(job.artistOtpVerifiedAt!.toLocal()).format(context)}',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: green),
                ),
              ),
            ])
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [
                  Icon(Icons.verified_user_outlined, color: brand),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Artist Trip OTP',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  ),
                  Text('NEEDED TO CLOSE',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.orange)),
                ]),
                const SizedBox(height: 6),
                Text(
                  "Once the artist / assistant is in the car, ask for the 4-digit OTP on their schedule and verify it here.",
                  style: TextStyle(fontSize: 12.5, color: Colors.grey[700]),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _otpCtrl,
                        enabled: !_verifyingOtp,
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 12),
                        onChanged: (_) {
                          if (_otpError != null) setState(() => _otpError = null);
                        },
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: '••••',
                          errorText: _otpError,
                          errorMaxLines: 3,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: _verifyingOtp ? null : () => _verifyOtp(job),
                        style: FilledButton.styleFrom(backgroundColor: brand),
                        child: _verifyingOtp
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Text('Verify'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final jobsAsync = ref.watch(driverJobsProvider);

    return jobsAsync.when(
      data: (jobs) {
        final job = jobs.cast<FleetJob?>().firstWhere(
              (j) => j?.id == widget.jobId,
              orElse: () => null,
            );

        if (job == null) {
          return _buildNotFound(context);
        }

        return _buildScreen(context, job);
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFF4A1942))),
      ),
      error: (err, _) => Scaffold(
        appBar: AppBar(),
        body: AppErrorView(
            error: err, onRetry: () => ref.invalidate(driverJobsProvider)),
      ),
    );
  }

  Widget _buildScreen(BuildContext context, FleetJob job) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: Column(
        children: [
          _buildHeader(context, job),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildStatusCard(job),
                  const SizedBox(height: 14),
                  _buildJobDetailsCard(job),
                  const SizedBox(height: 14),
                  if (job.preTripPhotos.isNotEmpty)
                    _buildPhotosCard(job),
                  const SizedBox(height: 28),
                  // Completed / accident trips are view-only — completing
                  // again is refused by the server.
                  if (job.tripStatus == 'in_progress') ...[
                    if (job.requiresArtistOtp) ...[
                      _buildOtpCard(job),
                      const SizedBox(height: 16),
                    ],
                    _buildCompleteButton(context, job),
                    const SizedBox(height: 12),
                    _buildAddExpenseButton(context, job),
                    const SizedBox(height: 12),
                    _buildAccidentButton(context, job),
                  ],
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, FleetJob job) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF388E3C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 16),
          child: Row(
            children: [
              IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white70, size: 20),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        job.tripStatus == 'in_progress' ? 'Active Job' : 'Trip Details',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800)),
                    Text(job.customerName,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.directions_car_rounded,
                        color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Text(_statusLabel(job.tripStatus),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _statusLabel(String status) => switch (status) {
        'in_progress' => 'In Progress',
        'completed' => 'Completed',
        'accident' => 'Accident',
        _ => 'Not Started',
      };

  Widget _buildStatusCard(FleetJob job) {
    if (job.tripStatus != 'in_progress') return _buildDoneCard(job);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF4CAF50).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: const Color(0xFF4CAF50).withValues(alpha: 0.25), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.local_shipping_rounded,
                color: Color(0xFF2E7D32), size: 28),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Trip In Progress',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1B5E20))),
                SizedBox(height: 3),
                Text('Drive safely. Complete the job when you arrive.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF388E3C))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Status card for a trip that is no longer in progress, with its km.
  Widget _buildDoneCard(FleetJob job) {
    final accident = job.tripStatus == 'accident';
    final color = accident ? const Color(0xFFC62828) : const Color(0xFF455A64);
    final km = job.tripKm;
    final kmLine = [
      if (job.startKm != null) 'Start ${formatKm(job.startKm!)} km',
      if (job.endKm != null) 'End ${formatKm(job.endKm!)} km',
      if (km != null) '${formatKm(km)} km driven',
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(
              accident
                  ? Icons.warning_amber_rounded
                  : Icons.check_circle_rounded,
              color: color,
              size: 32),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    accident
                        ? 'Accident reported'
                        : job.tripStatus == 'completed'
                            ? 'Trip completed'
                            : 'Trip not started',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: color)),
                const SizedBox(height: 3),
                Text(
                  kmLine.isEmpty ? 'No km recorded for this trip' : kmLine,
                  style: TextStyle(fontSize: 12, color: color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJobDetailsCard(FleetJob job) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Job Details',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A2E))),
          const SizedBox(height: 12),
          _buildDetailRow(Icons.person_outline_rounded, 'Customer',
              job.customerName, const Color(0xFF4A1942)),
          _buildDetailRow(Icons.confirmation_number_outlined, 'Booking',
              '#${job.bookingNumber}', Colors.grey),
          _buildDetailRow(Icons.design_services_outlined, 'Service',
              job.service, const Color(0xFF6C63FF)),
          if (job.eventSlot != null && job.eventSlot!.isNotEmpty)
            _buildDetailRow(Icons.event_available_outlined, 'Slot',
                job.eventSlot!, const Color(0xFF009688)),
          if (job.address != null && job.address!.isNotEmpty)
            _buildDetailRow(Icons.location_on_outlined, 'Location',
                job.address!, const Color(0xFF4CAF50)),
          if (job.pocName != null && job.pocName!.isNotEmpty)
            _buildDetailRow(Icons.contact_phone_outlined, 'POC',
                '${job.pocName}${job.pocPhone != null ? " · ${job.pocPhone}" : ""}',
                const Color(0xFF2196F3)),
          if (job.startKm != null)
            _buildDetailRow(Icons.speed_rounded, 'Starting km',
                '${formatKm(job.startKm!)} km', const Color(0xFFE65100)),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
      IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Text('$label: ',
              style: TextStyle(
                  fontSize: 13, color: Colors.grey[500], fontWeight: FontWeight.w500)),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF1A1A2E),
                    fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotosCard(FleetJob job) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.camera_alt_outlined,
                  color: Color(0xFF4A1942), size: 16),
              const SizedBox(width: 6),
              Text('Pre-Trip Photos (${job.preTripPhotos.length})',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1A2E))),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: job.preTripPhotos.length,
              itemBuilder: (_, i) => Container(
                width: 80,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  image: DecorationImage(
                    image: NetworkImage(job.preTripPhotos[i]),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompleteButton(BuildContext context, FleetJob job) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isCompleting ? null : () => _confirmComplete(context, job),
        icon: _isCompleting
            ? const SizedBox(
                width: 18,
                height: 18,
                child:
                    CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
            : const Icon(Icons.check_circle_outline_rounded, size: 22),
        label: Text(
          _isCompleting ? 'Completing...' : 'Complete Job',
          style:
              const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2E7D32),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 3,
        ),
      ),
    );
  }

  Widget _buildAddExpenseButton(BuildContext context, FleetJob job) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _isCompleting ? null : () => context.push('/driver/works/${job.id}/expense'),
        icon: const Icon(Icons.receipt_long_rounded, size: 20, color: Color(0xFF1976D2)),
        label: const Text('Add Expense', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1976D2))),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFF2196F3), width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Widget _buildAccidentButton(BuildContext context, FleetJob job) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _isCompleting
            ? null
            : () => _openAccidentReport(context, job),
        icon: const Icon(Icons.warning_amber_rounded,
            size: 20, color: Color(0xFFB71C1C)),
        label: const Text('Report Accident',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFFB71C1C))),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFE53935), width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Widget _buildNotFound(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded, size: 56, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Job not found'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => context.go('/driver/jobs'),
              child: const Text('Back to Dashboard'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmComplete(BuildContext context, FleetJob job) async {
    final jobs = ref.read(driverJobsProvider).value ?? const <FleetJob>[];
    // The next trip of the day, if any — offered right here so the driver
    // completes this one and starts that one in a single tap.
    final next = nextTripAfter(jobs, job);
    final carryKm = next != null && sameVehicle(job, next);
    final isLastJob = next == null;

    String? parkedLocation;
    double? endKm;
    double? nextKm;
    var startNext = next != null;
    final locCtrl = TextEditingController();
    final kmCtrl = TextEditingController();
    final nextKmCtrl = TextEditingController();
    String? kmError;
    String? nextKmError;
    // Artist OTP not verified during the trip → it must be entered here.
    final needOtp = job.artistOtpPending;
    final otpCtrl = TextEditingController(text: _otpCtrl.text.trim());
    String? otpError;
    String? artistOtp;

    double? parse(TextEditingController c) {
      final v = double.tryParse(c.text.replaceAll(',', '').trim());
      return (v == null || v < 0) ? null : v;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) {
          final km = parse(kmCtrl);
          final driven =
              (km != null && job.startKm != null) ? km - job.startKm! : null;
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32)),
                SizedBox(width: 8),
                Expanded(
                    child: Text('Complete trip', style: TextStyle(fontSize: 18))),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${job.customerName} · this cannot be undone.',
                      style: const TextStyle(fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 16),
                  const Text('Ending km',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    job.startKm != null
                        ? 'Odometer reading now. Started at ${formatKm(job.startKm!)} km.'
                        : 'Odometer reading shown on the vehicle now.',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: kmCtrl,
                    autofocus: true,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setDialog(() => kmError = null),
                    decoration: InputDecoration(
                      hintText: job.startKm != null
                          ? 'e.g. ${formatKm(job.startKm!)}'
                          : 'e.g. 45310',
                      suffixText: 'km',
                      errorText: kmError,
                      helperText: driven != null && driven >= 0
                          ? 'Trip distance: ${formatKm(driven)} km'
                          : null,
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                  ),
                  if (needOtp) ...[
                    const SizedBox(height: 16),
                    const Text('Artist Trip OTP',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    const Text(
                      "Not verified yet — enter the artist's 4-digit OTP to close this trip.",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: otpCtrl,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 10),
                      onChanged: (_) => setDialog(() => otpError = null),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: '••••',
                        errorText: otpError,
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                    ),
                  ],
                  if (next != null) ...[
                    const SizedBox(height: 18),
                    NextTripCard(job: next, label: 'Next trip today'),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: startNext,
                      onChanged: (v) => setDialog(() => startNext = v),
                      title: const Text('Start this trip now',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        !startNext
                            ? "You'll start it later from the dashboard"
                            : carryKm
                                ? 'Starts at your ending km — same vehicle'
                                : 'Different vehicle — enter its starting km',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    if (startNext && !carryKm)
                      TextField(
                        controller: nextKmCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        onChanged: (_) => setDialog(() => nextKmError = null),
                        decoration: InputDecoration(
                          labelText:
                              'Starting km · ${vehicleLabelOf(next).isEmpty ? 'next vehicle' : vehicleLabelOf(next)}',
                          suffixText: 'km',
                          errorText: nextKmError,
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                        ),
                      ),
                  ],
                  if (isLastJob) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8)),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: Colors.orange, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                              child: Text('This is your last trip today!',
                                  style: TextStyle(
                                      color: Colors.orange,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Where is the vehicle parked?',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: locCtrl,
                      decoration: const InputDecoration(
                        hintText: 'e.g., Office Parking, Home, etc.',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () {
                  final km = parse(kmCtrl);
                  if (km == null) {
                    setDialog(() => kmError = 'Enter the ending km reading');
                    return;
                  }
                  if (job.startKm != null && km < job.startKm!) {
                    setDialog(() => kmError =
                        "Can't be less than the starting ${formatKm(job.startKm!)} km");
                    return;
                  }
                  if (needOtp) {
                    final o = otpCtrl.text.trim();
                    if (o.length != 4) {
                      setDialog(() =>
                          otpError = "Enter the artist's 4-digit OTP to close the trip");
                      return;
                    }
                    artistOtp = o;
                  }
                  if (startNext && !carryKm) {
                    final nk = parse(nextKmCtrl);
                    if (nk == null) {
                      setDialog(() =>
                          nextKmError = "Enter the next vehicle's starting km");
                      return;
                    }
                    nextKm = nk;
                  }
                  if (isLastJob && locCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                        content:
                            Text('Please enter where you parked the vehicle.')));
                    return;
                  }
                  endKm = km;
                  parkedLocation = locCtrl.text.trim();
                  Navigator.pop(ctx, true);
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white),
                child: Text(next != null && startNext
                    ? 'Complete & start next'
                    : 'Complete'),
              ),
            ],
          );
        },
      ),
    );
    locCtrl.dispose();
    kmCtrl.dispose();
    nextKmCtrl.dispose();
    otpCtrl.dispose();

    if (confirmed != true || endKm == null || !mounted) return;

    // ignore: use_build_context_synchronously
    final messenger = ScaffoldMessenger.of(context);
    // ignore: use_build_context_synchronously
    final router = GoRouter.of(context);

    setState(() => _isCompleting = true);
    try {
      final res = await ref.read(fleetServiceProvider).completeJob(
            jobId: job.id,
            endKm: endKm!,
            parkedLocation:
                parkedLocation?.isNotEmpty == true ? parkedLocation : null,
            startNextJobId: next != null && startNext ? next.id : null,
            nextStartKm: nextKm,
            artistOtp: artistOtp,
          );
      // Jobs are bookings (tripStatus) and the vehicle's km / parking moves.
      ref.refreshData
        ..fleetJobs()
        ..bookings()
        ..vehicles();
      if (mounted) {
        final started = res.nextStarted ? res.nextJob : null;
        messenger.showSnackBar(
          SnackBar(
            content: Text(started != null
                ? 'Trip completed · next trip (${started.customerName}) started'
                : res.isLastJob
                    ? 'All trips done for today! Great work 🎉'
                    : 'Trip completed 🎉'),
            backgroundColor: const Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
          ),
        );
        // Straight into the next trip, or back to the day's list.
        router.go(started != null
            ? '/driver/active_job/${started.id}'
            : '/driver/jobs');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCompleting = false);
        messenger.showSnackBar(
          SnackBar(
            content: Text(friendlyErrorMessage(e)),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _openAccidentReport(BuildContext context, FleetJob job) {
    final v = job.vehicleId;
    final vehicleId = v is Map
        ? (v['_id'] ?? '').toString()
        : (v ?? '').toString();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            AccidentReportScreen(jobId: job.id, vehicleId: vehicleId),
      ),
    );
  }
}
