import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:go_router/go_router.dart';

import '../../app/i18n/l10n.dart';
import '../../app/theme.dart';
import '../../data/models.dart';
import '../../shared/animations/safer_animations.dart';
import '../../shared/city_visual.dart';
import '../../shared/city_picker.dart';
import '../../shared/widgets.dart';
import '../cubits.dart';
import '../shared/formatters.dart';
import '../shared/trip_tile.dart';
import '../shared/user_avatar.dart';

const _upcomingHomePreview = 8;

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => const _Home();
}

class _Home extends StatefulWidget {
  const _Home();

  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> {
  City? from, to;
  DateTime date = DateTime.now().add(const Duration(days: 1));
  bool _hydratedFromCubit = false;

  City? _cityById(List<City> cities, String? id) {
    if (id == null) return null;
    for (final city in cities) {
      if (city.id == id) return city;
    }
    return null;
  }

  void _hydrateFromSearchCubit(SearchState s) {
    if (_hydratedFromCubit || !s.hasLastSearch || s.cities.isEmpty) return;
    final fromCity = _cityById(s.cities, s.lastFromId);
    final toCity = _cityById(s.cities, s.lastToId);
    if (fromCity == null || toCity == null) return;
    _hydratedFromCubit = true;
    setState(() {
      from = fromCity;
      to = toCity;
      date = s.lastTravelDate!;
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _hydrateFromSearchCubit(context.read<SearchCubit>().state);
    });
  }

  int? _activeQuickDateMode() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = DateTime(date.year, date.month, date.day);
    if (selected == today) return 0;
    if (selected == today.add(const Duration(days: 1))) return 1;
    final weekday = now.weekday;
    final daysToWeekend = weekday >= DateTime.friday ? 0 : DateTime.friday - weekday;
    if (selected == today.add(Duration(days: daysToWeekend))) return 2;
    return null;
  }

