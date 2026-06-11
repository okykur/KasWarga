import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_widgets.dart';
import 'auth_controller.dart';

class AuthBackdrop extends StatelessWidget {
  const AuthBackdrop({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFF7F2E8), Color(0xFFE7EEE8)],
                ),
              ),
            ),
          ),
          Positioned(
            top: -100,
            right: -70,
            child: Container(
              width: 300,
              height: 300,
              decoration: const BoxDecoration(
                color: Color(0x1AE5A93D),
                shape: BoxShape.circle,
              ),
            ),
          ),
          SafeArea(child: child),
        ],
      ),
    );
  }
}

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final success = await ref.read(authControllerProvider.notifier).login(
          identifier: _identifier.text,
          password: _password.text,
        );
    if (!mounted) return;
    final state = ref.read(authControllerProvider);
    if (success && state.profile != null) {
      final query = GoRouterState.of(context).uri.queryParameters;
      final next = query['next'];
      if (next != null && next.startsWith('/')) {
        final token = query['token'];
        context.go(token == null ? next : '$next?token=$token');
        return;
      }
      if (state.isPlatformSuperAdmin && state.memberships.isEmpty) {
        context.go('/super-admin/dashboard');
      } else if (state.memberships.isEmpty) {
        context.go('/onboarding');
      } else if (state.selectedCommunityId == null) {
        context.go('/select-community');
      } else {
        context.go(
          state.canManageSelectedCommunity
              ? '/admin/dashboard'
              : '/member/dashboard',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    return AuthBackdrop(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040),
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 760;
                  final form = Padding(
                    padding: EdgeInsets.all(wide ? 48 : 28),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (!wide) const _BrandMark(),
                          Text(
                            'Selamat datang kembali',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Masuk untuk mengelola iuran dan kabar lingkungan.',
                            style:
                                TextStyle(color: AppColors.muted, height: 1.5),
                          ),
                          const SizedBox(height: 28),
                          AppTextField(
                            label: 'Email atau Nomor Handphone',
                            hint: 'Masukkan email atau nomor handphone',
                            controller: _identifier,
                            prefixIcon: Icons.person_outline_rounded,
                            validator: (value) => Validators.required(
                              value,
                              field: 'Email atau nomor handphone',
                            ),
                          ),
                          const SizedBox(height: 16),
                          AppTextField(
                            label: 'Password',
                            controller: _password,
                            obscureText: _obscure,
                            prefixIcon: Icons.lock_outline_rounded,
                            validator: Validators.password,
                            suffixIcon: IconButton(
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => context.go('/forgot-password'),
                              child: const Text('Lupa password?'),
                            ),
                          ),
                          if (auth.errorMessage != null) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.danger.withValues(alpha: .08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                auth.errorMessage!,
                                style: const TextStyle(color: AppColors.danger),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          AppButton(
                            label: 'Masuk',
                            onPressed: _submit,
                            isLoading: auth.isLoading,
                            expand: true,
                            icon: Icons.login_rounded,
                          ),
                          const SizedBox(height: 18),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('Belum punya akun?'),
                              TextButton(
                                onPressed: () => context.go('/register'),
                                child: const Text('Daftar'),
                              ),
                            ],
                          ),
                          if (!AppConfig.isSupabaseConfigured)
                            const _DemoCredentialHint(),
                        ],
                      ),
                    ),
                  );
                  if (!wide) return form;
                  return Row(
                    children: [
                      const Expanded(child: _LoginStoryPanel()),
                      Expanded(child: form),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginStoryPanel extends StatelessWidget {
  const _LoginStoryPanel();

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 680),
        padding: const EdgeInsets.all(48),
        decoration: const BoxDecoration(
          color: AppColors.forest,
          image: DecorationImage(
            image: AssetImage('assets/images/kaswarga-icon.png'),
            alignment: Alignment.bottomRight,
            opacity: .08,
            scale: 1.6,
          ),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _BrandMark(light: true),
            Spacer(),
            Text(
              'Kas rapi.\nWarga tenang.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 42,
                height: 1.12,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 18),
            Text(
              'Satu tempat untuk tagihan, bukti transfer, pengeluaran, dan pengumuman komunitas.',
              style: TextStyle(color: Color(0xFFD5E4DC), height: 1.6),
            ),
          ],
        ),
      );
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({this.light = false});
  final bool light;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 32),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: light ? Colors.white : AppColors.forest,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                Icons.holiday_village_rounded,
                color: light ? AppColors.forest : Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              AppConstants.appName,
              style: TextStyle(
                color: light ? Colors.white : AppColors.ink,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
}

