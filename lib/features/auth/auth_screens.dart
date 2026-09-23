import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../app/i18n/l10n.dart';
import '../../app/settings_cubit.dart';
import '../../app/theme.dart';
import '../../shared/widgets.dart';
import '../cubits.dart';
import '../shared/formatters.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginState();
}

class _LoginState extends State<LoginScreen> {
  final e = TextEditingController();
  final p = TextEditingController();
  bool _loginAttempt = false;
  bool _hidePassword = true;

  @override
  void dispose() {
    e.dispose();
    p.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AuthScaffold(
        child: BlocConsumer<AuthCubit, AuthState>(
          listenWhen: (prev, s) => _loginAttempt && prev.loading && !s.loading && s.error != null,
          listener: (c, s) {
            ScaffoldMessenger.of(c).showSnackBar(
              SnackBar(content: Text(mapError(s.error!, L10n.of(c)))),
            );
          },
          builder: (c, s) {
            final theme = Theme.of(c);
            final muted = theme.colorScheme.onSurface.withValues(alpha: .65);

            return AnimationLimiter(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, AppSpacing.xl),
                children: AnimationConfiguration.toStaggeredList(
                  duration: const Duration(milliseconds: 420),
                  childAnimationBuilder: (widget) => SlideAnimation(
                    verticalOffset: 28,
                    child: FadeInAnimation(child: widget),
                  ),
                  children: [
                    const _LoginLogo(),
                    const SizedBox(height: AppSpacing.lg),
                    const _LoginHero(),
                    const SizedBox(height: AppSpacing.xl),
                    GlassCard(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            c.tr('auth.loginTitle'),
                            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            c.tr('auth.loginSubtitle'),
                            style: theme.textTheme.bodySmall?.copyWith(color: muted),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          TextField(
                            controller: e,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.mail_outline_rounded),
                              labelText: c.tr('auth.email'),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          TextField(
                            controller: p,
                            obscureText: _hidePassword,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _submit(c, s),
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.lock_outline_rounded),
                              labelText: c.tr('auth.password'),
                              hintText: c.tr('auth.passwordHint'),
                              suffixIcon: IconButton(
                                onPressed: () => setState(() => _hidePassword = !_hidePassword),
                                icon: Icon(_hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                              ),
                            ),
                          ),
                          if (_loginAttempt && s.error != null && !s.loading) ...[
                            const SizedBox(height: AppSpacing.sm),
                            _LoginErrorBanner(message: mapError(s.error!, L10n.of(c))),
                          ],
                          const SizedBox(height: AppSpacing.xs),
                          Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: TextButton(
                              onPressed: () => c.push('/forgot'),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                                visualDensity: VisualDensity.compact,
                              ),
                              child: Text(c.tr('auth.forgotPassword')),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          _GradientAuthButton(
                            loading: s.loading,
                            label: s.loading ? c.tr('auth.loggingIn') : c.tr('auth.login'),
                            onPressed: s.loading ? null : () => _submit(c, s),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Row(
                            children: [
                              Expanded(child: Divider(color: muted.withValues(alpha: .35))),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                                child: Text(
                                  c.tr('auth.orContinue'),
                                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                                ),
                              ),
                              Expanded(child: Divider(color: muted.withValues(alpha: .35))),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          OutlinedButton.icon(
                            onPressed: () => c.go('/register'),
                            icon: const Icon(Icons.person_add_outlined, size: 20),
                            label: Text(c.tr('auth.register')),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: .45)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const AuthPreferencesBar(),
                  ],
                ),
              ),
            );
          },
        ),
      );

  void _submit(BuildContext c, AuthState s) {
    if (s.loading) return;
    setState(() => _loginAttempt = true);
    c.read<AuthCubit>().login(e.text, p.text);
  }
}

class _LoginLogo extends StatelessWidget {
  const _LoginLogo();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.primary.withValues(alpha: dark ? .28 : .18),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              gradient: AppGradients.hero,
              borderRadius: BorderRadius.circular(26),
              boxShadow: AppShadows.elevated(AppColors.primary),
            ),
            padding: const EdgeInsets.all(20),
            child: SvgPicture.asset('assets/images/app_logo.svg'),
          ),
        ],
      ),
    );
  }
}

