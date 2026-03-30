import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/extensions/space_extension.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/crm_theme.dart';
import '../../core/utils/responsive_builder.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    try {
      await ref
          .read(authControllerProvider)
          .login(
            email: _emailController.text,
            password: _passwordController.text,
          );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ref.read(authControllerProvider).errorMessage ??
                'Unable to sign in',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final crmColors = context.crmColors;
    final theme = Theme.of(context);
    final auth = ref.watch(authControllerProvider);
    final isDesktop = ResponsiveBuilder.isDesktop(context);

    return Scaffold(
      backgroundColor: crmColors.background,
      body: SafeArea(
        child: ResponsiveBuilder(
          mobile: _buildMobileLayout(context, theme, crmColors, auth),
          tablet: _buildMobileLayout(context, theme, crmColors, auth),
          desktop: Row(
            children: [
              Expanded(
                child: Container(
                  color: crmColors.sidebar,
                  child: Center(
                    child: Container(
                      width: 320,
                      height: 320,
                      padding: 36.px,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(40),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 42,
                            offset: const Offset(0, 22),
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/images/nizan_logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: _LoginCard(
                        formKey: _formKey,
                        emailController: _emailController,
                        passwordController: _passwordController,
                        obscurePassword: _obscurePassword,
                        isSubmitting: auth.isSubmitting,
                        isDesktop: isDesktop,
                        onTogglePassword: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                        onSubmit: _submit,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(
    BuildContext context,
    ThemeData theme,
    CrmTheme crmColors,
    AuthController auth,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: 24.px,
            decoration: BoxDecoration(
              color: crmColors.sidebar,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 132,
                  height: 132,
                  padding: 18.px,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/images/nizan_logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
                24.h,
                Text(
                  'Welcome back to your booking desk.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                12.h,
                Text(
                  'Sign in to manage live CRM requests, client records, and staff planning.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.78),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          24.h,
          _LoginCard(
            formKey: _formKey,
            emailController: _emailController,
            passwordController: _passwordController,
            obscurePassword: _obscurePassword,
            isSubmitting: auth.isSubmitting,
            isDesktop: false,
            onTogglePassword: () {
              setState(() => _obscurePassword = !_obscurePassword);
            },
            onSubmit: _submit,
          ),
        ],
      ),
    );
  }
}

class _LoginCard extends StatelessWidget {
  const _LoginCard({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.isSubmitting,
    required this.isDesktop,
    required this.onTogglePassword,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final bool isSubmitting;
  final bool isDesktop;
  final VoidCallback onTogglePassword;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final crmColors = context.crmColors;

    return Container(
      padding: EdgeInsets.all(isDesktop ? 36 : 24),
      decoration: BoxDecoration(
        color: crmColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: crmColors.border),
        boxShadow: [
          BoxShadow(
            color: crmColors.primary.withValues(alpha: 0.06),
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sign in',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            8.h,
            Text(
              'Use your admin account to access the CRM dashboard.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: crmColors.textSecondary,
              ),
            ),
            28.h,
            TextFormField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.username],
              decoration: const InputDecoration(
                labelText: 'Email address',
                prefixIcon: Icon(Icons.mail_outline),
              ),
              validator: (value) {
                final email = value?.trim() ?? '';
                if (email.isEmpty) return 'Email is required';
                final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                if (!emailRegex.hasMatch(email)) {
                  return 'Enter a valid email';
                }
                return null;
              },
            ),
            16.h,
            TextFormField(
              controller: passwordController,
              obscureText: obscurePassword,
              autofillHints: const [AutofillHints.password],
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  onPressed: onTogglePassword,
                  icon: Icon(
                    obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              onFieldSubmitted: (_) => onSubmit(),
              validator: (value) {
                if ((value ?? '').trim().isEmpty) {
                  return 'Password is required';
                }
                return null;
              },
            ),
            24.h,
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isSubmitting ? null : onSubmit,
                icon: Icon(
                  isSubmitting ? Icons.hourglass_top : Icons.login_rounded,
                ),
                label: Text(
                  isSubmitting ? 'Signing in...' : 'Access CRM',
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
