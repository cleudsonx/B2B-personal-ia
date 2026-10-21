import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/widgets/meta_components.dart';
import '../services/admin_data_service.dart';

class AdminSimulatorExportModal extends StatelessWidget {
  final AdminUnitEconomicsOverview overview;
  final AdminPricingSimulationResult? simulation;

  const AdminSimulatorExportModal({
    super.key,
    required this.overview,
    this.simulation,
  });

  static Future<void> show(
    BuildContext context, {
    required AdminUnitEconomicsOverview overview,
    AdminPricingSimulationResult? simulation,
  }) {
    return showDialog(
      context: context,
      builder: (_) => AdminSimulatorExportModal(
        overview: overview,
        simulation: simulation,
      ),
    );
  }

  String _formatBrl(double val) =>
      'R\$ ${val.toStringAsFixed(2).replaceAll('.', ',')}';

  String _generateCsv() {
    final buffer = StringBuffer();
    // UTF-8 BOM para garantir compatibilidade nativa com Excel no Windows
    buffer.write('\uFEFF');

    final now = DateTime.now();
    final dateStr =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    buffer.writeln('# ============================================================================');
    buffer.writeln('# MR. COACH / SHAIPADOS - RELATÓRIO EXECUTIVO DE UNIT ECONOMICS & SIMULAÇÃO SAAS');
    buffer.writeln('# Data de Extração: $dateStr | Versão do Sistema: 1.9.0');
    buffer.writeln('# ============================================================================');
    buffer.writeln('');

    // SEÇÃO 1: PANORAMA GLOBAL
    buffer.writeln('# SEÇÃO 1: PANORAMA GLOBAL ATUAL (UNIT ECONOMICS)');
    buffer.writeln('Métrica;Valor');
    buffer.writeln('Treinadores Totais Cadastrados;${overview.totalTrainers}');
    buffer.writeln('Treinadores Pagantes;${overview.payingTrainers}');
    buffer.writeln('Alunos Ativos Conectados;${overview.totalStudentsActive}');
    buffer.writeln('MRR Assinaturas SaaS;${_formatBrl(overview.mrrSubscriptions)}');
    buffer.writeln('MRR Split GMV (5%);${_formatBrl(overview.mrrSplitGmv)}');
    buffer.writeln('MRR Total Consolidado;${_formatBrl(overview.totalMrr)}');
    buffer.writeln('ARR Anualizado Projetado;${_formatBrl(overview.arr)}');
    buffer.writeln('COGS Gemini 2.5 Flash Lite;${_formatBrl(overview.cogsGeminiAi)}');
    buffer.writeln('COGS WhatsApp Cloud API;${_formatBrl(overview.cogsWhatsapp)}');
    buffer.writeln('COGS Gateway (Asaas/Stripe);${_formatBrl(overview.cogsGatewayFees)}');
    buffer.writeln('COGS Diretos Totais;${_formatBrl(overview.totalCogs)}');
    buffer.writeln('Lucro Líquido Mensal;${_formatBrl(overview.netMarginMonthly)}');
    buffer.writeln('Margem Líquida Consolidada;${overview.netMarginPct.toStringAsFixed(1).replaceAll('.', ',')}%');
    buffer.writeln('LTV Estimado (Lifetime Value);${_formatBrl(overview.ltvEstimated)}');
    buffer.writeln('CAC Estimado;${_formatBrl(overview.cacEstimated)}');
    buffer.writeln('LTV / CAC Ratio;${overview.ltvToCacRatio.toStringAsFixed(1).replaceAll('.', ',')}x');
    buffer.writeln('Payback Médio do CAC (Meses);${overview.paybackMonths.toStringAsFixed(1).replaceAll('.', ',')}');
    buffer.writeln('');

    // SEÇÃO 2: PROJEÇÃO DO CENÁRIO SIMULADO
    if (simulation != null) {
      final sim = simulation!;
      buffer.writeln('# SEÇÃO 2: CENÁRIO PROJETADO (SIMULAÇÃO DE PRECIFICAÇÃO)');
      buffer.writeln('Parâmetro / Indicador;Valor Projetado');
      buffer.writeln('MRR Atual Base;${_formatBrl(sim.currentMrr)}');
      buffer.writeln('MRR Projetado Simulado;${_formatBrl(sim.projectedMrr)}');
      buffer.writeln('Delta MRR Mensal;${(sim.deltaMrr >= 0 ? '+' : '')}${_formatBrl(sim.deltaMrr)}');
      buffer.writeln('Variação MRR (%);${(sim.deltaMrr >= 0 ? '+' : '')}${sim.deltaMrrPct.toStringAsFixed(1).replaceAll('.', ',')}%');
      buffer.writeln('Nova Margem Líquida (%);${sim.projectedNetMarginPct.toStringAsFixed(1).replaceAll('.', ',')}%');
      buffer.writeln('Impacto Lucro Líquido Anual;${(sim.deltaAnnualNetProfit >= 0 ? '+' : '')}${_formatBrl(sim.deltaAnnualNetProfit)}');
      buffer.writeln('Base Simulada (Treinadores);${sim.projectedTrainers}');
      buffer.writeln('Base Simulada (Alunos);${sim.projectedStudents}');
      buffer.writeln('COGS Gemini AI Projetado;${_formatBrl(sim.cogsBreakdown['gemini_ai'] ?? 0.0)}');
      buffer.writeln('COGS WhatsApp Projetado;${_formatBrl(sim.cogsBreakdown['whatsapp'] ?? 0.0)}');
      buffer.writeln('COGS Gateway Projetado;${_formatBrl(sim.cogsBreakdown['gateway'] ?? 0.0)}');
      buffer.writeln('COGS Total Projetado;${_formatBrl(sim.cogsBreakdown['total'] ?? 0.0)}');
      buffer.writeln('');
    }

    // SEÇÃO 3: MATRIZ DE TIERS
    buffer.writeln('# SEÇÃO 3: MATRIZ DE TIERS DE ASSINATURA');
    buffer.writeln('Tier;Personals;Alunos;Preço Base;MRR Planos;MRR Split (5%);COGS IA;Margem Líquida;Margem %');
    for (final t in overview.tierEconomics) {
      final priceStr = t.price > 0 ? _formatBrl(t.price) : 'Gratuito';
      buffer.writeln(
          '${t.tier};${t.trainers};${t.studentsTotal};$priceStr;${_formatBrl(t.mrrSubs)};${_formatBrl(t.mrrSplit)};${_formatBrl(t.cogsAi)};${_formatBrl(t.netMargin)};${t.marginPct.toStringAsFixed(1).replaceAll('.', ',')}%');
    }
    buffer.writeln('');

    // SEÇÃO 4: TOP HIGH-VALUE ACCOUNTS
    buffer.writeln('# SEÇÃO 4: TOP HIGH-VALUE ACCOUNTS (RANKING DE PERSONALS)');
    buffer.writeln('ID;Personal / Assessoria;Plano;Alunos;GMV Alunos;Receita Plataforma;Custo IA + WA;Margem Líquida;Margem %');
    for (final trn in overview.topTrainerEconomics) {
      buffer.writeln(
          '${trn.trainerId};${trn.trainerName};${trn.planId.toUpperCase()};${trn.studentsCount};${_formatBrl(trn.gmv)};${_formatBrl(trn.platformRevenue)};${_formatBrl(trn.cogsTotal)};${_formatBrl(trn.netMargin)};${trn.netMarginPct.toStringAsFixed(1).replaceAll('.', ',')}%');
    }

    return buffer.toString();
  }

