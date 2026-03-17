import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/extensions/space_extension.dart';
import '../../core/theme/crm_theme.dart';
import '../../core/utils/responsive_builder.dart';

class ClientProfileScreen extends StatelessWidget {
  final String clientName;

  const ClientProfileScreen({
    super.key,
    required this.clientName,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final crmColors = context.crmColors;
    final isDesktop = ResponsiveBuilder.isDesktop(context);

    // Decode URI name if passed via URL
    final name = Uri.decodeComponent(clientName);

    final leftColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: 24.p,
            child: Column(
              children: [
                const CircleAvatar(
                  radius: 48,
                  child: Icon(Icons.person, size: 48),
                ),
                16.h,
                Text(name, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                4.h,
                Text('Client since March 2021', style: TextStyle(color: crmColors.textSecondary)),
                16.h,
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: crmColors.secondary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '2,450 Loyalty Points',
                    style: TextStyle(fontWeight: FontWeight.bold, color: crmColors.primary),
                  ),
                ),
                24.h,
                const Divider(),
                16.h,
                _buildInfoRow(context, Icons.phone, 'PHONE', '+1 (555) 123-4567'),
                16.h,
                _buildInfoRow(context, Icons.email, 'EMAIL', 'emma.w@example.com'),
                16.h,
                _buildInfoRow(context, Icons.location_on, 'ADDRESS', '123 Luxury Ave, Apt 4B\nNew York, NY 10012'),
                16.h,
                _buildInfoRow(context, Icons.cake, 'BIRTHDAY', 'April 15, 1995'),
              ],
            ),
          ),
        ),
        16.h,
        Card(
          child: Padding(
            padding: 24.p,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Client Notes', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    Icon(Icons.edit_note, color: crmColors.textSecondary),
                  ],
                ),
                16.h,
                Container(
                  padding: 16.p,
                  decoration: BoxDecoration(
                    color: crmColors.background,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Prefers organic hair products. Allergic to certain synthetic fragrances. Likes a quiet environment during massages. Usually books morning appointments.',
                    style: TextStyle(color: crmColors.textSecondary, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    final rightColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: 24.p,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Appointments', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    TextButton(onPressed: () {}, child: const Text('View All')),
                  ],
                ),
                16.h,
                _buildAppointmentCard(context, 'NOV', '15', 'Bridal Makeup Trial', '10:00 AM - 11:30 AM', 'Upcoming', isUpcoming: true),
                12.h,
                _buildAppointmentCard(context, 'OCT', '12', 'Luxury Spa Pedicure', '3:00 PM - 4:00 PM', 'Completed', isUpcoming: false),
                12.h,
                _buildAppointmentCard(context, 'SEP', '05', 'Balayage & Blowout', '1:00 PM - 4:00 PM', 'Completed', isUpcoming: false),
              ],
            ),
          ),
        ),
        16.h,
        Card(
          child: Padding(
            padding: 24.p,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Service History Timeline', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                24.h,
                _buildTimelineItem(context, 'Haircut & Styling', 'Aug 22, 2023', 'Trimmed 2 inches, added face-framing layers. Used hydrating serum.', 'Stylist: Sarah Jenkins', isFirst: true),
                _buildTimelineItem(context, 'Deep Tissue Massage', 'Jul 10, 2023', '60-minute session. Focused on upper back and shoulders as requested.', 'Therapist: Michael Chen'),
                _buildTimelineItem(context, 'Hydrating Facial', 'May 04, 2023', 'Used rose-water infused products. Skin responded well, no redness.', 'Esthetician: Amanda Lopez', isLast: true),
              ],
            ),
          ),
        ),
      ],
    );

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/clients')),
              12.w,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Client Profile', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                    Text('View and manage details for $name.', style: theme.textTheme.bodyMedium?.copyWith(color: crmColors.textSecondary)),
                  ],
                ),
              ),
              if (!ResponsiveBuilder.isMobile(context)) ...[
                OutlinedButton(onPressed: () {}, child: const Text('Edit Profile')),
                16.w,
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(backgroundColor: crmColors.primary, foregroundColor: Colors.white),
                  child: const Text('Book Appointment'),
                ),
              ]
            ],
          ),
          if (ResponsiveBuilder.isMobile(context)) ...[
            16.h,
            Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: () {}, child: const Text('Edit Profile'))),
                16.w,
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(backgroundColor: crmColors.primary, foregroundColor: Colors.white),
                    child: const Text('Book Appointment'),
                  ),
                ),
              ],
            ),
          ],
          24.h,
          if (isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 1, child: leftColumn),
                24.w,
                Expanded(flex: 2, child: rightColumn),
              ],
            )
          else
            Column(
              children: [
                leftColumn,
                16.h,
                rightColumn,
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String label, String value) {
    final crmColors = context.crmColors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: crmColors.textSecondary),
        16.w,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: crmColors.textSecondary, letterSpacing: 1.2)),
              4.h,
              Text(value, style: TextStyle(fontWeight: FontWeight.w500, color: crmColors.textPrimary)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAppointmentCard(BuildContext context, String month, String day, String title, String time, String status, {bool isUpcoming = false}) {
    final crmColors = context.crmColors;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: crmColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: 16.p,
        child: Row(
          children: [
            Column(
              children: [
                Text(month, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: crmColors.textSecondary)),
                Text(day, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: crmColors.primary)),
              ],
            ),
            16.w,
            Container(width: 1, height: 40, color: crmColors.border),
            16.w,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(time, style: TextStyle(color: crmColors.textSecondary, fontSize: 13)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isUpcoming ? crmColors.warning.withOpacity(0.1) : crmColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                status,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isUpcoming ? crmColors.warning : crmColors.success,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineItem(BuildContext context, String title, String date, String desc, String staff, {bool isFirst = false, bool isLast = false}) {
    final crmColors = context.crmColors;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: 2,
                  height: 16,
                  color: isFirst ? Colors.transparent : crmColors.border,
                ),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: isFirst ? crmColors.primary : crmColors.border,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast ? Colors.transparent : crmColors.border,
                  ),
                ),
              ],
            ),
          ),
          16.w,
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(date, style: TextStyle(color: crmColors.textSecondary, fontSize: 13)),
                    ],
                  ),
                  8.h,
                  Text(desc, style: TextStyle(color: crmColors.textSecondary)),
                  8.h,
                  Text(staff, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
