import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/state/data_refresh.dart';
import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/features/finance/data/bank_account.dart';
import 'package:nizan_crm/features/finance/presentation/widgets/money_account_picker.dart';
import 'package:nizan_crm/features/finance/services/bank_account_service.dart';
import 'package:nizan_crm/providers/dio_provider.dart';

final _inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
final _day = DateFormat('d MMM yyyy');
const _pageSize = 50;

/// One booking's advance, as listed by GET /booking-advances.
class BookingAdvance {
  final String id;
  final String bookingNumber;
  final String customerName;
  final String phone;
  final double advanceAmount;
  final DateTime? bookedOn;
  final String createdByName;

  /// '' (untracked) | pending | verified | rejected
  final String advanceStatus;
  final String advanceMode;
  final String advancePaymentRef;
  final String accountName;

  const BookingAdvance({
    required this.id,
    this.bookingNumber = '',
    this.customerName = '',
    this.phone = '',
    this.advanceAmount = 0,
    this.bookedOn,
    this.createdByName = '',
    this.advanceStatus = '',
    this.advanceMode = '',
    this.advancePaymentRef = '',
    this.accountName = '',
  });

  factory BookingAdvance.fromJson(Map<String, dynamic> j) {
    final acc = j['advanceMoneyAccount'];
    return BookingAdvance(
      id: j['_id']?.toString() ?? '',
      bookingNumber: j['bookingNumber']?.toString() ?? '',
      customerName: j['customerName']?.toString() ?? '',
      phone: j['phone']?.toString() ?? '',
      advanceAmount: (j['advanceAmount'] as num?)?.toDouble() ?? 0,
      bookedOn: DateTime.tryParse(j['createdAt']?.toString() ?? '')?.toLocal(),
      createdByName: j['createdByName']?.toString() ?? '',
      advanceStatus: j['advanceStatus']?.toString() ?? '',
      advanceMode: j['advanceMode']?.toString() ?? '',
      advancePaymentRef: j['advancePaymentRef']?.toString() ?? '',
      accountName: acc is Map ? acc['name']?.toString() ?? '' : '',
    );
  }
}

/// Where new advances are posted ('' = not set: they wait for Accounts).
final advanceSettingsProvider = FutureProvider.autoDispose<({String id, String name})>((ref) async {
  try {
    final res = await ref.watch(dioProvider).get('/booking-advances/settings');
    final acc = (res.data as Map)['advanceMoneyAccount'];
    return acc is Map ? (id: acc['_id']?.toString() ?? '', name: acc['name']?.toString() ?? '') : (id: '', name: '');
  } catch (e) {
    throw AppException(e, action: 'load advance settings');
  }
});

/// Accounts → Collections → Advances. Sales confirm an advance before they
/// convert the lead; once Accounts picks the account advances land in, every
/// new advance is posted there automatically (Bank & Cash balance moves).
/// Without that setting, advances wait here under "To verify". "Older" lists
/// advances booked before this existed. Loads 50 at a time.
class BookingAdvancesTab extends ConsumerStatefulWidget {
  const BookingAdvancesTab({super.key});

  @override
  ConsumerState<BookingAdvancesTab> createState() => _BookingAdvancesTabState();
}

class _BookingAdvancesTabState extends ConsumerState<BookingAdvancesTab> {
  String _status = 'verified';
  String _search = '';

  final List<BookingAdvance> _rows = [];
  int _page = 0;
  int _pages = 1;
  int _count = 0;
  double _total = 0;
  bool _loading = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Dio get _dio => ref.read(dioProvider);

