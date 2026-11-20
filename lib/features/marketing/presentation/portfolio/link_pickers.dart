import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/marketing/data/portfolio_models.dart';
import 'package:nizan_crm/features/marketing/data/socials_models.dart';
import 'package:nizan_crm/features/marketing/presentation/kit/mkt_kit.dart';
import 'package:nizan_crm/features/marketing/presentation/portfolio/portfolio_widgets.dart';
import 'package:nizan_crm/features/marketing/services/portfolio_service.dart';
import 'package:nizan_crm/features/marketing/services/socials_service.dart';

// The pickers that link one record to another: a shoot (for an asset or a post), a work (a CRM booking, for a shoot) and an approved
// asset (for a post). Each opens a searchable list; the answer is the picked record, `(value: null)` to clear, or null when closed.

/// A form row that shows what is linked and opens its picker: "Shoot — Bridal Transformation · 10 Nov" with a clear button.
class LinkField extends StatelessWidget {
  const LinkField({super.key, required this.label, required this.value, required this.onTap, this.onClear, this.icon = Icons.link_rounded, this.hint = 'None', this.locked = false, this.note});
  final String label;
  final String? value;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  final IconData icon;
  final String hint;

  /// Shown but not changeable here ([note] says why).
  final bool locked;
  final String? note;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: locked ? null : onTap,
          child: InputDecorator(
            decoration: InputDecoration(labelText: label, isDense: true, border: const OutlineInputBorder(), prefixIcon: Icon(icon, size: 18), enabled: !locked),
            child: Row(children: [
              Expanded(child: Text(value ?? hint, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(13, weight: value == null ? FontWeight.w400 : FontWeight.w700, color: value == null ? Mkt.inkSoft : Mkt.ink))),
              if (value != null && onClear != null && !locked)
                InkWell(onTap: onClear, child: const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.close_rounded, size: 18, color: Mkt.inkSoft)))
              else if (!locked)
                const Icon(Icons.search_rounded, size: 18, color: Mkt.inkSoft),
            ]),
          ),
        ),
        if (note != null) Padding(padding: const EdgeInsets.only(top: 4, left: 2), child: Text(note!, style: mktText(11, color: Mkt.inkSoft))),
      ]);
}

Future<T?> _show<T>(BuildContext context, Widget body) {
  if (MediaQuery.sizeOf(context).width >= 700) {
    return showDialog<T>(context: context, builder: (_) => Dialog(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520, maxHeight: 620), child: body)));
  }
  return showModalBottomSheet<T>(context: context, isScrollControlled: true, useSafeArea: true, showDragHandle: true, builder: (_) => SizedBox(height: MediaQuery.sizeOf(context).height * 0.8, child: body));
}

/// Pick a shoot (not cancelled, newest first). → the shoot, `(value: null)` = no shoot, null = closed.
Future<({ShootOption? value})?> pickShoot(BuildContext context, {String? selectedId}) => _show(context, _ShootList(selectedId: selectedId));

/// Pick a work (a CRM booking) for a shoot; the list opens on the works within 30 days of [around]. → as [pickShoot].
Future<({BookingBrief? value})?> pickBooking(BuildContext context, {String? selectedId, String? around}) => _show(context, _BookingList(selectedId: selectedId, around: around));

/// Pick an asset a post can be made from — approved or final only. → as [pickShoot].
Future<({Asset? value})?> pickApprovedAsset(BuildContext context, {String? selectedId, String brand = 'all'}) => _show(context, _AssetList(selectedId: selectedId, brand: brand));

class _PickerFrame extends StatelessWidget {
  const _PickerFrame({required this.title, required this.searchKey, required this.hint, required this.onSearch, required this.body, required this.noneLabel, required this.onNone});
  final String title, hint, noneLabel;
  final Key searchKey;
  final ValueChanged<String> onSearch;
  final Widget body;
  final VoidCallback onNone;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: mktText(17, weight: FontWeight.w800)),
          const SizedBox(height: 10),
          TextField(
            key: searchKey,
            autofocus: true,
            onChanged: onSearch,
            style: mktText(13),
            decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded, size: 18), hintText: hint, isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 10), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: Mkt.border)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: Mkt.primary))),
          ),
          const SizedBox(height: 8),
          Expanded(child: body),
          const Divider(height: 16),
          Row(children: [
            TextButton(key: const Key('picker_none'), onPressed: onNone, child: Text(noneLabel)),
            const Spacer(),
            TextButton(key: const Key('picker_close'), onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ]),
        ]),
      );
}

Widget _row({required Key key, required bool selected, required Widget leading, required String title, required String subtitle, required VoidCallback onTap}) => ListTile(
      key: key,
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 6),
      selected: selected,
      selectedTileColor: Mkt.primarySoft,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      leading: leading,
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(13, weight: FontWeight.w700)),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: mktText(11, color: Mkt.inkSoft)),
      trailing: selected ? const Icon(Icons.check_rounded, color: Mkt.primary, size: 18) : null,
      onTap: onTap,
    );

