import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:nizan_crm/core/models/district.dart';
import 'package:nizan_crm/core/models/service_package.dart';
import 'package:nizan_crm/core/models/spot_invoice.dart';
import 'package:nizan_crm/services/district_service.dart';
import 'package:nizan_crm/services/package_service.dart';

/// Bridal Quote Builder: the builder on the left, a live client-facing quote
/// sheet on the right (stacked on phones). Prices come from the ERP package
/// (district price for the chosen district) unless overridden in
/// the on-device price list. The draft survives reloads.
class QuoteBuilderTab extends ConsumerStatefulWidget {
  final void Function(
    String customer,
    String phone,
    String? districtId,
    List<SpotInvoiceLine> lines,
  )
  onCreateInvoice;

  const QuoteBuilderTab({super.key, required this.onCreateInvoice});

  @override
  ConsumerState<QuoteBuilderTab> createState() => _QuoteBuilderTabState();
}

// ─────────────────────────────────────────────────────────────────────────
//  Catalogue
// ─────────────────────────────────────────────────────────────────────────
class _Pkg {
  final String id, name, erp, tech, brief;
  final double price;
  const _Pkg(this.id, this.name, this.erp, this.tech, this.price, this.brief);
}

class _Addon {
  final String id, name, note;
  final double? price;
  final bool perPerson;
  final List<String> includedIn;
  const _Addon(
    this.id,
    this.name,
    this.note,
    this.price, {
    this.perPerson = false,
    this.includedIn = const [],
  });
}

const _packages = [
  _Pkg('premium', 'Premium', 'Platinum', 'HD Makeup', 20000,
      'A luxurious HD bridal makeup experience combining premium makeup artistry with elegant styling and attention to detail.'),
  _Pkg('signature', 'Signature', 'Airbrush', 'Airbrush Makeup', 27000,
      'A refined, flawless finish with professional airbrush artistry. Lightweight and seamless, and it photographs beautifully.'),
  _Pkg('royal', 'Royal', 'Team N Royal', 'Bespoke Airbrush', 38000,
      'A personalised package for brides who want an elevated, bespoke experience, with our full Signature airbrush artistry.'),
];

// [label, premium, signature, royal]: bool = ✓ / —, String = text.
const List<List<Object>> _features = [
  ['Makeup technique', 'HD', 'Airbrush', 'Airbrush'],
  ['Products used', 'Premium, skin-friendly', 'Premium & high-end', 'Exclusive luxury'],
  ['Professional lenses & lashes', true, true, true],
  ['Advanced bridal hairstyling', true, true, true],
  ['Hair extensions, when required', true, true, true],
  ['Professional saree draping', false, true, true],
  ['Fully bespoke artistry & styling direction', false, false, true],
  ['Dedicated pre-wedding styling consultations', false, false, true],
  ['Optional offline styling support', false, false, true],
  ['Personalised bridal styling & finishing', false, false, true],
];

const _addons = [
  _Addon('trial', 'Bridal Trial', 'Try your makeup and hairstyle before the day', null),
  _Addon('styling', 'Bridal Styling',
      '4 online consultations (45 min each) + offline styling & assistance', null,
      includedIn: ['royal']),
  _Addon('brideSaree', 'Saree Draping for Bride', 'Professional bridal saree draping', 3000,
      includedIn: ['signature', 'royal']),
  _Addon('gPremium', 'Bridesmaid / Party Makeup: Premium',
      'Estée Lauder, Huda Beauty, Bobbi Brown & more. Lashes, coloured lens & hairstyle included',
      null, perPerson: true),
  _Addon('gFace', 'Bridesmaid / Party Makeup: Essential', 'Face makeup', 5000, perPerson: true),
  _Addon('gHair', 'Guest Hairstyle', 'Add-on to Essential', 3000, perPerson: true),
  _Addon('gSaree', 'Guest Saree Draping', 'Add-on to Essential', 2000, perPerson: true),
];

const _events = ['Wedding', 'Reception', 'Engagement', 'Nikah', 'Haldi / Mehendi', 'Save the date'];
const _defaultNote =
    'Only premium, skin-friendly products are used to ensure a flawless, radiant and long-lasting finish.';
const _kDraft = 'tnm.draft';
const _kPrices = 'tnm.prices';

// ─────────────────────────────────────────────────────────────────────────
//  Palette (builder follows light/dark; the sheet is always light)
// ─────────────────────────────────────────────────────────────────────────
const _wine = Color(0xFF5E1B2A);
const _wineDeep = Color(0xFF451320);

class _Pal {
  final Color bg, surface, fg, muted, line, blush, chip, accent, cream;
  const _Pal(this.bg, this.surface, this.fg, this.muted, this.line, this.blush,
      this.chip, this.accent, this.cream);
  static const light = _Pal(Color(0xFFF6F2F1), Colors.white, Color(0xFF2A1A1E),
      Color(0xFF7A666B), Color(0xFFE7DCDD), Color(0xFFF3E6E8), Color(0xFFF1E4E6),
      Color(0xFF5E1B2A), Color(0xFFF7EED3));
  static const dark = _Pal(Color(0xFF1B1214), Color(0xFF251A1D), Color(0xFFF3E9EA),
      Color(0xFFB59EA3), Color(0xFF3C2A2F), Color(0xFF33212A), Color(0xFF3A242B),
      Color(0xFFF0B9C4), Color(0xFF3B2F1E));
}

// Sheet colours.
const _sFg = Color(0xFF2A1A1E);
const _sMuted = Color(0xFF7A666B);
const _sLine = Color(0xFFEADFE0);
const _sTint = Color(0xFFF8F0E0);
const _sRecCol = Color(0xFFFBF2F3);
const _sBody = Color(0xFF4C3A3F);
const _sHead = Color(0xFF5A4146);
const _sOk = Color(0xFF2F7A4B);

String _inr(num v) {
  final s = v.round().abs().toString();
  String out;
  if (s.length <= 3) {
    out = s;
  } else {
    final last3 = s.substring(s.length - 3);
    var rest = s.substring(0, s.length - 3);
    final parts = <String>[];
    while (rest.length > 2) {
      parts.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) parts.insert(0, rest);
    out = '${parts.join(',')},$last3';
  }
  return '${v < 0 ? '-' : ''}₹$out';
}

String _fmtDate(DateTime d) => DateFormat('d MMM y').format(d);

