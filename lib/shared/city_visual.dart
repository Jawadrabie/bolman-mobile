import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/theme.dart';

enum _CityGlyph { emoji, noria }

class _CityVisual {
  final _CityGlyph glyph;
  final String? emoji;
  final List<Color> gradient;

  const _CityVisual.emoji(this.emoji, this.gradient) : glyph = _CityGlyph.emoji;

  const _CityVisual.noria(this.gradient)
      : glyph = _CityGlyph.noria,
        emoji = null;
}

String _normalizeCityName(String name) =>
    name.trim().replaceAll('أ', 'ا').replaceAll('إ', 'ا').replaceAll('آ', 'ا');

_CityVisual _visualFor(String cityName) {
  final key = _normalizeCityName(cityName);
  return _catalog[key] ?? const _CityVisual.emoji('📍', [AppColors.primary, AppColors.deepPurple]);
}

const _catalog = <String, _CityVisual>{
  'حلب': _CityVisual.emoji('🏰', [Color(0xFF92400E), Color(0xFFD97706)]),
  'حماة': _CityVisual.noria([Color(0xFF0F766E), Color(0xFF14B8A6)]),
  'حمص': _CityVisual.emoji('🕌', [Color(0xFF7C3AED), Color(0xFF6C63FF)]),
  'دمشق': _CityVisual.emoji('🏛️', [Color(0xFF4F46E5), Color(0xFF6366F1)]),
  'اللاذقية': _CityVisual.emoji('🌊', [Color(0xFF0369A1), Color(0xFF0EA5E9)]),
  'طرطوس': _CityVisual.emoji('⛱️', [Color(0xFF0891B2), Color(0xFF22D3EE)]),
  'ادلب': _CityVisual.emoji('🌿', [Color(0xFF15803D), Color(0xFF4ADE80)]),
  'الرقة': _CityVisual.emoji('🏜️', [Color(0xFFB45309), Color(0xFFF59E0B)]),
  'دير الزور': _CityVisual.emoji('🌅', [Color(0xFFEA580C), Color(0xFFFB923C)]),
  'السويداء': _CityVisual.emoji('🏔️', [Color(0xFF475569), Color(0xFF94A3B8)]),
  'الحسكة': _CityVisual.emoji('🌾', [Color(0xFFCA8A04), Color(0xFFEAB308)]),
  'القامشلي': _CityVisual.emoji('🌾', [Color(0xFFA16207), Color(0xFFFBBF24)]),
  'درعا': _CityVisual.emoji('🌳', [Color(0xFF166534), Color(0xFF22C55E)]),
};

/// Compact landmark thumbnail for a Syrian city.
class CityThumbnail extends StatelessWidget {
  final String cityName;
  final double size;
  final bool selected;

  const CityThumbnail({
    super.key,
    required this.cityName,
    this.size = 34,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final visual = _visualFor(cityName);
    final scheme = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: visual.gradient,
        ),
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(
          color: selected ? scheme.primary : Colors.white.withValues(alpha: .22),
          width: selected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: visual.gradient.last.withValues(alpha: .28),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: switch (visual.glyph) {
          _CityGlyph.emoji => Text(
              visual.emoji!,
              style: TextStyle(fontSize: size * 0.48, height: 1),
            ),
          _CityGlyph.noria => _NoriaGlyph(size: size * 0.58),
        },
      ),
    );
  }
}

class _NoriaGlyph extends StatelessWidget {
  final double size;

  const _NoriaGlyph({required this.size});

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size.square(size),
        painter: _NoriaPainter(),
      );
}

class _NoriaPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.38;
    final stroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.07
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(Offset(cx, cy), r, stroke);

    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      canvas.drawLine(
        Offset(cx + r * 0.2 * math.cos(a), cy + r * 0.2 * math.sin(a)),
        Offset(cx + r * math.cos(a), cy + r * math.sin(a)),
        stroke,
      );
    }

    canvas.drawLine(
      Offset(cx - r * 1.05, cy),
      Offset(cx + r * 1.05, cy),
      stroke..strokeWidth = size.width * 0.09,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
