import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nizan_crm/core/extensions/space_extension.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/utils/phone_utils.dart';
import 'package:nizan_crm/features/bookings/data/booking.dart';
import 'package:nizan_crm/features/bookings/controllers/booking_provider.dart';
import 'package:nizan_crm/core/auth/access_control.dart';
import 'package:nizan_crm/core/providers/auth_provider.dart';
import 'package:nizan_crm/models/customer.dart';
import 'package:nizan_crm/services/customer_service.dart';
import 'package:nizan_crm/services/package_service.dart';
import 'package:nizan_crm/services/district_service.dart';
import 'package:nizan_crm/services/addon_service_service.dart';
import 'package:nizan_crm/core/models/addon_service.dart';
import 'package:nizan_crm/core/models/service_package.dart';
import 'package:nizan_crm/core/models/district.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/widgets/hq_distance_line.dart';
import 'package:nizan_crm/core/widgets/pincode_field.dart';

// New Booking — redesigned (Oct 2026).
//
// One flow for every booking: the client, then a PROGRAMME of event days.
// Each day holds one or more package lines (package or custom, district,
// time, slot, add-ons). Whatever is entered here is saved exactly as before —
// ONE booking / one invoice with one bookingItem per package per day — so
// Manage Booking, invoices, the calendar and reports read it unchanged.
//
// Replaces the old Single / Multiple modes: a "single" booking is just one
// day with one package; "Use Day 1's packages for all days" covers a
// multi-day single-package event.

const _kCustom = 'custom'; // packageId of a custom (non-catalogue) line

class AddBookingScreen extends HookConsumerWidget {
  const AddBookingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final asyncPackages = ref.watch(packagesProvider);
    final asyncDistricts = ref.watch(districtsProvider);
    final asyncAddonServices = ref.watch(addonServicesProvider);
    final packages = _uniquePackages(asyncPackages.value ?? const []);
    final districts = _uniqueDistricts(asyncDistricts.value ?? const []);
    final addonServices = (asyncAddonServices.value ?? const <AddonService>[])
        .where((s) => s.status.toLowerCase() == 'active')
        .toList();

    final formKey = useMemoized(() => GlobalKey<FormState>());
    final qParams = GoRouterState.of(context).uri.queryParameters;
    // Prefill from query params — Lead → Booking conversion (lead_conversion.dart).
    final nameCtrl = useMemoized(() => <TextEditingController?>[null]);
    final phoneCtrl = useTextEditingController(text: qParams['phone'] ?? '');
    final emailCtrl = useTextEditingController(text: qParams['email'] ?? '');
    final addressCtrl = useTextEditingController(
      text: qParams['address'] ?? '',
    );
    final pincodeCtrl = useTextEditingController(
      text: qParams['pincode'] ?? '',
    );
    final allowMissingEmail = useState(false);
    final isSubmitting = useState(false);
    // When the booking was MADE (defaults to today; past-date a late entry).
    final bookedDate = useState<DateTime>(DateTime.now());
    final days = useState<List<_Day>>([]);
    final discountType = useState<String>('inr');
    final discountCtrl = useTextEditingController();
    final discountNoteCtrl = useTextEditingController();
    final discountValue = useState<double>(0);
    final showErrors = useState(
      false,
    ); // highlight unfinished lines after a failed save

    ServicePackage? pkgById(String id) {
      for (final p in packages) {
        if (p.id == id) return p;
      }
      return null;
    }

    District? districtById(String id) {
      for (final d in districts) {
        if (d.id == id) return d;
      }
      return null;
    }

    double linePrice(_Line l) => l.packageId == _kCustom
        ? l.customAmount
        : (pkgById(l.packageId)?.effectivePriceForDistrict(l.districtId) ?? 0);
    double lineAdvance(_Line l) => l.packageId == _kCustom
        ? 0
        : (pkgById(l.packageId)?.advanceAmount ?? 0);
    double addonsOf(_Line l) =>
        l.addons.fold<double>(0, (s, a) => s + a.amount * a.persons);

    final allLines = [for (final d in days.value) ...d.lines];
    final total = allLines.fold<double>(
      0,
      (s, l) => s + linePrice(l) + addonsOf(l),
    );
    final advance = allLines.fold<double>(0, (s, l) => s + lineAdvance(l));
    final discount =
        (discountType.value == 'percent'
                ? total * discountValue.value / 100
                : discountValue.value)
            .clamp(0.0, total)
            .toDouble();
    final balance = (total - discount - advance)
        .clamp(0.0, double.infinity)
        .toDouble();

    // ── Programme edits ────────────────────────────────────────────────────
    void setDays(List<_Day> next) {
      next.sort((a, b) => a.date.compareTo(b.date));
      days.value = next;
    }

    void updateLine(int di, int li, _Line line) {
      final next = [...days.value];
      final lines = [...next[di].lines]..[li] = line;
      next[di] = next[di].copyWith(lines: lines);
      days.value = next;
    }

    Future<DateTime?> pickEventDate(DateTime initial) => showDatePicker(
      context: context,
      initialDate: initial,
      // Bridal dates are booked 1–2+ years ahead; older dates allowed for
      // legacy entries — same window as the edit screen.
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );

    bool dateTaken(DateTime d, {int? exceptIndex}) =>
        days.value.asMap().entries.any(
          (e) => e.key != exceptIndex && _dateKey(e.value.date) == _dateKey(d),
        );

