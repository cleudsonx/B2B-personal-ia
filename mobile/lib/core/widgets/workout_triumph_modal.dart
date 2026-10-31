import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'meta_components.dart';

/// Modal animado e gamificado de celebração de treino concluído (Padrão Ouro Hevy/Strong).
///
/// Apresenta troféu elástico, aura com pulso, cards de métricas em cascata (Tempo, Volume em kg, Séries),
/// seletor tátil de RPE (Percepção Subjetiva de Esforço 1 a 10), indicador de Ofensiva (Streak),
/// Recordes Pessoais (PRs batidos), botão de Card Comemorativo de Triunfo (Story / Redes)
/// e compartilhamento via WhatsApp.
class WorkoutTriumphModal extends StatefulWidget {
  final String workoutTitle;
  final String trainerName;
  final String? studentName;
  final String? trainerPhone;
  final String? trainerCref;
  final String? trainerUsername;
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
    this.studentName,
    this.trainerPhone,
    this.trainerCref,
    this.trainerUsername,
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
    String? studentName,
    String? trainerPhone,
    String? trainerCref,
    String? trainerUsername,
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
        studentName: studentName,
        trainerPhone: trainerPhone,
        trainerCref: trainerCref,
        trainerUsername: trainerUsername,
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

  @override
  State<WorkoutTriumphModal> createState() => _WorkoutTriumphModalState();
}

class _WorkoutTriumphModalState extends State<WorkoutTriumphModal> {
  int _selectedRpe = 8; // Padrão: 8/10 (Intenso/Efetivo)

  String _getRpeLabel(int rpe) {
    if (rpe <= 2) return 'Muito Leve • Regenerativo';
    if (rpe <= 4) return 'Leve • Cargas Confortáveis';
    if (rpe <= 6) return 'Moderado • Ritmo Constante';
    if (rpe <= 8) return 'Intenso • Próximo à Falha (Ideal)';
    if (rpe == 9) return 'Muito Intenso • 1 Rep da Falha';
    return 'Máximo Absoluto • Até a Falha Total';
  }

  Color _getRpeColor(int rpe) {
    if (rpe <= 3) return Colors.lightGreenAccent;
    if (rpe <= 6) return MetaColors.emerald;
    if (rpe <= 8) return Colors.amber;
    if (rpe == 9) return Colors.deepOrangeAccent;
    return Colors.redAccent;
  }