// ─────────────────────────────────────────────────────────────────────────
//  Computed quote
// ─────────────────────────────────────────────────────────────────────────
class _Line {
  final _Addon addon;
  final int qty;
  final double? rate;
  double? get amount => rate == null ? null : rate! * qty;
  const _Line(this.addon, this.qty, this.rate);
}

class _Totals {
  final double base, add, total;
  const _Totals(this.base, this.add, this.total);
}

class _Quote {
  final String no;
  final DateTime today, validUntil;
  final String name, phone, event, venue, notes;
  final DateTime? date;
  final List<_Pkg> pkgs;
  final String rec;
  final Map<String, double?> prices;
  final List<_Line> lines;
  final double travel, discount, advance;
  final Map<String, _Totals> totals;
  bool get onRequest => lines.any((l) => l.amount == null);

  const _Quote({
    required this.no,
    required this.today,
    required this.validUntil,
    required this.name,
    required this.phone,
    required this.event,
    required this.venue,
    required this.notes,
    required this.date,
    required this.pkgs,
    required this.rec,
    required this.prices,
    required this.lines,
    required this.travel,
    required this.discount,
    required this.advance,
    required this.totals,
  });
}

class _AddonSel {
  bool on;
  int qty;
  _AddonSel({this.on = false, this.qty = 1});
}

