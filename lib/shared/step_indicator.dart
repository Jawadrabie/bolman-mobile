import 'package:flutter/material.dart';

import '../app/theme.dart';

class BookingStepIndicator extends StatelessWidget {
  final int currentStep;
  final List<String> labels;

  const BookingStepIndicator({
    super.key,
    required this.currentStep,
    required this.labels,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, AppSpacing.md),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: theme.dividerColor.withValues(alpha: .6)),
      ),
      child: Row(
        children: List.generate(labels.length, (index) {
          final done = index <= currentStep;
          final isLast = index == labels.length - 1;
          return Expanded(
            child: Row(
              children: [
                Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 240),
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: done ? AppColors.primary : theme.colorScheme.surfaceContainerHighest,
                      ),
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: done ? Colors.white : theme.colorScheme.onSurface.withValues(alpha: .7),
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      labels[index],
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: done ? AppColors.primary : theme.colorScheme.onSurface.withValues(alpha: .65),
                        fontWeight: done ? FontWeight.w700 : FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      height: 2,
                      color: index < currentStep ? AppColors.primary : theme.dividerColor.withValues(alpha: .6),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
