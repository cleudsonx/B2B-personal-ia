import 'package:flutter/material.dart';

import '../../core/widgets/meta_components.dart';

class StudentDemoScreen extends StatefulWidget {
  const StudentDemoScreen({super.key});

  @override
  State<StudentDemoScreen> createState() => _StudentDemoScreenState();
}

class _StudentDemoScreenState extends State<StudentDemoScreen> {
  final Set<int> _completedExercises = {};

  static const _exercises = [
    ('Supino máquina', 'Peitoral', '3 séries  ·  12 repetições'),
    ('Remada baixa', 'Costas', '3 séries  ·  12 repetições'),
    ('Agachamento guiado', 'Pernas', '3 séries  ·  10 repetições'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MetaColors.background,
      appBar: AppBar(
        backgroundColor: MetaColors.background,
        title: const Text('Área do aluno'),
        leading: IconButton(
          tooltip: 'Voltar',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.maybePop(context),
        ),
        actions: [
          IconButton(
            tooltip: 'Reiniciar demonstração',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => setState(_completedExercises.clear),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: MetaColors.emerald.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: MetaColors.emerald.withValues(alpha: 0.35),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.visibility_outlined, size: 16, color: MetaColors.emerald),
                      SizedBox(width: 8),
                      Text(
                        'DEMONSTRAÇÃO · DADOS FICTÍCIOS',
                        style: TextStyle(
                          color: MetaColors.emerald,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Olá, Camila',
                  style: TextStyle(
                    color: MetaColors.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Seu treino de hoje está pronto.',
                  style: TextStyle(color: MetaColors.textSecondary, fontSize: 15),
                ),
                const SizedBox(height: 24),
                MetaCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.fitness_center_rounded, color: MetaColors.emerald),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Treino A · Corpo inteiro',
                              style: TextStyle(
                                color: MetaColors.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_completedExercises.length} de ${_exercises.length} exercícios concluídos',
                        style: const TextStyle(color: MetaColors.textSecondary),
                      ),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: _completedExercises.length / _exercises.length,
                        color: MetaColors.emerald,
                        backgroundColor: MetaColors.surfaceHighlight,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                for (var index = 0; index < _exercises.length; index++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: MetaCard(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Checkbox.adaptive(
                            value: _completedExercises.contains(index),
                            activeColor: MetaColors.emerald,
                            onChanged: (value) => setState(() {
                              if (value == true) {
                                _completedExercises.add(index);
                              } else {
                                _completedExercises.remove(index);
                              }
                            }),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _exercises[index].$1,
                                  style: const TextStyle(
                                    color: MetaColors.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_exercises[index].$2}  ·  ${_exercises[index].$3}',
                                  style: const TextStyle(
                                    color: MetaColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.more_horiz_rounded, color: MetaColors.textSecondary),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/home'),
                    icon: const Icon(Icons.login_rounded),
                    label: const Text('Acessar plataforma'),
                    style: FilledButton.styleFrom(
                      backgroundColor: MetaColors.emerald,
                      foregroundColor: Colors.black,
                    ),
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