    Future<void> addDay() async {
      final last = days.value.isEmpty ? null : days.value.last;
      final picked = await pickEventDate(
        last == null ? DateTime.now() : last.date.add(const Duration(days: 1)),
      );
      if (picked == null || !context.mounted) return;
      final date = DateTime(picked.year, picked.month, picked.day);
      if (dateTaken(date)) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                '${_longDate(date)} is already in the programme — add a package to that day instead.',
              ),
            ),
          );
        return;
      }
      // A new day starts as a visible copy of the latest day's packages (the
      // usual case: same package, next day) — or one empty line to choose.
      final lines = last == null
          ? [_Line.blank()]
          : [for (final l in last.lines) l.copyForNewDay()];
      setDays([...days.value, _Day(date: date, lines: lines)]);
    }

    Future<void> changeDayDate(int di) async {
      final picked = await pickEventDate(days.value[di].date);
      if (picked == null || !context.mounted) return;
      final date = DateTime(picked.year, picked.month, picked.day);
      if (dateTaken(date, exceptIndex: di)) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('${_longDate(date)} is already in the programme.'),
            ),
          );
        return;
      }
      final next = [...days.value];
      next[di] = next[di].copyWith(date: date);
      setDays(next);
    }

    void removeDay(int di) {
      final removed = days.value[di];
      final next = [...days.value]..removeAt(di);
      days.value = next;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Removed ${_longDate(removed.date)}'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () => setDays([...days.value, removed]),
            ),
          ),
        );
    }

    void addLine(int di) {
      final day = days.value[di];
      final prev = day.lines.isEmpty ? null : day.lines.last;
      final next = [...days.value];
      next[di] = day.copyWith(
        lines: [
          ...day.lines,
          _Line.blank(prev: prev),
        ],
      );
      days.value = next;
    }

    void removeLine(int di, int li) {
      final next = [...days.value];
      final lines = [...next[di].lines]..removeAt(li);
      next[di] = next[di].copyWith(lines: lines);
      days.value = next;
    }

    void copyFirstDayToAll() {
      if (days.value.length < 2) return;
      final first = days.value.first;
      setDays([
        first,
        for (final d in days.value.skip(1))
          d.copyWith(lines: [for (final l in first.lines) l.copyForNewDay()]),
      ]);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              "${_longDate(first.date)}'s packages copied to every day — change any day as needed.",
            ),
          ),
        );
    }

    Future<void> pickBookedDate() async {
      final picked = await showDatePicker(
        context: context,
        initialDate: bookedDate.value,
        firstDate: DateTime(2020),
        lastDate:
            DateTime.now(), // a booking can't have been made in the future
      );
      if (picked != null) {
        bookedDate.value = DateTime(picked.year, picked.month, picked.day);
      }
    }

    // ── Save ───────────────────────────────────────────────────────────────
    String? programmeProblem() {
      if (days.value.isEmpty) return 'Add at least one event day.';
      for (final d in days.value) {
        if (d.lines.isEmpty) return 'Add a package to ${_longDate(d.date)}.';
        for (var i = 0; i < d.lines.length; i++) {
          final l = d.lines[i];
          final where =
              '${_longDate(d.date)}${d.lines.length > 1 ? ' (package ${i + 1})' : ''}';
          if (l.packageId.isEmpty) return 'Choose a package for $where.';
          if (l.packageId == _kCustom) {
            if (l.customName.trim().isEmpty) {
              return 'Enter the custom package name for $where.';
            }
            if (l.customAmount <= 0) {
              return 'Enter the custom package amount for $where.';
            }
          } else if (pkgById(l.packageId) == null) {
            return 'The package chosen for $where no longer exists — choose another.';
          }
          if (_minutes(l.end) <= _minutes(l.start)) {
            return 'End time must be after the start time for $where.';
          }
        }
      }
      return null;
    }

    Future<void> submit() async {
      if (isSubmitting.value) return;
      final formOk = formKey.currentState!.validate();
      final problem = programmeProblem();
      if (!formOk || problem != null) {
        showErrors.value = true;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                !formOk ? 'Fill the required client details.' : problem!,
              ),
            ),
          );
        return;
      }

      final sortedDays = [...days.value]
        ..sort((a, b) => a.date.compareTo(b.date));
      // One bookingItem per package line per day (exactly the old shape).
      final items = <BookingItem>[
        for (final d in sortedDays)
          for (final l in d.lines)
            () {
              final pkg = l.packageId == _kCustom ? null : pkgById(l.packageId);
              return BookingItem(
                packageId: pkg?.id ?? '',
                service: pkg?.name ?? l.customName.trim(),
                eventSlot: l.slot.trim(),
                selectedDates: [d.date],
                totalPrice: linePrice(l),
                advanceAmount: lineAdvance(l),
                districtId: l.districtId,
                regionId: districtById(l.districtId)?.regionId ?? '',
                addons: l.addons
                    .where((a) => a.service.trim().isNotEmpty || a.amount > 0)
                    .toList(),
                startTime: _hhmm(l.start),
                endTime: _hhmm(l.end),
              );
            }(),
      ];
      final firstDay = sortedDays.first;
      final lastDay = sortedDays.last;
      TimeOfDay earliest(_Day d) => d.lines
          .map((l) => l.start)
          .reduce((a, b) => _minutes(a) <= _minutes(b) ? a : b);
      TimeOfDay latest(_Day d) => d.lines
          .map((l) => l.end)
          .reduce((a, b) => _minutes(a) >= _minutes(b) ? a : b);
      final s = earliest(firstDay), e = latest(lastDay);
      // Booking-level district (geo / reports): the first package's district.
      final bookingDistrict = districtById(items.first.districtId);
      final services = <String>{
        for (final it in items)
          if (it.service.trim().isNotEmpty) it.service.trim(),
      };
      final slots = <String>{
        for (final it in items)
          if (it.eventSlot.trim().isNotEmpty) it.eventSlot.trim(),
      };

      final booking = Booking(
        id: '${DateTime.now().millisecondsSinceEpoch}',
        packageId: items.first.packageId,
        regionId: bookingDistrict?.regionId ?? '',
        districtId: bookingDistrict?.id ?? '',
        customerName: (nameCtrl.first?.text ?? qParams['name'] ?? '').trim(),
        phone: normalizePhone(phoneCtrl.text),
        address: addressCtrl.text.trim(),
        pincode: pincodeCtrl.text.trim(),
        email: emailCtrl.text.trim(),
        legacyBooking: allowMissingEmail.value,
        service: services.join(' + '),
        eventSlot: slots.join(' | '),
        region: bookingDistrict?.regionName ?? '',
        district: bookingDistrict?.name ?? '',
        bookingDate: firstDay.date,
        selectedDates: [for (final d in sortedDays) d.date],
        createdAt: bookedDate.value,
        serviceStart: DateTime(
          firstDay.date.year,
          firstDay.date.month,
          firstDay.date.day,
          s.hour,
          s.minute,
        ),
        serviceEnd: DateTime(
          lastDay.date.year,
          lastDay.date.month,
          lastDay.date.day,
          e.hour,
          e.minute,
        ),
        totalPrice: total,
        discountAmount: discount,
        discountType: discountType.value,
        discountValue: discountValue.value,
        discountReason: discountNoteCtrl.text.trim(),
        advanceAmount: advance,
        leadId: qParams['leadId'],
        bookingItems: items,
        // Add-ons live on each package line (bookingItems).
        addons: const <BookingAddon>[],
      );

      isSubmitting.value = true;
      try {
        try {
          await ref.read(bookingProvider.notifier).addBooking(booking);
        } catch (error) {
          // The server refuses a second active booking for the same number on
          // the same date (usually the same booking saved twice). Only create
          // it if the user explicitly confirms.
          final cause = error is AppException ? error.cause : error;
          final data = cause is DioException ? cause.response?.data : null;
          if (cause is! DioException ||
              cause.response?.statusCode != 409 ||
              data is! Map ||
              data['duplicateBookingId'] == null) {
            rethrow;
          }
          if (!context.mounted) return;
          final proceed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Possible duplicate booking'),
              content: Text(
                '${data['message'] ?? 'A booking for this number on the same date already exists.'}\n\n'
                'Create another booking anyway?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Create anyway'),
                ),
              ],
            ),
          );
          if (proceed != true) return;
          await ref
              .read(bookingProvider.notifier)
              .addBooking(booking, allowDuplicate: true);
        }
        if (!context.mounted) return;

        final isConversion = (qParams['leadId'] ?? '').isNotEmpty;
        final isAnother = qParams['another'] == '1';
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF10B981),
              content: Text(
                isConversion
                    ? (isAnother
                          ? 'Another booking added for this customer.'
                          : 'Lead converted — booking created.')
                    : items.length > 1
                    ? 'Booking created with ${items.length} packages — one invoice.'
                    : 'Booking created and added to calendar.',
              ),
            ),
          );
        // Go somewhere this user can open (sales roles often lack the calendar).
        final access = Access.of(ref.read(authSessionProvider));
        if (isConversion && context.canPop()) {
          context.pop();
        } else if (access.canSeeCalendar) {
          context.go('/calendar?date=${_routeDate(firstDay.date)}');
        } else if (context.canPop()) {
          context.pop();
        } else {
          context.go(access.homeRoute.isNotEmpty ? access.homeRoute : '/');
        }
      } catch (error) {
        if (!context.mounted) return;
        showErrorSnackBar(context, error);
      } finally {
        if (context.mounted) isSubmitting.value = false;
      }
    }

    // ── Layout ─────────────────────────────────────────────────────────────
    final clientSection = _Section(
      number: 1,
      title: 'Client',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Consumer(
            builder: (context, ref, _) {
              final asyncCustomers = ref.watch(customersProvider);
              final customers = asyncCustomers.value ?? const <Customer>[];
              return Autocomplete<Customer>(
                // The Autocomplete owns its controller; seed it from a lead prefill.
                initialValue: TextEditingValue(text: qParams['name'] ?? ''),
                optionsBuilder: (v) => v.text.isEmpty
                    ? const Iterable<Customer>.empty()
                    : customers.where(
                        (c) =>
                            c.name.toLowerCase().contains(v.text.toLowerCase()),
                      ),
                displayStringForOption: (c) => c.name,
                onSelected: (c) {
                  phoneCtrl.text = c.phone ?? '';
                  addressCtrl.text = c.address ?? '';
                  pincodeCtrl.text = c.pincode ?? '';
                  final placeholder = c.email.contains('@placeholder.local');
                  emailCtrl.text = placeholder ? '' : c.email;
                  allowMissingEmail.value = placeholder;
                },
                fieldViewBuilder: (context, controller, focusNode, onSubmit) {
                  nameCtrl.first = controller;
                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    textCapitalization: TextCapitalization.words,
                    decoration:
                        _deco(
                          'Full name',
                          crm,
                          hint: 'Type to search existing clients',
                        ).copyWith(
                          prefixIcon: const Icon(Icons.person_outline),
                          suffixIcon: asyncCustomers.isLoading
                              ? const Padding(
                                  padding: EdgeInsets.all(14),
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                    onFieldSubmitted: (_) => onSubmit(),
                  );
                },
              );
            },
          ),
          12.h,
          _ResponsiveRow(
            children: [
              TextFormField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: _deco(
                  'Phone',
                  crm,
                ).copyWith(prefixIcon: const Icon(Icons.phone_outlined)),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              TextFormField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: _deco(
                  allowMissingEmail.value
                      ? 'Email (optional — old booking)'
                      : 'Email',
                  crm,
                ).copyWith(prefixIcon: const Icon(Icons.mail_outline)),
                validator: (v) {
                  final value = v?.trim() ?? '';
                  if (allowMissingEmail.value && value.isEmpty) return null;
                  if (value.isEmpty) return 'Required';
                  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {
                    return 'Enter a valid email';
                  }
                  if (value.toLowerCase().endsWith('@placeholder.local')) {
                    return 'Enter a real client email';
                  }
                  return null;
                },
              ),
            ],
          ),
          12.h,
          _ResponsiveRow(
            flex: const [2, 1],
            children: [
              TextFormField(
                controller: addressCtrl,
                decoration: _deco(
                  'Venue / address',
                  crm,
                ).copyWith(prefixIcon: const Icon(Icons.place_outlined)),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              PincodeField(
                controller: pincodeCtrl,
                decoration: _deco('Pincode', crm),
                required: true,
                // The pincode says which district it is; pricing follows the district, so the
                // booking can be priced for it in one tap (never changed on its own).
                actionBuilder: (context, place) {
                  final d = place.district;
                  if (d == null || districtById(d.id) == null) return null;
                  if (allLines.isEmpty || allLines.every((l) => l.districtId == d.id)) return null;
                  return TextButton(
                    key: const Key('pincodeUseDistrict'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => setDays([
                      for (final day in days.value)
                        day.copyWith(lines: [for (final l in day.lines) l.copyWith(districtId: d.id)]),
                    ]),
                    child: Text('Use ${d.name} pricing for all packages'),
                  );
                },
              ),
            ],
          ),
          // Road distance from HQ (HiLITE Business Park) + per-km estimate.
          HqDistanceLine(addressCtrl: addressCtrl, pincodeCtrl: pincodeCtrl),
          4.h,
          CheckboxListTile(
            value: allowMissingEmail.value,
            onChanged: (v) => allowMissingEmail.value = v ?? false,
            contentPadding: EdgeInsets.zero,
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('Old booking without a client email'),
            subtitle: const Text(
              'Saves without a real email; the confirmation email is skipped.',
            ),
          ),
        ],
      ),
    );

    final programmeSection = _Section(
      number: 2,
      title: 'Programme',
      trailing: InkWell(
        onTap: isSubmitting.value ? null : pickBookedDate,
        borderRadius: BorderRadius.circular(8),
        child: Tooltip(
          message:
              'When the booking was made. Entering a forgotten booking late? Set the real past date.',
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    'Booked on ${_longDate(bookedDate.value)}',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, color: crm.textSecondary),
                  ),
                ),
                4.w,
                Icon(
                  Icons.edit_calendar_outlined,
                  size: 16,
                  color: crm.primary,
                ),
              ],
            ),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (asyncPackages.isLoading || asyncDistricts.isLoading)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          if (asyncPackages.hasError || asyncDistricts.hasError)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AppErrorView(
                error: asyncPackages.error ?? asyncDistricts.error,
                compact: true,
                title: 'Could not load packages and districts',
                onRetry: () {
                  final c = ProviderScope.containerOf(context, listen: false);
                  c.invalidate(packagesProvider);
                  c.invalidate(districtsProvider);
                },
              ),
            ),
          if (days.value.isEmpty)
            _EmptyProgramme(onAdd: isSubmitting.value ? null : addDay)
          else
            for (var di = 0; di < days.value.length; di++)
              _DayCard(
                key: ValueKey(
                  'day-${_dateKey(days.value[di].date)}-${days.value[di].lines.first.id}',
                ),
                dayNumber: di + 1,
                day: days.value[di],
                packages: packages,
                districts: districts,
                addonServices: addonServices,
                enabled: !isSubmitting.value,
                showErrors: showErrors.value,
                priceOf: linePrice,
                onChangeDate: () => changeDayDate(di),
                onRemoveDay: () => removeDay(di),
                onAddLine: () => addLine(di),
                onRemoveLine: (li) => removeLine(di, li),
                onLineChanged: (li, line) => updateLine(di, li, line),
              ),
          if (days.value.isNotEmpty) ...[
            4.h,
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: isSubmitting.value ? null : addDay,
                  icon: const Icon(Icons.calendar_month_outlined, size: 18),
                  label: const Text('Add another day'),
                ),
                if (days.value.length > 1)
                  TextButton.icon(
                    onPressed: isSubmitting.value ? null : copyFirstDayToAll,
                    icon: const Icon(Icons.copy_all_outlined, size: 18),
                    label: Text(
                      "Use ${_shortDate(days.value.first.date)}'s packages for all days",
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );

    final discountSection = _Section(
      number: 3,
      title: 'Discount',
      subtitle: 'Optional',
      child: _ResponsiveRow(
        flex: const [1, 2],
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: discountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (v) =>
                      discountValue.value = double.tryParse(v.trim()) ?? 0,
                  decoration: _deco(
                    discountType.value == 'percent'
                        ? 'Discount (%)'
                        : 'Discount (₹)',
                    crm,
                  ),
                ),
              ),
              8.w,
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'inr', label: Text('₹')),
                  ButtonSegment(value: 'percent', label: Text('%')),
                ],
                selected: {discountType.value},
                showSelectedIcon: false,
                onSelectionChanged: (v) => discountType.value = v.first,
              ),
            ],
          ),
          TextField(
            controller: discountNoteCtrl,
            decoration: _deco('Discount note', crm),
          ),
        ],
      ),
    );

    final percentOver =
        discountType.value == 'percent' && discountValue.value > 100;

    final summaryBar = Material(
      color: crm.surface,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Wrap(
            spacing: 24,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Wrap(
                spacing: 24,
                runSpacing: 8,
                children: [
                  _Figure('Total', _inr(total), crm.textPrimary),
                  if (discount > 0)
                    _Figure('Discount', '− ${_inr(discount)}', crm.accent),
                  _Figure('Advance', _inr(advance), crm.accent),
                  _Figure('Balance', _inr(balance), crm.textPrimary),
                  if (percentOver)
                    Text(
                      'Discount capped at 100%',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade800,
                      ),
                    ),
                ],
              ),
              FilledButton.icon(
                onPressed: isSubmitting.value ? null : submit,
                style: FilledButton.styleFrom(
                  backgroundColor: crm.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 18,
                  ),
                ),
                icon: isSubmitting.value
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: Text(
                  isSubmitting.value ? 'Saving…' : 'Create booking',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              child: AbsorbPointer(
                absorbing: isSubmitting.value,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 920),
                      child: Form(
                        key: formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                IconButton(
                                  tooltip: 'Back',
                                  onPressed: () => context.canPop()
                                      ? context.pop()
                                      : context.go('/calendar'),
                                  icon: const Icon(Icons.arrow_back),
                                ),
                                8.w,
                                Expanded(
                                  child: Text(
                                    'New booking',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            12.h,
                            clientSection,
                            16.h,
                            programmeSection,
                            16.h,
                            discountSection,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            summaryBar,
          ],
        ),
        if (isSubmitting.value)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black.withValues(alpha: 0.08),
              child: const Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }
}

// ── Programme model ─────────────────────────────────────────────────────────

int _lineSeq = 0;

/// One package on one day.
class _Line {
  final String id;
  final String packageId; // '' = not chosen yet, _kCustom = custom package
  final String customName;
  final double customAmount;
  final String districtId; // '' = base price
  final TimeOfDay start;
  final TimeOfDay end;
  final String slot;
  final List<BookingAddon> addons;

  const _Line({
    required this.id,
    this.packageId = '',
    this.customName = '',
    this.customAmount = 0,
    this.districtId = '',
    required this.start,
    required this.end,
    this.slot = '',
    this.addons = const [],
  });

  static String _newId() =>
      'line-${DateTime.now().microsecondsSinceEpoch}-${_lineSeq++}';

  /// An empty line to choose. After [prev], it keeps the same district and
  /// starts when the previous package ends.
  factory _Line.blank({_Line? prev}) {
    final start = prev?.end ?? const TimeOfDay(hour: 9, minute: 0);
    final endMin = (_minutes(start) + 60).clamp(0, 23 * 60 + 59);
    return _Line(
      id: _newId(),
      districtId: prev?.districtId ?? '',
      start: start,
      end: TimeOfDay(hour: endMin ~/ 60, minute: endMin % 60),
    );
  }

  /// Same package / district / time / slot on another day (add-ons are per day).
  _Line copyForNewDay() => _Line(
    id: _newId(),
    packageId: packageId,
    customName: customName,
    customAmount: customAmount,
    districtId: districtId,
    start: start,
    end: end,
    slot: slot,
  );

  _Line copyWith({
    String? packageId,
    String? customName,
    double? customAmount,
    String? districtId,
    TimeOfDay? start,
    TimeOfDay? end,
    String? slot,
    List<BookingAddon>? addons,
  }) => _Line(
    id: id,
    packageId: packageId ?? this.packageId,
    customName: customName ?? this.customName,
    customAmount: customAmount ?? this.customAmount,
    districtId: districtId ?? this.districtId,
    start: start ?? this.start,
    end: end ?? this.end,
    slot: slot ?? this.slot,
    addons: addons ?? this.addons,
  );
}

class _Day {
  final DateTime date;
  final List<_Line> lines;
  const _Day({required this.date, required this.lines});
  _Day copyWith({DateTime? date, List<_Line>? lines}) =>
      _Day(date: date ?? this.date, lines: lines ?? this.lines);
}

int _minutes(TimeOfDay t) => t.hour * 60 + t.minute;

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// "Sat, 18 Oct 2026"
String _longDate(DateTime d) =>
    '${_weekdays[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]} ${d.year}';

/// "18 Oct"
String _shortDate(DateTime d) => '${d.day} ${_months[d.month - 1]}';

String _routeDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _fmtTime(TimeOfDay t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '$h:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'AM' : 'PM'}';
}

/// ₹1,23,456 (Indian grouping, whole rupees).
String _inr(double v) {
  final whole = v.round().abs().toString();
  String grouped;
  if (whole.length <= 3) {
    grouped = whole;
  } else {
    final last3 = whole.substring(whole.length - 3);
    var rest = whole.substring(0, whole.length - 3);
    final parts = <String>[];
    while (rest.length > 2) {
      parts.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) parts.insert(0, rest);
    grouped = '${parts.join(',')},$last3';
  }
  return '₹${v < 0 ? '-' : ''}$grouped';
}

InputDecoration _deco(String label, CrmTheme crm, {String? hint}) =>
    InputDecoration(
      labelText: label,
      hintText: hint,
      isDense: true,
      filled: true,
      fillColor: crm.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: crm.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: crm.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: crm.primary, width: 2),
      ),
    );

