import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/marketing/data/market_models.dart';
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/services/market_service.dart';

/// Marketing → Countries & Cities. The list a lead is placed in (Country → City), so leads, and soon campaigns, teams and budgets, can
/// be read by market. Everybody in Marketing reads it; the Marketing Manager / Admin change it (the server says who — `canManage`).
/// A country or city that leads are placed in is switched off, not removed; a rename reaches the leads that carry it.
class MarketsScreen extends ConsumerWidget {
  const MarketsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(marketsAllProvider);
    final canManage = async.asData?.value.canManage ?? false;

    return MktPage(
      child: Material(
        type: MaterialType.transparency,
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(marketsAllProvider),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              MktHeader(
                icon: Icons.public_outlined,
                title: 'Countries & Cities',
                subtitle: 'Where brides are — every lead is placed in one of these',
                actions: [
                  if (canManage) MktPrimaryButton(key: const Key('mk_add_country'), label: 'Add country', onPressed: () => _editCountry(context, ref)),
                ],
              ),
              const SizedBox(height: 14),
              async.when(
                loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 48), child: Center(child: CircularProgressIndicator())),
                error: (e, _) => AppErrorView(error: e, onRetry: () => ref.invalidate(marketsAllProvider)),
                data: (list) => _Body(list: list),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.list});
  final MarketList list;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countries = list.countries;
    if (countries.isEmpty) {
      return MktEmpty(list.canManage ? 'No countries yet. Use Add country.' : 'No countries yet. A Marketing Manager adds them.', icon: Icons.public_off_outlined, height: 130);
    }
    final cities = countries.fold<int>(0, (n, c) => n + c.cities.where((k) => k.isActive).length);
    final placed = countries.fold<int>(0, (n, c) => n + (c.leads ?? 0));
    final nCountries = countries.where((c) => c.isActive).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            '$nCountries ${nCountries == 1 ? 'country' : 'countries'} · $cities ${cities == 1 ? 'city' : 'cities'}'
            '${list.canManage ? ' · $placed ${placed == 1 ? 'lead' : 'leads'} placed' : ''}',
            key: const Key('mk_summary'),
            style: mktText(12.5, color: Mkt.inkSoft),
          ),
        ),
        for (final c in countries) ...[
          _CountryCard(country: c, canManage: list.canManage),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _CountryCard extends ConsumerWidget {
  const _CountryCard({required this.country, required this.canManage});
  final MarketCountry country;
  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = country;
    return MktCard(
      key: Key('mk_country_${c.id}'),
      title: c.name,
      subtitle: [c.detail, if (c.leads != null) '${c.leads} ${c.leads == 1 ? 'lead' : 'leads'}'].where((s) => s.isNotEmpty).join('  ·  '),
      icon: Icons.flag_outlined,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!c.isActive) const MktChip('Switched off', color: Mkt.grey),
          if (canManage)
            PopupMenuButton<String>(
              key: Key('mk_country_menu_${c.id}'),
              tooltip: 'Country options',
              icon: const Icon(Icons.more_vert_rounded, size: 20, color: Mkt.inkSoft),
              onSelected: (v) => _countryAction(context, ref, c, v),
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit country')),
                PopupMenuItem(value: 'toggle', child: Text(c.isActive ? 'Switch off' : 'Switch on')),
                const PopupMenuItem(value: 'delete', child: Text('Remove')),
              ],
            ),
        ],
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (c.cities.isEmpty) Text('No cities yet.', style: mktText(12.5, color: Mkt.inkSoft)),
          for (final k in c.cities) _CityChip(city: k, canManage: canManage),
          if (canManage)
            ActionChip(
              key: Key('mk_add_city_${c.id}'),
              avatar: const Icon(Icons.add_rounded, size: 16, color: Mkt.primary),
              label: Text('Add city', style: mktText(12, weight: FontWeight.w700, color: Mkt.primary)),
              backgroundColor: Mkt.primarySoft,
              side: BorderSide.none,
              onPressed: () => _editCity(context, ref, countryId: c.id),
            ),
        ],
      ),
    );
  }
}

