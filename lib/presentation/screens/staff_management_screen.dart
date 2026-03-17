import 'package:flutter/material.dart';
import '../../core/extensions/space_extension.dart';
import '../../core/theme/crm_theme.dart';
import '../../core/utils/responsive_builder.dart';

class StaffManagementScreen extends StatelessWidget {
  const StaffManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final crmColors = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Staff Management',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Manage your salon employees, their roles, and schedules.',
                    style: TextStyle(color: crmColors.textSecondary),
                  ),
                ],
              ),
            ),
            if (!isMobile) ...[
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.filter_list, size: 18),
                label: const Text('Filter Roles'),
              ),
              16.w,
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Staff'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: crmColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
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
                  label: const Text('Filter Roles'),
                ),
              ),
              16.w,
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Staff'),
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
        Expanded(
          child: Card(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth:
                      MediaQuery.of(context).size.width - (isMobile ? 32 : 300),
                ),
                child: SingleChildScrollView(
                  child: DataTable(
                    columnSpacing: 32,
                    headingTextStyle: TextStyle(
                      color: crmColors.textSecondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    columns: const [
                      DataColumn(label: Text('STAFF MEMBER')),
                      DataColumn(label: Text('ROLE')),
                      DataColumn(label: Text('PHONE NUMBER')),
                      DataColumn(label: Text('ASSIGNED SERVICES')),
                      DataColumn(label: Text('SCHEDULE')),
                      DataColumn(label: Text('ACTIONS')),
                    ],
                    rows: [
                      _buildStaffRow(
                        context,
                        name: 'Sarah Jenkins',
                        email: 'sarah.j@nizan.com',
                        role: 'Senior Stylist',
                        phone: '+1 (555) 123-4567',
                        services: ['Haircut', 'Coloring', 'Extensions'],
                        schedule: 'Today: 9AM - 5PM',
                        isWorkingToday: true,
                      ),
                      _buildStaffRow(
                        context,
                        name: 'Amara Diallo',
                        email: 'amara.d@nizan.com',
                        role: 'Makeup Artist',
                        phone: '+1 (555) 987-6543',
                        services: ['Bridal', 'Evening Glam'],
                        schedule: 'Today: 10AM - 6PM',
                        isWorkingToday: true,
                      ),
                      _buildStaffRow(
                        context,
                        name: 'Michael Chang',
                        email: 'm.chang@nizan.com',
                        role: 'Massage Therapist',
                        phone: '+1 (555) 456-7890',
                        services: ['Deep Tissue', 'Swedish'],
                        schedule: 'Off Today',
                        isWorkingToday: false,
                      ),
                      _buildStaffRow(
                        context,
                        name: 'Elena Rodriguez',
                        email: 'elena.r@nizan.com',
                        role: 'Esthetician',
                        phone: '+1 (555) 321-6547',
                        services: ['Facials', 'Skincare'],
                        schedule: 'Today: 8AM - 4PM',
                        isWorkingToday: true,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  DataRow _buildStaffRow(
    BuildContext context, {
    required String name,
    required String email,
    required String role,
    required String phone,
    required List<String> services,
    required String schedule,
    required bool isWorkingToday,
  }) {
    final crmColors = context.crmColors;

    return DataRow(
      cells: [
        DataCell(
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: crmColors.primary.withValues(alpha: 0.1),
                child: Text(
                  name.isNotEmpty ? name[0] : '?',
                  style: TextStyle(
                    fontSize: 18,
                    color: crmColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              12.w,
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    email,
                    style: TextStyle(
                      color: crmColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: crmColors.surface,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: crmColors.border),
            ),
            child: Text(
              role,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: crmColors.textPrimary,
              ),
            ),
          ),
        ),
        DataCell(
          Text(
            phone,
            style: TextStyle(color: crmColors.textSecondary, fontSize: 13),
          ),
        ),
        DataCell(
          Wrap(
            spacing: 8,
            children: services
                .map(
                  (s) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: crmColors.surface,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: crmColors.border),
                    ),
                    child: Text(
                      s,
                      style: TextStyle(
                        fontSize: 11,
                        color: crmColors.textSecondary,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        DataCell(
          Row(
            children: [
              CircleAvatar(
                radius: 4,
                backgroundColor: isWorkingToday
                    ? crmColors.success
                    : crmColors.textSecondary,
              ),
              8.w,
              Text(
                schedule,
                style: TextStyle(
                  color: isWorkingToday
                      ? crmColors.textPrimary
                      : crmColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.event_available, size: 18),
                color: crmColors.textSecondary,
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(4),
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.edit_outlined, size: 18),
                color: crmColors.textSecondary,
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(4),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
