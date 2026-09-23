import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/models.dart';

/// Profile picture with an initial-letter fallback. Used in the profile screen,
/// the edit form, and the home app bar so the avatar looks the same everywhere.
class UserAvatar extends StatelessWidget {
  final Profile? profile;
  final double size;
  final VoidCallback? onTap;

  /// Draws a gradient ring around the image — used on the larger avatars.
  final bool showRing;

  const UserAvatar({
    super.key,
    required this.profile,
    this.size = 44,
    this.onTap,
    this.showRing = false,
  });

  /// Ring thickness when [showRing] is set.
  static const _ring = 3.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inner = showRing ? size - _ring * 2 : size;

    // ClipOval, not a circular Container + clipBehavior: the container's clip
    // path spans the full box, so a square child smaller than that box only
    // loses its corners and still shows flat edges.
    Widget face = ClipOval(
      child: SizedBox(
        width: inner,
        height: inner,
        child: ColoredBox(
          color: theme.colorScheme.primary.withValues(alpha: .14),
          child: profile != null && profile!.hasAvatar
              ? CachedNetworkImage(
                  imageUrl: profile!.avatarUrl!,
                  fit: BoxFit.cover,
                  width: inner,
                  height: inner,
                  placeholder: (_, __) => _Initial(profile: profile, size: inner),
                  errorWidget: (_, __, ___) => _Initial(profile: profile, size: inner),
                )
              : _Initial(profile: profile, size: inner),
        ),
      ),
    );

    if (showRing) {
      face = Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppGradients.hero,
          boxShadow: AppShadows.subtle(AppColors.primary),
        ),
        child: face,
      );
    }

    if (onTap == null) return face;
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: face,
    );
  }
}

class _Initial extends StatelessWidget {
  final Profile? profile;
  final double size;

  const _Initial({required this.profile, required this.size});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final letter = profile?.initial;
    if (letter == null) {
      return Icon(Icons.person, color: theme.colorScheme.primary, size: size * .5);
    }
    return Center(
      child: Text(
        letter,
        style: TextStyle(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w900,
          fontSize: size * .42,
          height: 1,
        ),
      ),
    );
  }
}