class _CityChip extends ConsumerWidget {
  const _CityChip({required this.city, required this.canManage});
  final MarketCity city;
  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final k = city;
    final leads = k.leads ?? 0;
    final body = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: k.isActive ? Mkt.card : Mkt.bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Mkt.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(k.name, style: mktText(12.5, weight: FontWeight.w700, color: k.isActive ? Mkt.ink : Mkt.inkSoft)),
          if (k.state.isNotEmpty) Text('  ${k.state}', style: mktText(11.5, color: Mkt.inkSoft)),
          if (leads > 0) Text('  $leads', style: mktText(11.5, weight: FontWeight.w700, color: Mkt.primary)),
          if (!k.isActive) Text('  off', style: mktText(11, color: Mkt.inkSoft)),
        ],
      ),
    );
    if (!canManage) return KeyedSubtree(key: Key('mk_city_${k.id}'), child: body);
    return PopupMenuButton<String>(
      key: Key('mk_city_${k.id}'),
      tooltip: 'City options',
      onSelected: (v) => _cityAction(context, ref, k, v),
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'edit', child: Text('Edit city')),
        PopupMenuItem(value: 'toggle', child: Text(k.isActive ? 'Switch off' : 'Switch on')),
        const PopupMenuItem(value: 'delete', child: Text('Remove')),
      ],
      child: body,
    );
  }
}

// ── actions ──────────────────────────────────────────────────

Future<void> _run(BuildContext context, Future<void> Function() job, {String? done}) async {
  try {
    await job();
    if (done != null && context.mounted) showSuccessSnackBar(context, done);
  } catch (e) {
    if (context.mounted) showErrorSnackBar(context, e);
  }
}

Future<void> _countryAction(BuildContext context, WidgetRef ref, MarketCountry c, String action) async {
  final svc = ref.read(marketServiceProvider);
  switch (action) {
    case 'edit':
      return _editCountry(context, ref, country: c);
    case 'toggle':
      return _run(
        context,
        () => svc.updateCountry(c.id, name: c.name, code: c.code, dialCode: c.dialCode, currency: c.currency, status: c.isActive ? 'inactive' : 'active'),
        done: c.isActive ? '${c.name} is switched off.' : '${c.name} is on again.',
      );
    case 'delete':
      if (await _confirm(context, 'Remove ${c.name}?', 'It can only be removed when it has no cities and no lead is placed in it.')) {
        if (context.mounted) await _run(context, () => svc.deleteCountry(c.id), done: '${c.name} was removed.');
      }
  }
}

Future<void> _cityAction(BuildContext context, WidgetRef ref, MarketCity k, String action) async {
  final svc = ref.read(marketServiceProvider);
  switch (action) {
    case 'edit':
      return _editCity(context, ref, city: k);
    case 'toggle':
      return _run(context, () => svc.updateCity(k.id, name: k.name, state: k.state, status: k.isActive ? 'inactive' : 'active'),
          done: k.isActive ? '${k.name} is switched off.' : '${k.name} is on again.');
    case 'delete':
      if (await _confirm(context, 'Remove ${k.name}?', 'It can only be removed when no lead is placed in it. Otherwise, switch it off.')) {
        if (context.mounted) await _run(context, () => svc.deleteCity(k.id), done: '${k.name} was removed.');
      }
  }
}

Future<bool> _confirm(BuildContext context, String title, String body) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(
          key: const Key('mk_confirm'),
          style: FilledButton.styleFrom(backgroundColor: Mkt.maroon),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Remove'),
        ),
      ],
    ),
  );
  return ok == true;
}

