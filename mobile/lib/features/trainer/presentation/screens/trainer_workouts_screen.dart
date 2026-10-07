import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/widgets/meta_components.dart';
import '../../../../services/workout_service.dart';
import '../../anamnesis_screen.dart';

/// Modelo de dados mockado para fichas de treino recentes
class _RecentWorkoutItem {
  final String id;
  final String studentName;
  final String workoutTitle;
  final String splitInfo;
  final String statusText;
  final bool isExpired;
  final String initials;
  final bool useClipboardIcon;
  final Map<String, dynamic>? rawWorkout;

  const _RecentWorkoutItem({
    this.rawWorkout,
    required this.id,
    required this.studentName,
    required this.workoutTitle,
    required this.splitInfo,
    required this.statusText,
    required this.isExpired,
    required this.initials,
    this.useClipboardIcon = false,
  });
}

/// Aba 2 do Professor (Treinos) no padrão WhatsApp Business / Meta Design System
class TrainerWorkoutsScreen extends StatefulWidget {
  const TrainerWorkoutsScreen({super.key});

  @override
  State<TrainerWorkoutsScreen> createState() => _TrainerWorkoutsScreenState();
}

class _TrainerWorkoutsScreenState extends State<TrainerWorkoutsScreen> {
  List<_RecentWorkoutItem> _recentWorkouts = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadWorkouts();
  }

  Future<void> _loadWorkouts() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });
    try {
      final workouts = await WorkoutService.getTrainerWorkouts();
      if (mounted) {
        setState(() {
          _recentWorkouts = workouts.map((w) {
            final client = w['profiles'] ?? {};
            final clientName = client['full_name'] as String? ?? 'Aluno';
            final title = w['title'] as String? ?? 'Ficha de Treino';
            final updatedAt = w['updated_at'] as String?;
            
            // Format updated_at roughly
            String status = 'Atualizada recentemente';
            bool expired = false;
            if (updatedAt != null) {
              final date = DateTime.tryParse(updatedAt);
              if (date != null) {
                final diff = DateTime.now().difference(date);
                if (diff.inDays > 30) {
                  expired = true;
                  status = 'Vencida há ${diff.inDays} dias';
                } else if (diff.inDays > 0) {
                  status = 'Atualizada há ${diff.inDays} dias';
                } else {
                  status = 'Atualizada hoje';
                }
              }
            }

            // Initials
            String initials = 'AL';
            final parts = clientName.trim().split(RegExp(r'\s+'));
            if (parts.isNotEmpty) {
              if (parts.length == 1) {
                initials = parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
              } else {
                initials = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
              }
            }

            return _RecentWorkoutItem(
              id: w['id'] ?? '',
              studentName: clientName,
              workoutTitle: title,
              splitInfo: w['notes_for_trainer'] as String? ?? 'Sem notas',
              statusText: status,
              isExpired: expired,
              initials: initials,
              useClipboardIcon: clientName == 'Aluno',
              rawWorkout: w,
            );
          }).toList();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToCreateWorkout({String? studentName}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TrainerAnamnesisScreen(
          initialStudentName: studentName,
        ),
      ),
    );
  }

  void _showAssessmentDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: MetaColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.paddingOf(ctx).bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: MetaColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Avaliação Física & Biomecânica',
                style: TextStyle(
                  color: MetaColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Escolha o tipo de teste para registrar e vincular à periodização do aluno.',
                style: TextStyle(
                  color: MetaColors.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 20),
              SquircleButton(
                icon: Icons.fitness_center,
                label: 'Nova Avaliação Biomecânica',
                isPrimary: true,
                onPressed: () {
                  Navigator.pop(ctx);
                  _navigateToCreateWorkout();
                },
              ),
              const SizedBox(height: 10),
              SquircleButton(
                icon: Icons.monitor_weight_outlined,
                label: 'Composição Corporal & Cargas',
                isPrimary: false,
                onPressed: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: MetaColors.surfaceHighlight,
                      content: Text(
                        'Módulo de Composição Corporal selecionado.',
                        style: TextStyle(color: MetaColors.textPrimary),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showWorkoutDetails(_RecentWorkoutItem workout) {
    showModalBottomSheet(
      context: context,
      backgroundColor: MetaColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.paddingOf(ctx).bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: MetaColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: MetaColors.surfaceHighlight,
                    child: workout.useClipboardIcon
                        ? const Icon(
                            Icons.assignment_outlined,
                            color: MetaColors.emerald,
                            size: 24,
                          )
                        : Text(
                            workout.initials,
                            style: const TextStyle(
                              color: MetaColors.emerald,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          workout.studentName,
                          style: const TextStyle(
                            color: MetaColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          workout.workoutTitle,
                          style: const TextStyle(
                            color: MetaColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: MetaColors.surfaceHighlight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: MetaColors.border),
                ),
                child: Row(
                  children: [
                    Icon(
                      workout.isExpired
                          ? Icons.call_missed_rounded
                          : Icons.call_made_rounded,
                      color: workout.isExpired
                          ? const Color(0xFFEF4444)
                          : MetaColors.emerald,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        workout.isExpired
                            ? '${workout.statusText} • Necessita renovação'
                            : '${workout.statusText} • Ficha ativa no prazo',
                        style: TextStyle(
                          color: workout.isExpired
                              ? const Color(0xFFEF4444)
                              : MetaColors.emerald,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SquircleButton(
                icon: Icons.edit_note_rounded,
                label: 'Ajustar Ficha com IA',
                isPrimary: true,
                onPressed: () {
                  Navigator.pop(ctx);
                  _navigateToCreateWorkout(studentName: workout.studentName);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(36),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: MetaColors.surfaceHighlight,
                shape: BoxShape.circle,
                border: Border.all(
                  color: MetaColors.border,
                  width: 1.0,
                ),
              ),
              child: Icon(
                icon,
                color: MetaColors.emerald,
                size: 26,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: MetaColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: MetaColors.background,
        body: Stack(
          children: [
            CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                // Topo da tela: Título e Ações Rápidas em Círculos
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: topPadding + 16,
                      left: 20,
                      right: 20,
                      bottom: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Treinos',
                          style: TextStyle(
                            color: MetaColors.textPrimary,
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Topo (Ações Rápidas em Círculos estilo WhatsApp Ligações)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildQuickActionButton(
                              icon: Icons.post_add,
                              label: 'Nova Ficha',
                              onTap: () => _navigateToCreateWorkout(),
                            ),
                            _buildQuickActionButton(
                              icon: Icons.fitness_center,
                              label: 'Avaliação',
                              onTap: _showAssessmentDialog,
                            ),
                            _buildQuickActionButton(
                              icon: Icons.auto_awesome,
                              label: 'IA',
                              onTap: () => _navigateToCreateWorkout(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Seção "Fichas Recentes": Título
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: 20,
                      right: 20,
                      top: 16,
                      bottom: 8,
                    ),
                    child: Text(
                      'Fichas Recentes',
                      style: TextStyle(
                        color: MetaColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ),

                // Lista de Fichas Recentes (ListView sem Divider, fundo transparente)
                SliverPadding(
                  padding: EdgeInsets.only(
                    left: 8,
                    right: 8,
                    bottom: bottomPadding + 88,
                  ),
                  sliver: _isLoading 
                  ? const SliverFillRemaining(
                      child: Center(
                        child: CircularProgressIndicator(color: MetaColors.emerald),
                      ),
                    )
                  : _hasError
                    ? SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                              const SizedBox(height: 16),
                              Text('Erro ao carregar treinos:\n$_errorMessage', textAlign: TextAlign.center, style: const TextStyle(color: MetaColors.textSecondary)),
                              const SizedBox(height: 16),
                              ElevatedButton(onPressed: _loadWorkouts, child: const Text('Tentar Novamente')),
                            ],
                          ),
                        ),
                      )
                    : _recentWorkouts.isEmpty 
                      ? const SliverFillRemaining(
                          child: Center(
                            child: Text(
                              'Nenhum treino encontrado.',
                              style: TextStyle(color: MetaColors.textSecondary, fontSize: 16),
                            ),
                          ),
                        )
                      : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final workout = _recentWorkouts[index];
                        return Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            onTap: () => _showWorkoutDetails(workout),
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                tileColor: Colors.transparent,
                                leading: CircleAvatar(
                                  radius: 24,
                                  backgroundColor: MetaColors.surfaceHighlight,
                                  child: workout.useClipboardIcon
                                      ? const Icon(
                                          Icons.assignment_outlined,
                                          color: MetaColors.emerald,
                                          size: 22,
                                        )
                                      : Text(
                                          workout.initials,
                                          style: const TextStyle(
                                            color: MetaColors.emerald,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                ),
                                title: Text(
                                  '${workout.studentName} • ${workout.workoutTitle}',
                                  style: const TextStyle(
                                    color: MetaColors.textPrimary,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 16,
                                  ),
                                ),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Row(
                                    children: [
                                      Icon(
                                        workout.isExpired
                                            ? Icons.call_missed_rounded
                                            : Icons.call_made_rounded,
                                        size: 14,
                                        color: workout.isExpired
                                            ? const Color(0xFFEF4444)
                                            : MetaColors.emerald,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          workout.statusText,
                                          style: TextStyle(
                                            color: workout.isExpired
                                                ? const Color(0xFFEF4444)
                                                : MetaColors.textSecondary,
                                            fontSize: 13,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                trailing: const Icon(
                                  Icons.chevron_right_rounded,
                                  color: MetaColors.textSecondary,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                      childCount: _recentWorkouts.length,
                    ),
                  ),
                ),
              ],
            ),

            // FAB (Botão Principal): SquircleButton no canto inferior direito
            Positioned(
              right: 16,
              bottom: bottomPadding + 16,
              child: SquircleButton(
                icon: Icons.add,
                label: 'Criar',
                isPrimary: true,
                onPressed: () => _navigateToCreateWorkout(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