class _ShootList extends ConsumerStatefulWidget {
  const _ShootList({this.selectedId});
  final String? selectedId;
  @override
  ConsumerState<_ShootList> createState() => _ShootListState();
}

class _ShootListState extends ConsumerState<_ShootList> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(shootOptionsProvider(_q.trim()));
    return _PickerFrame(
      title: 'Pick the shoot',
      searchKey: const Key('pick_shoot_search'),
      hint: 'Search shoots…',
      onSearch: (v) => setState(() => _q = v),
      noneLabel: 'No shoot',
      onNone: () => Navigator.pop(context, (value: null)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AppErrorView(error: e, onRetry: () => ref.invalidate(shootOptionsProvider)),
        data: (list) => list.isEmpty
            ? const MktEmpty('No shoot matches.', icon: Icons.videocam_outlined)
            : ListView(children: [
                for (final s in list)
                  _row(
                    key: Key('pick_shoot_${s.id}'),
                    selected: s.id == widget.selectedId,
                    leading: Icon(Icons.videocam_outlined, color: shootStatusColor(s.status)),
                    title: s.title,
                    subtitle: [shootDay(s.shootDate), if (s.category.isNotEmpty) s.category, s.brand == 'kerala' ? 'Kerala' : 'Main'].join(' · '),
                    onTap: () => Navigator.pop(context, (value: s)),
                  ),
              ]),
      ),
    );
  }
}

class _BookingList extends ConsumerStatefulWidget {
  const _BookingList({this.selectedId, this.around});
  final String? selectedId, around;
  @override
  ConsumerState<_BookingList> createState() => _BookingListState();
}

class _BookingListState extends ConsumerState<_BookingList> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(bookingOptionsProvider((q: _q.trim(), around: widget.around)));
    return _PickerFrame(
      title: 'Link a work (booking)',
      searchKey: const Key('pick_booking_search'),
      hint: 'Booking number, client or service…',
      onSearch: (v) => setState(() => _q = v),
      noneLabel: 'No booking',
      onNone: () => Navigator.pop(context, (value: null)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AppErrorView(error: e, onRetry: () => ref.invalidate(bookingOptionsProvider)),
        data: (list) => list.isEmpty
            ? MktEmpty(_q.trim().isEmpty ? 'No work within 30 days. Search by booking number or client.' : 'No booking matches.', icon: Icons.event_note_outlined)
            : ListView(children: [
                for (final b in list)
                  _row(
                    key: Key('pick_booking_${b.id}'),
                    selected: b.id == widget.selectedId,
                    leading: const Icon(Icons.event_note_outlined, color: Mkt.primary),
                    title: b.label.isEmpty ? 'Booking' : b.label,
                    subtitle: [if (b.service.isNotEmpty) b.service, if (b.eventDate != null) shootDay(b.eventDate!), if (b.district.isNotEmpty) b.district].join(' · '),
                    onTap: () => Navigator.pop(context, (value: b)),
                  ),
              ]),
      ),
    );
  }
}

class _AssetList extends ConsumerStatefulWidget {
  const _AssetList({this.selectedId, required this.brand});
  final String? selectedId;
  final String brand;
  @override
  ConsumerState<_AssetList> createState() => _AssetListState();
}

class _AssetListState extends ConsumerState<_AssetList> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(socialsAssetsProvider(AssetQuery(q: _q, usable: true, brand: widget.brand)));
    return _PickerFrame(
      title: 'Pick an approved asset',
      searchKey: const Key('pick_asset_search'),
      hint: 'Search approved assets…',
      onSearch: (v) => setState(() => _q = v),
      noneLabel: 'No asset',
      onNone: () => Navigator.pop(context, (value: null)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AppErrorView(error: e, onRetry: () => ref.invalidate(socialsAssetsProvider)),
        data: (l) => l.items.isEmpty
            ? const MktEmpty('No approved asset matches. Only approved or final assets can be posted — approve one in Content & Assets.', icon: Icons.verified_outlined, height: 140)
            : ListView(children: [
                for (final a in l.items)
                  _row(
                    key: Key('pick_asset_${a.id}'),
                    selected: a.id == widget.selectedId,
                    leading: Icon(a.media == 'video' ? Icons.play_circle_outline_rounded : Icons.image_outlined, color: Mkt.primary),
                    title: a.title,
                    subtitle: [assetKindLabel(a.kind), if (a.page.isNotEmpty) a.page, a.brand == 'kerala' ? 'Kerala' : 'Main', a.isFinal ? 'Final' : assetStageLabel(a.stage)].join(' · '),
                    onTap: () => Navigator.pop(context, (value: a)),
                  ),
              ]),
      ),
    );
  }
}
