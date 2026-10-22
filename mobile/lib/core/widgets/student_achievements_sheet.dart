import 'dart:math';
import '../../services/workout_service.dart';
import '../../services/workout_session_service.dart';
import '../../services/auth_service.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'meta_components.dart';

/// Nível ou raridade da conquista
enum BadgeTier {
  bronze,
  silver,
  gold,
  diamond;

  String get label {
    switch (this) {
      case BadgeTier.bronze:
        return 'BRONZE';
      case BadgeTier.silver:
        return 'PRATA';
      case BadgeTier.gold:
        return 'OURO';
      case BadgeTier.diamond:
        return 'DIAMANTE';
    }
  }

  Color get color {
    switch (this) {
      case BadgeTier.bronze:
        return const Color(0xFFCD7F32);
      case BadgeTier.silver:
        return const Color(0xFF94A3B8);
      case BadgeTier.gold:
        return const Color(0xFFF59E0B);
      case BadgeTier.diamond:
        return const Color(0xFF38BDF8);
    }
  }
}

/// Modelo de dados de uma Conquista / Badge de Força
class StudentBadge {
  final String id;
  final String title;
  final String description;
  final String category; // 'strength', 'consistency', 'volume', 'mastery'
  final IconData icon;
  final BadgeTier tier;
  final bool isUnlocked;
  final DateTime? unlockedAt;
  final double currentProgress;
  final double targetProgress;
  final String progressLabel;

  const StudentBadge({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.icon,
    required this.tier,
    this.isUnlocked = false,
    this.unlockedAt,
    this.currentProgress = 0,
    required this.targetProgress,
    required this.progressLabel,
  });

  double get progressFactor =>
      targetProgress <= 0 ? 1.0 : (currentProgress / targetProgress).clamp(0.0, 1.0);

  StudentBadge copyWith({
    bool? isUnlocked,
    DateTime? unlockedAt,
    double? currentProgress,
    String? progressLabel,
  }) {
    return StudentBadge(
      id: id,
      title: title,
      description: description,
      category: category,
      icon: icon,
      tier: tier,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      currentProgress: currentProgress ?? this.currentProgress,
      targetProgress: targetProgress,
      progressLabel: progressLabel ?? this.progressLabel,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'isUnlocked': isUnlocked,
        'unlockedAt': unlockedAt?.toIso8601String(),
        'currentProgress': currentProgress,
        'progressLabel': progressLabel,
      };
}

/// Serviço de gerenciamento e persistência das conquistas do aluno
class StudentAchievementsService {
  static const String _prefPrefix = 'student_achievements_v1_';

  static List<StudentBadge> get canonicalBadges => [
        const StudentBadge(
          id: 'first_triumph',
          title: 'Primeiro Triunfo',
          description: 'Concluiu o primeiro treino completo com registro de cargas no app.',
          category: 'consistency',
          icon: Icons.emoji_events_rounded,
          tier: BadgeTier.bronze,
          isUnlocked: true,
          unlockedAt: null,
          currentProgress: 1,
          targetProgress: 1,
          progressLabel: '1 / 1 concluído',
        ),
        const StudentBadge(
          id: 'club_100_bench',
          title: 'Clube dos 100kg no Supino',
          description: 'Atingiu 1RM teórico estimado igual ou superior a 100kg no supino reto.',
          category: 'strength',
          icon: Icons.fitness_center_rounded,
          tier: BadgeTier.gold,
          isUnlocked: true,
          unlockedAt: null,
          currentProgress: 106.7,
          targetProgress: 100.0,
          progressLabel: '106.7 / 100 kg',
        ),
        const StudentBadge(
          id: 'overload_master',
          title: 'Mestre da Sobrecarga',
          description: 'Aceitou e completou 3 metas consecutivas de sobrecarga propostas pela IA.',
          category: 'mastery',
          icon: Icons.auto_awesome_rounded,
          tier: BadgeTier.silver,
          isUnlocked: true,
          unlockedAt: null,
          currentProgress: 3,
          targetProgress: 3,
          progressLabel: '3 / 3 metas batidas',
        ),
        const StudentBadge(
          id: 'volume_titan',
          title: 'Titã do Volume (5t)',
          description: 'Movimentou mais de 5 toneladas de tonelagem acumulada em uma única semana.',
          category: 'volume',
          icon: Icons.bar_chart_rounded,
          tier: BadgeTier.gold,
          isUnlocked: true,
          unlockedAt: null,
          currentProgress: 5.8,
          targetProgress: 5.0,
          progressLabel: '5.8 / 5.0 toneladas',
        ),
        const StudentBadge(
          id: 'streak_10',
          title: 'Hábito de Ferro (10 Treinos)',
          description: 'Mantenha a frequência semanal e conclua 10 sessões de musculação.',
          category: 'consistency',
          icon: Icons.local_fire_department_rounded,
          tier: BadgeTier.silver,
          isUnlocked: false,
          unlockedAt: null,
          currentProgress: 7,
          targetProgress: 10,
          progressLabel: '7 / 10 treinos',
        ),
        const StudentBadge(
          id: 'club_140_squat',
          title: 'Clube dos 140kg no Agachamento',
          description: 'Construa bases sólidas e atinja 140kg de 1RM estimado no agachamento livre.',
          category: 'strength',
          icon: Icons.arrow_upward_rounded,
          tier: BadgeTier.diamond,
          isUnlocked: false,
          unlockedAt: null,
          currentProgress: 125.0,
          targetProgress: 140.0,
          progressLabel: '125 / 140 kg',
        ),
        const StudentBadge(
          id: 'rest_timer_zen',
          title: 'Disciplina Cirúrgica',
          description: 'Utilizou o cronômetro de descanso 3-2-1 em todas as séries de uma sessão.',
          category: 'mastery',
          icon: Icons.timer_rounded,
          tier: BadgeTier.bronze,
          isUnlocked: false,
          unlockedAt: null,
          currentProgress: 14,
          targetProgress: 16,
          progressLabel: '14 / 16 séries',
        ),
        const StudentBadge(
          id: 'social_inspiration',
          title: 'Inspiração Fitness',
          description: 'Compartilhou seu card de triunfo em formato Story nos últimos 30 dias.',
          category: 'mastery',
          icon: Icons.share_rounded,
          tier: BadgeTier.bronze,
          isUnlocked: false,
          unlockedAt: null,
          currentProgress: 0,
          targetProgress: 1,
          progressLabel: '0 / 1 compartilhado',
        ),
      ];