Future<void> _editCountry(BuildContext context, WidgetRef ref, {MarketCountry? country}) {
  final svc = ref.read(marketServiceProvider);
  return showDialog<void>(
    context: context,
    builder: (_) => _FormDialog(
      title: country == null ? 'Add country' : 'Edit ${country.name}',
      fields: [
        _Field('name', 'Country *', initial: country?.name ?? '', caps: TextCapitalization.words, maxLength: 60),
        _Field('code', 'Code (IN, AE)', initial: country?.code ?? '', caps: TextCapitalization.characters, maxLength: 3),
        _Field('dialCode', 'Dialling code (+971)', initial: country?.dialCode ?? '', keyboard: TextInputType.phone, maxLength: 5),
        _Field('currency', 'Currency (INR, AED)', initial: country?.currency ?? '', caps: TextCapitalization.characters, maxLength: 3),
      ],
      onSave: (v) => country == null
          ? svc.addCountry(name: v['name']!, code: v['code']!, dialCode: v['dialCode']!, currency: v['currency']!)
          : svc.updateCountry(country.id, name: v['name']!, code: v['code']!, dialCode: v['dialCode']!, currency: v['currency']!),
    ),
  );
}

Future<void> _editCity(BuildContext context, WidgetRef ref, {String? countryId, MarketCity? city}) {
  final svc = ref.read(marketServiceProvider);
  return showDialog<void>(
    context: context,
    builder: (_) => _FormDialog(
      title: city == null ? 'Add city' : 'Edit ${city.name}',
      fields: [
        _Field('name', 'City *', initial: city?.name ?? '', caps: TextCapitalization.words, maxLength: 60),
        _Field('state', 'State or province (optional)', initial: city?.state ?? '', caps: TextCapitalization.words, maxLength: 60),
      ],
      onSave: (v) => city == null ? svc.addCity(countryId!, name: v['name']!, state: v['state']!) : svc.updateCity(city.id, name: v['name']!, state: v['state']!),
    ),
  );
}

class _Field {
  const _Field(this.key, this.label, {this.initial = '', this.caps = TextCapitalization.none, this.keyboard, this.maxLength});
  final String key, label, initial;
  final TextCapitalization caps;
  final TextInputType? keyboard;
  final int? maxLength;
}

/// A small form in a dialog. The first field is required. A failed save stays open and says why, in plain words.
class _FormDialog extends StatefulWidget {
  const _FormDialog({required this.title, required this.fields, required this.onSave});
  final String title;
  final List<_Field> fields;
  final Future<void> Function(Map<String, String> values) onSave;

  @override
  State<_FormDialog> createState() => _FormDialogState();
}

class _FormDialogState extends State<_FormDialog> {
  late final Map<String, TextEditingController> _c = {for (final f in widget.fields) f.key: TextEditingController(text: f.initial)};
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final first = widget.fields.first;
    if (_c[first.key]!.text.trim().length < 2) {
      setState(() => _error = 'Give it a name (2 letters or more).');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave({for (final f in widget.fields) f.key: _c[f.key]!.text.trim()});
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = friendlyErrorMessage(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SizedBox(
      width: 380,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final f in widget.fields)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextField(
                  key: Key('mk_f_${f.key}'),
                  controller: _c[f.key],
                  autofocus: f == widget.fields.first,
                  textCapitalization: f.caps,
                  keyboardType: f.keyboard,
                  inputFormatters: [if (f.maxLength != null) LengthLimitingTextInputFormatter(f.maxLength)],
                  decoration: InputDecoration(labelText: f.label),
                  onSubmitted: (_) => _saving ? null : _save(),
                ),
              ),
            if (_error != null) Align(alignment: Alignment.centerLeft, child: Text(_error!, key: const Key('mk_error'), style: mktText(12.5, color: Mkt.bad))),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(
        key: const Key('mk_save'),
        style: FilledButton.styleFrom(backgroundColor: Mkt.maroon),
        onPressed: _saving ? null : _save,
        child: Text(_saving ? 'Saving…' : 'Save'),
      ),
    ],
  );
}
