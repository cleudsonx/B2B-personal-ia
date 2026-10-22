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
        '📲 app.sheipados.com';
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

/// Diálogo com Card Comemorativo Visual de Triunfo pronto para Stories e Redes Sociais.
class WorkoutShareCardDialog extends StatelessWidget {
  final String workoutTitle;
  final String trainerName;
  final String? studentName;
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

  void _copySummary(BuildContext context) {
    Clipboard.setData(ClipboardData(text: summaryText));
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

  void _shareViaWhatsApp(BuildContext context) {
    final msg = Uri.encodeComponent(summaryText);
    launchUrl(
      Uri.parse('https://api.whatsapp.com/send?text=$msg'),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.sizeOf(context).width;
    final cardWidth = screenW > 440 ? 380.0 : (screenW - 32).clamp(300.0, 380.0);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Card Visual Estilo Instagram Story / Whoop
              Container(
                width: cardWidth,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
                decoration: BoxDecoration(
                  color: const Color(0xFF090D16), // Obsidian fosco absoluto
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: MetaColors.emerald.withValues(alpha: 0.45),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: MetaColors.emerald.withValues(alpha: 0.25),
                      blurRadius: 36,
                      spreadRadius: 2,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header Branding
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
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: MetaColors.emerald.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: MetaColors.emerald.withValues(alpha: 0.35),
                            ),
                          ),
                          child: const Text(
                            'SESSÃO CONCLUÍDA',
                            style: TextStyle(
                              color: MetaColors.emerald,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Troféu Central
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: MetaColors.emerald.withValues(alpha: 0.14),
                        boxShadow: [
                          BoxShadow(
                            color: MetaColors.emerald.withValues(alpha: 0.4),
                            blurRadius: 24,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          '🏆',
                          style: TextStyle(fontSize: 40),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Título do Treino
                    Text(
                      workoutTitle.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),

                    if (studentName != null && studentName!.isNotEmpty)
                      Text(
                        'Atleta: $studentName',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                    const SizedBox(height: 20),

                    // 3 Pilares de Performance
                    Row(
                      children: [
                        _buildMetricBox(
                          icon: Icons.timer_rounded,
                          color: MetaColors.emerald,
                          value: '$durationMin',
                          unit: 'MIN',
                        ),
                        const SizedBox(width: 8),
                        _buildMetricBox(
                          icon: Icons.fitness_center_rounded,
                          color: Colors.amber,
                          value: totalVolumeKg >= 1000
                              ? '${(totalVolumeKg / 1000).toStringAsFixed(1)}t'
                              : totalVolumeKg.toStringAsFixed(0),
                          unit: 'VOLUME KG',
                        ),
                        const SizedBox(width: 8),
                        _buildMetricBox(
                          icon: Icons.check_circle_rounded,
                          color: const Color(0xFF60A5FA),
                          value: '$completedSets/$totalSets',
                          unit: 'SÉRIES',
                        ),
                      ],
                    ),

                    if (newPrCount > 0) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('🏆', style: TextStyle(fontSize: 16)),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                '$newPrCount NOVO(S) RECORDE(S) DE CARGA (PR)!',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.amber,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    if (currentStreak != null && currentStreak! > 0) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.deepOrangeAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.deepOrangeAccent.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('🔥', style: TextStyle(fontSize: 16)),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                '$currentStreakº DIA SEGUIDO DE TREINO!',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.deepOrangeAccent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 18),
                    Divider(color: Colors.white.withValues(alpha: 0.12), height: 1),
                    const SizedBox(height: 14),

                    // Rodapé do Card
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Treinador Oficial',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Prof. $trainerName',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'app.sheipados.com',
                              style: TextStyle(
                                color: MetaColors.emerald.withValues(alpha: 0.9),
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'Personal Training IA',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.45),
                                fontSize: 9.5,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Dica amigável de captura de tela
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.camera_alt_outlined, size: 14, color: Colors.white70),
                    SizedBox(width: 6),
                    Text(
                      'Tire um print para postar no Instagram Stories!',
                      style: TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Botões de Ação
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MetaColors.surfaceHighlight,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => _copySummary(context),
                    icon: const Icon(Icons.copy_rounded, size: 17),
                    label: const Text('Copiar Texto', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => _shareViaWhatsApp(context),
                    icon: const Icon(Icons.share_rounded, size: 17),
                    label: const Text('WhatsApp', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF131B2E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              unit,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 9,
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
