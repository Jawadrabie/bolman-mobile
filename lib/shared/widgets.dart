import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shimmer/shimmer.dart';

import '../app/i18n/l10n.dart';
import '../app/settings_cubit.dart';
import '../app/theme.dart';
import '../features/cubits.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  const AppCard({super.key, required this.child, this.onTap, this.padding = const EdgeInsets.all(18)});

  @override
  Widget build(BuildContext context) {
    final card = Card(child: Padding(padding: padding, child: child));
    return onTap == null
        ? card
        : InkWell(borderRadius: BorderRadius.circular(24), onTap: onTap, child: card);
  }
}

class Header extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;

  const Header({super.key, required this.title, required this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          gradient: AppGradients.hero,
          boxShadow: AppShadows.subtle(AppColors.primary),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22)),
                  const SizedBox(height: 6),
                  Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: .82))),
                ],
              ),
            ),
            trailing ?? const Icon(Icons.directions_bus_rounded, color: Colors.white, size: 42),
          ],
        ),
      );
}

class Badge extends StatelessWidget {
  final String text;
  final Color color;

  const Badge({super.key, required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(AppRadius.pill)),
        child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
      );
}

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge(this.status, {super.key});

  @override
  Widget build(BuildContext context) => Badge(text: context.trStatus(status), color: AppColors.primary);
}

class StateBox extends StatelessWidget {
  final bool loading;
  final bool empty;
  final String? error;
  final Widget child;
  final String? emptyMessage;
  final String? emptyTitle;
  final String? assetName;
  final Widget? emptyActions;

  const StateBox({
    super.key,
    required this.loading,
    this.empty = false,
    this.error,
    required this.child,
    this.emptyMessage,
    this.emptyTitle,
    this.assetName,
    this.emptyActions,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) return const _LoadingPlaceholder();
    if (error != null) {
      return _StateMessage(
        icon: Icons.error_outline_rounded,
        title: context.tr('common.errorTitle'),
        message: error!,
        color: Theme.of(context).colorScheme.error,
        assetName: assetName,
      );
    }
    if (empty) {
      return _StateMessage(
        icon: Icons.inbox_outlined,
        title: emptyTitle ?? context.tr('common.emptyTitle'),
        message: emptyMessage ?? context.tr('common.noData'),
        color: Theme.of(context).colorScheme.primary,
        assetName: assetName,
        actions: emptyActions,
      );
    }
    return child;
  }
}

class _LoadingPlaceholder extends StatelessWidget {
  const _LoadingPlaceholder();

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: const [
          ShimmerBlock(height: 110),
          SizedBox(height: AppSpacing.md),
          ShimmerBlock(height: 90),
          SizedBox(height: AppSpacing.md),
          ShimmerBlock(height: 90),
        ],
      );
}

class _StateMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Color color;
  final String? assetName;
  final Widget? actions;

  const _StateMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.color,
    this.assetName,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final hasAsset = assetName != null && assetName!.trim().isNotEmpty;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasAsset)
              SizedBox(
                height: 110,
                width: 110,
                child: SvgPicture.asset(assetName!),
              )
            else
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 32),
              ),
            const SizedBox(height: AppSpacing.md),
            Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .75),
                  ),
            ),
            if (actions != null) ...[
              const SizedBox(height: AppSpacing.lg),
              actions!,
            ],
          ],
        ),
      ),
    );
  }
}

class AuthScaffold extends StatelessWidget {
  final Widget child;

  const AuthScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topLeft,
            radius: 1.2,
            colors: [
              dark ? AppColors.primary.withValues(alpha: .25) : AppColors.accent.withValues(alpha: .25),
              Colors.transparent,
            ],
            stops: const [0.0, 0.28],
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: dark
                  ? [AppColors.darkBg, AppColors.darkCard]
                  : [AppColors.lightBg, AppColors.lightTint],
            ),
          ),
          child: SafeArea(child: child),
        ),
      ),
    );
  }
}

class AuthPreferencesBar extends StatelessWidget {
  const AuthPreferencesBar({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: .55);

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextButton.icon(
            onPressed: () => context.read<SettingsCubit>().toggleLocale(),
            icon: Icon(Icons.translate_rounded, size: 18, color: muted),
            label: Text(
              context.l10n.languageCode == 'ar' ? 'English' : 'العربية',
              style: TextStyle(color: muted, fontWeight: FontWeight.w600),
            ),
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
          ),
          Container(
            width: 1,
            height: 18,
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            color: muted.withValues(alpha: .35),
          ),
          TextButton.icon(
            onPressed: () => context.read<SettingsCubit>().toggleTheme(),
            icon: Icon(
              dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              size: 18,
              color: muted,
            ),
            label: Text(
              context.tr('passenger.theme'),
              style: TextStyle(color: muted, fontWeight: FontWeight.w600),
            ),
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
          ),
        ],
      ),
    );
  }
}

