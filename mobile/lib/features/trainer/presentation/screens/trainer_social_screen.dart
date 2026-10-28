import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/theme_controller.dart';
import '../../../../core/widgets/app_version_footer.dart';
import '../../../../core/widgets/avatar_selector_sheet.dart';
import '../../../../core/widgets/meta_components.dart';
import '../../../../services/auth_service.dart';
import '../../../../services/whatsapp_direct_service.dart';
import '../../../../services/workout_service.dart';
import 'trainer_profile_setup_screen.dart';

enum _SocialRankingFilter { all, fire, risk }

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
  _SocialRankingFilter _rankingFilter = _SocialRankingFilter.all;
  bool _isBatchCongratulating = false;
  final Set<String> _congratulatedSessionIds = {};

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
      final rawSessions = results[1] as List<Map<String, dynamic>>;
      final seenClients = <String>{};
      final uniqueSessions = <Map<String, dynamic>>[];
      for (final s in rawSessions) {
        final cid = s['client_id']?.toString() ?? s['client_name']?.toString() ?? '';
        if (cid.isNotEmpty && !seenClients.contains(cid)) {
          seenClients.add(cid);
          uniqueSessions.add(s);
        } else if (cid.isEmpty) {
          uniqueSessions.add(s);
        }
      }

      setState(() {
        _rankingStudents = results[0] as List<Map<String, dynamic>>;
        _recentSessions = uniqueSessions;
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
    final size = radius * 2;

    Widget avatarContent = ClipOval(
      child: Container(
        width: size,
        height: size,
        color: backgroundColor ?? MetaColors.card(context),
        child: hasPhoto
            ? (photoUrl.startsWith('assets/')
                ? Image.asset(
                    photoUrl,
                    fit: BoxFit.cover,
                    width: size,
                    height: size,
                  )
                : Image.network(
                    photoUrl,
                    fit: BoxFit.cover,
                    width: size,
                    height: size,
                    errorBuilder: (_, _, _) => Center(
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
      ),
    );

    if (borderColor != null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: borderColor, width: 2),
        ),
        child: avatarContent,
      );
    }

    return avatarContent;
  }

  void _openEditStatusModal({bool initialSendWaBroadcast = false}) {
    final currentMsg = _trainerStatus?['status_message'] as String? ?? '';
    final ctrl = TextEditingController(text: currentMsg);
    var isSaving = false;
    var sendWaBroadcast = initialSendWaBroadcast;

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
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildTemplateChip(
                      ctx,
                      '🔥 Desafio da Semana',
                      '🔥 Desafio da Semana: Quem fechar 100% dos treinos entra no destaque de sexta!',
                      ctrl,
                    ),
                    const SizedBox(width: 8),
                    _buildTemplateChip(
                      ctx,
                      '⏰ Aviso Feriado',
                      '⏰ Horário Especial: Atenção ao cronograma diferenciado de feriado!',
                      ctrl,
                    ),
                    const SizedBox(width: 8),
                    _buildTemplateChip(
                      ctx,
                      '💧 Dica de Hidratação',
                      '💧 Dica do Coach: Aumentem 500ml de água hoje para acelerar a recuperação muscular.',
                      ctrl,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
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
              const SizedBox(height: 10),
              // Switch de Disparo WhatsApp In-App via Robô
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: MetaColors.emerald.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: MetaColors.emerald.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.smart_toy_rounded, color: MetaColors.emerald, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Disparar no WhatsApp (In-App)',
                            style: TextStyle(
                              color: MetaColors.emerald,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Envia via robô para alunos ativos sem abrir o app externo',
                            style: TextStyle(
                              color: MetaColors.subtext(ctx),
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: sendWaBroadcast,
                      activeTrackColor: MetaColors.emerald,
                      onChanged: (val) {
                        setModalState(() => sendWaBroadcast = val);
                      },
                    ),
                  ],
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

                                if (sendWaBroadcast && text.isNotEmpty) {
                                  _broadcastStatusToStudents(text);
                                }
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

  Widget _buildTemplateChip(
    BuildContext ctx,
    String label,
    String templateText,
    TextEditingController ctrl,
  ) {
    return InkWell(
      onTap: () {
        ctrl.text = templateText;
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: MetaColors.highlight(ctx),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: MetaColors.cardBorder(ctx)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: MetaColors.text(ctx),
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Future<void> _broadcastStatusToStudents(String text) async {
    if (_rankingStudents.isEmpty) return;
    int sentCount = 0;
    for (final st in _rankingStudents.take(15)) {
      final phone = st['phone']?.toString();
      final name = st['full_name']?.toString() ?? 'Aluno';
      final firstName = name.split(' ').first;
      final studentId = st['client_id']?.toString();
      if (phone != null && phone.isNotEmpty) {
        final res = await WhatsAppDirectService.sendOneClick(
          context: context,
          phone: phone,
          studentId: studentId,
          studentName: name,
          message: 'Fala $firstName! Recado do seu treinador no Mr. Coach:\n\n"$text"',
          category: 'trainer_mural_broadcast',
          showFeedback: false,
          allowExternalFallback: false,
        );
        if (res.sentInApp) sentCount++;
      }
    }
    if (mounted && sentCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: MetaColors.emerald,
          behavior: SnackBarBehavior.floating,
          content: Text(
            '📢 Recado disparado via Robô para $sentCount alunos no WhatsApp!',
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w800),
          ),
        ),
      );
    }
  }

  Future<void> _updateTrainerProfilePhoto() async {
    final currentPhoto = _getTrainerPhotoUrl();
    final selected = await AvatarSelectorSheet.show(
      context: context,
      isTrainer: true,
      currentUrl: currentPhoto,
    );
    if (selected != null && mounted) {
      try {
        final supabase = Supabase.instance.client;
        final user = supabase.auth.currentUser;
        if (user != null) {
          await supabase.from('profiles').update({
            'photo_url': selected,
            'avatar_url': selected,
          }).eq('id', user.id);

          await supabase.auth.updateUser(
            UserAttributes(data: {
              'photo_url': selected,
              'avatar_url': selected,
            }),
          );
        }
        await _loadAll();
        WorkoutService.studentsRefreshNotifier.value++;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Foto de perfil atualizada com sucesso!',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              backgroundColor: MetaColors.emerald,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        debugPrint('Erro ao atualizar foto de perfil: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Não foi possível salvar a foto: $e',
                style: const TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    }
  }

  void _openSessionDetailsModal(Map<String, dynamic> session) {
    final clientName = session['client_name'] as String? ?? 'Aluno';
    final photoUrl = session['photo_url'] as String?;
    final splitId = session['split_identifier'] as String? ?? 'A';
    final splitName = session['split_name'] as String? ?? 'Treino Completo';
    final durationSeconds = (session['duration_seconds'] as num?)?.toInt() ?? 0;
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

    final String formattedDuration;
    if (durationSeconds <= 0) {
      formattedDuration = '~45 min';
    } else if (durationSeconds < 60) {
      formattedDuration = '${durationSeconds}s';
    } else {
      formattedDuration = '${(durationSeconds / 60).round()} min';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: MetaColors.card(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        String cleanPhone = (phone ?? '').replaceAll(RegExp(r'\D'), '');
        if (cleanPhone.isNotEmpty) {
          if (cleanPhone.length == 10 || cleanPhone.length == 11) {
            cleanPhone = '55$cleanPhone';
          }
        }

        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              20,
              18,
              20,
              24 + MediaQuery.of(ctx).padding.bottom,
            ),
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
                  style: const TextStyle(color: MetaColors.emerald, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: MetaColors.highlight(ctx),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: MetaColors.cardBorder(ctx)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: MetaColors.emerald.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'SPLIT $splitId',
                              style: const TextStyle(
                                color: MetaColors.emerald,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              splitName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: MetaColors.text(ctx),
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Divider(height: 1, color: MetaColors.cardBorder(ctx)),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                Text('Duração', style: TextStyle(color: MetaColors.subtext(ctx), fontSize: 11)),
                                const SizedBox(height: 4),
                                Text(
                                  formattedDuration,
                                  style: TextStyle(color: MetaColors.text(ctx), fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Text('Tempo total', style: TextStyle(color: MetaColors.subtext(ctx), fontSize: 10)),
                              ],
                            ),
                          ),
                          Container(width: 1, height: 32, color: MetaColors.cardBorder(ctx)),
                          Expanded(
                            child: Column(
                              children: [
                                Text('Exercícios', style: TextStyle(color: MetaColors.subtext(ctx), fontSize: 11)),
                                const SizedBox(height: 4),
                                Text(
                                  '$completedEx / $totalEx',
                                  style: TextStyle(color: MetaColors.text(ctx), fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Text('Executados', style: TextStyle(color: MetaColors.subtext(ctx), fontSize: 10)),
                              ],
                            ),
                          ),
                          Container(width: 1, height: 32, color: MetaColors.cardBorder(ctx)),
                          Expanded(
                            child: Column(
                              children: [
                                Text('Status', style: TextStyle(color: MetaColors.subtext(ctx), fontSize: 11)),
                                const SizedBox(height: 4),
                                const Text(
                                  'Concluído 🔥',
                                  style: TextStyle(color: MetaColors.emerald, fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Text('Meta batida', style: TextStyle(color: MetaColors.subtext(ctx), fontSize: 10)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final firstName = clientName.split(' ').first;
                      final msg = 'Fala $firstName! Vi aqui no Mr. Coach que você concluiu o Split $splitId ($splitName)! Parabéns pela dedicação e foco! 🔥💪';
                      if (ctx.mounted) Navigator.pop(ctx);
                      await WhatsAppDirectService.sendOneClick(
                        context: context,
                        phone: cleanPhone,
                        studentId: session['client_id']?.toString(),
                        studentName: clientName,
                        message: msg,
                        category: 'social_session_congrats',
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MetaColors.emerald,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_outlined, size: 20, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          'Parabenizar no WhatsApp 🔥',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                if (cleanPhone.isEmpty)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.info_outline, size: 12, color: MetaColors.subtext(ctx)),
                      const SizedBox(width: 6),
                      Text(
                        'WhatsApp não salvo: abrirá para você escolher o contato',
                        style: TextStyle(color: MetaColors.subtext(ctx), fontSize: 11),
                      ),
                    ],
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle_outline, size: 12, color: MetaColors.emerald),
                      const SizedBox(width: 6),
                      Text(
                        'Enviando para $phone',
                        style: const TextStyle(color: MetaColors.emerald, fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
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
                  // 1. Topo M3: Título da Aba "Comunidade" + Status Pill do Robô WA + Popover One UI
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
                          Row(
                            children: [
                              Text(
                                'Comunidade',
                                style: TextStyle(
                                  color: MetaColors.text(context),
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: MetaColors.emerald.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: MetaColors.emerald.withValues(alpha: 0.35)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.smart_toy_rounded, size: 12, color: MetaColors.emerald),
                                    SizedBox(width: 4),
                                    Text(
                                      'Robô WA Ativo',
                                      style: TextStyle(
                                        color: MetaColors.emerald,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          OneUiPopoverMenuButton(
                            showBadgeDot: true,
                            items: [
                              OneUiPopoverItem(
                                label: 'Novidades da versão',
                                icon: Icons.new_releases_outlined,
                                showOrangeDot: true,
                                onTap: () =>
                                    AppVersionFooter.showReleaseNotesModal(
                                      context,
                                    ),
                              ),
                              OneUiPopoverItem(
                                label: 'Alternar modo visual',
                                icon: isDark
                                    ? Icons.light_mode_outlined
                                    : Icons.dark_mode_outlined,
                                onTap: () =>
                                    ThemeController.instance.toggleTheme(),
                              ),
                              OneUiPopoverItem(
                                label: 'Configurar Vitrine',
                                icon: Icons.storefront_outlined,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const TrainerProfileSetupScreen(),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 2. Card Editorial: Pulso da Turma (Últimos 7 dias)
                  SliverToBoxAdapter(
                    child: _buildCommunityPulseBanner(),
                  ),

                  // 3. Seção "Mural do Treinador"
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(
                        left: 20,
                        right: 20,
                        top: 8,
                        bottom: 8,
                      ),
                      child: Text(
                        'Mural do Treinador',
                        style: TextStyle(
                          color: MetaColors.text(context),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                  ),

                  // Status do Treinador (Avatar para Trocar Foto + Recado Interativo + Ações Rápidas)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Container(
                        decoration: BoxDecoration(
                          color: MetaColors.card(context),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: MetaColors.cardBorder(context)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  // Avatar do Treinador: Tocar para alterar foto de perfil
                                  InkWell(
                                    onTap: _updateTrainerProfilePhoto,
                                    borderRadius: BorderRadius.circular(32),
                                    child: Stack(
                                      children: [
                                        _buildAvatar(
                                          photoUrl: trainerPhoto,
                                          initials: trainerInitials,
                                          radius: 26,
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
                                                color: MetaColors.card(context),
                                                width: 2,
                                              ),
                                            ),
                                            child: const Icon(
                                              Icons.camera_alt_rounded,
                                              size: 11,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Clique no texto e recado para editar o status
                                  Expanded(
                                    child: InkWell(
                                      onTap: _openEditStatusModal,
                                      borderRadius: BorderRadius.circular(12),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                'Meu aviso atual',
                                                style: TextStyle(
                                                  color: MetaColors.text(context),
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 14.5,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              const Icon(
                                                Icons.edit_outlined,
                                                size: 14,
                                                color: MetaColors.emerald,
                                              ),
                                            ],
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
                                              fontSize: 12.5,
                                              fontWeight: hasStatus ? FontWeight.w500 : FontWeight.normal,
                                            ),
                                          ),
                                          if (hasStatus && statusUpdatedAt != null) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              _formatRelativeTime(statusUpdatedAt),
                                              style: const TextStyle(color: MetaColors.emerald, fontSize: 10.5),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Divider(height: 1, color: MetaColors.cardBorder(context)),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: InkWell(
                                      onTap: () => _openEditStatusModal(initialSendWaBroadcast: false),
                                      borderRadius: BorderRadius.circular(10),
                                      child: Container(
                                        height: 36,
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                        decoration: BoxDecoration(
                                          color: MetaColors.highlight(context),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Center(
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              '✏️ Editar Aviso',
                                              maxLines: 1,
                                              style: TextStyle(
                                                color: MetaColors.text(context),
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: InkWell(
                                      onTap: () => _openEditStatusModal(initialSendWaBroadcast: true),
                                      borderRadius: BorderRadius.circular(10),
                                      child: Container(
                                        height: 36,
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                        decoration: BoxDecoration(
                                          color: MetaColors.emerald.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: MetaColors.emerald.withValues(alpha: 0.35)),
                                        ),
                                        child: const Center(
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              '🤖 Disparar no WhatsApp',
                                              maxLines: 1,
                                              style: TextStyle(
                                                color: MetaColors.emerald,
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 4. Seção "Finalizaram hoje" (Treinos Concluídos) com Ação em Lote
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(
                        left: 20,
                        right: 20,
                        top: 20,
                        bottom: 10,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Finalizaram hoje',
                                style: TextStyle(
                                  color: MetaColors.text(context),
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              if (_recentSessions.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: MetaColors.emerald.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${_recentSessions.length}',
                                    style: const TextStyle(
                                      color: MetaColors.emerald,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (_recentSessions.isNotEmpty)
                            InkWell(
                              onTap: _isBatchCongratulating ? null : _congratulateAllToday,
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: MetaColors.emerald,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: MetaColors.emerald.withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_isBatchCongratulating)
                                      const SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    else
                                      const Icon(Icons.bolt_rounded, size: 14, color: Colors.white),
                                    const SizedBox(width: 4),
                                    const Text(
                                      'Parabenizar Todos',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
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
                    child: SizedBox(height: 20),
                  ),

                  // 5. Seção "Consistência & Retenção": Cabeçalho + Chips de Filtro
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Consistência & Retenção',
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

                  // Chips de Filtro (One UI)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 10, bottom: 8),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            _buildFilterChip('🏆 Ranking Geral', _SocialRankingFilter.all),
                            const SizedBox(width: 8),
                            _buildFilterChip('🔥 Em Chamas (+7d)', _SocialRankingFilter.fire),
                            const SizedBox(width: 8),
                            _buildFilterChip('⚠️ Sumidos (+4d)', _SocialRankingFilter.risk, isRisk: true),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Pódio Top 3 (Se houver pelo menos 3 alunos no filtro e não for 'risk')
                  if (!_isLoading &&
                      !_loadFailed &&
                      _rankingFilter != _SocialRankingFilter.risk &&
                      _getFilteredStudents().length >= 3)
                    SliverToBoxAdapter(
                      child: _buildPodiumTop3(_getFilteredStudents().take(3).toList()),
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

  Widget _buildCommunityPulseBanner() {
    final totalCompleted = _recentSessions.length;
    final inStreakCount = _rankingStudents.where((s) {
      final st = (s['current_streak'] as num?)?.toInt() ?? 0;
      return st >= 3;
    }).length;
    final totalStudents = _rankingStudents.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              MetaColors.emerald.withValues(alpha: 0.18),
              const Color(0xFF06B6D4).withValues(alpha: 0.08),
            ],
          ),
          border: Border.all(
            color: MetaColors.emerald.withValues(alpha: 0.28),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.bolt_rounded, size: 14, color: MetaColors.emerald),
                SizedBox(width: 4),
                Text(
                  'PULSO DA TURMA • ÚLTIMOS 7 DIAS',
                  style: TextStyle(
                    color: MetaColors.emerald,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              inStreakCount > 0
                  ? '$inStreakCount alunos mantendo ofensiva ativa hoje'
                  : 'Acompanhe o engajamento e a disciplina dos seus alunos',
              style: TextStyle(
                color: MetaColors.text(context),
                fontSize: 14.5,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMiniStat(
                    title: 'Treinos hoje',
                    value: '$totalCompleted',
                    color: MetaColors.text(context),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMiniStat(
                    title: 'Em ofensiva',
                    value: '$inStreakCount 🔥',
                    color: MetaColors.emerald,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMiniStat(
                    title: 'Total alunos',
                    value: '$totalStudents',
                    color: const Color(0xFF06B6D4),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat({
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: MetaColors.card(context).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MetaColors.cardBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: MetaColors.subtext(context),
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, _SocialRankingFilter filter, {bool isRisk = false}) {
    final isSelected = _rankingFilter == filter;
    final activeColor = isRisk ? const Color(0xFFF43F5E) : MetaColors.emerald;

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _rankingFilter = filter);
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor
              : MetaColors.card(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? activeColor
                : MetaColors.cardBorder(context),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : MetaColors.subtext(context),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getFilteredStudents() {
    switch (_rankingFilter) {
      case _SocialRankingFilter.fire:
        return _rankingStudents.where((s) {
          final streak = (s['current_streak'] as num?)?.toInt() ?? 0;
          return streak >= 7;
        }).toList();
      case _SocialRankingFilter.risk:
        return _rankingStudents.where((s) {
          final streak = (s['current_streak'] as num?)?.toInt() ?? 0;
          final lastDate = DateTime.tryParse(s['last_activity_date']?.toString() ?? '');
          if (lastDate == null) return true;
          final days = DateTime.now().toUtc().difference(lastDate.toUtc()).inDays;
          return streak == 0 || days >= 4;
        }).toList();
      case _SocialRankingFilter.all:
        return _rankingStudents;
    }
  }

  Widget _buildPodiumTop3(List<Map<String, dynamic>> top3) {
    if (top3.length < 3) return const SizedBox.shrink();

    final first = top3[0];
    final second = top3[1];
    final third = top3[2];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          color: MetaColors.card(context),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: MetaColors.cardBorder(context)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // 2nd Place (Left)
            Expanded(
              child: _buildPodiumColumn(
                student: second,
                rank: 2,
                borderColor: const Color(0xFF94A3B8),
                badgeColor: const Color(0xFFCBD5E1),
                isFirst: false,
              ),
            ),
            const SizedBox(width: 8),
            // 1st Place (Center - Higher)
            Expanded(
              child: _buildPodiumColumn(
                student: first,
                rank: 1,
                borderColor: const Color(0xFFF59E0B),
                badgeColor: const Color(0xFFF59E0B),
                isFirst: true,
              ),
            ),
            const SizedBox(width: 8),
            // 3rd Place (Right)
            Expanded(
              child: _buildPodiumColumn(
                student: third,
                rank: 3,
                borderColor: const Color(0xFFD97706),
                badgeColor: const Color(0xFFB45309),
                isFirst: false,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPodiumColumn({
    required Map<String, dynamic> student,
    required int rank,
    required Color borderColor,
    required Color badgeColor,
    required bool isFirst,
  }) {
    final name = student['full_name']?.toString() ?? 'Aluno';
    final firstName = name.trim().split(RegExp(r'\s+')).first;
    final photoUrl = student['photo_url'] as String?;
    final streak = (student['current_streak'] as num?)?.toInt() ?? 0;
    final sessions = (student['sessions_in_window'] as num?)?.toInt() ?? 0;

    final parts = name.trim().split(RegExp(r'\s+'));
    final initials = parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : (parts.isNotEmpty && parts[0].isNotEmpty ? parts[0][0].toUpperCase() : 'A');

    return Container(
      padding: EdgeInsets.symmetric(vertical: isFirst ? 14 : 10, horizontal: 4),
      decoration: BoxDecoration(
        color: isFirst
            ? const Color(0xFFF59E0B).withValues(alpha: 0.08)
            : MetaColors.highlight(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isFirst
              ? const Color(0xFFF59E0B).withValues(alpha: 0.35)
              : MetaColors.cardBorder(context),
          width: isFirst ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isFirst) ...[
            const Text('👑', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 2),
          ] else ...[
            const SizedBox(height: 18),
          ],
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              _buildAvatar(
                photoUrl: photoUrl,
                initials: initials,
                radius: isFirst ? 26 : 22,
                borderColor: borderColor,
              ),
              Positioned(
                bottom: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '#$rank',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            firstName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: MetaColors.text(context),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '🔥 ${streak}d',
              style: const TextStyle(
                color: Color(0xFFF59E0B),
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '$sessions treinos',
              style: TextStyle(
                color: MetaColors.subtext(context),
                fontSize: 9.5,
              ),
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: InkWell(
              onTap: () => _congratulateStudentStreak(student),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: MetaColors.emerald.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: MetaColors.emerald.withValues(alpha: 0.35)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('🤖', style: TextStyle(fontSize: 10)),
                    SizedBox(width: 2),
                    Text(
                      'Parabenizar',
                      style: TextStyle(
                        color: MetaColors.emerald,
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentSessionsCarousel() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 14),
        child: SizedBox(
          height: 120,
          child: ShaipadosLoaderContainer(
            type: ShaipadosLoaderType.executiveShimmer,
            isOverlay: false,
            customTitle: 'Carregando atualizações...',
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
      height: 145,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: _recentSessions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final session = _recentSessions[index];
          final clientName = session['client_name'] as String? ?? 'Aluno';
          final firstName = clientName.split(' ').first;
          final photoUrl = session['photo_url'] as String?;
          final splitId = session['split_identifier'] as String? ?? 'A';
          final timeRelative = _formatRelativeTime(session['completed_at']);
          final sessionId = session['id']?.toString() ?? clientName;
          final isAlreadyCongratulated = _congratulatedSessionIds.contains(sessionId);

          final initials = firstName.isNotEmpty ? firstName[0].toUpperCase() : 'A';

          return Container(
            width: 90,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              color: MetaColors.card(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: MetaColors.cardBorder(context)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => _openSessionDetailsModal(session),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Anel verde de status
                      Container(
                        width: 58,
                        height: 58,
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
                        radius: 24,
                      ),
                      // Badge do Split
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: MetaColors.emerald,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: MetaColors.card(context), width: 1.5),
                          ),
                          child: Text(
                            splitId,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  firstName,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: MetaColors.text(context),
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  timeRelative,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: MetaColors.subtext(context),
                    fontSize: 9.5,
                  ),
                ),
                const SizedBox(height: 4),
                // Botão Rápido 1-Clique In-App
                InkWell(
                  onTap: isAlreadyCongratulated
                      ? null
                      : () async {
                          final phone = session['phone'] as String?;
                          final splitName = session['split_name'] as String? ?? 'Treino';
                          final clientId = session['client_id'] as String?;
                          final msg = 'Fala $firstName! Vi aqui no Mr. Coach que você concluiu o Split $splitId ($splitName)! Parabéns pela dedicação e foco! 🔥💪';

                          final res = await WhatsAppDirectService.sendOneClick(
                            context: context,
                            phone: phone,
                            studentId: clientId,
                            studentName: clientName,
                            message: msg,
                            category: 'social_session_congrats',
                          );
                          if (res.sentInApp && mounted) {
                            setState(() {
                              _congratulatedSessionIds.add(sessionId);
                            });
                          }
                        },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    decoration: BoxDecoration(
                      color: isAlreadyCongratulated
                          ? MetaColors.highlight(context)
                          : MetaColors.emerald.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: isAlreadyCongratulated
                          ? null
                          : Border.all(color: MetaColors.emerald.withValues(alpha: 0.35)),
                    ),
                    child: Center(
                      child: Text(
                        isAlreadyCongratulated ? '✓ Enviado' : '🤖 👏 In-App',
                        style: TextStyle(
                          color: isAlreadyCongratulated ? MetaColors.subtext(context) : MetaColors.emerald,
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
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
    );
  }

  Widget _buildRankingSliver() {
    if (_isLoading) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 20),
          child: SizedBox(
            height: 180,
            child: ShaipadosLoaderContainer(
              type: ShaipadosLoaderType.executiveShimmer,
              isOverlay: false,
              customTitle: 'Sincronizando consistência...',
            ),
          ),
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

    final filtered = _getFilteredStudents();

    if (filtered.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              _rankingFilter == _SocialRankingFilter.risk
                  ? '🎉 Parabéns! Nenhum aluno com risco de abandono ou sem treinar há mais de 4 dias.'
                  : 'Ainda não há atividades registradas para este filtro.',
              textAlign: TextAlign.center,
              style: TextStyle(color: MetaColors.subtext(context), fontSize: 13),
            ),
          ),
        ),
      );
    }

    // Se o pódio estiver ativo (3 ou mais alunos e não for filtro de risco), começamos da 4ª posição (índice 3)
    final bool hasPodium = _rankingFilter != _SocialRankingFilter.risk && filtered.length >= 3;
    final displayList = hasPodium ? filtered.sublist(3) : filtered;
    final int startIndexOffset = hasPodium ? 3 : 0;

    if (displayList.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverList.separated(
      itemCount: displayList.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final student = displayList[index];
        final actualRank = startIndexOffset + index + 1;
        final streak = (student['current_streak'] as num?)?.toInt() ?? 0;
        final recentSessions = (student['sessions_in_window'] as num?)?.toInt() ?? 0;
        final isRisk = _rankingFilter == _SocialRankingFilter.risk || streak == 0;
        final badgeColor = isRisk ? const Color(0xFFF43F5E) : _getBadgeColor(streak);
        final name = student['full_name']?.toString() ?? 'Aluno';
        final photoUrl = student['photo_url'] as String?;

        final parts = name.trim().split(RegExp(r'\s+'));
        final initials = parts.length >= 2
            ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
            : (parts.isNotEmpty && parts[0].isNotEmpty ? parts[0][0].toUpperCase() : 'A');

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: MetaColors.card(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isRisk
                    ? const Color(0xFFF43F5E).withValues(alpha: 0.25)
                    : MetaColors.cardBorder(context),
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Center(
                    child: Text(
                      '#$actualRank',
                      style: TextStyle(
                        color: badgeColor,
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _buildAvatar(
                  photoUrl: photoUrl,
                  initials: initials,
                  radius: 20,
                  borderColor: streak >= 7 ? badgeColor.withValues(alpha: 0.6) : null,
                ),
                const SizedBox(width: 10),
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
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isRisk
                            ? '${_formatLastActivity(student['last_activity_date'])} · Sem treinar recente'
                            : '${_formatLastActivity(student['last_activity_date'])} · $recentSessions treinos em 100d',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isRisk ? const Color(0xFFF43F5E) : MetaColors.subtext(context),
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: MetaColors.highlight(context),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isRisk ? Icons.warning_amber_rounded : Icons.local_fire_department_rounded,
                        color: isRisk ? const Color(0xFFF43F5E) : const Color(0xFFF97316),
                        size: 13,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${streak}d',
                        style: TextStyle(
                          color: badgeColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: () => isRisk
                      ? _rescueStudentNudge(student)
                      : _congratulateStudentStreak(student),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: isRisk
                          ? const Color(0xFFF43F5E).withValues(alpha: 0.14)
                          : MetaColors.emerald.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isRisk
                            ? const Color(0xFFF43F5E).withValues(alpha: 0.38)
                            : MetaColors.emerald.withValues(alpha: 0.38),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(isRisk ? '🛟' : '🤖', style: const TextStyle(fontSize: 11)),
                        const SizedBox(width: 3),
                        Text(
                          isRisk ? 'Resgatar' : '1-Click',
                          style: TextStyle(
                            color: isRisk ? const Color(0xFFF43F5E) : MetaColors.emerald,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _congratulateStudentStreak(Map<String, dynamic> student) async {
    HapticFeedback.lightImpact();
    final clientId = student['client_id'] as String? ?? '';
    final name = student['full_name']?.toString() ?? 'Aluno';
    final firstName = name.trim().split(RegExp(r'\s+')).first;
    final streak = (student['current_streak'] as num?)?.toInt() ?? 0;
    final sessionsInWindow = (student['sessions_in_window'] as num?)?.toInt() ?? 0;
    final phone = student['phone'] as String? ?? '';

    final msg = streak > 0
        ? 'Fala $firstName! Vi aqui no Mr. Coach que você bateu $streak ${streak == 1 ? "dia seguido" : "dias seguidos"} de treino 🔥 Parabéns pela disciplina! Vamos pra cima! 💪'
        : 'Fala $firstName! Passando pelo ranking do Mr. Coach pra reconhecer seus $sessionsInWindow treinos concluídos! Bora manter o ritmo! 🔥💪';

    await WhatsAppDirectService.sendOneClick(
      context: context,
      phone: phone,
      studentId: clientId,
      studentName: name,
      message: msg,
      category: 'social_streak_congrats',
    );
  }

  Future<void> _rescueStudentNudge(Map<String, dynamic> student) async {
    HapticFeedback.lightImpact();
    final clientId = student['client_id'] as String? ?? '';
    final name = student['full_name']?.toString() ?? 'Aluno';
    final firstName = name.trim().split(RegExp(r'\s+')).first;
    final phone = student['phone'] as String? ?? '';

    final msg = 'Fala $firstName! Senti sua falta nos treinos esses dias! Está tudo bem por aí? Me avisa se precisar ajustar a periodização ou o volume, estou aqui contigo! Bora retomar! 🔥💪';

    await WhatsAppDirectService.sendOneClick(
      context: context,
      phone: phone,
      studentId: clientId,
      studentName: name,
      message: msg,
      category: 'social_rescue_nudge',
    );
  }

  Future<void> _congratulateAllToday() async {
    if (_recentSessions.isEmpty || _isBatchCongratulating) return;
    setState(() => _isBatchCongratulating = true);
    HapticFeedback.mediumImpact();

    int successCount = 0;
    for (final session in _recentSessions) {
      final clientName = session['client_name'] as String? ?? 'Aluno';
      final firstName = clientName.split(' ').first;
      final splitId = session['split_identifier'] as String? ?? 'A';
      final splitName = session['split_name'] as String? ?? 'Treino';
      final phone = session['phone'] as String?;
      final clientId = session['client_id'] as String?;
      final sessionId = session['id']?.toString() ?? clientName;

      final msg = 'Fala $firstName! Vi aqui no Mr. Coach que você concluiu o Split $splitId ($splitName) hoje! Parabéns pela dedicação e foco! 🔥💪';

      final res = await WhatsAppDirectService.sendOneClick(
        context: context,
        phone: phone,
        studentId: clientId,
        studentName: clientName,
        message: msg,
        category: 'social_batch_today_congrats',
        showFeedback: false,
        allowExternalFallback: false,
      );
      if (res.sentInApp) {
        successCount++;
        _congratulatedSessionIds.add(sessionId);
      }
    }

    if (mounted) {
      setState(() => _isBatchCongratulating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: MetaColors.emerald,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.black, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  successCount > 0
                      ? '🚀 $successCount incentivos enviados no WhatsApp dos alunos com 1 clique!'
                      : 'Incentivos disparados para os alunos de hoje!',
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }
}
