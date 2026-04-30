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
    final session = ref.watch(authControllerProvider).session;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
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
                  Container(
                    height: 160,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [crm.primary, crm.sidebar],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  Positioned(
                    bottom: -50,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: CircleAvatar(
                        radius: 54,
                        backgroundColor: crm.surface,
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: crm.primary,
                          child: Text(
                            session?.email.substring(0, 1).toUpperCase() ?? 'U',
                            style: const TextStyle(
                              color: Colors.white, 
                              fontSize: 40, 
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              60.h,
              Text(
                session?.email ?? 'User Email',
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
              ),
              Text(
                (session?.role ?? 'ARTIST').toUpperCase(),
                style: TextStyle(
                  color: crm.primary, 
                  letterSpacing: 2, 
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
              32.h,
              // Profile Stats
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ProfileStat(label: 'Works', value: '42'),
                  _ProfileStat(label: 'Rating', value: '4.8'),
                  _ProfileStat(label: 'Exp', value: '3y'),
                ],
              ),
              32.h,
              // Settings Group
              Container(
                decoration: BoxDecoration(
                  color: crm.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: crm.border.withValues(alpha: 0.5)),
                ),
                child: Column(
                  children: [
                    _ProfileTile(
                      icon: Icons.person_outline_rounded,
                      title: 'Account Settings',
                      subtitle: 'Update your profile information',
                      onTap: () {},
                    ),
                    _ProfileTile(
                      icon: Icons.notifications_none_rounded,
                      title: 'Notifications',
                      subtitle: 'Configure your alerts',
                      onTap: () {},
                    ),
                    _ProfileTile(
                      icon: Icons.security_rounded,
                      title: 'Security',
                      subtitle: 'Password and authentication',
                      onTap: () {},
                    ),
                    _ProfileTile(
                      icon: Icons.help_outline_rounded,
                      title: 'Support',
                      subtitle: 'Get help or send feedback',
                      onTap: () {},
                      isLast: true,
                    ),
                  ],
                ),
              ),
              24.h,
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
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    backgroundColor: Colors.redAccent.withValues(alpha: 0.05),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              40.h,
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  final String label;
  final String value;

  const _ProfileStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
        Text(
          label,
          style: TextStyle(color: context.crmColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isLast;

  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: crm.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: crm.primary, size: 22),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
          subtitle: Text(subtitle, style: TextStyle(color: crm.textSecondary, fontSize: 12)),
          trailing: Icon(Icons.chevron_right_rounded, color: crm.textSecondary.withValues(alpha: 0.5)),
          onTap: onTap,
        ),
        if (!isLast) Divider(height: 1, indent: 70, color: crm.border.withValues(alpha: 0.5)),
      ],
    );
  }
}
