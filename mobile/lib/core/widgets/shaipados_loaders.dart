import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'meta_components.dart';

/// Enum para facilitar a seleção do loader animado nativo
enum ShaipadosLoaderType {
  mrCoachEvolution, // Conceito 1: Robô evoluindo (Iniciante -> Atlético -> Shaipado)
  labShakerDna,     // Conceito 2: Coqueteleira de laboratório borbulhando com hélice de DNA
  barbellPlates,    // Conceito 3: Barra olímpica encaixando anilhas com efeito elástico e envergando
}

/// Container com Glassmorphism, Tag Shaipados Labs, Mensagens Rotativas e Suporte Light/Dark
class ShaipadosLoaderContainer extends StatefulWidget {
  final ShaipadosLoaderType type;
  final String? customTitle;
  final List<String>? loadingMessages;
  final bool isOverlay;
  final VoidCallback? onCancel;
  final double? progressOverride;

  /// Controla timers e repetições automáticas em testes de widget
  static bool enableAutoAnimate = true;

  const ShaipadosLoaderContainer({
    super.key,
    required this.type,
    this.customTitle,
    this.loadingMessages,
    this.isOverlay = true,
    this.onCancel,
    this.progressOverride,
  });

  @override
  State<ShaipadosLoaderContainer> createState() =>
      _ShaipadosLoaderContainerState();
}

