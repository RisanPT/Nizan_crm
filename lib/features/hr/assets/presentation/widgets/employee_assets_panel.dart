import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/features/hr/assets/data/employee_asset_models.dart';
import 'package:nizan_crm/features/hr/assets/service/employee_asset_service.dart';
import 'package:nizan_crm/features/hr/assets/presentation/widgets/employee_asset_dialogs.dart';

/// One asset line with its actions. Used by [EmployeeAssetsPanel] and the
/// HR Assets screen.
class EmployeeAssetTile extends ConsumerWidget {
  const EmployeeAssetTile({super.key, required this.asset, this.showEmployee = false, this.readOnly = false});
  final EmployeeAsset asset;
  final bool showEmployee;
  final bool readOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final a = asset;
    final color = employeeAssetStatusColor(a.status);
    final details = <String>[
      employeeAssetCategoryLabel(a.category),
      if (a.serialNo.isNotEmpty) 'S/N ${a.serialNo}',
      'Issued ${fmtAssetDate(a.issuedOn)}',
      if (a.status == 'returned') 'Returned ${fmtAssetDate(a.returnedOn)}',
      if (a.returnCondition.isNotEmpty) 'Return: ${a.returnCondition}',
    ];
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
      child: Text(employeeAssetStatusLabel(a.status),
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
    final returnBtn = (!readOnly && a.isIssued)
        ? TextButton(
            onPressed: () => showReturnEmployeeAssetDialog(context, ref, a),
            child: const Text('Mark returned', style: TextStyle(fontSize: 12)),
          )
        : null;
    // On narrow widths the status chip and "Mark returned" drop under the text.
    return LayoutBuilder(builder: (context, constraints) {
    final narrow = constraints.maxWidth < 480;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(_iconFor(a.category), size: 18, color: crm.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  showEmployee ? '${a.item} — ${a.employeeName}' : a.item,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: crm.textPrimary),
                ),
                Text(details.join('  ·  '), style: TextStyle(fontSize: 11, color: crm.textSecondary)),
                if (a.notes.isNotEmpty)
                  Text(a.notes, style: TextStyle(fontSize: 11, color: crm.textSecondary, fontStyle: FontStyle.italic)),
                if (narrow)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Wrap(
                      spacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [chip, ?returnBtn],
                    ),
                  ),
              ],
            ),
          ),
          if (!narrow) chip,
          if (!narrow && returnBtn != null) ...[
            const SizedBox(width: 6),
            returnBtn,
          ],
          if (!readOnly)
            PopupMenuButton<String>(
              tooltip: 'More',
              icon: Icon(Icons.more_vert, size: 18, color: crm.textSecondary),
              onSelected: (v) {
                switch (v) {
                  case 'edit':
                    showIssueEmployeeAssetDialog(context, ref, existing: a);
                  case 'lost':
                    showLostEmployeeAssetDialog(context, ref, a);
                  case 'delete':
                    confirmDeleteEmployeeAsset(context, ref, a);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                if (a.isIssued) const PopupMenuItem(value: 'lost', child: Text('Mark lost')),
                const PopupMenuItem(value: 'delete', child: Text('Delete (HR only)')),
              ],
            ),
        ],
      ),
    );
    });
  }

  static IconData _iconFor(String c) {
    switch (c) {
      case 'laptop':
        return Icons.laptop_mac_rounded;
      case 'phone':
        return Icons.smartphone_rounded;
      case 'kit':
        return Icons.brush_rounded;
      case 'uniform':
        return Icons.checkroom_rounded;
      case 'id_card':
        return Icons.badge_outlined;
      case 'sim':
        return Icons.sim_card_outlined;
      default:
        return Icons.inventory_2_outlined;
    }
  }
}

/// Embeddable list of one employee's assets with "Issue" and "Mark returned".
/// Drop it into any screen: `EmployeeAssetsPanel(employeeId: id)`.
class EmployeeAssetsPanel extends ConsumerWidget {
  const EmployeeAssetsPanel({
    super.key,
    required this.employeeId,
    this.title = 'ASSETS ISSUED',
    this.allowIssue = true,
    this.readOnly = false,
  });
  final String employeeId;
  final String title;
  final bool allowIssue;
  final bool readOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    if (employeeId.isEmpty) return const SizedBox.shrink();
    final async = ref.watch(employeeAssetsForProvider(employeeId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: kAssetMaroon),
              ),
            ),
            if (allowIssue && !readOnly)
              TextButton.icon(
                onPressed: () => showIssueEmployeeAssetDialog(context, ref, employeeId: employeeId),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Issue', style: TextStyle(fontSize: 12)),
              ),
          ],
        ),
        async.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(8),
            child: LinearProgressIndicator(minHeight: 2),
          ),
          error: (e, _) => Text(friendlyErrorMessage(e), style: const TextStyle(fontSize: 12, color: Colors.red)),
          data: (rows) {
            if (rows.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text('No assets recorded for this employee.',
                    style: TextStyle(fontSize: 12, color: crm.textSecondary)),
              );
            }
            final issued = rows.where((a) => a.isIssued).length;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (issued > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('$issued item(s) still with the employee',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFFD97706))),
                  ),
                ...rows.map((a) => EmployeeAssetTile(asset: a, readOnly: readOnly)),
              ],
            );
          },
        ),
      ],
    );
  }
}
