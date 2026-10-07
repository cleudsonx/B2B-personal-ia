import re

path = 'mobile/lib/features/trainer/presentation/screens/student_details_screen.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Replace state fields
state_replacement = '''
  late Map<String, dynamic> student;
  bool _isLoadingWorkout = true;
  var _activeWorkout; // WorkoutPlanModel?

  @override
  void initState() {
    super.initState();
    student = widget.studentData;
    _fetchWorkout();
  }

  Future<void> _fetchWorkout() async {
    try {
      final workout = await WorkoutService.getActiveWorkoutForClient(clientId: student['id']);
      if (mounted) {
        setState(() {
          _activeWorkout = workout;
          _isLoadingWorkout = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingWorkout = false;
        });
      }
    }
  }
'''

content = re.sub(
    r'  late Map<String, dynamic> student;\n  bool _hasActiveWorkout = false; // Mock, in the future this will be fetched from API\n\n  @override\n  void initState\(\) {\n    super.initState\(\);\n    student = widget.studentData;\n    _hasActiveWorkout = student\[\'status\'\] == \'Ativo\'; \n  }',
    state_replacement.strip(),
    content
)

if "import '../../../../services/workout_service.dart';" not in content:
    content = "import '../../../../services/workout_service.dart';\n" + content

# Replace uses of _hasActiveWorkout in gamification
content = content.replace('if (_hasActiveWorkout)', 'if (!_isLoadingWorkout && _activeWorkout != null)')

# We will just replace 'if (!_hasActiveWorkout)' with 'if (_isLoadingWorkout)' logic
old_chunk = '''              if (!_hasActiveWorkout)
                MetaCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Icon(Icons.fitness_center, color: MetaColors.textSecondary, size: 48),
                      const SizedBox(height: 16),
                      const Text(
                        'Nenhuma ficha ativa ainda.',
                        style: TextStyle(color: MetaColors.textSecondary, fontSize: 16),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: SquircleButton(
                          label: '✨ Prescrever com IA em 30s',
                          isPrimary: true,
                          onPressed: () {
                            // TODO: Navegar para geração de treino
                          },
                        ),
                      ),
                    ],
                  ),
                )
              else
                MetaCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ficha Atual',
                        style: TextStyle(color: MetaColors.textSecondary, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Treino ABC - Hipertrofia',
                        style: TextStyle(color: MetaColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Atualizada há 12 dias',
                        style: TextStyle(color: MetaColors.emerald, fontSize: 14),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: SquircleButton(
                              label: 'Ver/Ajustar',
                              icon: Icons.visibility,
                              isPrimary: true,
                              onPressed: () {},
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SquircleButton(
                              label: 'Renovar',
                              icon: Icons.refresh,
                              isPrimary: false,
                              onPressed: () {},
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          label: const Text('Excluir Ficha', style: TextStyle(color: Colors.redAccent)),
                        ),
                      ),
                    ],
                  ),
                ),'''

new_chunk = '''              if (_isLoadingWorkout)
                const Center(child: CircularProgressIndicator(color: MetaColors.emerald))
              else if (_activeWorkout == null)
                MetaCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Icon(Icons.fitness_center, color: MetaColors.textSecondary, size: 48),
                      const SizedBox(height: 16),
                      const Text(
                        'Nenhuma ficha ativa ainda.',
                        style: TextStyle(color: MetaColors.textSecondary, fontSize: 16),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: SquircleButton(
                          label: '✨ Prescrever com IA em 30s',
                          isPrimary: true,
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Integração em andamento...')));
                          },
                        ),
                      ),
                    ],
                  ),
                )
              else
                MetaCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ficha Atual',
                        style: TextStyle(color: MetaColors.textSecondary, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _activeWorkout.workoutPlanTitle ?? 'Periodização',
                        style: const TextStyle(color: MetaColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Ativa',
                        style: TextStyle(color: MetaColors.emerald, fontSize: 14),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: SquircleButton(
                              label: 'Ver/Ajustar',
                              icon: Icons.visibility,
                              isPrimary: true,
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Visualização em breve')));
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SquircleButton(
                              label: 'Renovar',
                              icon: Icons.refresh,
                              isPrimary: false,
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Em breve')));
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton.icon(
                          onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não suportado ainda')));
                          },
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          label: const Text('Excluir Ficha', style: TextStyle(color: Colors.redAccent)),
                        ),
                      ),
                    ],
                  ),
                ),'''

content = content.replace(old_chunk, new_chunk)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
