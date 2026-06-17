import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/extensions/space_extension.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/crm_theme.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final crm = context.crmColors;
    final session = ref.watch(authSessionProvider);
    final employeeAsync = ref.watch(currentEmployeeProvider);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            children: [
              // Cover & Avatar Section
              Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // Decorative Cover Banner
                  Container(
                    height: 170,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [crm.sidebar, crm.primary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: crm.primary.withValues(alpha: 0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Stack(
                        children: [
                          // Decorative shapes inside cover
                          Positioned(
                            right: -40,
                            top: -40,
                            child: CircleAvatar(
                              radius: 90,
                              backgroundColor: Colors.white.withValues(alpha: 0.04),
                            ),
                          ),
                          Positioned(
                            left: -60,
                            bottom: -50,
                            child: CircleAvatar(
                              radius: 110,
                              backgroundColor: crm.accent.withValues(alpha: 0.06),
                            ),
                          ),
                          Positioned(
                            right: 40,
                            bottom: -30,
                            child: CircleAvatar(
                              radius: 40,
                              backgroundColor: Colors.white.withValues(alpha: 0.02),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Avatar with status badge
                  Positioned(
                    bottom: -55,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 16,
                                offset: Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: crm.accent.withValues(alpha: 0.8), width: 2.5),
                            ),
                            child: employeeAsync.when(
                              data: (employee) {
                                final imageUrl = employee?.profileImage ?? '';
                                final initial = (employee?.name ?? session?.name ?? session?.email ?? 'U')
                                    .substring(0, 1)
                                    .toUpperCase();

                                return CircleAvatar(
                                  radius: 50,
                                  backgroundColor: crm.secondary.withValues(alpha: 0.5),
                                  backgroundImage: imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
                                  child: imageUrl.isEmpty
                                      ? Text(
                                          initial,
                                          style: TextStyle(
                                            color: crm.primary,
                                            fontSize: 38,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        )
                                      : null,
                                );
                              },
                              loading: () => CircleAvatar(
                                radius: 50,
                                backgroundColor: crm.secondary.withValues(alpha: 0.3),
                                child: const SizedBox(
                                  width: 32,
                                  height: 32,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                              error: (_, _) => CircleAvatar(
                                radius: 50,
                                backgroundColor: crm.primary,
                                child: Text(
                                  (session?.email ?? 'U').substring(0, 1).toUpperCase(),
                                  style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w900),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Online / Active Badge
                        Positioned(
                          bottom: 4,
                          right: 4,
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: crm.success,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3.5),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              68.h,

              // Name & Email Title
              employeeAsync.when(
                data: (employee) => Text(
                  employee?.name ?? session?.name ?? 'CRM Artist',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: crm.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                loading: () => Container(
                  width: 140,
                  height: 20,
                  decoration: BoxDecoration(
                    color: crm.border.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                error: (_, _) => Text(
                  session?.name ?? 'CRM User',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              4.h,
              Text(
                session?.email ?? 'artist@email.com',
                style: TextStyle(
                  color: crm.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              8.h,

              // Role & Specialty Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: crm.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      (session?.role ?? 'ARTIST').toUpperCase(),
                      style: TextStyle(
                        color: crm.primary,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  employeeAsync.when(
                    data: (employee) {
                      if (employee == null || employee.specialization.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: crm.accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            employee.specialization.toUpperCase(),
                            style: TextStyle(
                              color: crm.accent,
                              fontWeight: FontWeight.w800,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                ],
              ),
              28.h,

              // Profile Stats Cards Row
              employeeAsync.when(
                data: (employee) {
                  final worksCount = employee?.works.length ?? 0;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: _ProfileStatCard(
                          label: 'Works',
                          value: worksCount > 0 ? '$worksCount' : '42',
                          icon: Icons.palette_outlined,
                          iconColor: const Color(0xFF6B4EFF),
                        ),
                      ),
                      12.w,
                      const Expanded(
                        child: _ProfileStatCard(
                          label: 'Rating',
                          value: '4.8',
                          icon: Icons.star_rounded,
                          iconColor: Color(0xFFC9A66B),
                        ),
                      ),
                      12.w,
                      const Expanded(
                        child: _ProfileStatCard(
                          label: 'Exp',
                          value: '3y',
                          icon: Icons.schedule_rounded,
                          iconColor: Color(0xFFE05638),
                        ),
                      ),
                    ],
                  );
                },
                loading: () => Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: _StatCardSkeleton(crm: crm)),
                    12.w,
                    Expanded(child: _StatCardSkeleton(crm: crm)),
                    12.w,
                    Expanded(child: _StatCardSkeleton(crm: crm)),
                  ],
                ),
                error: (_, _) => const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: _ProfileStatCard(
                        label: 'Works',
                        value: '42',
                        icon: Icons.palette_outlined,
                        iconColor: Color(0xFF6B4EFF),
                      ),
                    ),
                    Expanded(
                      child: _ProfileStatCard(
                        label: 'Rating',
                        value: '4.8',
                        icon: Icons.star_rounded,
                        iconColor: Color(0xFFC9A66B),
                      ),
                    ),
                    Expanded(
                      child: _ProfileStatCard(
                        label: 'Exp',
                        value: '3y',
                        icon: Icons.schedule_rounded,
                        iconColor: Color(0xFFE05638),
                      ),
                    ),
                  ],
                ),
              ),
              24.h,

              // Artist Details Card (Dynamic employee metadata)
              employeeAsync.when(
                data: (employee) {
                  if (employee == null) return const SizedBox.shrink();
                  
                  final locationStr = [
                    if (employee.districtName.isNotEmpty) employee.districtName,
                    if (employee.stateName.isNotEmpty) employee.stateName,
                  ].join(', ');

                  return Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: crm.surface,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: crm.border.withValues(alpha: 0.5)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.015),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.badge_outlined, color: crm.accent, size: 20),
                                8.w,
                                Text(
                                  'Professional Profile',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                    color: crm.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            16.h,
                            _DetailRow(
                              icon: Icons.work_outline_rounded,
                              label: 'Specialization',
                              value: employee.specialization.isNotEmpty 
                                  ? employee.specialization 
                                  : 'General Artistry',
                            ),
                            12.h,
                            _DetailRow(
                              icon: Icons.location_on_outlined,
                              label: 'Service Area',
                              value: locationStr.isNotEmpty ? locationStr : 'Not specified',
                            ),
                            12.h,
                            _DetailRow(
                              icon: Icons.phone_android_rounded,
                              label: 'Contact Phone',
                              value: employee.phone.isNotEmpty ? employee.phone : 'Not specified',
                            ),
                            12.h,
                            _DetailRow(
                              icon: Icons.category_outlined,
                              label: 'Artist Category',
                              value: employee.category.toUpperCase(),
                            ),
                          ],
                        ),
                      ),
                      24.h,
                    ],
                  );
                },
                loading: () => Column(
                  children: [
                    Container(
                      width: double.infinity,
                      height: 180,
                      decoration: BoxDecoration(
                        color: crm.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: crm.border.withValues(alpha: 0.5)),
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                    24.h,
                  ],
                ),
                error: (_, _) => const SizedBox.shrink(),
              ),

              // Settings Card Group
              Container(
                decoration: BoxDecoration(
                  color: crm.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: crm.border.withValues(alpha: 0.5)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.015),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Column(
                    children: [
                      _ProfileTile(
                        icon: Icons.person_outline_rounded,
                        title: 'Account Settings',
                        subtitle: 'Update your profile information',
                        gradientColors: const [Color(0xFF6B4EFF), Color(0xFF9075FF)],
                        onTap: () {},
                      ),
                      _ProfileTile(
                        icon: Icons.notifications_none_rounded,
                        title: 'Notifications',
                        subtitle: 'Configure your alerts & push options',
                        gradientColors: const [Color(0xFFE05638), Color(0xFFFF7A5E)],
                        onTap: () {},
                      ),
                      _ProfileTile(
                        icon: Icons.security_rounded,
                        title: 'Security',
                        subtitle: 'Password, PIN and authentication',
                        gradientColors: const [Color(0xFFC9A66B), Color(0xFFE6C48B)],
                        onTap: () {},
                      ),
                      _ProfileTile(
                        icon: Icons.help_outline_rounded,
                        title: 'Support Center',
                        subtitle: 'Get help, FAQs or send feedback',
                        gradientColors: const [Color(0xFF0F9D58), Color(0xFF34A853)],
                        onTap: () {},
                        isLast: true,
                      ),
                    ],
                  ),
                ),
              ),
              24.h,

              // Logout Button
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () => ref.read(authControllerProvider).logout(),
                  icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
                  label: const Text(
                    'LOGOUT ACCOUNT',
                    style: TextStyle(
                      color: Colors.redAccent, 
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                      fontSize: 13,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    backgroundColor: Colors.redAccent.withValues(alpha: 0.05),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.15)),
                    ),
                  ),
                ),
              ),
              30.h,
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;

  const _ProfileStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: crm.border.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          10.h,
          Text(
            value,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: crm.textPrimary,
            ),
          ),
          2.h,
          Text(
            label,
            style: TextStyle(
              color: crm.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCardSkeleton extends StatelessWidget {
  final CrmTheme crm;
  const _StatCardSkeleton({required this.crm});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 98,
      decoration: BoxDecoration(
        color: crm.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: crm.border.withValues(alpha: 0.3)),
      ),
      child: const Center(
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 1.5),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: crm.border.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: crm.textSecondary),
        ),
        12.w,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: crm.textSecondary,
                ),
              ),
              1.h,
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: crm.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradientColors;
  final VoidCallback onTap;
  final bool isLast;

  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradientColors,
    required this.onTap,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: gradientColors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: gradientColors.first.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(icon, color: Colors.white, size: 22),
                  ),
                  16.w,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            color: crm.textPrimary,
                          ),
                        ),
                        2.h,
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: crm.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: crm.textSecondary.withValues(alpha: 0.5),
                    size: 24,
                  ),
                ],
              ),
            ),
            if (!isLast)
              Divider(
                height: 1,
                indent: 76,
                color: crm.border.withValues(alpha: 0.4),
              ),
          ],
        ),
      ),
    );
  }
}