  static Future<List<StudentBadge>> evaluateBadgesFromRealData({
    required List<StudentBadge> currentBadges,
    String? userId,
  }) async {
    final effectiveId = userId ?? AuthService.currentUser?.id;
    if (effectiveId == null) return currentBadges;

    try {
      final overloads = await WorkoutService.getStudentProgressiveOverload(effectiveId);

      int completedWorkouts = 0;
      try {
        final sessionService = WorkoutSessionService();
        final pendingSessions = await sessionService.pending(effectiveId);
        completedWorkouts += pendingSessions.length;
      } catch (_) {}

      try {
        final feedback = await WorkoutService.getStudentWorkoutFeedback(effectiveId);
        if (feedback != null && feedback.isNotEmpty) {
          completedWorkouts = max(completedWorkouts, 1);
        }
      } catch (_) {}

      double maxBench1Rm = 0.0;
      double maxSquat1Rm = 0.0;
      double totalWeeklyVolumeKg = 0.0;

      for (final item in overloads) {
        final name = (item['exercise'] as String?)?.toLowerCase() ?? '';
        final currentLoadStr = (item['current_load'] as String?)?.replaceAll('kg', '').trim() ?? '0';
        final load = double.tryParse(currentLoadStr) ?? 0.0;
        final estimated1Rm = (load > 0) ? (load * (1.0 + 10.0 / 30.0)) : 0.0;

        if (name.contains('supino') || name.contains('bench')) {
          if (estimated1Rm > maxBench1Rm) maxBench1Rm = estimated1Rm;
        }
        if (name.contains('agachamento') || name.contains('squat') || name.contains('leg press')) {
          if (estimated1Rm > maxSquat1Rm) maxSquat1Rm = estimated1Rm;
        }

        final history = (item['history'] as List<dynamic>?) ?? [];
        if (history.isNotEmpty) {
          completedWorkouts = max(completedWorkouts, history.length);
          totalWeeklyVolumeKg += load * 10 * 3;
        }
      }

      final tonnageTons = (totalWeeklyVolumeKg / 1000.0);

      if (overloads.isEmpty && completedWorkouts == 0) {
        return currentBadges;
      }

      final evaluated = currentBadges.map((badge) {
        switch (badge.id) {
          case 'first_triumph':
            final unlocked = badge.isUnlocked || completedWorkouts >= 1;
            return badge.copyWith(
              isUnlocked: unlocked,
              currentProgress: (unlocked || completedWorkouts >= 1) ? 1.0 : 0.0,
              progressLabel: (unlocked || completedWorkouts >= 1) ? '1 / 1 concluído' : '0 / 1 concluído',
            );
          case 'streak_10':
            final progress = (completedWorkouts).toDouble();
            final unlocked = badge.isUnlocked || progress >= 10.0;
            return badge.copyWith(
              isUnlocked: unlocked,
              currentProgress: unlocked ? 10.0 : progress,
              progressLabel: '${unlocked ? 10 : progress.toInt()} / 10 treinos',
            );
          case 'club_100_bench':
            if (maxBench1Rm > 0) {
              final rounded = (maxBench1Rm * 10).round() / 10.0;
              final unlocked = badge.isUnlocked || rounded >= 100.0;
              return badge.copyWith(
                isUnlocked: unlocked,
                currentProgress: rounded,
                progressLabel: '$rounded / 100 kg',
              );
            }
            return badge;
          case 'club_140_squat':
            if (maxSquat1Rm > 0) {
              final rounded = (maxSquat1Rm * 10).round() / 10.0;
              final unlocked = badge.isUnlocked || rounded >= 140.0;
              return badge.copyWith(
                isUnlocked: unlocked,
                currentProgress: rounded,
                progressLabel: '$rounded / 140 kg',
              );
            }
            return badge;
          case 'volume_titan':
            if (tonnageTons > 0) {
              final rounded = (tonnageTons * 10).round() / 10.0;
              final unlocked = badge.isUnlocked || rounded >= 5.0;
              return badge.copyWith(
                isUnlocked: unlocked,
                currentProgress: rounded,
                progressLabel: '$rounded / 5.0 toneladas',
              );
            }
            return badge;
          default:
            return badge;
        }
      }).toList();

      return evaluated;
    } catch (_) {
      return currentBadges;
    }
  }