// ── Layout pieces ───────────────────────────────────────────────────────────

/// Side by side on wide screens, stacked on phones.
class _ResponsiveRow extends StatelessWidget {
  final List<Widget> children;
  final List<int>? flex;
  const _ResponsiveRow({required this.children, this.flex});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 560) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) 12.h,
                children[i],
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) 12.w,
              Expanded(
                flex: flex != null && i < flex!.length ? flex![i] : 1,
                child: children[i],
              ),
            ],
          ],
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  final int number;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;
  const _Section({
    required this.number,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    // Material (not a coloured DecoratedBox) so ink ripples on list tiles /
    // checkboxes inside stay visible.
    return Material(
      color: crm.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: crm.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor: crm.primary.withValues(alpha: 0.12),
                  child: Text(
                    '$number',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: crm.primary,
                    ),
                  ),
                ),
                10.w,
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (subtitle != null) ...[
                  8.w,
                  Text(
                    subtitle!,
                    style: TextStyle(fontSize: 12.5, color: crm.textSecondary),
                  ),
                ],
                const Spacer(),
                if (trailing != null) Flexible(child: trailing!),
              ],
            ),
            14.h,
            child,
          ],
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Figure(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            color: context.crmColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _EmptyProgramme extends StatelessWidget {
  final VoidCallback? onAdd;
  const _EmptyProgramme({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: crm.border),
      ),
      child: Column(
        children: [
          Icon(
            Icons.event_available_outlined,
            size: 32,
            color: crm.textSecondary,
          ),
          8.h,
          const Text(
            'Add the first event day',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          4.h,
          Text(
            'Then choose its package. Add more days for a multi-day programme.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: crm.textSecondary),
          ),
          12.h,
          FilledButton.icon(
            onPressed: onAdd,
            style: FilledButton.styleFrom(backgroundColor: crm.primary),
            icon: const Icon(Icons.add),
            label: const Text('Add event day'),
          ),
        ],
      ),
    );
  }
}

