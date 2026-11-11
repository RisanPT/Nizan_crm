import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nizan_crm/core/models/pincode_lookup.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/services/pincode_service.dart';

/// A pincode box that knows where the pincode is.
///
/// Digits only, six at most. Once a full pincode is in (after a short pause, so typing doesn't fire
/// lookups) it says where that is — "Kozhikode · Calicut · Kerala" — from our pincode list, or, for a
/// pincode we don't list, from the map as a suggestion. It only ever INFORMS: a pincode we don't
/// know, or a lookup that fails, never stops anyone saving. The one thing that can is the format
/// check ([strict]), which saves a typo like 67300.
///
/// It works on the caller's [controller], so anything else listening to the same controller (the
/// road-distance line, say) keeps working, and a pre-filled value is looked up straight away.
class PincodeField extends ConsumerStatefulWidget {
  final TextEditingController controller;

  /// The caller's own look for a text box (each screen has one); a suffix is not added.
  final InputDecoration decoration;

  /// Empty is an error.
  final bool required;

  /// A non-empty value that is not 6 digits is an error. Turn off when editing old records whose
  /// pincode may be free text — it then only says so.
  final bool strict;
  final bool enabled;

  /// Told (after the frame) when a full pincode has been looked up — and with null when the pincode
  /// is changed again, so a screen can drop what it suggested.
  final ValueChanged<PincodeLookup?>? onResolved;

  /// A button or note under the result for a pincode that was placed, e.g. "Use Kozhikode pricing".
  final Widget? Function(BuildContext context, PincodeLookup lookup)?
  actionBuilder;

  /// How long to wait after the last keystroke before looking up.
  final Duration pause;

  const PincodeField({
    super.key,
    required this.controller,
    required this.decoration,
    this.required = false,
    this.strict = true,
    this.enabled = true,
    this.onResolved,
    this.actionBuilder,
    this.pause = const Duration(milliseconds: 400),
  });

  @override
  ConsumerState<PincodeField> createState() => _PincodeFieldState();
}

class _PincodeFieldState extends ConsumerState<PincodeField> {
  static final _pin = RegExp(r'^[1-9]\d{5}$');

  final _focus = FocusNode();
  Timer? _timer;

  /// The complete pincode being shown ('' = none yet).
  String _code = '';
  ProviderSubscription<AsyncValue<PincodeLookup>>? _sub;

