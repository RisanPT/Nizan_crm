import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/extensions/space_extension.dart';
import '../../core/theme/crm_theme.dart';
import '../../core/utils/responsive_builder.dart';

class ClientsDirectoryScreen extends StatelessWidget {
  const ClientsDirectoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final crmColors = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Clients Directory',
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Manage your customer relationships, booking history, and contact details.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                            color: crmColors.textSecondary,
                          ),
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
                16.w,
                ElevatedButton.icon(
                  onPressed: () => context.go('/clients/add'),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Client'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: crmColors.primary,
                    foregroundColor: Colors.white,
                  ),
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
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text('Export'),
                  ),
                ),
                16.w,
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => context.go('/clients/add'),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Client'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: crmColors.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
          24.h,
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: 24.p,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Search clients by name, phone, or email...',
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
                  // Client List header
                  if (!isMobile)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Row(
                        children: [
                          Expanded(flex: 2, child: Text('CLIENT', style: TextStyle(color: crmColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12))),
                          Expanded(flex: 2, child: Text('CONTACT INFO', style: TextStyle(color: crmColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12))),
                          Expanded(flex: 1, child: Text('TOTAL VISITS', style: TextStyle(color: crmColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12))),
                          Expanded(flex: 1, child: Text('LAST APPOINTMENT', style: TextStyle(color: crmColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12))),
                          SizedBox(width: 80, child: Text('ACTIONS', style: TextStyle(color: crmColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12))),
                        ],
                      ),
                    ),
                  const Divider(),
                  _buildClientRow(
                    context,
                    name: 'Emma Watson',
                    tag: 'VIP Member',
                    phone: '+1 (555) 123-4567',
                    email: 'emma.watson@example.com',
                    visits: '12',
                    lastApptDate: 'Oct 24, 2023',
                    lastApptService: 'Bridal Makeover',
                  ),
                  const Divider(),
                  _buildClientRow(
                    context,
                    name: 'Sarah Jenkins',
                    tag: 'Regular',
                    phone: '+1 (555) 987-6543',
                    email: 'sarah.j@example.com',
                    visits: '4',
                    lastApptDate: 'Nov 02, 2023',
                    lastApptService: 'Luxury Facial',
                  ),
                  const Divider(),
                  _buildClientRow(
                    context,
                    name: 'Chloe Kim',
                    tag: 'New',
                    phone: '+1 (555) 456-7890',
                    email: 'c.kim@example.com',
                    visits: '1',
                    lastApptDate: 'Today',
                    lastApptService: 'Hair Styling',
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
    BuildContext context, {
    required String name,
    required String tag,
    required String phone,
    required String email,
    required String visits,
    required String lastApptDate,
    required String lastApptService,
  }) {
    final crmColors = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);

    if (isMobile) {
      return Padding(
        padding: 16.py,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(child: Icon(Icons.person)),
                12.w,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(tag, style: TextStyle(color: crmColors.warning, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.more_horiz), onPressed: () {}),
              ],
            ),
            12.h,
            Row(
              children: [
                Icon(Icons.phone, size: 14, color: crmColors.textSecondary),
                8.w,
                Text(phone, style: TextStyle(color: crmColors.textSecondary)),
              ],
            ),
            4.h,
            Row(
              children: [
                Icon(Icons.email, size: 14, color: crmColors.textSecondary),
                8.w,
                Text(email, style: TextStyle(color: crmColors.textSecondary)),
              ],
            ),
            12.h,
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(visits, style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('Lifetime', style: TextStyle(color: crmColors.textSecondary, fontSize: 12)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(lastApptDate, style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(lastApptService, style: TextStyle(color: crmColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ],
            ),
            12.h,
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => context.go('/client/$name'),
                child: const Text('View Profile'),
              ),
            )
          ],
        ),
      );
    }

    return InkWell(
      onTap: () => context.go('/client/$name'),
      child: Padding(
        padding: 16.py,
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  const CircleAvatar(child: Icon(Icons.person)),
                  12.w,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: tag == 'VIP Member' ? crmColors.warning.withOpacity(0.1) : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(tag, style: TextStyle(color: tag == 'VIP Member' ? crmColors.warning : crmColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.phone, size: 14, color: crmColors.textSecondary),
                      8.w,
                      Text(phone, style: TextStyle(color: crmColors.textSecondary)),
                    ],
                  ),
                  4.h,
                  Row(
                    children: [
                      Icon(Icons.email, size: 14, color: crmColors.textSecondary),
                      8.w,
                      Text(email, style: TextStyle(color: crmColors.textSecondary)),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(visits, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('Lifetime', style: TextStyle(color: crmColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            Expanded(
              flex: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(lastApptDate, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(lastApptService, style: TextStyle(color: crmColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            SizedBox(
              width: 80,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.message_outlined, color: crmColors.success, size: 20),
                  8.w,
                  Icon(Icons.event_outlined, color: crmColors.textSecondary, size: 20),
                  8.w,
                  Icon(Icons.more_horiz, color: crmColors.textSecondary, size: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