/// One event day: its date and its package lines.
class _DayCard extends StatelessWidget {
  final int dayNumber;
  final _Day day;
  final List<ServicePackage> packages;
  final List<District> districts;
  final List<AddonService> addonServices;
  final bool enabled;
  final bool showErrors;
  final double Function(_Line) priceOf;
  final VoidCallback onChangeDate;
  final VoidCallback onRemoveDay;
  final VoidCallback onAddLine;
  final ValueChanged<int> onRemoveLine;
  final void Function(int, _Line) onLineChanged;

  const _DayCard({
    super.key,
    required this.dayNumber,
    required this.day,
    required this.packages,
    required this.districts,
    required this.addonServices,
    required this.enabled,
    required this.showErrors,
    required this.priceOf,
    required this.onChangeDate,
    required this.onRemoveDay,
    required this.onAddLine,
    required this.onRemoveLine,
    required this.onLineChanged,
  });

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: crm.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
            decoration: BoxDecoration(
              color: crm.primary.withValues(alpha: 0.06),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Text(
                  'DAY $dayNumber',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: crm.primary,
                  ),
                ),
                12.w,
                Flexible(
                  child: InkWell(
                    onTap: enabled ? onChangeDate : null,
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              _longDate(day.date),
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14.5,
                              ),
                            ),
                          ),
                          4.w,
                          Icon(
                            Icons.edit_calendar_outlined,
                            size: 16,
                            color: crm.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Remove this day',
                  onPressed: enabled ? onRemoveDay : null,
                  icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var li = 0; li < day.lines.length; li++) ...[
                  if (li > 0) Divider(height: 24, color: crm.border),
                  _LineEditor(
                    key: ValueKey(day.lines[li].id),
                    line: day.lines[li],
                    index: li,
                    showIndex: day.lines.length > 1,
                    packages: packages,
                    districts: districts,
                    addonServices: addonServices,
                    enabled: enabled,
                    showErrors: showErrors,
                    price: priceOf(day.lines[li]),
                    canRemove: day.lines.length > 1,
                    onChanged: (l) => onLineChanged(li, l),
                    onRemove: () => onRemoveLine(li),
                  ),
                ],
                6.h,
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: enabled ? onAddLine : null,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add another package to this day'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One package line: package (or custom), district + price, time, slot,
/// add-ons. Keyed by its own id, so removing a line never shifts another
/// line's choices onto the wrong row.
class _LineEditor extends StatefulWidget {
  final _Line line;
  final int index;
  final bool showIndex;
  final List<ServicePackage> packages;
  final List<District> districts;
  final List<AddonService> addonServices;
  final bool enabled;
  final bool showErrors;
  final double price;
  final bool canRemove;
  final ValueChanged<_Line> onChanged;
  final VoidCallback onRemove;

