import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import 'meta_components.dart';

/// Modal animado e gamificado de celebração de treino concluído (Padrão Ouro Hevy/Strong).
///
/// Apresenta troféu elástico, aura com pulso, cards de métricas em cascata (Tempo, Volume em kg, Séries),
/// indicador de Ofensiva (Streak), Recordes Pessoais (PRs batidos) e botão direto de WhatsApp.
class WorkoutTriumphModal extends StatelessWidget {
  final String workoutTitle;
  final String trainerName;
  final String? trainerPhone;
  final int durationMin;
  final double totalVolumeKg;
  final int completedSets;
  final int totalSets;
  final int? currentStreak;
  final int newPrCount;
  final VoidCallback onDismiss;

  const WorkoutTriumphModal({
    super.key,
    required this.workoutTitle,
    required this.trainerName,
    this.trainerPhone,
    required this.durationMin,
    required this.totalVolumeKg,
    required this.completedSets,
    required this.totalSets,
    this.currentStreak,
    this.newPrCount = 0,
    required this.onDismiss,
  });

  /// Exibe o modal com duplo feedback háptico
  static Future<void> show(
    BuildContext context, {
    required String workoutTitle,
    required String trainerName,
    String? trainerPhone,
    required int durationMin,
    required double totalVolumeKg,
    required int completedSets,
    required int totalSets,
    int? currentStreak,
    int newPrCount = 0,
    required VoidCallback onDismiss,
  }) async {
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 140));
    HapticFeedback.heavyImpact();

    if (!context.mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => WorkoutTriumphModal(
        workoutTitle: workoutTitle,
        trainerName: trainerName,
        trainerPhone: trainerPhone,
        durationMin: durationMin,
        totalVolumeKg: totalVolumeKg,
        completedSets: completedSets,
        totalSets: totalSets,
        currentStreak: currentStreak,
        newPrCount: newPrCount,
        onDismiss: onDismiss,
      ),
    );
  }

  void _shareOnWhatsApp(BuildContext context) {
    if (trainerPhone == null || trainerPhone!.trim().isEmpty) return;

    final cleanPhone = trainerPhone!.replaceAll(RegExp(r'\D'), '');
    final phoneWithCountry =
        cleanPhone.startsWith('55') ? cleanPhone : '55$cleanPhone';
    final prMsg = newPrCount > 0
        ? '🏆 Recordes batidos: $newPrCount novo(s) PR(s)!\n'
        : '';
    final msg = Uri.encodeComponent(
      'Fala Prof. $trainerName! 💪 Acabei de concluir o $workoutTitle!\n'
      '⏱ Tempo: $durationMin min\n'
      '📊 Volume total: ${totalVolumeKg.toStringAsFixed(0)} kg\n'
      '$prMsg'
      '🔥 Treino registrado no Mr. Coach AI.',
    );
    launchUrl(
      Uri.parse('https://api.whatsapp.com/send?phone=$phoneWithCountry&text=$msg'),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = MetaColors.isDark(context);
    final bg = isDark ? MetaColors.surface : MetaColors.lightSurface;
    final cardBg = isDark ? MetaColors.background : MetaColors.lightSurfaceHighlight;
    final border = isDark ? MetaColors.border : MetaColors.lightBorder;
    final textPrimary = isDark ? MetaColors.textPrimary : MetaColors.lightTextPrimary;
    final textSecondary = isDark ? MetaColors.textSecondary : MetaColors.lightTextSecondary;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.92,
      ),
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(
            color: MetaColors.emerald.withValues(alpha: 0.5),
            width: 1.5,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 30,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle Bar
            Center(
              child: Container(
                width: 44,
                height: 4.5,
                decoration: BoxDecoration(
                  color: textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Troféu animado central com aura radiante
            Center(
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      MetaColors.emerald.withValues(alpha: 0.35),
                      MetaColors.emerald.withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                    stops: const [0.2, 0.65, 1.0],
                  ),
                ),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: MetaColors.emerald.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: MetaColors.emerald.withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: MetaColors.emerald.withValues(alpha: 0.28),
                          blurRadius: 18,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.emoji_events_rounded,
                      size: 42,
                      color: MetaColors.emerald,
                    ),
                  ),
                ),
              ),
            )
                .animate()
                .scale(
                  begin: const Offset(0.35, 0.35),
                  end: const Offset(1, 1),
                  duration: 650.ms,
                  curve: Curves.elasticOut,
                )
                .rotate(
                  begin: -0.06,
                  end: 0,
                  duration: 600.ms,
                  curve: Curves.easeOutBack,
                ),
            const SizedBox(height: 14),

            // Título principal escalonado
            Center(
              child: Text(
                'Treino Concluído com Sucesso!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  color: textPrimary,
                ),
              ),
            )
                .animate()
                .fadeIn(duration: 400.ms, delay: 150.ms)
                .slideY(begin: 0.18, end: 0, curve: Curves.easeOutCubic),
            const SizedBox(height: 8),

            // Subtítulo em Pill com nome do treino e treinador
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: isDark
                      ? MetaColors.surfaceHighlight.withValues(alpha: 0.7)
                      : MetaColors.lightSurfaceHighlight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: border),
                ),
                child: Text(
                  '$workoutTitle · $trainerName',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: textSecondary,
                  ),
                ),
              ),
            )
                .animate()
                .fadeIn(duration: 400.ms, delay: 220.ms)
                .slideY(begin: 0.15, end: 0, curve: Curves.easeOutCubic),
            const SizedBox(height: 22),

            // Métricas em Cards One UI 7 com Animação em Cascata
            Row(
              children: [
                // Card TEMPO
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: border),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.timer_outlined,
                              size: 12,
                              color: textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'TEMPO',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: textSecondary,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '$durationMin min',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: textPrimary,
                          ),
                        ),
                      ],
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 350.ms, delay: 280.ms)
                      .slideY(begin: 0.2, end: 0, curve: Curves.easeOutQuad),
                ),
                const SizedBox(width: 8),

                // Card VOLUME (Destaque Esmeralda com Shimmer)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: MetaColors.emerald.withValues(alpha: 0.38),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: MetaColors.emerald.withValues(alpha: 0.08),
                          blurRadius: 16,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(
                              Icons.fitness_center_rounded,
                              size: 12,
                              color: MetaColors.emerald,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'VOLUME',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: MetaColors.emerald,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${totalVolumeKg.toStringAsFixed(0)} kg',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: MetaColors.emerald,
                          ),
                        ),
                      ],
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 350.ms, delay: 350.ms)
                      .slideY(begin: 0.2, end: 0, curve: Curves.easeOutQuad)
                      .shimmer(delay: 750.ms, duration: 1100.ms, color: Colors.white12),
                ),
                const SizedBox(width: 8),

                // Card SÉRIES
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: border),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_circle_outline_rounded,
                              size: 12,
                              color: textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'SÉRIES',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: textSecondary,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '$completedSets/$totalSets',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: textPrimary,
                          ),
                        ),
                      ],
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 350.ms, delay: 420.ms)
                      .slideY(begin: 0.2, end: 0, curve: Curves.easeOutQuad),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Streak / Ofensiva com Fogo Vivo Animado
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFF59E0B).withValues(alpha: 0.14),
                    const Color(0xFFD97706).withValues(alpha: 0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.38),
                  width: 1.2,
                ),
              ),
              child: Row(
                children: [
                  const Text('🔥', style: TextStyle(fontSize: 24))
                      .animate(onPlay: (controller) => controller.repeat(reverse: true))
                      .scale(
                        begin: const Offset(1, 1),
                        end: const Offset(1.18, 1.18),
                        duration: 900.ms,
                        curve: Curves.easeInOut,
                      ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentStreak != null
                              ? 'Ofensiva ativa: ${currentStreak! + 1} dias'
                              : 'Ofensiva mantida com consistência!',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Meta diária de estímulo muscular concluída com foco.',
                          style: TextStyle(
                            fontSize: 12,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
                .animate()
                .fadeIn(duration: 380.ms, delay: 490.ms)
                .slideY(begin: 0.15, end: 0, curve: Curves.easeOutCubic),

            // Destaque de Recordes Pessoais (PR) com Shimmer de Celebração
            if (newPrCount > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      MetaColors.emerald.withValues(alpha: 0.16),
                      MetaColors.emerald.withValues(alpha: 0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: MetaColors.emerald.withValues(alpha: 0.45),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  children: [
                    const Text('🏆', style: TextStyle(fontSize: 24))
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .scale(
                          begin: const Offset(1, 1),
                          end: const Offset(1.16, 1.16),
                          duration: 1100.ms,
                        ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$newPrCount Novo(s) Recorde(s) de Carga Batido(s)!',
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w900,
                              color: MetaColors.emerald,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Sua progressão de sobrecarga está evoluindo.',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
                  .animate()
                  .fadeIn(duration: 380.ms, delay: 550.ms)
                  .slideY(begin: 0.15, end: 0, curve: Curves.easeOutCubic)
                  .shimmer(delay: 900.ms, duration: 1200.ms, color: Colors.white24),
            ],
            const SizedBox(height: 24),

            // Botão Compartilhar WhatsApp com Gradiente Oficial
            if (trainerPhone != null && trainerPhone!.trim().isNotEmpty) ...[
              Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  onTap: () => _shareOnWhatsApp(context),
                  borderRadius: BorderRadius.circular(16),
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF25D366), Color(0xFF1EBE5D)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF25D366).withValues(alpha: 0.28),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.chat_bubble_rounded,
                          size: 19,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            'Compartilhar no WhatsApp de $trainerName',
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
                  .animate()
                  .fadeIn(delay: 600.ms, duration: 350.ms)
                  .slideY(begin: 0.1, end: 0),
              const SizedBox(height: 12),
            ],

            // Botão Secundário Concluir e Sair
            SquircleButton(
              label: 'Concluir e Voltar ao Início',
              icon: Icons.check_circle_outline_rounded,
              isPrimary: false,
              backgroundColor: isDark ? MetaColors.surfaceHighlight : MetaColors.lightSurfaceHighlight,
              foregroundColor: textPrimary,
              onPressed: () {
                Navigator.pop(context);
                onDismiss();
              },
            )
                .animate()
                .fadeIn(delay: 660.ms, duration: 350.ms)
                .slideY(begin: 0.1, end: 0),
          ],
        ),
      ),
    );
  }
}
