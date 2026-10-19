import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/exercise_media_service.dart';
import 'biomechanical_analysis_sheet.dart';
import 'meta_components.dart';

/// Modal interativo com demonstração em vídeo e orientações biomecânicas do exercício
class ExerciseMediaSheet extends StatelessWidget {
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

  Future<void> _openVideo(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('[ExerciseMediaSheet] Erro ao abrir vídeo: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = MetaColors.isDark(context);
    final bg = isDark ? const Color(0xFF090D16) : Colors.white;
    final cardBg = isDark ? MetaColors.surface : MetaColors.lightSurface;
    final border = isDark ? MetaColors.border : MetaColors.lightBorder;
    final textColor = isDark ? MetaColors.textPrimary : MetaColors.lightTextPrimary;
    final subtextColor = isDark ? MetaColors.textSecondary : MetaColors.lightTextSecondary;

    final resolvedTitle = media?.name ?? exerciseName;
    final resolvedMuscle = media?.muscleGroup ?? 'Músculo Principal';
    final resolvedEquip = media?.equipment ?? 'Equipamento de Academia';
    final hasVideo = media != null && media!.mediaUrl.isNotEmpty;

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
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

              // Cabeçalho
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
                      Icons.play_circle_filled_rounded,
                      color: MetaColors.emerald,
                      size: 24,
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
              const SizedBox(height: 20),

              // Área do Vídeo / Player
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF131B2E), const Color(0xFF0F172A)]
                        : [const Color(0xFFF1F5F9), const Color(0xFFE2E8F0)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: MetaColors.emerald.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: MetaColors.emerald,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: MetaColors.emerald.withValues(alpha: 0.4),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 36,
                        ),
                        onPressed: hasVideo ? () => _openVideo(media!.mediaUrl) : null,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      hasVideo
                          ? 'Vídeo de Demonstração em Alta Definição'
                          : 'Vídeo em processo de catalogação',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasVideo
                          ? 'Toque no play para assistir à execução biomecânica oficial.'
                          : 'A demonstração em vídeo para este movimento estará disponível em breve.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: subtextColor,
                        fontSize: 11.5,
                      ),
                    ),
                    if (hasVideo) ...[
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: () => _openVideo(media!.mediaUrl),
                        icon: const Icon(Icons.open_in_new_rounded, size: 16),
                        label: const Text('Assistir no Player Externo'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: MetaColors.emerald,
                          side: BorderSide(color: MetaColors.emerald.withValues(alpha: 0.5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Orientações da IA de Biomecânica
              if (media?.executionCues != null && media!.executionCues!.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text(
                  'COMO EXECUTAR (DICAS BIOMECÂNICAS)',
                  style: TextStyle(
                    color: subtextColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.lightbulb_outline_rounded, size: 20, color: Colors.amber),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          media!.executionCues!,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 12.5,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Ação secundária: Ver Análise 3D
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
}

