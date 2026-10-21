import 'package:flutter/material.dart';
import '../../../core/widgets/meta_components.dart';
import '../services/admin_data_service.dart';

class AdminAiUsageScreen extends StatefulWidget {
  const AdminAiUsageScreen({super.key});

  @override
  State<AdminAiUsageScreen> createState() => _AdminAiUsageScreenState();
}

class _AdminAiUsageScreenState extends State<AdminAiUsageScreen> {
  bool _isLoading = true;
  AdminAiUsageOverview _overview = const AdminAiUsageOverview(
    totalTokens: 0,
    promptTokens: 0,
    completionTokens: 0,
    estimatedCostUsd: 0,
    estimatedCostBrl: 0,
    zeroCostCommandsExecuted: 0,
    geminiCallsExecuted: 0,
    zeroCostRatio: 0.85,
    estimatedSavingsUsd: 0,
    estimatedSavingsBrl: 0,
    period: 'current_month',
    modelsBreakdown: [],
    trainers: [],
  );

  String _searchQuery = '';
  String _selectedPlan = 'all';

  @override
  void initState() {
    super.initState();
    _loadAiUsage();
  }

  Future<void> _loadAiUsage() async {
    setState(() => _isLoading = true);
    final data = await AdminDataService.getAiUsageOverview(
      searchQuery: _searchQuery,
      planFilter: _selectedPlan,
    );
    if (!mounted) return;
    setState(() {
      _overview = data;
      _isLoading = false;
    });
  }

  void _onSearchChanged(String value) {
    _searchQuery = value;
    _loadAiUsage();
  }

  void _onPlanChanged(String plan) {
    setState(() => _selectedPlan = plan);
    _loadAiUsage();
  }

