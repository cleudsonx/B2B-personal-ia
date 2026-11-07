import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/widgets/meta_components.dart';
import '../../../../models/operational_cockpit_model.dart';

/// Card executivo do Cockpit Operacional 24h & Live Pulse do Treinador.
///
/// Apresenta séries concluídas nas últimas 24h, alertas articulares em tempo real
/// e taxa de presença semanal da carteira com padrão visual One UI 7 / Meta Glass.
class TrainerOperationalCockpitCard extends StatelessWidget {
  final TrainerOperationalCockpitData data;
  final VoidCallback? onRefresh;
  final ValueChanged<OperationalPainAlertItem>? onAlertTap;
  final VoidCallback? onViewAllAlerts;

  const TrainerOperationalCockpitCard({
    super.key,
    required this.data,
    this.onRefresh,
    this.onAlertTap,
    this.onViewAllAlerts,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = MetaColors.isDark(context);
    final hasPainAlerts = data.pendingPainAlertsCount > 0;
    final topAlert =
        data.recentPainAlerts.isNotEmpty ? data.recentPainAlerts.first : null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: MetaColors.card(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: hasPainAlerts
              ? const Color(0xFFF59E0B).withValues(alpha: 0.35)
              : MetaColors.cardBorder(context),
          width: hasPainAlerts ? 1.2 : 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Cabeçalho Executivo do Cockpit
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            MetaColors.emerald.withValues(alpha: 0.2),
                            const Color(0xFF6366F1).withValues(alpha: 0.2),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: MetaColors.emerald.withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.bolt_rounded,
                        color: MetaColors.emerald,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cockpit Operacional',
                          style: TextStyle(
                            color: MetaColors.text(context),
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          'Últimas 24h · Telemetria em Tempo Real',
                          style: TextStyle(
                            color: MetaColors.subtext(context),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                // Indicador Live Pulse
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: MetaColors.emerald.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: MetaColors.emerald.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: MetaColors.emerald,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Text(
                        'LIVE',
                        style: TextStyle(
                          color: MetaColors.emerald,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Divisor sutil
          Divider(
            height: 1,
            color: MetaColors.cardBorder(context).withValues(alpha: 0.5),
          ),

          // 2. Três Pilares de Métricas em Grade Fluida
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                // Pilar 1: Séries 24h
                Expanded(
                  child: _buildMetricTile(
                    context: context,
                    icon: Icons.fitness_center_rounded,
                    value: '${data.estimatedSets24h}',
                    label: 'Séries',
                    subtext: '${data.sessionsCompleted24h} treinos',
                    accentColor: MetaColors.emerald,
                  ),
                ),
                const SizedBox(width: 8),

                // Pilar 2: Alertas Articulares
                Expanded(
                  child: _buildMetricTile(
                    context: context,
                    icon: Icons.health_and_safety_rounded,
                    value: '${data.pendingPainAlertsCount}',
                    label: 'Alertas Articulares',
                    subtext: hasPainAlerts ? 'Requer atenção' : '100% OK',
                    accentColor: hasPainAlerts
                        ? const Color(0xFFF59E0B)
                        : (isDark ? Colors.grey[400]! : Colors.grey[600]!),
                    isAlert: hasPainAlerts,
                    onTap: hasPainAlerts ? onViewAllAlerts : null,
                  ),
                ),
                const SizedBox(width: 8),

                // Pilar 3: Retenção Semanal
                Expanded(
                  child: _buildMetricTile(
                    context: context,
                    icon: Icons.shield_outlined,
                    value: '${data.retentionRate}%',
                    label: 'Presença',
                    subtext:
                        '${data.activeStudentsThisWeek}/${data.totalStudents} ativos',
                    accentColor: const Color(0xFF6366F1),
                  ),
                ),
              ],
            ),
          ),

          // 3. Faixa de Destaque de Alerta Biomecânico Pendente (se houver)
          if (hasPainAlerts && topAlert != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onAlertTap?.call(topAlert);
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFFF59E0B).withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.warning_amber_rounded,
                          color: Color(0xFFF59E0B),
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${topAlert.studentName} · ${topAlert.painLocation ?? "Desconforto"}',
                              style: const TextStyle(
                                color: Color(0xFFF59E0B),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${topAlert.originalExercise} ➔ ${topAlert.adaptedExercise}',
                              style: TextStyle(
                                color: MetaColors.subtext(context),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFFF59E0B).withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Ver Adaptação',
                              style: TextStyle(
                                color: Color(0xFFD97706),
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(width: 2),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 14,
                              color: Color(0xFFD97706),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required BuildContext context,
    required IconData icon,
    required String value,
    required String label,
    required String subtext,
    required Color accentColor,
    bool isAlert = false,
    VoidCallback? onTap,
  }) {
    final tile = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: isAlert
            ? const Color(0xFFF59E0B).withValues(alpha: 0.08)
            : MetaColors.highlight(context).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAlert
              ? const Color(0xFFF59E0B).withValues(alpha: 0.3)
              : MetaColors.cardBorder(context).withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: accentColor),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: MetaColors.subtext(context),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: isAlert ? const Color(0xFFF59E0B) : accentColor,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtext,
            style: TextStyle(
              color: MetaColors.subtext(context),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(16),
        child: tile,
      );
    }
    return tile;
  }
}
