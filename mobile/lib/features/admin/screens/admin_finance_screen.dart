import 'package:flutter/material.dart';
import '../../../core/widgets/meta_components.dart';
import '../services/admin_data_service.dart';
import '../widgets/admin_finance_export_modal.dart';

/// Módulo 3: Faturamento, Split & GMV (Take-rate 5% da Plataforma) e Modelagem LTV/CAC & Runway Forecast
class AdminFinanceScreen extends StatefulWidget {
  final VoidCallback? onNavigateToSimulator;

  const AdminFinanceScreen({
    super.key,
    this.onNavigateToSimulator,
  });

  @override
  State<AdminFinanceScreen> createState() => _AdminFinanceScreenState();
}

class _AdminFinanceScreenState extends State<AdminFinanceScreen> {
  final TextEditingController _searchCtrl = TextEditingController();

  int _selectedTab = 0; // 0: Transações & Splits, 1: LTV/CAC & Runway Forecast

  String _formatCurrency(double value) {
    return 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  String _formatDateTime(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d/$m/$y $h:$min';
  }

  bool _isLoading = true;
  List<AdminTransaction> _transactions = [];
  String _statusFilter = 'all'; // 'all', 'paid', 'pending', 'failed'

  // Runway & LTV/CAC State
  bool _isLoadingRunway = false;
  AdminRunwayForecastResult? _runwayResult;

  // Sliders de simulação de Runway
  double _initialCash = 85000.0;
  double _fixedOpex = 4500.0;
  double _cacSpend = 1800.0;
  double _trainerGrowthPct = 12.0;
  double _churnPct = 2.5;
  double _cacPerTrainer = 120.0;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
    _loadRunwayData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);
    final data = await AdminDataService.getTransactions(
      statusFilter: _statusFilter,
      searchQuery: _searchCtrl.text,
    );
    if (mounted) {
      setState(() {
        _transactions = data;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadRunwayData() async {
    setState(() => _isLoadingRunway = true);
    final res = await AdminDataService.getRunwayOverview();
    if (mounted) {
      setState(() {
        _runwayResult = res;
        _isLoadingRunway = false;
      });
    }
  }

  Future<void> _runRunwaySimulation() async {
    setState(() => _isLoadingRunway = true);
    final res = await AdminDataService.simulateRunwayForecast(
      initialCashBalance: _initialCash,
      monthlyFixedOpex: _fixedOpex,
      monthlyCacSpend: _cacSpend,
      monthlyTrainerGrowthPct: _trainerGrowthPct,
      monthlyChurnPct: _churnPct,
      cacPerTrainer: _cacPerTrainer,
    );
    if (mounted) {
      setState(() {
        _runwayResult = res;
        _isLoadingRunway = false;
      });
    }
  }

  void _resetRunwayDefaults() {
    setState(() {
      _initialCash = 85000.0;
      _fixedOpex = 4500.0;
      _cacSpend = 1800.0;
      _trainerGrowthPct = 12.0;
      _churnPct = 2.5;
      _cacPerTrainer = 120.0;
    });
    _runRunwaySimulation();
  }

  double get _totalGmv =>
      _transactions.where((t) => t.isPaid).fold(0.0, (acc, t) => acc + t.amountReais);

  double get _totalPlatformFee => _totalGmv * 0.05; // 5% Take-Rate

  double get _totalTrainerNet => _totalGmv * 0.95; // 95% Repasse aos Treinadores

  int get _paidCount => _transactions.where((t) => t.isPaid).length;
  int get _pendingCount => _transactions.where((t) => t.isPending).length;
  int get _failedCount => _transactions.where((t) => t.isFailed).length;

  void _showTransactionDetails(AdminTransaction tx) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF1F2937), width: 1.2),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF818CF8), size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              'Detalhes do Split',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('ID da Transação', tx.id),
              _buildDetailRow('Treinador', tx.trainerName),
              if (tx.trainerEmail != null) _buildDetailRow('E-mail', tx.trainerEmail!),
              _buildDetailRow('Plano', tx.planName),
              _buildDetailRow('Método', tx.paymentMethod.toUpperCase()),
              _buildDetailRow('Data/Hora', _formatDateTime(tx.createdAt)),
              const Divider(color: Color(0xFF1F2937), height: 24),
              // Resumo do Split
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF090D16),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF1F2937)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Valor Bruto (GMV):', style: TextStyle(color: Colors.white70, fontSize: 13)),
                        Text(
                          _formatCurrency(tx.amountReais),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.shield_rounded, size: 13, color: Color(0xFF818CF8)),
                            SizedBox(width: 4),
                            Text('Take-rate Plataforma (5%):', style: TextStyle(color: Color(0xFF818CF8), fontSize: 13, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Text(
                          _formatCurrency(tx.platformFeeReais),
                          style: const TextStyle(color: Color(0xFF818CF8), fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.person_rounded, size: 13, color: MetaColors.emerald),
                            SizedBox(width: 4),
                            Text('Líquido do Personal (95%):', style: TextStyle(color: MetaColors.emerald, fontSize: 13, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Text(
                          _formatCurrency(tx.trainerNetReais),
                          style: const TextStyle(color: MetaColors.emerald, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 13)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadTransactions();
          await _loadRunwayData();
        },
        color: const Color(0xFF6366F1),
        backgroundColor: const Color(0xFF111827),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header do Módulo
              _buildHeader(),
              const SizedBox(height: 20),

              // Segmentador de Abas
              _buildSegmentSwitcher(),
              const SizedBox(height: 24),

              if (_selectedTab == 0) ...[
                _buildTransactionsTab(),
              ] else ...[
                _buildRunwayForecastTab(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Row(
                children: [
                  Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF818CF8), size: 24),
                  SizedBox(width: 10),
                  Text(
                    'Financeiro & Unit Economics',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4),
              Text(
                'Auditoria de transações Asaas/Pix, repasses, split 5% e modelagem preditiva de fluxo de caixa & runway',
                style: TextStyle(color: Colors.white60, fontSize: 13),
              ),
            ],
          ),
        ),
        Row(
          children: [
            if (widget.onNavigateToSimulator != null) ...[
              OutlinedButton.icon(
                onPressed: widget.onNavigateToSimulator,
                icon: const Icon(Icons.calculate_rounded, size: 16, color: Color(0xFF10B981)),
                label: const Text('Simulador de Margem', style: TextStyle(color: Color(0xFF10B981), fontSize: 13, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                  backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.1),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(width: 10),
            ],
            ElevatedButton.icon(
              onPressed: () => AdminFinanceExportModal.show(context, _transactions),
              icon: const Icon(Icons.download_rounded, size: 16),
              label: const Text('Exportar Relatório', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: MetaColors.emerald,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: () {
                _loadTransactions();
                _loadRunwayData();
              },
              icon: const Icon(Icons.refresh_rounded, size: 16, color: Color(0xFF818CF8)),
              label: const Text('Atualizar', style: TextStyle(color: Color(0xFF818CF8), fontSize: 13)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF1F2937)),
                backgroundColor: const Color(0xFF111827),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSegmentSwitcher() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _selectedTab = 0),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedTab == 0 ? const Color(0xFF6366F1) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.receipt_long_rounded, size: 16, color: _selectedTab == 0 ? Colors.white : Colors.white60),
                    const SizedBox(width: 8),
                    Text(
                      'Faturamento & Split (Transações Asaas)',
                      style: TextStyle(
                        color: _selectedTab == 0 ? Colors.white : Colors.white60,
                        fontSize: 13,
                        fontWeight: _selectedTab == 0 ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _selectedTab = 1),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedTab == 1 ? const Color(0xFF6366F1) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.trending_up_rounded, size: 16, color: _selectedTab == 1 ? Colors.white : Colors.white60),
                    const SizedBox(width: 8),
                    Text(
                      'Modelagem LTV/CAC & Runway Forecast (12M)',
                      style: TextStyle(
                        color: _selectedTab == 1 ? Colors.white : Colors.white60,
                        fontSize: 13,
                        fontWeight: _selectedTab == 1 ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // TAB 1: TRANSAÇÕES & SPLITS
  // ============================================================================

  Widget _buildTransactionsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Cards de KPIs Financeiros
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 800;
            return isWide
                ? Row(
                    children: [
                      Expanded(child: _buildKpiCard('GMV Total Liquidado', _formatCurrency(_totalGmv), Icons.monetization_on_rounded, MetaColors.emerald, 'Volume bruto transacionado')),
                      const SizedBox(width: 16),
                      Expanded(child: _buildKpiCard('Take-Rate Plataforma (5%)', _formatCurrency(_totalPlatformFee), Icons.pie_chart_rounded, const Color(0xFF818CF8), 'Receita líquida retida')),
                      const SizedBox(width: 16),
                      Expanded(child: _buildKpiCard('Repasse aos Personals (95%)', _formatCurrency(_totalTrainerNet), Icons.people_outline_rounded, const Color(0xFF38BDF8), 'Líquido creditado aos profs.')),
                      const SizedBox(width: 16),
                      Expanded(child: _buildKpiCard('Eficiência de Cobrança', '$_paidCount/${_transactions.length} pagas', Icons.verified_rounded, Colors.amber, '$_pendingCount pend. • $_failedCount falhas')),
                    ],
                  )
                : Column(
                    children: [
                      _buildKpiCard('GMV Total Liquidado', _formatCurrency(_totalGmv), Icons.monetization_on_rounded, MetaColors.emerald, 'Volume bruto transacionado'),
                      const SizedBox(height: 12),
                      _buildKpiCard('Take-Rate Plataforma (5%)', _formatCurrency(_totalPlatformFee), Icons.pie_chart_rounded, const Color(0xFF818CF8), 'Receita líquida retida'),
                      const SizedBox(height: 12),
                      _buildKpiCard('Repasse aos Personals (95%)', _formatCurrency(_totalTrainerNet), Icons.people_outline_rounded, const Color(0xFF38BDF8), 'Líquido creditado aos profs.'),
                      const SizedBox(height: 12),
                      _buildKpiCard('Eficiência de Cobrança', '$_paidCount/${_transactions.length} pagas', Icons.verified_rounded, Colors.amber, '$_pendingCount pend. • $_failedCount falhas'),
                    ],
                  );
          },
        ),
        const SizedBox(height: 24),

        // Barra de Busca e Filtros
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1F2937)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      onChanged: (_) => _loadTransactions(),
                      decoration: InputDecoration(
                        hintText: 'Buscar por treinador, e-mail ou código da transação...',
                        hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                        prefixIcon: const Icon(Icons.search_rounded, color: Colors.white38, size: 20),
                        suffixIcon: _searchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18, color: Colors.white38),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  _loadTransactions();
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: const Color(0xFF090D16),
                        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF1F2937)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF1F2937)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Filtros por Status
              Row(
                children: [
                  _buildStatusFilterChip('all', 'Todas (${_transactions.length})'),
                  const SizedBox(width: 8),
                  _buildStatusFilterChip('paid', 'Pagas ($_paidCount)', color: MetaColors.emerald),
                  const SizedBox(width: 8),
                  _buildStatusFilterChip('pending', 'Pendentes ($_pendingCount)', color: Colors.amber),
                  const SizedBox(width: 8),
                  _buildStatusFilterChip('failed', 'Falhas ($_failedCount)', color: Colors.redAccent),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Lista de Transações
        if (_isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(48),
              child: CircularProgressIndicator(color: Color(0xFF6366F1)),
            ),
          )
        else if (_transactions.isEmpty)
          Container(
            padding: const EdgeInsets.all(48),
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF1F2937)),
            ),
            child: Column(
              children: const [
                Icon(Icons.inbox_outlined, size: 48, color: Colors.white24),
                SizedBox(height: 12),
                Text(
                  'Nenhuma transação encontrada',
                  style: TextStyle(color: Colors.white60, fontSize: 14),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _transactions.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final tx = _transactions[index];
              return _buildTransactionCard(tx);
            },
          ),
      ],
    );
  }

  // ============================================================================
  // TAB 2: MODELAGEM LTV/CAC & RUNWAY CASHFLOW FORECAST
  // ============================================================================

  Widget _buildRunwayForecastTab() {
    if (_isLoadingRunway || _runwayResult == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(48),
          child: CircularProgressIndicator(color: Color(0xFF10B981)),
        ),
      );
    }

    final s = _runwayResult!.summary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Top KPI Grid de Runway & Unit Economics
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 900;
            final isMed = constraints.maxWidth > 600;

            final kpi1 = _buildRunwayKpiCard(
              title: 'Saldo Final Projetado (12M)',
              value: _formatCurrency(s.finalCashBalance),
              subtitle: 'Inicial: ${_formatCurrency(s.initialCashBalance)} (${s.netCashDelta >= 0 ? "+" : ""}${_formatCurrency(s.netCashDelta)})',
              icon: Icons.account_balance_rounded,
              color: s.netCashDelta >= 0 ? const Color(0xFF10B981) : Colors.amber,
            );

            final kpi2 = _buildRunwayKpiCard(
              title: 'Status de Sobrevivência',
              value: s.isDefaultAlive ? 'DEFAULT ALIVE' : '${s.runwayMonths.toStringAsFixed(1)} Meses',
              subtitle: s.isDefaultAlive ? 'Fluxo autossustentável e positivo' : 'Runway crítico antes do breakeven',
              icon: s.isDefaultAlive ? Icons.shield_rounded : Icons.timer_outlined,
              color: s.isDefaultAlive ? const Color(0xFF10B981) : Colors.redAccent,
            );

            final kpi3 = _buildRunwayKpiCard(
              title: 'Relação LTV / CAC',
              value: '${s.ltvToCacRatio}x',
              subtitle: 'LTV: ${_formatCurrency(s.ltv)} • CAC: ${_formatCurrency(s.cac)}',
              icon: Icons.hub_rounded,
              color: const Color(0xFF6366F1),
            );

            final kpi4 = _buildRunwayKpiCard(
              title: 'Mês de Breakeven Operacional',
              value: 'Mês ${s.breakevenMonth}',
              subtitle: 'Ponto de equilíbrio de caixa atingido',
              icon: Icons.check_circle_outline_rounded,
              color: const Color(0xFF38BDF8),
            );

            if (isWide) {
              return Row(
                children: [
                  Expanded(child: kpi1),
                  const SizedBox(width: 14),
                  Expanded(child: kpi2),
                  const SizedBox(width: 14),
                  Expanded(child: kpi3),
                  const SizedBox(width: 14),
                  Expanded(child: kpi4),
                ],
              );
            } else if (isMed) {
              return Column(
                children: [
                  Row(children: [Expanded(child: kpi1), const SizedBox(width: 14), Expanded(child: kpi2)]),
                  const SizedBox(height: 14),
                  Row(children: [Expanded(child: kpi3), const SizedBox(width: 14), Expanded(child: kpi4)]),
                ],
              );
            } else {
              return Column(
                children: [
                  kpi1,
                  const SizedBox(height: 12),
                  kpi2,
                  const SizedBox(height: 12),
                  kpi3,
                  const SizedBox(height: 12),
                  kpi4,
                ],
              );
            }
          },
        ),
        const SizedBox(height: 24),

        // 2. Painel Interativo de Sliders de Simulação
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1F2937), width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.tune_rounded, color: Color(0xFF10B981), size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Simulador Interativo de Parâmetros de Caixa & Queima',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: _resetRunwayDefaults,
                    icon: const Icon(Icons.restart_alt_rounded, size: 16, color: Color(0xFF818CF8)),
                    label: const Text('Valores de Referência', style: TextStyle(color: Color(0xFF818CF8), fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 800;
                  final col1 = Column(
                    children: [
                      _buildSliderField(
                        label: 'Caixa Inicial Disponível',
                        value: _initialCash,
                        displayValue: _formatCurrency(_initialCash),
                        min: 10000.0,
                        max: 250000.0,
                        divisions: 24,
                        onChanged: (v) {
                          setState(() => _initialCash = v);
                          _runRunwaySimulation();
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildSliderField(
                        label: 'Custo Operacional Fixo (OPEX Mensal)',
                        value: _fixedOpex,
                        displayValue: _formatCurrency(_fixedOpex),
                        min: 1000.0,
                        max: 20000.0,
                        divisions: 19,
                        onChanged: (v) {
                          setState(() => _fixedOpex = v);
                          _runRunwaySimulation();
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildSliderField(
                        label: 'Investimento Mensal em CAC / Anúncios',
                        value: _cacSpend,
                        displayValue: _formatCurrency(_cacSpend),
                        min: 0.0,
                        max: 10000.0,
                        divisions: 20,
                        onChanged: (v) {
                          setState(() => _cacSpend = v);
                          _runRunwaySimulation();
                        },
                      ),
                    ],
                  );

                  final col2 = Column(
                    children: [
                      _buildSliderField(
                        label: 'Crescimento Mensal de Treinadores (%)',
                        value: _trainerGrowthPct,
                        displayValue: '${_trainerGrowthPct.toStringAsFixed(1)}% / mês',
                        min: 2.0,
                        max: 30.0,
                        divisions: 28,
                        onChanged: (v) {
                          setState(() => _trainerGrowthPct = v);
                          _runRunwaySimulation();
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildSliderField(
                        label: 'Taxa de Churn Mensal de Treinadores (%)',
                        value: _churnPct,
                        displayValue: '${_churnPct.toStringAsFixed(1)}% / mês',
                        min: 0.5,
                        max: 10.0,
                        divisions: 19,
                        onChanged: (v) {
                          setState(() => _churnPct = v);
                          _runRunwaySimulation();
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildSliderField(
                        label: 'CAC Unitário por Treinador Adquirido',
                        value: _cacPerTrainer,
                        displayValue: _formatCurrency(_cacPerTrainer),
                        min: 50.0,
                        max: 300.0,
                        divisions: 25,
                        onChanged: (v) {
                          setState(() => _cacPerTrainer = v);
                          _runRunwaySimulation();
                        },
                      ),
                    ],
                  );

                  return isWide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: col1),
                            const SizedBox(width: 24),
                            Expanded(child: col2),
                          ],
                        )
                      : Column(children: [col1, const SizedBox(height: 12), col2]);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // 3. Tabela de Projeção Mês a Mês (M1 a M12)
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1F2937), width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text(
                    'Fluxo de Caixa Projetado Mês a Mês (Horizonte 12 Meses)',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Valores em R\$ Reais',
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  horizontalMargin: 12,
                  columnSpacing: 20,
                  headingRowColor: WidgetStateProperty.all(const Color(0xFF090D16)),
                  dataRowColor: WidgetStateProperty.resolveWith(
                    (states) => const Color(0xFF111827),
                  ),
                  columns: const [
                    DataColumn(label: Text('Mês', style: TextStyle(color: Color(0xFF818CF8), fontWeight: FontWeight.bold, fontSize: 12))),
                    DataColumn(label: Text('Personals', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12))),
                    DataColumn(label: Text('Alunos Totais', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12))),
                    DataColumn(label: Text('Receita Bruta (SaaS + 5%)', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 12))),
                    DataColumn(label: Text('Custos & OPEX', style: TextStyle(color: Color(0xFFF87171), fontWeight: FontWeight.bold, fontSize: 12))),
                    DataColumn(label: Text('Fluxo Líquido Mensal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                    DataColumn(label: Text('Saldo de Caixa Final', style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 12))),
                    DataColumn(label: Text('Status', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12))),
                  ],
                  rows: _runwayResult!.forecastMonths.map((m) {
                    final isPositive = m.netCashflow >= 0;
                    return DataRow(
                      cells: [
                        DataCell(Text(m.monthLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                        DataCell(Text('${m.trainersCount}', style: const TextStyle(color: Colors.white, fontSize: 12))),
                        DataCell(Text('${m.studentsCount}', style: const TextStyle(color: Colors.white70, fontSize: 12))),
                        DataCell(Text(_formatCurrency(m.totalRevenue), style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w600, fontSize: 12))),
                        DataCell(Text(_formatCurrency(m.totalExpenses), style: const TextStyle(color: Color(0xFFF87171), fontSize: 12))),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isPositive ? const Color(0xFF10B981).withValues(alpha: 0.15) : Colors.redAccent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${isPositive ? "+" : ""}${_formatCurrency(m.netCashflow)}',
                              style: TextStyle(
                                color: isPositive ? const Color(0xFF10B981) : Colors.redAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                        DataCell(Text(_formatCurrency(m.endCashBalance), style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 12))),
                        DataCell(
                          isPositive
                              ? const Text('🟢 POSITIVO', style: TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold))
                              : const Text('🔴 QUEIMA', style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // 4. Diagnóstico Executivo de Sustentabilidade (Investor Ready)
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF334155), width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.workspace_premium_rounded, color: Color(0xFFF59E0B), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Diagnóstico Executivo de Runway & Alocação de Capital',
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                s.isDefaultAlive
                    ? '✅ A empresa está classificada como DEFAULT ALIVE: o crescimento orgânico e a receita recorrente (SaaS + take-rate de 5% sobre o GMV) superam os custos de servidores de IA Gemini, Meta Cloud WhatsApp e OPEX logo no início. O caixa permanece em expansão contínua sem necessidade iminente de rodadas externas de diluição.'
                    : '⚠️ A empresa necessita de acompanhamento de runway de curto prazo (${s.runwayMonths.toStringAsFixed(1)} meses). Recomenda-se otimizar custos de aquisição ou focar na conversão de planos Pro para Studio VIP para antecipar o breakeven.',
                style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12, height: 1.5),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildDiagPill('Margem Contribuição: > 92%', const Color(0xFF10B981)),
                  _buildDiagPill('Payback CAC: < 1 Mês', const Color(0xFF38BDF8)),
                  _buildDiagPill('Infraestrutura Gemini: Zero-Cost Barometer', const Color(0xFF818CF8)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDiagPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildRunwayKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1F2937), width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white60, fontSize: 11)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliderField({
    required String label,
    required double value,
    required String displayValue,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ),
            const SizedBox(width: 8),
            Text(
              displayValue,
              style: const TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: const Color(0xFF10B981),
            inactiveTrackColor: const Color(0xFF1F2937),
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
    );
  }

  // ============================================================================
  // COMPONENTES AUXILIARES
  // ============================================================================

  Widget _buildKpiCard(String title, String value, IconData icon, Color color, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilterChip(String value, String label, {Color? color}) {
    final isSelected = _statusFilter == value;
    final chipColor = color ?? const Color(0xFF818CF8);

    return InkWell(
      onTap: () {
        setState(() => _statusFilter = value);
        _loadTransactions();
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? chipColor.withValues(alpha: 0.2) : const Color(0xFF090D16),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? chipColor : const Color(0xFF1F2937),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white60,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionCard(AdminTransaction tx) {
    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    if (tx.isPaid) {
      statusColor = MetaColors.emerald;
      statusLabel = 'PAGO';
      statusIcon = Icons.check_circle_rounded;
    } else if (tx.isPending) {
      statusColor = Colors.amber;
      statusLabel = 'PENDENTE';
      statusIcon = Icons.schedule_rounded;
    } else {
      statusColor = Colors.redAccent;
      statusLabel = 'FALHA';
      statusIcon = Icons.error_outline_rounded;
    }

    return InkWell(
      onTap: () => _showTransactionDetails(tx),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF1F2937)),
        ),
        child: Row(
          children: [
            // Ícone do Método de Pagamento
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF090D16),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF1F2937)),
              ),
              child: Icon(
                tx.paymentMethod == 'pix' ? Icons.pix_rounded : Icons.credit_card_rounded,
                color: const Color(0xFF818CF8),
                size: 20,
              ),
            ),
            const SizedBox(width: 14),

            // Informações do Treinador e Plano
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        tx.trainerName,
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          tx.planName,
                          style: const TextStyle(color: Color(0xFF818CF8), fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        _formatDateTime(tx.createdAt),
                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                      const SizedBox(width: 8),
                      // Split pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF090D16),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFF1F2937)),
                        ),
                        child: Text(
                          'Split 5%: ${_formatCurrency(tx.platformFeeReais)}',
                          style: const TextStyle(color: Color(0xFF818CF8), fontSize: 10, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Valor & Status
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatCurrency(tx.amountReais),
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, color: statusColor, size: 10),
                      const SizedBox(width: 4),
                      Text(
                        statusLabel,
                        style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