  Future<void> _showAdjustQuotaDialog(AdminTrainerAiConsumption trainer) async {
    final controller = TextEditingController(
      text: trainer.isUnlimited ? '-1' : trainer.monthlyQuota.toString(),
    );

    final result = await showDialog<int>(
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
              const Icon(Icons.tune_rounded, color: Color(0xFF818CF8), size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Ajustar Cota IA: ${trainer.trainerName}',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Plano Atual: ${trainer.plan} • Gerações Usadas no Mês: ${trainer.usedGenerations}',
                style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
              ),
              const SizedBox(height: 16),
              const Text(
                'Cota Mensal de Gerações:',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Ex: 150 (ou -1 para Ilimitado)',
                  hintStyle: const TextStyle(color: Color(0xFF6B7280)),
                  filled: true,
                  fillColor: const Color(0xFF1F2937),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF374151)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '💡 Dica: Digite -1 para liberar acesso ilimitado de IA para este treinador.',
                style: TextStyle(color: Color(0xFF818CF8), fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                final val = int.tryParse(controller.text.trim());
                if (val != null) {
                  Navigator.pop(ctx, val);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Salvar Cota'),
            ),
          ],
        );
      },
    );

    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Atualizando cota de ${trainer.trainerName} para $result...'),
          duration: const Duration(seconds: 2),
        ),
      );

      final res = await AdminDataService.adjustTrainerAiQuota(
        trainerId: trainer.trainerId,
        customMonthlyQuota: result,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message']?.toString() ?? 'Cota atualizada com sucesso!'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        _loadAiUsage();
      }
    }
  }

  Future<void> _notifyQuotaRisk(AdminTrainerAiConsumption trainer) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF1F2937)),
        ),
        title: const Row(
          children: [
            Icon(Icons.mark_chat_unread_rounded, color: Color(0xFF10B981), size: 22),
            SizedBox(width: 10),
            Text(
              'Alerta de Cota via WhatsApp',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Deseja enviar um alerta proativo no WhatsApp de ${trainer.trainerName} informando que '
          'ele consumiu ${trainer.usagePercent.toStringAsFixed(0)}% da cota mensal (${trainer.usedGenerations}/${trainer.monthlyQuota} fichas) '
          'e orientando o upgrade de plano?',
          style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Enviar WhatsApp'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Enviando alerta para ${trainer.trainerName}...'),
          duration: const Duration(seconds: 2),
        ),
      );

      final res = await AdminDataService.notifyTrainerAiQuotaRisk(
        trainerId: trainer.trainerId,
        trainerName: trainer.trainerName,
        usagePercent: trainer.usagePercent,
        usedGenerations: trainer.usedGenerations,
        monthlyQuota: trainer.monthlyQuota,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message']?.toString() ?? 'Alerta enviado!'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    }
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
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
          : RefreshIndicator(
              onRefresh: _loadAiUsage,
              color: const Color(0xFF6366F1),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    _buildHeader(textPrimary, textSecondary),
                    const SizedBox(height: 24),

                    // KPIs
                    _buildKpis(cardBg, borderColor, textPrimary, textSecondary),
                    const SizedBox(height: 24),

                    // Barômetro de Eficiência (Zero-Cost vs Gemini)
                    _buildEfficiencyBarometer(cardBg, borderColor, textPrimary, textSecondary),
                    const SizedBox(height: 24),

                    // Model Breakdown Cards
                    _buildModelBreakdown(cardBg, borderColor, textPrimary, textSecondary),
                    const SizedBox(height: 28),

                    // Tabela de Consumo por Treinador
                    _buildTrainersSection(cardBg, borderColor, textPrimary, textSecondary),
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
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
              ),
              child: const Icon(
                Icons.psychology_rounded,
                color: Color(0xFF818CF8),
                size: 26,
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Inteligência & Custos de IA',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Auditoria de tokens Gemini 2.5, eficiência Zero-Cost e cotas por treinador',
                  style: TextStyle(
                    fontSize: 13,
                    color: textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
        IconButton(
          onPressed: _loadAiUsage,
          icon: const Icon(Icons.refresh_rounded, color: Color(0xFF818CF8)),
          tooltip: 'Atualizar Telemetria',
        ),
      ],
    );
  }

  Widget _buildKpis(Color cardBg, Color borderColor, Color textPrimary, Color textSecondary) {
    final tokensStr = _overview.totalTokens >= 1000000
        ? '${(_overview.totalTokens / 1000000).toStringAsFixed(2)}M'
        : '${(_overview.totalTokens / 1000).toStringAsFixed(1)}k';

    final promptStr = '${(_overview.promptTokens / 1000).toStringAsFixed(0)}k in';
    final compStr = '${(_overview.completionTokens / 1000).toStringAsFixed(0)}k out';

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 800;
        final cardWidth = isDesktop ? (constraints.maxWidth - 36) / 4 : (constraints.maxWidth - 12) / 2;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: cardWidth,
              child: _buildKpiCard(
                title: 'TOKENS GEMINI',
                value: tokensStr,
                subtext: '$promptStr • $compStr',
                icon: Icons.data_usage_rounded,
                iconColor: const Color(0xFF6366F1),
                cardBg: cardBg,
                borderColor: borderColor,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildKpiCard(
                title: 'CUSTO ESTIMADO',
                value: 'R\$ ${_overview.estimatedCostBrl.toStringAsFixed(2)}',
                subtext: 'US\$ ${_overview.estimatedCostUsd.toStringAsFixed(3)} (Flash 2.5)',
                icon: Icons.monetization_on_rounded,
                iconColor: const Color(0xFF10B981),
                cardBg: cardBg,
                borderColor: borderColor,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildKpiCard(
                title: 'COMANDOS ZERO-COST',
                value: _overview.zeroCostCommandsExecuted.toString(),
                subtext: '${_overview.efficiencyPercentage.toStringAsFixed(1)}% a custo zero',
                icon: Icons.bolt_rounded,
                iconColor: const Color(0xFFF59E0B),
                cardBg: cardBg,
                borderColor: borderColor,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildKpiCard(
                title: 'ECONOMIA GERADA',
                value: 'R\$ ${_overview.estimatedSavingsBrl.toStringAsFixed(2)}',
                subtext: 'US\$ ${_overview.estimatedSavingsUsd.toStringAsFixed(2)} poupados',
                icon: Icons.savings_rounded,
                iconColor: const Color(0xFF3B82F6),
                cardBg: cardBg,
                borderColor: borderColor,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
            ),
          ],
        );
      },
    );
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
      padding: const EdgeInsets.all(16),
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
              Text(
                title,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                  color: textSecondary,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: iconColor),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
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
    );
  }

  Widget _buildEfficiencyBarometer(
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    final zeroCostPct = _overview.efficiencyPercentage;
    final geminiPct = 100.0 - zeroCostPct;

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
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.speed_rounded, color: Color(0xFF10B981), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Barômetro de Eficiência de IA (Arquitetura Custo Zero)',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                ),
                child: Text(
                  '${zeroCostPct.toStringAsFixed(1)}% EFICIÊNCIA NATIVA',
                  style: const TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Comandos 1 a 5 (Treino Hoje, Próximo Treino, Cargas, Ficha e Notificar Personal) são atendidos diretamente via Supabase e cache, sem gastar tokens de LLM.',
            style: TextStyle(fontSize: 12, color: textSecondary),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 14,
              child: Row(
                children: [
                  Expanded(
                    flex: zeroCostPct.round().clamp(1, 100),
                    child: Container(color: const Color(0xFF10B981)),
                  ),
                  Expanded(
                    flex: geminiPct.round().clamp(1, 100),
                    child: Container(color: const Color(0xFF6366F1)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 16,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text(
                    'Zero-Cost Nativos: ${_overview.zeroCostCommandsExecuted} reqs (${zeroCostPct.toStringAsFixed(1)}%)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSecondary),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFF6366F1), shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text(
                    'Chamadas Gemini LLM: ${_overview.geminiCallsExecuted} reqs (${geminiPct.toStringAsFixed(1)}%)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSecondary),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModelBreakdown(Color cardBg, Color borderColor, Color textPrimary, Color textSecondary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Modelos Google Gemini em Operação',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth > 700;
            return Flex(
              direction: isDesktop ? Axis.horizontal : Axis.vertical,
              children: _overview.modelsBreakdown.map((m) {
                final child = Container(
                  margin: EdgeInsets.only(
                    right: isDesktop ? 12 : 0,
                    bottom: isDesktop ? 0 : 12,
                  ),
                  padding: const EdgeInsets.all(16),
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
                          Text(
                            m.modelName,
                            style: const TextStyle(
                              color: Color(0xFF818CF8),
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${m.sharePercent.toStringAsFixed(1)}% vol',
                              style: const TextStyle(
                                color: Color(0xFF818CF8),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(m.purpose, style: TextStyle(fontSize: 12, color: textSecondary)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          Text('Tokens: ${(m.tokens / 1000).toStringAsFixed(0)}k', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary)),
                          Text('Chamadas: ${m.calls}', style: TextStyle(fontSize: 12, color: textSecondary)),
                          Text('R\$ ${m.costBrl.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                        ],
                      ),
                    ],
                  ),
                );
                return isDesktop ? Expanded(child: child) : child;
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTrainersSection(Color cardBg, Color borderColor, Color textPrimary, Color textSecondary) {
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
              Text(
                'Consumo de IA e Cotas por Treinador (${_overview.trainers.length})',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Builder(
            builder: (context) {
              final atRiskTrainers = _overview.trainers.where((t) => t.isNearLimit || t.isOverLimit).toList();
              if (atRiskTrainers.isEmpty) return const SizedBox.shrink();

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${atRiskTrainers.length} personal(s) atingiram >=80% da cota mensal de IA. Toque no ícone do WhatsApp para disparar o aviso de upgrade.',
                        style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // Filtros e Busca
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: _onSearchChanged,
                  style: TextStyle(color: textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Buscar por personal, e-mail ou plano...',
                    hintStyle: TextStyle(color: textSecondary, fontSize: 13),
                    prefixIcon: Icon(Icons.search_rounded, color: textSecondary, size: 18),
                    filled: true,
                    fillColor: MetaColors.isDark(context) ? const Color(0xFF1F2937) : const Color(0xFFF3F4F6),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Wrap(
                spacing: 6,
                children: [
                  _buildFilterChip('all', 'Todos'),
                  _buildFilterChip('studio', 'Studio'),
                  _buildFilterChip('elite', 'Elite'),
                  _buildFilterChip('pro', 'Pro'),
                  _buildFilterChip('starter', 'Starter'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Lista de Treinadores
          if (_overview.trainers.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text('Nenhum treinador encontrado com os filtros atuais.', style: TextStyle(color: textSecondary)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _overview.trainers.length,
              separatorBuilder: (context, index) => Divider(color: borderColor, height: 20),
              itemBuilder: (context, index) {
                final t = _overview.trainers[index];
                return _buildTrainerRow(t, textPrimary, textSecondary, borderColor);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedPlan == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => _onPlanChanged(value),
      selectedColor: const Color(0xFF6366F1),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: isSelected ? Colors.white : Colors.grey,
      ),
      backgroundColor: MetaColors.isDark(context) ? const Color(0xFF1F2937) : const Color(0xFFF3F4F6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      side: BorderSide.none,
    );
  }

  Widget _buildTrainerRow(
    AdminTrainerAiConsumption trainer,
    Color textPrimary,
    Color textSecondary,
    Color borderColor,
  ) {
    final quotaText = trainer.isUnlimited ? 'Ilimitado' : '${trainer.usedGenerations}/${trainer.monthlyQuota} fichas';
    final pctColor = trainer.isOverLimit
        ? Colors.redAccent
        : (trainer.isNearLimit ? Colors.orangeAccent : const Color(0xFF10B981));

    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.2),
          child: Text(
            trainer.trainerName.isNotEmpty ? trainer.trainerName[0].toUpperCase() : 'P',
            style: const TextStyle(color: Color(0xFF818CF8), fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      trainer.trainerName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF818CF8).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      trainer.plan,
                      style: const TextStyle(
                        color: Color(0xFF818CF8),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                trainer.email,
                style: TextStyle(fontSize: 12, color: textSecondary),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${(trainer.tokensUsed / 1000).toStringAsFixed(1)}k tokens',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textPrimary),
              ),
              const SizedBox(height: 2),
              Text(
                'R\$ ${trainer.costBrl.toStringAsFixed(2)} • ${trainer.geminiCalls} calls',
                style: TextStyle(fontSize: 11, color: textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Cota: $quotaText',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary),
                  ),
                  if (!trainer.isUnlimited)
                    Text(
                      '${trainer.usagePercent.toStringAsFixed(0)}%',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: pctColor),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              if (!trainer.isUnlimited)
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (trainer.usagePercent / 100.0).clamp(0.0, 1.0),
                    backgroundColor: const Color(0xFF1F2937),
                    valueColor: AlwaysStoppedAnimation<Color>(pctColor),
                    minHeight: 6,
                  ),
                )
              else
                const Text('⚡ Ilimitado', style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: () => _showAdjustQuotaDialog(trainer),
          icon: const Icon(Icons.tune_rounded, size: 14, color: Color(0xFF818CF8)),
          label: const Text('Cota', style: TextStyle(fontSize: 12, color: Color(0xFF818CF8))),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFF6366F1), width: 0.8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        if (trainer.isNearLimit || trainer.isOverLimit) ...[
          const SizedBox(width: 6),
          IconButton(
            onPressed: () => _notifyQuotaRisk(trainer),
            icon: const Icon(Icons.mark_chat_unread_rounded, size: 18, color: Color(0xFF10B981)),
            tooltip: 'Alertar Cota via WhatsApp',
          ),
        ],
      ],
    );
  }
}
