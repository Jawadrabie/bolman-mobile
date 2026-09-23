import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../app/i18n/l10n.dart';
import '../../app/settings_cubit.dart';
import '../../app/theme.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../shared/widgets.dart';
import '../cubits.dart';
import '../shared/formatters.dart';
import '../shared/trip_tile.dart';
import 'user_avatar.dart';

enum _PastTripsFilter { all, thisMonth, last3Months, thisYear }

class ProfileScreen extends StatelessWidget {
  final bool isDriver;

  const ProfileScreen({super.key, this.isDriver = false});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(context.tr('passenger.profile'))),
        body: BlocBuilder<AuthCubit, AuthState>(
          buildWhen: (prev, next) => prev.loading != next.loading || prev.profile != next.profile,
          builder: (context, auth) {
            if (auth.loading && auth.profile == null) {
              return _ProfileLoadingPlaceholder(isDriver: isDriver);
            }
            return _ProfileBody(isDriver: isDriver, profile: auth.profile);
          },
        ),
      );
}

class _ProfileLoadingPlaceholder extends StatelessWidget {
  final bool isDriver;

  const _ProfileLoadingPlaceholder({required this.isDriver});

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          const ShimmerBlock(height: 72),
          const SizedBox(height: AppSpacing.md),
          const ShimmerBlock(height: 168),
          if (isDriver) ...[
            const SizedBox(height: AppSpacing.lg),
            const ShimmerBlock(height: 20, width: 140),
            const SizedBox(height: AppSpacing.sm),
            ShimmerBlock(height: 36, borderRadius: BorderRadius.circular(20)),
            const SizedBox(height: AppSpacing.sm),
            const ShimmerBlock(height: 130),
            const SizedBox(height: AppSpacing.sm),
            const ShimmerBlock(height: 130),
          ],
        ],
      );
}

class _ProfileBody extends StatelessWidget {
  final bool isDriver;
  final Profile? profile;

  const _ProfileBody({required this.isDriver, this.profile});

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          if (profile != null)
            _ProfileHeaderCard(profile: profile!)
          else
            const ShimmerBlock(height: 128),
          const SizedBox(height: AppSpacing.md),
          GlassCard(
            padding: EdgeInsets.zero,
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
                  leading: const Icon(Icons.lock_reset_rounded),
                  title: Text(context.tr('profile.changePassword')),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/change-password'),
                ),
                ListTile(
                  leading: Icon(Icons.logout, color: Theme.of(context).colorScheme.error),
                  title: Text(
                    context.tr('passenger.logout'),
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                  onTap: () => context.read<AuthCubit>().logout(),
                ),
              ],
            ),
          ),
          if (isDriver) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              context.tr('driver.pastTrips'),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: AppSpacing.sm),
            const _DriverPastTripsSection(),
          ],
        ],
      );
}

class _ProfileHeaderCard extends StatelessWidget {
  final Profile profile;

  const _ProfileHeaderCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: .68);

    return GlassCard(
      child: Row(
        children: [
          UserAvatar(
            profile: profile,
            size: 68,
            showRing: true,
            onTap: () => context.push('/profile/edit'),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.fullName,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if ((profile.email ?? '').isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    profile.email!,
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if ((profile.phone ?? '').isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    profile.phone!,
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    maxLines: 1,
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: context.tr('profile.editTitle'),
            onPressed: () => context.push('/profile/edit'),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
    );
  }
}

class _DriverPastTripsSection extends StatefulWidget {
  const _DriverPastTripsSection();

  @override
  State<_DriverPastTripsSection> createState() => _DriverPastTripsSectionState();
}

class _DriverPastTripsSectionState extends State<_DriverPastTripsSection> {
  final _repo = DriverRepo();
  _PastTripsFilter _filter = _PastTripsFilter.all;
  bool _loading = true;
  String? _error;
  List<Trip> _trips = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  (DateTime?, DateTime?) _dateRange() {
    final now = DateTime.now();
    switch (_filter) {
      case _PastTripsFilter.all:
        return (null, null);
      case _PastTripsFilter.thisMonth:
        return (DateTime(now.year, now.month, 1), null);
      case _PastTripsFilter.last3Months:
        return (DateTime(now.year, now.month - 2, 1), null);
      case _PastTripsFilter.thisYear:
        return (DateTime(now.year, 1, 1), null);
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final (from, to) = _dateRange();
      final trips = await _repo.pastTrips(from: from, to: to);
      if (!mounted) return;
      setState(() {
        _trips = trips;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = mapError(e, L10n.of(context));
        _loading = false;
      });
    }
  }

  void _setFilter(_PastTripsFilter f) {
    if (_filter == f) return;
    setState(() => _filter = f);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _FilterChip(
                label: context.tr('driver.filterAll'),
                selected: _filter == _PastTripsFilter.all,
                onTap: () => _setFilter(_PastTripsFilter.all),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: context.tr('driver.filterThisMonth'),
                selected: _filter == _PastTripsFilter.thisMonth,
                onTap: () => _setFilter(_PastTripsFilter.thisMonth),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: context.tr('driver.filterLast3Months'),
                selected: _filter == _PastTripsFilter.last3Months,
                onTap: () => _setFilter(_PastTripsFilter.last3Months),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: context.tr('driver.filterThisYear'),
                selected: _filter == _PastTripsFilter.thisYear,
                onTap: () => _setFilter(_PastTripsFilter.thisYear),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (_loading)
          const Column(
            children: [
              ShimmerBlock(height: 130),
              SizedBox(height: AppSpacing.sm),
              ShimmerBlock(height: 130),
            ],
          )
        else if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          )
        else if (_trips.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Text(
              context.tr('common.noData'),
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .55)),
            ),
          )
        else
          Column(
            children: _trips
                .map(
                  (t) => TripTile(
                    t,
                    onTap: () => context.push('/driver/trip', extra: t),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
      );
}