class _DemoCredentialHint extends StatelessWidget {
  const _DemoCredentialHint();

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.amber.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'Mode demo: admin@kaswarga.local / password123',
          style: TextStyle(fontSize: 12, color: AppColors.ink),
        ),
      );
}

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final success = await ref.read(authControllerProvider.notifier).register(
          fullName: _name.text,
          email: _email.text,
          phoneNumber: _phone.text,
          password: _password.text,
        );
    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pendaftaran berhasil. Silakan masuk ke akun Anda.'),
        ),
      );
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    return AuthBackdrop(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _BrandMark(),
                      Text(
                        'Buat akun warga',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Setelah mendaftar, Anda dapat membuat komunitas atau bergabung dengan kode.',
                        style: TextStyle(color: AppColors.muted),
                      ),
                      const SizedBox(height: 24),
                      AppTextField(
                        label: 'Nama Lengkap',
                        controller: _name,
                        validator: (value) =>
                            Validators.required(value, field: 'Nama lengkap'),
                      ),
                      const SizedBox(height: 14),
                      AppTextField(
                        label: 'Email',
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        validator: Validators.email,
                      ),
                      const SizedBox(height: 14),
                      AppTextField(
                        label: 'Nomor Handphone',
                        hint: 'Contoh: 081234567890',
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        validator: Validators.phone,
                      ),
                      const SizedBox(height: 14),
                      AppTextField(
                        label: 'Password',
                        controller: _password,
                        obscureText: true,
                        validator: Validators.password,
                      ),
                      const SizedBox(height: 14),
                      AppTextField(
                        label: 'Konfirmasi Password',
                        controller: _confirmation,
                        obscureText: true,
                        validator: (value) {
                          if (value != _password.text) {
                            return 'Konfirmasi password belum sama.';
                          }
                          return Validators.password(value);
                        },
                      ),
                      if (auth.errorMessage != null) ...[
                        const SizedBox(height: 14),
                        Text(
                          auth.errorMessage!,
                          style: const TextStyle(color: AppColors.danger),
                        ),
                      ],
                      const SizedBox(height: 22),
                      AppButton(
                        label: 'Daftar',
                        onPressed: _submit,
                        isLoading: auth.isLoading,
                        expand: true,
                        icon: Icons.person_add_alt_1_rounded,
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton(
                          onPressed: () => context.go('/login'),
                          child: const Text('Sudah punya akun? Masuk'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    return AuthBackdrop(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: _sent
                    ? EmptyState(
                        title: 'Periksa email Anda',
                        message:
                            'Tautan reset password telah dikirim ke email terdaftar.',
                        icon: Icons.mark_email_read_outlined,
                        action: FilledButton(
                          onPressed: () => context.go('/login'),
                          child: const Text('Kembali ke Login'),
                        ),
                      )
                    : Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _BrandMark(),
                            Text(
                              'Lupa password',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Reset password saat ini dikirim melalui email terdaftar.',
                              style: TextStyle(
                                color: AppColors.muted,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 24),
                            AppTextField(
                              label: 'Email',
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              validator: Validators.email,
                            ),
                            if (auth.errorMessage != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                auth.errorMessage!,
                                style: const TextStyle(color: AppColors.danger),
                              ),
                            ],
                            const SizedBox(height: 20),
                            AppButton(
                              label: 'Kirim Tautan Reset',
                              onPressed: () async {
                                if (!_formKey.currentState!.validate()) return;
                                final success = await ref
                                    .read(authControllerProvider.notifier)
                                    .sendPasswordReset(_email.text);
                                if (mounted && success) {
                                  setState(() => _sent = true);
                                }
                              },
                              isLoading: auth.isLoading,
                              expand: true,
                              icon: Icons.send_rounded,
                            ),
                            const SizedBox(height: 8),
                            Center(
                              child: TextButton(
                                onPressed: () => context.go('/login'),
                                child: const Text('Kembali ke Login'),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
