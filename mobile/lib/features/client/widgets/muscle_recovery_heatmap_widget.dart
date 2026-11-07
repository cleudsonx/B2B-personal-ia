import 'package:flutter/material.dart';
import '../../../models/biohub_model.dart';

class MuscleRecoveryHeatmapWidget extends StatelessWidget {
  final MuscleRecoveryReportModel report;
  final VoidCallback? onRefresh;

  const MuscleRecoveryHeatmapWidget({
    super.key,
    required this.report,
    this.onRefresh,
  });

  IconData _getMuscleIcon(String muscleGroup) {
    switch (muscleGroup) {
      case 'chest':
        return Icons.accessibility_new_rounded;
      case 'back':
        return Icons.shield_rounded;
      case 'quadriceps':
        return Icons.directions_walk_rounded;
      case 'hamstrings_glutes':
        return Icons.airline_seat_legroom_extra_rounded;
      case 'shoulders':
        return Icons.fitness_center_rounded;
      case 'arms_core':
        return Icons.sports_kabaddi_rounded;
      default:
        return Icons.fitness_center_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final overallPct = report.overallRecoveryPercentage;
    final overallColor = overallPct >= 80
        ? const Color(0xFF10B981)
        : (overallPct >= 50 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444));

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1F2C) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF2E384D) : Colors.grey.shade200,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: overallColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.battery_charging_full_rounded,
                      color: overallColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Recuperação Muscular',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Cinética miofibrilar em tempo real',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: overallColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$overallPct% Total',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: overallColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            report.summary,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 16),
          // 6 Muscle groups list
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: report.muscles.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final muscle = report.muscles[index];
              final mColor = muscle.statusColor;
              final icon = _getMuscleIcon(muscle.muscleGroup);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(icon, size: 14, color: mColor),
                          const SizedBox(width: 6),
                          Text(
                            muscle.label,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          if (muscle.hoursUntilRecovered > 0)
                            Text(
                              'Faltam ${muscle.hoursUntilRecovered}h',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              ),
                            )
                          else
                            const Text(
                              'Pronto',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF10B981),
                              ),
                            ),
                          const SizedBox(width: 8),
                          Text(
                            '${muscle.recoveryPercentage}%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: mColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: muscle.recoveryPercentage / 100.0,
                      minHeight: 6,
                      backgroundColor: isDark
                          ? const Color(0xFF282E3E)
                          : Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(mColor),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