  static Future<List<StudentBadge>> loadBadges({
    String? userId,
    bool evaluateDynamic = true,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_prefPrefix${userId ?? "default"}';
    final raw = prefs.getString(key);
    final defaults = canonicalBadges;

    List<StudentBadge> badges = defaults;

    if (raw != null && raw.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(raw);
        final Map<String, dynamic> storedMap = {
          for (var item in decoded) item['id'] as String: item
        };

        badges = defaults.map((badge) {
          final saved = storedMap[badge.id];
          if (saved != null) {
            final isUnlocked = (saved['isUnlocked'] as bool?) ?? badge.isUnlocked;
            final unlockedStr = saved['unlockedAt'] as String?;
            final currentProg = (saved['currentProgress'] as num?)?.toDouble() ?? badge.currentProgress;
            final progLabel = (saved['progressLabel'] as String?) ?? badge.progressLabel;
            return badge.copyWith(
              isUnlocked: isUnlocked,
              unlockedAt: unlockedStr != null ? DateTime.tryParse(unlockedStr) : badge.unlockedAt,
              currentProgress: currentProg,
              progressLabel: progLabel,
            );
          }
          return badge;
        }).toList();
      } catch (_) {
        badges = defaults;
      }
    }

    if (evaluateDynamic) {
      badges = await evaluateBadgesFromRealData(
        currentBadges: badges,
        userId: userId,
      );
    }

    return badges;
  }

  static Future<void> saveBadges(List<StudentBadge> badges, {String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_prefPrefix${userId ?? "default"}';
    final payload = badges.map((b) => b.toJson()).toList();
    await prefs.setString(key, jsonEncode(payload));
  }
}

/// Modal Sheet com a Galeria Completa de Conquistas & Badges do Aluno
class StudentAchievementsModalSheet extends StatefulWidget {
  final String? userId;
  final String? trainerName;

  const StudentAchievementsModalSheet({
    super.key,
    this.userId,
    this.trainerName,
  });

  static Future<void> show(
    BuildContext context, {
    String? userId,
    String? trainerName,
  }) {
    HapticFeedback.mediumImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StudentAchievementsModalSheet(
        userId: userId,
        trainerName: trainerName,
      ),
    );
  }

  @override
  State<StudentAchievementsModalSheet> createState() =>
      _StudentAchievementsModalSheetState();
}

class _StudentAchievementsModalSheetState
    extends State<StudentAchievementsModalSheet> {
  List<StudentBadge> _badges = [];
  bool _isLoading = true;
  String _selectedFilter = 'all'; // 'all', 'unlocked', 'locked'

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await StudentAchievementsService.loadBadges(userId: widget.userId);
    if (mounted) {
      setState(() {
        _badges = list;
        _isLoading = false;
      });
    }
  }

  List<StudentBadge> get _filteredBadges {
    if (_selectedFilter == 'unlocked') {
      return _badges.where((b) => b.isUnlocked).toList();
    }
    if (_selectedFilter == 'locked') {
      return _badges.where((b) => !b.isUnlocked).toList();
    }
    return _badges;
  }

