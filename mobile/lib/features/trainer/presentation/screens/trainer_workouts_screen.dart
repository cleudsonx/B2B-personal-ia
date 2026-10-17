import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/widgets/meta_components.dart';
import '../../../../services/workout_service.dart';
import '../../anamnesis_screen.dart';

enum _WorkoutFilter { all, onTrack, attention }

/// Modelo de dados para fichas de treino prescritas
class _RecentWorkoutItem {
  final String id;
  final String? studentId;
  final String studentName;
  final String workoutTitle;
  final String splitInfo;
  final String statusText;
  final int daysElapsed;
  final bool isExpired;
  final bool isExpiringSoon;
  final String initials;
  final bool useClipboardIcon;
  final String? photoUrl;
  final Map<String, dynamic>? rawWorkout;

  const _RecentWorkoutItem({
    this.rawWorkout,
    required this.id,
    this.studentId,
    required this.studentName,
    required this.workoutTitle,
    required this.splitInfo,
    required this.statusText,
    required this.daysElapsed,
    required this.isExpired,
    required this.isExpiringSoon,
    required this.initials,
    this.useClipboardIcon = false,
    this.photoUrl,
  });

  bool get needsAttention => isExpired || isExpiringSoon;
}

/// Aba 2 do Professor (Treinos) — Cockpit de Prescrição & Vigência (Meta Design System)
class TrainerWorkoutsScreen extends StatefulWidget {
  const TrainerWorkoutsScreen({super.key});

  @override
  State<TrainerWorkoutsScreen> createState() => _TrainerWorkoutsScreenState();
}