  String get _digits => widget.controller.text.replaceAll(RegExp(r'\D'), '');

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onText);
    _focus.addListener(_refresh);
    if (_pin.hasMatch(_digits)) _watch(_digits);
  }

  @override
  void didUpdateWidget(covariant PincodeField old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onText);
      widget.controller.addListener(_onText);
      _onText();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onText);
    _focus.dispose();
    _timer?.cancel();
    _sub?.close();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _notify(PincodeLookup? lookup) {
    final cb = widget.onResolved;
    if (cb == null) return;
    // After the frame: a lookup that is already cached answers while the form is still building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) cb(lookup);
    });
  }

  void _onText() {
    final digits = _digits;
    if (digits == _code) return; // nothing new (a space, say)
    _timer?.cancel();
    // What was shown (and suggested to the screen) is for the old pincode — drop it at once.
    if (_code.isNotEmpty) {
      _sub?.close();
      _sub = null;
      _code = '';
      _notify(null);
    }
    if (_pin.hasMatch(digits)) {
      _timer = Timer(widget.pause, () {
        if (mounted && _digits == digits) _watch(digits);
      });
    }
    _refresh();
  }

  void _watch(String code) {
    _sub?.close();
    _code = code;
    _sub = ref.listenManual<AsyncValue<PincodeLookup>>(
      pincodeLookupProvider(code),
      (_, next) {
        if (!mounted) return;
        setState(() {});
        final lookup = next.value;
        if (lookup != null) _notify(lookup);
      },
      fireImmediately: true,
    );
  }

  String? _validate(String? v) {
    final text = (v ?? '').trim();
    if (text.isEmpty) return widget.required ? 'Required' : null;
    if (widget.strict && !_pin.hasMatch(text)) return 'Enter a 6-digit pincode';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: widget.controller,
          focusNode: _focus,
          enabled: widget.enabled,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          decoration: widget.decoration.copyWith(counterText: ''),
          validator: _validate,
        ),
        _result(context),
      ],
    );
  }

  Widget _result(BuildContext context) {
    final crm = context.crmColors;
    final text = widget.controller.text.trim();

    Widget line(IconData icon, Color color, Widget child, {Key? key}) =>
        Padding(
          key: key,
          padding: const EdgeInsets.only(top: 6, left: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(icon, size: 15, color: color),
              ),
              const SizedBox(width: 6),
              Expanded(child: child),
            ],
          ),
        );
    TextStyle style(Color c, {bool bold = false}) => TextStyle(
      fontSize: 12,
      height: 1.3,
      color: c,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
    );

    final digits = _digits;
    if (!_pin.hasMatch(digits)) {
      // Old records may hold free text; say so once the box is left (never while typing).
      if (text.isNotEmpty && !_focus.hasFocus && !widget.strict) {
        return line(
          Icons.info_outline_rounded,
          crm.textSecondary,
          Text('Not a 6-digit pincode', style: style(crm.textSecondary)),
          key: const Key('pincodeFormat'),
        );
      }
      return const SizedBox.shrink();
    }
    if (_code != digits) {
      // a full pincode, waiting out the pause before it is looked up
      return line(
        Icons.search_rounded,
        crm.textSecondary,
        Text('Checking pincode…', style: style(crm.textSecondary)),
        key: const Key('pincodeChecking'),
      );
    }

    final async = _sub?.read();
    if (async == null || async.isLoading) {
      return line(
        Icons.search_rounded,
        crm.textSecondary,
        Text('Checking pincode…', style: style(crm.textSecondary)),
        key: const Key('pincodeChecking'),
      );
    }
    if (async.hasError) {
      return line(
        Icons.cloud_off_outlined,
        crm.textSecondary,
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              "Couldn't check this pincode right now — you can still continue. ",
              style: style(crm.textSecondary),
            ),
            InkWell(
              key: const Key('pincodeRetry'),
              onTap: () => ref.invalidate(pincodeLookupProvider(_code)),
              child: Text('Retry', style: style(crm.primary, bold: true)),
            ),
          ],
        ),
        key: const Key('pincodeError'),
      );
    }

    final r = async.requireValue;
    final action = r.found && r.district != null
        ? widget.actionBuilder?.call(context, r)
        : null;

    Widget withAction(Widget text) => action == null
        ? text
        : Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [text, action],
          );

    if (r.inOurList && r.active) {
      return line(
        Icons.check_circle_rounded,
        crm.success,
        withAction(
          Text(r.placeLine, style: style(crm.textPrimary, bold: true)),
        ),
        key: const Key('pincodeResult'),
      );
    }
    if (r.inOurList) {
      return line(
        Icons.warning_amber_rounded,
        crm.warning,
        withAction(
          Text(
            '${r.placeLine} — this pincode is marked inactive in our pincode list',
            style: style(crm.warning, bold: true),
          ),
        ),
        key: const Key('pincodeInactive'),
      );
    }
    if (r.isSuggestion) {
      return line(
        Icons.travel_explore_rounded,
        crm.primary,
        withAction(
          Text(
            'Looks like ${r.placeLine} (from the map — not in our pincode list yet)',
            style: style(crm.textPrimary),
          ),
        ),
        key: const Key('pincodeSuggestion'),
      );
    }
    return line(
      Icons.help_outline_rounded,
      crm.warning,
      Text(
        r.area.isNotEmpty
            ? 'Not in our pincode list. The map puts it near ${r.area} — choose the district yourself.'
            : 'Not in our pincode list, and the map does not know it — check the number.',
        style: style(crm.textSecondary),
      ),
      key: const Key('pincodeNotListed'),
    );
  }
}
