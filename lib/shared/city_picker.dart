import 'package:flutter/material.dart';

import '../app/i18n/l10n.dart';
import '../app/theme.dart';
import '../data/models.dart';
import 'city_visual.dart';

const _rowHeight = 44.0;
const _sheetMaxFraction = 0.52;

Future<City?> showCityPickerBottomSheet(
  BuildContext context, {
  required String title,
  required List<City> cities,
  City? selected,
}) {
  final screenH = MediaQuery.sizeOf(context).height;
  final maxSheetH = screenH * _sheetMaxFraction;
  const headerH = 108.0;
  final estimatedListH = cities.length * _rowHeight;
  final sheetH = (headerH + estimatedListH + MediaQuery.paddingOf(context).bottom + 16)
      .clamp(220.0, maxSheetH);

  return showModalBottomSheet<City>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: (_) => SizedBox(
      height: sheetH,
      child: _CityPickerSheet(
        title: title,
        cities: cities,
        selected: selected,
      ),
    ),
  );
}

class _CityPickerSheet extends StatefulWidget {
  final String title;
  final List<City> cities;
  final City? selected;

  const _CityPickerSheet({
    required this.title,
    required this.cities,
    this.selected,
  });

  @override
  State<_CityPickerSheet> createState() => _CityPickerSheetState();
}

class _CityPickerSheetState extends State<_CityPickerSheet> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.text.trim().toLowerCase();
    final filtered = widget.cities.where((c) => c.name.toLowerCase().contains(q)).toList();
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 42,
            child: TextField(
              controller: _query,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                isDense: true,
                hintText: context.tr('common.search'),
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      context.tr('common.noData'),
                      style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      thickness: 1,
                      color: scheme.outline.withValues(alpha: .35),
                    ),
                    itemBuilder: (_, i) => _CityRow(
                      city: filtered[i],
                      selected: filtered[i].id == widget.selected?.id,
                      onTap: () => Navigator.pop(context, filtered[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _CityRow extends StatelessWidget {
  final City city;
  final bool selected;
  final VoidCallback onTap;

  const _CityRow({
    required this.city,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? AppColors.primary.withValues(alpha: .07) : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: SizedBox(
          height: _rowHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Row(
              children: [
                CityThumbnail(cityName: city.name, selected: selected),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    city.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      color: selected ? scheme.primary : scheme.onSurface,
                    ),
                  ),
                ),
                if (selected)
                  Icon(Icons.check_circle_rounded, size: 20, color: scheme.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