class _LoginHero extends StatelessWidget {
  const _LoginHero();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Text(
          context.tr('auth.welcomeBack'),
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          context.tr('auth.heroSubtitle'),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: .7),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _LoginErrorBanner extends StatelessWidget {
  final String message;

  const _LoginErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: error.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: error.withValues(alpha: .25)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: error, size: 20),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: error, fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _GradientAuthButton extends StatelessWidget {
  final bool loading;
  final String label;
  final VoidCallback? onPressed;

  const _GradientAuthButton({
    required this.loading,
    required this.label,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: disabled ? null : AppGradients.hero,
        color: disabled ? Theme.of(context).colorScheme.onSurface.withValues(alpha: .12) : null,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: disabled ? null : AppShadows.medium(AppColors.primary),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: SizedBox(
            height: 52,
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : Text(
                      label,
                      style: TextStyle(
                        color: disabled ? Theme.of(context).colorScheme.onSurface.withValues(alpha: .45) : Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterState();
}

class _RegisterState extends State<RegisterScreen> {
  final n = TextEditingController();
  final ph = TextEditingController();
  final e = TextEditingController();
  final p = TextEditingController();
  final cp = TextEditingController();
  bool _hidePassword = true;
  bool _hideConfirmPassword = true;
  bool _registerAttempt = false;

  @override
  void dispose() {
    n.dispose();
    ph.dispose();
    e.dispose();
    p.dispose();
    cp.dispose();
    super.dispose();
  }

  void _submit(BuildContext c, AuthState s) {
    if (s.loading) return;

    FocusScope.of(c).unfocus();

    if (n.text.trim().length < 2) {
      showAppSnack(c, c.tr('auth.errorNameShort'), type: AppSnackType.error);
      return;
    }
    if (!e.text.contains('@')) {
      showAppSnack(c, c.tr('auth.errorEmailInvalid'), type: AppSnackType.error);
      return;
    }
    if (ph.text.trim().isEmpty) {
      showAppSnack(c, c.tr('auth.validateData'), type: AppSnackType.error);
      return;
    }
    if (p.text.length < 8) {
      showAppSnack(c, c.tr('auth.errorPasswordShort'), type: AppSnackType.error);
      return;
    }
    if (p.text != cp.text) {
      showAppSnack(c, c.tr('auth.errorPasswordMismatch'), type: AppSnackType.error);
      return;
    }

    setState(() => _registerAttempt = true);
    c.read<AuthCubit>().register(n.text, ph.text, e.text, p.text);
  }

  @override
  Widget build(BuildContext context) => AuthScaffold(
        child: BlocConsumer<AuthCubit, AuthState>(
          listenWhen: (prev, s) => _registerAttempt && prev.loading && !s.loading && s.error != null,
          listener: (c, s) {
            ScaffoldMessenger.of(c).showSnackBar(
              SnackBar(content: Text(mapError(s.error!, L10n.of(c)))),
            );
          },
          builder: (c, s) {
            final theme = Theme.of(c);

            return Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => context.go('/login'),
                ),
                title: Text(context.tr('auth.register')),
              ),
              body: ListView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                children: [
                  Text(
                    context.tr('passenger.travelWithComfort'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: .7),
                        ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: n,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.person_outline),
                            labelText: context.tr('auth.fullName'),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        TextField(
                          controller: ph,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.phone_outlined),
                            labelText: context.tr('auth.phone'),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        TextField(
                          controller: e,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.mail_outline),
                            labelText: context.tr('auth.email'),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        TextField(
                          controller: p,
                          obscureText: _hidePassword,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.lock_outline),
                            labelText: context.tr('auth.password'),
                            hintText: context.tr('auth.passwordHint'),
                            suffixIcon: IconButton(
                              onPressed: () => setState(() => _hidePassword = !_hidePassword),
                              icon: Icon(_hidePassword ? Icons.visibility : Icons.visibility_off),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        TextField(
                          controller: cp,
                          obscureText: _hideConfirmPassword,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _submit(c, s),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.verified_user_outlined),
                            labelText: context.tr('auth.confirmPassword'),
                            suffixIcon: IconButton(
                              onPressed: () => setState(() => _hideConfirmPassword = !_hideConfirmPassword),
                              icon: Icon(_hideConfirmPassword ? Icons.visibility : Icons.visibility_off),
                            ),
                          ),
                        ),
                        if (_registerAttempt && s.error != null && !s.loading) ...[
                          const SizedBox(height: AppSpacing.sm),
                          _LoginErrorBanner(message: mapError(s.error!, L10n.of(c))),
                        ],
                        const SizedBox(height: AppSpacing.md),
                        _GradientAuthButton(
                          loading: s.loading,
                          label: context.tr('auth.register'),
                          onPressed: s.loading ? null : () => _submit(c, s),
                        ),
                      ],
                    ),
                  ),
                  const AuthPreferencesBar(),
                ],
              ),
            );
          },
        ),
      );
}