  String _generateMarkdownReport() {
    final now = DateTime.now();
    final dateStr =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

    final sim = simulation;
    final deltaMrrStr = sim != null
        ? '${sim.deltaMrr >= 0 ? '+' : ''}${_formatBrl(sim.deltaMrr)}/mês (${sim.deltaMrrPct.toStringAsFixed(1)}%)'
        : 'N/A';
    final deltaAnnualStr = sim != null
        ? '${sim.deltaAnnualNetProfit >= 0 ? '+' : ''}${_formatBrl(sim.deltaAnnualNetProfit)}/ano'
        : 'N/A';
    final projMrrStr = sim != null ? _formatBrl(sim.projectedMrr) : _formatBrl(overview.totalMrr);
    final projMarginStr = sim != null
        ? '${sim.projectedNetMarginPct.toStringAsFixed(1)}%'
        : '${overview.netMarginPct.toStringAsFixed(1)}%';

    return '''# 📊 MR. COACH / SHAIPADOS — RELATÓRIO EXECUTIVO DE UNIT ECONOMICS & SAAS PRICING
*Data de Emissão: $dateStr | Plataforma SaaS B2B para Personal Trainers*

---

## 🎯 1. Destaques Financeiros Consolidados (Executive Highlights)

| Métrica Chave | Valor Atual | Cenário Simulado | Variação / Delta |
|:---|:---:|:---:|:---:|
| **MRR Total** | ${_formatBrl(overview.totalMrr)} | $projMrrStr | **$deltaMrrStr** |
| **ARR Projetado** | ${_formatBrl(overview.arr)} | ${_formatBrl((sim?.projectedMrr ?? overview.totalMrr) * 12.0)} | **$deltaAnnualStr** |
| **Margem Líquida** | ${overview.netMarginPct.toStringAsFixed(1)}% | $projMarginStr | Altíssima Eficiência (>95%) |
| **Lucro Líquido Mensal** | ${_formatBrl(overview.netMarginMonthly)} | ${_formatBrl((sim?.projectedMrr ?? overview.totalMrr) - (sim?.cogsBreakdown['total'] ?? overview.totalCogs))} | Escala Pura |
| **LTV / CAC Ratio** | **${overview.ltvToCacRatio.toStringAsFixed(1)}x** | Benchmark Saudável | LTV ${_formatBrl(overview.ltvEstimated)} / CAC ${_formatBrl(overview.cacEstimated)} |
| **Payback do CAC** | **${overview.paybackMonths.toStringAsFixed(1)} meses** | Retorno Ultra Rápido | ARPU Alto + Churn Mínimo |

---

## 💎 2. Matriz de Unit Economics por Tier de Assinatura

| Tier | Treinadores | Alunos | Preço Base | MRR Assinaturas | MRR Split GMV (5%) | Custo IA (COGS) | Margem Líquida | Margem % |
|:---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
${overview.tierEconomics.map((t) => '| **${t.tier}** | ${t.trainers} | ${t.studentsTotal} | ${t.price > 0 ? _formatBrl(t.price) : 'Gratuito'} | ${_formatBrl(t.mrrSubs)} | ${_formatBrl(t.mrrSplit)} | ${_formatBrl(t.cogsAi)} | **${_formatBrl(t.netMargin)}** | **${t.marginPct.toStringAsFixed(1)}%** |').join('\n')}

---

## ⚡ 3. Estrutura de COGS & Vantagem Competitiva Zero-Cost

A plataforma combina a arquitetura **Zero-Cost Local First** com o modelo **Google Gemini 2.5 Flash Lite** e a **Meta Cloud API oficial do WhatsApp**:
- **Custo Médio de IA por Aluno:** ~R\$ 0,018/mês (90% das consultas tratadas via rotas instantâneas sem chamada de LLM).
- **Custo WhatsApp por Aluno Ativo:** ~R\$ 0,052/mês por janela de sessão.
- **Margem de Contribuição Consolidada:** **${overview.netMarginPct.toStringAsFixed(1)}%**, viabilizando crescimento sustentável e fluxo de caixa positivo.

---
*Relatório gerado automaticamente pelo Mission Control Admin do Mr. Coach.*
''';
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
              content: Text('Planilha CSV copiada para a área de transferência! Cole no seu Excel ou Google Sheets.'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Download do relatório CSV iniciado com sucesso!'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: csvContent));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Planilha CSV copiada para a área de transferência! Cole no seu Excel ou Google Sheets.'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    }
  }

