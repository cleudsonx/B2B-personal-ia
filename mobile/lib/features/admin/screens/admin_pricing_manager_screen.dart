import 'package:flutter/material.dart';
import '../../../core/widgets/meta_components.dart';
import '../services/admin_data_service.dart';

/// Módulo: Gestão Dinâmica de Preços & Planos SaaS
class AdminPricingManagerScreen extends StatefulWidget {
  final VoidCallback? onNavigateToSimulator;

  const AdminPricingManagerScreen({
    super.key,
    this.onNavigateToSimulator,
  });

  @override
  State<AdminPricingManagerScreen> createState() => _AdminPricingManagerScreenState();
}

class _AdminPricingManagerScreenState extends State<AdminPricingManagerScreen> {
  bool _isLoading = true;
  AdminPricingConfigOverview? _overview;

  @override
  void initState() {
    super.initState();
    _loadPricing();
  }

  Future<void> _loadPricing() async {
    setState(() => _isLoading = true);
    final data = await AdminDataService.getPricingPlansOverview();
    if (mounted) {
      setState(() {
        _overview = data;
        _isLoading = false;
      });
    }
  }

  Future<void> _togglePlanActive(AdminPricingPlanItem plan, bool newValue) async {
    final messenger = ScaffoldMessenger.of(context);
    final updated = plan.copyWith(isActive: newValue);
    final success = await AdminDataService.updatePricingPlan(updated);
    if (mounted) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            success
                ? (newValue
                    ? 'Plano ${plan.name} ativado no catálogo!'
                    : 'Plano ${plan.name} desativado temporariamente.')
                : 'Falha ao atualizar status do plano.',
          ),
          backgroundColor: newValue ? MetaColors.emerald : Colors.amber,
          duration: const Duration(seconds: 2),
        ),
      );
      _loadPricing();
    }
  }

  Future<void> _resetToDefaults() async {
    final messenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.restart_alt_rounded, color: Colors.amber),
            SizedBox(width: 8),
            Text(
              'Redefinir Planos Padrão?',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          'Deseja restaurar as configurações oficiais de fábrica (Starter R\$ 49, Pro R\$ 89, Elite R\$ 159)?\nAlterações personalizadas serão substituídas.',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Confirmar Restauração', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await AdminDataService.resetDefaultPricingPlans();
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              success ? 'Planos restaurados para os valores de fábrica!' : 'Falha ao restaurar planos.',
            ),
            backgroundColor: success ? MetaColors.emerald : Colors.redAccent,
          ),
        );
        _loadPricing();
      }
    }
  }

  Future<void> _openEditPlanDialog(AdminPricingPlanItem plan) async {
    final messenger = ScaffoldMessenger.of(context);
    final nameCtrl = TextEditingController(text: plan.name);
    final badgeCtrl = TextEditingController(text: plan.badge);
    final monthlyCtrl = TextEditingController(text: plan.priceMonthly.toStringAsFixed(2));
    final yearlyCtrl = TextEditingController(text: plan.priceYearly.toStringAsFixed(2));
    final studentLimitCtrl = TextEditingController(text: plan.studentLimit.toString());
    final splitCtrl = TextEditingController(text: plan.platformFeePercent.toStringAsFixed(1));
    final aiQuotaCtrl = TextEditingController(text: plan.aiQuotaLimit.toString());

    bool unlimitedStudents = plan.studentLimit <= 0;
    bool unlimitedAi = plan.aiQuotaLimit <= 0;
    bool hasCustomBranding = plan.hasCustomBranding;
    bool hasPrioritySupport = plan.hasPrioritySupport;
    bool isActive = plan.isActive;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF111827),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.edit_note_rounded, color: Color(0xFF818CF8), size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Editar Plano: ${plan.name}',
                      style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Nome e Badge
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: _buildModalTextField(
                              label: 'Nome do Plano',
                              controller: nameCtrl,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: _buildModalTextField(
                              label: 'Badge / Tag',
                              controller: badgeCtrl,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Preços
                      Row(
                        children: [
                          Expanded(
                            child: _buildModalTextField(
                              label: 'Preço Mensal (R\$)',
                              controller: monthlyCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildModalTextField(
                              label: 'Preço Anual (R\$)',
                              controller: yearlyCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Limite de Alunos
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF090D16),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF1F2937)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Limite de Alunos Ativos',
                                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                                Row(
                                  children: [
                                    const Text('Ilimitado', style: TextStyle(color: Colors.white60, fontSize: 12)),
                                    Switch(
                                      value: unlimitedStudents,
                                      onChanged: (val) {
                                        setModalState(() {
                                          unlimitedStudents = val;
                                          if (val) studentLimitCtrl.text = '0';
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            if (!unlimitedStudents)
                              _buildModalTextField(
                                label: 'Capacidade Máxima de Alunos',
                                controller: studentLimitCtrl,
                                keyboardType: TextInputType.number,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Taxa de Split & Cota IA
                      Row(
                        children: [
                          Expanded(
                            child: _buildModalTextField(
                              label: 'Taxa Split da Plataforma (%)',
                              controller: splitCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF090D16),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFF1F2937)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Cota IA',
                                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                      ),
                                      Switch(
                                        value: unlimitedAi,
                                        onChanged: (val) {
                                          setModalState(() {
                                            unlimitedAi = val;
                                            if (val) aiQuotaCtrl.text = '0';
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                  if (!unlimitedAi)
                                    _buildModalTextField(
                                      label: 'Gerações / Mês',
                                      controller: aiQuotaCtrl,
                                      keyboardType: TextInputType.number,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Switches de Features
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF090D16),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF1F2937)),
                        ),
                        child: Column(
                          children: [
                            _buildFeatureSwitchRow(
                              title: 'Marca Própria (White-label & Logo)',
                              subtitle: 'Permite ao personal customizar vitrine e app',
                              value: hasCustomBranding,
                              onChanged: (val) => setModalState(() => hasCustomBranding = val),
                            ),
                            const Divider(color: Color(0xFF1F2937), height: 1),
                            _buildFeatureSwitchRow(
                              title: 'Suporte Prioritário VIP',
                              subtitle: 'Atendimento dedicado via WhatsApp oficial',
                              value: hasPrioritySupport,
                              onChanged: (val) => setModalState(() => hasPrioritySupport = val),
                            ),
                            const Divider(color: Color(0xFF1F2937), height: 1),
                            _buildFeatureSwitchRow(
                              title: 'Plano Ativo no Checkout',
                              subtitle: 'Exibir este plano para novas assinaturas',
                              value: isActive,
                              onChanged: (val) => setModalState(() => isActive = val),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar', style: TextStyle(color: Colors.white60)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final monthly = double.tryParse(monthlyCtrl.text.replaceAll(',', '.')) ?? plan.priceMonthly;
                    final yearly = double.tryParse(yearlyCtrl.text.replaceAll(',', '.')) ?? plan.priceYearly;
                    final sLimit = unlimitedStudents ? 0 : (int.tryParse(studentLimitCtrl.text) ?? plan.studentLimit);
                    final split = double.tryParse(splitCtrl.text.replaceAll(',', '.')) ?? plan.platformFeePercent;
                    final aiQuota = unlimitedAi ? 0 : (int.tryParse(aiQuotaCtrl.text) ?? plan.aiQuotaLimit);

                    final updated = plan.copyWith(
                      name: nameCtrl.text.trim().isEmpty ? plan.name : nameCtrl.text.trim(),
                      badge: badgeCtrl.text.trim(),
                      priceMonthly: monthly,
                      priceYearly: yearly,
                      studentLimit: sLimit,
                      platformFeePercent: split,
                      aiQuotaLimit: aiQuota,
                      hasCustomBranding: hasCustomBranding,
                      hasPrioritySupport: hasPrioritySupport,
                      isActive: isActive,
                    );

                    Navigator.pop(ctx);
                    final success = await AdminDataService.updatePricingPlan(updated);
                    if (mounted) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(success ? 'Plano ${updated.name} atualizado!' : 'Falha ao salvar plano.'),
                          backgroundColor: success ? MetaColors.emerald : Colors.redAccent,
                        ),
                      );
                      _loadPricing();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Salvar Alterações', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildFeatureSwitchRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildModalTextField({
    required String label,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF090D16),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF1F2937)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF1F2937)),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      body: RefreshIndicator(
        onRefresh: _loadPricing,
        color: const Color(0xFF6366F1),
        backgroundColor: const Color(0xFF111827),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Principal
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.sell_rounded, color: Color(0xFF818CF8), size: 24),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Gestão de Preços & Planos SaaS',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.3,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Configure valores de assinatura, limites de alunos, split da plataforma e cotas de IA Gemini',
                          style: TextStyle(color: Colors.white60, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (widget.onNavigateToSimulator != null)
                        OutlinedButton.icon(
                          onPressed: widget.onNavigateToSimulator,
                          icon: const Icon(Icons.calculate_rounded, size: 16, color: MetaColors.emerald),
                          label: const Text('Simulador Margem', style: TextStyle(color: MetaColors.emerald, fontSize: 13)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF1F2937)),
                            backgroundColor: const Color(0xFF111827),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      OutlinedButton.icon(
                        onPressed: _resetToDefaults,
                        icon: const Icon(Icons.restart_alt_rounded, size: 16, color: Colors.amber),
                        label: const Text('Padrões', style: TextStyle(color: Colors.amber, fontSize: 13)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF1F2937)),
                          backgroundColor: const Color(0xFF111827),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _loadPricing,
                        icon: const Icon(Icons.refresh_rounded, size: 16, color: Color(0xFF818CF8)),
                        label: const Text('Atualizar', style: TextStyle(color: Color(0xFF818CF8), fontSize: 13)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF1F2937)),
                          backgroundColor: const Color(0xFF111827),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // KPI Cards
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(48),
                    child: CircularProgressIndicator(color: Color(0xFF6366F1)),
                  ),
                )
              else ...[
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isDesktop = constraints.maxWidth > 900;
                    final isTablet = constraints.maxWidth > 550 && !isDesktop;

                    final kpi1 = _buildKpiCard(
                      title: 'Planos Ativos',
                      value: '${_overview?.activePlansCount ?? 0}',
                      subtitle: 'Disponíveis no catálogo',
                      icon: Icons.check_circle_rounded,
                      accentColor: MetaColors.emerald,
                    );
                    final kpi2 = _buildKpiCard(
                      title: 'Ticket Médio Mensal',
                      value: 'R\$ ${(_overview?.averageMonthlyPrice ?? 0).toStringAsFixed(2)}',
                      subtitle: 'Média ponderada por plano',
                      icon: Icons.receipt_long_rounded,
                      accentColor: const Color(0xFF818CF8),
                    );
                    final kpi3 = _buildKpiCard(
                      title: 'Assinantes Vinculados',
                      value: '${_overview?.totalSubscribers ?? 0}',
                      subtitle: 'Personals em planos ativos',
                      icon: Icons.people_alt_rounded,
                      accentColor: Colors.cyanAccent,
                    );
                    final kpi4 = _buildKpiCard(
                      title: 'Taxa Split Plataforma',
                      value: '${(_overview?.platformFeeAverage ?? 5.0).toStringAsFixed(1)}%',
                      subtitle: 'Retenção sobre receita',
                      icon: Icons.pie_chart_rounded,
                      accentColor: Colors.amber,
                    );

                    if (isDesktop) {
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
                    } else if (isTablet) {
                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(child: kpi1),
                              const SizedBox(width: 14),
                              Expanded(child: kpi2),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(child: kpi3),
                              const SizedBox(width: 14),
                              Expanded(child: kpi4),
                            ],
                          ),
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

                // Banner Informativo
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF1F2937)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.sync_rounded, color: Color(0xFF818CF8), size: 22),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sincronização em Tempo Real',
                              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Alterações de mensalidade, anuidade ou cotas de alunos entram em vigor imediatamente para novas contratações e no simulador SaaS.',
                              style: TextStyle(color: Colors.white60, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Lista de Planos Configurados
                Text(
                  'Catálogo de Planos SaaS (${_overview?.plans.length ?? 0})',
                  style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 14),

                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _overview?.plans.length ?? 0,
                  separatorBuilder: (context, index) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final plan = _overview!.plans[index];
                    return _buildPlanCard(plan);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
  }) {
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
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accentColor.withValues(alpha: 0.25)),
            ),
            child: Icon(icon, color: accentColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(color: accentColor, fontSize: 20, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(AdminPricingPlanItem plan) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: plan.isActive ? const Color(0xFF1F2937) : Colors.redAccent.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header do Card
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      plan.name,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                    if (plan.badge.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          plan.badge.toUpperCase(),
                          style: const TextStyle(color: Color(0xFF818CF8), fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: plan.isActive ? MetaColors.emerald.withValues(alpha: 0.12) : Colors.redAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: plan.isActive ? MetaColors.emerald.withValues(alpha: 0.4) : Colors.redAccent.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        plan.isActive ? 'ATIVO NO CHECKOUT' : 'DESATIVADO',
                        style: TextStyle(
                          color: plan.isActive ? MetaColors.emerald : Colors.redAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Switch(
                    value: plan.isActive,
                    onChanged: (val) => _togglePlanActive(plan, val),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Preços e Condições em Grid Responsivo
          Wrap(
            spacing: 20,
            runSpacing: 12,
            children: [
              _buildMetricChip(
                label: 'Mensalidade',
                value: 'R\$ ${plan.priceMonthly.toStringAsFixed(2)}',
                subtitle: '/ mês',
                color: const Color(0xFF818CF8),
              ),
              _buildMetricChip(
                label: 'Anual (À Vista)',
                value: 'R\$ ${plan.priceYearly.toStringAsFixed(2)}',
                subtitle: 'economia de ~20%',
                color: MetaColors.emerald,
              ),
              _buildMetricChip(
                label: 'Capacidade',
                value: plan.isUnlimitedStudents ? 'Ilimitado' : '${plan.studentLimit} alunos',
                subtitle: 'vagas ativas simultâneas',
                color: Colors.amber,
              ),
              _buildMetricChip(
                label: 'Split Plataforma',
                value: '${plan.platformFeePercent.toStringAsFixed(1)}%',
                subtitle: 'por transação',
                color: Colors.cyanAccent,
              ),
              _buildMetricChip(
                label: 'Cota IA Gemini',
                value: plan.isUnlimitedAi ? 'Ilimitada' : '${plan.aiQuotaLimit} gerações',
                subtitle: 'mensais por personal',
                color: const Color(0xFFC084FC),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Features Ativas
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFeatureBadge(
                label: 'Marca Própria',
                enabled: plan.hasCustomBranding,
                icon: Icons.brush_rounded,
              ),
              _buildFeatureBadge(
                label: 'Suporte VIP WhatsApp',
                enabled: plan.hasPrioritySupport,
                icon: Icons.verified_user_rounded,
              ),
              _buildFeatureBadge(
                label: 'Checkout Asaas Direto',
                enabled: true,
                icon: Icons.pix_rounded,
              ),
              _buildFeatureBadge(
                label: 'PWA Customizado',
                enabled: true,
                icon: Icons.install_mobile_rounded,
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFF1F2937), height: 1),
          const SizedBox(height: 12),

          // Rodapé do Card
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${plan.subscriberCount} treinadores inscritos neste plano',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              ElevatedButton.icon(
                onPressed: () => _openEditPlanDialog(plan),
                icon: const Icon(Icons.tune_rounded, size: 15),
                label: const Text('Editar Parâmetros', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip({
    required String label,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF090D16),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w900),
              ),
              const SizedBox(width: 4),
              Text(
                subtitle,
                style: const TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureBadge({
    required String label,
    required bool enabled,
    required IconData icon,
  }) {
    final color = enabled ? MetaColors.emerald : Colors.white38;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
