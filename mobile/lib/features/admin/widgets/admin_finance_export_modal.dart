import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/widgets/meta_components.dart';
import '../services/admin_data_service.dart';

class AdminFinanceExportModal extends StatelessWidget {
  final List<AdminTransaction> transactions;

  const AdminFinanceExportModal({
    super.key,
    required this.transactions,
  });

  static Future<void> show(BuildContext context, List<AdminTransaction> transactions) {
    return showDialog(
      context: context,
      builder: (_) => AdminFinanceExportModal(transactions: transactions),
    );
  }

  String _formatCurrency(double val) =>
      'R\$ ${val.toStringAsFixed(2).replaceAll('.', ',')}';

  String _formatDate(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final y = dt.year.toString();
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$d/$m/$y $h:$min';
  }

  double get _totalGmv =>
      transactions.where((t) => t.isPaid).fold(0.0, (acc, t) => acc + t.amountReais);
  double get _totalFee => _totalGmv * 0.05;
  double get _totalNet => _totalGmv * 0.95;

  String _generateCsv() {
    final buffer = StringBuffer();
    // UTF-8 BOM para garantir compatibilidade com Excel no Windows
    buffer.write('\uFEFF');
    buffer.writeln(
        'ID Transação;Data;Treinador;E-mail;Plano;Método;Status;Valor Bruto (R\$);Split Plataforma (5% R\$);Repasse Personal (95% R\$)');

    for (final tx in transactions) {
      final id = tx.id;
      final date = _formatDate(tx.createdAt);
      final trainer = tx.trainerName.replaceAll(';', ',');
      final email = (tx.trainerEmail ?? '').replaceAll(';', ',');
      final plan = tx.planName.replaceAll(';', ',');
      final method = tx.paymentMethod.toUpperCase();
      final status = tx.status.toUpperCase();
      final bruto = tx.amountReais.toStringAsFixed(2).replaceAll('.', ',');
      final taxa = tx.platformFeeReais.toStringAsFixed(2).replaceAll('.', ',');
      final liquido = tx.trainerNetReais.toStringAsFixed(2).replaceAll('.', ',');

      buffer.writeln(
          '$id;$date;$trainer;$email;$plan;$method;$status;$bruto;$taxa;$liquido');
    }
    return buffer.toString();
  }

  String _generateTsv() {
    final buffer = StringBuffer();
    buffer.writeln(
        'ID Transação\tData\tTreinador\tE-mail\tPlano\tMétodo\tStatus\tValor Bruto\tSplit 5%\tRepasse 95%');

    for (final tx in transactions) {
      buffer.writeln(
          '${tx.id}\t${_formatDate(tx.createdAt)}\t${tx.trainerName}\t${tx.trainerEmail ?? ''}\t${tx.planName}\t${tx.paymentMethod}\t${tx.status}\t${tx.amountReais.toStringAsFixed(2)}\t${tx.platformFeeReais.toStringAsFixed(2)}\t${tx.trainerNetReais.toStringAsFixed(2)}');
    }
    return buffer.toString();
  }

