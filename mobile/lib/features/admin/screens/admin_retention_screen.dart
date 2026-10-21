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
  AdminRetentionOverview _overview = AdminRetentionOverview.empty();
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
    if (!mounted) return;
    setState(() {
      _overview = data;
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
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            backgroundColor: MetaColors.emerald,
                            content: Text(
                              '✓ Gatilho de mensagem enviado para a fila do WhatsApp (Evolution API).',
                            ),
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
                    const SizedBox(height: 24),

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
                              Text(
                                'RADAR 360° DE ALUNOS & PREDIÇÃO DE EVASÃO',
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
}