class _ShaipadosLoaderContainerState extends State<ShaipadosLoaderContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Timer? _messageTimer;
  int _currentMessageIndex = 0;

  static const Color containerIndigoNeon = Color(0xFF6366F1);
  static const Color containerEmeraldNeon = Color(0xFF10B981);

  List<String> get _defaultMessages {
    switch (widget.type) {
      case ShaipadosLoaderType.mrCoachEvolution:
        return const [
          'Fase 1: Analisando perfil fisiológico e anamnese...',
          'Fase 2: Calculando volume de séries e vetores articulares...',
          'Fase 3: Calibrando hipertrofia, descanso e RPE...',
          'Fase 4: Finalizando periodização inteligente do Mr. Coach!',
        ];
      case ShaipadosLoaderType.labShakerDna:
        return const [
          'Sintetizando algoritmos no Shaipados Labs...',
          'Sincronizando protocolos biomecânicos...',
          'Calibrando banco de dados e inteligência de treino...',
          'Pronto para o próximo nível!',
        ];
      case ShaipadosLoaderType.barbellPlates:
        return const [
          'Montando a barra olímpica...',
          'Ajustando vetores e restrições articulares...',
          'Adicionando carga progressiva ao movimento...',
          'Variação aprovada! Pronto para o treino.',
        ];
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );

    if (ShaipadosLoaderContainer.enableAutoAnimate) {
      _controller.repeat();

      final msgs = widget.loadingMessages ?? _defaultMessages;
      if (msgs.length > 1) {
        _messageTimer = Timer.periodic(const Duration(milliseconds: 1800), (_) {
          if (mounted) {
            setState(() {
              _currentMessageIndex = (_currentMessageIndex + 1) % msgs.length;
            });
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Widget _buildCustomPainter(double progress, bool isDark) {
    switch (widget.type) {
      case ShaipadosLoaderType.mrCoachEvolution:
        return CustomPaint(
          painter: MrCoachEvolutionPainter(
            progress: progress,
            isDark: isDark,
          ),
        );
      case ShaipadosLoaderType.labShakerDna:
        return CustomPaint(
          painter: LabShakerDnaPainter(
            progress: progress,
            isDark: isDark,
          ),
        );
      case ShaipadosLoaderType.barbellPlates:
        return CustomPaint(
          painter: BarbellPlatesPainter(
            progress: progress,
            isDark: isDark,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = MetaColors.isDark(context);
    final msgs = widget.loadingMessages ?? _defaultMessages;

    final cardBg = isDark
        ? const Color(0xFF0F172A).withValues(alpha: 0.96)
        : Colors.white.withValues(alpha: 0.98);

    final cardBorder = isDark
        ? containerIndigoNeon.withValues(alpha: 0.35)
        : const Color(0xFFCBD5E1);

    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtextColor = isDark
        ? Colors.white.withValues(alpha: 0.8)
        : const Color(0xFF475569);

    final card = Container(
      constraints: const BoxConstraints(maxWidth: 340),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cardBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? containerIndigoNeon.withValues(alpha: 0.25)
                : Colors.black.withValues(alpha: 0.12),
            blurRadius: 30,
            spreadRadius: isDark ? 2 : 0,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Badge Superior Shaipados Labs (com proteção FittedBox anti-overflow)
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.bolt, color: containerEmeraldNeon, size: 14),
                  const SizedBox(width: 5),
                  Text(
                    'SHAIPADOS LABS • MR. COACH',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : const Color(0xFF334155),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Canvas Animado Isolado com RepaintBoundary (Performance 60 FPS)
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final progress = _controller.value;
              final double displayProgress = widget.progressOverride != null
                  ? widget.progressOverride!.clamp(0.0, 1.0)
                  : (0.15 + (progress * 0.85));

              return Column(
                children: [
                  RepaintBoundary(
                    child: SizedBox(
                      height: 120,
                      width: 250,
                      child: _buildCustomPainter(progress, isDark),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      height: 6,
                      width: 220,
                      child: LinearProgressIndicator(
                        value: widget.progressOverride != null
                            ? displayProgress
                            : null, // Indeterminado suave quando não fixado
                        backgroundColor: isDark
                            ? Colors.white12
                            : const Color(0xFFE2E8F0),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color.lerp(containerIndigoNeon, containerEmeraldNeon, progress) ??
                              containerEmeraldNeon,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),

          if (widget.customTitle != null) ...[
            Text(
              widget.customTitle!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 6),
          ],

          SizedBox(
            height: 40,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                msgs[_currentMessageIndex % msgs.length],
                key: ValueKey<int>(_currentMessageIndex),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: subtextColor,
                  fontSize: 12.5,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),

          if (widget.onCancel != null) ...[
            const SizedBox(height: 14),
            TextButton(
              onPressed: widget.onCancel,
              style: TextButton.styleFrom(
                foregroundColor: isDark ? Colors.white60 : const Color(0xFF64748B),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: const Text(
                'Cancelar operação',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
    );

    if (!widget.isOverlay) return Center(child: card);

    return Stack(
      children: [
        Positioned.fill(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Container(
              color: Colors.black.withValues(alpha: isDark ? 0.65 : 0.45),
            ),
          ),
        ),
        Center(child: Material(color: Colors.transparent, child: card)),
      ],
    );
  }
}

// ============================================================================
// CONCEITO 1: EVOLUÇÃO DO MR. COACH (Do Frango ao Shaipado Cibernético)
// ============================================================================
class MrCoachEvolutionPainter extends CustomPainter {
  final double progress;
  final bool isDark;

  MrCoachEvolutionPainter({
    required this.progress,
    required this.isDark,
  });

  static const Color stage1Color = Color(0xFF94A3B8); // Slate iniciante
  static const Color stage2Color = Color(0xFF6366F1); // Indigo intermediário
  static const Color stage3Color = Color(0xFF10B981); // Esmeralda Shaipado

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2 + 8;

    // Estágios de evolução com interpolação suave
    final Color activeColor = progress < 0.33
        ? Color.lerp(stage1Color, stage2Color, progress / 0.33)!
        : Color.lerp(stage2Color, stage3Color, (progress - 0.33) / 0.67)!;

    // Escala de hipertrofia muscular progressiva
    final double muscleScale = ui.lerpDouble(0.75, 1.35, progress)!;

    // Movimento senoidal de rosca bíceps
    final double curlAngle = math.sin(progress * math.pi * 6) * 0.45;

    // Aura de energia crescente
    final glowPaint = Paint()
      ..color = activeColor.withValues(alpha: 0.25 + (progress * 0.25))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
    canvas.drawCircle(
      Offset(centerX, centerY - 10),
      28 * muscleScale,
      glowPaint,
    );

    final bodyPaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.fill;

    final outlineColor = isDark
        ? Colors.white.withValues(alpha: 0.85)
        : const Color(0xFF1E293B).withValues(alpha: 0.85);

    final outlinePaint = Paint()
      ..color = outlineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // 1. Cabeça Cibernética com Visor
    final headRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(centerX, centerY - 38),
        width: 26 * (0.9 + progress * 0.2),
        height: 22,
      ),
      const Radius.circular(6),
    );
    canvas.drawRRect(headRect, bodyPaint);
    canvas.drawRRect(headRect, outlinePaint);

    // Visor LED dos olhos
    final visorPaint = Paint()..color = Colors.white;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(centerX, centerY - 38),
          width: 16,
          height: 5,
        ),
        const Radius.circular(2),
      ),
      visorPaint,
    );

    // 2. Tronco em V-Taper (expansão de ombros e dorsais)
    final shoulderWidth = 28.0 * muscleScale;
    final waistWidth = 18.0 * (0.9 + progress * 0.15);
    final torsoPath = Path()
      ..moveTo(centerX - shoulderWidth, centerY - 22)
      ..lineTo(centerX + shoulderWidth, centerY - 22)
      ..lineTo(centerX + waistWidth, centerY + 18)
      ..lineTo(centerX - waistWidth, centerY + 18)
      ..close();
    canvas.drawPath(torsoPath, bodyPaint);
    canvas.drawPath(torsoPath, outlinePaint);

    // Núcleo de energia no peitoral
    canvas.drawCircle(
      Offset(centerX, centerY - 6),
      4 + (progress * 3),
      visorPaint,
    );

    // 3. Braços e halteres executando a rosca direta
    _drawCyberArm(
      canvas: canvas,
      shoulder: Offset(centerX - shoulderWidth - 4, centerY - 16),
      isLeft: true,
      muscleScale: muscleScale,
      curlAngle: curlAngle,
      color: activeColor,
    );
    _drawCyberArm(
      canvas: canvas,
      shoulder: Offset(centerX + shoulderWidth + 4, centerY - 16),
      isLeft: false,
      muscleScale: muscleScale,
      curlAngle: curlAngle,
      color: activeColor,
    );
  }

  void _drawCyberArm({
    required Canvas canvas,
    required Offset shoulder,
    required bool isLeft,
    required double muscleScale,
    required double curlAngle,
    required Color color,
  }) {
    final dir = isLeft ? -1.0 : 1.0;
    final armPaint = Paint()
      ..color = color
      ..strokeWidth = 7.0 * muscleScale
      ..strokeCap = StrokeCap.round;

    final elbow = Offset(shoulder.dx + (dir * 12 * muscleScale), shoulder.dy + 14);
    final hand = Offset(
      elbow.dx + (dir * 10 * math.cos(curlAngle)),
      elbow.dy - (14 * math.sin(curlAngle).abs()),
    );

    canvas.drawLine(shoulder, elbow, armPaint);
    canvas.drawLine(elbow, hand, armPaint);

    // Halter na mão
    final dumbbellPaint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(hand.dx - 8, hand.dy - 6),
      Offset(hand.dx + 8, hand.dy + 6),
      dumbbellPaint,
    );
  }

  @override
  bool shouldRepaint(covariant MrCoachEvolutionPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.isDark != isDark;
}

// ============================================================================
// CONCEITO 2: SHAIPADOS LABS SHAKER (Fórmula IA + DNA com Base Reta Realista)
// ============================================================================
class LabShakerDnaPainter extends CustomPainter {
  final double progress;
  final bool isDark;

  LabShakerDnaPainter({
    required this.progress,
    required this.isDark,
  });

  static const Color indigoNeon = Color(0xFF6366F1);
  static const Color emeraldNeon = Color(0xFF10B981);
  static const Color cyanNeon = Color(0xFF38BDF8);

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2 + 5;

    // 1. Brilho ambiente do laboratório
    final glowPaint = Paint()
      ..color = emeraldNeon.withValues(alpha: isDark ? 0.2 : 0.12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 25);
    canvas.drawCircle(Offset(centerX, centerY), 50, glowPaint);

    // 2. Hélice Dupla de DNA em Rotação Senoidal
    final phase = progress * math.pi * 4;
    for (int i = 0; i < 10; i++) {
      final t = i / 10.0;
      final y = (centerY + 25) - (t * 75);
      final wave = math.sin(phase + (t * math.pi * 2)) * 18;

      final x1 = centerX + wave;
      final x2 = centerX - wave;

      final linePaint = Paint()
        ..color = isDark
            ? Colors.white.withValues(alpha: 0.25)
            : const Color(0xFF64748B).withValues(alpha: 0.3)
        ..strokeWidth = 1.5;
      canvas.drawLine(Offset(x1, y), Offset(x2, y), linePaint);

      final dot1Paint = Paint()..color = indigoNeon;
      final dot2Paint = Paint()..color = emeraldNeon;
      canvas.drawCircle(Offset(x1, y), 3.5, dot1Paint);
      canvas.drawCircle(Offset(x2, y), 3.5, dot2Paint);
    }

    // 3. Silhueta da Coqueteleira / Béquer (Base Reta com Cantos Curvos Fiéis)
    final flaskPath = Path()
      ..moveTo(centerX - 34, centerY - 32)
      ..lineTo(centerX + 34, centerY - 32)
      ..lineTo(centerX + 26, centerY + 30)
      ..quadraticBezierTo(
        centerX + 26,
        centerY + 38,
        centerX + 18,
        centerY + 38,
      )
      ..lineTo(centerX - 18, centerY + 38)
      ..quadraticBezierTo(
        centerX - 26,
        centerY + 38,
        centerX - 26,
        centerY + 30,
      )
      ..close();

    // Líquido borbulhando no béquer
    canvas.save();
    canvas.clipPath(flaskPath);
    final liquidLevel = ui.lerpDouble(centerY + 30, centerY - 18, progress)!;
    final liquidPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(centerX, centerY + 40),
        Offset(centerX, centerY - 25),
        [
          indigoNeon.withValues(alpha: 0.7),
          emeraldNeon.withValues(alpha: 0.55),
        ],
      );
    canvas.drawRect(
      Rect.fromLTRB(centerX - 40, liquidLevel, centerX + 40, centerY + 45),
      liquidPaint,
    );

    // Bolhas subindo
    final bubblePaint = Paint()..color = cyanNeon.withValues(alpha: 0.75);
    for (int b = 0; b < 5; b++) {
      final by = centerY + 30 - (((progress * 80) + (b * 18)) % 65);
      final bx = centerX - 16 + (b * 8.0);
      canvas.drawCircle(Offset(bx, by), 2.5 + (b % 2), bubblePaint);
    }
    canvas.restore();

    // Contorno neon de vidro
    final glassBorder = Paint()
      ..color = cyanNeon.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawPath(flaskPath, glassBorder);

    // Graduação de mililitros científica
    final tickPaint = Paint()
      ..color = isDark ? Colors.white54 : const Color(0xFF475569)
      ..strokeWidth = 1.5;
    for (int m = 0; m < 4; m++) {
      final my = centerY + 20 - (m * 12);
      canvas.drawLine(Offset(centerX - 24, my), Offset(centerX - 16, my), tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant LabShakerDnaPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.isDark != isDark;
}

// ============================================================================
// CONCEITO 3: BARRA OLÍMPICA E ANILHAS (Com Efeito Elástico & Envergadura)
// ============================================================================
class BarbellPlatesPainter extends CustomPainter {
  final double progress;
  final bool isDark;

  BarbellPlatesPainter({
    required this.progress,
    required this.isDark,
  });

  static const Color indigoNeon = Color(0xFF6366F1);
  static const Color emeraldNeon = Color(0xFF10B981);
  static const Color cyanNeon = Color(0xFF38BDF8);
  static const Color steelLight = Color(0xFFCBD5E1);
  static const Color steelDark = Color(0xFF64748B);

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final centerX = size.width / 2;

    double bendAmount = 0.0;
    if (progress > 0.65) {
      final t = ((progress - 0.65) / 0.35).clamp(0.0, 1.0);
      bendAmount = 10.0 * ui.lerpDouble(0, 1, t)!;
    }

    if (progress > 0.75) {
      final glowOpacity = ((progress - 0.75) / 0.25).clamp(0.0, 1.0);
      final glowPaint = Paint()
        ..color = emeraldNeon.withValues(alpha: 0.35 * glowOpacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22);
      canvas.drawCircle(Offset(centerX, centerY), 60, glowPaint);
    }

    // Barra de aço com curva de envergadura
    final barPath = Path()
      ..moveTo(10, centerY + bendAmount)
      ..quadraticBezierTo(
        centerX,
        centerY - (bendAmount * 0.8),
        size.width - 10,
        centerY + bendAmount,
      );

    final barPaint = Paint()
      ..color = isDark ? steelLight : const Color(0xFF475569)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.5
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(barPath, barPaint);

    final collarPaint = Paint()..color = steelDark;
    final collarY = centerY + (bendAmount * 0.45);

    // Presilhas / Batentes da Barra
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(58, collarY), width: 6, height: 18),
        const Radius.circular(2),
      ),
      collarPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(size.width - 58, collarY),
          width: 6,
          height: 18,
        ),
        const Radius.circular(2),
      ),
      collarPaint,
    );

    // Par 1 de Anilhas: 20kg (Indigo)
    _drawPlatePair(
      canvas: canvas,
      size: size,
      progress: ((progress - 0.10) / 0.25).clamp(0.0, 1.0),
      targetOffsetFromCenter: 72,
      plateHeight: 58,
      plateWidth: 11,
      color: indigoNeon,
      bendY: centerY + (bendAmount * 0.55),
    );

    // Par 2 de Anilhas: 15kg (Esmeralda)
    _drawPlatePair(
      canvas: canvas,
      size: size,
      progress: ((progress - 0.35) / 0.25).clamp(0.0, 1.0),
      targetOffsetFromCenter: 86,
      plateHeight: 48,
      plateWidth: 10,
      color: emeraldNeon,
      bendY: centerY + (bendAmount * 0.72),
    );

    // Par 3 de Anilhas: 10kg (Cyan)
    _drawPlatePair(
      canvas: canvas,
      size: size,
      progress: ((progress - 0.60) / 0.22).clamp(0.0, 1.0),
      targetOffsetFromCenter: 99,
      plateHeight: 38,
      plateWidth: 9,
      color: cyanNeon,
      bendY: centerY + (bendAmount * 0.88),
    );
  }

  void _drawPlatePair({
    required Canvas canvas,
    required Size size,
    required double progress,
    required double targetOffsetFromCenter,
    required double plateHeight,
    required double plateWidth,
    required Color color,
    required double bendY,
  }) {
    if (progress <= 0) return;

    final centerX = size.width / 2;
    final curved = Curves.easeOutBack.transform(progress);
    final slideDistance = (1.0 - curved) * 28.0;
    final leftX = (centerX - targetOffsetFromCenter) - slideDistance;
    final rightX = (centerX + targetOffsetFromCenter) + slideDistance;

    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.45 * progress)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final platePaint = Paint()
      ..color = color.withValues(alpha: progress.clamp(0.0, 1.0));

    final leftRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(leftX, bendY),
        width: plateWidth,
        height: plateHeight,
      ),
      const Radius.circular(4),
    );
    final rightRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(rightX, bendY),
        width: plateWidth,
        height: plateHeight,
      ),
      const Radius.circular(4),
    );

    canvas.drawRRect(leftRect, glowPaint);
    canvas.drawRRect(rightRect, glowPaint);
    canvas.drawRRect(leftRect, platePaint);
    canvas.drawRRect(rightRect, platePaint);
  }

  @override
  bool shouldRepaint(covariant BarbellPlatesPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.isDark != isDark;
}