// ─────────────────────────────────────────────────────────────────────────
//  State
// ─────────────────────────────────────────────────────────────────────────
class _QuoteBuilderTabState extends ConsumerState<QuoteBuilderTab> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  String? _districtId;
  final _travel = TextEditingController(text: '0');
  final _discount = TextEditingController(text: '0');
  final _validDays = TextEditingController(text: '15');
  final _advance = TextEditingController(text: '0');
  final _notes = TextEditingController(text: _defaultNote);
  final _sheetKey = GlobalKey();

  DateTime? _date;
  String _event = _events.first;
  Map<String, bool> _show = {for (final p in _packages) p.id: true};
  String _rec = 'signature';
  Map<String, _AddonSel> _sel = {};
  String? _no;

  /// Price-list overrides saved on this device. A key mapped to null means
  /// "price on request"; a missing key means "use the default".
  Map<String, double?> _overrides = {};

  SharedPreferences? _prefs;
  String? _toast;
  Timer? _toastTimer;
  bool _busyPdf = false;

  @override
  void initState() {
    super.initState();
    _seedExample();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _travel, _discount, _validDays, _advance, _notes]) {
      c.dispose();
    }
    _toastTimer?.cancel();
    super.dispose();
  }

  void _seedExample() {
    _sel = {
      'brideSaree': _AddonSel(on: true),
      'gFace': _AddonSel(on: true, qty: 2),
      'gHair': _AddonSel(on: true, qty: 2),
    };
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _prefs = prefs;
      final rawPrices = prefs.getString(_kPrices);
      final rawDraft = prefs.getString(_kDraft);
      if (!mounted) return;
      setState(() {
        if (rawPrices != null) {
          final m = jsonDecode(rawPrices) as Map<String, dynamic>;
          _overrides = m.map((k, v) => MapEntry(k, (v as num?)?.toDouble()));
        }
        if (rawDraft != null) _restore(jsonDecode(rawDraft) as Map<String, dynamic>);
      });
    } catch (_) {
      // Storage unavailable or corrupt: start from the example quote.
    }
  }

  void _restore(Map<String, dynamic> d) {
    final show = d['show'] as Map<String, dynamic>?;
    if (show != null) {
      _show = {for (final p in _packages) p.id: show[p.id] != false};
      if (!_show.values.any((v) => v)) _show[_packages.first.id] = true;
    }
    final rec = d['rec'] as String?;
    if (_packages.any((p) => p.id == rec)) _rec = rec!;
    final addons = d['addons'] as Map<String, dynamic>?;
    if (addons != null) {
      _sel = addons.map((k, v) {
        final m = v as Map<String, dynamic>;
        return MapEntry(k, _AddonSel(on: m['on'] == true, qty: (m['qty'] as num?)?.toInt() ?? 1));
      });
    }
    _no = d['no'] as String?;
    final f = d['f'] as Map<String, dynamic>? ?? const {};
    _name.text = f['name'] ?? '';
    _phone.text = f['phone'] ?? '';
    final did = f['districtId'] as String?;
    _districtId = (did == null || did.isEmpty) ? null : did;
    _travel.text = f['travel'] ?? '0';
    _discount.text = f['discount'] ?? '0';
    _validDays.text = f['validDays'] ?? '15';
    _advance.text = f['advance'] ?? '0';
    _notes.text = f['notes'] ?? _defaultNote;
    if (_events.contains(f['event'])) _event = f['event'];
    _date = DateTime.tryParse(f['date'] ?? '');
  }

  void _save() {
    final prefs = _prefs;
    if (prefs == null) return;
    final draft = {
      'show': _show,
      'rec': _rec,
      'no': _no,
      'addons': _sel.map((k, v) => MapEntry(k, {'on': v.on, 'qty': v.qty})),
      'f': {
        'name': _name.text,
        'phone': _phone.text,
        'districtId': _districtId ?? '',
        'travel': _travel.text,
        'discount': _discount.text,
        'validDays': _validDays.text,
        'advance': _advance.text,
        'notes': _notes.text,
        'event': _event,
        'date': _date == null ? '' : DateFormat('yyyy-MM-dd').format(_date!),
      },
    };
    unawaited(prefs.setString(_kDraft, jsonEncode(draft)));
  }

  void _changed([VoidCallback? fn]) {
    setState(() => fn?.call());
    _save();
  }

  void _showToast(String msg) {
    _toastTimer?.cancel();
    setState(() => _toast = msg);
    _toastTimer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  String _quoteNo() {
    if (_no == null) {
      final d = DateTime.now();
      _no = 'TNM-${DateFormat('yyMMdd').format(d)}-${100 + Random().nextInt(900)}';
      _save();
    }
    return _no!;
  }

  double _num(TextEditingController c) => max(0, double.tryParse(c.text.trim()) ?? 0);

  // ── Prices ─────────────────────────────────────────────────────────────
  District? _selectedDistrict(List<District> districts) =>
      districts.where((d) => d.id == _districtId).firstOrNull;

  Map<String, double?> _defaultPrices(List<ServicePackage> erp, District? district) {
    final out = <String, double?>{};
    for (final p in _packages) {
      final match = erp.where((e) => e.name.trim().toLowerCase() == p.erp.toLowerCase()).firstOrNull;
      out[p.id] = match != null ? match.effectivePriceForDistrict(district?.id) : p.price;
    }
    for (final a in _addons) {
      out[a.id] = a.price;
    }
    return out;
  }

  Map<String, double?> _prices(Map<String, double?> defaults) => {
    for (final e in defaults.entries)
      e.key: _overrides.containsKey(e.key) ? _overrides[e.key] : e.value,
  };

  _Quote _compute(Map<String, double?> prices, String venue) {
    final pkgs = _packages.where((p) => _show[p.id] == true).toList();
    final lines = [
      for (final a in _addons)
        if (_sel[a.id]?.on == true)
          _Line(a, a.perPerson ? max(1, _sel[a.id]!.qty) : 1, prices[a.id]),
    ];
    final travel = _num(_travel), discount = _num(_discount);
    final totals = {
      for (final p in pkgs)
        p.id: () {
          final base = prices[p.id] ?? 0;
          final add = lines.fold<double>(0, (s, l) =>
              s + (l.amount == null || l.addon.includedIn.contains(p.id) ? 0 : l.amount!));
          return _Totals(base, add, max(0, base + add + travel - discount));
        }(),
    };
    final today = DateTime.now();
    final days = _num(_validDays).round();
    return _Quote(
      no: _quoteNo(),
      today: today,
      validUntil: today.add(Duration(days: days == 0 ? 15 : days)),
      name: _name.text.trim(),
      phone: _phone.text.trim(),
      event: _event,
      venue: venue,
      notes: _notes.text.trim(),
      date: _date,
      pkgs: pkgs,
      rec: _rec,
      prices: prices,
      lines: lines,
      travel: travel,
      discount: discount,
      advance: _num(_advance),
      totals: totals,
    );
  }

  // ── Actions ────────────────────────────────────────────────────────────
  String _waText(_Quote q) {
    final l = <String>[];
    l.addAll(['*TEAM N MAKEOVERS*', '_Bridal Makeup Quote · ${q.no}_', '']);
    if (q.name.isNotEmpty) l.add('Dear ${q.name},');
    l.addAll([
      'Thank you for your enquiry! Here are our bridal packages'
          '${q.date != null ? ' for your ${q.event.toLowerCase()} on ${_fmtDate(q.date!)}' : ''}'
          '${q.venue.isNotEmpty ? ' at ${q.venue}' : ''}:',
      '',
    ]);
    for (final p in q.pkgs) {
      final i = _packages.indexOf(p);
      l.add('*${p.name.toUpperCase()}*${p.id == q.rec ? ' ⭐ _Recommended_' : ''} · ${p.tech}');
      l.add('*${q.prices[p.id] != null ? _inr(q.prices[p.id]!) : 'Price on request'}*');
      l.add('_${p.brief}_');
      for (final f in _features.skip(2)) {
        if (f[1 + i] == true) l.add('✓ ${f[0]}');
      }
      l.add('');
    }
    if (q.lines.isNotEmpty) {
      l.add('*ADD-ONS & GUEST SERVICES*');
      for (final x in q.lines) {
        final free = x.addon.includedIn.isEmpty
            ? ''
            : ' (free with ${x.addon.includedIn.map((id) => _packages.firstWhere((p) => p.id == id).name).join(' & ')})';
        l.add('• ${x.addon.name}${x.qty > 1 ? ' × ${x.qty}' : ''}: '
            '${x.amount == null ? 'on request' : _inr(x.amount!)}$free');
      }
      l.add('');
    }
    if (q.lines.isNotEmpty || q.travel > 0 || q.discount > 0) {
      l.add('*TOTAL*${q.travel > 0 ? ' (incl. travel ${_inr(q.travel)})' : ''}'
          '${q.discount > 0 ? ' (after ${_inr(q.discount)} discount)' : ''}');
      for (final p in q.pkgs) {
        l.add('${p.name}: *${_inr(q.totals[p.id]!.total)}*');
      }
      if (q.onRequest) l.add('_Items on request are priced during consultation._');
      l.add('');
    }
    if (q.advance > 0) l.add('Booking advance: ${_inr(q.advance)} to confirm your date.');
    l.add('Quote valid until ${_fmtDate(q.validUntil)}.');
    if (q.notes.isNotEmpty) l.addAll(['', q.notes]);
    l.addAll(['', '_Your Look. Your Style. Your Day._ ✨']);
    return l.join('\n');
  }

  Future<void> _copyWa(_Quote q) async {
    try {
      await Clipboard.setData(ClipboardData(text: _waText(q)));
      _showToast('Message copied. Paste it in WhatsApp');
    } catch (_) {
      _showToast('Could not copy. Please try again');
    }
  }

  Future<void> _openWa(_Quote q) async {
    var digits = q.phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) digits = '91$digits';
    final uri = Uri.parse(
      'https://wa.me/${digits.isEmpty ? '' : digits}?text=${Uri.encodeComponent(_waText(q))}',
    );
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) _showToast('Could not open WhatsApp');
  }

  Future<void> _downloadPdf(_Quote q) async {
    final boundary = _sheetKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;
    setState(() => _busyPdf = true);
    try {
      final image = await boundary.toImage(pixelRatio: 2.5);
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
      final doc = pw.Document();
      const width = 595.0; // A4 width in points; height follows the sheet.
      doc.addPage(pw.Page(
        pageFormat: PdfPageFormat(width, width * image.height / image.width),
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.fill),
      ));
      final safeName = q.name.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
      await Printing.sharePdf(
        bytes: await doc.save(),
        filename: 'Quote_${q.no}${safeName.isEmpty ? '' : '_$safeName'}.pdf',
      );
    } catch (_) {
      _showToast('Could not create the PDF');
    } finally {
      if (mounted) setState(() => _busyPdf = false);
    }
  }

  void _createInvoice(_Quote q, District? district) {
    final rec = q.pkgs.any((p) => p.id == q.rec) ? q.rec : q.pkgs.first.id;
    final pkg = _packages.firstWhere((p) => p.id == rec);
    final lines = <SpotInvoiceLine>[
      SpotInvoiceLine(label: '${pkg.name} bridal package · ${pkg.tech}', amount: q.prices[rec] ?? 0),
      for (final l in q.lines)
        if (l.amount != null && !l.addon.includedIn.contains(rec))
          SpotInvoiceLine(label: l.qty > 1 ? '${l.addon.name} × ${l.qty}' : l.addon.name, amount: l.amount!),
      if (q.travel > 0) SpotInvoiceLine(label: 'Travel / location', amount: q.travel),
      if (q.discount > 0) SpotInvoiceLine(label: 'Discount', amount: -q.discount),
    ];
    widget.onCreateInvoice(q.name, q.phone, district?.id, lines);
  }

  void _newQuote() {
    _changed(() {
      _show = {for (final p in _packages) p.id: true};
      _rec = 'signature';
      _sel = {};
      _no = null;
      _districtId = null;
      for (final c in [_name, _phone]) {
        c.clear();
      }
      _date = null;
      _event = _events.first;
      _travel.text = '0';
      _discount.text = '0';
      _validDays.text = '15';
      _advance.text = '0';
      _notes.text = _defaultNote;
    });
    _showToast('Started a new quote');
  }

  void _setOverride(String id, double? v, Map<String, double?> defaults) {
    setState(() {
      if (v == defaults[id]) {
        _overrides.remove(id);
      } else {
        _overrides[id] = v;
      }
    });
    unawaited(_prefs?.setString(_kPrices, jsonEncode(_overrides)));
  }

  Future<void> _openPriceList(Map<String, double?> defaults, _Pal pal) async {
    await showDialog<void>(
      context: context,
      barrierColor: const Color(0x731E0A0F),
      builder: (ctx) => _PriceListDialog(
        pal: pal,
        prices: () => _prices(defaults),
        onChanged: (id, v) => _setOverride(id, v, defaults),
        onRestore: () {
          setState(() => _overrides = {});
          unawaited(_prefs?.remove(_kPrices));
          _showToast('Default prices restored');
        },
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final pal = Theme.of(context).brightness == Brightness.dark ? _Pal.dark : _Pal.light;
    final erp = ref.watch(packagesProvider).value ?? const <ServicePackage>[];
    final districts = ref.watch(districtsProvider).value ?? const <District>[];
    final district = _selectedDistrict(districts);
    final defaults = _defaultPrices(erp, district);
    final q = _compute(_prices(defaults), district?.name ?? '');
    final body = GoogleFonts.archivoTextTheme();

    return Theme(
      data: Theme.of(context).copyWith(textTheme: body),
      child: DefaultTextStyle(
        style: GoogleFonts.archivo(fontSize: 15, height: 1.5, color: pal.fg),
        child: ColoredBox(
          color: pal.bg,
          child: Stack(
            children: [
              Column(
                children: [
                  _AppBar(onPrices: () => _openPriceList(defaults, pal)),
                  Expanded(
                    child: LayoutBuilder(builder: (context, c) {
                      final wide = c.maxWidth >= 960;
                      final builder = _builder(q, pal, district, districts);
                      final sheet = RepaintBoundary(key: _sheetKey, child: _QuoteSheet(q: q));
                      if (!wide) {
                        return SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(16, 24, 16, 60),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [builder, const SizedBox(height: 24), sheet],
                          ),
                        );
                      }
                      final builderWidth = (c.maxWidth * 0.3).clamp(320.0, 420.0);
                      return Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1440),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: builderWidth + 24,
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.fromLTRB(20, 24, 4, 24),
                                  child: builder,
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.fromLTRB(0, 24, 20, 60),
                                  child: sheet,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
              if (_toast != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 24,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(color: pal.fg, borderRadius: BorderRadius.circular(10)),
                      child: Text(_toast!, style: TextStyle(color: pal.bg, fontSize: 14)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _districtDropdown(_Pal pal, List<District> districts) {
    final sorted = [...districts.where((d) => d.isActive || d.id == _districtId)]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    // Until districts load, a saved id has no matching item: show the hint
    // and re-seed (via the key) once the list arrives.
    final value = sorted.any((d) => d.id == _districtId) ? _districtId : null;
    return DropdownButtonFormField<String>(
      key: ValueKey('quote-district-${sorted.length}-$value'),
      initialValue: value,
      isExpanded: true,
      isDense: true,
      menuMaxHeight: 360,
      dropdownColor: pal.surface,
      style: TextStyle(fontSize: 15, color: pal.fg),
      hint: Text('Select district', style: TextStyle(fontSize: 15, color: pal.muted.withValues(alpha: 0.7))),
      decoration: _inputDeco(pal, null),
      items: [
        for (final d in sorted)
          DropdownMenuItem(value: d.id, child: Text(d.name, overflow: TextOverflow.ellipsis)),
      ],
      onChanged: (id) => _changed(() => _districtId = id),
    );
  }

  Widget _builder(_Quote q, _Pal pal, District? district, List<District> districts) {
    Widget field(String label, Widget input) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: TextStyle(fontSize: 12.5, color: pal.muted)),
        const SizedBox(height: 4),
        input,
      ],
    );
    Widget text(TextEditingController c, {String? hint, bool number = false, bool phone = false, int lines = 1}) =>
        TextField(
          controller: c,
          onChanged: (_) => _changed(),
          minLines: lines,
          maxLines: lines == 1 ? 1 : null,
          keyboardType: number
              ? TextInputType.number
              : phone
              ? TextInputType.phone
              : (lines > 1 ? TextInputType.multiline : TextInputType.text),
          inputFormatters: number ? [FilteringTextInputFormatter.digitsOnly] : null,
          style: TextStyle(fontSize: 15, color: pal.fg),
          decoration: _inputDeco(pal, hint),
        );
    Widget row2(Widget a, Widget b) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [Expanded(child: a), const SizedBox(width: 10), Expanded(child: b)],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Panel(pal: pal, title: 'Client', children: [
          field('Bride / customer name', text(_name, hint: 'e.g. Ayesha Rahman')),
          row2(
            field('Phone', text(_phone, hint: '+91', phone: true)),
            field('Wedding date', _DateInput(
              pal: pal,
              value: _date,
              onPick: (d) => _changed(() => _date = d),
            )),
          ),
          row2(
            field('Event', DropdownButtonFormField<String>(
              initialValue: _event,
              isExpanded: true,
              isDense: true,
              dropdownColor: pal.surface,
              style: TextStyle(fontSize: 15, color: pal.fg),
              decoration: _inputDeco(pal, null),
              items: [for (final e in _events) DropdownMenuItem(value: e, child: Text(e))],
              onChanged: (v) => _changed(() => _event = v ?? _event),
            )),
            field('Venue / district', _districtDropdown(pal, districts)),
          ),
        ]),
        const SizedBox(height: 16),
        _Panel(pal: pal, title: 'Bridal packages in this quote', children: [
          for (final p in _packages)
            _PkgOption(
              pal: pal,
              pkg: p,
              price: q.prices[p.id],
              on: _show[p.id] == true,
              rec: _rec == p.id,
              onToggle: () {
                final next = !(_show[p.id] == true);
                if (!next && _show.values.where((v) => v).length == 1) {
                  _showToast('Keep at least one package in the quote');
                  return;
                }
                _changed(() => _show[p.id] = next);
              },
              onRecommend: () => _changed(() {
                _rec = p.id;
                _show[p.id] = true;
              }),
            ),
        ]),
        const SizedBox(height: 16),
        _Panel(pal: pal, title: 'Add-ons & guest services', gap: 0, children: [
          for (var i = 0; i < _addons.length; i++)
            _AddonRow(
              pal: pal,
              addon: _addons[i],
              first: i == 0,
              price: q.prices[_addons[i].id],
              sel: _sel[_addons[i].id],
              onToggle: (on) => _changed(() => (_sel[_addons[i].id] ??= _AddonSel()).on = on),
              onQty: (n) => _changed(() => _sel[_addons[i].id]!.qty = max(1, n)),
            ),
        ]),
        const SizedBox(height: 16),
        _Panel(pal: pal, title: 'Adjustments', children: [
          row2(
            field('Travel / location charge (₹)', text(_travel, number: true)),
            field('Discount (₹)', text(_discount, number: true)),
          ),
          row2(
            field('Valid for (days)', text(_validDays, number: true)),
            field('Booking advance (₹)', text(_advance, number: true)),
          ),
          field('Note to client', text(_notes, lines: 3)),
        ]),
        const SizedBox(height: 16),
        _Btn(pal: pal, label: 'Copy WhatsApp message', primary: true, onTap: () => _copyWa(q)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _Btn(pal: pal, label: 'Send on WhatsApp', icon: Icons.send_rounded, onTap: () => _openWa(q))),
          const SizedBox(width: 8),
          Expanded(
            child: _Btn(
              pal: pal,
              label: _busyPdf ? 'Preparing…' : 'Download PDF',
              icon: Icons.picture_as_pdf_outlined,
              onTap: _busyPdf ? null : () => _downloadPdf(q),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        _Btn(
          pal: pal,
          label: 'Create invoice (${_packages.firstWhere((p) => p.id == (q.pkgs.any((p) => p.id == q.rec) ? q.rec : q.pkgs.first.id)).name})',
          icon: Icons.receipt_long_rounded,
          onTap: () => _createInvoice(q, district),
        ),
        const SizedBox(height: 8),
        _Btn(pal: pal, label: 'New quote', onTap: _newQuote),
      ],
    );
  }
}

InputDecoration _inputDeco(_Pal pal, String? hint) {
  OutlineInputBorder b(Color c, [double w = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(color: c, width: w),
  );
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: pal.muted.withValues(alpha: 0.7)),
    isDense: true,
    filled: true,
    fillColor: pal.bg,
    contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
    border: b(pal.line),
    enabledBorder: b(pal.line),
    focusedBorder: b(pal.accent, 2),
  );
}

// ─────────────────────────────────────────────────────────────────────────
//  Builder widgets
// ─────────────────────────────────────────────────────────────────────────
class _AppBar extends StatelessWidget {
  final VoidCallback onPrices;
  const _AppBar({required this.onPrices});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _wine,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Image.asset('assets/images/teamn_logo.png', width: 44, height: 44),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Team N Makeovers',
                    style: GoogleFonts.italiana(fontSize: 24, height: 1, letterSpacing: 0.96, color: Colors.white)),
                const SizedBox(height: 3),
                Text('Bridal Quote Builder',
                    style: TextStyle(fontSize: 12, letterSpacing: 0.24, color: Colors.white.withValues(alpha: 0.75))),
              ],
            ),
          ),
          Material(
            color: Colors.white.withValues(alpha: 0.12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onPrices,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text('Edit price list', style: TextStyle(fontSize: 13, color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final _Pal pal;
  final String title;
  final List<Widget> children;
  final double gap;
  const _Panel({required this.pal, required this.title, required this.children, this.gap = 12});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: pal.surface,
        border: Border.all(color: pal.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title.toUpperCase(),
              style: TextStyle(fontSize: 12, letterSpacing: 1.2, fontWeight: FontWeight.w600, color: pal.muted)),
          for (final c in children) ...[SizedBox(height: gap == 0 ? 4 : gap), c],
        ],
      ),
    );
  }
}

class _DateInput extends StatelessWidget {
  final _Pal pal;
  final DateTime? value;
  final ValueChanged<DateTime?> onPick;
  const _DateInput({required this.pal, required this.value, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () async {
        final now = DateTime.now();
        final d = await showDatePicker(
          context: context,
          initialDate: value ?? now,
          firstDate: DateTime(now.year - 1),
          lastDate: DateTime(now.year + 5),
        );
        if (d != null) onPick(d);
      },
      child: InputDecorator(
        decoration: _inputDeco(pal, null).copyWith(
          suffixIcon: value == null
              ? Icon(Icons.calendar_today_outlined, size: 16, color: pal.muted)
              : IconButton(
                  icon: Icon(Icons.close, size: 16, color: pal.muted),
                  onPressed: () => onPick(null),
                ),
          suffixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 20),
        ),
        child: Text(
          value == null ? 'dd/mm/yyyy' : DateFormat('dd/MM/yyyy').format(value!),
          style: TextStyle(fontSize: 15, color: value == null ? pal.muted.withValues(alpha: 0.7) : pal.fg),
        ),
      ),
    );
  }
}

class _PkgOption extends StatelessWidget {
  final _Pal pal;
  final _Pkg pkg;
  final double? price;
  final bool on, rec;
  final VoidCallback onToggle, onRecommend;
  const _PkgOption({
    required this.pal,
    required this.pkg,
    required this.price,
    required this.on,
    required this.rec,
    required this.onToggle,
    required this.onRecommend,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: on ? pal.blush : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: on ? pal.accent : pal.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              _Check(pal: pal, value: on, onChanged: (_) => onToggle()),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(TextSpan(children: [
                      TextSpan(text: pkg.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      TextSpan(text: '  ${price != null ? _inr(price!) : 'On request'}'),
                    ]), style: TextStyle(fontSize: 15, color: pal.fg)),
                    Text('${pkg.tech} · ERP: ${pkg.erp}', style: TextStyle(fontSize: 12, color: pal.muted)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Material(
                color: rec ? _wine : pal.surface,
                shape: StadiumBorder(side: BorderSide(color: rec ? _wine : pal.line)),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: onRecommend,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    child: Text(rec ? '★ Recommended' : 'Recommend',
                        style: TextStyle(fontSize: 11.5, color: rec ? Colors.white : pal.fg)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Check extends StatelessWidget {
  final _Pal pal;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _Check({required this.pal, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 18,
      child: Checkbox(
        value: value,
        onChanged: (v) => onChanged(v ?? false),
        activeColor: _wine,
        side: BorderSide(color: pal.muted, width: 1.5),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
      ),
    );
  }
}

class _AddonRow extends StatelessWidget {
  final _Pal pal;
  final _Addon addon;
  final bool first;
  final double? price;
  final _AddonSel? sel;
  final ValueChanged<bool> onToggle;
  final ValueChanged<int> onQty;
  const _AddonRow({
    required this.pal,
    required this.addon,
    required this.first,
    required this.price,
    required this.sel,
    required this.onToggle,
    required this.onQty,
  });

  @override
  Widget build(BuildContext context) {
    final on = sel?.on == true;
    return Container(
      decoration: BoxDecoration(
        border: first ? null : Border(top: BorderSide(color: pal.line)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: () => onToggle(!on),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _Check(pal: pal, value: on, onChanged: onToggle),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(addon.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: pal.fg)),
                  Text(addon.note, style: TextStyle(fontSize: 12, height: 1.4, color: pal.muted)),
                  if (addon.perPerson && on) ...[
                    const SizedBox(height: 4),
                    _Qty(pal: pal, value: sel!.qty, onChanged: onQty),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            price == null
                ? Text('On request',
                    style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: pal.muted))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(_inr(price!), style: TextStyle(fontSize: 13, color: pal.fg)),
                      if (addon.perPerson)
                        Text('per person', style: TextStyle(fontSize: 11, color: pal.muted)),
                    ],
                  ),
          ],
        ),
      ),
    );
  }
}

class _Qty extends StatelessWidget {
  final _Pal pal;
  final int value;
  final ValueChanged<int> onChanged;
  const _Qty({required this.pal, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget btn(String t, int d) => Material(
      color: pal.chip,
      child: InkWell(
        onTap: () => onChanged(value + d),
        child: SizedBox(width: 28, height: 26, child: Center(child: Text(t, style: TextStyle(color: pal.fg)))),
      ),
    );
    return Container(
      decoration: BoxDecoration(border: Border.all(color: pal.line), borderRadius: BorderRadius.circular(8)),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          btn('−', -1),
          SizedBox(
            width: 38,
            child: Text('$value', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: pal.fg)),
          ),
          btn('+', 1),
        ],
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  final _Pal pal;
  final String label;
  final bool primary;
  final IconData? icon;
  final VoidCallback? onTap;
  const _Btn({required this.pal, required this.label, this.primary = false, this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final fg = primary ? Colors.white : pal.fg;
    return Material(
      color: primary ? _wine : pal.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(9),
        side: BorderSide(color: primary ? _wine : pal.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[Icon(icon, size: 16, color: fg), const SizedBox(width: 6)],
              Flexible(
                child: Text(label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: fg)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PriceListDialog extends StatefulWidget {
  final _Pal pal;
  final Map<String, double?> Function() prices;
  final void Function(String id, double? value) onChanged;
  final VoidCallback onRestore;
  const _PriceListDialog({
    required this.pal,
    required this.prices,
    required this.onChanged,
    required this.onRestore,
  });

  @override
  State<_PriceListDialog> createState() => _PriceListDialogState();
}

class _PriceListDialogState extends State<_PriceListDialog> {
  late Map<String, TextEditingController> _ctrls = _fresh();

  Map<String, TextEditingController> _fresh() {
    final p = widget.prices();
    String t(double? v) => v == null ? '' : v.round().toString();
    return {
      for (final x in _packages) x.id: TextEditingController(text: t(p[x.id])),
      for (final a in _addons) a.id: TextEditingController(text: t(p[a.id])),
    };
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pal = widget.pal;
    final rows = [
      for (final p in _packages) (p.id, '${p.name} package', '${p.tech} · ERP: ${p.erp}'),
      for (final a in _addons) (a.id, a.name, a.perPerson ? 'per person' : ''),
    ];
    return Dialog(
      backgroundColor: pal.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
      alignment: Alignment.topCenter,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: DefaultTextStyle(
            style: GoogleFonts.archivo(fontSize: 15, height: 1.5, color: pal.fg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Price list',
                    style: GoogleFonts.italiana(fontSize: 26, height: 1.1, color: pal.accent)),
                const SizedBox(height: 12),
                Text('Saved on this device. Leave a price empty to show “Price on request” in the quote.',
                    style: TextStyle(fontSize: 13, color: pal.muted)),
                const SizedBox(height: 12),
                for (final (id, name, sub) in rows)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(border: Border(top: BorderSide(color: pal.line))),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name),
                              if (sub.isNotEmpty)
                                Text(sub, style: TextStyle(fontSize: 11.5, color: pal.muted)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 130,
                          child: TextField(
                            controller: _ctrls[id],
                            textAlign: TextAlign.right,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            style: TextStyle(fontSize: 15, color: pal.fg),
                            decoration: _inputDeco(pal, 'On request').copyWith(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                            ),
                            onChanged: (v) => widget.onChanged(id, v.trim().isEmpty ? null : double.parse(v)),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 4),
                Row(children: [
                  Expanded(
                    child: _Btn(
                      pal: pal,
                      label: 'Restore defaults',
                      onTap: () {
                        widget.onRestore();
                        setState(() {
                          for (final c in _ctrls.values) {
                            c.dispose();
                          }
                          _ctrls = _fresh();
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _Btn(pal: pal, label: 'Done', primary: true, onTap: () => Navigator.pop(context)),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
//  Client-facing quote sheet (always light)
// ─────────────────────────────────────────────────────────────────────────
class _QuoteSheet extends StatelessWidget {
  final _Quote q;
  const _QuoteSheet({required this.q});

  @override
  Widget build(BuildContext context) {
    final display = GoogleFonts.italiana();
    return LayoutBuilder(builder: (context, c) {
      final narrow = c.maxWidth < 600;
      return Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFFFFFDFA),
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(color: Color(0x0F3C141E), blurRadius: 2, offset: Offset(0, 1)),
            BoxShadow(color: Color(0x143C141E), blurRadius: 32, offset: Offset(0, 12)),
          ],
        ),
        child: DefaultTextStyle(
          style: GoogleFonts.archivo(fontSize: 14, height: 1.5, color: _sFg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _head(display, narrow),
              Padding(
                padding: narrow
                    ? const EdgeInsets.fromLTRB(16, 20, 16, 24)
                    : const EdgeInsets.fromLTRB(32, 26, 32, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _client(),
                    const SizedBox(height: 28),
                    _title(display, 'Bridal Makeup Packages', 'Choose the experience that suits your style'),
                    _cards(display, c.maxWidth < 760),
                    const SizedBox(height: 28),
                    _title(display, 'What’s Included'),
                    _featuresTable(),
                    if (q.lines.isNotEmpty) ...[
                      const SizedBox(height: 28),
                      _title(display, 'Add-ons & Guest Services'),
                      _addonsTable(),
                    ],
                    const SizedBox(height: 28),
                    _title(display, 'Your Total', 'per package option'),
                    _totalsTable(),
                    if (q.onRequest)
                      const Padding(
                        padding: EdgeInsets.fromLTRB(2, 8, 2, 0),
                        child: Text(
                          'Services marked “On request” will be priced during consultation and are not in the totals above.',
                          style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: _sMuted),
                        ),
                      ),
                    if (q.advance > 0)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(2, 8, 2, 0),
                        child: Text.rich(TextSpan(children: [
                          const TextSpan(text: 'Booking advance: '),
                          TextSpan(text: _inr(q.advance), style: const TextStyle(fontWeight: FontWeight.w700)),
                          const TextSpan(text: ' to confirm your date.'),
                        ]), style: const TextStyle(fontSize: 13.5)),
                      ),
                    if (q.notes.isNotEmpty) ...[
                      const SizedBox(height: 28),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFBF6EF),
                          border: Border(left: BorderSide(color: Color(0xFFD9B98A), width: 3)),
                          borderRadius: BorderRadius.horizontal(right: Radius.circular(8)),
                        ),
                        child: Text(q.notes, style: const TextStyle(fontSize: 13, color: _sBody)),
                      ),
                    ],
                    const SizedBox(height: 28),
                    Container(
                      padding: const EdgeInsets.only(top: 18),
                      decoration: const BoxDecoration(border: Border(top: BorderSide(color: _sLine))),
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 16,
                        runSpacing: 6,
                        children: [
                          Text('Your Look. Your Style. Your Day.',
                              style: display.copyWith(fontSize: 18, letterSpacing: 0.72, color: _wine)),
                          const Text('Team N Makeovers · 8000+ bridal transformations · 6+ years',
                              style: TextStyle(fontSize: 12.5, color: _sMuted)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _head(TextStyle display, bool narrow) {
    TextSpan meta(String k, String v) => TextSpan(children: [
      TextSpan(text: '$k '),
      TextSpan(text: v, style: const TextStyle(color: Color(0xFFF7EED3), fontWeight: FontWeight.w600)),
    ]);
    return Container(
      color: _wine,
      padding: narrow ? const EdgeInsets.symmetric(horizontal: 18, vertical: 22) : const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 22,
        runSpacing: 16,
        children: [
          Image.asset('assets/images/teamn_logo.png', width: 84, height: 84),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 200, maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Bridal Makeup Quote',
                    style: display.copyWith(fontSize: 34, height: 1.05, letterSpacing: 1.7, color: Colors.white)),
                const SizedBox(height: 6),
                const Text('Trained under Feeniya Nizan · Founder, Nizan Makeovers',
                    style: TextStyle(fontSize: 13, color: Color(0xFFF2DFC0))),
              ],
            ),
          ),
          Text.rich(
            TextSpan(children: [
              meta('Quote', q.no),
              const TextSpan(text: '\n'),
              meta('Date', _fmtDate(q.today)),
              const TextSpan(text: '\n'),
              meta('Valid until', _fmtDate(q.validUntil)),
            ]),
            textAlign: narrow ? TextAlign.left : TextAlign.right,
            style: const TextStyle(fontSize: 13, height: 1.7, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _client() {
    final items = [
      ('Prepared for', q.name.isEmpty ? '—' : q.name),
      ('Phone', q.phone.isEmpty ? '—' : q.phone),
      ('${q.event} date', q.date == null ? 'To be confirmed' : _fmtDate(q.date!)),
      ('Venue', q.venue.isEmpty ? '—' : q.venue),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(color: _sTint, borderRadius: BorderRadius.circular(10)),
      child: LayoutBuilder(builder: (context, c) {
        final cols = max(1, min(4, ((c.maxWidth + 20) / 170).floor()));
        final w = (c.maxWidth - 20 * (cols - 1)) / cols;
        return Wrap(
          spacing: 20,
          runSpacing: 12,
          children: [
            for (final (k, v) in items)
              SizedBox(
                width: w,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(k.toUpperCase(), style: const TextStyle(fontSize: 11, letterSpacing: 1.1, color: _sMuted)),
                    Text(v, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
          ],
        );
      }),
    );
  }

  Widget _title(TextStyle display, String t, [String? sub]) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Wrap(
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: 12,
      runSpacing: 4,
      children: [
        Text(t, style: display.copyWith(fontSize: 26, height: 1.1, letterSpacing: 0.78, color: _wine)),
        if (sub != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Text(sub, style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: _sMuted)),
          ),
      ],
    ),
  );

  Widget _cards(TextStyle display, bool stack) {
    Widget card(_Pkg p) {
      final rec = p.id == q.rec;
      final price = q.prices[p.id];
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: rec ? _wine : _sLine, width: rec ? 2 : 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.tech.toUpperCase(),
                    style: const TextStyle(fontSize: 11.5, letterSpacing: 1.15, color: _sMuted)),
                const SizedBox(height: 8),
                Text(p.name, style: display.copyWith(fontSize: 28, height: 1, letterSpacing: 1.12, color: _wine)),
                const SizedBox(height: 8),
                Text(price != null ? _inr(price) : 'On request',
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, height: 1.3)),
                const SizedBox(height: 8),
                Text(p.brief, style: const TextStyle(fontSize: 13.5, fontStyle: FontStyle.italic, color: _sBody)),
              ],
            ),
          ),
          if (rec)
            Positioned(
              top: -11,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(color: _wine, borderRadius: BorderRadius.circular(999)),
                child: const Text('RECOMMENDED FOR YOU',
                    style: TextStyle(fontSize: 11, letterSpacing: 0.88, color: Colors.white, height: 1.4)),
              ),
            ),
        ],
      );
    }

    if (stack) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < q.pkgs.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            card(q.pkgs[i]),
          ],
        ],
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 11),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < q.pkgs.length; i++) ...[
              if (i > 0) const SizedBox(width: 14),
              Expanded(child: card(q.pkgs[i])),
            ],
          ],
        ),
      ),
    );
  }

  // ── Tables ─────────────────────────────────────────────────────────────
  Widget _table({
    required List<String> header,
    required List<List<Widget>> rows,
    required Map<int, TableColumnWidth> widths,
    required List<TextAlign> align,
    Set<int> recCols = const {},
    bool lastIsTotal = false,
    double minWidth = 0,
  }) {
    Widget cell(Widget child, int col, {Color? bg, TextAlign? a}) => Container(
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      alignment: switch (a ?? align[col]) {
        TextAlign.center => Alignment.topCenter,
        TextAlign.right => Alignment.topRight,
        _ => Alignment.topLeft,
      },
      child: child,
    );
    final table = Table(
      columnWidths: widths,
      defaultVerticalAlignment: TableCellVerticalAlignment.intrinsicHeight,
      children: [
        TableRow(
          decoration: const BoxDecoration(color: _sTint, border: Border(bottom: BorderSide(color: _sLine))),
          children: [
            for (var i = 0; i < header.length; i++)
              cell(
                Text(header[i].toUpperCase(),
                    textAlign: align[i],
                    style: const TextStyle(fontSize: 12.5, letterSpacing: 0.75, fontWeight: FontWeight.w600, color: _sHead)),
                i,
                bg: recCols.contains(i) ? _sRecCol : null,
              ),
          ],
        ),
        for (var r = 0; r < rows.length; r++)
          TableRow(
            decoration: BoxDecoration(
              color: lastIsTotal && r == rows.length - 1 ? _wine : null,
              border: r == rows.length - 1 ? null : const Border(bottom: BorderSide(color: _sLine)),
            ),
            children: [
              for (var i = 0; i < rows[r].length; i++)
                cell(
                  rows[r][i],
                  i,
                  bg: recCols.contains(i)
                      ? (lastIsTotal && r == rows.length - 1 ? _wineDeep : _sRecCol)
                      : null,
                ),
            ],
          ),
      ],
    );
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(border: Border.all(color: _sLine), borderRadius: BorderRadius.circular(12)),
      child: LayoutBuilder(builder: (context, c) {
        if (c.maxWidth >= minWidth) return table;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(width: minWidth, child: table),
        );
      }),
    );
  }

  Set<int> _recCols() => {
    for (var i = 0; i < q.pkgs.length; i++)
      if (q.pkgs[i].id == q.rec) i + 1,
  };

  Widget _featuresTable() {
    final n = q.pkgs.length;
    return _table(
      header: ['Inclusion', for (final p in q.pkgs) p.name],
      align: [TextAlign.left, for (var i = 0; i < n; i++) TextAlign.center],
      widths: {0: const FlexColumnWidth(2.2), for (var i = 1; i <= n; i++) i: const FlexColumnWidth(1)},
      recCols: _recCols(),
      minWidth: 200.0 + 130 * n,
      rows: [
        for (final f in _features)
          [
            Text(f[0] as String),
            for (final p in q.pkgs)
              switch (f[1 + _packages.indexOf(p)]) {
                true => const Text('✓', textAlign: TextAlign.center, style: TextStyle(color: _sOk, fontWeight: FontWeight.w700)),
                false => const Text('—', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFFC9B6BA))),
                final v => Text('$v', textAlign: TextAlign.center),
              },
          ],
      ],
    );
  }

  Widget _addonsTable() {
    const req = Text('On request', style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: _sMuted));
    return _table(
      header: const ['Service', 'Qty', 'Rate', 'Amount'],
      align: const [TextAlign.left, TextAlign.center, TextAlign.right, TextAlign.right],
      widths: const {
        0: FlexColumnWidth(3),
        1: FixedColumnWidth(64),
        2: FixedColumnWidth(110),
        3: FixedColumnWidth(120),
      },
      minWidth: 520,
      rows: [
        for (final l in q.lines)
          [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.addon.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(l.addon.note, style: const TextStyle(fontSize: 12.5, color: _sMuted)),
                if (l.addon.includedIn.isNotEmpty)
                  Text(
                    'Included free with ${l.addon.includedIn.map((id) => _packages.firstWhere((p) => p.id == id).name).join(' & ')}',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _sOk),
                  ),
              ],
            ),
            Text('${l.qty}', textAlign: TextAlign.center),
            l.rate == null ? req : Text(_inr(l.rate!), textAlign: TextAlign.right),
            l.amount == null ? req : Text(_inr(l.amount!), textAlign: TextAlign.right),
          ],
      ],
    );
  }

  Widget _totalsTable() {
    final n = q.pkgs.length;
    const sub = TextStyle(color: _sHead);
    const disc = TextStyle(color: _sOk);
    const tot = TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Colors.white);
    List<Widget> row(String label, TextStyle s, String Function(_Pkg) v) => [
      Text(label, style: s),
      for (final p in q.pkgs) Text(v(p), textAlign: TextAlign.right, style: s),
    ];
    return _table(
      header: ['', for (final p in q.pkgs) p.name],
      align: [TextAlign.left, for (var i = 0; i < n; i++) TextAlign.right],
      widths: {0: const FlexColumnWidth(1.6), for (var i = 1; i <= n; i++) i: const FlexColumnWidth(1)},
      recCols: _recCols(),
      lastIsTotal: true,
      minWidth: 160.0 + 120 * n,
      rows: [
        row('Bridal package', sub, (p) => _inr(q.totals[p.id]!.base)),
        if (q.lines.isNotEmpty) row('Add-ons & guests', sub, (p) => _inr(q.totals[p.id]!.add)),
        if (q.travel > 0) row('Travel / location', sub, (_) => _inr(q.travel)),
        if (q.discount > 0) row('Discount', disc, (_) => '− ${_inr(q.discount)}'),
        row('Total', tot, (p) => _inr(q.totals[p.id]!.total)),
      ],
    );
  }
}
