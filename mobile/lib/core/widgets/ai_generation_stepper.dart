import 'dart:async';
import 'package:flutter/material.dart';
import 'meta_components.dart';

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
      'detail': 'Filtrando contraindicações e histórico...',
      'icon': Icons.health_and_safety_outlined,
    },
    {
      'title': 'Calculando Volume e Sinergistas',
      'detail': 'Balanceando séries e recuperação muscular...',
      'icon': Icons.fitness_center_rounded,
    },
    {
      'title': 'Estruturando Splits Biomecânicos',
      'detail': 'Determinando vetores e divisão do treino...',
      'icon': Icons.auto_awesome,
    },
    {
      'title': 'Formatando Periodização',
      'detail': 'Validando esquema clínico para liberação...',
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
      if (!mounted) return;
      if (_currentStep < _steps.length - 1) {
        setState(() {
          _currentStep++;
        });
      } else {
        timer.cancel();
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
      color: Colors.black87,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: MetaCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: MetaColors.surfaceHighlight,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        color: MetaColors.emerald,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'IA CLÍNICA',
                            style: TextStyle(
                              color: MetaColors.emerald,
                              fontSize: 11,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Engenharia Biomecânica',
                            style: TextStyle(
                              color: MetaColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Passos
                ...List.generate(_steps.length, (index) {
                  final isCompleted = index < _currentStep;
                  final isCurrent = index == _currentStep;
                  final isPending = index > _currentStep;

                  Color iconBgColor = MetaColors.surfaceHighlight;
                  Color iconColor = MetaColors.textSecondary;
                  Widget iconWidget = Icon(_steps[index]['icon'], size: 16, color: iconColor);

                  if (isCompleted) {
                    iconBgColor = MetaColors.emerald;
                    iconColor = Colors.black;
                    iconWidget = Icon(Icons.check, size: 16, color: iconColor);
                  } else if (isCurrent) {
                    iconBgColor = MetaColors.surfaceHighlight;
                    iconColor = MetaColors.emerald;
                    iconWidget = AnimatedBuilder(
                      animation: _pulseController,
                      builder: (_, child) {
                        return Transform.scale(
                          scale: 0.8 + (_pulseController.value * 0.2),
                          child: Icon(_steps[index]['icon'], size: 16, color: iconColor),
                        );
                      },
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: iconBgColor,
                            shape: BoxShape.circle,
                          ),
                          child: Center(child: iconWidget),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _steps[index]['title'],
                                style: TextStyle(
                                  color: isPending ? MetaColors.textSecondary : MetaColors.textPrimary,
                                  fontSize: 15,
                                  fontWeight: isCompleted || isCurrent ? FontWeight.w600 : FontWeight.w400,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _steps[index]['detail'],
                                style: TextStyle(
                                  color: isCurrent ? MetaColors.emerald : MetaColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (_currentStep + 1) / _steps.length,
                    backgroundColor: MetaColors.surfaceHighlight,
                    valueColor: const AlwaysStoppedAnimation<Color>(MetaColors.emerald),
                    minHeight: 4,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Conectando ao Google Gemini 3.8 com redundância ativa...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: MetaColors.textSecondary,
                    fontSize: 11,
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