  const _LineEditor({
    super.key,
    required this.line,
    required this.index,
    required this.showIndex,
    required this.packages,
    required this.districts,
    required this.addonServices,
    required this.enabled,
    required this.showErrors,
    required this.price,
    required this.canRemove,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  State<_LineEditor> createState() => _LineEditorState();
}

class _LineEditorState extends State<_LineEditor> {
  late final _customName = TextEditingController(text: widget.line.customName);
  late final _customAmount = TextEditingController(
    text: widget.line.customAmount > 0
        ? widget.line.customAmount.toStringAsFixed(0)
        : '',
  );
  late final _slot = TextEditingController(text: widget.line.slot);

  @override
  void dispose() {
    _customName.dispose();
    _customAmount.dispose();
    _slot.dispose();
    super.dispose();
  }

  _Line get line => widget.line;

  ServicePackage? get _pkg {
    for (final p in widget.packages) {
      if (p.id == line.packageId) return p;
    }
    return null;
  }

  Future<void> _pickTime() async {
    final start = await showTimePicker(
      context: context,
      initialTime: line.start,
      helpText: 'START TIME',
    );
    if (start == null || !mounted) return;
    var endInitial = line.end;
    if (_minutes(endInitial) <= _minutes(start)) {
      final m = (_minutes(start) + 60).clamp(0, 23 * 60 + 59);
      endInitial = TimeOfDay(hour: m ~/ 60, minute: m % 60);
    }
    final end = await showTimePicker(
      context: context,
      initialTime: endInitial,
      helpText: 'END TIME',
    );
    if (end == null) return;
    widget.onChanged(line.copyWith(start: start, end: end));
  }

  Future<void> _pickDistrict() async {
    final picked = await _showDistrictPricePicker(
      context: context,
      districts: widget.districts,
      package: line.packageId == _kCustom ? null : _pkg,
      currentId: line.districtId,
    );
    if (picked != null) widget.onChanged(line.copyWith(districtId: picked));
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final missing = widget.showErrors && line.packageId.isEmpty;
    final known =
        line.packageId == _kCustom ||
        widget.packages.any((p) => p.id == line.packageId);
    final districtName = () {
      for (final d in widget.districts) {
        if (d.id == line.districtId) return '${d.name} (${d.regionName})';
      }
      return 'Default (base price)';
    }();
    final badTime = _minutes(line.end) <= _minutes(line.start);

    final packageField = DropdownButtonFormField<String>(
      // Keyed by line + choice so the shown value always matches the data.
      key: ValueKey('pkg-${line.id}-${line.packageId}'),
      initialValue: known ? line.packageId : null,
      isExpanded: true,
      decoration: _deco('Package', crm).copyWith(
        errorText: missing ? 'Choose a package' : null,
        prefixIcon: const Icon(Icons.inventory_2_outlined, size: 18),
      ),
      hint: const Text('Choose package'),
      items: [
        for (final p in widget.packages)
          DropdownMenuItem(
            value: p.id,
            // The price actually charged for THIS line's district.
            child: Text(
              '${p.name} · ${_inr(p.effectivePriceForDistrict(line.districtId))}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        const DropdownMenuItem(value: _kCustom, child: Text('Custom package…')),
      ],
      onChanged: widget.enabled
          ? (v) => widget.onChanged(line.copyWith(packageId: v ?? ''))
          : null,
    );

    final districtField = InkWell(
      onTap: widget.enabled && widget.districts.isNotEmpty
          ? _pickDistrict
          : null,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: _deco('District (price)', crm).copyWith(
          prefixIcon: const Icon(Icons.location_on_outlined, size: 18),
        ),
        child: Text(districtName, overflow: TextOverflow.ellipsis),
      ),
    );

    final timeField = InkWell(
      onTap: widget.enabled ? _pickTime : null,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: _deco('Time', crm).copyWith(
          prefixIcon: const Icon(Icons.schedule, size: 18),
          errorText: widget.showErrors && badTime ? 'End before start' : null,
        ),
        child: Text(
          '${_fmtTime(line.start)} – ${_fmtTime(line.end)}',
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (widget.showIndex)
              Text(
                'PACKAGE ${widget.index + 1}',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: crm.textSecondary,
                ),
              ),
            const Spacer(),
            Text(
              widget.price > 0 ? _inr(widget.price) : '',
              style: TextStyle(fontWeight: FontWeight.bold, color: crm.primary),
            ),
            if (widget.canRemove)
              IconButton(
                tooltip: 'Remove this package',
                visualDensity: VisualDensity.compact,
                onPressed: widget.enabled ? widget.onRemove : null,
                icon: Icon(Icons.close, size: 18, color: Colors.red.shade400),
              ),
          ],
        ),
        if (widget.showIndex || widget.canRemove) 4.h,
        _ResponsiveRow(
          flex: const [5, 4],
          children: [packageField, districtField],
        ),
        if (line.packageId == _kCustom) ...[
          10.h,
          _ResponsiveRow(
            flex: const [3, 2],
            children: [
              TextField(
                controller: _customName,
                enabled: widget.enabled,
                textCapitalization: TextCapitalization.words,
                decoration: _deco('Custom package name', crm).copyWith(
                  errorText: widget.showErrors && line.customName.trim().isEmpty
                      ? 'Required'
                      : null,
                ),
                onChanged: (v) =>
                    widget.onChanged(line.copyWith(customName: v)),
              ),
              TextField(
                controller: _customAmount,
                enabled: widget.enabled,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: _deco('Amount (₹)', crm).copyWith(
                  errorText: widget.showErrors && line.customAmount <= 0
                      ? 'Required'
                      : null,
                ),
                onChanged: (v) => widget.onChanged(
                  line.copyWith(customAmount: double.tryParse(v.trim()) ?? 0),
                ),
              ),
            ],
          ),
        ],
        10.h,
        _ResponsiveRow(
          flex: const [4, 5],
          children: [
            timeField,
            TextField(
              controller: _slot,
              enabled: widget.enabled,
              decoration: _deco(
                'Slot (optional)',
                crm,
                hint: 'Morning wedding, Reception…',
              ),
              onChanged: (v) => widget.onChanged(line.copyWith(slot: v)),
            ),
          ],
        ),
        // Add-ons for this package.
        for (var i = 0; i < line.addons.length; i++)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: _AddonRow(
              key: ValueKey('addon-${line.id}-$i-${line.addons.length}'),
              index: i,
              addon: line.addons[i],
              services: widget.addonServices,
              crm: crm,
              enabled: widget.enabled,
              onChanged: (a) {
                final next = [...line.addons]..[i] = a;
                widget.onChanged(line.copyWith(addons: next));
              },
              onRemove: () {
                final next = [...line.addons]..removeAt(i);
                widget.onChanged(line.copyWith(addons: next));
              },
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: widget.enabled
                ? () => widget.onChanged(
                    line.copyWith(
                      addons: [
                        ...line.addons,
                        const BookingAddon(
                          addonServiceId: '',
                          service: '',
                          amount: 0,
                          persons: 1,
                        ),
                      ],
                    ),
                  )
                : null,
            icon: const Icon(Icons.add_circle_outline, size: 16),
            label: Text(
              line.addons.isEmpty
                  ? 'Add-on (hairstyling, draping…)'
                  : 'Another add-on',
            ),
          ),
        ),
      ],
    );
  }
}

