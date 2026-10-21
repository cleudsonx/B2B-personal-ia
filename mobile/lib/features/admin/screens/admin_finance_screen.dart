import 'package:flutter/material.dart';
import '../../../core/widgets/meta_components.dart';
import '../services/admin_data_service.dart';

/// Módulo 3: Faturamento, Split & GMV (Take-rate 5% da Plataforma)
class AdminFinanceScreen extends StatefulWidget {
  const AdminFinanceScreen({super.key});

  @override
  State<AdminFinanceScreen> createState() => _AdminFinanceScreenState();
}

class _AdminFinanceScreenState extends State<AdminFinanceScreen> {
  final TextEditingController _searchCtrl = TextEditingController();

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

  @override
  void initState() {
    super.initState();
    _loadTransactions();
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
        onRefresh: _loadTransactions,
        color: const Color(0xFF6366F1),
        backgroundColor: const Color(0xFF111827),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header do Módulo
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Row(
                        children: [
                          Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF818CF8), size: 24),
                          SizedBox(width: 10),
                          Text(
                            'Faturamento & Split de Pagamentos',
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
                        'Auditoria de transações Asaas/Pix, repasses e split automático de 5% da plataforma',
                        style: TextStyle(color: Colors.white60, fontSize: 13),
                      ),
                    ],
                  ),
                  OutlinedButton.icon(
                    onPressed: _loadTransactions,
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
              const SizedBox(height: 24),

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
                    const SizedBox(height: 14),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('all', 'Todas as Transações', _transactions.length),
                          const SizedBox(width: 8),
                          _buildFilterChip('paid', 'Liquidadas (Pagas)', _paidCount, color: MetaColors.emerald),
                          const SizedBox(width: 8),
                          _buildFilterChip('pending', 'Pendentes (Aguardando)', _pendingCount, color: Colors.amber),
                          const SizedBox(width: 8),
                          _buildFilterChip('failed', 'Falhas / Canceladas', _failedCount, color: Colors.redAccent),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

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
                      Icon(Icons.receipt_long_outlined, size: 48, color: Colors.white24),
                      SizedBox(height: 12),
                      Text(
                        'Nenhuma transação encontrada com os filtros selecionados',
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
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final tx = _transactions[index];
                    return _buildTransactionCard(tx);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKpiCard(String title, String value, IconData icon, Color color, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(18),
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
              Text(title, style: const TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.w600)),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label, int count, {Color? color}) {
    final isSelected = _statusFilter == key;
    final activeColor = color ?? const Color(0xFF818CF8);

    return InkWell(
      onTap: () {
        setState(() => _statusFilter = key);
        _loadTransactions();
      },
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.2) : const Color(0xFF090D16),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? activeColor : const Color(0xFF1F2937),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white60,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? activeColor : const Color(0xFF1F2937),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white60,
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
      statusIcon = Icons.access_time_filled_rounded;
    } else {
      statusColor = Colors.redAccent;
      statusLabel = 'FALHA';
      statusIcon = Icons.cancel_rounded;
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
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF1F2937)),
              ),
              child: Icon(
                tx.paymentMethod == 'pix' ? Icons.qr_code_2_rounded : Icons.credit_card_rounded,
                color: tx.paymentMethod == 'pix' ? MetaColors.emerald : const Color(0xFF818CF8),
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
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
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
                        '${tx.id} • ${_formatDateTime(tx.createdAt)}',
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