/// Forgot password: email → recovery code → new password, all in-app.
///
/// Uses Supabase's recovery OTP rather than the emailed link, so the flow needs
/// no deep-link/URL-scheme setup. [AuthRepo.confirmPasswordReset] also accepts a
/// pasted reset link, which keeps this working with the default email template.
class ForgotScreen extends StatelessWidget {
  const ForgotScreen({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => PasswordResetCubit(),
        child: const _ForgotView(),
      );
}

class _ForgotView extends StatefulWidget {
  const _ForgotView();

  @override
  State<_ForgotView> createState() => _ForgotViewState();
}

class _ForgotViewState extends State<_ForgotView> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _hidePassword = true;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _sendCode() {
    FocusScope.of(context).unfocus();
    if (!_email.text.contains('@')) {
      showAppSnack(context, context.tr('auth.errorEmailInvalid'), type: AppSnackType.error);
      return;
    }
    context.read<PasswordResetCubit>().sendCode(_email.text);
  }

  void _confirmReset() {
    FocusScope.of(context).unfocus();
    if (_code.text.trim().isEmpty) {
      showAppSnack(context, context.tr('auth.errorCodeRequired'), type: AppSnackType.error);
      return;
    }
    if (_password.text.length < 8) {
      showAppSnack(context, context.tr('auth.errorPasswordShort'), type: AppSnackType.error);
      return;
    }
    if (_password.text != _confirm.text) {
      showAppSnack(context, context.tr('auth.errorPasswordMismatch'), type: AppSnackType.error);
      return;
    }
    context.read<PasswordResetCubit>().confirm(code: _code.text, newPassword: _password.text);
  }

  Future<void> _resend(BuildContext c) async {
    final ok = await c.read<PasswordResetCubit>().resendCode();
    if (ok && mounted) showAppSnack(context, context.tr('auth.codeSent'), type: AppSnackType.success);
  }

