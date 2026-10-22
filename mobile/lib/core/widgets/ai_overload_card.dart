import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'meta_components.dart';

/// Estratégia de progressão científica adotada
enum OverloadStrategy {
  weight, // Aumento de carga (Double Progression / Overload)
  reps, // Aumento de repetições (Step Loading)
  consolidate, // Manutenção para refinamento de cadência (RPE alto)
}

/// Representação da sugestão de sobrecarga calculada pela IA
class OverloadSuggestion {
  final String exerciseName;
  final double suggestedWeightKg;
  final int suggestedReps;
  final double previousWeightKg;
  final int previousReps;
  final OverloadStrategy strategy;
  final String badge;
  final String rationale;

  const OverloadSuggestion({
    required this.exerciseName,
    required this.suggestedWeightKg,
    required this.suggestedReps,
    required this.previousWeightKg,
    required this.previousReps,
    required this.strategy,
    required this.badge,
    required this.rationale,
  });

  double get deltaWeight => (suggestedWeightKg - previousWeightKg);
  int get deltaReps => (suggestedReps - previousReps);
}

/// Motor determinístico e inteligente de cálculo de sobrecarga progressiva
class ProgressiveOverloadEngine {
  /// Calcula a sugestão científica com base nas referências anteriores e intensidade percebida (RPE)
  static OverloadSuggestion computeSuggestion({
    required String exerciseName,
    required String targetMuscleGroup,
    required double currentWeight,
    required int currentReps,
    double? previousWeight,
    int? lastRpe,
  }) {
    final effectiveWeight = currentWeight > 0
        ? currentWeight
        : (previousWeight != null && previousWeight > 0 ? previousWeight : 20.0);
    final effectiveReps = currentReps > 0 ? currentReps : 10;
    final rpe = lastRpe ?? 8;

    // Detecta se é grupamento muscular de grande porte (compostos multiarticulares)
    final cleanGroup = targetMuscleGroup.toLowerCase();
    final isCompound = cleanGroup.contains('peitor') ||
        cleanGroup.contains('costa') ||
        cleanGroup.contains('quadr') ||
        cleanGroup.contains('glút') ||
        cleanGroup.contains('perna') ||
        exerciseName.toLowerCase().contains('supino') ||
        exerciseName.toLowerCase().contains('agacha') ||
        exerciseName.toLowerCase().contains('terra') ||
        exerciseName.toLowerCase().contains('leg press');

    // Regra 1: Se RPE <= 8 e carga consolidada -> Sobrecarga de Carga
    if (rpe <= 8 && effectiveWeight >= 5.0) {
      final double increment = isCompound
          ? (effectiveWeight >= 60.0 ? 5.0 : 2.5)
          : (effectiveWeight >= 20.0 ? 2.0 : 1.0);
      final double newWeight = effectiveWeight + increment;

      return OverloadSuggestion(
        exerciseName: exerciseName,
        suggestedWeightKg: newWeight,
        suggestedReps: effectiveReps,
        previousWeightKg: effectiveWeight,
        previousReps: effectiveReps,
        strategy: OverloadStrategy.weight,
        badge: '+${increment.toStringAsFixed(increment.truncateToDouble() == increment ? 0 : 1)} KG',
        rationale:
            'Último RPE $rpe/10 indicou boa margem de reserva. Aumente ${increment.toStringAsFixed(1)} kg mantendo a cadência controlada.',
      );
    }

    // Regra 2: Se RPE == 9 -> Sobrecarga de Volume (+1 Repetição)
    if (rpe == 9) {
      final int newReps = effectiveReps + 1;
      return OverloadSuggestion(
        exerciseName: exerciseName,
        suggestedWeightKg: effectiveWeight,
        suggestedReps: newReps,
        previousWeightKg: effectiveWeight,
        previousReps: effectiveReps,
        strategy: OverloadStrategy.reps,
        badge: '+1 REP',
        rationale:
            'Carga de ${effectiveWeight.toStringAsFixed(1)} kg já está desafiadora (RPE 9). Busque +1 repetição antes de subir peso.',
      );
    }

    // Regra 3: RPE 10 (Falha Máxima) -> Manter e Consolidar Técnica
    return OverloadSuggestion(
      exerciseName: exerciseName,
      suggestedWeightKg: effectiveWeight,
      suggestedReps: effectiveReps,
      previousWeightKg: effectiveWeight,
      previousReps: effectiveReps,
      strategy: OverloadStrategy.consolidate,
      badge: 'CONSOLIDAÇÃO',
      rationale:
          'Sessão anterior atingiu a falha total (RPE 10). Mantenha ${effectiveWeight.toStringAsFixed(1)} kg focando em descida excêntrica de 3s.',
    );
  }
}

