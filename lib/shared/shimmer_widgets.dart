import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../app/theme.dart';

class ScreenShimmerList extends StatelessWidget {
  final int count;
  final EdgeInsets padding;

  const ScreenShimmerList({
    super.key,
    this.count = 4,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
  });

  @override
  Widget build(BuildContext context) => ListView.separated(
        padding: padding,
        itemBuilder: (_, __) => const ShimmerCard(),
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
        itemCount: count,
      );
}

class ShimmerCard extends StatelessWidget {
  final double height;

  const ShimmerCard({super.key, this.height = 96});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = dark ? AppColors.shimmerBaseDark : AppColors.shimmerBaseLight;
    final highlight = dark ? AppColors.shimmerHighlightDark : AppColors.shimmerHighlightLight;
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
    );
  }
}
