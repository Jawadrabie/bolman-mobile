import 'package:flutter/material.dart';

import '../../app/i18n/l10n.dart';
import '../../app/theme.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import 'formatters.dart';

/// Asks the passenger to pay an unpaid booking before it can be modified.
///
/// Returns `true` when they choose to pay, `false` when they decline or dismiss
/// the dialog. The payment itself is performed by the caller so that loading and
/// error handling stay with the owning cubit.
Future<bool> showPayPendingDialog(BuildContext context, double amount) async {
  final paid = await showDialog<bool>(
    context: context,
    builder: (ctx) => _PayPendingDialog(amount: amount),
  );
  return paid ?? false;
}

class _PayPendingDialog extends StatelessWidget {
  final double amount;

  const _PayPendingDialog({required this.amount});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Icon(Icons.account_balance_wallet_outlined, size: 20, color: AppColors.warning),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.t('booking.payFirstTitle'),
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
          ),
        ],
      ),
      content: FutureBuilder<Wallet?>(
        future: WalletRepo().wallet(),
        builder: (c, snap) {
          final loading = snap.connectionState == ConnectionState.waiting;
          final balance = snap.data?.balance;
          final enough = balance != null && balance >= amount;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.t('booking.payFirstBody'), style: const TextStyle(height: 1.5)),
              const SizedBox(height: AppSpacing.md),
              _AmountRow(
                label: l10n.t('booking.payFirstAmount'),
                value: formatMoney(amount, l10n),
                emphasis: true,
              ),
              const SizedBox(height: AppSpacing.xs),
              _AmountRow(
                label: l10n.t('booking.payFirstBalance'),
                value: loading ? '—' : formatMoney(balance ?? 0, l10n),
                danger: !loading && !enough,
              ),
              if (!loading && !enough) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.t('booking.payFirstInsufficient'),
                  style: const TextStyle(color: AppColors.danger, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: Text(l10n.t('booking.payFirstDecline')),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: loading || !enough ? null : () => Navigator.pop(c, true),
                      child: Text(l10n.t('booking.payFirstConfirm')),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasis;
  final bool danger;

  const _AmountRow({
    required this.label,
    required this.value,
    this.emphasis = false,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger
        ? AppColors.danger
        : emphasis
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurface;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .7),
          ),
        ),
        Text(
          value,
          style: TextStyle(fontSize: emphasis ? 17 : 15, fontWeight: FontWeight.w900, color: color),
        ),
      ],
    );
  }
}
