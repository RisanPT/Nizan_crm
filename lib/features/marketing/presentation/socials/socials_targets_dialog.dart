import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/marketing/data/socials_models.dart';
import 'package:nizan_crm/features/marketing/data/team_models.dart';
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/presentation/team/team_widgets.dart' show shortDay;
import 'package:nizan_crm/features/marketing/services/socials_service.dart';
import 'package:nizan_crm/features/marketing/services/team_service.dart';

/// The weekly targets the activity tracker compares against. A target is stored FOR its week and never rewrites another week's; a week
/// with none inherits the latest earlier one. Only a Marketing Manager can set them (the server says so if anyone else tries).
Future<void> showSocialsTargets(BuildContext context, WidgetRef ref) => showDialog<void>(context: context, builder: (_) => const Dialog(child: _TargetsForm()));

class _TargetsForm extends ConsumerStatefulWidget {
  const _TargetsForm();

  @override
  ConsumerState<_TargetsForm> createState() => _TargetsFormState();
}

class _TargetsFormState extends ConsumerState<_TargetsForm> {
  final Map<String, TextEditingController> _c = {};
  late TeamBrand _brand = ref.read(teamFilterProvider).brand;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _n(double? v) => v == null ? '' : (v == v.roundToDouble() ? '${v.toInt()}' : '$v');

  Future<void> _save(TargetsData d) async {
    final values = <String, double>{};
    for (final m in d.metrics) {
      final t = _c[m.id]?.text.trim() ?? '';
      if (t.isEmpty) continue;
      final v = double.tryParse(t);
      if (v == null || v < 0) {
        setState(() => _error = 'A target must be a number, zero or more.');
        return;
      }
      values[m.id] = v;
    }
    if (values.isEmpty) {
      setState(() => _error = 'Type at least one target.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(marketingSocialsServiceProvider).saveTargets(brand: _brand.wire, week: d.week, values: values);
      refreshSocials(ref);
      if (mounted) Navigator.pop(context);
    } on TeamRefusal catch (r) {
      if (mounted) setState(() { _error = r.message; _saving = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showErrorSnackBar(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // the targets are for the week the page is showing and the brand chosen here
    final async = ref.watch(socialsTargetsProvider);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: async.when(
          loading: () => const SizedBox(height: 120, child: Center(child: CircularProgressIndicator())),
          error: (e, _) => AppErrorView(error: e, onRetry: () => ref.invalidate(socialsTargetsProvider)),
          data: (d) {
            for (final m in d.metrics) {
              _c.putIfAbsent(m.id, () => TextEditingController(text: _n(m.target)));
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Weekly targets', style: mktText(19, weight: FontWeight.w800)),
                Text('Week of ${shortDay(d.week)} · the tracker compares what was logged with these. A week with none uses the latest earlier target.', style: mktText(12, color: Mkt.inkSoft)),
                const SizedBox(height: 12),
                Wrap(spacing: 8, children: [
                  for (final b in TeamBrand.values)
                    MktFilterChip(key: Key('soc_target_brand_${b.wire}'), label: b == TeamBrand.all ? 'All brands' : b.label, selected: _brand == b, onTap: () => setState(() => _brand = b)),
                ]),
                const SizedBox(height: 12),
                if (d.metrics.isEmpty)
                  const MktEmpty('No activities are set up under Socials yet (Team → EOD → Setup).', icon: Icons.grid_view_rounded)
                else
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(children: [
                        for (final m in d.metrics)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(children: [
                              Expanded(child: Text(m.name, style: mktText(13))),
                              SizedBox(
                                width: 92,
                                child: TextField(key: Key('soc_target_${m.id}'), controller: _c[m.id], keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), hintText: 'Target')),
                              ),
                            ]),
                          ),
                      ]),
                    ),
                  ),
                if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, key: const Key('soc_targets_error'), style: mktText(12.5, weight: FontWeight.w600, color: Mkt.bad))),
                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  OutlinedButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
                  const SizedBox(width: 10),
                  FilledButton(key: const Key('soc_targets_save'), style: FilledButton.styleFrom(backgroundColor: Mkt.maroon), onPressed: _saving || d.metrics.isEmpty ? null : () => _save(d), child: const Text('Save targets')),
                ]),
              ],
            );
          },
        ),
      ),
    );
  }
}
