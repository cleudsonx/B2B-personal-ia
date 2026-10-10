import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/widgets/meta_components.dart';
import '../../../../services/auth_service.dart';
import '../../../../services/workout_service.dart';

/// Aba 3 do Professor (Social / Atualizações)
///
/// Inspirada na aba "Atualizações" do ecossistema Meta / WhatsApp:
/// - Seção "Status" no topo com círculo do professor e badge verde "+" sobreposto
/// - Visualização de status recentes de alunos (carrossel)
/// - Seção "Canais / Ranking" de consistência e ofensivas (Streaks 🔥)
/// - Totalmente Edge-to-Edge nativo, sem letterbox e sem SafeAreas no Scaffold.
class TrainerSocialScreen extends StatefulWidget {
  const TrainerSocialScreen({super.key});

  @override
  State<TrainerSocialScreen> createState() => _TrainerSocialScreenState();
}

class _TrainerSocialScreenState extends State<TrainerSocialScreen> {
  List<Map<String, dynamic>> _rankingStudents = [];
  bool _isLoadingRanking = true;
  bool _rankingLoadFailed = false;

  @override
  void initState() {
    super.initState();
    _loadRanking();
  }

  Future<void> _loadRanking() async {
    if (mounted) {
      setState(() {
        _isLoadingRanking = true;
        _rankingLoadFailed = false;
      });
    }
    try {
      final ranking = await WorkoutService.getTrainerGamificationRanking();
      if (!mounted) return;
      setState(() {
        _rankingStudents = ranking;
        _isLoadingRanking = false;
      });
    } catch (error) {
      debugPrint('Erro ao carregar consistência dos alunos: $error');
      if (!mounted) return;
      setState(() {
        _rankingLoadFailed = true;
        _isLoadingRanking = false;
      });
    }
  }

  String _getTrainerName() {
    final user = AuthService.currentUser;
    final name = user?.userMetadata?['full_name'] as String?;
    if (name != null && name.trim().isNotEmpty) {
      return name;
    }
    return 'Prof. Treinador';
  }

  String _getTrainerInitials() {
    final name = _getTrainerName();
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
  }

  Color _getBadgeColor(int streakDays) {
    if (streakDays >= 30) return const Color(0xFFF59E0B);
    if (streakDays >= 7) return MetaColors.emerald;
    return MetaColors.textSecondary;
  }

  String _formatLastActivity(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return 'Nenhuma sessão registrada';
    final today = DateTime.now().toUtc();
    final activityDate = date.toUtc();
    final days = DateTime.utc(today.year, today.month, today.day)
      .difference(DateTime.utc(activityDate.year, activityDate.month, activityDate.day))
        .inDays;
    if (days <= 0) return 'Última atividade hoje';
    if (days == 1) return 'Última atividade ontem';
    return 'Última atividade há $days dias';
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final trainerInitials = _getTrainerInitials();
    final isDark = MetaColors.isDark(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: MetaColors.bg(context),
        body: Stack(
          children: [
            RefreshIndicator(
              onRefresh: _loadRanking,
              color: MetaColors.emerald,
              child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                // 1. Topo M3: Título da Aba "Atualizações"
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: topPadding + 16,
                      left: 20,
                      right: 20,
                      bottom: 12,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Atualizações',
                          style: TextStyle(
                            color: MetaColors.text(context),
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 2. Seção "Status": Título
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: 20,
                      right: 20,
                      top: 4,
                      bottom: 8,
                    ),
                    child: Text(
                      'Status',
                      style: TextStyle(
                        color: MetaColors.text(context),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                ),

                // Status do Treinador
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: MetaColors.highlight(context),
                            child: Text(
                              trainerInitials,
                              style: const TextStyle(
                                color: MetaColors.emerald,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Meu status',
                                  style: TextStyle(
                                    color: MetaColors.text(context),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Publicação de status ainda não disponível.',
                                  style: TextStyle(
                                    color: MetaColors.subtext(context),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // 4. Carrossel de Status Recentes de Alunos
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: 20,
                      right: 20,
                      top: 14,
                      bottom: 8,
                    ),
                    child: Text(
                      'Atualizações recentes',
                      style: TextStyle(
                        color: MetaColors.subtext(context),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 98,
                    child: Center(
                      child: Text(
                        'Atualizações de alunos ainda não estão disponíveis.',
                        style: TextStyle(color: MetaColors.subtext(context)),
                      ),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(
                  child: SizedBox(height: 20),
                ),

                // 5. Seção "Canais / Ranking": Cabeçalho
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'Consistência dos alunos',
                      style: TextStyle(
                        color: MetaColors.text(context),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(
                  child: SizedBox(height: 8),
                ),

                // Consistency ranking
                SliverPadding(
                  padding: EdgeInsets.only(
                    left: 12,
                    right: 12,
                    bottom: bottomPadding + 88,
                  ),
                  sliver: _buildRankingSliver(),
                ),
              ],
            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRankingSliver() {
    if (_isLoadingRanking) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator(color: MetaColors.emerald)),
        ),
      );
    }
    if (_rankingLoadFailed) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text(
                'Não foi possível carregar a consistência dos alunos.',
                textAlign: TextAlign.center,
                style: TextStyle(color: MetaColors.subtext(context)),
              ),
              TextButton.icon(
                onPressed: _loadRanking,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }
    if (_rankingStudents.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'Ainda não há atividades registradas pelos alunos.',
            textAlign: TextAlign.center,
            style: TextStyle(color: MetaColors.subtext(context)),
          ),
        ),
      );
    }

    return SliverList.separated(
      itemCount: _rankingStudents.length,
      separatorBuilder: (_, _) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final student = _rankingStudents[index];
        final streak = (student['current_streak'] as num?)?.toInt() ?? 0;
        final recentSessions =
          (student['sessions_in_window'] as num?)?.toInt() ?? 0;
        final badgeColor = _getBadgeColor(streak);
        final name = student['full_name']?.toString() ?? 'Aluno';
        final initials = name.trim().isEmpty
            ? 'A'
            : name.trim().substring(0, 1).toUpperCase();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: Center(
                  child: Text(
                    '#${index + 1}',
                    style: TextStyle(
                      color: badgeColor,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 22,
                backgroundColor: MetaColors.highlight(context),
                child: Text(
                  initials,
                  style: TextStyle(
                    color: badgeColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: MetaColors.text(context),
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_formatLastActivity(student['last_activity_date'])} · $recentSessions treinos em 100 dias',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: MetaColors.subtext(context),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: MetaColors.highlight(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.local_fire_department_rounded,
                      color: Color(0xFFF97316),
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${streak}d',
                      style: TextStyle(
                        color: badgeColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
