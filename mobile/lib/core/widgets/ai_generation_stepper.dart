import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AIGenerationStepper extends StatefulWidget {
  final VoidCallback? onCancel;

  const AIGenerationStepper({super.key, this.onCancel});

  @override
  State<AIGenerationStepper> createState() => _AIGenerationStepperState();
}

class _AIGenerationStepperState extends State<AIGenerationStepper>
    with SingleTickerProviderStateMixin {
  int _currentStep = 0;
  Timer? _stepTimer;
  late AnimationController _pulseController;

  final List<Map<String, dynamic>> _steps = [
    {
      'title': 'Analisando Restrições Articulares',
      'detail': 'Filtrando contraindicações de ombro, lombar e joelhos...',
      'icon': Icons.health_and_safety_outlined,
    },
    {
      'title': 'Calculando Volume & Sinergistas',
      'detail': 'Balanceando séries semanais e recuperação muscular...',
      'icon': Icons.fitness_center_rounded,
    },
    {
      'title': 'Estruturando Splits Biomecânicos',
      'detail': 'Determinando vetores de empurrar, puxar e pernas...',
      'icon': Icons.auto_awesome,
    },
    {
      'title': 'Formatando Periodização Estrita',
      'detail': 'Validando esquema clínico para liberação ao aluno...',
      'icon': Icons.verified_outlined,
    },
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _stepTimer = Timer.periodic(const Duration(milliseconds: 2200), (timer) {
      if (_currentStep < _steps.length - 1) {
        setState(() {
          _currentStep++;
        });
      }
    });
  }

  @override
  void dispose() {
    _stepTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.75),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.trainerSurface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.trainerBorder, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: AppColors.trainerEmeraldGlow.withValues(alpha: 0.2),
                blurRadius: 32,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.trainerEmerald.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      color: AppColors.trainerEmerald,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PRESCRIÇÃO COM IA CLÍNICA',
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w700,
                            color: AppColors.trainerEmerald,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Engenharia Biomecânica em Execução',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // List of animated steps
              ...List.generate(_steps.length, (index) {
                final isDone = index < _currentStep;
                final isCurrent = index == _currentStep;
                final item = _steps[index];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              isDone
                                  ? AppColors.trainerEmerald
                                  : (isCurrent
                                      ? AppColors.trainerEmerald.withValues(
                                        alpha: 0.2,
                                      )
                                      : AppColors.trainerBorder),
                          border: Border.all(
                            color:
                                isDone || isCurrent
                                    ? AppColors.trainerEmerald
                                    : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child:
                              isDone
                                  ? const Icon(
                                    Icons.check,
                                    size: 16,
                                    color: Colors.black,
                                  )
                                  : (isCurrent
                                      ? const SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                AppColors.trainerEmerald,
                                              ),
                                        ),
                                      )
                                      : Text(
                                        '${index + 1}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textMuted,
                                        ),
                                      )),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['title'] as String,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight:
                                    isCurrent
                                        ? FontWeight.bold
                                        : FontWeight.w600,
                                color:
                                    isDone || isCurrent
                                        ? AppColors.textPrimary
                                        : AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item['detail'] as String,
                              style: TextStyle(
                                fontSize: 11,
                                color:
                                    isCurrent
                                        ? AppColors.trainerEmerald
                                        : AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: (_currentStep + 1) / _steps.length,
                backgroundColor: AppColors.trainerBorder,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.trainerEmerald,
                ),
                minHeight: 4,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 12),
              const Center(
                child: Text(
                  'Conectando ao Google Gemini 3.8 com redundância ativa...',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
