import 'package:flutter/material.dart';
import '../../services/exercise_media_service.dart';
import 'biomechanical_analysis_sheet.dart';
import 'meta_components.dart';

/// Modal interativo com demonstração in-app e orientações biomecânicas colapsáveis do exercício
class ExerciseMediaSheet extends StatefulWidget {
  final String exerciseName;
  final ExerciseMedia? media;

  const ExerciseMediaSheet({
    super.key,
    required this.exerciseName,
    this.media,
  });

  static Future<void> show(
    BuildContext context, {
    required String exerciseName,
    ExerciseMedia? preloadedMedia,
  }) async {
    final media = preloadedMedia ?? await ExerciseMediaService.getMediaFor(exerciseName);

    if (!context.mounted) return;

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ExerciseMediaSheet(
        exerciseName: exerciseName,
        media: media,
      ),
    );
  }

  @override
  State<ExerciseMediaSheet> createState() => _ExerciseMediaSheetState();
}

class _ExerciseMediaSheetState extends State<ExerciseMediaSheet> {
  // Controle de expansão das dicas biomecânicas (recolhido por padrão para otimizar espaço)
  bool _isCuesExpanded = false;

  void _openInAppFullScreenViewer(BuildContext context, String mediaUrl, String title) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (dialogCtx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Stack(
            alignment: Alignment.center,
            children: [
              InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.0,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    mediaUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: MetaColors.emerald,
                        ),
                      );
                    },
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.65),
                  ),
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                  onPressed: () => Navigator.pop(dialogCtx),
                ),
              ),
              Positioned(
                bottom: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = MetaColors.isDark(context);
    final bg = isDark ? const Color(0xFF090D16) : Colors.white;
    final cardBg = isDark ? MetaColors.surface : MetaColors.lightSurface;
    final border = isDark ? MetaColors.border : MetaColors.lightBorder;
    final textColor = isDark ? MetaColors.textPrimary : MetaColors.lightTextPrimary;
    final subtextColor = isDark ? MetaColors.textSecondary : MetaColors.lightTextSecondary;

    final resolvedTitle = widget.media?.name ?? widget.exerciseName;
    final resolvedMuscle = widget.media?.muscleGroup ?? 'Músculo Principal';
    final resolvedEquip = widget.media?.equipment ?? 'Equipamento de Academia';
    final inAppMediaUrl = widget.media?.inAppMediaUrl;
    final hasInAppMedia = inAppMediaUrl != null && inAppMediaUrl.isNotEmpty;

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.90,
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
        child: SingleChildScrollView(
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
              const SizedBox(height: 16),

              // Cabeçalho do Exercício
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: MetaColors.emerald.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: MetaColors.emerald.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Icon(
                      Icons.fitness_center_rounded,
                      color: MetaColors.emerald,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          resolvedTitle,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: MetaColors.emerald.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: MetaColors.emerald.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                resolvedMuscle,
                                style: const TextStyle(
                                  color: MetaColors.emerald,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: MetaColors.surfaceHighlight,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                resolvedEquip,
                                style: TextStyle(
                                  color: subtextColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            if (widget.media?.isOfflineCached == true)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(0xFF38BDF8).withValues(alpha: 0.4),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.offline_pin_rounded, size: 12, color: Color(0xFF38BDF8)),
                                    SizedBox(width: 4),
                                    Text(
                                      'Offline',
                                      style: TextStyle(
                                        color: Color(0xFF38BDF8),
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
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
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: subtextColor),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Área de Demonstração In-App (GIF Animado em Loop ou Banner de Processamento)
              if (hasInAppMedia) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    width: double.infinity,
                    height: 220,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0C1322) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: MetaColors.emerald.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Image.network(
                            inAppMediaUrl,
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return const Center(
                                child: SizedBox(
                                  width: 32,
                                  height: 32,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: MetaColors.emerald,
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return _buildFallbackCard(isDark, textColor, subtextColor);
                            },
                          ),
                        ),

                        // Badge indicando execução contínua in-app
                        Positioned(
                          top: 10,
                          left: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: MetaColors.emerald.withValues(alpha: 0.4),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.repeat_rounded, size: 13, color: MetaColors.emerald),
                                SizedBox(width: 4),
                                Text(
                                  'Demonstração In-App',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Botão para zoom e tela cheia in-app (sem redirecionar externamente)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.fullscreen_rounded, color: Colors.white, size: 20),
                              tooltip: 'Ver em Tela Cheia In-App',
                              onPressed: () => _openInAppFullScreenViewer(context, inAppMediaUrl, resolvedTitle),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                _buildFallbackCard(isDark, textColor, subtextColor),
              ],

              // Dicas Biomecânicas e Postura (Card Colapsável sob demanda)
              if (widget.media?.executionCues != null && widget.media!.executionCues!.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _isCuesExpanded
                          ? MetaColors.emerald.withValues(alpha: 0.45)
                          : border,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _isCuesExpanded = !_isCuesExpanded;
                        });
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.lightbulb_outline_rounded,
                                    size: 16,
                                    color: Colors.amber,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'COMO EXECUTAR (POSTURA & BIOMECÂNICA)',
                                        style: TextStyle(
                                          color: subtextColor,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                      if (!_isCuesExpanded) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          'Toque para abrir orientações posturais detalhadas',
                                          style: TextStyle(
                                            color: textColor.withValues(alpha: 0.7),
                                            fontSize: 11.5,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: MetaColors.surfaceHighlight,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    _isCuesExpanded
                                        ? Icons.keyboard_arrow_up_rounded
                                        : Icons.keyboard_arrow_down_rounded,
                                    size: 18,
                                    color: subtextColor,
                                  ),
                                ),
                              ],
                            ),
                            if (_isCuesExpanded) ...[
                              const SizedBox(height: 12),
                              Divider(color: border, height: 1),
                              const SizedBox(height: 12),
                              Text(
                                widget.media!.executionCues!,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 13,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 18),

              // Ação Secundária: Ver Análise 3D
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    BiomechanicalAnalysisSheet.show(
                      context,
                      exerciseName: resolvedTitle,
                      primaryMuscle: resolvedMuscle,
                    );
                  },
                  icon: const Icon(Icons.view_in_ar_rounded, size: 18),
                  label: const Text('Ver Análise 3D com Ângulos Articulares e EMG'),
                  style: TextButton.styleFrom(
                    foregroundColor: MetaColors.emerald,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackCard(bool isDark, Color textColor, Color subtextColor) {
    final title = widget.media?.name ?? widget.exerciseName;
    final muscle = widget.media?.muscleGroup ?? 'Músculo Alvo';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0C1322) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF38BDF8).withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.offline_bolt_rounded,
              size: 26,
              color: Color(0xFF38BDF8),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Modo Offline no Salão',
            style: TextStyle(
              color: textColor,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Instruções biomecânicas salvas no seu aparelho para você treinar mesmo sem internet na academia.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: subtextColor,
              fontSize: 11.5,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: MetaColors.emerald,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            icon: const Icon(Icons.view_in_ar_rounded, size: 16),
            label: const Text(
              'Abrir Loop Biomecânico & Ângulos',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              BiomechanicalAnalysisSheet.show(
                context,
                exerciseName: title,
                primaryMuscle: muscle,
              );
            },
          ),
        ],
      ),
    );
  }
}
