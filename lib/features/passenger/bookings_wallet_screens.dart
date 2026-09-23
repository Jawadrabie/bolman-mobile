import 'package:flutter/material.dart' hide Badge;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/i18n/l10n.dart';
import '../../app/theme.dart';
import '../../data/models.dart';
import '../../shared/widgets.dart';
import '../cubits.dart';
import '../shared/booking_card.dart';
import '../shared/formatters.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

enum BookingsPeriod { all, past, current, future }

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

List<BookingSummary> _filterByPeriod(List<BookingSummary> items, BookingsPeriod period) {
  if (period == BookingsPeriod.all) return items;
  final now = DateTime.now();
  return items.where((e) {
    final departure = e.trip?.departure;
    if (departure == null) return period == BookingsPeriod.current;
    switch (period) {
      case BookingsPeriod.past:
        return departure.isBefore(now) && !_isSameDay(departure, now);
      case BookingsPeriod.current:
        return _isSameDay(departure, now);
      case BookingsPeriod.future:
        return departure.isAfter(now) && !_isSameDay(departure, now);
      case BookingsPeriod.all:
        return true;
    }
  }).toList();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  BookingsPeriod _period = BookingsPeriod.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<BookingsCubit>().load();
    });
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 4,
        child: Scaffold(
            appBar: AppBar(
              title: Text(context.tr('passenger.myBookings')),
              bottom: TabBar(
                isScrollable: true,
                tabs: [
                  Tab(text: context.tr('passenger.filterAll')),
                  Tab(text: context.tr('passenger.filterActive')),
                  Tab(text: context.tr('passenger.filterCompleted')),
                  Tab(text: context.tr('passenger.filterCancelled')),
                ],
              ),
            ),
            body: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _PeriodChip(
                          label: context.tr('passenger.periodAll'),
                          selected: _period == BookingsPeriod.all,
                          onTap: () => setState(() => _period = BookingsPeriod.all),
                        ),
                        const SizedBox(width: 8),
                        _PeriodChip(
                          label: context.tr('passenger.periodPast'),
                          selected: _period == BookingsPeriod.past,
                          onTap: () => setState(() => _period = BookingsPeriod.past),
                        ),
                        const SizedBox(width: 8),
                        _PeriodChip(
                          label: context.tr('passenger.periodCurrent'),
                          selected: _period == BookingsPeriod.current,
                          onTap: () => setState(() => _period = BookingsPeriod.current),
                        ),
                        const SizedBox(width: 8),
                        _PeriodChip(
                          label: context.tr('passenger.periodFuture'),
                          selected: _period == BookingsPeriod.future,
                          onTap: () => setState(() => _period = BookingsPeriod.future),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: BlocBuilder<BookingsCubit, BookingsState>(
                    builder: (c, s) {
                      final items = _filterByPeriod(s.items, _period);
                      return RefreshIndicator(
                        onRefresh: () => c.read<BookingsCubit>().load(),
                        child: StateBox(
                          loading: s.loading,
                          error: s.error != null ? mapError(s.error!, L10n.of(c)) : null,
                          empty: items.isEmpty,
                          assetName: 'assets/images/empty_trips.svg',
                          child: TabBarView(
                            children: [
                              _BookingsList(items: items),
                              _BookingsList(
                                items: items.where((e) => isActiveBookingStatus(e.status)).toList(),
                                emptyMessage: context.tr('passenger.noActiveBookings'),
                              ),
                              _BookingsList(
                                items: items.where((e) => e.status == 'completed').toList(),
                                emptyMessage: context.tr('passenger.noCompletedBookings'),
                              ),
                              _BookingsList(
                                items: items.where((e) => e.status == 'cancelled').toList(),
                                emptyMessage: context.tr('passenger.noCancelledBookings'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
      );
}

class _PeriodChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PeriodChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
      );
}

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
          appBar: AppBar(title: Text(context.tr('passenger.myWallet'))),
          body: BlocBuilder<WalletCubit, WalletState>(
            builder: (c, s) => RefreshIndicator(
              onRefresh: () => c.read<WalletCubit>().load(),
              child: StateBox(
                loading: s.loading,
                error: s.error != null ? mapError(s.error!, L10n.of(c)) : null,
                assetName: 'assets/images/empty_wallet.svg',
                child: ListView(
                  padding: const EdgeInsets.all(18),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        gradient: AppGradients.wallet,
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                        boxShadow: AppShadows.medium(AppColors.primary),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.tr('passenger.balance'), style: TextStyle(color: Colors.white.withValues(alpha: .75))),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            formatMoney(s.wallet?.balance ?? 0, c.l10n),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 26),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _WalletSummary(txs: s.txs),
                    const SizedBox(height: 12),
                    _WalletGroupedTransactions(grouped: _groupTransactions(s.txs)),
                  ],
                ),
              ),
            ),
          ),
      );
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // The cubit is app-wide and loads once at start, so resync every time the
    // page opens instead of showing whatever was cached then.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<NotificationsCubit>().load();
    });
  }

  IconData _typeIcon(String type) {
    if (type.contains('booking')) return Icons.confirmation_num_outlined;
    if (type.contains('wallet') || type.contains('payment')) return Icons.account_balance_wallet_outlined;
    if (type.contains('offer')) return Icons.local_offer_outlined;
    return Icons.notifications_outlined;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
          appBar: AppBar(
            title: Text(context.tr('passenger.notificationsTitle')),
            leading: const BackButton(),
          ),
          body: BlocBuilder<NotificationsCubit, NotificationsState>(
            builder: (c, s) {
              final items = s.items;
              return RefreshIndicator(
              onRefresh: () => c.read<NotificationsCubit>().load(),
              child: items.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(c).size.height * 0.4,
                          // A failed query used to render as "no notifications";
                          // show why instead so it is not mistaken for empty.
                          child: StateBox(
                            loading: s.loading,
                            empty: s.error == null,
                            error: s.error,
                            assetName: 'assets/images/empty_notifications.svg',
                            child: const SizedBox.shrink(),
                          ),
                        ),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.all(18),
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: items
                          .map(
                            (n) => Dismissible(
                              key: ValueKey(n.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(AppRadius.lg),
                                  color: AppColors.danger,
                                ),
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                                child: const Icon(Icons.delete_outline, color: Colors.white),
                              ),
                              onDismissed: (_) => c.read<NotificationsCubit>().read(n.id),
                              child: AppCard(
                                onTap: () => c.read<NotificationsCubit>().read(n.id),
                                child: ListTile(
                                  leading: Icon(_typeIcon(n.type), color: Theme.of(c).colorScheme.primary),
                                  title: Text(
                                    n.title,
                                    style: TextStyle(fontWeight: n.read ? FontWeight.w600 : FontWeight.w900),
                                  ),
                                  subtitle: Text(n.message),
                                  trailing: n.read
                                      ? null
                                      : Badge(text: c.tr('passenger.notificationsUnread'), color: AppColors.primary),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
            );
            },
          ),
      );
}

class _BookingsList extends StatelessWidget {
  final List<BookingSummary> items;
  final String? emptyMessage;

  const _BookingsList({required this.items, this.emptyMessage});

  List<BookingSummary> get _oldestFirst => [...items]..sort(
      (a, b) => (a.trip?.departure ?? a.createdAt).compareTo(b.trip?.departure ?? b.createdAt),
    );

  @override
  Widget build(BuildContext context) {
    final sorted = _oldestFirst;
    if (sorted.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.42,
            child: StateBox(
              loading: false,
              empty: true,
              emptyMessage: emptyMessage ?? context.tr('common.noData'),
              assetName: 'assets/images/empty_trips.svg',
              child: const SizedBox.shrink(),
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xl),
      physics: const AlwaysScrollableScrollPhysics(),
      children: sorted
          .map(
            (b) => BookingCard(
              booking: b,
              onRate: b.status == 'completed' && b.rating == null
                  ? () async {
                      final stars = await pickRating(context);
                      if (stars != null && context.mounted) {
                        await context.read<BookingsCubit>().rate(b.id, stars);
                      }
                    }
                  : null,
            ),
          )
          .toList(),
    );
  }
}

class _WalletSummary extends StatelessWidget {
  final List<WalletTx> txs;

  const _WalletSummary({required this.txs});

  @override
  Widget build(BuildContext context) {
    final income = txs.where((e) => e.type == 'credit').fold<double>(0, (p, c) => p + c.amount);
    final expense = txs.where((e) => e.type != 'credit').fold<double>(0, (p, c) => p + c.amount);
    return Row(
      children: [
        Expanded(
          child: AppCard(
            child: Column(
              children: [
                Text(context.tr('passenger.walletIncome')),
                const SizedBox(height: AppSpacing.xs),
                Text(formatMoney(income, context.l10n), style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.success)),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: AppCard(
            child: Column(
              children: [
                Text(context.tr('passenger.walletExpense')),
                const SizedBox(height: AppSpacing.xs),
                Text(formatMoney(expense, context.l10n), style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.danger)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

Map<String, List<WalletTx>> _groupTransactions(List<WalletTx> txs) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final weekStart = today.subtract(Duration(days: today.weekday - 1));
  final map = <String, List<WalletTx>>{
    'today': [],
    'yesterday': [],
    'week': [],
    'earlier': [],
  };
  for (final tx in txs) {
    final d = DateTime(tx.createdAt.year, tx.createdAt.month, tx.createdAt.day);
    if (d == today) {
      map['today']!.add(tx);
    } else if (d == yesterday) {
      map['yesterday']!.add(tx);
    } else if (d.isAfter(weekStart.subtract(const Duration(days: 1)))) {
      map['week']!.add(tx);
    } else {
      map['earlier']!.add(tx);
    }
  }
  return {
    for (final entry in map.entries)
      if (entry.value.isNotEmpty) entry.key: entry.value,
  };
}

String _groupLabel(BuildContext context, String key) {
  switch (key) {
    case 'today':
      return context.tr('passenger.txToday');
    case 'yesterday':
      return context.tr('passenger.txYesterday');
    case 'week':
      return context.tr('passenger.txThisWeek');
    default:
      return context.tr('passenger.txEarlier');
  }
}

class _WalletGroupedTransactions extends StatelessWidget {
  final Map<String, List<WalletTx>> grouped;

  const _WalletGroupedTransactions({required this.grouped});

  @override
  Widget build(BuildContext context) => Column(
        children: grouped.entries
            .map(
              (entry) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                    child: Text(_groupLabel(context, entry.key), style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
                  ...entry.value.map(
                    (x) => AppCard(
                      child: ListTile(
                        leading: Icon(
                          x.type == 'credit' ? Icons.add_circle : Icons.remove_circle,
                          color: x.type == 'credit' ? AppColors.success : Colors.red,
                        ),
                        title: Text(x.source),
                        subtitle: Text(formatDateTime(x.createdAt, context.l10n.languageCode)),
                        trailing: Text(formatMoney(x.amount, context.l10n)),
                      ),
                    ),
                  ),
                ],
              ),
            )
            .toList(),
      );
}
