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
      'title': 'Considerando sua avaliação',
      'detail': 'Levando em conta objetivos e restrições.',
      'icon': Icons.health_and_safety_outlined,
    },
    {
      'title': 'Equilibrando exercícios e volume',
      'detail': 'Dosando estímulo e recuperação.',
      'icon': Icons.fitness_center_rounded,
    },
    {
      'title': 'Organizando seus dias de treino',
      'detail': 'Distribuindo os grupos musculares.',
      'icon': Icons.auto_awesome,
    },
    {
      'title': 'Revisando sua ficha',
      'detail': 'Conferindo os últimos detalhes.',
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
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, _) {
                        return SizedBox(
                          width: 56,
                          height: 56,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              const CircularProgressIndicator(
                                semanticsLabel: 'Preparando ficha de treino',
                                strokeWidth: 2.5,
                                backgroundColor: MetaColors.surfaceHighlight,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  MetaColors.emerald,
                                ),
                              ),
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: MetaColors.emerald.withValues(
                                    alpha: 0.08 + _pulseController.value * 0.08,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Transform.scale(
                                    scale: 0.9 + _pulseController.value * 0.1,
                                    child: AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 350),
                                      transitionBuilder: (child, animation) =>
                                          FadeTransition(
                                        opacity: animation,
                                        child: ScaleTransition(
                                          scale: animation,
                                          child: child,
                                        ),
                                      ),
                                      child: Icon(
                                        _steps[_currentStep]['icon'] as IconData,
                                        key: ValueKey<int>(_currentStep),
                                        color: MetaColors.emerald,
                                        size: 21,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PREPARANDO SEU TREINO',
                            style: TextStyle(
                              color: MetaColors.emerald,
                              fontSize: 11,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Montando uma ficha personalizada',
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
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOutCubic,
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? MetaColors.emerald.withValues(alpha: 0.07)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 350),
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
                                  AnimatedDefaultTextStyle(
                                    duration: const Duration(milliseconds: 300),
                                    style: TextStyle(
                                      color: isPending
                                          ? MetaColors.textSecondary
                                          : MetaColors.textPrimary,
                                      fontSize: 15,
                                      fontWeight: isCompleted || isCurrent
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                    ),
                                    child: Text(_steps[index]['title'] as String),
                                  ),
                                  const SizedBox(height: 2),
                                  AnimatedDefaultTextStyle(
                                    duration: const Duration(milliseconds: 300),
                                    style: TextStyle(
                                      color: isCurrent
                                          ? MetaColors.emerald
                                          : MetaColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                    child: Text(_steps[index]['detail'] as String),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: const LinearProgressIndicator(
                    backgroundColor: MetaColors.surfaceHighlight,
                    valueColor: const AlwaysStoppedAnimation<Color>(MetaColors.emerald),
                    minHeight: 4,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Seu treino está sendo preparado. Isso pode levar alguns instantes.',
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
