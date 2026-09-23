import 'package:flutter/material.dart';

import '../../app/i18n/l10n.dart';
import '../../app/theme.dart';
import '../../data/models.dart';

/// Builds rows from API seats using [SeatStatus.column] (A,B,C,D) and [SeatStatus.number].
class BusSeatLayout {
  final List<String> columns;
  final List<List<SeatStatus?>> rows;
  final int aisleAfterIndex;

  const BusSeatLayout({
    required this.columns,
    required this.rows,
    required this.aisleAfterIndex,
  });

  factory BusSeatLayout.fromSeats(List<SeatStatus> seats) {
    if (seats.isEmpty) {
      return const BusSeatLayout(columns: [], rows: [], aisleAfterIndex: 0);
    }

    final cols = seats
        .map((s) => s.column.trim().toUpperCase())
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    if (cols.isEmpty) {
      return _legacyLayout(seats);
    }

    final colCount = cols.length;
    final maxNum = seats.map((s) => s.number).reduce((a, b) => a > b ? a : b);
    final rowCount = (maxNum + colCount - 1) ~/ colCount;
    final byNumber = {for (final s in seats) s.number: s};

    final rows = <List<SeatStatus?>>[];
    for (var r = 0; r < rowCount; r++) {
      final row = <SeatStatus?>[];
      for (var c = 0; c < colCount; c++) {
        row.add(byNumber[r * colCount + c + 1]);
      }
      rows.add(row);
    }

    final aisleAfter = colCount >= 4
        ? 2
        : colCount == 3
            ? 2
            : colCount == 2
                ? 1
                : 0;

    return BusSeatLayout(columns: cols, rows: rows, aisleAfterIndex: aisleAfter);
  }

  static BusSeatLayout _legacyLayout(List<SeatStatus> seats) {
    const colCount = 4;
    final sorted = [...seats]..sort((a, b) => a.number.compareTo(b.number));
    final rows = <List<SeatStatus?>>[];
    for (var i = 0; i < sorted.length; i += colCount) {
      final row = <SeatStatus?>[];
      for (var c = 0; c < colCount; c++) {
        row.add(i + c < sorted.length ? sorted[i + c] : null);
      }
      rows.add(row);
    }
    return BusSeatLayout(columns: const ['A', 'B', 'C', 'D'], rows: rows, aisleAfterIndex: 2);
  }
}

class SeatGrid extends StatelessWidget {
  final List<SeatStatus> seats;
  final Set<String> selected;
  final void Function(SeatStatus seat)? onToggle;
  final bool readOnly;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  const SeatGrid({
    super.key,
    required this.seats,
    required this.selected,
    this.onToggle,
    this.readOnly = false,
    this.shrinkWrap = false,
    this.physics,
  });

  @override
  Widget build(BuildContext context) {
    final layout = BusSeatLayout.fromSeats(seats);
    if (layout.rows.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      shrinkWrap: shrinkWrap,
      physics: physics,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      children: [
        _BusShell(
          headerLabel: context.tr('seatMap.driver'),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Column(
              children: [
                if (layout.columns.isNotEmpty) _ColumnLabelsRow(layout: layout),
                const SizedBox(height: 6),
                for (var r = 0; r < layout.rows.length; r++) ...[
                  if (r > 0) const SizedBox(height: 8),
                  _SeatRow(
                    row: layout.rows[r],
                    layout: layout,
                    selected: selected,
                    readOnly: readOnly,
                    onToggle: onToggle,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            context.tr('seatMap.rear'),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .45),
                ),
          ),
        ),
      ],
    );
  }
}

class _BusShell extends StatelessWidget {
  final String headerLabel;
  final Widget child;

  const _BusShell({required this.headerLabel, required this.child});

