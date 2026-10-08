import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/widgets/meta_components.dart';
import '../../../../services/auth_service.dart';

/// Modelo de dados de um aluno no ranking de ofensivas (Streaks)
class _StreakStudentItem {
  final int rank;
  final String name;
  final int streakDays;
  final String lastActivity;
  final String category; // 'Ouro', 'Prata', 'Bronze', 'Normal'
  final String initials;

  const _StreakStudentItem({
    required this.rank,
    required this.name,
    required this.streakDays,
    required this.lastActivity,
    required this.category,
    required this.initials,
  });
}

/// Modelo de dados de um status recente de aluno
class _StudentStoryItem {
  final String name;
  final String caption;
  final String timeAgo;
  final String initials;
  final bool isViewed;

  const _StudentStoryItem({
    required this.name,
    required this.caption,
    required this.timeAgo,
    required this.initials,
    this.isViewed = false,
  });
}

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
  final List<_StreakStudentItem> _rankingStudents = const [];
  final List<_StudentStoryItem> _studentStories = const [];

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

  void _congratulateStudent(_StreakStudentItem student) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: MetaColors.surfaceHighlight,
          content: Text(
            'O contato de ${student.name} não está vinculado a estes dados de demonstração. Nenhuma mensagem foi enviada.',
            style: const TextStyle(color: MetaColors.textPrimary),
          ),
        ),
      );
    }
  }

  void _showCreateStatusModal() {
    final controller = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
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
              const Row(
                children: [
                  Icon(
                    Icons.add_photo_alternate_rounded,
                    color: MetaColors.emerald,
                    size: 24,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Novo Status para Alunos',
                    style: TextStyle(
                      color: MetaColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                maxLines: 3,
                style: const TextStyle(color: MetaColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Escreva um aviso, dica de biomecânica ou motivação...',
                  hintStyle: const TextStyle(color: MetaColors.textSecondary),
                  filled: true,
                  fillColor: MetaColors.surfaceHighlight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SquircleButton(
                icon: Icons.send_rounded,
                label: 'Publicar Status',
                isPrimary: true,
                onPressed: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: MetaColors.surfaceHighlight,
                      content: Text(
                        'Publicação de status ainda não disponível. Nenhum status foi enviado.',
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

  void _showStoryDetails(_StudentStoryItem story) {
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
                    radius: 24,
                    backgroundColor: MetaColors.surfaceHighlight,
                    child: Text(
                      story.initials,
                      style: const TextStyle(
                        color: MetaColors.emerald,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          story.name,
                          style: const TextStyle(
                            color: MetaColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          ),
                        ),
                        Text(
                          story.timeAgo,
                          style: const TextStyle(
                            color: MetaColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: MetaColors.surfaceHighlight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: MetaColors.border),
                ),
                child: Text(
                  story.caption,
                  style: const TextStyle(
                    color: MetaColors.textPrimary,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SquircleButton(
                icon: Icons.thumb_up_alt_outlined,
                label: 'Reagir com Incentivo',
                isPrimary: true,
                onPressed: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: MetaColors.surfaceHighlight,
                      content: Text(
                        'Reações ainda não são enviadas aos alunos.',
                        style: const TextStyle(color: MetaColors.textPrimary),
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

  Color _getBadgeColor(String category) {
    switch (category) {
      case 'Ouro':
        return const Color(0xFFF59E0B);
      case 'Prata':
        return const Color(0xFF94A3B8);
      case 'Bronze':
        return const Color(0xFFD97706);
      default:
        return MetaColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final trainerName = _getTrainerName();
    final trainerInitials = _getTrainerInitials();

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
                        const Text(
                          'Atualizações',
                          style: TextStyle(
                            color: MetaColors.textPrimary,
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.search,
                                color: MetaColors.textSecondary,
                                size: 22,
                              ),
                              tooltip: 'Pesquisar',
                              onPressed: null,
                              splashRadius: 20,
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.more_vert,
                                color: MetaColors.textSecondary,
                                size: 22,
                              ),
                              tooltip: 'Opções',
                              onPressed: null,
                              splashRadius: 20,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // 2. Seção "Status": Título
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: 20,
                      right: 20,
                      top: 4,
                      bottom: 8,
                    ),
                    child: Text(
                      'Status',
                      style: TextStyle(
                        color: MetaColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                ),

                // 3. Item "Meu Status" (Professor com badge verde "+" sobreposto estilo WhatsApp)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        onTap: _showCreateStatusModal,
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              // Avatar do Professor com Badge de "+" Verde Sobreposto
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  CircleAvatar(
                                    radius: 28,
                                    backgroundColor:
                                        MetaColors.surfaceHighlight,
                                    child: Text(
                                      trainerInitials,
                                      style: const TextStyle(
                                        color: MetaColors.emerald,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                  // Badge circular verde com o ícone de '+' no canto inferior direito
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        color: MetaColors.emerald,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: MetaColors.background,
                                          width: 2.2,
                                        ),
                                      ),
                                      child: const Center(
                                        child: Icon(
                                          Icons.add,
                                          color: Colors.white,
                                          size: 15,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Meu status',
                                      style: TextStyle(
                                        color: MetaColors.textPrimary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Toque para atualizar seu status ($trainerName)',
                                      style: const TextStyle(
                                        color: MetaColors.textSecondary,
                                        fontSize: 13,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // 4. Carrossel de Status Recentes de Alunos (Histórias no padrão WhatsApp)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: 20,
                      right: 20,
                      top: 14,
                      bottom: 8,
                    ),
                    child: Text(
                      'Atualizações recentes',
                      style: TextStyle(
                        color: MetaColors.textSecondary,
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
                    child: _studentStories.isEmpty
                        ? const Center(
                            child: Text(
                              'As atualizações dos alunos aparecerão aqui.',
                              style: TextStyle(color: MetaColors.textSecondary),
                            ),
                          )
                        : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _studentStories.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final story = _studentStories[index];
                        final ringColor = story.isViewed
                            ? MetaColors.border
                            : MetaColors.emerald;

                        return InkWell(
                          onTap: () => _showStoryDetails(story),
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 4,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(2.5),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: ringColor,
                                      width: 2.2,
                                    ),
                                  ),
                                  child: CircleAvatar(
                                    radius: 24,
                                    backgroundColor:
                                        MetaColors.surfaceHighlight,
                                    child: Text(
                                      story.initials,
                                      style: TextStyle(
                                        color: story.isViewed
                                            ? MetaColors.textSecondary
                                            : MetaColors.emerald,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  story.name,
                                  style: const TextStyle(
                                    color: MetaColors.textPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
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
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Canais / Ranking',
                          style: TextStyle(
                            color: MetaColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: MetaColors.emerald.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.local_fire_department_rounded,
                                color: Color(0xFFF97316),
                                size: 14,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Streaks',
                                style: TextStyle(
                                  color: MetaColors.emerald,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SliverToBoxAdapter(
                  child: SizedBox(height: 8),
                ),

                // Canal oficial de avisos (estilo Canais do WhatsApp)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              backgroundColor: MetaColors.surfaceHighlight,
                              content: Text(
                                'Canal ainda não configurado. Nenhum aviso foi enviado.',
                                style: TextStyle(color: MetaColors.textPrimary),
                              ),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: MetaColors.surfaceHighlight,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: MetaColors.border,
                                    width: 1.0,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.campaign_rounded,
                                  color: MetaColors.emerald,
                                  size: 26,
                                ),
                              ),
                              const SizedBox(width: 14),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          'Canal da Consultoria',
                                          style: TextStyle(
                                            color: MetaColors.textPrimary,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                          ),
                                        ),
                                        SizedBox(width: 6),
                                        Icon(
                                          Icons.verified,
                                          color: MetaColors.accentBlue,
                                          size: 16,
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 3),
                                    Text(
                                      'Avisos e periodização coletiva para alunos',
                                      style: TextStyle(
                                        color: MetaColors.textSecondary,
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
                  ),
                ),

                const SliverToBoxAdapter(
                  child: SizedBox(height: 12),
                ),

                // 6. Lista de Ranking de Ofensivas (Streaks) de Alunos
                // Fundo transparente, sem dividers artificiais
                SliverPadding(
                  padding: EdgeInsets.only(
                    left: 12,
                    right: 12,
                    bottom: bottomPadding + 88, // Padding dinâmico Edge-to-Edge
                  ),
                  sliver: _rankingStudents.isEmpty
                      ? const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Text(
                              'O ranking ficará disponível quando houver atividades registradas.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: MetaColors.textSecondary),
                            ),
                          ),
                        )
                      : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final student = _rankingStudents[index];
                        final badgeColor = _getBadgeColor(student.category);

                        return Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            onTap: () => _congratulateStudent(student),
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              child: Row(
                                children: [
                                  // Posição no Ranking (#1, #2, #3, ...)
                                  SizedBox(
                                    width: 28,
                                    child: Center(
                                      child: Text(
                                        '#${student.rank}',
                                        style: TextStyle(
                                          color: badgeColor,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Avatar do Aluno (CircleAvatar)
                                  CircleAvatar(
                                    radius: 22,
                                    backgroundColor:
                                        MetaColors.surfaceHighlight,
                                    child: Text(
                                      student.initials,
                                      style: TextStyle(
                                        color: student.rank <= 3
                                            ? badgeColor
                                            : MetaColors.emerald,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Nome e Atividade Recente
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          student.name,
                                          style: const TextStyle(
                                            color: MetaColors.textPrimary,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          student.lastActivity,
                                          style: const TextStyle(
                                            color: MetaColors.textSecondary,
                                            fontSize: 12.5,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Badge de Ofensiva (Streaks com Ícone de Fogo)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: MetaColors.surfaceHighlight,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: student.rank <= 3
                                            ? badgeColor.withValues(alpha: 0.4)
                                            : MetaColors.border,
                                      ),
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
                                          '${student.streakDays}d',
                                          style: TextStyle(
                                            color: student.rank <= 3
                                                ? badgeColor
                                                : MetaColors.textPrimary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                      childCount: _rankingStudents.length,
                    ),
                  ),
                ),
              ],
            ),

            // Botão Flutuante (FAB): Postar Novo Status no canto inferior direito
            Positioned(
              right: 16,
              bottom: bottomPadding + 16,
              child: SquircleButton(
                icon: Icons.camera_alt_rounded,
                label: 'Status',
                isPrimary: true,
                onPressed: _showCreateStatusModal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
