import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import '../../core/extensions/space_extension.dart';
import '../../core/providers/booking_provider.dart';
import '../../core/theme/crm_theme.dart';
import '../../core/models/booking.dart';
import '../common_widgets/paginated_footer.dart';

class ArtistWorksScreen extends HookConsumerWidget {
  const ArtistWorksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final crmColors = context.crmColors;
    final pageState = useState(1);
    
    final asyncWorks = ref.watch(artistAssignedWorksProvider(pageState.value));

    return Scaffold(
      backgroundColor: crmColors.background,
      body: asyncWorks.when(
        data: (response) {
          final items = response.items;
          
          if (items.isEmpty) {
            return _EmptyState(crmColors: crmColors, theme: theme);
          }

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final booking = items[index];
                    return _WorkCard(booking: booking, crmColors: crmColors, theme: theme);
                  },
                ),
              ),
              _SummaryBar(summary: response.summary, crmColors: crmColors, theme: theme),
              PaginatedFooter(
                page: response.page,
                limit: response.limit,
                totalPages: response.totalPages,
                totalItems: response.totalItems,
                currentItemCount: items.length,
                onPrevious: response.page > 1 ? () => pageState.value-- : null,
                onNext: response.page < response.totalPages ? () => pageState.value++ : null,
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: crmColors.destructive),
              16.h,
              Text('Error loading works: $error'),
              16.h,
              ElevatedButton(
                onPressed: () => ref.invalidate(artistAssignedWorksProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkCard extends StatelessWidget {
  final Booking booking;
  final CrmTheme crmColors;
  final ThemeData theme;

  const _WorkCard({
    required this.booking,
    required this.crmColors,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final balance = booking.totalPrice - booking.advanceAmount - booking.discountAmount;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: crmColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: crmColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Status and Date
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _StatusBadge(status: booking.status, crmColors: crmColors),
                Text(
                  _formatDate(booking.serviceStart),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: crmColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking.customerName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                4.h,
                Text(
                  booking.service,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: crmColors.textSecondary,
                  ),
                ),
                16.h,
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                    4.w,
                    Expanded(
                      child: Text(
                        booking.region.isNotEmpty ? booking.region : 'Location not set',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: crmColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                12.h,
                Row(
                  children: [
                    const Icon(Icons.access_time_outlined, size: 16, color: Colors.grey),
                    4.w,
                    Text(
                      '${_formatTime(booking.serviceStart)} - ${_formatTime(booking.serviceEnd)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: crmColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Payment Info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _PaymentStat(label: 'Total', value: '₹${booking.totalPrice.toStringAsFixed(0)}', color: crmColors.textPrimary),
                _PaymentStat(label: 'Advance', value: '₹${booking.advanceAmount.toStringAsFixed(0)}', color: crmColors.success),
                _PaymentStat(label: 'Balance', value: '₹${balance.toStringAsFixed(0)}', color: balance > 0 ? crmColors.destructive : crmColors.success),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatTime(DateTime date) {
    final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final ampm = date.hour >= 12 ? 'PM' : 'AM';
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute $ampm';
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  final CrmTheme crmColors;

  const _StatusBadge({required this.status, required this.crmColors});

  @override
  Widget build(BuildContext context) {
    final color = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

class _PaymentStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _PaymentStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w500),
        ),
        4.h,
        Text(
          value,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }
}

class _SummaryBar extends StatelessWidget {
  final BookingPageSummary summary;
  final CrmTheme crmColors;
  final ThemeData theme;

  const _SummaryBar({required this.summary, required this.crmColors, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: crmColors.surface,
        border: Border(top: BorderSide(color: crmColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _SummaryItem(label: 'Total Sales', value: '₹${summary.totalSales.toStringAsFixed(0)}', color: crmColors.primary),
          _SummaryItem(label: 'Advance', value: '₹${summary.totalAdvance.toStringAsFixed(0)}', color: crmColors.success),
          _SummaryItem(label: 'Completed', value: '${summary.completedCount}', color: crmColors.success),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryItem({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final CrmTheme crmColors;
  final ThemeData theme;

  const _EmptyState({required this.crmColors, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.work_history_outlined, size: 64, color: crmColors.textSecondary.withValues(alpha: 0.3)),
          16.h,
          Text(
            'No Assigned Works',
            style: theme.textTheme.titleLarge?.copyWith(color: crmColors.textSecondary),
          ),
          8.h,
          Text(
            'Your assigned bookings will appear here.',
            style: theme.textTheme.bodyMedium?.copyWith(color: crmColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
