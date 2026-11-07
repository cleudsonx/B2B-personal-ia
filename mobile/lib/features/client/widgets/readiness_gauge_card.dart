import 'package:flutter/material.dart';
import '../../../models/biohub_model.dart';

class ReadinessGaugeCard extends StatelessWidget {
  final ReadinessScoreModel readiness;
  final VoidCallback? onRefresh;
  final Function(DailyBiometricLogModel)? onLogBiometrics;

  const ReadinessGaugeCard({
    super.key,
    required this.readiness,
    this.onRefresh,
    this.onLogBiometrics,
  });

  void _showBiometricsModal(BuildContext context) {
    double currentHours = 7.5;
    int currentQuality = 4;
    int currentStress = 2;
    int currentSoreness = 2;
    bool currentJointPain = false;
    final notesController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final theme = Theme.of(modalCtx);
            final isDark = theme.brightness == Brightness.dark;
            final bg = isDark ? const Color(0xFF1E222D) : Colors.white;

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.bedtime_rounded,
                              color: Color(0xFF10B981),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Calibrar Prontidão Diária',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Horas de Sono: ${currentHours.toStringAsFixed(1)}h',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Slider(
                        value: currentHours,
                        min: 3.0,
                        max: 12.0,
                        divisions: 18,
                        activeColor: const Color(0xFF10B981),
                        label: '${currentHours.toStringAsFixed(1)}h',
                        onChanged: (val) {
                          setModalState(() => currentHours = val);
                        },
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Qualidade do Sono (1 a 5):',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: List.generate(5, (index) {
                          final star = index + 1;
                          final isSelected = star <= currentQuality;
                          return IconButton(
                            icon: Icon(
                              isSelected ? Icons.star_rounded : Icons.star_outline_rounded,
                              color: isSelected ? Colors.amber : Colors.grey,
                              size: 32,
                            ),
                            onPressed: () {
                              setModalState(() => currentQuality = star);
                            },
                          );
                        }),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Dor ou Desconforto Articular?',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Switch(
                            value: currentJointPain,
                            activeColor: Colors.redAccent,
                            onChanged: (v) {
                              setModalState(() => currentJointPain = v);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Nível de Dor Muscular Tardia (DOMS): $currentSoreness / 5',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Slider(
                        value: currentSoreness.toDouble(),
                        min: 1.0,
                        max: 5.0,
                        divisions: 4,
                        activeColor: Colors.deepOrange,
                        label: '$currentSoreness',
                        onChanged: (v) {
                          setModalState(() => currentSoreness = v.round());
                        },
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: notesController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'Observações (ex: dormi tarde, cafeína antes de deitar...)',
                          filled: true,
                          fillColor: isDark ? const Color(0xFF282E3E) : Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            final log = DailyBiometricLogModel(
                              sleepHours: currentHours,
                              sleepQuality: currentQuality,
                              perceivedStress: currentStress,
                              sorenessLevel: currentSoreness,
                              hasJointPain: currentJointPain,
                              notes: notesController.text.trim().isEmpty
                                  ? null
                                  : notesController.text.trim(),
                            );
                            Navigator.pop(ctx);
                            onLogBiometrics?.call(log);
                          },
                          child: const Text(
                            'Salvar e Atualizar Score',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = readiness.scoreColor;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1F2C) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.bolt_rounded, size: 16, color: color),
                        const SizedBox(width: 4),
                        Text(
                          readiness.levelLabel,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (onRefresh != null)
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  onPressed: onRefresh,
                  tooltip: 'Atualizar Prontidão',
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Score circular gauge
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 76,
                    height: 76,
                    child: CircularProgressIndicator(
                      value: readiness.score / 100.0,
                      strokeWidth: 8,
                      backgroundColor: color.withValues(alpha: 0.15),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${readiness.score}',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: color,
                        ),
                      ),
                      const Text(
                        'READINESS',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      readiness.headline,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      readiness.recommendation,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Factors row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF242A38) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildFactorItem(
                  icon: Icons.nightlight_round,
                  label: 'Sono',
                  factor: readiness.sleepFactor,
                  isDark: isDark,
                ),
                _buildFactorItem(
                  icon: Icons.fitness_center_rounded,
                  label: 'Fadiga RPE',
                  factor: readiness.fatigueFactor,
                  isDark: isDark,
                ),
                _buildFactorItem(
                  icon: Icons.healing_rounded,
                  label: 'Articular',
                  factor: readiness.jointFactor,
                  isDark: isDark,
                  alertWhenNegative: true,
                ),
                _buildFactorItem(
                  icon: Icons.local_fire_department_rounded,
                  label: 'Streak',
                  factor: readiness.streakFactor,
                  isDark: isDark,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.edit_calendar_rounded, size: 16),
              label: const Text(
                'Registrar Sono & Prontidão',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: color,
                side: BorderSide(color: color.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => _showBiometricsModal(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFactorItem({
    required IconData icon,
    required String label,
    required double factor,
    required bool isDark,
    bool alertWhenNegative = false,
  }) {
    Color factorColor = Colors.grey;
    if (factor > 0) {
      factorColor = const Color(0xFF10B981);
    } else if (factor < 0) {
      factorColor = alertWhenNegative ? const Color(0xFFEF4444) : const Color(0xFFF59E0B);
    }

    final sign = factor > 0 ? '+' : '';
    final factorText = factor == 0 ? '0' : '$sign${factor.toInt()}';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: factorColor),
            const SizedBox(width: 4),
            Text(
              factorText,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: factorColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}
