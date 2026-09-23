import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../app/i18n/l10n.dart';
import '../../app/theme.dart';
import '../../shared/widgets.dart';
import '../cubits.dart';
import 'formatters.dart';

/// Password change for a signed-in user. The current password is re-verified
/// server-side before the new one is accepted.
class ChangePasswordScreen extends StatelessWidget {
  const ChangePasswordScreen({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => ChangePasswordCubit(),
        child: const _ChangePasswordView(),
      );
}

class _ChangePasswordView extends StatefulWidget {
  const _ChangePasswordView();

  @override
  State<_ChangePasswordView> createState() => _ChangePasswordViewState();
}

class _ChangePasswordViewState extends State<_ChangePasswordView> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _hideCurrent = true;
  bool _hideNext = true;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    if (_current.text.isEmpty) {
      showAppSnack(context, context.tr('profile.errorCurrentPasswordRequired'), type: AppSnackType.error);
      return;
    }
    if (_next.text.length < 8) {
      showAppSnack(context, context.tr('auth.errorPasswordShort'), type: AppSnackType.error);
      return;
    }
    if (_next.text != _confirm.text) {
      showAppSnack(context, context.tr('auth.errorPasswordMismatch'), type: AppSnackType.error);
      return;
    }
    if (_next.text == _current.text) {
      showAppSnack(context, context.tr('profile.errorSamePassword'), type: AppSnackType.error);
      return;
    }
    context.read<ChangePasswordCubit>().submit(
          currentPassword: _current.text,
          newPassword: _next.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: .65);

    return BlocConsumer<ChangePasswordCubit, ChangePasswordState>(
      listener: (c, s) {
        if (s.error != null) showAppSnack(c, mapError(s.error!, L10n.of(c)), type: AppSnackType.error);
        if (s.done) {
          showAppSnack(c, c.tr('profile.passwordChanged'), type: AppSnackType.success);
          if (c.canPop()) c.pop();
        }
      },
      builder: (c, s) => Scaffold(
        appBar: AppBar(
          title: Text(c.tr('profile.changePassword')),
          leading: const BackButton(),
        ),
        body: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            Text(
              c.tr('profile.changePasswordHint'),
              style: theme.textTheme.bodyMedium?.copyWith(color: muted),
            ),
            const SizedBox(height: AppSpacing.lg),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _current,
                    obscureText: _hideCurrent,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.lock_outline),
                      labelText: c.tr('profile.currentPassword'),
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _hideCurrent = !_hideCurrent),
                        icon: Icon(_hideCurrent ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _next,
                    obscureText: _hideNext,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.lock_reset_rounded),
                      labelText: c.tr('profile.newPassword'),
                      hintText: c.tr('auth.passwordHint'),
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _hideNext = !_hideNext),
                        icon: Icon(_hideNext ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _confirm,
                    obscureText: _hideNext,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.verified_user_outlined),
                      labelText: c.tr('auth.confirmPassword'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton(
                    onPressed: s.loading ? null : _submit,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    ),
                    child: s.loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                          )
                        : Text(c.tr('profile.savePassword')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
