import 'package:flutter/material.dart';
import '../../../core/utils/currency_pt_br_formatter.dart';
import '../../../core/widgets/meta_components.dart';
import '../services/admin_data_service.dart';

/// Aba Executiva de Monitoramento do Funil Público, North Star KPIs e Afiliados
class AdminPublicFunnelTab extends StatefulWidget {
  final VoidCallback? onNavigateToAffiliates;

  const AdminPublicFunnelTab({
    super.key,
    this.onNavigateToAffiliates,
  });

  @override
  State<AdminPublicFunnelTab> createState() => _AdminPublicFunnelTabState();
}

class _AdminPublicFunnelTabState extends State<AdminPublicFunnelTab> {
  bool _isLoading = true;
  String _selectedPeriod = '30d'; // 'today', '7d', '30d', 'all'
  AdminPublicFunnelData _data = AdminPublicFunnelData.mockDefault();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final result = await AdminDataService.getPublicFunnelData();
    if (!mounted) return;
    setState(() {
      _data = result;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = MetaColors.isDark(context);
    final cardBg = isDark ? const Color(0xFF111827) : Colors.white;
    final borderColor = isDark ? const Color(0xFF1F2937) : const Color(0xFFE5E7EB);
    final textPrimary = isDark ? Colors.white : const Color(0xFF111827);
    final textSecondary = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

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
                    // Header Executivo & Filtro de Período
                    _buildHeader(textPrimary, textSecondary, isDark),
                    const SizedBox(height: 20),

                    // North Star KPIs (Bento Grid)
                    _buildNorthStarGrid(isDark, cardBg, borderColor, textPrimary, textSecondary),
                    const SizedBox(height: 24),

                    // Funil de Aquisição Visual (4 Estágios)
                    _buildFunnelStagesCard(isDark, cardBg, borderColor, textPrimary, textSecondary),
                    const SizedBox(height: 24),

                    // Feed de Telemetria em Tempo Real (public_funnel_events)
                    _buildLiveTelemetryCard(isDark, cardBg, borderColor, textPrimary, textSecondary),
                    const SizedBox(height: 24),

                    // Resumo Executivo de Afiliados
                    _buildAffiliatesSummaryCard(isDark, cardBg, borderColor, textPrimary, textSecondary),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeader(Color textPrimary, Color textSecondary, bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 650;
        final periodSelector = Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
          ),
          padding: const EdgeInsets.all(3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPeriodChip('Hoje', 'today', isDark),
              _buildPeriodChip('7 Dias', '7d', isDark),
              _buildPeriodChip('30 Dias', '30d', isDark),
              _buildPeriodChip('Total', 'all', isDark),
            ],
          ),
        );

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      children: [
                        Text('🎯', style: TextStyle(fontSize: 12)),
                        SizedBox(width: 4),
                        Text(
                          'NORTH STAR KPIS • FUNIL PÚBLICO',
                          style: TextStyle(
                            color: Color(0xFF818CF8),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Funil de Aquisição, Vitrines & Afiliados',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              periodSelector,
            ],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.4)),
                        ),
                        child: const Row(
                          children: [
                            Text('🎯', style: TextStyle(fontSize: 12)),
                            SizedBox(width: 4),
                            Text(
                              'NORTH STAR KPIS • FUNIL PÚBLICO',
                              style: TextStyle(
                                color: Color(0xFF818CF8),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Funil de Aquisição, Vitrines & Afiliados',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    'Telemetria de tráfego orgânico, taxas de conversão Pix e K-Factor viral',
                    style: TextStyle(color: textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            periodSelector,
          ],
        );
      },
    );
  }

  Widget _buildPeriodChip(String label, String value, bool isDark) {
    final isSelected = _selectedPeriod == value;
    return InkWell(
      onTap: () => setState(() => _selectedPeriod = value),
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF6366F1) : const Color(0xFF4F46E5))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildNorthStarGrid(
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 900
            ? 4
            : constraints.maxWidth > 550
                ? 2
                : 1;

        final cards = [
          _buildKpiCard(
            title: 'ENGAJAMENTO SIMULADORES',
            value: '${_data.simulatorEngagementRate.toStringAsFixed(1)}%',
            targetText: 'Meta: > 35%',
            isTargetMet: _data.simulatorEngagementRate >= 35.0,
            badgeText: 'META BATIDA +7.0%',
            subtitle: '${_data.simulatorInteractions} de ${_data.totalUniqueVisitors} visitantes',
            icon: Icons.calculate_rounded,
            iconColor: const Color(0xFF6366F1),
            cardBg: cardBg,
            borderColor: borderColor,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          _buildKpiCard(
            title: 'PIX -> PRIMEIRO TREINO',
            value: '${_data.activationTimeMinutes.toStringAsFixed(1)} min',
            targetText: 'Meta: < 3.0 min',
            isTargetMet: _data.activationTimeMinutes <= 3.0,
            badgeText: 'ULTRA VELOZ',
            subtitle: '${_data.pixCheckoutsCompleted} ativações Pix na vitrine',
            icon: Icons.flash_on_rounded,
            iconColor: const Color(0xFFF59E0B),
            cardBg: cardBg,
            borderColor: borderColor,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          _buildKpiCard(
            title: 'K-FACTOR STORIES 9:16',
            value: '${_data.storyViralRate.toStringAsFixed(1)}%',
            targetText: 'Meta: > 18.0%',
            isTargetMet: _data.storyViralRate >= 18.0,
            badgeText: 'VIRALIDADE ALTA',
            subtitle: '${_data.workoutsSharedStories} cards com QR Code gerados',
            icon: Icons.share_rounded,
            iconColor: MetaColors.emerald,
            cardBg: cardBg,
            borderColor: borderColor,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          _buildKpiCard(
            title: 'EXPANSÃO PLG (STARTER->PRO)',
            value: '${_data.plgExpansionRate.toStringAsFixed(1)}%',
            targetText: 'Meta: > 45.0%',
            isTargetMet: _data.plgExpansionRate >= 45.0,
            badgeText: 'CONVERSÃO FORTE',
            subtitle: '${_data.proTrainersConverted} de ${_data.starterTrainersActive} coaches',
            icon: Icons.trending_up_rounded,
            iconColor: const Color(0xFFEC4899),
            cardBg: cardBg,
            borderColor: borderColor,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
        ];

        return GridView.count(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: crossAxisCount == 1 ? 2.3 : (crossAxisCount == 2 ? 1.6 : 1.45),
          children: cards,
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String targetText,
    required bool isTargetMet,
    required String badgeText,
    required String subtitle,
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
        borderRadius: BorderRadius.circular(18),
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
                    color: textSecondary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
              const SizedBox(width: 4),
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
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isTargetMet
                      ? MetaColors.emerald.withValues(alpha: 0.15)
                      : const Color(0xFFEF4444).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    color: isTargetMet ? MetaColors.emerald : const Color(0xFFEF4444),
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                targetText,
                style: TextStyle(
                  color: isTargetMet ? MetaColors.emerald : const Color(0xFFEF4444),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: textSecondary, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFunnelStagesCard(
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Container(
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Jornada de Conversão do Funil Público',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'De visitantes anônimos a receita recorrente de alunos e treinadores',
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'PIPELINE 4 PASSOS',
                  style: TextStyle(color: Color(0xFF818CF8), fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Etapa 1
          _buildStageRow(
            step: '1',
            title: 'Visitantes Únicos no Ecossistema',
            sub: 'Acessos na Landing B2B, Diretório /coaches e Science Hub /science',
            count: '${_data.totalUniqueVisitors} visitas',
            percent: 1.0,
            percentLabel: '100% Topo',
            gradientColors: const [Color(0xFF3B82F6), Color(0xFF6366F1)],
            isDark: isDark,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          const SizedBox(height: 14),

          // Etapa 2
          _buildStageRow(
            step: '2',
            title: 'Engajamento em Simuladores & Test-Drive',
            sub: 'Visitantes que calcularam ROI ou simularam dor/aparelho biomecânico',
            count: '${_data.simulatorInteractions} interações',
            percent: _data.simulatorInteractions / _data.totalUniqueVisitors,
            percentLabel: '${_data.simulatorEngagementRate.toStringAsFixed(1)}% engajou',
            gradientColors: const [Color(0xFF6366F1), Color(0xFF8B5CF6)],
            isDark: isDark,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          const SizedBox(height: 14),

          // Etapa 3
          _buildStageRow(
            step: '3',
            title: 'Ativações Pix nas Vitrines Públicas (/p/{user})',
            sub: 'Alunos que pagaram plano pelo Asaas com split automático 95%/5%',
            count: '${_data.pixCheckoutsCompleted} contratações',
            percent: _data.pixCheckoutsCompleted / _data.simulatorInteractions,
            percentLabel: '${((_data.pixCheckoutsCompleted / _data.simulatorInteractions) * 100).toStringAsFixed(1)}% do step 2',
            gradientColors: const [Color(0xFF8B5CF6), Color(0xFFEC4899)],
            isDark: isDark,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          const SizedBox(height: 14),

          // Etapa 4
          _buildStageRow(
            step: '4',
            title: 'Expansão PLG para Treinadores Pro',
            sub: 'Coaches que atingiram 3 alunos e assinaram recorrência Pro de R\$ 99/mês',
            count: '${_data.proTrainersConverted} coaches Pro',
            percent: _data.proTrainersConverted / _data.starterTrainersActive,
            percentLabel: '${_data.plgExpansionRate.toStringAsFixed(1)}% conversão',
            gradientColors: const [Color(0xFFEC4899), MetaColors.emerald],
            isDark: isDark,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
        ],
      ),
    );
  }

  Widget _buildStageRow({
    required String step,
    required String title,
    required String sub,
    required String count,
    required double percent,
    required String percentLabel,
    required List<Color> gradientColors,
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final clampedPercent = percent.clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 11,
                  backgroundColor: gradientColors.first.withValues(alpha: 0.2),
                  child: Text(
                    step,
                    style: TextStyle(
                      color: gradientColors.first,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Text(
                  count,
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: gradientColors.last.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    percentLabel,
                    style: TextStyle(
                      color: gradientColors.last,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 30),
          child: Text(sub, style: TextStyle(color: textSecondary, fontSize: 11)),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 30),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: clampedPercent,
              minHeight: 6,
              backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(gradientColors.last),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLiveTelemetryCard(
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Container(
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
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: MetaColors.emerald,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Feed de Eventos em Tempo Real (public_funnel_events)',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              Text(
                '${_data.recentEvents.length} eventos recentes',
                style: TextStyle(color: textSecondary, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _data.recentEvents.length,
            separatorBuilder: (context, index) => Divider(
              color: isDark ? const Color(0xFF1F2937) : const Color(0xFFE5E7EB),
              height: 16,
            ),
            itemBuilder: (context, index) {
              final ev = _data.recentEvents[index];
              return _buildEventItem(ev, isDark, textPrimary, textSecondary);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEventItem(
    PublicFunnelEvent ev,
    bool isDark,
    Color textPrimary,
    Color textSecondary,
  ) {
    Color badgeColor;
    IconData icon;

    switch (ev.eventType) {
      case 'CHECKOUT_PIX_SUCCESS':
        badgeColor = MetaColors.emerald;
        icon = Icons.check_circle_rounded;
        break;
      case 'SIMULATOR_ROI_CALC':
        badgeColor = const Color(0xFF6366F1);
        icon = Icons.calculate_rounded;
        break;
      case 'STORY_CARD_EXPORT':
        badgeColor = const Color(0xFFEC4899);
        icon = Icons.camera_alt_rounded;
        break;
      case 'TEST_DRIVE_BIOMECHANICS':
        badgeColor = const Color(0xFFF59E0B);
        icon = Icons.science_rounded;
        break;
      case 'PLG_CONVERSION_PRO':
        badgeColor = const Color(0xFF06B6D4);
        icon = Icons.star_rounded;
        break;
      default:
        badgeColor = Colors.grey;
        icon = Icons.info_rounded;
    }

    final diff = DateTime.now().difference(ev.timestamp);
    final timeAgo = diff.inMinutes < 60
        ? '${diff.inMinutes}m atrás'
        : '${diff.inHours}h atrás';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: badgeColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      ev.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    timeAgo,
                    style: TextStyle(color: textSecondary, fontSize: 10.5),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                ev.details,
                style: TextStyle(color: textSecondary, fontSize: 11.5),
              ),
              const SizedBox(height: 2),
              Text(
                'Origem: ${ev.sourcePath}',
                style: TextStyle(
                  color: const Color(0xFF818CF8),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAffiliatesSummaryCard(
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Container(
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Motor de Afiliados & Comissões B2B',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Parceiros credenciados, GMV gerado e liquidação de comissões Pix',
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
                ],
              ),
              if (widget.onNavigateToAffiliates != null)
                TextButton.icon(
                  onPressed: widget.onNavigateToAffiliates,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF818CF8)),
                  label: const Text(
                    'Gerenciar Afiliados',
                    style: TextStyle(color: Color(0xFF818CF8), fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  label: 'GMV VIA AFILIADOS',
                  value: CurrencyPtBrFormatter.format(_data.totalGmvGeneratedBrl),
                  color: MetaColors.emerald,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricTile(
                  label: 'COMISSÕES TOTAIS',
                  value: CurrencyPtBrFormatter.format(_data.totalCommissionsBrl),
                  color: const Color(0xFF6366F1),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricTile(
                  label: 'LIQUIDAÇÃO PIX',
                  value: 'Automática D+1',
                  color: const Color(0xFFF59E0B),
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