class _TrainerWorkoutsScreenState extends State<TrainerWorkoutsScreen> {
  List<_RecentWorkoutItem> _recentWorkouts = [];
  List<Map<String, dynamic>> _pendingStudents = [];
  _WorkoutFilter _selectedFilter = _WorkoutFilter.all;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    WorkoutService.studentsRefreshNotifier.addListener(_onExternalRefresh);
    _loadWorkouts();
  }

  @override
  void dispose() {
    WorkoutService.studentsRefreshNotifier.removeListener(_onExternalRefresh);
    super.dispose();
  }

  void _onExternalRefresh() {
    if (mounted) _loadWorkouts();
  }

  Future<void> _loadWorkouts() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });
    try {
      final workouts = await WorkoutService.getTrainerWorkouts();
      final students = await WorkoutService.getTrainerStudents();

      // Identifica apenas alunos com cadastro ativo que estão aguardando periodização (sem ficha ativa)
      // Alunos com convite pendente / aguardando cadastro ou arquivados NÃO entram aqui!
      final activeStudentIds = workouts
          .where((w) => w['is_active'] == true)
          .map((w) => w['client_id']?.toString())
          .toSet();

      final pending = students.where((s) {
        final sid = s['id']?.toString();
        final hasActive = s['has_active_prescription'] == true;
        final status = (s['status'] as String? ?? '').toLowerCase();
        final recentStatus = (s['recent_status'] as String? ?? '').toLowerCase();
        final isPendingInvite = status.contains('pendente') ||
            recentStatus.contains('pendente') ||
            recentStatus.contains('cadastro') ||
            status.contains('pending');
        final isArchived = status.contains('arquivado') ||
            status.contains('inativo') ||
            recentStatus.contains('arquivado');

        return !hasActive &&
            !activeStudentIds.contains(sid) &&
            !isPendingInvite &&
            !isArchived;
      }).toList();

      // Indexar alunos para fallback de fotos e dados completos
      final studentMap = {for (final s in students) s['id']?.toString(): s};

      if (mounted) {
        setState(() {
          _pendingStudents = pending;
          final parsedList = workouts.map((w) {
            final client = w['profiles'] ?? {};
            final clientId = w['client_id']?.toString();
            final stProfile = studentMap[clientId];
            final clientName = (client['full_name'] as String?) ??
                (stProfile?['full_name'] as String?) ??
                'Aluno';
            final photoUrl = (client['photo_url'] ??
                client['avatar_url'] ??
                stProfile?['photo_url'] ??
                stProfile?['avatar_url']) as String?;
            final title = w['title'] as String? ?? 'Ficha de Treino';
            final updatedAt = (w['updated_at'] ?? w['created_at']) as String?;

            String status = 'Em dia • Atualizada recentemente';
            bool expired = false;
            bool expiringSoon = false;
            int daysElapsed = 0;

            if (updatedAt != null) {
              final date = DateTime.tryParse(updatedAt);
              if (date != null) {
                daysElapsed = DateTime.now().difference(date).inDays;
                if (daysElapsed < 0) daysElapsed = 0;
                if (daysElapsed > 30) {
                  expired = true;
                  status = 'Vencida há ${daysElapsed - 30}d (ciclo ${daysElapsed}d)';
                } else if (daysElapsed >= 23) {
                  expiringSoon = true;
                  final remaining = 30 - daysElapsed;
                  status = 'Renovação em ${remaining}d (dia $daysElapsed/30)';
                } else if (daysElapsed > 0) {
                  status = 'Em dia • Dia $daysElapsed/30';
                } else {
                  status = 'Em dia • Atualizada hoje';
                }
              }
            }

            String initials = 'AL';
            final parts = clientName.trim().split(RegExp(r'\s+'));
            if (parts.isNotEmpty) {
              if (parts.length == 1) {
                initials = parts[0]
                    .substring(0, parts[0].length >= 2 ? 2 : 1)
                    .toUpperCase();
              } else {
                initials = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
              }
            }

            return _RecentWorkoutItem(
              id: w['id']?.toString() ?? '',
              studentId: clientId,
              studentName: clientName,
              workoutTitle: title,
              splitInfo: w['notes_for_trainer'] as String? ?? 'Sem notas',
              statusText: status,
              daysElapsed: daysElapsed,
              isExpired: expired,
              isExpiringSoon: expiringSoon,
              initials: initials,
              useClipboardIcon: clientName == 'Aluno',
              photoUrl: photoUrl,
              rawWorkout: w,
            );
          }).toList();

          // Ordena priorizando fichas vencidas -> renovação próxima -> em dia
          parsedList.sort((a, b) {
            int rank(_RecentWorkoutItem item) {
              if (item.isExpired) return 0;
              if (item.isExpiringSoon) return 1;
              return 2;
            }

            final rA = rank(a);
            final rB = rank(b);
            if (rA != rB) return rA.compareTo(rB);
            return b.daysElapsed.compareTo(a.daysElapsed);
          });

          _recentWorkouts = parsedList;
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

  Future<void> _navigateToCreateWorkout({
    String? studentId,
    String? studentName,
  }) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => TrainerAnamnesisScreen(
          initialStudentId: studentId,
          initialStudentName: studentName,
        ),
      ),
    );
    if (mounted) await _loadWorkouts();
  }

  void _showAssessmentDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: MetaColors.card(context),
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
                    color: MetaColors.cardBorder(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Avaliação Física & Biomecânica',
                style: TextStyle(
                  color: MetaColors.text(context),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Escolha o tipo de protocolo para registrar e vincular à periodização do aluno.',
                style: TextStyle(
                  color: MetaColors.subtext(context),
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
                    SnackBar(
                      backgroundColor: MetaColors.highlight(context),
                      content: Text(
                        'Módulo de Composição Corporal selecionado.',
                        style: TextStyle(color: MetaColors.text(context)),
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
    final badgeColor = workout.isExpired
        ? const Color(0xFFEF4444)
        : workout.isExpiringSoon
            ? Colors.amber
            : MetaColors.emerald;

    showModalBottomSheet(
      context: context,
      backgroundColor: MetaColors.card(context),
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
                    color: MetaColors.cardBorder(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: MetaColors.highlight(context),
                    backgroundImage: safeImageProvider(workout.photoUrl),
                    child: safeImageProvider(workout.photoUrl) != null
                        ? null
                        : (workout.useClipboardIcon
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
                              )),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          workout.studentName,
                          style: TextStyle(
                            color: MetaColors.text(context),
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          workout.workoutTitle,
                          style: TextStyle(
                            color: MetaColors.subtext(context),
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
                  color: MetaColors.highlight(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    Icon(
                      workout.isExpired
                          ? Icons.warning_amber_rounded
                          : workout.isExpiringSoon
                              ? Icons.schedule_rounded
                              : Icons.check_circle_outline_rounded,
                      color: badgeColor,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        workout.isExpired
                            ? '${workout.statusText} • Necessita renovação'
                            : workout.isExpiringSoon
                                ? '${workout.statusText} • Prepare o próximo ciclo'
                                : '${workout.statusText} • Ficha ativa no prazo',
                        style: TextStyle(
                          color: badgeColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  if (workout.needsAttention && workout.studentId != null) ...[
                    Expanded(
                      child: SquircleButton(
                        icon: Icons.autorenew_rounded,
                        label: 'Renovar +30d',
                        isPrimary: false,
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await WorkoutService.renewWorkoutPlan(
                            clientId: workout.studentId!,
                            workoutId: workout.id,
                          );
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              backgroundColor: MetaColors.emerald,
                              content: Text(
                                'Ciclo de 30 dias renovado com sucesso!',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                          await _loadWorkouts();
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: SquircleButton(
                      icon: Icons.auto_awesome_rounded,
                      label: 'Nova Periodização IA',
                      isPrimary: true,
                      onPressed: () {
                        Navigator.pop(ctx);
                        _navigateToCreateWorkout(
                          studentId: workout.studentId,
                          studentName: workout.studentName,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildKpiMetricCard({
    required BuildContext context,
    required String value,
    required String label,
    required Color accentColor,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: MetaCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: MetaColors.text(context),
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                Icon(icon, color: accentColor, size: 18),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: MetaColors.subtext(context),
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required BuildContext context,
    required String label,
    required _WorkoutFilter filter,
    required int count,
  }) {
    final isSelected = _selectedFilter == filter;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = filter),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? MetaColors.emerald.withValues(alpha: 0.16)
              : MetaColors.highlight(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? MetaColors.emerald
                : MetaColors.cardBorder(context),
          ),
        ),
        child: Text(
          '$label ($count)',
          style: TextStyle(
            color: isSelected ? MetaColors.emerald : MetaColors.subtext(context),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final isDark = MetaColors.isDark(context);

    final onTrackCount =
        _recentWorkouts.where((w) => !w.needsAttention).length;
    final attentionCount =
        _recentWorkouts.where((w) => w.needsAttention).length;

    final filteredWorkouts = _recentWorkouts.where((w) {
      switch (_selectedFilter) {
        case _WorkoutFilter.all:
          return true;
        case _WorkoutFilter.onTrack:
          return !w.needsAttention;
        case _WorkoutFilter.attention:
          return w.needsAttention;
      }
    }).toList();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: MetaColors.bg(context),
        body: Stack(
          children: [
            CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                // Topo da tela: Título + Botão Diretrizes de Avaliação + Painel de Indicadores (KPIs)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: topPadding + 16,
                      left: 20,
                      right: 20,
                      bottom: 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Treinos',
                              style: TextStyle(
                                color: MetaColors.text(context),
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.5,
                              ),
                            ),
                            InkWell(
                              onTap: _showAssessmentDialog,
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: MetaColors.highlight(context),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: MetaColors.cardBorder(context),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.fact_check_outlined,
                                      size: 16,
                                      color: MetaColors.emerald,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Avaliação Física',
                                      style: TextStyle(
                                        color: MetaColors.text(context),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Barra de KPIs Operacionais (Sem botões redundantes)
                        Row(
                          children: [
                            _buildKpiMetricCard(
                              context: context,
                              value: '$onTrackCount',
                              label: 'Fichas em Dia',
                              accentColor: MetaColors.emerald,
                              icon: Icons.check_circle_outline_rounded,
                              onTap: () => setState(
                                () => _selectedFilter = _WorkoutFilter.onTrack,
                              ),
                            ),
                            const SizedBox(width: 10),
                            _buildKpiMetricCard(
                              context: context,
                              value: '$attentionCount',
                              label: 'Renovação',
                              accentColor: attentionCount > 0
                                  ? Colors.amber
                                  : MetaColors.subtext(context),
                              icon: Icons.autorenew_rounded,
                              onTap: () => setState(
                                () => _selectedFilter = _WorkoutFilter.attention,
                              ),
                            ),
                            const SizedBox(width: 10),
                            _buildKpiMetricCard(
                              context: context,
                              value: '${_pendingStudents.length}',
                              label: 'Na Fila',
                              accentColor: _pendingStudents.isNotEmpty
                                  ? MetaColors.emerald
                                  : MetaColors.subtext(context),
                              icon: Icons.pending_actions_rounded,
                              onTap: () {
                                if (_pendingStudents.isNotEmpty) {
                                  final first = _pendingStudents.first;
                                  _navigateToCreateWorkout(
                                    studentId: first['id']?.toString(),
                                    studentName:
                                        first['full_name'] as String? ?? 'Aluno',
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Seção "Aguardando Periodização" (Apenas alunos com cadastro ativo sem ficha)
                if (_pendingStudents.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(
                        left: 20,
                        right: 20,
                        top: 12,
                        bottom: 6,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: MetaColors.emerald,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Aguardando Periodização (${_pendingStudents.length})',
                                style: const TextStyle(
                                  color: MetaColors.emerald,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ..._pendingStudents.map((st) {
                            final name = st['full_name'] as String? ?? 'Aluno';
                            final goal =
                                st['goal'] as String? ?? 'Objetivo não informado';
                            final stId = st['id'] as String?;
                            final photoUrl =
                                (st['photo_url'] ?? st['avatar_url']) as String?;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: MetaColors.card(context),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color:
                                      MetaColors.emerald.withValues(alpha: 0.4),
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor:
                                        MetaColors.highlight(context),
                                    backgroundImage:
                                        safeImageProvider(photoUrl),
                                    child: safeImageProvider(photoUrl) != null
                                        ? null
                                        : Text(
                                            name.isNotEmpty
                                                ? name[0].toUpperCase()
                                                : 'A',
                                            style: const TextStyle(
                                              color: MetaColors.emerald,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                          ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: TextStyle(
                                            color: MetaColors.text(context),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          goal.isNotEmpty &&
                                                  goal != 'Treino' &&
                                                  goal != 'Geral'
                                              ? 'Anamnese preenchida • $goal'
                                              : 'Cadastro ativo • Aguardando 1ª periodização',
                                          style: TextStyle(
                                            color: MetaColors.subtext(context),
                                            fontSize: 12,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    onPressed: () => _navigateToCreateWorkout(
                                      studentId: stId,
                                      studentName: name,
                                    ),
                                    icon:
                                        const Icon(Icons.auto_awesome, size: 15),
                                    label: const Text('Prescrever'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: MetaColors.emerald,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      textStyle: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),

                // Seção "Fichas Recentes" + Filtros de Vigência
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: 20,
                      right: 20,
                      top: 14,
                      bottom: 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Fichas Recentes',
                          style: TextStyle(
                            color: MetaColors.text(context),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildFilterChip(
                                context: context,
                                label: 'Todas',
                                filter: _WorkoutFilter.all,
                                count: _recentWorkouts.length,
                              ),
                              const SizedBox(width: 8),
                              _buildFilterChip(
                                context: context,
                                label: 'Em dia',
                                filter: _WorkoutFilter.onTrack,
                                count: onTrackCount,
                              ),
                              const SizedBox(width: 8),
                              _buildFilterChip(
                                context: context,
                                label: 'Renovação / Vencidas',
                                filter: _WorkoutFilter.attention,
                                count: attentionCount,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Lista de Fichas Prescritas
                SliverPadding(
                  padding: EdgeInsets.only(
                    left: 8,
                    right: 8,
                    bottom: bottomPadding + 88,
                  ),
                  sliver: _isLoading
                      ? const SliverFillRemaining(
                          child: Center(
                            child: CircularProgressIndicator(
                              color: MetaColors.emerald,
                            ),
                          ),
                        )
                      : _hasError
                          ? SliverFillRemaining(
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.error_outline,
                                      color: Colors.redAccent,
                                      size: 48,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Erro ao carregar treinos:\n$_errorMessage',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: MetaColors.subtext(context),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton(
                                      onPressed: _loadWorkouts,
                                      child: const Text('Tentar Novamente'),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : filteredWorkouts.isEmpty
                              ? SliverFillRemaining(
                                  child: Center(
                                    child: Text(
                                      'Nenhum treino encontrado neste filtro.',
                                      style: TextStyle(
                                        color: MetaColors.subtext(context),
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                )
                              : SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) {
                                      final workout = filteredWorkouts[index];
                                      final statusColor = workout.isExpired
                                          ? const Color(0xFFEF4444)
                                          : workout.isExpiringSoon
                                              ? Colors.amber
                                              : MetaColors.emerald;
                                      final statusLabel = workout.isExpired
                                          ? 'VENCIDA'
                                          : workout.isExpiringSoon
                                              ? 'RENOVAR'
                                              : 'EM DIA';

                                      return Material(
                                        color: Colors.transparent,
                                        borderRadius: BorderRadius.circular(16),
                                        child: InkWell(
                                          onTap: () =>
                                              _showWorkoutDetails(workout),
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            child: ListTile(
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 2,
                                              ),
                                              tileColor: Colors.transparent,
                                              leading: CircleAvatar(
                                                radius: 24,
                                                backgroundColor:
                                                    MetaColors.highlight(
                                                  context,
                                                ),
                                                backgroundImage:
                                                    safeImageProvider(
                                                  workout.photoUrl,
                                                ),
                                                child: safeImageProvider(
                                                          workout.photoUrl,
                                                        ) !=
                                                        null
                                                    ? null
                                                    : (workout.useClipboardIcon
                                                        ? const Icon(
                                                            Icons
                                                                .assignment_outlined,
                                                            color: MetaColors
                                                                .emerald,
                                                            size: 22,
                                                          )
                                                        : Text(
                                                            workout.initials,
                                                            style:
                                                                const TextStyle(
                                                              color: MetaColors
                                                                  .emerald,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 15,
                                                            ),
                                                          )),
                                              ),
                                              title: Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      '${workout.studentName} • ${workout.workoutTitle}',
                                                      style: TextStyle(
                                                        color: MetaColors.text(
                                                          context,
                                                        ),
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontSize: 15.5,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 7,
                                                      vertical: 2,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: statusColor
                                                          .withValues(
                                                        alpha: 0.14,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                        6,
                                                      ),
                                                    ),
                                                    child: Text(
                                                      statusLabel,
                                                      style: TextStyle(
                                                        color: statusColor,
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        letterSpacing: 0.4,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              subtitle: Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 4,
                                                ),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      workout.isExpired
                                                          ? Icons
                                                              .call_missed_rounded
                                                          : workout
                                                                  .isExpiringSoon
                                                              ? Icons
                                                                  .schedule_rounded
                                                              : Icons
                                                                  .call_made_rounded,
                                                      size: 14,
                                                      color: statusColor,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Expanded(
                                                      child: Text(
                                                        workout.statusText,
                                                        style: TextStyle(
                                                          color: workout
                                                                  .isExpired
                                                              ? statusColor
                                                              : MetaColors
                                                                  .subtext(
                                                                  context,
                                                                ),
                                                          fontSize: 13,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              trailing: Icon(
                                                Icons.chevron_right_rounded,
                                                color: MetaColors.subtext(
                                                  context,
                                                ),
                                                size: 20,
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                    childCount: filteredWorkouts.length,
                                  ),
                                ),
                ),
              ],
            ),

            // FAB (Botão Principal Único): SquircleButton no canto inferior direito
            Positioned(
              right: 16,
              bottom: bottomPadding + 16,
              child: SquircleButton(
                icon: Icons.add,
                label: 'Prescrever',
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
