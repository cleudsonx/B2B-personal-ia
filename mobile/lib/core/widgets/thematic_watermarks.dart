import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Tipo temático da marca d'água 3D volumétrica
enum ThematicWatermarkType {
  /// Ângulos, arcos e ondas biomecânicas
  biomechanics,

  /// Arco volumétrico de manômetro/velocímetro e pulso de cárdio
  cardioLoad,

  /// Vaso sanguíneo em perspectiva com eritrócitos/fibras musculares
  muscleFatigue,

  /// Células neurais e cápsula/badge do copiloto de IA
  aiCopilot,

  /// Moléculas de glicose e esferas nutricionais
  nutritionMetabolism,

  /// Escudo de segurança com moeda e selo financeiro Pix
  walletFinance,
}

/// Widget mestre de marca d'água 3D para posicionamento nos cantos dos cards editoriais
class ThematicWatermark extends StatelessWidget {
  final ThematicWatermarkType type;
  final double size;
  final double opacity;
  final Color baseColor;

  const ThematicWatermark({
    super.key,
    required this.type,
    this.size = 140,
    this.opacity = 0.85,
    this.baseColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _ThematicWatermarkPainter(
              type: type,
              tint: baseColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _ThematicWatermarkPainter extends CustomPainter {
  final ThematicWatermarkType type;
  final Color tint;

  _ThematicWatermarkPainter({
    required this.type,
    required this.tint,
  });

  @override
  void paint(Canvas canvas, Size size) {
    switch (type) {
      case ThematicWatermarkType.biomechanics:
        _paintBiomechanics(canvas, size);
        break;
      case ThematicWatermarkType.cardioLoad:
        _paintCardioLoad(canvas, size);
        break;
      case ThematicWatermarkType.muscleFatigue:
        _paintMuscleFatigue(canvas, size);
        break;
      case ThematicWatermarkType.aiCopilot:
        _paintAiCopilot(canvas, size);
        break;
      case ThematicWatermarkType.nutritionMetabolism:
        _paintNutrition(canvas, size);
        break;
      case ThematicWatermarkType.walletFinance:
        _paintWallet(canvas, size);
        break;
    }
  }

  /// 1. Biomecânica: Ondas concêntricas e esferas de articulação 3D
  void _paintBiomechanics(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.85, size.height * 0.15);

    final strokePaint = Paint()
      ..color = tint.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.06;

    // Arcos concêntricos volumétricos
    canvas.drawCircle(center, size.width * 0.65, strokePaint);
    strokePaint
      ..color = tint.withValues(alpha: 0.24)
      ..strokeWidth = size.width * 0.05;
    canvas.drawCircle(center, size.width * 0.45, strokePaint);
    strokePaint
      ..color = tint.withValues(alpha: 0.35)
      ..strokeWidth = size.width * 0.04;
    canvas.drawCircle(center, size.width * 0.26, strokePaint);

    // Núcleo com gradiente radial volumétrico
    final corePaint = Paint()
      ..shader = RadialGradient(
        colors: [tint.withValues(alpha: 0.65), tint.withValues(alpha: 0.10)],
      ).createShader(Rect.fromCircle(center: center, radius: size.width * 0.15));
    canvas.drawCircle(center, size.width * 0.15, corePaint);

    // Esferas menores em relevo (gotículas de movimento)
    final dropletPaint = Paint()..style = PaintingStyle.fill;
    dropletPaint.color = tint.withValues(alpha: 0.75);
    canvas.drawCircle(Offset(size.width * 0.55, size.height * 0.38), size.width * 0.04, dropletPaint);
    dropletPaint.color = tint.withValues(alpha: 0.55);
    canvas.drawCircle(Offset(size.width * 0.70, size.height * 0.62), size.width * 0.028, dropletPaint);
    dropletPaint.color = tint.withValues(alpha: 0.65);
    canvas.drawCircle(Offset(size.width * 0.38, size.height * 0.22), size.width * 0.032, dropletPaint);
  }

  /// 2. Carga & Cárdio: Manômetro volumétrico em arco com agulha indicadora
  void _paintCardioLoad(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.82, size.height * 0.25);
    final radius = size.width * 0.44;

    // Arco de carga externa
    final arcPaint = Paint()
      ..color = tint.withValues(alpha: 0.20)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = size.width * 0.11;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi * 0.7,
      math.pi * 1.2,
      false,
      arcPaint,
    );

    // Arco de carga interna mais iluminado
    arcPaint
      ..color = tint.withValues(alpha: 0.36)
      ..strokeWidth = size.width * 0.06;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.68),
      math.pi * 0.85,
      math.pi * 0.9,
      false,
      arcPaint,
    );