/// Card visual de sugestão de sobrecarga progressiva com visual Meta
class AiOverloadCard extends StatefulWidget {
  final OverloadSuggestion suggestion;
  final VoidCallback onApply;
  final VoidCallback? onDismiss;

  const AiOverloadCard({
    super.key,
    required this.suggestion,
    required this.onApply,
    this.onDismiss,
  });

  @override
  State<AiOverloadCard> createState() => _AiOverloadCardState();
}

class _AiOverloadCardState extends State<AiOverloadCard> {
  bool _isApplied = false;

  void _handleApply() {
    HapticFeedback.heavyImpact();
    setState(() {
      _isApplied = true;
    });
    widget.onApply();
  }

  Color _getBadgeColor() {
    switch (widget.suggestion.strategy) {
      case OverloadStrategy.weight:
        return MetaColors.emerald;
      case OverloadStrategy.reps:
        return const Color(0xFF60A5FA); // Blue
      case OverloadStrategy.consolidate:
        return Colors.amber;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = MetaColors.isDark(context);
    final bg = isDark ? const Color(0xFF111827) : MetaColors.lightSurface;
    final textPrimary = isDark ? MetaColors.textPrimary : MetaColors.lightTextPrimary;
    final textSecondary = isDark ? MetaColors.textSecondary : MetaColors.lightTextSecondary;
    final border = isDark ? MetaColors.border : MetaColors.lightBorder;
    final badgeColor = _getBadgeColor();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isApplied
              ? MetaColors.emerald.withValues(alpha: 0.6)
              : const Color(0xFF6366F1).withValues(alpha: 0.4),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: AI Sparkle header + Badge + Dismiss
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF10B981)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      size: 13,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'PROGRESSÃO INTELIGENTE IA',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                      color: textPrimary,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      widget.suggestion.badge,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        color: badgeColor,
                      ),
                    ),
                  ),
                  if (widget.onDismiss != null) ...[
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: widget.onDismiss,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(Icons.close_rounded, size: 16, color: textSecondary),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Suggestion Details
          Row(
            children: [
              Text(
                '${widget.suggestion.suggestedWeightKg.toStringAsFixed(widget.suggestion.suggestedWeightKg.truncateToDouble() == widget.suggestion.suggestedWeightKg ? 0 : 1)} kg',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: MetaColors.emerald,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '× ${widget.suggestion.suggestedReps} reps',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                ),
              ),
              if (widget.suggestion.previousWeightKg > 0) ...[
                const SizedBox(width: 8),
                Text(
                  '(vs. ${widget.suggestion.previousWeightKg.toStringAsFixed(0)} kg)',
                  style: TextStyle(
                    fontSize: 11,
                    color: textSecondary,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 5),

          // Rationale Text
          Text(
            widget.suggestion.rationale,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.35,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 12),

          // Action Button
          SizedBox(
            width: double.infinity,
            child: _isApplied
                ? Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: MetaColors.emerald.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: MetaColors.emerald.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_rounded, size: 15, color: MetaColors.emerald),
                        SizedBox(width: 6),
                        Text(
                          'Sugestão Aplicada nas Séries!',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: MetaColors.emerald,
                          ),
                        ),
                      ],
                    ),
                  )
                : InkWell(
                    onTap: _handleApply,
                    borderRadius: BorderRadius.circular(10),
                    child: Ink(
                      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4F46E5), Color(0xFF059669)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.bolt_rounded, size: 16, color: Colors.white),
                          SizedBox(width: 6),
                          Text(
                            'Aplicar Sobrecarga na Ficha',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