  Future<void> _quickDate(BuildContext context, int mode) async {
    final now = DateTime.now();
    if (mode == 0) {
      setState(() => date = DateTime(now.year, now.month, now.day));
      return;
    }
    if (mode == 1) {
      setState(() => date = DateTime(now.year, now.month, now.day).add(const Duration(days: 1)));
      return;
    }
    final weekday = now.weekday;
    final daysToWeekend = weekday >= DateTime.friday ? 0 : DateTime.friday - weekday;
    setState(() => date = DateTime(now.year, now.month, now.day).add(Duration(days: daysToWeekend)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          centerTitle: false,
          leadingWidth: 60,
          leading: BlocBuilder<AuthCubit, AuthState>(
            buildWhen: (prev, next) => prev.profile != next.profile,
            // Center, not just Padding: AppBar.leading is given a *tight* height
            // equal to the whole toolbar (see NavigationToolbar), and a tight
            // constraint stretches a fixed-size SizedBox to fill it — squashing
            // the avatar into an oval. Center loosens that constraint first.
            builder: (context, auth) => Center(
              child: Padding(
                padding: const EdgeInsetsDirectional.only(start: AppSpacing.md),
                child: UserAvatar(
                  profile: auth.profile,
                  size: 38,
                  onTap: () => context.go('/profile'),
                ),
              ),
            ),
          ),
          title: BlocBuilder<AuthCubit, AuthState>(
            builder: (context, auth) {
              final name = auth.profile?.fullName.trim();
              final theme = Theme.of(context);
              if (name == null || name.isEmpty) {
                return Text(context.tr('passenger.welcome'));
              }
              return Text.rich(
                TextSpan(
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  children: [
                    TextSpan(text: '${context.tr('passenger.welcome')} '),
                    TextSpan(
                      text: name,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              );
            },
          ),
          actions: [
            NotificationsAppBarButton(onPressed: () => context.push('/notifications')),
          ],
        ),
        body: BlocConsumer<SearchCubit, SearchState>(
          listenWhen: (prev, next) => !_hydratedFromCubit && next.hasLastSearch && next.cities.isNotEmpty,
          listener: (c, s) => _hydrateFromSearchCubit(s),
          builder: (c, s) => StateBox(
            loading: s.loading && s.cities.isEmpty,
            error: s.error != null ? mapError(s.error!, L10n.of(c)) : null,
            child: RefreshIndicator(
              onRefresh: () => c.read<SearchCubit>().init(),
              child: AnimationLimiter(
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    AnimatedAppCard(
                      index: 0,
                      padding: EdgeInsets.zero,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          HomeHeroBanner(
                            title: c.tr('passenger.heroTitle'),
                            typewriterPhrases: [
                              c.tr('passenger.heroPhrase1'),
                              c.tr('passenger.heroPhrase2'),
                              c.tr('passenger.heroPhrase3'),
                            ],
                            marqueeItems: s.cities.map((city) => city.name).take(18).toList(),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: _SearchForm(
                        from: from,
                        to: to,
                        date: date,
                        activeQuickDate: _activeQuickDateMode(),
                        loading: s.loading && s.cities.isNotEmpty,
                        onFromTap: () async {
                          final picked = await showCityPickerBottomSheet(
                            c,
                            title: c.tr('passenger.pickCity'),
                            cities: s.cities,
                            selected: from,
                          );
                          if (picked != null) setState(() => from = picked);
                        },
                        onToTap: () async {
                          final picked = await showCityPickerBottomSheet(
                            c,
                            title: c.tr('passenger.pickCity'),
                            cities: s.cities,
                            selected: to,
                          );
                          if (picked != null) setState(() => to = picked);
                        },
                        onSwap: from == null || to == null
                            ? null
                            : () => setState(() {
                                  final tmp = from;
                                  from = to;
                                  to = tmp;
                                }),
                        onQuickDate: (mode) => _quickDate(c, mode),
                        onPickDate: () async {
                          final d = await showDatePicker(
                            context: c,
                            locale: const Locale('en'),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 90)),
                            initialDate: date,
                          );
                          if (d != null) setState(() => date = d);
                        },
                        onSearch: from == null || to == null || (s.loading && s.cities.isNotEmpty)
                            ? null
                            : from!.id == to!.id
                                ? () => showAppSnack(c, c.tr('passenger.differentCities'), type: AppSnackType.error)
                                : () async {
                                    await c.read<SearchCubit>().search(
                                      from!.id,
                                      to!.id,
                                      date,
                                      fromName: from!.name,
                                      toName: to!.name,
                                    );
                                    if (c.mounted) c.push('/results');
                                  },
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (s.upcoming.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              c.tr('passenger.nearestTrips'),
                              style: Theme.of(c).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                            ),
                          ),
                          TextButton(
                            onPressed: () => c.push('/upcoming'),
                            child: Text(c.tr('passenger.viewAllNearestTrips')),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Builder(
                        builder: (context) {
                          final nearest = sortTripsByDeparture(s.upcoming).take(_upcomingHomePreview).toList();
                          return SizedBox(
                            height: TripSuggestionCard.cardHeight,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: nearest.length,
                              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
                              itemBuilder: (_, i) => TripSuggestionCard(nearest[i], showCountdown: true),
                            ),
                          );
                        },
                      ),
                    ],
                    if (s.offers.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        c.tr('passenger.offerForYou'),
                        style: Theme.of(c).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ...s.offers.asMap().entries.map((entry) {
                        final i = entry.key;
                        final trip = entry.value;
                        return AnimatedListItem(
                          index: i + 1,
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: _OfferBanner(trip: trip),
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

class UpcomingTripsScreen extends StatelessWidget {
  const UpcomingTripsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
                return;
              }
              context.go('/home');
            },
          ),
          title: Text(context.tr('passenger.allNearestTrips')),
        ),
        body: BlocBuilder<SearchCubit, SearchState>(
          builder: (c, s) {
            if (s.loading && s.upcoming.isEmpty) {
              return const StateBox(loading: true, child: SizedBox.shrink());
            }
            if (s.error != null) {
              return StateBox(
                loading: false,
                error: mapError(s.error!, L10n.of(c)),
                child: const SizedBox.shrink(),
              );
            }
            if (s.upcoming.isEmpty) {
              return RefreshIndicator(
                onRefresh: () => c.read<SearchCubit>().init(),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                  children: [
                    SizedBox(
                      height: MediaQuery.of(c).size.height * 0.42,
                      child: StateBox(
                        loading: false,
                        empty: true,
                        emptyTitle: c.tr('passenger.noUpcomingTrips'),
                        emptyMessage: c.tr('passenger.noUpcomingTripsHint'),
                        assetName: 'assets/images/empty_trips.svg',
                        child: const SizedBox.shrink(),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () => context.go('/home'),
                      icon: const Icon(Icons.search_rounded),
                      label: Text(c.tr('passenger.backToSearch')),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: () => c.read<SearchCubit>().init(),
              child: AnimationLimiter(
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: sortTripsByDeparture(s.upcoming).asMap().entries.map((entry) {
                    final i = entry.key;
                    final trip = entry.value;
                    return AnimatedListItem(
                      index: i,
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: TripTile(trip),
                    );
                  }).toList(),
                ),
              ),
            );
          },
        ),
      );
}

class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key});

  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/home');
  }

  String? _searchSummary(BuildContext context, SearchState s) {
    if (!s.hasLastSearch || s.lastFromName == null || s.lastToName == null) return null;
    return context.tr('passenger.searchSummary', {
      'from': s.lastFromName!,
      'to': s.lastToName!,
      'arrow': context.tr('common.routeArrow'),
      'date': formatSearchDate(s.lastTravelDate!),
    });
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<SearchCubit, SearchState>(
        builder: (c, s) {
          final summary = _searchSummary(c, s);
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => _back(c),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.tr('passenger.searchResults')),
                  if (summary != null)
                    Text(
                      summary,
                      style: Theme.of(c).textTheme.bodySmall?.copyWith(
                            color: Theme.of(c).colorScheme.onSurface.withValues(alpha: .65),
                          ),
                    ),
                ],
              ),
            ),
            body: _ResultsBody(state: s, onBack: () => _back(c)),
          );
        },
      );
}

class _ResultsBody extends StatefulWidget {
  final SearchState state;
  final VoidCallback onBack;

  const _ResultsBody({required this.state, required this.onBack});

  @override
  State<_ResultsBody> createState() => _ResultsBodyState();
}

class _ResultsBodyState extends State<_ResultsBody> {
  TripSortMode _sortMode = TripSortMode.soonest;

  SearchState get state => widget.state;

  Future<void> _refresh(BuildContext context) async {
    final cubit = context.read<SearchCubit>();
    if (state.hasLastSearch) {
      await cubit.retryLastSearch();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (state.loading && state.results.isEmpty) {
      return const StateBox(loading: true, child: SizedBox.shrink());
    }
    if (state.error != null) {
      return RefreshIndicator(
        onRefresh: () => _refresh(context),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.55,
              child: StateBox(
                loading: false,
                error: mapError(state.error!, L10n.of(context)),
                child: const SizedBox.shrink(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: _SearchResultActions(state: state, onBack: widget.onBack, showRetry: true),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      );
    }
    if (state.results.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _refresh(context),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.42,
              child: StateBox(
                loading: false,
                empty: true,
                emptyTitle: context.tr('passenger.noSearchResults'),
                emptyMessage: context.tr('passenger.noSearchResultsHint'),
                assetName: 'assets/images/empty_trips.svg',
                child: const SizedBox.shrink(),
              ),
            ),
            _SearchResultActions(state: state, onBack: widget.onBack, showRetry: true),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      );
    }

    final sorted = applyTripSort(state.results, _sortMode);
    final bestPriceId = cheapestTripId(state.results);

    return RefreshIndicator(
      onRefresh: () => _refresh(context),
      child: AnimationLimiter(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            AnimatedSegmentBar<TripSortMode>(
              options: [
                SegmentOption(
                  value: TripSortMode.cheapest,
                  label: context.tr('passenger.sortCheapest'),
                  icon: Icons.sell_outlined,
                ),
                SegmentOption(
                  value: TripSortMode.soonest,
                  label: context.tr('passenger.sortSoonest'),
                  icon: Icons.schedule_rounded,
                ),
              ],
              selected: _sortMode,
              onChanged: (mode) => setState(() => _sortMode = mode),
            ),
            const SizedBox(height: AppSpacing.md),
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                context.tr('passenger.resultsCount', {'count': '${sorted.length}'}),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 340),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(begin: const Offset(0, .03), end: Offset.zero).animate(animation),
                  child: child,
                ),
              ),
              child: Column(
                key: ValueKey(_sortMode),
                children: sorted.asMap().entries.map((entry) {
                  final i = entry.key;
                  final trip = entry.value;
                  return AnimatedListItem(
                    index: i,
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: TripTile(
                      trip,
                      highlightBestPrice: bestPriceId != null && trip.id == bestPriceId,
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchResultActions extends StatelessWidget {
  final SearchState state;
  final VoidCallback onBack;
  final bool showRetry;

  const _SearchResultActions({
    required this.state,
    required this.onBack,
    this.showRetry = false,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: onBack,
            icon: const Icon(Icons.edit_location_alt_outlined),
            label: Text(context.tr('passenger.modifySearch')),
          ),
          if (showRetry && state.hasLastSearch) ...[
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: state.loading ? null : () => context.read<SearchCubit>().retryLastSearch(),
              icon: const Icon(Icons.refresh_rounded),
              label: Text(context.tr('passenger.searchAgain')),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: () => context.push('/upcoming'),
            child: Text(context.tr('passenger.viewAllNearestTrips')),
          ),
        ],
      );
}

class _SearchForm extends StatelessWidget {
  final City? from;
  final City? to;
  final DateTime date;
  final int? activeQuickDate;
  final bool loading;
  final VoidCallback onFromTap;
  final VoidCallback onToTap;
  final VoidCallback? onSwap;
  final ValueChanged<int> onQuickDate;
  final VoidCallback onPickDate;
  final VoidCallback? onSearch;

  const _SearchForm({
    required this.from,
    required this.to,
    required this.date,
    required this.activeQuickDate,
    required this.loading,
    required this.onFromTap,
    required this.onToTap,
    required this.onSwap,
    required this.onQuickDate,
    required this.onPickDate,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final quickLabels = [
      context.tr('passenger.quickToday'),
      context.tr('passenger.quickTomorrow'),
      context.tr('passenger.quickWeekend'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _CityPickerField(
                title: context.tr('passenger.from'),
                value: from?.name,
                onTap: onFromTap,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 18),
              child: _SwapButton(onPressed: onSwap),
            ),
            Expanded(
              child: _CityPickerField(
                title: context.tr('passenger.to'),
                value: to?.name,
                onTap: onToTap,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: .45),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.tr('passenger.date'),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: List.generate(quickLabels.length, (i) {
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsetsDirectional.only(
                        start: i == 0 ? 0 : AppSpacing.xxs,
                        end: i == quickLabels.length - 1 ? 0 : AppSpacing.xxs,
                      ),
                      child: _QuickDatePill(
                        label: quickLabels[i],
                        selected: activeQuickDate == i,
                        onTap: () => onQuickDate(i),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: AppSpacing.sm),
              _DatePickerTile(date: date, onTap: onPickDate),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 52,
          child: FilledButton.icon(
            icon: loading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: scheme.onPrimary,
                    ),
                  )
                : const Icon(Icons.search_rounded),
            onPressed: onSearch,
            label: Text(
              context.tr('passenger.search'),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }
}

class _SwapButton extends StatefulWidget {
  final VoidCallback? onPressed;

  const _SwapButton({required this.onPressed});

  @override
  State<_SwapButton> createState() => _SwapButtonState();
}

class _SwapButtonState extends State<_SwapButton> with SingleTickerProviderStateMixin {
  late final AnimationController _spin;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.onPressed == null) return;
    _spin.forward(from: 0).then((_) {
      if (mounted) _spin.value = 0;
    });
    widget.onPressed!();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.primaryContainer,
      shape: const CircleBorder(),
      elevation: widget.onPressed != null ? 1 : 0,
      shadowColor: scheme.primary.withValues(alpha: .25),
      child: InkWell(
        onTap: widget.onPressed == null ? null : _handleTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 40,
          height: 40,
          child: RotationTransition(
            turns: Tween<double>(begin: 0, end: .5).animate(CurvedAnimation(parent: _spin, curve: Curves.easeOutBack)),
            child: Icon(
              Icons.swap_vert_rounded,
              size: 22,
              color: widget.onPressed != null ? scheme.primary : scheme.onSurface.withValues(alpha: .35),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickDatePill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _QuickDatePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primary : scheme.surface,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outline.withValues(alpha: .7),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: selected ? scheme.onPrimary : scheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class _DatePickerTile extends StatelessWidget {
  final DateTime date;
  final VoidCallback onTap;

  const _DatePickerTile({required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: scheme.outline.withValues(alpha: .7)),
          ),
          child: Row(
            children: [
              Icon(Icons.calendar_month_rounded, size: 20, color: scheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  formatSearchDate(date),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                ),
              ),
              Icon(Icons.chevron_left_rounded, color: scheme.onSurfaceVariant, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class _CityPickerField extends StatelessWidget {
  final String title;
  final String? value;
  final VoidCallback onTap;

  const _CityPickerField({
    required this.title,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final filled = value != null;

    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: .5),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  if (filled)
                    CityThumbnail(cityName: value!, size: 28)
                  else
                    Icon(
                      Icons.location_on_outlined,
                      size: 17,
                      color: scheme.onSurfaceVariant,
                    ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      value ?? '—',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: filled ? scheme.onSurface : scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Icon(Icons.keyboard_arrow_down_rounded, size: 22, color: scheme.onSurfaceVariant),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfferBanner extends StatelessWidget {
  final Trip trip;

  const _OfferBanner({required this.trip});

  int? get _discountPercent {
    if (trip.offerPrice == null || trip.offerPrice! >= trip.price || trip.price <= 0) return null;
    return ((1 - trip.offerPrice! / trip.price) * 100).round();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final discount = _discountPercent;
    final hasDiscount = trip.isOffer && trip.offerPrice != null && trip.offerPrice! < trip.price;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () => context.push('/trip', extra: trip),
        child: Ink(
          height: 128,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            gradient: AppGradients.offer,
            boxShadow: AppShadows.medium(AppColors.deepPurple),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Stack(
              children: [
                Positioned(
                  top: -28,
                  right: -20,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: .10),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -18,
                  left: -12,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: .06),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: .18),
                              borderRadius: BorderRadius.circular(AppRadius.pill),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.local_offer_rounded, color: Colors.white, size: 13),
                                const SizedBox(width: 4),
                                Text(
                                  context.tr('passenger.offerBadge'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (discount != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(AppRadius.pill),
                              ),
                              child: Text(
                                '-$discount%',
                                style: const TextStyle(
                                  color: AppColors.deepPurple,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                          const Spacer(),
                          Icon(Icons.arrow_forward_ios_rounded, size: 13, color: Colors.white.withValues(alpha: .8)),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        '${trip.originName} ${context.tr('common.routeArrow')} ${trip.destinationName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      if (trip.offerTitle != null && trip.offerTitle!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          trip.offerTitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: .82),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.business_rounded, size: 12, color: Colors.white.withValues(alpha: .75)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              trip.companyName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: .85),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            formatHomeCardDateTime(trip.departure),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: .8),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 10),
                          if (hasDiscount)
                            Text(
                              formatMoney(trip.price, l10n),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: .6),
                                decoration: TextDecoration.lineThrough,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          if (hasDiscount) const SizedBox(width: 5),
                          Text(
                            formatMoney(trip.finalPrice, l10n),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 17,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
