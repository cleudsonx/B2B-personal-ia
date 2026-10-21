import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/widgets/meta_components.dart';
import '../services/admin_data_service.dart';

/// Painel de Retenção & Visão 360° do Aluno (Mission Control)
/// Barômetro de Churn, Engajamento de Check-in Semanal e Monitoramento Ativo.
class AdminRetentionScreen extends StatefulWidget {
  const AdminRetentionScreen({super.key});

  @override
  State<AdminRetentionScreen> createState() => _AdminRetentionScreenState();
}

class _AdminRetentionScreenState extends State<AdminRetentionScreen> {
  bool _isLoading = true;
  int _selectedSegment = 0; // 0: Alunos 360° (B2C), 1: Treinadores B2B (CAC Payback & Cohorts)
  AdminRetentionOverview _overview = AdminRetentionOverview.empty();
  AdminTrainerRetentionCohortsOverview? _trainerOverview;
  String _searchQuery = '';
  StudentChurnRisk? _selectedRiskFilter;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final data = await AdminDataService.getRetentionOverview();
    final trainerData = await AdminDataService().getTrainerRetentionCohortsOverview();
    if (!mounted) return;
    setState(() {
      _overview = data;
      _trainerOverview = trainerData;
      _isLoading = false;
    });
  }

  void _showStudentDetailsModal(AdminStudentRetentionItem student) {
    HapticFeedback.lightImpact();
    final isDark = MetaColors.isDark(context);
    final textSecondary = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: const Color(0xFF1F2937)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: _riskColor(student.churnRisk).withValues(alpha: 0.2),
                      child: Text(
                        student.studentName.isNotEmpty ? student.studentName[0].toUpperCase() : 'A',
                        style: TextStyle(
                          color: _riskColor(student.churnRisk),
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            student.studentName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Personal: ${student.trainerName}',
                            style: TextStyle(color: textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    _buildRiskPill(student.churnRisk, student.churnScore),
                  ],
                ),
              ),
              const Divider(color: Color(0xFF1F2937), height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    // Diagnóstico de Churn
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _riskColor(student.churnRisk).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _riskColor(student.churnRisk).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            student.churnRisk == StudentChurnRisk.critical
                                ? Icons.warning_amber_rounded
                                : (student.churnRisk == StudentChurnRisk.moderate
                                    ? Icons.info_outline_rounded
                                    : Icons.check_circle_outline_rounded),
                            color: _riskColor(student.churnRisk),
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'DIAGNÓSTICO DO ALGORITMO',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    color: _riskColor(student.churnRisk),
                                    letterSpacing: 0.6,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  student.riskReason,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Grid de Métricas 360°
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricTile(
                            label: 'Dias sem Treino',
                            value: '${student.daysInactive} dias',
                            sub: student.lastWorkoutDate != null
                                ? 'Último: ${_formatDate(student.lastWorkoutDate!)}'
                                : 'Nenhum treino',
                            icon: Icons.fitness_center_rounded,
                            iconColor: student.daysInactive > 7 ? Colors.redAccent : MetaColors.emerald,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricTile(
                            label: 'Check-in Semanal',
                            value: student.lastWeightKg != null
                                ? '${student.lastWeightKg!.toStringAsFixed(1)} kg'
                                : 'Pendente',
                            sub: student.lastCheckinDate != null
                                ? 'Em: ${_formatDate(student.lastCheckinDate!)}'
                                : 'Sem pesagem',
                            icon: Icons.scale_rounded,
                            iconColor: student.lastCheckinDate != null
                                ? MetaColors.emerald
                                : Colors.amber,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricTile(
                            label: 'Treinos no Mês',
                            value: '${student.workoutsThisMonth} sessões',
                            sub: '${student.workoutsCompletedTotal} totais no histórico',
                            icon: Icons.calendar_month_rounded,
                            iconColor: const Color(0xFF818CF8),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricTile(
                            label: 'Contato',
                            value: student.studentPhone ?? 'Sem tel',
                            sub: student.studentEmail ?? 'Sem email',
                            icon: Icons.phone_android_rounded,
                            iconColor: Colors.blueAccent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // Ações Rápidas
                    const Text(
                      'AÇÕES IMEDIATAS DE REATIVAÇÃO',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SquircleButton(
                      label: 'Enviar Alerta ao Treinador Responsável',
                      icon: Icons.campaign_rounded,
                      isPrimary: true,
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: const Color(0xFF6366F1),
                            content: Text(
                              '✓ Alerta de retenção enviado ao treinador ${student.trainerName} com sucesso.',
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    SquircleButton(
                      label: 'Disparar WhatsApp de Reengajamento',
                      icon: Icons.chat_rounded,
                      backgroundColor: const Color(0xFF1F2937),
                      foregroundColor: Colors.white,
                      isPrimary: false,
                      onPressed: () async {
                        Navigator.pop(context);
                        if (student.studentPhone == null || student.studentPhone!.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              backgroundColor: Colors.redAccent,
                              content: Text('Aluno sem telefone cadastrado.'),
                            ),
                          );
                          return;
                        }

                        final res = await AdminDataService.sendStudentReengagementWhatsapp(
                          studentId: student.studentId,
                          studentName: student.studentName,
                          studentPhone: student.studentPhone!,
                          trainerId: student.trainerId,
                          trainerName: student.trainerName,
                          daysInactive: student.daysInactive,
                        );

                        if (!mounted) return;
                        final msg = res['message']?.toString() ?? 'Mensagem enviada com sucesso.';
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: MetaColors.emerald,
                            content: Text('✓ $msg'),
                          ),
                        );
                      },
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

  Future<void> _handleBulkReengagement() async {
    final criticalStudents = _overview.students
        .where((s) => s.churnRisk == StudentChurnRisk.critical)
        .toList();

    if (criticalStudents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFEF4444),
          content: Text('Nenhum aluno em risco crítico encontrado para reengajar.'),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF334155)),
        ),
        title: const Row(
          children: [
            Icon(Icons.bolt_rounded, color: Color(0xFFEF4444)),
            SizedBox(width: 8),
            Text(
              'Disparo em Massa (WhatsApp)',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Deseja disparar mensagens automáticas de reengajamento via WhatsApp (Evolution API) para os ${criticalStudents.length} alunos em risco crítico de evasão?',
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Disparar Agora', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF1E293B),
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Text('Disparando reengajamento para ${criticalStudents.length} alunos...'),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );

    final result = await AdminDataService.sendBulkReengagementWhatsapp(criticalStudents);

    if (!mounted) return;

    final sent = result['sent_count'] ?? 0;
    final total = result['total'] ?? criticalStudents.length;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: MetaColors.emerald,
        content: Text('✓ Reengajamento concluído: $sent de $total disparos realizados com sucesso.'),
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required String sub,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF090D16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = MetaColors.isDark(context);
    final cardBg = isDark ? const Color(0xFF111827) : Colors.white;
    final borderColor = isDark ? const Color(0xFF1F2937) : const Color(0xFFE5E7EB);
    final textPrimary = isDark ? Colors.white : const Color(0xFF111827);
    final textSecondary = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    final filteredStudents = _overview.students.where((s) {
      final matchesQuery = _searchQuery.isEmpty ||
          s.studentName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s.trainerName.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesRisk = _selectedRiskFilter == null || s.churnRisk == _selectedRiskFilter;
      return matchesQuery && matchesRisk;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF6366F1)),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              color: const Color(0xFF6366F1),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('🎯', style: TextStyle(fontSize: 12)),
                                    SizedBox(width: 4),
                                    Text(
                                      'MISSION CONTROL • CHURN RADAR',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.8,
                                        color: Color(0xFF818CF8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Retenção & Alunos 360°',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: textPrimary,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Monitoramento preditivo de evasão, assiduidade de check-ins e engajamento.',
                                style: TextStyle(fontSize: 13, color: textSecondary),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded),
                          tooltip: 'Recarregar Retenção',
                          color: const Color(0xFF818CF8),
                          onPressed: _loadData,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Segment Switcher: Alunos 360° vs Treinadores B2B (CAC Payback & Cohorts)
                    _buildSegmentSwitcher(cardBg, borderColor, textPrimary, textSecondary),
                    const SizedBox(height: 20),

                    if (_selectedSegment == 1) ...[
                      _buildTrainerCohortsView(cardBg, borderColor, textPrimary, textSecondary),
                    ] else ...[
                    // Grid de KPIs Primários de Retenção
                    LayoutBuilder(
                      builder: (ctx, constraints) {
                        final isDesktop = constraints.maxWidth > 900;
                        final crossAxisCount = isDesktop ? 4 : (constraints.maxWidth > 600 ? 2 : 1);

                        return GridView.count(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          childAspectRatio: isDesktop ? 1.6 : 2.2,
                          children: [
                            _buildKpiCard(
                              title: 'RETENÇÃO DO ECOSSISTEMA',
                              value: '${_overview.overallRetentionRatePct.toStringAsFixed(1)}%',
                              subtext: '${_overview.totalStudents - _overview.criticalRiskCount} de ${_overview.totalStudents} alunos saudáveis',
                              icon: Icons.shield_rounded,
                              iconColor: MetaColors.emerald,
                              cardBg: cardBg,
                              borderColor: borderColor,
                              textPrimary: textPrimary,
                              textSecondary: textSecondary,
                            ),
                            _buildKpiCard(
                              title: 'CHECK-IN SEMANAL (BIO HUB)',
                              value: '${_overview.weeklyCheckinRatePct.toStringAsFixed(1)}%',
                              subtext: '${_overview.checkinsThisWeek} pesagens nesta semana',
                              icon: Icons.scale_rounded,
                              iconColor: const Color(0xFF6366F1),
                              cardBg: cardBg,
                              borderColor: borderColor,
                              textPrimary: textPrimary,
                              textSecondary: textSecondary,
                            ),
                            _buildKpiCard(
                              title: 'ALUNOS EM RISCO CRÍTICO',
                              value: '${_overview.criticalRiskCount}',
                              subtext: '>14 dias sem treino ou check-in',
                              icon: Icons.warning_rounded,
                              iconColor: Colors.redAccent,
                              cardBg: cardBg,
                              borderColor: borderColor,
                              textPrimary: textPrimary,
                              textSecondary: textSecondary,
                            ),
                            _buildKpiCard(
                              title: 'ALUNOS ATIVOS NA SEMANA',
                              value: '${_overview.activeStudentsCount}',
                              subtext: '${_overview.moderateRiskCount} em atenção moderada',
                              icon: Icons.bolt_rounded,
                              iconColor: Colors.amber,
                              cardBg: cardBg,
                              borderColor: borderColor,
                              textPrimary: textPrimary,
                              textSecondary: textSecondary,
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    // Barômetro Visual de Distribuição de Risco (Churn Spectrum)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'ESPECTRO DE SAÚDE DA BASE DE ALUNOS',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                  color: textSecondary,
                                ),
                              ),
                              Text(
                                '${_overview.totalStudents} Alunos Totais',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF818CF8),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              height: 14,
                              child: Row(
                                children: [
                                  if (_overview.totalStudents > 0) ...[
                                    Expanded(
                                      flex: _overview.healthyCount,
                                      child: Container(color: MetaColors.emerald),
                                    ),
                                    Expanded(
                                      flex: _overview.moderateRiskCount,
                                      child: Container(color: Colors.amber),
                                    ),
                                    Expanded(
                                      flex: _overview.criticalRiskCount,
                                      child: Container(color: Colors.redAccent),
                                    ),
                                  ] else
                                    Expanded(child: Container(color: Colors.grey)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 16,
                            runSpacing: 8,
                            children: [
                              _buildSpectrumLegend(
                                color: MetaColors.emerald,
                                label: 'Saudável (<30% Churn): ${_overview.healthyCount}',
                              ),
                              _buildSpectrumLegend(
                                color: Colors.amber,
                                label: 'Moderado (30-60% Churn): ${_overview.moderateRiskCount}',
                              ),
                              _buildSpectrumLegend(
                                color: Colors.redAccent,
                                label: 'Crítico (>60% Churn): ${_overview.criticalRiskCount}',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Ranking de Retenção por Personal
                    if (_overview.trainerRetentionStats.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.leaderboard_rounded, color: Color(0xFF818CF8), size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'COMPLIANCE & RETENÇÃO POR PERSONAL',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.8,
                                    color: textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _overview.trainerRetentionStats.length,
                              separatorBuilder: (context, index) => const Divider(color: Color(0xFF1F2937), height: 16),
                              itemBuilder: (ctx, idx) {
                                final t = _overview.trainerRetentionStats[idx];
                                return Row(
                                  children: [
                                    Container(
                                      width: 28,
                                      height: 28,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1F2937),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '#${idx + 1}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            t.trainerName,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${t.totalStudents} alunos · ${t.atRiskStudents} em risco',
                                            style: TextStyle(color: textSecondary, fontSize: 11.5),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '${t.retentionRatePct.toStringAsFixed(1)}% Retenção',
                                          style: TextStyle(
                                            color: t.retentionRatePct >= 70
                                                ? MetaColors.emerald
                                                : Colors.amber,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${t.checkinCompliancePct.toStringAsFixed(0)}% Check-ins',
                                          style: TextStyle(color: textSecondary, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Radar de Alunos 360° (Busca, Filtros e Lista)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.radar_rounded, color: Color(0xFF818CF8), size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'RADAR 360° DE ALUNOS & PREDIÇÃO DE EVASÃO',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.8,
                                    color: textSecondary,
                                  ),
                                ),
                              ),
                              if (_overview.criticalRiskCount > 0)
                                TextButton.icon(
                                  key: const Key('admin_retention_bulk_reengage_btn'),
                                  onPressed: _handleBulkReengagement,
                                  style: TextButton.styleFrom(
                                    backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.15),
                                    foregroundColor: const Color(0xFFEF4444),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  icon: const Icon(Icons.bolt_rounded, size: 16),
                                  label: Text(
                                    'Reengajar Críticos (${_overview.criticalRiskCount})',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Barra de Busca
                          TextField(
                            onChanged: (val) => setState(() => _searchQuery = val),
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Buscar por aluno ou personal trainer...',
                              hintStyle: TextStyle(color: textSecondary),
                              prefixIcon: Icon(Icons.search_rounded, color: textSecondary, size: 20),
                              filled: true,
                              fillColor: const Color(0xFF090D16),
                              contentPadding: const EdgeInsets.symmetric(vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: borderColor),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: borderColor),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Chips de Filtro por Risco
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildFilterChip(
                                  label: 'Todos (${_overview.students.length})',
                                  isSelected: _selectedRiskFilter == null,
                                  onTap: () => setState(() => _selectedRiskFilter = null),
                                ),
                                const SizedBox(width: 8),
                                _buildFilterChip(
                                  label: '🚨 Crítico (${_overview.criticalRiskCount})',
                                  isSelected: _selectedRiskFilter == StudentChurnRisk.critical,
                                  onTap: () => setState(() => _selectedRiskFilter = StudentChurnRisk.critical),
                                  activeColor: Colors.redAccent,
                                ),
                                const SizedBox(width: 8),
                                _buildFilterChip(
                                  label: '⚠️ Moderado (${_overview.moderateRiskCount})',
                                  isSelected: _selectedRiskFilter == StudentChurnRisk.moderate,
                                  onTap: () => setState(() => _selectedRiskFilter = StudentChurnRisk.moderate),
                                  activeColor: Colors.amber,
                                ),
                                const SizedBox(width: 8),
                                _buildFilterChip(
                                  label: '✅ Saudável (${_overview.healthyCount})',
                                  isSelected: _selectedRiskFilter == StudentChurnRisk.healthy,
                                  onTap: () => setState(() => _selectedRiskFilter = StudentChurnRisk.healthy),
                                  activeColor: MetaColors.emerald,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Lista de Alunos
                          if (filteredStudents.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 32),
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.search_off_rounded, size: 40, color: textSecondary),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Nenhum aluno encontrado para os filtros selecionados.',
                                      style: TextStyle(color: textSecondary, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: filteredStudents.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 12),
                              itemBuilder: (ctx, idx) {
                                final s = filteredStudents[idx];
                                return _buildStudentCard(s, cardBg, borderColor, textSecondary);
                              },
                            ),
                        ],
                      ),
                    ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStudentCard(
    AdminStudentRetentionItem student,
    Color cardBg,
    Color borderColor,
    Color textSecondary,
  ) {
    return InkWell(
      onTap: () => _showStudentDetailsModal(student),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF090D16),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: student.churnRisk == StudentChurnRisk.critical
                ? Colors.redAccent.withValues(alpha: 0.4)
                : borderColor,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: _riskColor(student.churnRisk).withValues(alpha: 0.2),
                  child: Text(
                    student.studentName.isNotEmpty ? student.studentName[0].toUpperCase() : 'A',
                    style: TextStyle(
                      color: _riskColor(student.churnRisk),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.studentName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Personal: ${student.trainerName}',
                        style: TextStyle(color: textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                _buildRiskPill(student.churnRisk, student.churnScore),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 14,
                        color: student.daysInactive > 7 ? Colors.redAccent : Colors.grey,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${student.daysInactive}d sem treinar',
                        style: TextStyle(
                          color: student.daysInactive > 7 ? Colors.redAccent : Colors.grey,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(
                        Icons.scale_rounded,
                        size: 14,
                        color: student.lastCheckinDate != null ? MetaColors.emerald : Colors.amber,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        student.lastCheckinDate != null
                            ? '${student.lastWeightKg?.toStringAsFixed(1) ?? "Peso"} kg'
                            : 'Check-in Pendente',
                        style: TextStyle(
                          color: student.lastCheckinDate != null ? MetaColors.emerald : Colors.amber,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded, size: 13, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(
                        '${student.workoutsThisMonth} treinos/mês',
                        style: const TextStyle(color: Colors.grey, fontSize: 11.5),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Motivo: ${student.riskReason}',
              style: TextStyle(
                color: _riskColor(student.churnRisk),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    Color activeColor = const Color(0xFF6366F1),
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.2) : const Color(0xFF090D16),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? activeColor : const Color(0xFF1F2937),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildSpectrumLegend({required Color color, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(color: Colors.grey, fontSize: 11.5, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildRiskPill(StudentChurnRisk risk, int score) {
    final color = _riskColor(risk);
    final text = risk == StudentChurnRisk.critical
        ? 'CRÍTICO ($score%)'
        : (risk == StudentChurnRisk.moderate ? 'MODERADO ($score%)' : 'SAUDÁVEL ($score%)');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Color _riskColor(StudentChurnRisk risk) {
    switch (risk) {
      case StudentChurnRisk.critical:
        return Colors.redAccent;
      case StudentChurnRisk.moderate:
        return Colors.amber;
      case StudentChurnRisk.healthy:
        return MetaColors.emerald;
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtext,
    required IconData icon,
    required Color iconColor,
    required Color cardBg,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 16, color: iconColor),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtext,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // TRAINER B2B RETENTION & CAC PAYBACK COHORTS WIDGETS
  // ============================================================================

  Widget _buildSegmentSwitcher(
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: borderColor.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSegmentButton(
              index: 0,
              label: 'Alunos 360° (B2C)',
              icon: Icons.people_alt_rounded,
              badge: '${_overview.totalStudents}',
              isSelected: _selectedSegment == 0,
              badgeColor: const Color(0xFF6366F1),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _buildSegmentButton(
              index: 1,
              label: 'Treinadores B2B & Cohorts',
              icon: Icons.business_center_rounded,
              badge: _trainerOverview != null ? '${_trainerOverview!.trainersAtRisk} em Risco' : 'COHORTS',
              isSelected: _selectedSegment == 1,
              badgeColor: const Color(0xFFEF4444),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentButton({
    required int index,
    required String label,
    required IconData icon,
    required String badge,
    required bool isSelected,
    required Color badgeColor,
  }) {
    return InkWell(
      onTap: () => setState(() => _selectedSegment = index),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6366F1).withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: isSelected
              ? Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.4))
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? const Color(0xFF818CF8) : const Color(0xFF9CA3AF),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : const Color(0xFF9CA3AF),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                badge,
                style: TextStyle(
                  color: badgeColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrainerCohortsView(
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    final tOv = _trainerOverview;
    if (tOv == null) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. KPIs B2B
        LayoutBuilder(
          builder: (ctx, constraints) {
            final isDesktop = constraints.maxWidth > 900;
            final count = isDesktop ? 4 : (constraints.maxWidth > 600 ? 2 : 1);

            return GridView.count(
              crossAxisCount: count,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: isDesktop ? 1.6 : 2.2,
              children: [
                _buildKpiCard(
                  title: 'TREINADORES EM RISCO PREDITIVO',
                  value: '${tOv.trainersAtRisk} de ${tOv.totalTrainers}',
                  subtext: '${tOv.criticalRiskCount} crítico · ${tOv.highRiskCount} alto risco',
                  icon: Icons.warning_amber_rounded,
                  iconColor: const Color(0xFFEF4444),
                  cardBg: cardBg,
                  borderColor: borderColor,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),
                _buildKpiCard(
                  title: 'RETENÇÃO MÉDIA DE COORTE',
                  value: '${tOv.avgCohortRetentionPct.toStringAsFixed(1)}%',
                  subtext: 'Benchmark saudável SaaS B2B (> 85%)',
                  icon: Icons.shield_rounded,
                  iconColor: MetaColors.emerald,
                  cardBg: cardBg,
                  borderColor: borderColor,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),
                _buildKpiCard(
                  title: 'PAYBACK MÉDIO DO CAC',
                  value: '${tOv.avgCacPaybackMonths.toStringAsFixed(1)} meses',
                  subtext: 'CAC R\$ 120 / ARPU R\$ 180+ (Retorno Imediato)',
                  icon: Icons.speed_rounded,
                  iconColor: const Color(0xFF6366F1),
                  cardBg: cardBg,
                  borderColor: borderColor,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),
                _buildKpiCard(
                  title: 'ARR PROTEGIDO EM RISCO',
                  value: 'R\$ ${tOv.arrAtRisk.toStringAsFixed(0)}',
                  subtext: 'MRR sob vigilância R\$ ${tOv.mrrAtRisk.toStringAsFixed(0)}/mês',
                  icon: Icons.savings_rounded,
                  iconColor: const Color(0xFFF59E0B),
                  cardBg: cardBg,
                  borderColor: borderColor,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                ),
              ],
            );
          },
        ),

        const SizedBox(height: 24),

        // 2. Matriz de Coortes & CAC Payback
        _buildCacCohortsTable(tOv, cardBg, borderColor, textPrimary, textSecondary),

        const SizedBox(height: 24),

        // 3. Radar Preditivo de Churn de Treinadores
        _buildTrainerRiskRadar(tOv, cardBg, borderColor, textPrimary, textSecondary),
      ],
    );
  }

  Widget _buildCacCohortsTable(
    AdminTrainerRetentionCohortsOverview tOv,
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.table_view_rounded, color: Color(0xFF818CF8), size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Matriz de Coortes & Velocidade de Payback do CAC',
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Retenção mês a mês e recuperação do Custo de Aquisição (CAC ~R\$ 120/treinador)',
                            style: TextStyle(color: textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: MetaColors.emerald.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'HEALTHY COHORTS',
                  style: TextStyle(
                    color: MetaColors.emerald,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(borderColor.withValues(alpha: 0.2)),
              columns: const [
                DataColumn(label: Text('COORTE (MÊS)', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('INICIAIS', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('ATIVOS', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('RETENÇÃO %', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('CAC INVESTIDO', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('RECEITA GERADA', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('PROGRESSO PAYBACK', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('STATUS', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('LUCRO LÍQUIDO', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: tOv.cohorts.map((c) {
                final isPaid = c.paybackStatus == 'PAGO';
                return DataRow(
                  cells: [
                    DataCell(Text(c.cohortMonth, style: const TextStyle(fontWeight: FontWeight.bold))),
                    DataCell(Text('${c.initialTrainers}')),
                    DataCell(Text('${c.activeTrainers}')),
                    DataCell(
                      Text(
                        '${c.retentionRatePct.toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: c.retentionRatePct >= 90.0 ? MetaColors.emerald : Colors.amber,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    DataCell(Text('R\$ ${c.cacInvestedTotal.toStringAsFixed(0)}')),
                    DataCell(Text('R\$ ${c.recoveredRevenueTotal.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold))),
                    DataCell(
                      SizedBox(
                        width: 110,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: (c.paybackProgressPct / 100.0).clamp(0.0, 1.0),
                                backgroundColor: borderColor,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  isPaid ? MetaColors.emerald : const Color(0xFFF59E0B),
                                ),
                                minHeight: 6,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${c.paybackProgressPct.toStringAsFixed(0)}%',
                              style: TextStyle(color: textSecondary, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: (isPaid ? MetaColors.emerald : const Color(0xFFF59E0B)).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          c.paybackStatus,
                          style: TextStyle(
                            color: isPaid ? MetaColors.emerald : const Color(0xFFF59E0B),
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        '${c.netProfitGenerated >= 0 ? '+' : ''}R\$ ${c.netProfitGenerated.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: c.netProfitGenerated >= 0 ? MetaColors.emerald : const Color(0xFFEF4444),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrainerRiskRadar(
    AdminTrainerRetentionCohortsOverview tOv,
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.radar_rounded, color: Color(0xFFEF4444), size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Radar Preditivo de Churn de Treinadores (B2B)',
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Intervenção recomendada para treinadores com inatividade e evasão de alunos',
                            style: TextStyle(color: textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${tOv.riskTrainers.length} Treinadores em Alerta',
                style: TextStyle(color: textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...tOv.riskTrainers.map((trn) {
            final isCritical = trn.riskLevel == 'CRITICAL';
            final isHigh = trn.riskLevel == 'HIGH';
            final badgeColor = isCritical
                ? const Color(0xFFEF4444)
                : (isHigh ? const Color(0xFFF97316) : const Color(0xFFF59E0B));

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: borderColor.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: badgeColor.withValues(alpha: isCritical ? 0.4 : 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: badgeColor.withValues(alpha: 0.15),
                              child: Text(
                                trn.trainerName.isNotEmpty ? trn.trainerName[0] : 'P',
                                style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        trn.trainerName,
                                        style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: badgeColor.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'RISCO ${trn.riskLevel}',
                                          style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Plano ${trn.planId.toUpperCase()} · Tel: ${trn.phone}',
                                    style: TextStyle(color: textSecondary, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Probabilidade ${trn.churnProbabilityPct.toStringAsFixed(0)}%',
                            style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          Text(
                            '${trn.daysInactive} dias inativo',
                            style: TextStyle(color: textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 10),

                  // Fatores de Risco
                  Text(
                    'FATORES DE RISCO IDENTIFICADOS:',
                    style: TextStyle(color: textSecondary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 4),
                  ...trn.riskFactors.map((f) => Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('• ', style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold)),
                            Expanded(
                              child: Text(f, style: TextStyle(color: textPrimary, fontSize: 12)),
                            ),
                          ],
                        ),
                      )),
                  const SizedBox(height: 10),

                  // Ação Sugerida & Botão de Resgate VIP
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lightbulb_rounded, color: Color(0xFF818CF8), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            trn.suggestedAction,
                            style: TextStyle(color: textPrimary, fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () => _showTrainerRescueModal(context, trn),
                          icon: const Icon(Icons.chat_rounded, size: 14),
                          label: const Text('Resgate VIP', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  void _showTrainerRescueModal(BuildContext context, AdminTrainerChurnRiskItem trn) {
    final msgCtrl = TextEditingController(
      text: 'Olá ${trn.trainerName.split(" ").first}! Notamos que faz ${trn.daysInactive} dias que você não cadastra novas fichas no Mr. Coach. Preparamos uma condição VIP para turbinar a rotina da sua assessoria esta semana. Podemos bater um papo rápido de 10 minutos?',
    );

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF111827),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF1F2937)),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.support_agent_rounded, color: Color(0xFF10B981), size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Intervenção VIP de Retenção',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Personal: ${trn.trainerName} · Plano ${trn.planId.toUpperCase()}',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 12),
              const Text(
                'Mensagem de Abordagem WhatsApp:',
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: msgCtrl,
                maxLines: 4,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF1F2937),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(ctx);
                await AdminDataService().triggerTrainerRescue(
                  trainerId: trn.trainerId,
                  channel: 'whatsapp',
                  customNote: msgCtrl.text,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Intervenção VIP disparada com sucesso para ${trn.trainerName}!'),
                      backgroundColor: const Color(0xFF10B981),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.send_rounded, size: 16),
              label: const Text('Disparar via WhatsApp', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.black,
              ),
            ),
          ],
        );
      },
    );
  }

}