  Future<void> _downloadCsv(BuildContext context) async {
    final csvContent = _generateCsv();
    final bytes = utf8.encode(csvContent);
    final base64Csv = base64Encode(bytes);
    final uri = Uri.parse('data:text/csv;charset=utf-8;base64,$base64Csv');

    try {
      final launched = await launchUrl(uri);
      if (!launched) {
        await Clipboard.setData(ClipboardData(text: csvContent));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('CSV copiado para a área de transferência! Cole no seu Excel/Sheets.'),
              backgroundColor: MetaColors.emerald,
            ),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Download do relatório CSV iniciado com sucesso!'),
              backgroundColor: MetaColors.emerald,
            ),
          );
        }
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: csvContent));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('CSV copiado para a área de transferência! Cole no seu Excel/Sheets.'),
            backgroundColor: MetaColors.emerald,
          ),
        );
      }
    }
  }

  Future<void> _copyTsv(BuildContext context) async {
    final tsv = _generateTsv();
    await Clipboard.setData(ClipboardData(text: tsv));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dados copiados em formato tabela! Cole direto no Excel ou Google Sheets (Ctrl+V).'),
          backgroundColor: Color(0xFF6366F1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF090D16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0xFF1F2937), width: 1.2),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Container(
        width: 900,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Bar
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.receipt_long_rounded,
                    color: Color(0xFF818CF8),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Relatório Contábil & Auditoria de Splits',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Exportação oficial e fechamento para faturamento e DRE',
                        style: TextStyle(color: Colors.white60, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white60),
                ),
              ],
            ),
            const Divider(color: Color(0xFF1F2937), height: 24),

            // Métricas Consolidadas do Relatório (Scroll horizontal se tela estreita)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF1F2937)),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildMetricItem(
                      'GMV Total (Faturado)',
                      _formatCurrency(_totalGmv),
                      MetaColors.emerald,
                      '${transactions.where((t) => t.isPaid).length} transações liquidadas',
                    ),
                    Container(width: 1, height: 40, color: const Color(0xFF1F2937)),
                    _buildMetricItem(
                      'Split Plataforma (5%)',
                      _formatCurrency(_totalFee),
                      const Color(0xFF818CF8),
                      'Take-rate de comissão líquida',
                    ),
                    Container(width: 1, height: 40, color: const Color(0xFF1F2937)),
                    _buildMetricItem(
                      'Repasse aos Personals (95%)',
                      _formatCurrency(_totalNet),
                      const Color(0xFF38BDF8),
                      'Saldo creditado aos profissionais',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Tabela Analítica de Transações (Scroll bidirecional)
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF1F2937)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(const Color(0xFF0F172A)),
                        horizontalMargin: 16,
                        columnSpacing: 18,
                        columns: const [
                          DataColumn(
                            label: Text('DATA',
                                style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ),
                          DataColumn(
                            label: Text('TREINADOR',
                                style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ),
                          DataColumn(
                            label: Text('PLANO',
                                style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ),
                          DataColumn(
                            label: Text('STATUS',
                                style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ),
                          DataColumn(
                            numeric: true,
                            label: Text('BRUTO (R\$)',
                                style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ),
                          DataColumn(
                            numeric: true,
                            label: Text('SPLIT 5%',
                                style: TextStyle(
                                    color: Color(0xFF818CF8),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ),
                          DataColumn(
                            numeric: true,
                            label: Text('LÍQUIDO 95%',
                                style: TextStyle(
                                    color: MetaColors.emerald,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                        rows: transactions.map((tx) {
                          return DataRow(
                            cells: [
                              DataCell(Text(
                                _formatDate(tx.createdAt),
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              )),
                              DataCell(Text(
                                tx.trainerName,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12),
                              )),
                              DataCell(Text(
                                tx.planName,
                                style: const TextStyle(color: Colors.white60, fontSize: 12),
                              )),
                              DataCell(_buildStatusBadge(tx.status)),
                              DataCell(Text(
                                _formatCurrency(tx.amountReais),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12),
                              )),
                              DataCell(Text(
                                _formatCurrency(tx.platformFeeReais),
                                style: const TextStyle(
                                    color: Color(0xFF818CF8),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12),
                              )),
                              DataCell(Text(
                                _formatCurrency(tx.trainerNetReais),
                                style: const TextStyle(
                                    color: MetaColors.emerald,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12),
                              )),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Barra Inferior de Ações de Exportação (Wrap responsivo)
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 15, color: Colors.white38),
                    const SizedBox(width: 6),
                    Text(
                      '${transactions.length} registros prontos para conciliação contábil.',
                      style: const TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _copyTsv(context),
                      icon: const Icon(Icons.copy_all_rounded, size: 16),
                      label: const Text('Copiar Tabela (Excel)',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Color(0xFF1F2937)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: () => _downloadCsv(context),
                      icon: const Icon(Icons.download_rounded, size: 17),
                      label: const Text('Baixar Relatório CSV',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MetaColors.emerald,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricItem(String label, String value, Color color, String sub) {
    return Container(
      constraints: const BoxConstraints(minWidth: 160),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white60, fontSize: 11.5, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(sub,
              style: const TextStyle(color: Colors.white38, fontSize: 10.5)),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final lower = status.toLowerCase();
    Color bg;
    Color fg;
    String label;

    if (lower == 'paid' || lower == 'approved') {
      bg = MetaColors.emerald.withValues(alpha: 0.15);
      fg = MetaColors.emerald;
      label = 'PAGO';
    } else if (lower == 'pending') {
      bg = Colors.amber.withValues(alpha: 0.15);
      fg = Colors.amber;
      label = 'PENDENTE';
    } else {
      bg = const Color(0xFFEF4444).withValues(alpha: 0.15);
      fg = const Color(0xFFEF4444);
      label = 'FALHA';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.w900),
      ),
    );
  }
}
