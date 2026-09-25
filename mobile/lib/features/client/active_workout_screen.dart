import 'package:flutter/material.dart';
import '../../models/exercise_model.dart';
import '../../models/adaptation_model.dart';
import '../../services/api_service.dart';

class ActiveWorkoutScreen extends StatefulWidget {
  const ActiveWorkoutScreen({super.key});

  @override
  State<ActiveWorkoutScreen> createState() => _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends State<ActiveWorkoutScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = false;

  // Lista de exercícios de demonstração inicial
  late List<ExerciseModel> _exercises;

  @override
  void initState() {
    super.initState();
    _exercises = [
      const ExerciseModel(
        order: 1,
        name: 'Supino Reto com Barra',
        targetMuscleGroup: 'Peitoral Maior',
        sets: 4,
        reps: '8-10',
        restSeconds: 90,
        notes: 'Manter escápulas aduzidas e descer até a linha do esterno.',
        substitutionVector: 'Empurrar horizontal livre',
      ),
      const ExerciseModel(
        order: 2,
        name: 'Desenvolvimento Máquina Articulada',
        targetMuscleGroup: 'Deltoide Anterior/Lateral',
        sets: 3,
        reps: '10-12',
        restSeconds: 60,
        notes: 'Ajustar altura do banco para que as pegadas fiquem na linha do queixo.',
        substitutionVector: 'Empurrar vertical guiado',
      ),
      const ExerciseModel(
        order: 3,
        name: 'Tríceps Polia com Barra Reta',
        targetMuscleGroup: 'Tríceps Braquial',
        sets: 4,
        reps: '12-15',
        restSeconds: 45,
        notes: 'Cotovelos fixos ao lado do tronco durante toda a extensão.',
        substitutionVector: 'Extensão de cotovelos cabo',
      ),
    ];
  }

  void _showAdaptationModal(int exerciseIndex) {
    final currentExercise = _exercises[exerciseIndex];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.bolt, color: Colors.amber, size: 28),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Substituir: ${currentExercise.name}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'A IA encontrará uma variação biomecanicamente idêntica ou mais confortável:',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  icon: const Icon(Icons.people_outline),
                  label: const Text('Aparelho Ocupado / Fila'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _executeAdaptation(exerciseIndex, 'Aparelho Ocupado / Fila');
                  },
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.health_and_safety_outlined, color: Colors.orange),
                  label: const Text(
                    'Desconforto ou Dor Articular',
                    style: TextStyle(color: Colors.orange),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Colors.orange),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _executeAdaptation(exerciseIndex, 'Desconforto ou Dor Articular');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _executeAdaptation(int index, String reason) async {
    setState(() => _isLoading = true);
    final target = _exercises[index];

    try {
      final AdaptationModel result = await _apiService.adaptExercise(
        currentExercise: target.name,
        reason: reason,
        workoutLocation: 'Academia completa',
        injuriesOrRestrictions: 'Histórico de leve desconforto no ombro',
      );

      setState(() {
        _exercises[index] = target.copyWith(
          name: result.adaptedExercise,
          sets: result.sets,
          reps: result.reps,
          restSeconds: result.restSeconds,
          notes: '${result.notes}\n[IA: ${result.biomechanicalRationale}]',
        );
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green.shade800,
            content: Text('Substituído com sucesso: ${result.adaptedExercise}'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade800,
            content: Text('Erro ao adaptar exercício: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Treino A - Peito e Tríceps'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Instruções',
            onPressed: () {},
          ),
        ],
      ),
      body: Stack(
        children: [
          ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _exercises.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = _exercises[index];
              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${item.order}. ${item.name}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.swap_horiz, color: Colors.blueAccent),
                            tooltip: 'Trocar exercício com IA',
                            onPressed: () => _showAdaptationModal(index),
                          ),
                        ],
                      ),
                      Text(
                        item.targetMuscleGroup,
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _MetricChip(label: 'Séries', value: '${item.sets}'),
                          _MetricChip(label: 'Reps', value: item.reps),
                          _MetricChip(label: 'Descanso', value: '${item.restSeconds}s'),
                        ],
                      ),
                      if (item.notes.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            item.notes,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
          if (_isLoading)
            Container(
              color: Colors.black45,
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Consultando IA biomecânica...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;

  const _MetricChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
