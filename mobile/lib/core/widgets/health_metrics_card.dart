import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/health_connect_service.dart';
import 'meta_components.dart';

/// Card interativo de telemetria de saúde integrada (Apple Health & Health Connect)
class HealthMetricsCard extends StatefulWidget {
  final String? userId;
  final VoidCallback? onMetricsUpdated;

  const HealthMetricsCard({
    super.key,
    this.userId,
    this.onMetricsUpdated,
  });

  @override
  State<HealthMetricsCard> createState() => _HealthMetricsCardState();
}

class _HealthMetricsCardState extends State<HealthMetricsCard> {
  DailyHealthSnapshot? _snapshot;
  bool _isLoading = true;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await HealthConnectService.getTodaySnapshot(userId: widget.userId);
    if (mounted) {
      setState(() {
        _snapshot = data;
        _isLoading = false;
      });
    }
  }

  Future<void> _sync() async {
    HapticFeedback.selectionClick();
    setState(() => _isSyncing = true);
    final updated = await HealthConnectService.triggerSync(userId: widget.userId);
    if (mounted) {
      setState(() {
        _snapshot = updated;
        _isSyncing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.sync_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                'Sincronizado com ${updated.platform.label}!',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          backgroundColor: MetaColors.emerald,
          behavior: SnackBarBehavior.floating,
        ),
      );
      widget.onMetricsUpdated?.call();
    }
  }

  Future<void> _addWater() async {
    HapticFeedback.lightImpact();
    final updated = await HealthConnectService.logWater(amountMl: 250, userId: widget.userId);
    if (mounted) {
      setState(() => _snapshot = updated);
      widget.onMetricsUpdated?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final snap = _snapshot ?? HealthConnectService.defaultSnapshot;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final border = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header com Badge da Plataforma
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF43F5E).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.favorite_rounded,
                  color: Color(0xFFF43F5E),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Saúde & Telemetria Vital',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Sincronização em tempo real com seu relógio/celular',
                      style: TextStyle(
                        color: subtextColor,
                        fontSize: 11.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: snap.isSynced
                      ? MetaColors.emerald.withValues(alpha: 0.15)
                      : Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: snap.isSynced
                        ? MetaColors.emerald.withValues(alpha: 0.3)
                        : Colors.amber.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: snap.isSynced ? MetaColors.emerald : Colors.amber,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      snap.platform.badgeName,
                      style: TextStyle(
                        color: snap.isSynced ? MetaColors.emerald : Colors.amber,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Grid 2x2 de Métricas
          Row(
            children: [
              // 1. Passos
              Expanded(
                child: _buildMetricTile(
                  icon: Icons.directions_walk_rounded,
                  iconColor: const Color(0xFF38BDF8),
                  title: 'Passos Diários',
                  value: '${snap.steps}',
                  sublabel: 'Meta: ${(snap.stepGoal / 1000).toStringAsFixed(0)}k',
                  progress: snap.stepProgress,
                  cardBg: cardBg,
                  border: border,
                  textColor: textColor,
                  subtextColor: subtextColor,
                ),
              ),
              const SizedBox(width: 10),
              // 2. Calorias Ativas
              Expanded(
                child: _buildMetricTile(
                  icon: Icons.local_fire_department_rounded,
                  iconColor: const Color(0xFFF97316),
                  title: 'Calorias Ativas',
                  value: '${snap.activeCaloriesKcal} kcal',
                  sublabel: 'Gasto em movimento',
                  progress: (snap.activeCaloriesKcal / 700).clamp(0.0, 1.0),
                  cardBg: cardBg,
                  border: border,
                  textColor: textColor,
                  subtextColor: subtextColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // 3. FC em Repouso
              Expanded(
                child: _buildMetricTile(
                  icon: Icons.monitor_heart_rounded,
                  iconColor: const Color(0xFFF43F5E),
                  title: 'FC em Repouso',
                  value: '${snap.restingHeartRateBpm} bpm',
                  sublabel: 'Zona Basal Ideal',
                  progress: 0.85,
                  cardBg: cardBg,
                  border: border,
                  textColor: textColor,
                  subtextColor: subtextColor,
                ),
              ),
              const SizedBox(width: 10),
              // 4. Sono & Recuperação
              Expanded(
                child: _buildMetricTile(
                  icon: Icons.bedtime_rounded,
                  iconColor: const Color(0xFF818CF8),
                  title: 'Sono & Repouso',
                  value: '${snap.sleepHours}h',
                  sublabel: '${snap.recoveryScore}% (${snap.recoveryLabel})',
                  progress: snap.recoveryScore / 100,
                  cardBg: cardBg,
                  border: border,
                  textColor: textColor,
                  subtextColor: subtextColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Barra de Hidratação
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border),
            ),
            child: Row(
              children: [
                const Icon(Icons.water_drop_rounded, size: 20, color: Color(0xFF38BDF8)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Hidratação Diária',
                            style: TextStyle(
                              color: textColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${(snap.waterMl / 1000).toStringAsFixed(1)}L / ${(snap.waterGoalMl / 1000).toStringAsFixed(1)}L',
                            style: const TextStyle(
                              color: Color(0xFF38BDF8),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: snap.waterProgress,
                          backgroundColor: border,
                          color: const Color(0xFF38BDF8),
                          minHeight: 5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  icon: const Icon(Icons.add_rounded, color: Color(0xFF38BDF8)),
                  tooltip: '+250ml',
                  onPressed: _addWater,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Ações Rápidas (Sincronizar Agora & Configurar Metas)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSyncing ? null : _sync,
                  icon: _isSyncing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync_rounded, size: 16),
                  label: Text(_isSyncing ? 'Sincronizando...' : 'Sincronizar Agora'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: MetaColors.emerald,
                    side: const BorderSide(color: MetaColors.emerald),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filledTonal(
                icon: const Icon(Icons.tune_rounded, size: 18),
                tooltip: 'Configurar Metas de Saúde',
                onPressed: () async {
                  await HealthSyncConfigSheet.show(context, snapshot: snap, userId: widget.userId);
                  _load();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required String sublabel,
    required double progress,
    required Color cardBg,
    required Color border,
    required Color textColor,
    required Color subtextColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: subtextColor,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: textColor,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            sublabel,
            style: TextStyle(
              color: subtextColor,
              fontSize: 10,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: border,
              color: iconColor,
              minHeight: 3.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Modal Sheet para configurar metas de saúde e plataforma de sincronização
class HealthSyncConfigSheet extends StatefulWidget {
  final DailyHealthSnapshot snapshot;
  final String? userId;

  const HealthSyncConfigSheet({
    super.key,
    required this.snapshot,
    this.userId,
  });

  static Future<void> show(
    BuildContext context, {
    required DailyHealthSnapshot snapshot,
    String? userId,
  }) {
    HapticFeedback.selectionClick();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => HealthSyncConfigSheet(
        snapshot: snapshot,
        userId: userId,
      ),
    );
  }

  @override
  State<HealthSyncConfigSheet> createState() => _HealthSyncConfigSheetState();
}

class _HealthSyncConfigSheetState extends State<HealthSyncConfigSheet> {
  late double _stepGoal;
  late double _waterGoal;
  late HealthSyncPlatform _platform;

  @override
  void initState() {
    super.initState();
    _stepGoal = widget.snapshot.stepGoal.toDouble();
    _waterGoal = widget.snapshot.waterGoalMl.toDouble();
    _platform = widget.snapshot.platform;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.tune_rounded, color: MetaColors.emerald),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Configuração de Metas de Saúde',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Meta de Passos
            Text(
              'Meta de Passos Diários: ${_stepGoal.round()}',
              style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13),
            ),
            Slider(
              value: _stepGoal,
              min: 4000,
              max: 20000,
              divisions: 16,
              activeColor: MetaColors.emerald,
              onChanged: (v) => setState(() => _stepGoal = v),
            ),
            const SizedBox(height: 10),

            // Meta de Água
            Text(
              'Meta de Hidratação Diária: ${(_waterGoal / 1000).toStringAsFixed(1)}L',
              style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13),
            ),
            Slider(
              value: _waterGoal,
              min: 1500,
              max: 5000,
              divisions: 14,
              activeColor: const Color(0xFF38BDF8),
              onChanged: (v) => setState(() => _waterGoal = v),
            ),
            const SizedBox(height: 16),

            // Plataforma
            Text(
              'Fonte de Dados:',
              style: TextStyle(color: subtextColor, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildPlatformChoice(HealthSyncPlatform.appleHealth),
                const SizedBox(width: 8),
                _buildPlatformChoice(HealthSyncPlatform.healthConnect),
                const SizedBox(width: 8),
                _buildPlatformChoice(HealthSyncPlatform.manual),
              ],
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  HapticFeedback.selectionClick();
                  await HealthConnectService.updateGoals(
                    stepGoal: _stepGoal.round(),
                    waterGoalMl: _waterGoal.round(),
                    userId: widget.userId,
                  );
                  if (context.mounted) Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: MetaColors.emerald,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Salvar Metas', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlatformChoice(HealthSyncPlatform plat) {
    final isSelected = _platform == plat;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _platform = plat),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? MetaColors.emerald.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? MetaColors.emerald : Colors.grey.withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            plat.badgeName,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? MetaColors.emerald : Colors.grey,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