  @override
  Widget build(BuildContext context) {
    final border = Theme.of(context).brightness == Brightness.dark ? AppColors.borderDark : AppColors.seatInactive;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: .06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: .14),
                  AppColors.primary.withValues(alpha: .05),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.airline_seat_recline_extra, color: AppColors.primary.withValues(alpha: .85), size: 22),
                const SizedBox(width: 8),
                Text(
                  headerLabel,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary.withValues(alpha: .9),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.navigation_rounded, color: AppColors.primary.withValues(alpha: .85), size: 20),
              ],
            ),
          ),
          Divider(height: 1, color: border.withValues(alpha: .6)),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _ColumnLabelsRow extends StatelessWidget {
  final BusSeatLayout layout;

  const _ColumnLabelsRow({required this.layout});

  @override
  Widget build(BuildContext context) {
    final labels = <Widget>[];
    for (var i = 0; i < layout.columns.length; i++) {
      if (i == layout.aisleAfterIndex && layout.aisleAfterIndex > 0) {
        labels.add(const SizedBox(width: 28));
      }
      labels.add(
        Expanded(
          child: Center(
            child: Text(
              layout.columns[i],
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .4),
              ),
            ),
          ),
        ),
      );
    }
    return Row(children: labels);
  }
}

class _SeatRow extends StatelessWidget {
  final List<SeatStatus?> row;
  final BusSeatLayout layout;
  final Set<String> selected;
  final bool readOnly;
  final void Function(SeatStatus seat)? onToggle;

  const _SeatRow({
    required this.row,
    required this.layout,
    required this.selected,
    required this.readOnly,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < row.length; i++) {
      if (i == layout.aisleAfterIndex && layout.aisleAfterIndex > 0) {
        children.add(const _AisleGap());
      }
      final seat = row[i];
      children.add(
        Expanded(
          child: seat == null
              ? const SizedBox(height: 52)
              : _BusSeatTile(
                  seat: seat,
                  selected: selected.contains(seat.id),
                  readOnly: readOnly,
                  onTap: !readOnly && seat.selectable ? () => onToggle?.call(seat) : null,
                ),
        ),
      );
    }
    return Row(children: children);
  }
}

class _AisleGap extends StatelessWidget {
  const _AisleGap();

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 28,
        height: 52,
        child: CustomPaint(
          painter: _AislePainter(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .18),
          ),
        ),
      );
}

class _AislePainter extends CustomPainter {
  final Color color;

  _AislePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    const dash = 4.0;
    var y = 0.0;
    final x = size.width / 2;
    while (y < size.height) {
      canvas.drawLine(Offset(x, y), Offset(x, y + dash), paint);
      y += dash * 2;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BusSeatTile extends StatefulWidget {
  final SeatStatus seat;
  final bool selected;
  final bool readOnly;
  final VoidCallback? onTap;

  const _BusSeatTile({
    required this.seat,
    required this.selected,
    required this.readOnly,
    this.onTap,
  });

  @override
  State<_BusSeatTile> createState() => _BusSeatTileState();
}

class _BusSeatTileState extends State<_BusSeatTile> {
  bool _pressed = false;

  ({Color bg, Color fg, Color border}) _colors() {
    final s = widget.seat;
    final sel = widget.selected;
    if (sel) {
      return (bg: AppColors.primary, fg: Colors.white, border: AppColors.primary);
    }
    return switch (s.status) {
      'available' => (bg: AppColors.seatAvailable, fg: AppColors.seatAvailableText, border: AppColors.seatAvailableText),
      'reserved' => (bg: AppColors.seatReserved, fg: AppColors.seatReservedText, border: AppColors.seatReservedText),
      'locked' => (bg: AppColors.seatLocked, fg: AppColors.seatLockedText, border: AppColors.seatLockedText),
      _ => (bg: AppColors.seatInactive, fg: AppColors.seatInactive, border: AppColors.seatInactive),
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = _colors();
    final enabled = widget.onTap != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1,
        duration: const Duration(milliseconds: 100),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            onHighlightChanged: enabled ? (v) => setState(() => _pressed = v) : null,
            borderRadius: BorderRadius.circular(12),
            child: Ink(
              height: 52,
              decoration: BoxDecoration(
                color: widget.selected ? c.bg : c.bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: c.border,
                  width: widget.selected ? 2 : 1.2,
                ),
                boxShadow: widget.selected
                    ? [BoxShadow(color: AppColors.primary.withValues(alpha: .28), blurRadius: 8, offset: const Offset(0, 3))]
                    : enabled
                        ? [BoxShadow(color: c.border.withValues(alpha: .12), blurRadius: 4, offset: const Offset(0, 2))]
                        : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.event_seat_rounded,
                    size: 22,
                    color: widget.selected ? Colors.white : c.fg.withValues(alpha: enabled ? 1 : .55),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '${widget.seat.number}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: widget.selected ? Colors.white : c.fg,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
