import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/widgets/meta_components.dart';
import '../../../../services/auth_service.dart';
import '../../../../services/workout_service.dart';

/// Aba 3 do Professor (Social / Atualizações)
///
/// Inspirada na aba "Atualizações" do ecossistema Meta / WhatsApp:
/// - Seção "Status" no topo com círculo do professor, status/recado publicado e edição
/// - Seção "Atualizações recentes" com carrossel dinâmico dos treinos concluídos recentemente
/// - Seção "Consistência dos alunos" (Ranking com fotos reais, ofensivas e treinos concluídos)
/// - Totalmente Edge-to-Edge nativo, sem letterbox e sem SafeAreas no Scaffold.
class TrainerSocialScreen extends StatefulWidget {
  const TrainerSocialScreen({super.key});

  @override
  State<TrainerSocialScreen> createState() => _TrainerSocialScreenState();
}

class _TrainerSocialScreenState extends State<TrainerSocialScreen> {
  List<Map<String, dynamic>> _rankingStudents = [];
  List<Map<String, dynamic>> _recentSessions = [];
  Map<String, dynamic>? _trainerStatus;
  bool _isLoading = true;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadFailed = false;
      });
    }
    try {
      final results = await Future.wait([
        WorkoutService.getTrainerGamificationRanking(),
        WorkoutService.getTrainerRecentCompletedSessions(),
        WorkoutService.getTrainerStatus(),
      ]);

      if (!mounted) return;
      setState(() {
        _rankingStudents = results[0] as List<Map<String, dynamic>>;
        _recentSessions = results[1] as List<Map<String, dynamic>>;
        _trainerStatus = results[2] as Map<String, dynamic>?;
        _isLoading = false;
      });
    } catch (error) {
      debugPrint('Erro ao carregar dados da aba social: $error');
      if (!mounted) return;
      setState(() {
        _loadFailed = true;
        _isLoading = false;
      });
    }
  }

  String _getTrainerName() {
    final statusName = _trainerStatus?['full_name'] as String?;
    if (statusName != null && statusName.trim().isNotEmpty) return statusName;
    final user = AuthService.currentUser;
    final name = user?.userMetadata?['full_name'] as String?;
    if (name != null && name.trim().isNotEmpty) return name;
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

  String? _getTrainerPhotoUrl() {
    return (_trainerStatus?['photo_url'] ?? _trainerStatus?['avatar_url']) as String?;
  }

  Color _getBadgeColor(int streakDays) {
    if (streakDays >= 30) return const Color(0xFFF59E0B);
    if (streakDays >= 7) return MetaColors.emerald;
    return MetaColors.textSecondary;
  }

  String _formatRelativeTime(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return '';
    final now = DateTime.now().toUtc();
    final diff = now.difference(date.toUtc());

    if (diff.inMinutes < 1) return 'Agora mesmo';
    if (diff.inMinutes < 60) return 'Há ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Há ${diff.inHours}h';
    if (diff.inDays == 1) return 'Ontem';
    return 'Há ${diff.inDays} dias';
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

  Widget _buildAvatar({
    String? photoUrl,
    required String initials,
    double radius = 24,
    Color? borderColor,
    Color? backgroundColor,
  }) {
    final hasPhoto = photoUrl != null && photoUrl.trim().isNotEmpty;
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor ?? MetaColors.highlight(context),
        border: borderColor != null ? Border.all(color: borderColor, width: 2) : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: hasPhoto
          ? (photoUrl.startsWith('assets/')
              ? Image.asset(photoUrl, fit: BoxFit.cover)
              : Image.network(
                  photoUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Center(
                    child: Text(
                      initials,
                      style: TextStyle(
                        color: MetaColors.text(context),
                        fontWeight: FontWeight.bold,
                        fontSize: radius * 0.7,
                      ),
                    ),
                  ),
                ))
          : Center(
              child: Text(
                initials,
                style: TextStyle(
                  color: MetaColors.text(context),
                  fontWeight: FontWeight.bold,
                  fontSize: radius * 0.7,
                ),
              ),
            ),
    );
  }

  void _openEditStatusModal() {
    final currentMsg = _trainerStatus?['status_message'] as String? ?? '';
    final ctrl = TextEditingController(text: currentMsg);
    var isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: MetaColors.card(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Mural do Treinador',
                    style: TextStyle(
                      color: MetaColors.text(ctx),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: MetaColors.subtext(ctx)),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Publique um aviso, dica ou recado motivacional para todos os seus alunos visualizarem.',
                style: TextStyle(color: MetaColors.subtext(ctx), fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                maxLines: 3,
                maxLength: 160,
                style: TextStyle(color: MetaColors.text(ctx)),
                decoration: InputDecoration(
                  hintText: 'Ex: Atenção turma: amanhã a academia abre em horário especial de feriado às 8h!',
                  hintStyle: TextStyle(color: MetaColors.subtext(ctx)),
                  filled: true,
                  fillColor: MetaColors.highlight(ctx),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (currentMsg.isNotEmpty) ...[
                    Expanded(
                      flex: 1,
                      child: OutlinedButton(
                        onPressed: isSaving
                            ? null
                            : () async {
                                setModalState(() => isSaving = true);
                                try {
                                  await WorkoutService.updateTrainerStatus('');
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  _loadAll();
                                } catch (e) {
                                  setModalState(() => isSaving = false);
                                }
                              },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(color: Colors.redAccent),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Limpar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: isSaving
                          ? null
                          : () async {
                              final text = ctrl.text.trim();
                              setModalState(() => isSaving = true);
                              try {
                                await WorkoutService.updateTrainerStatus(text);
                                if (ctx.mounted) Navigator.pop(ctx);
                                _loadAll();
                              } catch (e) {
                                setModalState(() => isSaving = false);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MetaColors.emerald,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text('Salvar e Publicar', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openSessionDetailsModal(Map<String, dynamic> session) {
    final clientName = session['client_name'] as String? ?? 'Aluno';
    final photoUrl = session['photo_url'] as String?;
    final splitId = session['split_identifier'] as String? ?? 'A';
    final splitName = session['split_name'] as String? ?? 'Treino';
    final durationSeconds = (session['duration_seconds'] as num?)?.toInt() ?? 0;
    final durationMin = (durationSeconds / 60).round();
    final completedEx = (session['completed_exercises'] as num?)?.toInt() ?? 0;
    final totalEx = (session['total_exercises'] as num?)?.toInt() ?? 0;
    final completedAt = session['completed_at'];
    final timeRelative = _formatRelativeTime(completedAt);
    final phone = session['phone'] as String?;

    final initials = clientName.trim().isNotEmpty
        ? (clientName.trim().split(' ').length > 1
            ? '${clientName.trim().split(' ')[0][0]}${clientName.trim().split(' ')[1][0]}'.toUpperCase()
            : clientName.trim().substring(0, 1).toUpperCase())
        : 'A';

    showModalBottomSheet(
      context: context,
      backgroundColor: MetaColors.card(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: MetaColors.highlight(ctx),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 18),
            _buildAvatar(
              photoUrl: photoUrl,
              initials: initials,
              radius: 36,
              borderColor: MetaColors.emerald,
            ),
            const SizedBox(height: 12),
            Text(
              clientName,
              style: TextStyle(
                color: MetaColors.text(ctx),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Treino concluído $timeRelative',
              style: TextStyle(color: MetaColors.emerald, fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: MetaColors.highlight(ctx),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text('Ficha / Split', style: TextStyle(color: MetaColors.subtext(ctx), fontSize: 11)),
                      const SizedBox(height: 4),
                      Text('Split $splitId', style: TextStyle(color: MetaColors.text(ctx), fontSize: 15, fontWeight: FontWeight.bold)),
                      Text(splitName, style: TextStyle(color: MetaColors.subtext(ctx), fontSize: 11)),
                    ],
                  ),
                  Container(width: 1, height: 36, color: MetaColors.cardBorder(ctx)),
                  Column(
                    children: [
                      Text('Duração', style: TextStyle(color: MetaColors.subtext(ctx), fontSize: 11)),
                      const SizedBox(height: 4),
                      Text('$durationMin min', style: TextStyle(color: MetaColors.text(ctx), fontSize: 15, fontWeight: FontWeight.bold)),
                      Text('Tempo total', style: TextStyle(color: MetaColors.subtext(ctx), fontSize: 11)),
                    ],
                  ),
                  Container(width: 1, height: 36, color: MetaColors.cardBorder(ctx)),
                  Column(
                    children: [
                      Text('Exercícios', style: TextStyle(color: MetaColors.subtext(ctx), fontSize: 11)),
                      const SizedBox(height: 4),
                      Text('$completedEx / $totalEx', style: TextStyle(color: MetaColors.text(ctx), fontSize: 15, fontWeight: FontWeight.bold)),
                      Text('Executados', style: TextStyle(color: MetaColors.subtext(ctx), fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final firstName = clientName.split(' ').first;
                  final msg = 'Fala $firstName! Vi aqui no Mr. Coach que você concluiu o Split $splitId ($splitName)! Parabéns pela dedicação e foco! 🔥💪';
                  final encoded = Uri.encodeComponent(msg);

                  if (phone != null && phone.trim().isNotEmpty) {
                    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
                    final uri = Uri.parse('https://wa.me/$cleanPhone?text=$encoded');
                    try {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    } catch (_) {}
                  } else {
                    // Fallback para abrir WhatsApp geral com a mensagem
                    final uri = Uri.parse('https://api.whatsapp.com/send?text=$encoded');
                    try {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    } catch (_) {}
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                icon: const Icon(Icons.chat_bubble_rounded, size: 20),
                label: const Text(
                  'Parabenizar no WhatsApp 🔥',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: MetaColors.emerald,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
              ),
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
    final trainerInitials = _getTrainerInitials();
    final trainerPhoto = _getTrainerPhotoUrl();
    final isDark = MetaColors.isDark(context);
    final statusMessage = _trainerStatus?['status_message'] as String? ?? '';
    final hasStatus = statusMessage.isNotEmpty;
    final statusUpdatedAt = _trainerStatus?['status_updated_at'];

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
              onRefresh: _loadAll,
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
                          IconButton(
                            icon: const Icon(Icons.edit_note_rounded, size: 26),
                            color: MetaColors.emerald,
                            tooltip: 'Publicar Aviso no Mural',
                            onPressed: _openEditStatusModal,
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
                        'Status do Treinador',
                        style: TextStyle(
                          color: MetaColors.text(context),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                  ),

                  // Status do Treinador (Mural / Recado Interativo)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: InkWell(
                        onTap: _openEditStatusModal,
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          child: Row(
                            children: [
                              Stack(
                                children: [
                                  _buildAvatar(
                                    photoUrl: trainerPhoto,
                                    initials: trainerInitials,
                                    radius: 28,
                                    borderColor: hasStatus ? MetaColors.emerald : null,
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: MetaColors.emerald,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: MetaColors.bg(context),
                                          width: 2,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.add,
                                        size: 13,
                                        color: Colors.white,
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
                                      hasStatus
                                          ? statusMessage
                                          : 'Toque para publicar um aviso ou dica para seus alunos.',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: hasStatus ? MetaColors.text(context) : MetaColors.subtext(context),
                                        fontSize: 13,
                                        fontWeight: hasStatus ? FontWeight.w500 : FontWeight.normal,
                                      ),
                                    ),
                                    if (hasStatus && statusUpdatedAt != null) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        _formatRelativeTime(statusUpdatedAt),
                                        style: TextStyle(color: MetaColors.emerald, fontSize: 11),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Icon(Icons.edit_outlined, size: 20, color: MetaColors.subtext(context)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 3. Seção "Atualizações Recentes" (Treinos Concluídos)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(
                        left: 20,
                        right: 20,
                        top: 20,
                        bottom: 12,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Atualizações recentes',
                            style: TextStyle(
                              color: MetaColors.text(context),
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.3,
                            ),
                          ),
                          if (_recentSessions.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: MetaColors.emerald.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${_recentSessions.length} treinos',
                                style: const TextStyle(
                                  color: MetaColors.emerald,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Carrossel Horizontal de Alunos que Treinaram
                  SliverToBoxAdapter(
                    child: _buildRecentSessionsCarousel(),
                  ),

                  const SliverToBoxAdapter(
                    child: SizedBox(height: 24),
                  ),

                  // 4. Seção "Consistência dos alunos": Cabeçalho
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Consistência dos alunos',
                            style: TextStyle(
                              color: MetaColors.text(context),
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            'Últimos 100 dias',
                            style: TextStyle(
                              color: MetaColors.subtext(context),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(
                    child: SizedBox(height: 8),
                  ),

                  // Ranking Sliver com Fotos Reais
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

  Widget _buildRecentSessionsCarousel() {
    if (_isLoading) {
      return SizedBox(
        height: 105,
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(color: MetaColors.emerald, strokeWidth: 2),
          ),
        ),
      );
    }

    if (_recentSessions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: MetaColors.card(context),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: MetaColors.cardBorder(context)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: MetaColors.highlight(context),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.fitness_center_rounded, color: MetaColors.subtext(context), size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nenhum treino finalizado hoje',
                      style: TextStyle(color: MetaColors.text(context), fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Quando os alunos finalizarem um treino no app, você poderá ver o split e parabenizá-los aqui.',
                      style: TextStyle(color: MetaColors.subtext(context), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 115,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: _recentSessions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final session = _recentSessions[index];
          final clientName = session['client_name'] as String? ?? 'Aluno';
          final firstName = clientName.split(' ').first;
          final photoUrl = session['photo_url'] as String?;
          final splitId = session['split_identifier'] as String? ?? 'A';
          final timeRelative = _formatRelativeTime(session['completed_at']);

          final initials = firstName.isNotEmpty ? firstName[0].toUpperCase() : 'A';

          return GestureDetector(
            onTap: () => _openSessionDetailsModal(session),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Anel verde de status novo
                    Container(
                      width: 66,
                      height: 66,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: MetaColors.emerald,
                          width: 2.5,
                        ),
                      ),
                    ),
                    _buildAvatar(
                      photoUrl: photoUrl,
                      initials: initials,
                      radius: 28,
                    ),
                    // Badge do Split
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: MetaColors.emerald,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: MetaColors.bg(context), width: 1.5),
                        ),
                        child: Text(
                          splitId,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: 72,
                  child: Text(
                    firstName,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: MetaColors.text(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(
                  width: 72,
                  child: Text(
                    timeRelative,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: MetaColors.emerald,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRankingSliver() {
    if (_isLoading) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator(color: MetaColors.emerald)),
        ),
      );
    }
    if (_loadFailed) {
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
                onPressed: _loadAll,
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
        final recentSessions = (student['sessions_in_window'] as num?)?.toInt() ?? 0;
        final badgeColor = _getBadgeColor(streak);
        final name = student['full_name']?.toString() ?? 'Aluno';
        final photoUrl = student['photo_url'] as String?;

        final parts = name.trim().split(RegExp(r'\s+'));
        final initials = parts.length >= 2
            ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
            : (parts.isNotEmpty && parts[0].isNotEmpty ? parts[0][0].toUpperCase() : 'A');

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
              _buildAvatar(
                photoUrl: photoUrl,
                initials: initials,
                radius: 22,
                borderColor: streak >= 7 ? badgeColor.withValues(alpha: 0.6) : null,
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