  Future<void> _reload() async {
    setState(() {
      _rows.clear();
      _page = 0;
      _pages = 1;
      _error = null;
    });
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || _page >= _pages) return;
    setState(() => _loading = true);
    final status = _status;
    final search = _search;
    try {
      final res = await _dio.get('/booking-advances', queryParameters: {
        'status': status,
        'page': _page + 1,
        'limit': _pageSize,
        if (search.trim().isNotEmpty) 'search': search.trim(),
      });
      // Ignore a response for a filter the user has already moved away from.
      if (!mounted || status != _status || search != _search) return;
      final data = (res.data as Map).cast<String, dynamic>();
      setState(() {
        _rows.addAll(((data['rows'] as List?) ?? const [])
            .map((e) => BookingAdvance.fromJson((e as Map).cast<String, dynamic>())));
        _page = (data['page'] as num?)?.toInt() ?? _page + 1;
        _pages = (data['pages'] as num?)?.toInt() ?? 1;
        _count = (data['count'] as num?)?.toInt() ?? _rows.length;
        _total = (data['total'] as num?)?.toDouble() ?? 0;
      });
    } catch (e) {
      if (mounted) setState(() => _error = AppException(e, action: 'load advances'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _setFilter({String? status, String? search}) {
    setState(() {
      if (status != null) _status = status;
      if (search != null) _search = search;
    });
    _reload();
  }

  Future<void> _setStatus(BookingAdvance a, String status, {MoneyChoice? money, required String done}) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _dio.put('/booking-advances/${a.id}/verify', data: {'status': status, ...?money?.toJson()});
      ref.refreshData.bankAccounts();
      messenger.showSnackBar(SnackBar(content: Text(done)));
      _reload();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(AppException(e, action: 'update the advance')))));
    }
  }

  Future<void> _verify(BookingAdvance a, {bool change = false}) async {
    final messenger = ScaffoldMessenger.of(context);
    final money = await showMoneyAccountPicker(
      context,
      title: '${change ? 'Change account' : 'Record advance'} · ${a.customerName}',
      amount: a.advanceAmount,
      moneyIn: true,
      modes: kCollectionPayModes,
      initialMode: a.advanceMode.isEmpty ? 'upi' : a.advanceMode,
      approveLabel: 'Save',
    );
    if (money == null) return;
    if (money.moneyAccountId.isEmpty) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Link a bank / cash account on Bank & Cash Balance first — an advance needs one.')));
      return;
    }
    await _setStatus(a, 'verified', money: money, done: 'Advance recorded');
  }

  Future<void> _pickDefaultAccount(String currentId) async {
    final messenger = ScaffoldMessenger.of(context);
    final banks = ref.read(bankAccountsProvider).value?.accounts.where((b) => b.active && b.isLinked).toList() ??
        const <BankAccount>[];
    String? choice = currentId.isEmpty ? null : currentId;
    final saved = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Where do advances land?'),
          content: SizedBox(
            width: 420,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text(
                'Sales confirm the advance before converting a lead. Every new booking advance will be recorded '
                'in this account straight away. You can still change the account on any single advance.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 14),
              if (banks.isEmpty)
                const Text('No bank / cash account is linked to a ledger yet — link one on Bank & Cash Balance.')
              else
                DropdownButtonFormField<String>(
                  initialValue: banks.any((b) => b.id == choice) ? choice : null,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Account', border: OutlineInputBorder(), isDense: true),
                  items: [
                    for (final b in banks)
                      DropdownMenuItem(value: b.id, child: Text(b.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (v) => setDlg(() => choice = v),
                ),
            ]),
          ),
          actions: [
            if (currentId.isNotEmpty)
              TextButton(onPressed: () => Navigator.pop(ctx, ''), child: const Text('Turn off')),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: choice == null ? null : () => Navigator.pop(ctx, choice),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (saved == null) return;
    try {
      await _dio.put('/booking-advances/settings', data: {'advanceMoneyAccount': saved.isEmpty ? null : saved});
      ref.invalidate(advanceSettingsProvider);
      messenger.showSnackBar(SnackBar(
          content: Text(saved.isEmpty ? 'New advances will wait for Accounts' : 'New advances will be recorded automatically')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(AppException(e, action: 'save the setting')))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    final setting = ref.watch(advanceSettingsProvider);
    ref.watch(bankAccountsProvider); // for the default-account dialog
    const labels = {
      'verified': 'Recorded',
      'pending': 'To verify',
      'rejected': 'Not received',
      'untracked': 'Older (before tracking)',
    };

    final itemCount = _rows.length + 1; // + footer (load more / status)
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        itemCount: itemCount + 1, // + header
        itemBuilder: (context, i) {
          if (i == 0) {
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              // Default account for new advances.
              Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                decoration: BoxDecoration(
                  color: crm.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: crm.border),
                ),
                child: Row(children: [
                  Icon(Icons.savings_outlined, size: 18, color: crm.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: setting.when(
                      loading: () => const Text('Loading…'),
                      error: (e, _) => Text(friendlyErrorMessage(e), style: TextStyle(color: crm.destructive, fontSize: 12)),
                      data: (s) => Text(
                        s.id.isEmpty
                            ? 'New advances wait for Accounts to verify. Choose an account to record them automatically.'
                            : 'New advances are recorded in ${s.name} automatically.',
                        style: TextStyle(fontSize: 12.5, color: crm.textPrimary),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: setting.hasValue ? () => _pickDefaultAccount(setting.value!.id) : null,
                    child: Text(setting.value?.id.isEmpty ?? true ? 'Choose' : 'Change'),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final s in labels.keys)
                  ChoiceChip(label: Text(labels[s]!), selected: _status == s, onSelected: (_) => _setFilter(status: s)),
              ]),
              const SizedBox(height: 10),
              TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search customer, booking no. or phone…',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onSubmitted: (v) => _setFilter(search: v),
              ),
              if (_status == 'untracked') ...[
                const SizedBox(height: 10),
                Text(
                  'Advances booked before tracking started. They are not in the books yet — record one to say '
                  'which account it went to. Only advances after the bank balance date move the current balance.',
                  style: TextStyle(fontSize: 12, color: crm.textSecondary),
                ),
              ],
              const SizedBox(height: 12),
              if (_error == null && (_rows.isNotEmpty || !_loading))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '$_count advance${_count == 1 ? '' : 's'} · ${_inr.format(_total)}'
                    '${_rows.length < _count ? ' · showing ${_rows.length}' : ''}',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: crm.textPrimary),
                  ),
                ),
            ]);
          }
          final idx = i - 1;
          if (idx < _rows.length) return _row(crm, _rows[idx]);
          // Footer.
          if (_error != null) return AppErrorView(error: _error!, onRetry: _loadMore);
          if (_loading) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (_rows.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(child: Text('Nothing here.', style: TextStyle(color: crm.textSecondary))),
            );
          }
          if (_page < _pages) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: OutlinedButton.icon(
                  onPressed: _loadMore,
                  icon: const Icon(Icons.expand_more),
                  label: Text('Load more (${_count - _rows.length} left)'),
                ),
              ),
            );
          }
          return const SizedBox(height: 8);
        },
      ),
    );
  }

  Widget _row(CrmTheme crm, BookingAdvance a) {
    final recorded = a.advanceStatus == 'verified';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: crm.border),
      ),
      child: ListTile(
        title: Text(a.customerName.isEmpty ? a.bookingNumber : a.customerName,
            maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          [
            '#${a.bookingNumber}',
            if (a.bookedOn != null) 'booked ${_day.format(a.bookedOn!)}',
            if (a.createdByName.isNotEmpty) 'by ${a.createdByName}',
            if (recorded && a.accountName.isNotEmpty) '→ ${a.accountName}',
            if (recorded && a.advancePaymentRef.isNotEmpty) 'ref ${a.advancePaymentRef}',
          ].join(' · '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, color: crm.textSecondary),
        ),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(_inr.format(a.advanceAmount), style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(width: 4),
          if (!recorded)
            IconButton(
              tooltip: 'Record (choose account)',
              icon: Icon(Icons.check_circle_outline, color: crm.success),
              onPressed: () => _verify(a),
            ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'change') _verify(a, change: true);
              if (v == 'reject') _setStatus(a, 'rejected', done: 'Marked not received');
              if (v == 'undo') _setStatus(a, 'pending', done: 'Moved to “To verify”');
            },
            itemBuilder: (_) => [
              if (recorded) const PopupMenuItem(value: 'change', child: Text('Change account')),
              if (recorded) const PopupMenuItem(value: 'undo', child: Text('Undo (back to To verify)')),
              if (a.advanceStatus != 'rejected') const PopupMenuItem(value: 'reject', child: Text('Not received')),
            ],
          ),
        ]),
      ),
    );
  }
}