  Future<void> _saveRpeToPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('last_session_rpe', _selectedRpe);
      await prefs.setString(
        'last_session_rpe_date',
        DateTime.now().toIso8601String(),
      );
    } catch (_) {}
  }

  String _buildFormattedSummary() {
    final prText = widget.newPrCount > 0
        ? '\n🏆 ${widget.newPrCount} NOVO(S) RECORDE(S) DE CARGA (PR)!'
        : '';
    final streakText = (widget.currentStreak != null && widget.currentStreak! > 0)
        ? '\n🔥 Ofensiva: ${widget.currentStreak} dias consecutivos!'
        : '';
    final volText = widget.totalVolumeKg >= 1000
        ? '${(widget.totalVolumeKg / 1000).toStringAsFixed(1)} toneladas'
        : '${widget.totalVolumeKg.toStringAsFixed(0)} kg';

    return '⚡ TREINO CONCLUÍDO NO MR. COACH AI! ⚡\n'
        '🏋️ ${widget.workoutTitle}\n'
        '⏱ Duração: ${widget.durationMin} minutos\n'
        '📊 Volume Total: $volText\n'
        '🎯 Séries: ${widget.completedSets}/${widget.totalSets}\n'
        '💥 RPE: $_selectedRpe/10 (${_getRpeLabel(_selectedRpe)})'
        '$prText$streakText\n'
        '💪 Personal Trainer: Prof. ${widget.trainerName}\n'
        '📲 shaipados.com';
  }

  void _shareOnWhatsApp(BuildContext context) {
    _saveRpeToPreferences();
    if (widget.trainerPhone == null || widget.trainerPhone!.trim().isEmpty) return;

    final cleanPhone = widget.trainerPhone!.replaceAll(RegExp(r'\D'), '');
    final phoneWithCountry =
        cleanPhone.startsWith('55') ? cleanPhone : '55$cleanPhone';
    final prMsg = widget.newPrCount > 0
        ? '🏆 Recordes batidos: ${widget.newPrCount} novo(s) PR(s)!\n'
        : '';
    final rpeMsg = '💥 Intensidade Percebida: $_selectedRpe/10 (${_getRpeLabel(_selectedRpe)})\n';

    final msg = Uri.encodeComponent(
      'Fala Prof. ${widget.trainerName}! 💪 Acabei de concluir o ${widget.workoutTitle}!\n'
      '⏱ Tempo: ${widget.durationMin} min\n'
      '📊 Volume total: ${widget.totalVolumeKg.toStringAsFixed(0)} kg\n'
      '$rpeMsg'
      '$prMsg'
      '🔥 Treino registrado no Mr. Coach AI.',
    );
    launchUrl(
      Uri.parse('https://api.whatsapp.com/send?phone=$phoneWithCountry&text=$msg'),
      mode: LaunchMode.externalApplication,
    );
  }

  void _showShareCardDialog(BuildContext context) {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (ctx) => WorkoutShareCardDialog(
        workoutTitle: widget.workoutTitle,
        trainerName: widget.trainerName,
        studentName: widget.studentName,
        trainerCref: widget.trainerCref,
        trainerUsername: widget.trainerUsername,
        durationMin: widget.durationMin,
        totalVolumeKg: widget.totalVolumeKg,
        completedSets: widget.completedSets,
        totalSets: widget.totalSets,
        currentStreak: widget.currentStreak,
        newPrCount: widget.newPrCount,
        rpe: _selectedRpe,
        rpeLabel: _getRpeLabel(_selectedRpe),
        rpeColor: _getRpeColor(_selectedRpe),
        summaryText: _buildFormattedSummary(),
      ),
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
        maxHeight: MediaQuery.sizeOf(context).height * 0.94,
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
                  color: MetaColors.emerald.withValues(alpha: 0.12),
                  boxShadow: [
                    BoxShadow(
                      color: MetaColors.emerald.withValues(alpha: 0.35),
                      blurRadius: 28,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    '🏆',
                    style: TextStyle(fontSize: 48),
                  ),
                ),
              )
                  .animate()
                  .scale(
                    begin: const Offset(0.3, 0.3),
                    end: const Offset(1, 1),
                    duration: 650.ms,
                    curve: Curves.elasticOut,
                  )
                  .fadeIn(duration: 350.ms),
            ),
            const SizedBox(height: 14),

            // Título triunfal
            Center(
              child: Text(
                'TREINO CONCLUÍDO!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                  color: textPrimary,
                ),
              ),
            )
                .animate()
                .fadeIn(delay: 200.ms, duration: 400.ms)
                .slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic),
            const SizedBox(height: 4),

            Center(
              child: Text(
                widget.workoutTitle,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: MetaColors.emerald,
                ),
                textAlign: TextAlign.center,
              ),
            )
                .animate()
                .fadeIn(delay: 250.ms, duration: 400.ms)
                .slideY(begin: 0.2, end: 0),
            const SizedBox(height: 18),

            // 3 Cards de Métricas em Cascata
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: border),
                    ),
                    child: Column(
                       children: [
                        const Icon(
                          Icons.timer_rounded,
                          size: 20,
                          color: MetaColors.emerald,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${widget.durationMin}',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: textPrimary,
                          ),
                        ),
                        Text(
                          'MINUTOS',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 300.ms, duration: 380.ms)
                      .slideY(begin: 0.2, end: 0),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: border),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.fitness_center_rounded,
                          size: 20,
                          color: Colors.amber,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.totalVolumeKg >= 1000
                              ? '${(widget.totalVolumeKg / 1000).toStringAsFixed(1)}t'
                              : widget.totalVolumeKg.toStringAsFixed(0),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: textPrimary,
                          ),
                        ),
                        Text(
                          'VOLUME KG',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 360.ms, duration: 380.ms)
                      .slideY(begin: 0.2, end: 0),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: border),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 20,
                          color: Color(0xFF60A5FA),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${widget.completedSets}/${widget.totalSets}',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: textPrimary,
                          ),
                        ),
                        Text(
                          'SÉRIES',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 420.ms, duration: 380.ms)
                      .slideY(begin: 0.2, end: 0),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // SELETOR DE ESFORÇO RPE (1 A 10)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _getRpeColor(_selectedRpe).withValues(alpha: 0.35),
                  width: 1.2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.speed_rounded,
                            size: 18,
                            color: MetaColors.emerald,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'PERCEPÇÃO DE ESFORÇO (RPE)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.6,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _getRpeColor(_selectedRpe).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$_selectedRpe / 10',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: _getRpeColor(_selectedRpe),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _getRpeLabel(_selectedRpe),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: _getRpeColor(_selectedRpe),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Seletor de botões táteis de 1 a 10
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(10, (idx) {
                      final val = idx + 1;
                      final isSelected = val == _selectedRpe;
                      return InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _selectedRpe = val;
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: (MediaQuery.sizeOf(context).width - 80) / 10,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? _getRpeColor(val)
                                : bg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected
                                  ? _getRpeColor(val)
                                  : border,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '$val',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: isSelected
                                    ? Colors.black
                                    : textSecondary,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            )
                .animate()
                .fadeIn(delay: 480.ms, duration: 380.ms)
                .slideY(begin: 0.15, end: 0),
            const SizedBox(height: 12),

            // Card de Ofensiva (Streak) se disponível
            if (widget.currentStreak != null && widget.currentStreak! > 0) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.amber.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    const Text('🔥', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${widget.currentStreak}º Dia Consecutivo de Treino!',
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.amber,
                        ),
                      ),
                    ),
                  ],
                ),
              )
                  .animate()
                  .fadeIn(delay: 520.ms, duration: 380.ms)
                  .slideY(begin: 0.15, end: 0),
              const SizedBox(height: 10),
            ],

            // Card de Recordes Pessoais (PRs) se houve quebra de carga
            if (widget.newPrCount > 0) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                            '${widget.newPrCount} Novo(s) Recorde(s) de Carga Batido(s)!',
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
                  .fadeIn(duration: 380.ms, delay: 560.ms)
                  .slideY(begin: 0.15, end: 0, curve: Curves.easeOutCubic)
                  .shimmer(delay: 900.ms, duration: 1200.ms, color: Colors.white24),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 14),

            // NOVO: Botão Card Comemorativo de Triunfo (Story / Redes Sociais)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  onTap: () => _showShareCardDialog(context),
                  borderRadius: BorderRadius.circular(16),
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF6366F1),
                          Color(0xFF10B981),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.32),
                          blurRadius: 18,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          size: 19,
                          color: Colors.white,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Ver Card de Conquista (Stories / Redes)',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
                .animate()
                .fadeIn(delay: 580.ms, duration: 350.ms)
                .slideY(begin: 0.1, end: 0),

            // Botão Compartilhar WhatsApp com Gradiente Oficial
            if (widget.trainerPhone != null && widget.trainerPhone!.trim().isNotEmpty) ...[
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
                            'Compartilhar no WhatsApp de ${widget.trainerName}',
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
                  .fadeIn(delay: 620.ms, duration: 350.ms)
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
                _saveRpeToPreferences();
                Navigator.pop(context);
                widget.onDismiss();
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

/// Diálogo com Card Comemorativo Visual de Triunfo pronto para Stories e Redes Sociais (9:16).
class WorkoutShareCardDialog extends StatefulWidget {
  final String workoutTitle;
  final String trainerName;
  final String? studentName;
  final String? trainerCref;
  final String? trainerUsername;
  final int durationMin;
  final double totalVolumeKg;
  final int completedSets;
  final int totalSets;
  final int? currentStreak;
  final int newPrCount;
  final int rpe;
  final String rpeLabel;
  final Color rpeColor;
  final String summaryText;

  const WorkoutShareCardDialog({
    super.key,
    required this.workoutTitle,
    required this.trainerName,
    this.studentName,
    this.trainerCref,
    this.trainerUsername,
    required this.durationMin,
    required this.totalVolumeKg,
    required this.completedSets,
    required this.totalSets,
    this.currentStreak,
    required this.newPrCount,
    required this.rpe,
    required this.rpeLabel,
    required this.rpeColor,
    required this.summaryText,
  });

  @override
  State<WorkoutShareCardDialog> createState() => _WorkoutShareCardDialogState();
}

class _WorkoutShareCardDialogState extends State<WorkoutShareCardDialog> {
  bool _isStoryMode = true;
  bool _isImmersivePrintMode = false;

  String get _trainerSlug {
    if (widget.trainerUsername != null &&
        widget.trainerUsername!.trim().isNotEmpty) {
      return widget.trainerUsername!.trim();
    }
    return widget.trainerName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
  }

  String get _landingUrl => 'https://shaipados.com/#/p/$_trainerSlug';

  void _copySummary(BuildContext context) {
    Clipboard.setData(ClipboardData(text: widget.summaryText));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Text('Resumo do treino copiado para colar no Stories ou WhatsApp!'),
          ],
        ),
        backgroundColor: MetaColors.emerald,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _copyLandingLink(BuildContext context) {
    Clipboard.setData(ClipboardData(text: _landingUrl));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.link_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Link da vitrine copiado: $_landingUrl\nCole no Sticker de Link do Instagram!',
                style: const TextStyle(fontSize: 12.5),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E88E5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _shareViaWhatsApp(BuildContext context) {
    final viralMsg = '${widget.summaryText}\n\n'
        '🔥 Treine você também com meu personal: $_landingUrl';
    final msg = Uri.encodeComponent(viralMsg);
    launchUrl(
      Uri.parse('https://api.whatsapp.com/send?text=$msg'),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.sizeOf(context).height;
    final screenW = MediaQuery.sizeOf(context).width;

    // Cálculo proporcional 9:16
    final maxStoryHeight = (screenH * 0.82).clamp(520.0, 720.0);
    final storyWidth = (maxStoryHeight * (9.0 / 16.0)).clamp(300.0, 400.0);
    final cardWidth = _isStoryMode
        ? storyWidth
        : (screenW > 440 ? 380.0 : (screenW - 32).clamp(300.0, 380.0));

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Banner de Print Imersivo (se ativo)
              if (_isImmersivePrintMode)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () => setState(() => _isImmersivePrintMode = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.touch_app_rounded,
                              size: 14, color: Colors.amber),
                          SizedBox(width: 6),
                          Text(
                            'Modo Print Ativo • Toque aqui para sair',
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
                ),

              // Card Visual Estilo Instagram Stories 9:16
              Container(
                width: cardWidth,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF070B09),
                      Color(0xFF0F1712),
                      Color(0xFF080D0A),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: MetaColors.emerald.withValues(alpha: 0.45),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: MetaColors.emerald.withValues(alpha: 0.28),
                      blurRadius: 40,
                      spreadRadius: 2,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Stack(
                    children: [
                      // Glow decorativo sutil no topo
                      Positioned(
                        top: -60,
                        right: -40,
                        child: Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: MetaColors.emerald.withValues(alpha: 0.12),
                          ),
                        ),
                      ),

                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: _isStoryMode ? 24 : 20,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Header Branding & Data
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: MetaColors.emerald,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: MetaColors.emerald,
                                            blurRadius: 6,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Text(
                                      'MR. COACH AI',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.9,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: MetaColors.emerald
                                        .withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: MetaColors.emerald
                                          .withValues(alpha: 0.35),
                                    ),
                                  ),
                                  child: const Text(
                                    'PERFORMANCE RECAP',
                                    style: TextStyle(
                                      color: MetaColors.emerald,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: _isStoryMode ? 18 : 14),

                            // Troféu Central
                            Container(
                              width: _isStoryMode ? 74 : 64,
                              height: _isStoryMode ? 74 : 64,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color:
                                    MetaColors.emerald.withValues(alpha: 0.14),
                                boxShadow: [
                                  BoxShadow(
                                    color: MetaColors.emerald
                                        .withValues(alpha: 0.4),
                                    blurRadius: 26,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  '🏆',
                                  style: TextStyle(
                                      fontSize: _isStoryMode ? 38 : 32),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Título do Treino
                            Text(
                              widget.workoutTitle.toUpperCase(),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: _isStoryMode ? 18 : 16.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.4,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),

                            // Identificação do Atleta e Personal
                            Text(
                              widget.studentName != null &&
                                      widget.studentName!.isNotEmpty
                                  ? 'Atleta: ${widget.studentName}'
                                  : 'Treino de Alto Rendimento',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 14),

                            // 3 Pilares de Performance
                            Row(
                              children: [
                                _buildMetricBox(
                                  icon: Icons.timer_rounded,
                                  color: MetaColors.emerald,
                                  value: '${widget.durationMin}',
                                  unit: 'MINUTOS',
                                ),
                                const SizedBox(width: 6),
                                _buildMetricBox(
                                  icon: Icons.fitness_center_rounded,
                                  color: Colors.amber,
                                  value: widget.totalVolumeKg >= 1000
                                      ? '${(widget.totalVolumeKg / 1000).toStringAsFixed(1)}t'
                                      : widget.totalVolumeKg.toStringAsFixed(0),
                                  unit: 'VOLUME KG',
                                ),
                                const SizedBox(width: 6),
                                _buildMetricBox(
                                  icon: Icons.bolt_rounded,
                                  color: widget.rpeColor,
                                  value: '${widget.rpe}/10',
                                  unit: 'RPE ESFORÇO',
                                ),
                              ],
                            ),

                            // Card Recorde Pessoal (PR)
                            if (widget.newPrCount > 0) ...[
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 7),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.amber.withValues(alpha: 0.22),
                                      Colors.orange.withValues(alpha: 0.15),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: Colors.amber.withValues(alpha: 0.5)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text('🏆',
                                        style: TextStyle(fontSize: 14)),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        '${widget.newPrCount} NOVO(S) RECORDE(S) DE CARGA (PR)!',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.amber,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // Card Fogo de Ofensiva (Streak)
                            if (widget.currentStreak != null &&
                                widget.currentStreak! > 0) ...[
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 7),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.deepOrangeAccent
                                          .withValues(alpha: 0.22),
                                      Colors.redAccent.withValues(alpha: 0.15),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.deepOrangeAccent
                                        .withValues(alpha: 0.5),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text('🔥',
                                        style: TextStyle(fontSize: 14)),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        '${widget.currentStreak}º DIA SEGUIDO DE DISCIPLINA!',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.deepOrangeAccent,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            SizedBox(height: _isStoryMode ? 14 : 10),
                            Divider(
                                color: Colors.white.withValues(alpha: 0.12),
                                height: 1),
                            SizedBox(height: _isStoryMode ? 12 : 10),

                            // Rodapé com QR Code e Vitrine Viral
                            Row(
                              children: [
                                // QR Code Box com Moldura One UI 7
                                Container(
                                  width: 58,
                                  height: 58,
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF131B2E),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: MetaColors.emerald
                                          .withValues(alpha: 0.4),
                                    ),
                                  ),
                                  child: Image.network(
                                    'https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=${Uri.encodeComponent(_landingUrl)}&bgcolor=131B2E&color=25A875',
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) => const Icon(
                                      Icons.qr_code_2_rounded,
                                      color: MetaColors.emerald,
                                      size: 38,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              'Prof. ${widget.trainerName}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          const Icon(Icons.verified_rounded,
                                              color: MetaColors.emerald,
                                              size: 13),
                                        ],
                                      ),
                                      if (widget.trainerCref != null &&
                                          widget.trainerCref!.isNotEmpty)
                                        Text(
                                          'CREF ${widget.trainerCref}',
                                          style: const TextStyle(
                                            color: Color(0xFF94A3B8),
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Escaneie o QR Code para vagas',
                                        style: TextStyle(
                                          color: MetaColors.emerald
                                              .withValues(alpha: 0.95),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        'shaipados.com/#/p/$_trainerSlug',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.4),
                                          fontSize: 9,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (!_isImmersivePrintMode) ...[
                const SizedBox(height: 14),

                // Seletor de Modo 9:16 vs Compacto & Dica de Print
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () =>
                          setState(() => _isStoryMode = !_isStoryMode),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: _isStoryMode
                                ? MetaColors.emerald
                                : Colors.white24,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isStoryMode
                                  ? Icons.aspect_ratio_rounded
                                  : Icons.crop_portrait_rounded,
                              size: 13,
                              color: _isStoryMode
                                  ? MetaColors.emerald
                                  : Colors.white70,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              _isStoryMode
                                  ? 'Stories 9:16'
                                  : 'Modo Compacto',
                              style: TextStyle(
                                color: _isStoryMode
                                    ? Colors.white
                                    : Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () =>
                          setState(() => _isImmersivePrintMode = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.amber.withValues(alpha: 0.4),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.camera_alt_outlined,
                                size: 13, color: Colors.amber),
                            SizedBox(width: 5),
                            Text(
                              'Modo Print',
                              style: TextStyle(
                                color: Colors.amber,
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
                const SizedBox(height: 14),

                // Botões de Ação
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E88E5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => _copyLandingLink(context),
                      icon: const Icon(Icons.link_rounded, size: 16),
                      label: const Text('Link Vitrine',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 12.5)),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => _shareViaWhatsApp(context),
                      icon: const Icon(Icons.share_rounded, size: 16),
                      label: const Text('WhatsApp',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 12.5)),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MetaColors.surfaceHighlight,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => _copySummary(context),
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Legenda',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 12.5)),
                    ),
                    IconButton(
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white12,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Fechar',
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricBox({
    required IconData icon,
    required Color color,
    required String value,
    required String unit,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF131B2E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 17, color: color),
            const SizedBox(height: 3),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              unit,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 8.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
