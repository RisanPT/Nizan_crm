import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/extensions/space_extension.dart';
import '../../core/theme/crm_theme.dart';
import '../../core/utils/responsive_builder.dart';
import '../../services/customer_service.dart';

class ClientsDirectoryScreen extends ConsumerWidget {
  const ClientsDirectoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final crmColors = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Clients Directory',
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Clients are created automatically when you add a booking.',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: crmColors.textSecondary),
                    ),
                  ],
                ),
              ),
              if (!isMobile) ...[
                16.w,
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text('Export'),
                ),
              ]
            ],
          ),
          if (isMobile) ...[
            16.h,
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.download, size: 18),
              label: const Text('Export'),
            ),
          ],
          24.h,

          // ── Table card ───────────────────────────────────────────────────
          Card(
            color: Colors.white,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: 24.p,
              child: Column(
                children: [
                  // Search + filter row
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          decoration: InputDecoration(
                            hintText:
                                'Search clients by name, phone, or email...',
                            prefixIcon: const Icon(Icons.search),
                            filled: true,
                            fillColor: crmColors.background,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      if (!isMobile) ...[
                        const Spacer(),
                        OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.filter_list, size: 18),
                          label: const Text('Filter'),
                        ),
                        16.w,
                        OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.sort, size: 18),
                          label: const Text('Sort: Newest'),
                        ),
                      ]
                    ],
                  ),
                  if (isMobile) ...[
                    16.h,
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.filter_list, size: 18),
                            label: const Text('Filter'),
                          ),
                        ),
                        16.w,
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.sort, size: 18),
                            label: const Text('Sort: Newest'),
                          ),
                        ),
                      ],
                    ),
                  ],
                  24.h,

                  // Table header (desktop)
                  if (!isMobile)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Row(
                        children: [
                          Expanded(
                              flex: 2,
                              child: Text('CLIENT',
                                  style: TextStyle(
                                      color: crmColors.textSecondary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12))),
                          Expanded(
                              flex: 2,
                              child: Text('CONTACT INFO',
                                  style: TextStyle(
                                      color: crmColors.textSecondary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12))),
                          Expanded(
                              flex: 1,
                              child: Text('STATUS',
                                  style: TextStyle(
                                      color: crmColors.textSecondary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12))),
                          SizedBox(
                              width: 80,
                              child: Text('ACTIONS',
                                  style: TextStyle(
                                      color: crmColors.textSecondary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12))),
                        ],
                      ),
                    ),
                  const Divider(),

                  // Data from provider
                  ref.watch(customersProvider).when(
                        data: (customers) {
                          if (customers.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Column(
                                children: [
                                  Icon(Icons.person_search,
                                      size: 48, color: crmColors.border),
                                  16.h,
                                  Text(
                                    'No clients yet.\nCreate a booking to auto-register a client.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: crmColors.textSecondary),
                                  ),
                                  16.h,
                                  ElevatedButton.icon(
                                    onPressed: () =>
                                        context.go('/booking/add'),
                                    icon: const Icon(Icons.add),
                                    label:
                                        const Text('Create First Booking'),
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: crmColors.primary,
                                        foregroundColor: Colors.white),
                                  ),
                                ],
                              ),
                            );
                          }
                          return Column(
                            children: customers
                                .map((c) => Column(
                                      children: [
                                        _buildClientRow(
                                          context,
                                          ref,
                                          id: c.id ?? '',
                                          name: c.name,
                                          tag: c.status,
                                          phone: c.phone ?? 'N/A',
                                          email: c.email
                                                  .contains('@placeholder')
                                              ? '—'
                                              : c.email,
                                        ),
                                        const Divider(),
                                      ],
                                    ))
                                .toList(),
                          );
                        },
                        loading: () => const Padding(
                          padding: EdgeInsets.all(32.0),
                          child: CircularProgressIndicator(),
                        ),
                        error: (error, stack) => Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Text('Error: $error',
                              style:
                                  TextStyle(color: crmColors.warning)),
                        ),
                      ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildClientRow(
    BuildContext context,
    WidgetRef ref, {
    required String id,
    required String name,
    required String tag,
    required String phone,
    required String email,
  }) {
    final crmColors = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);

    Future<void> deleteClient() async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete Client'),
          content:
              Text('Remove $name from the directory? This cannot be undone.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Delete',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        try {
          await ref.read(customerServiceProvider).deleteCustomer(id);
          ref.invalidate(customersProvider);
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to delete: $e')),
            );
          }
        }
      }
    }

    Color tagColor;
    switch (tag) {
      case 'Active':
        tagColor = crmColors.success;
        break;
      case 'Inactive':
        tagColor = crmColors.warning;
        break;
      default:
        tagColor = crmColors.textSecondary;
    }

    if (isMobile) {
      return Padding(
        padding: 16.py,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: crmColors.primary.withOpacity(0.12),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: crmColors.primary),
                  ),
                ),
                12.w,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(tag,
                          style: TextStyle(
                              color: tagColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz),
                  onSelected: (val) {
                    if (val == 'view') context.go('/client/$id');
                    if (val == 'delete') deleteClient();
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                        value: 'view', child: Text('View Profile')),
                    const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete',
                            style: TextStyle(color: Colors.red))),
                  ],
                ),
              ],
            ),
            12.h,
            Row(children: [
              Icon(Icons.phone, size: 14, color: crmColors.textSecondary),
              8.w,
              Text(phone,
                  style: TextStyle(color: crmColors.textSecondary)),
            ]),
            4.h,
            Row(children: [
              Icon(Icons.email, size: 14, color: crmColors.textSecondary),
              8.w,
              Expanded(
                  child: Text(email,
                      style:
                          TextStyle(color: crmColors.textSecondary))),
            ]),
            12.h,
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => context.go('/client/$id'),
                child: const Text('View Profile'),
              ),
            )
          ],
        ),
      );
    }

    return InkWell(
      onTap: () => context.go('/client/$id'),
      child: Padding(
        padding: 16.py,
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: crmColors.primary.withOpacity(0.12),
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: crmColors.primary),
                    ),
                  ),
                  12.w,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: tagColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(tag,
                              style: TextStyle(
                                  color: tagColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.phone,
                        size: 14, color: crmColors.textSecondary),
                    8.w,
                    Text(phone,
                        style:
                            TextStyle(color: crmColors.textSecondary)),
                  ]),
                  4.h,
                  Row(children: [
                    Icon(Icons.email,
                        size: 14, color: crmColors.textSecondary),
                    8.w,
                    Expanded(
                        child: Text(email,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: crmColors.textSecondary))),
                  ]),
                ],
              ),
            ),
            Expanded(
              flex: 1,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: tagColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(tag,
                    style: TextStyle(
                        color: tagColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ),
            ),
            SizedBox(
              width: 80,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: Icon(Icons.person_outline,
                        color: crmColors.primary, size: 20),
                    tooltip: 'View Profile',
                    onPressed: () => context.go('/client/$id'),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_horiz,
                        color: crmColors.textSecondary, size: 20),
                    onSelected: (val) {
                      if (val == 'delete') deleteClient();
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete',
                              style: TextStyle(color: Colors.red))),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