class SeatLegend extends StatelessWidget {
  const SeatLegend({super.key});

  @override
  Widget build(BuildContext context) {
    Widget item(Color bg, String label, {Color? border, Color? icon}) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 18,
                height: 18,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(5),
                  border: border != null ? Border.all(color: border, width: 1) : null,
                ),
                child: Icon(Icons.event_seat_rounded, size: 12, color: icon ?? border ?? bg),
              ),
              const SizedBox(width: 4),
              Text(label, style: const TextStyle(fontSize: 11)),
            ],
          ),
        );
    return Wrap(
      alignment: WrapAlignment.center,
      children: [
        item(AppColors.seatAvailable, context.tr('seatMap.available'), border: AppColors.seatAvailableText, icon: AppColors.seatAvailableText),
        item(AppColors.primary, context.tr('seatMap.selected'), icon: Colors.white),
        item(AppColors.seatReserved, context.tr('seatMap.reserved'), border: AppColors.seatReservedText, icon: AppColors.seatReservedText),
        item(AppColors.seatLocked, context.tr('seatMap.locked'), border: AppColors.seatLockedText, icon: AppColors.seatLockedText),
        item(AppColors.seatInactive, context.tr('seatMap.inactive'), icon: AppColors.seatInactive),
      ],
    );
  }
}

class ShimmerBlock extends StatelessWidget {
  final double height;
  final double? width;
  final BorderRadius? borderRadius;
  final EdgeInsets margin;

  const ShimmerBlock({
    super.key,
    required this.height,
    this.width,
    this.borderRadius,
    this.margin = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = dark ? AppColors.shimmerBaseDark : AppColors.shimmerBaseLight;
    final highlight = dark ? AppColors.shimmerHighlightDark : AppColors.shimmerHighlightLight;
    return Container(
      margin: margin,
      child: Shimmer.fromColors(
        baseColor: base,
        highlightColor: highlight,
        child: Container(
          height: height,
          width: width,
          decoration: BoxDecoration(
            color: base,
            borderRadius: borderRadius ?? BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
    );
  }
}

class AnimatedListItem extends StatelessWidget {
  final Widget child;
  final int index;
  final EdgeInsetsGeometry? padding;

  const AnimatedListItem({
    super.key,
    required this.child,
    required this.index,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final content = padding != null ? Padding(padding: padding!, child: child) : child;
    return AnimationConfiguration.staggeredList(
      position: index,
      duration: const Duration(milliseconds: 360),
      child: SlideAnimation(
        verticalOffset: 26,
        child: FadeInAnimation(child: content),
      ),
    );
  }
}

class AnimatedAppCard extends StatelessWidget {
  final Widget child;
  final int index;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  const AnimatedAppCard({
    super.key,
    required this.child,
    required this.index,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
  });

  @override
  Widget build(BuildContext context) => AnimationConfiguration.staggeredList(
        position: index,
        duration: const Duration(milliseconds: 360),
        child: SlideAnimation(
          verticalOffset: 26,
          child: FadeInAnimation(
            child: AppCard(
              padding: padding,
              onTap: onTap,
              child: child,
            ),
          ),
        ),
      );
}

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(AppRadius.lg);
    final content = Padding(padding: padding, child: child);

    // A Material, not a coloured Container: ListTile (and any InkWell) paints its
    // background and ink splash onto the nearest Material ancestor, so a coloured
    // box in between hides those effects entirely.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: AppShadows.subtle(AppColors.primary),
      ),
      child: Material(
        color: dark ? Colors.white.withValues(alpha: .06) : Colors.white.withValues(alpha: .7),
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: Colors.white.withValues(alpha: dark ? .18 : .7)),
        ),
        child: onTap == null ? content : InkWell(borderRadius: radius, onTap: onTap, child: content),
      ),
    );
  }
}

enum AppSnackType { success, error, info }

void showAppSnack(BuildContext context, String message, {AppSnackType type = AppSnackType.info}) {
  final color = switch (type) {
    AppSnackType.success => AppColors.success,
    AppSnackType.error => AppColors.danger,
    AppSnackType.info => AppColors.info,
  };
  final icon = switch (type) {
    AppSnackType.success => Icons.check_circle_rounded,
    AppSnackType.error => Icons.error_rounded,
    AppSnackType.info => Icons.info_rounded,
  };
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: color,
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(message, style: const TextStyle(color: Colors.white))),
          ],
        ),
      ),
    );
}

class NotificationsAppBarButton extends StatelessWidget {
  final VoidCallback onPressed;

  const NotificationsAppBarButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) => BlocBuilder<NotificationsCubit, NotificationsState>(
        builder: (c, s) {
          final unread = s.unread;
          return Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                onPressed: onPressed,
                icon: const Icon(Icons.notifications_outlined),
              ),
              if (unread > 0)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    width: 18,
                    height: 18,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.danger,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      unread > 9 ? '9+' : '$unread',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
            ],
          );
        },
      );
}