    // Miolo central
    final hubPaint = Paint()..color = tint.withValues(alpha: 0.45);
    canvas.drawCircle(center, size.width * 0.10, hubPaint);

    // Ponteiro volumétrico apontando para o esforço
    final needlePaint = Paint()
      ..color = tint.withValues(alpha: 0.85)
      ..strokeWidth = size.width * 0.035
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, Offset(size.width * 0.48, size.height * 0.44), needlePaint);
  }

  /// 3. Fadiga Muscular / RPE: Vaso em perspectiva e eritrócitos / células
  void _paintMuscleFatigue(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.82, size.height * 0.26);

    // Cilindro do vaso sanguíneo
    final vesselPath = Path();
    vesselPath.moveTo(size.width * 0.70, 0);
    vesselPath.cubicTo(
      size.width * 0.55, size.height * 0.18,
      size.width * 0.50, size.height * 0.50,
      size.width * 0.68, size.height * 0.75,
    );
    vesselPath.lineTo(size.width, size.height * 0.55);
    vesselPath.cubicTo(
      size.width * 0.85, size.height * 0.30,
      size.width * 0.90, size.height * 0.10,
      size.width, 0,
    );
    vesselPath.close();

    final vesselPaint = Paint()..color = tint.withValues(alpha: 0.18);
    canvas.drawPath(vesselPath, vesselPaint);

    // Borda do vaso em elipse inclinada
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-math.pi / 7);
    final rimPaint = Paint()
      ..color = tint.withValues(alpha: 0.32)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: size.width * 0.24, height: size.width * 0.36),
      rimPaint,
    );
    canvas.restore();

    // Eritrócitos / células flutuantes em relevo
    final cellPaint = Paint()..style = PaintingStyle.fill;
    cellPaint.color = tint.withValues(alpha: 0.50);
    canvas.drawCircle(Offset(size.width * 0.52, size.height * 0.46), size.width * 0.11, cellPaint);
    cellPaint.color = tint.withValues(alpha: 0.20);
    canvas.drawCircle(Offset(size.width * 0.52, size.height * 0.46), size.width * 0.06, cellPaint);

    cellPaint.color = tint.withValues(alpha: 0.60);
    canvas.drawCircle(Offset(size.width * 0.38, size.height * 0.72), size.width * 0.07, cellPaint);

    cellPaint.color = tint.withValues(alpha: 0.35);
    canvas.drawCircle(Offset(size.width * 0.76, size.height * 0.80), size.width * 0.08, cellPaint);
  }

  /// 4. Copiloto IA: Célula neural orgânica e pílula de insight
  void _paintAiCopilot(Canvas canvas, Size size) {
    final centerA = Offset(size.width * 0.75, size.height * 0.36);
    final centerB = Offset(size.width * 0.94, size.height * 0.16);

    // Célula neural primária
    final cellAPaint = Paint()..color = tint.withValues(alpha: 0.22);
    canvas.drawCircle(centerA, size.width * 0.28, cellAPaint);
    cellAPaint.color = tint.withValues(alpha: 0.38);
    canvas.drawCircle(centerA, size.width * 0.15, cellAPaint);

    // Célula secundária interligada
    final cellBPaint = Paint()..color = tint.withValues(alpha: 0.16);
    canvas.drawCircle(centerB, size.width * 0.20, cellBPaint);
    cellBPaint.color = tint.withValues(alpha: 0.28);
    canvas.drawCircle(centerB, size.width * 0.10, cellBPaint);

    // Pílula / Badge inteligente com ícone de faísca
    final pillRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width * 0.48, size.height * 0.65),
        width: size.width * 0.22,
        height: size.width * 0.12,
      ),
      Radius.circular(size.width * 0.06),
    );
    final pillPaint = Paint()..color = const Color(0xFFF59E0B).withValues(alpha: 0.85);
    canvas.drawRRect(pillRect, pillPaint);

    final dotPaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(size.width * 0.44, size.height * 0.65), size.width * 0.025, dotPaint);
  }

  /// 5. Nutrição: Esferas moleculares de glicose interligadas com brilho
  void _paintNutrition(Canvas canvas, Size size) {
    final atomPaint = Paint()..style = PaintingStyle.fill;

    // Átomo central principal com brilho
    final center = Offset(size.width * 0.68, size.height * 0.36);
    atomPaint.color = tint.withValues(alpha: 0.35);
    canvas.drawCircle(center, size.width * 0.22, atomPaint);

    atomPaint.color = tint.withValues(alpha: 0.55);
    canvas.drawCircle(Offset(center.dx - size.width * 0.05, center.dy - size.width * 0.05), size.width * 0.07, atomPaint);

    // Ligações moleculares sutis
    final bondPaint = Paint()
      ..color = tint.withValues(alpha: 0.25)
      ..strokeWidth = size.width * 0.025;
    final atomRight = Offset(size.width * 0.92, size.height * 0.52);
    final atomTop = Offset(size.width * 0.82, size.height * 0.14);
    final atomLeft = Offset(size.width * 0.45, size.height * 0.62);

    canvas.drawLine(center, atomRight, bondPaint);
    canvas.drawLine(center, atomTop, bondPaint);
    canvas.drawLine(center, atomLeft, bondPaint);

    // Átomos periféricos
    atomPaint.color = tint.withValues(alpha: 0.28);
    canvas.drawCircle(atomRight, size.width * 0.15, atomPaint);
    atomPaint.color = tint.withValues(alpha: 0.45);
    canvas.drawCircle(atomTop, size.width * 0.11, atomPaint);
    atomPaint.color = tint.withValues(alpha: 0.30);
    canvas.drawCircle(atomLeft, size.width * 0.13, atomPaint);
  }

  /// 6. Carteira / Pix: Escudo de segurança com moeda metálica 3D
  void _paintWallet(Canvas canvas, Size size) {
    // Escudo protetor de fundo
    final shieldPath = Path();
    final top = Offset(size.width * 0.80, size.height * 0.10);
    shieldPath.moveTo(top.dx, top.dy);
    shieldPath.lineTo(size.width * 0.98, size.height * 0.22);
    shieldPath.lineTo(size.width * 0.98, size.height * 0.52);
    shieldPath.cubicTo(
      size.width * 0.98, size.height * 0.75,
      size.width * 0.80, size.height * 0.90,
      size.width * 0.80, size.height * 0.90,
    );
    shieldPath.cubicTo(
      size.width * 0.80, size.height * 0.90,
      size.width * 0.62, size.height * 0.75,
      size.width * 0.62, size.height * 0.52,
    );
    shieldPath.lineTo(size.width * 0.62, size.height * 0.22);
    shieldPath.close();

    final shieldPaint = Paint()..color = tint.withValues(alpha: 0.20);
    canvas.drawPath(shieldPath, shieldPaint);

    // Moeda volumétrica sobreposta
    final coinCenter = Offset(size.width * 0.52, size.height * 0.56);
    final coinPaint = Paint()..color = tint.withValues(alpha: 0.35);
    canvas.drawCircle(coinCenter, size.width * 0.18, coinPaint);

    final coinRim = Paint()
      ..color = tint.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.025;
    canvas.drawCircle(coinCenter, size.width * 0.14, coinRim);
  }

  @override
  bool shouldRepaint(covariant _ThematicWatermarkPainter oldDelegate) {
    return oldDelegate.type != type || oldDelegate.tint != tint;
  }
}

