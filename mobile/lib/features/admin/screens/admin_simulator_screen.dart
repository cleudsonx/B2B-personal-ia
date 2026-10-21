import 'package:flutter/material.dart';
import '../../../core/widgets/meta_components.dart';
import '../services/admin_data_service.dart';

class AdminSimulatorScreen extends StatefulWidget {
  const AdminSimulatorScreen({super.key});

  @override
  State<AdminSimulatorScreen> createState() => _AdminSimulatorScreenState();
}

class _AdminSimulatorScreenState extends State<AdminSimulatorScreen> {
  final AdminDataService _dataService = AdminDataService();

  bool _isLoading = true;
  bool _isSimulating = false;

  AdminUnitEconomicsOverview? _overview;
  AdminPricingSimulationResult? _simResult;

  // Sliders de simulação
  double _starterPrice = 0.0;
  double _proPrice = 89.0;
  double _elitePrice = 149.0;
  double _studioPrice = 199.0;
  double _takeRatePct = 5.0;
  double _projectedGrowthPct = 15.0;
  bool _enableGeminiOptimization = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final ov = await _dataService.getUnitEconomicsOverview();
    if (mounted) {
      setState(() {
        _overview = ov;
        _isLoading = false;
      });
      _runSimulation();
    }
  }

  Future<void> _runSimulation() async {
    setState(() => _isSimulating = true);
    final res = await _dataService.simulatePricingScenario(
      starterPrice: _starterPrice,
      proPrice: _proPrice,
      elitePrice: _elitePrice,
      studioPrice: _studioPrice,
      takeRatePct: _takeRatePct,
      geminiOptFactor: _enableGeminiOptimization ? 0.70 : 1.0,
      projectedGrowthPct: _projectedGrowthPct,
    );

    if (mounted) {
      setState(() {
        _simResult = res;
        _isSimulating = false;
      });
    }
  }

  void _resetDefaults() {
    setState(() {
      _starterPrice = 0.0;
      _proPrice = 89.0;
      _elitePrice = 149.0;
      _studioPrice = 199.0;
      _takeRatePct = 5.0;
      _projectedGrowthPct = 15.0;
      _enableGeminiOptimization = true;
    });
    _runSimulation();
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
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: const Color(0xFF10B981),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cabeçalho
                    _buildHeader(textPrimary, textSecondary),
                    const SizedBox(height: 24),

                    // Top KPIs
                    if (_overview != null)
                      _buildKpiGrid(_overview!, cardBg, borderColor, textPrimary, textSecondary),
                    const SizedBox(height: 24),

                    // Painel Interativo de Simulação + Resultado do Delta
                    _buildSimulatorSection(cardBg, borderColor, textPrimary, textSecondary),
                    const SizedBox(height: 28),

                    // Matriz de Unit Economics por Tier (Starter, Pro, Elite, Studio)
                    if (_overview != null)
                      _buildTierEconomicsSection(_overview!, cardBg, borderColor, textPrimary, textSecondary),
                    const SizedBox(height: 28),

                    // Ranking de Personals por Margem Líquida Contribuída
                    if (_overview != null)
                      _buildTopTrainersSection(_overview!, cardBg, borderColor, textPrimary, textSecondary),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeader(Color textPrimary, Color textSecondary) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                ),
                child: const Icon(
                  Icons.calculate_rounded,
                  color: Color(0xFF10B981),
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Simulador de Precificação & Margem Líquida',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'SaaS Pricing, Split GMV (5%) e Unit Economics vs COGS de IA Gemini & WhatsApp',
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: _loadData,
          tooltip: 'Recarregar Unit Economics',
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: textSecondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.refresh_rounded, color: textPrimary, size: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildKpiGrid(
    AdminUnitEconomicsOverview ov,
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 700;
        final count = isMobile ? 2 : 4;

        return GridView.count(
          crossAxisCount: count,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: isMobile ? 1.45 : 1.7,
          children: [
            _buildKpiCard(
              title: 'MRR CONSOLIDADO',
              value: 'R\$ ${ov.totalMrr.toStringAsFixed(2)}',
              subvalue: 'Assinaturas R\$ ${ov.mrrSubscriptions.toStringAsFixed(0)} + Split R\$ ${ov.mrrSplitGmv.toStringAsFixed(0)}',
              icon: Icons.payments_rounded,
              color: const Color(0xFF10B981),
              cardBg: cardBg,
              borderColor: borderColor,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
            _buildKpiCard(
              title: 'MARGEM LÍQUIDA',
              value: '${ov.netMarginPct.toStringAsFixed(1)}%',
              subvalue: 'Lucro Líquido R\$ ${ov.netMarginMonthly.toStringAsFixed(2)}/mês',
              icon: Icons.shield_rounded,
              color: const Color(0xFF6366F1),
              cardBg: cardBg,
              borderColor: borderColor,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
            _buildKpiCard(
              title: 'LTV / CAC RATIO',
              value: '${ov.ltvToCacRatio.toStringAsFixed(1)}x',
              subvalue: 'LTV R\$ ${ov.ltvEstimated.toStringAsFixed(0)} · CAC R\$ ${ov.cacEstimated.toStringAsFixed(0)}',
              icon: Icons.trending_up_rounded,
              color: const Color(0xFFF59E0B),
              cardBg: cardBg,
              borderColor: borderColor,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
            _buildKpiCard(
              title: 'PAYBACK & ARR',
              value: '${ov.paybackMonths.toStringAsFixed(1)} meses',
              subvalue: 'ARR Projetado R\$ ${ov.arr.toStringAsFixed(0)}',
              icon: Icons.speed_rounded,
              color: const Color(0xFF06B6D4),
              cardBg: cardBg,
              borderColor: borderColor,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
          ],
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subvalue,
    required IconData icon,
    required Color color,
    required Color cardBg,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
            ],
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                color: textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Text(
            subvalue,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimulatorSection(
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;

        final controlsWidget = Container(
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
                        const Icon(Icons.tune_rounded, color: Color(0xFF10B981), size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Parâmetros Comerciais & Precificação',
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _resetDefaults,
                    icon: const Icon(Icons.restore_rounded, size: 16),
                    label: const Text('Restaurar Padrão', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Slider Plano Pro
              _buildSliderRow(
                label: 'Plano Pro (Mensal)',
                value: _proPrice,
                min: 49.0,
                max: 189.0,
                divisions: 28,
                unit: 'R\$ ',
                onChanged: (v) {
                  setState(() => _proPrice = v);
                  _runSimulation();
                },
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),

              // Slider Plano Elite
              _buildSliderRow(
                label: 'Plano Elite (Mensal)',
                value: _elitePrice,
                min: 99.0,
                max: 299.0,
                divisions: 20,
                unit: 'R\$ ',
                onChanged: (v) {
                  setState(() => _elitePrice = v);
                  _runSimulation();
                },
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),

              // Slider Plano Studio
              _buildSliderRow(
                label: 'Plano Studio (Mensal)',
                value: _studioPrice,
                min: 149.0,
                max: 499.0,
                divisions: 35,
                unit: 'R\$ ',
                onChanged: (v) {
                  setState(() => _studioPrice = v);
                  _runSimulation();
                },
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),

              // Slider Take-Rate Split GMV
              _buildSliderRow(
                label: 'Split de GMV da Consultoria (Take-Rate %)',
                value: _takeRatePct,
                min: 0.0,
                max: 15.0,
                divisions: 30,
                unit: '',
                suffix: '%',
                onChanged: (v) {
                  setState(() => _takeRatePct = v);
                  _runSimulation();
                },
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),

              // Slider Projeção de Crescimento da Base
              _buildSliderRow(
                label: 'Projeção de Expansão da Base de Treinadores',
                value: _projectedGrowthPct,
                min: -20.0,
                max: 100.0,
                divisions: 24,
                unit: '',
                suffix: '%',
                onChanged: (v) {
                  setState(() => _projectedGrowthPct = v);
                  _runSimulation();
                },
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),

              const SizedBox(height: 8),

              // Toggle Otimização Gemini Flash Lite
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.bolt_rounded, color: Color(0xFF6366F1), size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Otimização Gemini 2.5 Flash Lite (-30% Token COGS)',
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Context caching agressivo + Zero-Cost router de comandos locais',
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: _enableGeminiOptimization,
                      activeTrackColor: const Color(0xFF6366F1),
                      onChanged: (val) {
                        setState(() => _enableGeminiOptimization = val);
                        _runSimulation();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

        final resultWidget = _buildSimulationResultCard(cardBg, borderColor, textPrimary, textSecondary);

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 5, child: controlsWidget),
              const SizedBox(width: 20),
              Expanded(flex: 4, child: resultWidget),
            ],
          );
        } else {
          return Column(
            children: [
              controlsWidget,
              const SizedBox(height: 20),
              resultWidget,
            ],
          );
        }
      },
    );
  }

  Widget _buildSliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String unit,
    String suffix = '',
    required ValueChanged<double> onChanged,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$unit${value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1)}$suffix',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFF10B981),
              thumbColor: const Color(0xFF10B981),
              overlayColor: const Color(0xFF10B981).withValues(alpha: 0.2),
              trackHeight: 4,
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimulationResultCard(
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    final sim = _simResult;

    final isPositiveDelta = (sim?.deltaMrr ?? 0) >= 0;
    final deltaColor = isPositiveDelta ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
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
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.analytics_rounded, color: Color(0xFF10B981), size: 18),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Impacto Projetado',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (_isSimulating)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF10B981)),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: deltaColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${isPositiveDelta ? '+' : ''}${sim?.deltaMrrPct.toStringAsFixed(1) ?? '0.0'}%',
                    style: TextStyle(
                      color: deltaColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // MRR Projetado Grande
          Text(
            'MRR PROJETADO',
            style: TextStyle(
              color: textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'R\$ ${sim?.projectedMrr.toStringAsFixed(2) ?? '0.00'}',
            style: TextStyle(
              color: textPrimary,
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                isPositiveDelta ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                color: deltaColor,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                'Delta: ${isPositiveDelta ? '+' : ''}R\$ ${sim?.deltaMrr.toStringAsFixed(2) ?? '0.00'}/mês',
                style: TextStyle(
                  color: deltaColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // Lucro Líquido Anual Adicional
          _buildSummaryLine(
            title: 'Impacto Lucro Líquido Anual',
            value: '${isPositiveDelta ? '+' : ''}R\$ ${sim?.deltaAnnualNetProfit.toStringAsFixed(2) ?? '0.00'}/ano',
            valueColor: deltaColor,
            textSecondary: textSecondary,
            bold: true,
          ),
          const SizedBox(height: 10),

          // Margem Líquida Projetada
          _buildSummaryLine(
            title: 'Nova Margem Líquida %',
            value: '${sim?.projectedNetMarginPct.toStringAsFixed(1) ?? '0.0'}%',
            valueColor: textPrimary,
            textSecondary: textSecondary,
          ),
          const SizedBox(height: 10),

          // Base Ativa Simulada
          _buildSummaryLine(
            title: 'Base Simulada',
            value: '${sim?.projectedTrainers ?? 0} Personals · ${sim?.projectedStudents ?? 0} Alunos',
            valueColor: textPrimary,
            textSecondary: textSecondary,
          ),

          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),

          Text(
            'COGS / CUSTOS DIRETOS PROJETADOS',
            style: TextStyle(
              color: textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),

          // Breakdown de COGS
          Row(
            children: [
              Expanded(
                child: _buildCogsMiniBadge(
                  label: 'Gemini AI',
                  value: 'R\$ ${sim?.cogsBreakdown['gemini_ai']?.toStringAsFixed(2) ?? '0.00'}',
                  color: const Color(0xFF6366F1),
                  textPrimary: textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCogsMiniBadge(
                  label: 'WhatsApp',
                  value: 'R\$ ${sim?.cogsBreakdown['whatsapp']?.toStringAsFixed(2) ?? '0.00'}',
                  color: const Color(0xFF10B981),
                  textPrimary: textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCogsMiniBadge(
                  label: 'Gateway',
                  value: 'R\$ ${sim?.cogsBreakdown['gateway']?.toStringAsFixed(2) ?? '0.00'}',
                  color: const Color(0xFFF59E0B),
                  textPrimary: textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryLine({
    required String title,
    required String value,
    required Color valueColor,
    required Color textSecondary,
    bool bold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: textSecondary,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 13,
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildCogsMiniBadge({
    required String label,
    required String value,
    required Color color,
    required Color textPrimary,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(color: textPrimary, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildTierEconomicsSection(
    AdminUnitEconomicsOverview ov,
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
            children: [
              const Icon(Icons.table_chart_rounded, color: Color(0xFF6366F1), size: 20),
              const SizedBox(width: 8),
              Text(
                'Matriz de Unit Economics por Tier de Assinatura',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(textSecondary.withValues(alpha: 0.08)),
              columns: const [
                DataColumn(label: Text('TIER / PLANO', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('PERSONALS', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('ALUNOS', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('PREÇO BASE', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('MRR PLANO', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('MRR SPLIT (5%)', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('COGS IA', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('MARGEM LÍQUIDA', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('MARGEM %', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: ov.tierEconomics.map((t) {
                final tierColor = _getTierColor(t.tier);
                return DataRow(
                  cells: [
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: tierColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          t.tier.toUpperCase(),
                          style: TextStyle(color: tierColor, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                    ),
                    DataCell(Text('${t.trainers}')),
                    DataCell(Text('${t.studentsTotal}')),
                    DataCell(Text(t.price > 0 ? 'R\$ ${t.price.toStringAsFixed(0)}' : 'Gratuito')),
                    DataCell(Text('R\$ ${t.mrrSubs.toStringAsFixed(0)}')),
                    DataCell(Text('R\$ ${t.mrrSplit.toStringAsFixed(0)}')),
                    DataCell(Text('R\$ ${t.cogsAi.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFFEF4444)))),
                    DataCell(Text('R\$ ${t.netMargin.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF10B981)))),
                    DataCell(Text('${t.marginPct.toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.bold))),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopTrainersSection(
    AdminUnitEconomicsOverview ov,
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
              Row(
                children: [
                  const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Top Personals por Margem Líquida Contribuída',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Text(
                'High Value Accounts',
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...ov.topTrainerEconomics.map((trn) {
            final tierColor = _getTierColor(trn.planId);
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: borderColor.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.15),
                    child: Text(
                      trn.trainerName.isNotEmpty ? trn.trainerName[0] : 'P',
                      style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              trn.trainerName,
                              style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: tierColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                trn.planId.toUpperCase(),
                                style: TextStyle(color: tierColor, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${trn.studentsCount} alunos ativos · GMV R\$ ${trn.gmv.toStringAsFixed(0)} · Custo IA R\$ ${trn.cogsTotal.toStringAsFixed(2)}',
                          style: TextStyle(color: textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'R\$ ${trn.netMargin.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Color(0xFF10B981),
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Margem ${trn.netMarginPct.toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Color _getTierColor(String tier) {
    switch (tier.toLowerCase()) {
      case 'starter':
        return const Color(0xFF6B7280);
      case 'pro':
        return const Color(0xFF3B82F6);
      case 'elite':
        return const Color(0xFF8B5CF6);
      case 'studio':
        return const Color(0xFFEC4899);
      default:
        return const Color(0xFF10B981);
    }
  }
}