  int get _unlockedCount => _badges.where((b) => b.isUnlocked).length;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final cardBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final border = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.65),
              blurRadius: 32,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Barra de arrasto
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: subtextColor.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Cabeçalho da Central de Conquistas
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                            ),
                          ),
                          child: const Icon(
                            Icons.military_tech_rounded,
                            color: Color(0xFFF59E0B),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Galeria de Conquistas & Badges',
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Desbloqueie selos de força e consistência',
                                style: TextStyle(
                                  color: subtextColor,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded, color: subtextColor),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Card Hero de Resumo
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFFF59E0B).withValues(alpha: 0.18),
                            cardBg,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF59E0B)
                                            .withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'STATUS DE CONQUISTAS',
                                        style: TextStyle(
                                          color: Color(0xFFF59E0B),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '$_unlockedCount de ${_badges.length} Concluídas',
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Progresso geral de ${((_unlockedCount / (_badges.isEmpty ? 1 : _badges.length)) * 100).toStringAsFixed(0)}% no plano',
                                  style: TextStyle(
                                    color: subtextColor,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          CircularProgressIndicator(
                            value: _badges.isEmpty
                                ? 0.0
                                : _unlockedCount / _badges.length,
                            backgroundColor: border,
                            color: const Color(0xFFF59E0B),
                            strokeWidth: 6,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Filtros Rápidos (Todos / Conquistados / A Conquistar)
                    Row(
                      children: [
                        _buildFilterChip('all', 'Todas (${_badges.length})'),
                        const SizedBox(width: 8),
                        _buildFilterChip('unlocked', 'Conquistadas ($_unlockedCount)'),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          'locked',
                          'Bloqueadas (${_badges.length - _unlockedCount})',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Grid de Badges
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _filteredBadges.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.85,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemBuilder: (context, index) {
                        final badge = _filteredBadges[index];
                        return _buildBadgeCard(badge, cardBg, border, textColor, subtextColor);
                      },
                    ),
                    const SizedBox(height: 20),

                    // Botão Fechar
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF59E0B),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Continuar Focado nos Treinos',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedFilter == value;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedFilter = value);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFF59E0B).withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFF59E0B)
                : const Color(0xFF334155).withValues(alpha: 0.5),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFFF59E0B) : const Color(0xFF94A3B8),
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildBadgeCard(
    StudentBadge badge,
    Color cardBg,
    Color border,
    Color textColor,
    Color subtextColor,
  ) {
    final isUnlocked = badge.isUnlocked;
    final accentColor = badge.tier.color;

    return GestureDetector(
      onTap: () => _openBadgeDetail(badge),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isUnlocked ? cardBg : cardBg.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isUnlocked
                ? accentColor.withValues(alpha: 0.4)
                : border.withValues(alpha: 0.5),
            width: isUnlocked ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Ícone com Badge de Tier
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isUnlocked
                        ? accentColor.withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.05),
                    border: Border.all(
                      color: isUnlocked
                          ? accentColor
                          : Colors.grey.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    badge.icon,
                    size: 26,
                    color: isUnlocked ? accentColor : Colors.grey,
                  ),
                ),
                if (!isUnlocked)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Colors.black87,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock_rounded,
                        size: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Título
            Text(
              badge.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isUnlocked ? textColor : subtextColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),

            // Tier Tag
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                badge.tier.label,
                style: TextStyle(
                  color: accentColor,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Barra de Progresso
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: badge.progressFactor,
                backgroundColor: border,
                color: isUnlocked ? accentColor : Colors.grey,
                minHeight: 4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isUnlocked ? 'Desbloqueado! 🏆' : badge.progressLabel,
              style: TextStyle(
                color: isUnlocked ? accentColor : subtextColor,
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openBadgeDetail(StudentBadge badge) {
    HapticFeedback.selectionClick();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: badge.tier.color.withValues(alpha: 0.4),
          ),
        ),
        title: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: badge.tier.color.withValues(alpha: 0.2),
                border: Border.all(color: badge.tier.color, width: 2.5),
              ),
              child: Icon(badge.icon, size: 32, color: badge.tier.color),
            ),
            const SizedBox(height: 12),
            Text(
              badge.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: badge.tier.color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'TIER ${badge.tier.label}',
                style: TextStyle(
                  color: badge.tier.color,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              badge.description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    badge.isUnlocked
                        ? Icons.check_circle_rounded
                        : Icons.pending_rounded,
                    color: badge.isUnlocked ? MetaColors.emerald : Colors.amber,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      badge.isUnlocked
                          ? 'Conquista alcançada! Parabéns pela dedicação.'
                          : 'Progresso atual: ${badge.progressLabel}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar', style: TextStyle(color: Colors.white70)),
          ),
          if (badge.isUnlocked)
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _shareBadgeStory(badge);
              },
              icon: const Icon(Icons.share_rounded, size: 16),
              label: const Text('Compartilhar Conquista'),
              style: FilledButton.styleFrom(
                backgroundColor: badge.tier.color,
                foregroundColor: Colors.black87,
              ),
            ),
        ],
      ),
    );
  }

  void _shareBadgeStory(StudentBadge badge) {
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Story de conquista gerado! Menção a ${widget.trainerName ?? "Personal"} incluída.',
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

