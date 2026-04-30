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
  bool _isArtistLogin = false;
  String? _selectedState;
  String? _selectedRegion;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_isArtistLogin) {
      if (!_formKey.currentState!.validate()) return;
    } else {
      // For artist login, we skip state/region validation but still need email/password
      if (!_formKey.currentState!.validate()) return;
    }

    try {
      await ref
          .read(authControllerProvider)
          .login(
            email: _emailController.text,
            password: _passwordController.text,
            // You might need to pass role or something here if backend requires it
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
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        crmColors.sidebar,
                        crmColors.primary,
                      ],
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        top: -100,
                        right: -100,
                        child: Container(
                          width: 400,
                          height: 400,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 280,
                              height: 280,
                              padding: 48.px,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(60),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.25),
                                    blurRadius: 60,
                                    offset: const Offset(0, 30),
                                  ),
                                ],
                              ),
                              child: Image.asset(
                                'assets/images/nizan_logo.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                            48.h,
                            Text(
                              'NIZAN MAKEOVERS',
                              style: theme.textTheme.displaySmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 4,
                              ),
                            ),
                            12.h,
                            Text(
                              'ELEVATING BEAUTY STANDARDS',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: Colors.white.withValues(alpha: 0.6),
                                letterSpacing: 2,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  color: crmColors.background,
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(40),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: _LoginCard(
                          formKey: _formKey,
                          emailController: _emailController,
                          passwordController: _passwordController,
                          obscurePassword: _obscurePassword,
                          isSubmitting: auth.isSubmitting,
                          isDesktop: true,
                          isArtistLogin: _isArtistLogin,
                          selectedState: _selectedState,
                          selectedRegion: _selectedRegion,
                          onArtistLoginChanged: (val) =>
                              setState(() => _isArtistLogin = val),
                          onStateChanged: (val) =>
                              setState(() => _selectedState = val),
                          onRegionChanged: (val) =>
                              setState(() => _selectedRegion = val),
                          onTogglePassword: () {
                            setState(() => _obscurePassword = !_obscurePassword);
                          },
                          onSubmit: _submit,
                        ),
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
    return Container(
      color: crmColors.sidebar,
      child: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(24, 60, 24, 40),
              child: Column(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    padding: 16.px,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
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
                    'NIZAN MAKEOVERS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                    ),
                  ),
                  8.h,
                  Text(
                    'Creative Enterprise Portal',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height - 250,
              ),
              decoration: BoxDecoration(
                color: crmColors.background,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
                child: _LoginCard(
                  formKey: _formKey,
                  emailController: _emailController,
                  passwordController: _passwordController,
                  obscurePassword: _obscurePassword,
                  isSubmitting: auth.isSubmitting,
                  isDesktop: false,
                  isArtistLogin: _isArtistLogin,
                  selectedState: _selectedState,
                  selectedRegion: _selectedRegion,
                  onArtistLoginChanged: (val) => setState(() => _isArtistLogin = val),
                  onStateChanged: (val) => setState(() => _selectedState = val),
                  onRegionChanged: (val) => setState(() => _selectedRegion = val),
                  onTogglePassword: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                  onSubmit: _submit,
                ),
              ),
            ),
          ],
        ),
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
    required this.isArtistLogin,
    required this.selectedState,
    required this.selectedRegion,
    required this.onArtistLoginChanged,
    required this.onStateChanged,
    required this.onRegionChanged,
    required this.onTogglePassword,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final bool isSubmitting;
  final bool isDesktop;
  final bool isArtistLogin;
  final String? selectedState;
  final String? selectedRegion;
  final ValueChanged<bool> onArtistLoginChanged;
  final ValueChanged<String?> onStateChanged;
  final ValueChanged<String?> onRegionChanged;
  final VoidCallback onTogglePassword;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final crmColors = context.crmColors;
    final isMobile = ResponsiveBuilder.isMobile(context);
    return Container(
      padding: EdgeInsets.all(isMobile ? 28 : 40),
      decoration: BoxDecoration(
        color: crmColors.surface,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: crmColors.border.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Welcome Back',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                _ArtistToggle(
                  value: isArtistLogin,
                  onChanged: onArtistLoginChanged,
                ),
              ],
            ),
            4.h,
            Text(
              isArtistLogin
                  ? 'Artist Portal Access'
                  : 'Administrative CRM Access',
              style: TextStyle(
                color: crmColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 13,
                letterSpacing: 1,
              ),
            ),
            32.h,
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: Column(
                children: [
                  if (!isArtistLogin) ...[
                    DropdownButtonFormField<String>(
                      initialValue: selectedState,
                      items: ['Kerala', 'Karnataka']
                          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: onStateChanged,
                      decoration: const InputDecoration(
                        labelText: 'Select State',
                        prefixIcon: Icon(Icons.map_outlined),
                      ),
                      validator: (value) =>
                          value == null ? 'State is required' : null,
                    ),
                    16.h,
                    DropdownButtonFormField<String>(
                      initialValue: selectedRegion,
                      items: ['Kochi', 'Calicut']
                          .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                          .toList(),
                      onChanged: onRegionChanged,
                      decoration: const InputDecoration(
                        labelText: 'Select Region',
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                      validator: (value) =>
                          value == null ? 'Region is required' : null,
                    ),
                    16.h,
                  ],
                ],
              ),
            ),
            TextFormField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.username],
              decoration: const InputDecoration(
                labelText: 'Email Address',
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
            32.h,
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: isSubmitting ? null : onSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: crmColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            isArtistLogin ? 'ENTER ARTIST PORTAL' : 'ACCESS CRM DESK',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                              fontSize: 14,
                            ),
                          ),
                          12.w,
                          const Icon(Icons.arrow_forward_rounded, size: 18),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArtistToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ArtistToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final crm = context.crmColors;
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: value ? crm.primary.withValues(alpha: 0.15) : crm.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: value ? crm.primary.withValues(alpha: 0.3) : crm.border,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              value ? Icons.brush_rounded : Icons.person_outline_rounded,
              size: 16,
              color: value ? crm.primary : crm.textSecondary,
            ),
            8.w,
            Text(
              'ARTIST',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: value ? crm.primary : crm.textSecondary,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