  Future<void> _copyMarkdown(BuildContext context) async {
    final md = _generateMarkdownReport();
    await Clipboard.setData(ClipboardData(text: md));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Relatório Pitch Deck (Markdown) copiado com sucesso!'),
          backgroundColor: Color(0xFF6366F1),
        ),
      );
    }
  }

  Future<void> _copyCsv(BuildContext context) async {
    final csvContent = _generateCsv();
    await Clipboard.setData(ClipboardData(text: csvContent));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Conteúdo CSV copiado para a área de transferência!'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = MetaColors.isDark(context);
    final cardBg = isDark ? const Color(0xFF111827) : Colors.white;
    final borderColor = isDark ? const Color(0xFF1F2937) : const Color(0xFFE5E7EB);
    final textPrimary = isDark ? Colors.white : const Color(0xFF111827);
    final textSecondary = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    final sim = simulation;
    final isPositive = (sim?.deltaMrr ?? 0) >= 0;
    final deltaColor = isPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return Dialog(
      backgroundColor: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: borderColor),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                          ),
                          child: const Icon(
                            Icons.analytics_rounded,
                            color: Color(0xFF10B981),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Exportação Executiva & Pitch Deck',
                                style: TextStyle(
                                  color: textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Unit Economics, Projeções de MRR e Margem Líquida',
                                style: TextStyle(color: textSecondary, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded, color: textSecondary, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Mini Cards de Resumo Executivo
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: borderColor.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'MRR CONSOLIDADO',
                            style: TextStyle(color: textSecondary, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatBrl(overview.totalMrr),
                            style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Margem: ${overview.netMarginPct.toStringAsFixed(1)}%',
                            style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    Container(height: 40, width: 1, color: borderColor),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PROJETADO SIMULADO',
                            style: TextStyle(color: textSecondary, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            sim != null ? _formatBrl(sim.projectedMrr) : _formatBrl(overview.totalMrr),
                            style: TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            sim != null
                                ? 'Delta: ${(sim.deltaMrr >= 0 ? '+' : '')}${_formatBrl(sim.deltaMrr)}/mês'
                                : 'Sem variação',
                            style: TextStyle(color: deltaColor, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              Text(
                'Escolha o formato ideal para apresentação com investidores ou análise em planilhas:',
                style: TextStyle(color: textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 20),

              // Botões de Ação
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _downloadCsv(context),
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: const Text(
                        'Baixar CSV (Excel)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _copyMarkdown(context),
                      icon: const Icon(Icons.copy_rounded, size: 18, color: Color(0xFF6366F1)),
                      label: const Text(
                        'Copiar Pitch Deck',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF6366F1)),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF6366F1), width: 1.2),
                        backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.08),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton.icon(
                  onPressed: () => _copyCsv(context),
                  icon: const Icon(Icons.content_copy_rounded, size: 16),
                  label: const Text('Copiar CSV em Texto Bruto', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(foregroundColor: textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
