import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/i18n/l10n.dart';
import '../../app/theme.dart';
import '../../data/models.dart';
import '../../shared/widgets.dart';
import '../cubits.dart';
import 'formatters.dart';
import 'user_avatar.dart';

/// Name / phone / profile picture. Email is read-only because Supabase Auth
/// owns it and changing it needs its own confirmation flow.
class EditProfileScreen extends StatelessWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => ProfileEditCubit(context.read<AuthCubit>()),
        child: const _EditProfileView(),
      );
}

class _EditProfileView extends StatefulWidget {
  const _EditProfileView();

  @override
  State<_EditProfileView> createState() => _EditProfileViewState();
}

class _EditProfileViewState extends State<_EditProfileView> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _picker = ImagePicker();
  bool _hydrated = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _hydrate(Profile? profile) {
    if (_hydrated || profile == null) return;
    _hydrated = true;
    _name.text = profile.fullName;
    _phone.text = profile.phone ?? '';
  }

  bool _dirty(Profile? profile) {
    if (profile == null) return false;
    return _name.text.trim() != profile.fullName.trim() ||
        _phone.text.trim() != (profile.phone ?? '').trim();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (_name.text.trim().length < 2) {
      showAppSnack(context, context.tr('auth.errorNameShort'), type: AppSnackType.error);
      return;
    }
    if (_phone.text.trim().isEmpty) {
      showAppSnack(context, context.tr('profile.errorPhoneRequired'), type: AppSnackType.error);
      return;
    }
    final ok = await context.read<ProfileEditCubit>().save(
          fullName: _name.text,
          phone: _phone.text,
        );
    if (ok && mounted) context.pop();
  }

  Future<void> _pickAvatar(ImageSource source) async {
    final cubit = context.read<ProfileEditCubit>();
    try {
      final file = await _picker.pickImage(
        source: source,
        // Downscaled before upload so the 2MB bucket limit is never the issue.
        maxWidth: 720,
        maxHeight: 720,
        imageQuality: 85,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final name = file.name.isNotEmpty ? file.name : file.path;
      final dot = name.lastIndexOf('.');
      await cubit.uploadAvatar(
        bytes: bytes,
        fileExtension: dot >= 0 ? name.substring(dot + 1) : 'jpg',
      );
    } catch (e) {
      if (mounted) showAppSnack(context, context.tr('profile.errorPickImage'), type: AppSnackType.error);
    }
  }

  Future<void> _openAvatarSheet(Profile? profile) async {
    final cubit = context.read<ProfileEditCubit>();
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(sheet.tr('profile.takePhoto')),
              onTap: () => Navigator.pop(sheet, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(sheet.tr('profile.chooseFromGallery')),
              onTap: () => Navigator.pop(sheet, 'gallery'),
            ),
            if (profile?.hasAvatar ?? false)
              ListTile(
                leading: Icon(Icons.delete_outline, color: Theme.of(sheet).colorScheme.error),
                title: Text(
                  sheet.tr('profile.removePhoto'),
                  style: TextStyle(color: Theme.of(sheet).colorScheme.error),
                ),
                onTap: () => Navigator.pop(sheet, 'remove'),
              ),
            const SizedBox(height: AppSpacing.xs),
          ],
        ),
      ),
    );

    switch (action) {
      case 'camera':
        await _pickAvatar(ImageSource.camera);
      case 'gallery':
        await _pickAvatar(ImageSource.gallery);
      case 'remove':
        await cubit.removeAvatar();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: .65);

    return BlocConsumer<ProfileEditCubit, ProfileEditState>(
      listener: (c, s) {
        if (s.error != null) showAppSnack(c, mapError(s.error!, L10n.of(c)), type: AppSnackType.error);
        if (s.savedMessageKey != null) {
          showAppSnack(c, c.tr(s.savedMessageKey!), type: AppSnackType.success);
        }
      },
      builder: (c, edit) => BlocBuilder<AuthCubit, AuthState>(
        buildWhen: (prev, next) => prev.profile != next.profile,
        builder: (c, auth) {
          final profile = auth.profile;
          _hydrate(profile);

          return Scaffold(
            appBar: AppBar(
              title: Text(c.tr('profile.editTitle')),
              leading: const BackButton(),
            ),
            body: profile == null
                ? const _EditProfileSkeleton()
                : ListView(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    children: [
                      Center(
                        child: Column(
                          children: [
                            Stack(
                              alignment: AlignmentDirectional.bottomEnd,
                              children: [
                                UserAvatar(profile: profile, size: 116, showRing: true),
                                if (edit.uploadingAvatar)
                                  const Positioned.fill(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Color(0x66000000),
                                      ),
                                      child: Center(
                                        child: SizedBox(
                                          width: 26,
                                          height: 26,
                                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  Material(
                                    color: theme.colorScheme.primary,
                                    shape: const CircleBorder(),
                                    elevation: 2,
                                    child: InkWell(
                                      customBorder: const CircleBorder(),
                                      onTap: () => _openAvatarSheet(profile),
                                      child: const Padding(
                                        padding: EdgeInsets.all(AppSpacing.xs),
                                        child: Icon(Icons.photo_camera_rounded, color: Colors.white, size: 20),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            TextButton.icon(
                              onPressed: edit.busy ? null : () => _openAvatarSheet(profile),
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              label: Text(c.tr('profile.changePhoto')),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: _name,
                              textInputAction: TextInputAction.next,
                              textCapitalization: TextCapitalization.words,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.person_outline),
                                labelText: c.tr('auth.fullName'),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            TextField(
                              controller: _phone,
                              keyboardType: TextInputType.phone,
                              textInputAction: TextInputAction.done,
                              onChanged: (_) => setState(() {}),
                              onSubmitted: (_) => _save(),
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.phone_outlined),
                                labelText: c.tr('auth.phone'),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            TextFormField(
                              enabled: false,
                              initialValue: profile.email ?? '—',
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.mail_outline),
                                labelText: c.tr('auth.email'),
                                helperText: c.tr('profile.emailLocked'),
                                helperMaxLines: 2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      GlassCard(
                        padding: EdgeInsets.zero,
                        child: ListTile(
                          leading: const Icon(Icons.lock_reset_rounded),
                          title: Text(c.tr('profile.changePassword')),
                          subtitle: Text(
                            c.tr('profile.changePasswordHint'),
                            style: theme.textTheme.bodySmall?.copyWith(color: muted),
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => c.push('/change-password'),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      FilledButton.icon(
                        onPressed: edit.busy || !_dirty(profile) ? null : _save,
                        icon: edit.saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                              )
                            : const Icon(Icons.check_rounded),
                        label: Text(c.tr('common.save')),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                        ),
                      ),
                    ],
                  ),
          );
        },
      ),
    );
  }
}

class _EditProfileSkeleton extends StatelessWidget {
  const _EditProfileSkeleton();

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          Center(child: ShimmerBlock(height: 116, width: 116, borderRadius: BorderRadius.circular(58))),
          const SizedBox(height: AppSpacing.lg),
          const ShimmerBlock(height: 210),
          const SizedBox(height: AppSpacing.md),
          const ShimmerBlock(height: 72),
        ],
      );
}