  void _back(BuildContext c) {
    final cubit = c.read<PasswordResetCubit>();
    if (cubit.state.step == ResetStep.enterCode) {
      _code.clear();
      _password.clear();
      _confirm.clear();
      cubit.backToEmail();
      return;
    }
    if (c.canPop()) {
      c.pop();
    } else {
      c.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) => AuthScaffold(
        child: BlocConsumer<PasswordResetCubit, PasswordResetState>(
          listener: (c, s) {
            if (s.error != null) {
              showAppSnack(c, mapError(s.error!, L10n.of(c)), type: AppSnackType.error);
            }
            if (s.step == ResetStep.enterCode && s.error == null && !s.loading) {
              showAppSnack(c, c.tr('auth.codeSent'), type: AppSnackType.success);
            }
            if (s.step == ResetStep.done) {
              showAppSnack(c, c.tr('auth.passwordResetSuccess'), type: AppSnackType.success);
              // verifyOTP opened a session; loading the profile lets the router
              // land the user on their home screen.
              c.read<AuthCubit>().refreshSession();
            }
          },
          listenWhen: (prev, s) => prev.step != s.step || (prev.error != s.error && s.error != null),
          builder: (c, s) {
            final theme = Theme.of(c);
            final muted = theme.colorScheme.onSurface.withValues(alpha: .65);
            final codeStep = s.step == ResetStep.enterCode;
            final doneStep = s.step == ResetStep.done;

            return Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                automaticallyImplyLeading: false,
                leading: doneStep ? null : BackButton(onPressed: () => _back(c)),
                title: Text(c.tr('auth.forgotTitle')),
              ),
              body: ListView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                children: [
                  Icon(
                    doneStep
                        ? Icons.check_circle_outline_rounded
                        : codeStep
                            ? Icons.mark_email_read_outlined
                            : Icons.lock_reset_rounded,
                    size: 56,
                    color: doneStep ? AppColors.success : theme.colorScheme.primary,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    c.tr(doneStep
                        ? 'auth.passwordResetSuccess'
                        : codeStep
                            ? 'auth.enterCodeTitle'
                            : 'auth.forgotSubtitle'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                  ),
                  if (codeStep && s.email != null) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      s.email!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  GlassCard(
                    child: doneStep
                        ? _doneCard(c)
                        : codeStep
                            ? _codeForm(c, s)
                            : _emailForm(c, s),
                  ),
                  if (!doneStep) const AuthPreferencesBar(),
                ],
              ),
            );
          },
        ),
      );

  Widget _emailForm(BuildContext c, PasswordResetState s) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _sendCode(),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.mail_outline),
              labelText: c.tr('auth.email'),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _GradientAuthButton(
            loading: s.loading,
            label: c.tr('auth.sendReset'),
            onPressed: s.loading ? null : _sendCode,
          ),
        ],
      );

  /// The password is already changed here. The session opened by verifyOTP is
  /// valid, so this only waits for the profile load that lets the router move on
  /// — and offers a retry when that load times out instead of silently falling
  /// back to the email form.
  Widget _doneCard(BuildContext c) => BlocBuilder<AuthCubit, AuthState>(
        builder: (c, auth) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (auth.loading)
              Column(
                children: [
                  const SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    c.tr('auth.signingIn'),
                    textAlign: TextAlign.center,
                    style: Theme.of(c).textTheme.bodySmall,
                  ),
                ],
              )
            else
              _GradientAuthButton(
                loading: false,
                label: c.tr('auth.continueToApp'),
                onPressed: () => c.read<AuthCubit>().refreshSession(),
              ),
            const SizedBox(height: AppSpacing.xs),
            TextButton(
              onPressed: () async {
                await c.read<AuthCubit>().logout();
                if (c.mounted) c.go('/login');
              },
              child: Text(c.tr('auth.backToLogin')),
            ),
          ],
        ),
      );

  Widget _codeForm(BuildContext c, PasswordResetState s) {
    final theme = Theme.of(c);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _code,
          // Numeric pad for the emailed code, but still a text field so a pasted
          // reset link works as a fallback.
          keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: false),
          textInputAction: TextInputAction.next,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.pin_outlined),
            labelText: c.tr('auth.resetCode'),
            helperText: c.tr('auth.resetCodeHint'),
            helperMaxLines: 3,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _password,
          obscureText: _hidePassword,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.lock_outline),
            labelText: c.tr('profile.newPassword'),
            hintText: c.tr('auth.passwordHint'),
            suffixIcon: IconButton(
              onPressed: () => setState(() => _hidePassword = !_hidePassword),
              icon: Icon(_hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _confirm,
          obscureText: _hidePassword,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _confirmReset(),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.verified_user_outlined),
            labelText: c.tr('auth.confirmPassword'),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _GradientAuthButton(
          loading: s.loading,
          label: c.tr('auth.setNewPassword'),
          onPressed: s.loading ? null : _confirmReset,
        ),
        const SizedBox(height: AppSpacing.xs),
        TextButton(
          onPressed: s.loading ? null : () => _resend(c),
          child: Text(
            c.tr('auth.resendCode'),
            style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(context.tr('passenger.settings')),
          leading: const BackButton(),
        ),

        body: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            GlassCard(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.language),
                    title: Text(context.tr('passenger.language')),
                    onTap: () => context.read<SettingsCubit>().toggleLocale(),
                  ),
                  ListTile(
                    leading: const Icon(Icons.dark_mode),
                    title: Text(context.tr('passenger.theme')),
                    onTap: () => context.read<SettingsCubit>().toggleTheme(),
                  ),
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: Text(context.tr('passenger.logout')),
                    onTap: () => context.read<AuthCubit>().logout(),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}