List<ServicePackage> _uniquePackages(List<ServicePackage> packages) {
  final seen = <String>{};
  final unique = <ServicePackage>[];

  for (final package in packages) {
    if (package.id.isEmpty || seen.contains(package.id)) continue;
    seen.add(package.id);
    unique.add(package);
  }

  return unique;
}

List<District> _uniqueDistricts(List<District> districts) {
  final seen = <String>{};
  final unique = <District>[];

  for (final district in districts) {
    if (district.id.isEmpty || seen.contains(district.id)) continue;
    seen.add(district.id);
    unique.add(district);
  }

  return unique;
}

/// "HH:mm" (24-h) — the per-line time format BookingItem stores.
String _hhmm(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

String _dateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// One add-on row in the Add Booking screen. Stateful so its price/persons text
/// fields keep their own controllers and don't lose the cursor when the parent
/// rebuilds after each keystroke (the total recomputes live).
class _AddonRow extends StatefulWidget {
  final int index;
  final BookingAddon addon;
  final List<AddonService> services;
  final CrmTheme crm;
  final bool enabled;
  final ValueChanged<BookingAddon> onChanged;
  final VoidCallback onRemove;

  const _AddonRow({
    super.key,
    required this.index,
    required this.addon,
    required this.services,
    required this.crm,
    required this.enabled,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  State<_AddonRow> createState() => _AddonRowState();
}

class _AddonRowState extends State<_AddonRow> {
  late final TextEditingController _price;
  late final TextEditingController _persons;

  @override
  void initState() {
    super.initState();
    _price = TextEditingController(
      text: widget.addon.amount == 0
          ? ''
          : widget.addon.amount.toStringAsFixed(0),
    );
    _persons = TextEditingController(text: widget.addon.persons.toString());
  }

  @override
  void dispose() {
    _price.dispose();
    _persons.dispose();
    super.dispose();
  }

  InputDecoration _deco(String label) => InputDecoration(
    labelText: label,
    isDense: true,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  );

  @override
  Widget build(BuildContext context) {
    final crm = widget.crm;
    final selectedId =
        widget.services.any((s) => s.id == widget.addon.addonServiceId)
        ? widget.addon.addonServiceId
        : null;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: crm.border),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ADD-ON ${widget.index + 1}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: crm.textSecondary,
                  letterSpacing: 1.2,
                ),
              ),
              TextButton(
                onPressed: widget.enabled ? widget.onRemove : null,
                child: const Text(
                  'REMOVE',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          8.h,
          DropdownButtonFormField<String>(
            initialValue: selectedId,
            isExpanded: true,
            decoration: _deco('Add-on service'),
            items: widget.services
                .map(
                  (s) => DropdownMenuItem(
                    value: s.id,
                    child: Text(
                      '${s.name} — ₹ ${s.price.toStringAsFixed(0)}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: widget.enabled
                ? (value) {
                    if (value == null) return;
                    final sel = widget.services.firstWhere(
                      (s) => s.id == value,
                    );
                    // Auto-fill the price from the chosen service; the user can
                    // still override it below.
                    _price.text = sel.price.toStringAsFixed(0);
                    widget.onChanged(
                      widget.addon.copyWith(
                        addonServiceId: sel.id,
                        service: sel.name,
                        amount: sel.price,
                        description: sel.description,
                      ),
                    );
                  }
                : null,
          ),
          10.h,
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _price,
                  enabled: widget.enabled,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: _deco('Price (₹)'),
                  onChanged: (v) => widget.onChanged(
                    widget.addon.copyWith(amount: double.tryParse(v) ?? 0),
                  ),
                ),
              ),
              12.w,
              Expanded(
                child: TextField(
                  controller: _persons,
                  enabled: widget.enabled,
                  keyboardType: TextInputType.number,
                  decoration: _deco('Persons'),
                  onChanged: (v) => widget.onChanged(
                    widget.addon.copyWith(persons: int.tryParse(v) ?? 1),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Searchable, priced district picker ──────────────────────────────────────
// Bottom sheet listing districts with a search box and each district's price
// for the given package, so a per-package district is quick to choose.
Future<String?> _showDistrictPricePicker({
  required BuildContext context,
  required List<District> districts,
  required ServicePackage? package,
  required String currentId,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _DistrictPricePickerSheet(
      districts: districts,
      package: package,
      currentId: currentId,
    ),
  );
}

class _DistrictPricePickerSheet extends StatefulWidget {
  final List<District> districts;
  final ServicePackage? package;
  final String currentId;
  const _DistrictPricePickerSheet({
    required this.districts,
    required this.package,
    required this.currentId,
  });
  @override
  State<_DistrictPricePickerSheet> createState() =>
      _DistrictPricePickerSheetState();
}

class _DistrictPricePickerSheetState extends State<_DistrictPricePickerSheet> {
  final _searchCtrl = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _priceFor(String districtId) {
    final p = widget.package;
    if (p == null) return '';
    return '₹${p.effectivePriceForDistrict(districtId).toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final media = MediaQuery.of(context);
    final q = _q.trim().toLowerCase();
    final filtered = widget.districts
        .where(
          (d) =>
              q.isEmpty ||
              d.name.toLowerCase().contains(q) ||
              d.regionName.toLowerCase().contains(q),
        )
        .toList();

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.82),
        decoration: BoxDecoration(
          color: crm.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: crm.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
              child: Row(
                children: [
                  Text(
                    'Select district',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: crm.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  if (widget.package != null)
                    Flexible(
                      child: Text(
                        widget.package!.name,
                        textAlign: TextAlign.right,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: crm.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                onChanged: (v) => setState(() => _q = v),
                decoration: InputDecoration(
                  hintText: 'Search district or region…',
                  prefixIcon: const Icon(Icons.search_rounded),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            Flexible(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 16),
                children: [
                  if (q.isEmpty)
                    _row(
                      crm,
                      id: '',
                      title: 'Default (Base Price)',
                      subtitle: '',
                      price: _priceFor(''),
                    ),
                  for (final d in filtered)
                    _row(
                      crm,
                      id: d.id,
                      title: d.name,
                      subtitle: d.regionName,
                      price: _priceFor(d.id),
                    ),
                  if (filtered.isEmpty && q.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          'No districts match "$_q"',
                          style: TextStyle(color: crm.textSecondary),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(
    CrmTheme crm, {
    required String id,
    required String title,
    required String subtitle,
    required String price,
  }) {
    final selected = id == widget.currentId;
    return InkWell(
      onTap: () => Navigator.of(context).pop(id),
      child: Container(
        color: selected ? crm.primary.withValues(alpha: 0.06) : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.location_on_outlined,
              size: 18,
              color: selected ? crm.primary : crm.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: crm.textPrimary,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: crm.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            if (price.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: crm.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  price,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: crm.primary,
                    fontSize: 13,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
