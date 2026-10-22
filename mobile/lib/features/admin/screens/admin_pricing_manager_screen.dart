import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/widgets/meta_components.dart';
import '../services/admin_data_service.dart';

/// Módulo: Gestão Dinâmica de Preços, Planos SaaS & Cupons de Desconto
class AdminPricingManagerScreen extends StatefulWidget {
  final VoidCallback? onNavigateToSimulator;

  const AdminPricingManagerScreen({
    super.key,
    this.onNavigateToSimulator,
  });

  @override
  State<AdminPricingManagerScreen> createState() => _AdminPricingManagerScreenState();
}

class _AdminPricingManagerScreenState extends State<AdminPricingManagerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  bool _isLoadingCoupons = true;
  bool _isLoadingAffiliates = true;
  AdminPricingConfigOverview? _overview;
  AdminCouponsOverview? _couponsOverview;
  AdminAffiliatesOverview? _affiliatesOverview;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadPricing(),
      _loadCoupons(),
      _loadAffiliates(),
    ]);
  }

  Future<void> _loadAffiliates() async {
    setState(() => _isLoadingAffiliates = true);
    final data = await AdminDataService.getAffiliatesOverview();
    if (mounted) {
      setState(() {
        _affiliatesOverview = data;
        _isLoadingAffiliates = false;
      });
    }
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

  Future<void> _loadCoupons() async {
    setState(() => _isLoadingCoupons = true);
    final data = await AdminDataService.getCouponsOverview();
    if (mounted) {
      setState(() {
        _couponsOverview = data;
        _isLoadingCoupons = false;
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
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
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
                                const Expanded(
                                  child: Text(
                                    'Limite de Alunos Ativos',
                                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
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
                                      const Expanded(
                                        child: Text(
                                          'Cota IA',
                                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Text('Ilimitado', style: TextStyle(color: Colors.white60, fontSize: 12)),
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

                      // Switches de Recursos Premium
                      _buildFeatureSwitchRow(
                        title: 'Marca Própria (White-Label)',
                        subtitle: 'Permite personalizar logo e cores no PWA do aluno',
                        value: hasCustomBranding,
                        onChanged: (val) => setModalState(() => hasCustomBranding = val),
                      ),
                      _buildFeatureSwitchRow(
                        title: 'Suporte Prioritário VIP',
                        subtitle: 'Atendimento via canal exclusivo no WhatsApp',
                        value: hasPrioritySupport,
                        onChanged: (val) => setModalState(() => hasPrioritySupport = val),
                      ),
                      _buildFeatureSwitchRow(
                        title: 'Plano Ativo no Catálogo',
                        subtitle: 'Disponível para contratação imediata no checkout',
                        value: isActive,
                        onChanged: (val) => setModalState(() => isActive = val),
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
                    final studentLimit = unlimitedStudents ? 0 : (int.tryParse(studentLimitCtrl.text) ?? plan.studentLimit);
                    final split = double.tryParse(splitCtrl.text.replaceAll(',', '.')) ?? plan.platformFeePercent;
                    final aiQuota = unlimitedAi ? 0 : (int.tryParse(aiQuotaCtrl.text) ?? plan.aiQuotaLimit);

                    final updated = plan.copyWith(
                      name: nameCtrl.text.trim().isNotEmpty ? nameCtrl.text.trim() : plan.name,
                      badge: badgeCtrl.text.trim(),
                      priceMonthly: monthly,
                      priceYearly: yearly,
                      studentLimit: studentLimit,
                      platformFeePercent: split,
                      aiQuotaLimit: aiQuota,
                      hasCustomBranding: hasCustomBranding,
                      hasPrioritySupport: hasPrioritySupport,
                      isActive: isActive,
                    );

                    final ok = await AdminDataService.updatePricingPlan(updated);
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            ok ? 'Plano ${updated.name} salvo com sucesso!' : 'Erro ao salvar alterações do plano.',
                          ),
                          backgroundColor: ok ? MetaColors.emerald : Colors.redAccent,
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

  // ==========================================
  // Lógica de Cupons Promocionais
  // ==========================================
  Future<void> _toggleCouponActive(AdminCouponItem coupon, bool newValue) async {
    final messenger = ScaffoldMessenger.of(context);
    final success = await AdminDataService.toggleCouponActive(coupon.id, newValue);
    if (mounted) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            success
                ? (newValue
                    ? 'Cupom ${coupon.code} ativado para resgates!'
                    : 'Cupom ${coupon.code} pausado temporariamente.')
                : 'Falha ao atualizar status do cupom.',
          ),
          backgroundColor: newValue ? MetaColors.emerald : Colors.amber,
          duration: const Duration(seconds: 2),
        ),
      );
      _loadCoupons();
    }
  }

  Future<void> _deleteCoupon(AdminCouponItem coupon) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
            const SizedBox(width: 8),
            Text(
              'Excluir Cupom ${coupon.code}?',
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Deseja remover o cupom "${coupon.code}" (${coupon.formattedDiscount})?\nEssa ação não pode ser desfeita.',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Excluir Cupom', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await AdminDataService.deleteCoupon(coupon.id);
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              success ? 'Cupom ${coupon.code} removido com sucesso!' : 'Falha ao remover cupom.',
            ),
            backgroundColor: success ? MetaColors.emerald : Colors.redAccent,
          ),
        );
        _loadCoupons();
      }
    }
  }

  Future<void> _openCreateOrEditCouponDialog([AdminCouponItem? existing]) async {
    final messenger = ScaffoldMessenger.of(context);
    final isEditing = existing != null;

    final codeCtrl = TextEditingController(text: existing?.code ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final valCtrl = TextEditingController(
      text: existing != null
          ? (existing.discountType == 'percentage'
              ? existing.discountValue.toStringAsFixed(0)
              : existing.discountValue.toStringAsFixed(2))
          : '20',
    );
    final maxUsesCtrl = TextEditingController(
      text: existing != null ? (existing.maxUses > 0 ? existing.maxUses.toString() : '0') : '50',
    );
    final expiresCtrl = TextEditingController(
      text: existing?.expiresAt != null ? existing!.expiresAt!.split('T').first : '2026-12-31',
    );

    String discountType = existing?.discountType ?? 'percentage';
    String applicablePlan = existing?.applicablePlan ?? 'all';
    bool isActive = existing?.isActive ?? true;
    bool unlimitedUses = existing != null && existing.maxUses <= 0;

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
                    child: Icon(
                      isEditing ? Icons.edit_note_rounded : Icons.confirmation_number_rounded,
                      color: const Color(0xFF818CF8),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isEditing ? 'Editar Cupom: ${existing.code}' : 'Novo Cupom Promocional',
                      style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Código do Cupom
                      _buildModalTextField(
                        label: 'Código do Cupom (ex: PROMO50, BLACKFRIDAY)',
                        controller: codeCtrl,
                        textCapitalization: TextCapitalization.characters,
                      ),
                      const SizedBox(height: 12),

                      // Descrição
                      _buildModalTextField(
                        label: 'Descrição / Campanha',
                        controller: descCtrl,
                      ),
                      const SizedBox(height: 14),

                      // Tipo e Valor
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Tipo de Desconto',
                                  style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF090D16),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFF1F2937)),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: discountType,
                                      dropdownColor: const Color(0xFF111827),
                                      isExpanded: true,
                                      style: const TextStyle(color: Colors.white, fontSize: 13),
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'percentage',
                                          child: Text('Porcentagem (%)'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'fixed',
                                          child: Text('Valor Fixo (R\$)'),
                                        ),
                                      ],
                                      onChanged: (val) {
                                        if (val != null) {
                                          setModalState(() => discountType = val);
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildModalTextField(
                              label: discountType == 'percentage' ? 'Percentual (%)' : 'Valor (R\$)',
                              controller: valCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Limite de Usos
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
                                const Expanded(
                                  child: Text(
                                    'Limite Máximo de Resgates',
                                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('Ilimitado', style: TextStyle(color: Colors.white60, fontSize: 12)),
                                    Switch(
                                      value: unlimitedUses,
                                      onChanged: (val) {
                                        setModalState(() {
                                          unlimitedUses = val;
                                          if (val) maxUsesCtrl.text = '0';
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            if (!unlimitedUses)
                              _buildModalTextField(
                                label: 'Total de Resgates Permitidos',
                                controller: maxUsesCtrl,
                                keyboardType: TextInputType.number,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Plano Aplicável e Data de Expiração
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Plano Aplicável',
                                  style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF090D16),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFF1F2937)),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: applicablePlan,
                                      dropdownColor: const Color(0xFF111827),
                                      isExpanded: true,
                                      style: const TextStyle(color: Colors.white, fontSize: 13),
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'all',
                                          child: Text('Todos os Planos'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'starter',
                                          child: Text('Apenas Starter'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'pro',
                                          child: Text('Apenas Pro'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'elite',
                                          child: Text('Apenas Elite'),
                                        ),
                                      ],
                                      onChanged: (val) {
                                        if (val != null) {
                                          setModalState(() => applicablePlan = val);
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildModalTextField(
                              label: 'Validade (AAAA-MM-DD)',
                              controller: expiresCtrl,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Ativar Cupom
                      _buildFeatureSwitchRow(
                        title: 'Cupom Ativo Imediatamente',
                        subtitle: 'Permite que personals utilizem o código na tela de checkout',
                        value: isActive,
                        onChanged: (val) => setModalState(() => isActive = val),
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
                    final code = codeCtrl.text.trim().toUpperCase();
                    if (code.isEmpty) {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Por favor, informe um código para o cupom.'),
                          backgroundColor: Colors.amber,
                        ),
                      );
                      return;
                    }

                    final discountVal = double.tryParse(valCtrl.text.replaceAll(',', '.')) ?? 10.0;
                    final maxUses = unlimitedUses ? 0 : (int.tryParse(maxUsesCtrl.text) ?? 50);

                    final newCoupon = AdminCouponItem(
                      id: existing?.id ?? code,
                      code: code,
                      description: descCtrl.text.trim().isNotEmpty ? descCtrl.text.trim() : 'Campanha promocional',
                      discountType: discountType,
                      discountValue: discountVal,
                      maxUses: maxUses,
                      currentUses: existing?.currentUses ?? 0,
                      applicablePlan: applicablePlan,
                      isActive: isActive,
                      expiresAt: expiresCtrl.text.trim().isNotEmpty ? '${expiresCtrl.text.trim()}T23:59:59Z' : null,
                      createdAt: existing?.createdAt ?? DateTime.now().toIso8601String(),
                    );

                    final ok = await AdminDataService.createOrUpdateCoupon(newCoupon);
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            ok
                                ? (isEditing ? 'Cupom ${newCoupon.code} atualizado!' : 'Cupom ${newCoupon.code} criado com sucesso!')
                                : 'Erro ao processar cupom promocional.',
                          ),
                          backgroundColor: ok ? MetaColors.emerald : Colors.redAccent,
                        ),
                      );
                      _loadCoupons();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(isEditing ? 'Salvar Cupom' : 'Criar Cupom', style: const TextStyle(fontWeight: FontWeight.bold)),
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
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? hintText,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF090D16),
            hintText: hintText,
            hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
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
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
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
                                'Configure planos, valores de mensalidades, cotas de alunos e cupons de desconto',
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
                              onPressed: _loadAll,
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
                    const SizedBox(height: 20),

                    // TabBar Customizada
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF111827),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF1F2937)),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        indicatorColor: const Color(0xFF6366F1),
                        indicatorWeight: 3,
                        indicatorSize: TabBarIndicatorSize.tab,
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.white54,
                        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 14),
                        tabs: const [
                          Tab(
                            icon: Icon(Icons.sell_rounded, size: 18),
                            text: 'Planos & Mensalidades',
                          ),
                          Tab(
                            icon: Icon(Icons.confirmation_number_rounded, size: 18),
                            text: 'Cupons Promocionais',
                          ),
                          Tab(
                            icon: Icon(Icons.handshake_rounded, size: 18),
                            text: 'Afiliados & Parcerias',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            // Aba 1: Planos
            _buildPlansTab(),

            // Aba 2: Cupons
            _buildCouponsTab(),

            // Aba 3: Afiliados & Parcerias
            _buildAffiliatesTab(),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // Renderização da Aba de Planos
  // ==========================================
  Widget _buildPlansTab() {
    return RefreshIndicator(
      onRefresh: _loadPricing,
      color: const Color(0xFF6366F1),
      backgroundColor: const Color(0xFF111827),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(48),
                  child: CircularProgressIndicator(color: Color(0xFF6366F1)),
                ),
              )
            else ...[
              // KPI Cards
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
              const SizedBox(height: 32),
            ],
          ],
        ),
      ),
    );
  }

  // ==========================================
  // Renderização da Aba de Cupons
  // ==========================================
  Widget _buildCouponsTab() {
    return RefreshIndicator(
      onRefresh: _loadCoupons,
      color: const Color(0xFF6366F1),
      backgroundColor: const Color(0xFF111827),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_isLoadingCoupons)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(48),
                  child: CircularProgressIndicator(color: Color(0xFF6366F1)),
                ),
              )
            else ...[
              // KPI Cards de Cupons
              LayoutBuilder(
                builder: (context, constraints) {
                  final isDesktop = constraints.maxWidth > 900;
                  final isTablet = constraints.maxWidth > 550 && !isDesktop;

                  final kpi1 = _buildKpiCard(
                    title: 'Cupons Ativos',
                    value: '${_couponsOverview?.activeCoupons ?? 0}',
                    subtitle: 'Em circulação no checkout',
                    icon: Icons.check_circle_rounded,
                    accentColor: MetaColors.emerald,
                  );
                  final kpi2 = _buildKpiCard(
                    title: 'Total de Resgates',
                    value: '${_couponsOverview?.totalRedemptions ?? 0}',
                    subtitle: 'Personal trainers beneficiados',
                    icon: Icons.people_alt_rounded,
                    accentColor: Colors.cyanAccent,
                  );
                  final kpi3 = _buildKpiCard(
                    title: 'Desconto Concedido',
                    value: 'R\$ ${(_couponsOverview?.totalDiscountGrantedBrl ?? 0).toStringAsFixed(2)}',
                    subtitle: 'Impacto total em incentivos',
                    icon: Icons.savings_rounded,
                    accentColor: Colors.amber,
                  );
                  final kpi4 = _buildKpiCard(
                    title: 'Esgotados / Expirados',
                    value: '${_couponsOverview?.depletedOrExpiredCoupons ?? 0}',
                    subtitle: 'Campanhas finalizadas',
                    icon: Icons.timer_off_rounded,
                    accentColor: const Color(0xFFF43F5E),
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

              // Banner de Ações da Campanha
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
                      child: const Icon(Icons.campaign_rounded, color: Color(0xFF818CF8), size: 22),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Motor de Campanhas & Aquisição (CAC)',
                            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Crie códigos promocionais com desconto percentual ou fixo para impulsionar novos cadastros e parcerias com assessorias ou CREF.',
                            style: TextStyle(color: Colors.white60, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => _openCreateOrEditCouponDialog(),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Novo Cupom', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Lista de Cupons
              Text(
                'Cupons & Campanhas Cadastradas (${_couponsOverview?.coupons.length ?? 0})',
                style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),

              if (_couponsOverview?.coupons.isEmpty ?? true)
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF1F2937)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.confirmation_number_outlined, size: 48, color: Colors.white38),
                      const SizedBox(height: 12),
                      const Text(
                        'Nenhum cupom cadastrado ainda',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Crie seu primeiro cupom promocional para alavancar novas assinaturas.',
                        style: TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => _openCreateOrEditCouponDialog(),
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('Criar Primeiro Cupom'),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _couponsOverview!.coupons.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final coupon = _couponsOverview!.coupons[index];
                    return _buildCouponCard(coupon);
                  },
                ),
              const SizedBox(height: 32),
            ],
          ],
        ),
      ),
    );
  }

  // ==========================================
  // Card de Cupom
  // ==========================================
  Widget _buildCouponCard(AdminCouponItem coupon) {
    final isDepleted = coupon.isDepleted;
    final progress = coupon.usageProgress;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDepleted
              ? Colors.redAccent.withValues(alpha: 0.3)
              : (coupon.isActive ? const Color(0xFF1F2937) : Colors.amber.withValues(alpha: 0.3)),
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
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Badge Código
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        coupon.code,
                        style: const TextStyle(
                          color: Color(0xFF818CF8),
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),

                    // Badge Desconto
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: MetaColors.emerald.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: MetaColors.emerald.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        coupon.formattedDiscount,
                        style: const TextStyle(color: MetaColors.emerald, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),

                    // Status Ativo / Pausado / Esgotado
                    if (isDepleted)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                        ),
                        child: const Text(
                          'ESGOTADO',
                          style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: coupon.isActive
                              ? MetaColors.emerald.withValues(alpha: 0.12)
                              : Colors.amber.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: coupon.isActive
                                ? MetaColors.emerald.withValues(alpha: 0.4)
                                : Colors.amber.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          coupon.isActive ? 'ATIVO NO CHECKOUT' : 'PAUSADO',
                          style: TextStyle(
                            color: coupon.isActive ? MetaColors.emerald : Colors.amber,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Switch(
                    value: coupon.isActive,
                    onChanged: (val) => _toggleCouponActive(coupon, val),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Descrição do Cupom
          Text(
            coupon.description,
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 14),

          // Progresso de Resgates
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  coupon.maxUses > 0
                      ? 'Resgates: ${coupon.currentUses} de ${coupon.maxUses} (${(progress * 100).toInt()}%)'
                      : 'Resgates: ${coupon.currentUses} (Sem limite de usos)',
                  style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (coupon.expiresAt != null)
                Text(
                  'Expira em: ${coupon.expiresAt!.split('T').first}',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: coupon.maxUses > 0 ? progress : (coupon.currentUses > 0 ? 0.5 : 0.0),
              backgroundColor: const Color(0xFF090D16),
              valueColor: AlwaysStoppedAnimation<Color>(
                isDepleted
                    ? Colors.redAccent
                    : (progress > 0.8 ? Colors.amber : const Color(0xFF6366F1)),
              ),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 14),

          // Badges Informativos do Cupom
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFeatureBadge(
                label: coupon.applicablePlan == 'all'
                    ? 'Todos os Planos'
                    : 'Plano ${coupon.applicablePlan.toUpperCase()}',
                enabled: true,
                icon: Icons.layers_rounded,
              ),
              _buildFeatureBadge(
                label: coupon.discountType == 'percentage' ? 'Desconto %' : 'Desconto Fixo',
                enabled: true,
                icon: Icons.percent_rounded,
              ),
              if (coupon.maxUses > 0)
                _buildFeatureBadge(
                  label: '${coupon.maxUses - coupon.currentUses} vagas restantes',
                  enabled: !isDepleted,
                  icon: Icons.event_available_rounded,
                ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: Color(0xFF1F2937), height: 1),
          const SizedBox(height: 12),

          // Rodapé do Card
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Criado em ${coupon.createdAt != null ? coupon.createdAt!.split('T').first : "Início de 2026"}',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () => _deleteCoupon(coupon),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                    tooltip: 'Excluir Cupom',
                  ),
                  const SizedBox(width: 6),
                  ElevatedButton.icon(
                    onPressed: () => _openCreateOrEditCouponDialog(coupon),
                    icon: const Icon(Icons.edit_rounded, size: 14),
                    label: const Text('Editar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // Componentes de Visualização Compartilhados
  // ==========================================

  // ==========================================
  // Lógica de Afiliados & Parcerias
  // ==========================================
  Future<void> _toggleAffiliateActive(AdminAffiliatePartnerItem affiliate, bool newValue) async {
    final messenger = ScaffoldMessenger.of(context);
    final success = await AdminDataService.toggleAffiliateActive(affiliate.id, newValue);
    if (mounted) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            success
                ? (newValue
                    ? 'Parceiro ${affiliate.partnerName} ativado para rastreamento!'
                    : 'Parceiro ${affiliate.partnerName} pausado temporariamente.')
                : 'Falha ao atualizar status do parceiro.',
          ),
          backgroundColor: newValue ? MetaColors.emerald : Colors.amber,
          duration: const Duration(seconds: 2),
        ),
      );
      _loadAffiliates();
    }
  }

  Future<void> _deleteAffiliate(AdminAffiliatePartnerItem affiliate) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Excluir Parceiro ${affiliate.partnerName}?',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Text(
          'Deseja remover a parceria com "${affiliate.partnerName}" (Slug: ${affiliate.slug})?\nO link de indicação deixará de ser contabilizado.',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Excluir Parceiro', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await AdminDataService.deleteAffiliate(affiliate.id);
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              success ? 'Parceiro ${affiliate.partnerName} removido com sucesso!' : 'Falha ao remover parceiro.',
            ),
            backgroundColor: success ? MetaColors.emerald : Colors.redAccent,
          ),
        );
        _loadAffiliates();
      }
    }
  }

  void _copyReferralLink(String url) {
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Link copiado: $url'),
            ),
          ],
        ),
        backgroundColor: MetaColors.emerald,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Modal de Liquidação de Comissões via Pix (Payout Engine)
  Future<void> _openPayoutDialog(AdminAffiliatePartnerItem affiliate) async {
    final messenger = ScaffoldMessenger.of(context);
    final amountCtrl = TextEditingController(
      text: affiliate.totalCommissionDueBrl > 0 ? affiliate.totalCommissionDueBrl.toStringAsFixed(2) : '100.00',
    );
    final pixCtrl = TextEditingController(text: affiliate.pixKey ?? '');
    final txCtrl = TextEditingController();
    final notesCtrl = TextEditingController(text: 'Liquidação de comissões via Pix');
    bool isSubmitting = false;

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
                      color: MetaColors.emerald.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.payments_rounded, color: MetaColors.emerald, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Liquidar Comissão via Pix',
                          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          affiliate.partnerName,
                          style: const TextStyle(color: Colors.white60, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Card de Saldo Devido vs Liquidado
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF090D16),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF1F2937)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Saldo Pendente', style: TextStyle(color: Colors.white54, fontSize: 11)),
                                  const SizedBox(height: 2),
                                  Text(
                                    affiliate.formattedCommission,
                                    style: TextStyle(
                                      color: affiliate.hasPendingCommission ? const Color(0xFFF43F5E) : Colors.white38,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(width: 1, height: 32, color: const Color(0xFF1F2937)),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Total Já Pago', style: TextStyle(color: Colors.white54, fontSize: 11)),
                                  const SizedBox(height: 2),
                                  Text(
                                    affiliate.formattedPaidCommission,
                                    style: const TextStyle(
                                      color: MetaColors.emerald,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Valor do Repasse
                      _buildModalTextField(
                        label: 'Valor a Liquidar (R\$)',
                        controller: amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                      const SizedBox(height: 12),

                      // Chave Pix com Botão de Copiar
                      Row(
                        children: [
                          Expanded(
                            child: _buildModalTextField(
                              label: 'Chave Pix de Destino',
                              controller: pixCtrl,
                            ),
                          ),
                          if (pixCtrl.text.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: pixCtrl.text));
                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text('Chave Pix copiada para a área de transferência!'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.copy_rounded, color: Color(0xFF818CF8)),
                              tooltip: 'Copiar Chave Pix',
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),

                      // ID da Transação / E2E
                      _buildModalTextField(
                        label: 'Código da Transação Pix / E2E (opcional)',
                        controller: txCtrl,
                        hintText: 'ex: E2E98472938472983749823',
                      ),
                      const SizedBox(height: 12),

                      // Observação
                      _buildModalTextField(
                        label: 'Observações do Repasse (opcional)',
                        controller: notesCtrl,
                        maxLines: 2,
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
                ElevatedButton.icon(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final valStr = amountCtrl.text.replaceAll(',', '.').trim();
                          final val = double.tryParse(valStr);
                          if (val == null || val <= 0) {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Informe um valor de liquidação válido.'),
                                backgroundColor: Colors.amber,
                              ),
                            );
                            return;
                          }
                          final pix = pixCtrl.text.trim();
                          if (pix.isEmpty) {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Informe a chave Pix para realização do repasse.'),
                                backgroundColor: Colors.amber,
                              ),
                            );
                            return;
                          }

                          setModalState(() => isSubmitting = true);
                          final res = await AdminDataService.payoutAffiliate(
                            affiliateId: affiliate.id,
                            amountBrl: val,
                            pixKey: pix,
                            pixTransactionId: txCtrl.text.trim().isNotEmpty ? txCtrl.text.trim() : null,
                            notes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
                          );

                          if (mounted && ctx.mounted) {
                            Navigator.pop(ctx);
                            _loadAffiliates();
                            messenger.showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        res['message']?.toString() ?? 'Repasse liquidado com sucesso!',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                backgroundColor: MetaColors.emerald,
                                duration: const Duration(seconds: 4),
                              ),
                            );
                          }
                        },
                  icon: isSubmitting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_rounded, size: 16),
                  label: Text(
                    isSubmitting ? 'Processando...' : 'Confirmar Liquidação Pix',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MetaColors.emerald,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Modal de Extrato Geral / Recibos de Liquidação Pix
  Future<void> _openPayoutHistoryDialog([AdminAffiliatePartnerItem? affiliate]) async {
    final messenger = ScaffoldMessenger.of(context);
    final payouts = await AdminDataService.getAffiliatePayouts(affiliateId: affiliate?.id);

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF111827),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: MetaColors.emerald.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.receipt_long_rounded, color: MetaColors.emerald, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      affiliate != null ? 'Recibos: ${affiliate.partnerName}' : 'Extrato Geral de Repasses Pix',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${payouts.length} liquidações registradas',
                      style: const TextStyle(color: Colors.white60, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 550,
            height: 420,
            child: payouts.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 40, color: Colors.white38),
                          SizedBox(height: 12),
                          Text(
                            'Nenhum repasse liquidado ainda.',
                            style: TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: payouts.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final p = payouts[index];
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF090D16),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF1F2937)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: MetaColors.emerald.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: MetaColors.emerald.withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    p.receiptNumber,
                                    style: const TextStyle(
                                      color: MetaColors.emerald,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                                Text(
                                  p.formattedAmount,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              p.partnerName,
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '📅 ${p.paidAt} • Pix: ${p.pixKey}',
                              style: const TextStyle(color: Colors.white60, fontSize: 11),
                            ),
                            if (p.notes != null && p.notes!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                '📝 ${p.notes}',
                                style: const TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic),
                              ),
                            ],
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'ID: ${p.pixTransactionId}',
                                    style: const TextStyle(
                                      color: Color(0xFF818CF8),
                                      fontSize: 10.5,
                                      fontFamily: 'monospace',
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                InkWell(
                                  onTap: () {
                                    Clipboard.setData(ClipboardData(text: p.pixTransactionId));
                                    messenger.showSnackBar(
                                      const SnackBar(
                                        content: Text('ID de transação copiado!'),
                                        duration: Duration(seconds: 1),
                                      ),
                                    );
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                    child: Icon(Icons.copy_rounded, size: 14, color: Color(0xFF818CF8)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Fechar', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openCreateOrEditAffiliateDialog([AdminAffiliatePartnerItem? existing]) async {
    final messenger = ScaffoldMessenger.of(context);
    final isEditing = existing != null;

    final nameCtrl = TextEditingController(text: existing?.partnerName ?? '');
    final slugCtrl = TextEditingController(text: existing?.slug ?? '');
    final commCtrl = TextEditingController(text: existing != null ? existing.commissionPercent.toStringAsFixed(1) : '10.0');
    final couponCtrl = TextEditingController(text: existing?.associatedCouponCode ?? '');
    final emailCtrl = TextEditingController(text: existing?.contactEmail ?? '');
    final pixCtrl = TextEditingController(text: existing?.pixKey ?? '');

    String partnerType = existing?.partnerType ?? 'entity';
    bool isActive = existing?.isActive ?? true;

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
                    child: Icon(
                      isEditing ? Icons.edit_note_rounded : Icons.handshake_rounded,
                      color: const Color(0xFF818CF8),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isEditing ? 'Editar Parceiro: ${existing.partnerName}' : 'Novo Parceiro Afiliado',
                      style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Nome do Parceiro
                      _buildModalTextField(
                        label: 'Nome do Parceiro / Entidade (ex: CREF4/SP, Assessoria Iron)',
                        controller: nameCtrl,
                      ),
                      const SizedBox(height: 12),

                      // Slug e Tipo
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: _buildModalTextField(
                              label: 'Slug do Link (ex: CREFSP)',
                              controller: slugCtrl,
                              textCapitalization: TextCapitalization.characters,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Categoria',
                                  style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF090D16),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFF1F2937)),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: partnerType,
                                      dropdownColor: const Color(0xFF111827),
                                      isExpanded: true,
                                      style: const TextStyle(color: Colors.white, fontSize: 13),
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'entity',
                                          child: Text('Conselho / Entidade'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'coach',
                                          child: Text('Assessoria / Treinador'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'influencer',
                                          child: Text('Influenciador / Creator'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'gym_chain',
                                          child: Text('Rede de Academias'),
                                        ),
                                      ],
                                      onChanged: (val) {
                                        if (val != null) {
                                          setModalState(() => partnerType = val);
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Comissão (%) e Cupom Vinculado
                      Row(
                        children: [
                          Expanded(
                            child: _buildModalTextField(
                              label: 'Comissão do Parceiro (%)',
                              controller: commCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildModalTextField(
                              label: 'Cupom Vinculado (Opcional)',
                              controller: couponCtrl,
                              textCapitalization: TextCapitalization.characters,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Contato & Chave Pix
                      Row(
                        children: [
                          Expanded(
                            child: _buildModalTextField(
                              label: 'E-mail de Contato',
                              controller: emailCtrl,
                              keyboardType: TextInputType.emailAddress,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildModalTextField(
                              label: 'Chave Pix para Repasse',
                              controller: pixCtrl,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Status Ativo
                      _buildFeatureSwitchRow(
                        title: 'Parceria Ativa',
                        subtitle: 'Links e conversões ativas para este parceiro',
                        value: isActive,
                        onChanged: (val) => setModalState(() => isActive = val),
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
                    final name = nameCtrl.text.trim();
                    final slug = slugCtrl.text.trim().toUpperCase().replaceAll(' ', '-');
                    if (name.isEmpty || slug.isEmpty) {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Por favor, informe o nome e o slug do parceiro.'),
                          backgroundColor: Colors.amber,
                        ),
                      );
                      return;
                    }

                    final comm = double.tryParse(commCtrl.text.replaceAll(',', '.')) ?? 10.0;

                    final partner = AdminAffiliatePartnerItem(
                      id: existing?.id ?? 'aff-${slug.toLowerCase()}-${DateTime.now().millisecondsSinceEpoch}',
                      partnerName: name,
                      slug: slug,
                      partnerType: partnerType,
                      commissionPercent: comm,
                      associatedCouponCode: couponCtrl.text.trim().isNotEmpty ? couponCtrl.text.trim().toUpperCase() : null,
                      clicksCount: existing?.clicksCount ?? 0,
                      conversionsCount: existing?.conversionsCount ?? 0,
                      totalRevenueGeneratedBrl: existing?.totalRevenueGeneratedBrl ?? 0.0,
                      totalCommissionDueBrl: existing?.totalCommissionDueBrl ?? 0.0,
                      contactEmail: emailCtrl.text.trim().isNotEmpty ? emailCtrl.text.trim() : null,
                      pixKey: pixCtrl.text.trim().isNotEmpty ? pixCtrl.text.trim() : null,
                      isActive: isActive,
                      createdAt: existing?.createdAt ?? DateTime.now().toIso8601String(),
                    );

                    final ok = await AdminDataService.createOrUpdateAffiliate(partner);
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            ok
                                ? (isEditing ? 'Parceiro ${partner.partnerName} atualizado!' : 'Parceiro ${partner.partnerName} cadastrado com sucesso!')
                                : 'Erro ao salvar parceiro afiliado.',
                          ),
                          backgroundColor: ok ? MetaColors.emerald : Colors.redAccent,
                        ),
                      );
                      _loadAffiliates();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(isEditing ? 'Salvar Parceiro' : 'Cadastrar Parceiro', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ==========================================
  // Renderização da Aba de Afiliados
  // ==========================================
  Widget _buildAffiliatesTab() {
    return RefreshIndicator(
      onRefresh: _loadAffiliates,
      color: const Color(0xFF6366F1),
      backgroundColor: const Color(0xFF111827),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_isLoadingAffiliates)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(48),
                  child: CircularProgressIndicator(color: Color(0xFF6366F1)),
                ),
              )
            else ...[
              // KPI Cards de Afiliados
              LayoutBuilder(
                builder: (context, constraints) {
                  final isDesktop = constraints.maxWidth > 900;
                  final isTablet = constraints.maxWidth > 550 && !isDesktop;

                  final kpi1 = _buildKpiCard(
                    title: 'Parceiros Ativos',
                    value: '${_affiliatesOverview?.activePartnersCount ?? 0}',
                    subtitle: 'Divulgando links de indicação',
                    icon: Icons.check_circle_rounded,
                    accentColor: MetaColors.emerald,
                  );
                  final kpi2 = _buildKpiCard(
                    title: 'Total de Cliques',
                    value: '${_affiliatesOverview?.totalClicks ?? 0}',
                    subtitle: 'Acessos únicos aos links',
                    icon: Icons.ads_click_rounded,
                    accentColor: const Color(0xFF818CF8),
                  );
                  final kpi3 = _buildKpiCard(
                    title: 'Total de Conversões',
                    value: '${_affiliatesOverview?.totalConversions ?? 0}',
                    subtitle: 'Taxa média de ${_affiliatesOverview?.averageConversionRatePercent.toStringAsFixed(1) ?? "0.0"}%',
                    icon: Icons.people_alt_rounded,
                    accentColor: Colors.cyanAccent,
                  );
                  final kpi4 = _buildKpiCard(
                    title: 'Comissões a Repassar',
                    value: 'R\$ ${(_affiliatesOverview?.totalCommissionDueBrl ?? 0).toStringAsFixed(2)}',
                    subtitle: 'Base em R\$ ${(_affiliatesOverview?.totalRevenueGeneratedBrl ?? 0).toStringAsFixed(0)} gerados',
                    icon: Icons.payments_rounded,
                    accentColor: Colors.amber,
                  );
                  final kpi5 = _buildKpiCard(
                    title: 'Total Liquidado Pix',
                    value: 'R\$ ${(_affiliatesOverview?.totalCommissionPaidBrl ?? 0).toStringAsFixed(2)}',
                    subtitle: '${_affiliatesOverview?.totalPayoutsCount ?? 0} repasses efetuados',
                    icon: Icons.verified_rounded,
                    accentColor: MetaColors.emerald,
                  );

                  if (isDesktop) {
                    return Row(
                      children: [
                        Expanded(child: kpi1),
                        const SizedBox(width: 12),
                        Expanded(child: kpi2),
                        const SizedBox(width: 12),
                        Expanded(child: kpi3),
                        const SizedBox(width: 12),
                        Expanded(child: kpi4),
                        const SizedBox(width: 12),
                        Expanded(child: kpi5),
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
                            const SizedBox(width: 14),
                            Expanded(child: kpi3),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(child: kpi4),
                            const SizedBox(width: 14),
                            Expanded(child: kpi5),
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
                        const SizedBox(height: 12),
                        kpi5,
                      ],
                    );
                  }
                },
              ),
              const SizedBox(height: 24),

              // Banner de Ações de Afiliados
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
                      child: const Icon(Icons.handshake_rounded, color: Color(0xFF818CF8), size: 22),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Rede de Parcerias, Entidades & Afiliados',
                            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Gere links rastreáveis comissionados (ex: CREF, assessorias, influencers) com atribuição direta ao cupom promocional e repasse por Pix.',
                            style: TextStyle(color: Colors.white60, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () => _openPayoutHistoryDialog(),
                      icon: const Icon(Icons.receipt_long_rounded, size: 16, color: MetaColors.emerald),
                      label: const Text('Extrato de Repasses', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF1F2937)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _openCreateOrEditAffiliateDialog(),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Novo Parceiro', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Lista de Afiliados
              Text(
                'Parceiros Cadastrados (${_affiliatesOverview?.affiliates.length ?? 0})',
                style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),

              if (_affiliatesOverview?.affiliates.isEmpty ?? true)
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF1F2937)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.handshake_outlined, size: 48, color: Colors.white38),
                      const SizedBox(height: 12),
                      const Text(
                        'Nenhum parceiro afiliado cadastrado ainda',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Cadastre conselhos regionais, assessorias e parceiros para expandir a base de personals.',
                        style: TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => _openCreateOrEditAffiliateDialog(),
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('Cadastrar Primeiro Parceiro'),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _affiliatesOverview!.affiliates.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final affiliate = _affiliatesOverview!.affiliates[index];
                    return _buildAffiliateCard(affiliate);
                  },
                ),
              const SizedBox(height: 32),
            ],
          ],
        ),
      ),
    );
  }

  // ==========================================
  // Card de Parceiro Afiliado
  // ==========================================
  Widget _buildAffiliateCard(AdminAffiliatePartnerItem affiliate) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: affiliate.isActive ? const Color(0xFF1F2937) : Colors.amber.withValues(alpha: 0.3),
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
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      affiliate.partnerName,
                      style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        affiliate.partnerTypeLabel.toUpperCase(),
                        style: const TextStyle(color: Color(0xFF818CF8), fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: affiliate.isActive
                            ? MetaColors.emerald.withValues(alpha: 0.12)
                            : Colors.amber.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: affiliate.isActive
                              ? MetaColors.emerald.withValues(alpha: 0.4)
                              : Colors.amber.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        affiliate.isActive ? 'ATIVO' : 'PAUSADO',
                        style: TextStyle(
                          color: affiliate.isActive ? MetaColors.emerald : Colors.amber,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Switch(
                    value: affiliate.isActive,
                    onChanged: (val) => _toggleAffiliateActive(affiliate, val),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Link de Indicação com Botão de Copiar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF090D16),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF1F2937)),
            ),
            child: Row(
              children: [
                const Icon(Icons.link_rounded, color: Color(0xFF818CF8), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    affiliate.referralUrl,
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace'),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (affiliate.associatedCouponCode != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: MetaColors.emerald.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: MetaColors.emerald.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      '🏷️ ${affiliate.associatedCouponCode}',
                      style: const TextStyle(color: MetaColors.emerald, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 18, color: Color(0xFF818CF8)),
                  tooltip: 'Copiar link de indicação',
                  onPressed: () => _copyReferralLink(affiliate.referralUrl),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Métricas de Performance em Grid
          Wrap(
            spacing: 16,
            runSpacing: 10,
            children: [
              _buildMetricChip(
                label: 'Comissão',
                value: '${affiliate.commissionPercent.toStringAsFixed(1)}%',
                subtitle: 'por conversão',
                color: Colors.cyanAccent,
              ),
              _buildMetricChip(
                label: 'Cliques Recebidos',
                value: '${affiliate.clicksCount}',
                subtitle: 'acessos únicos',
                color: const Color(0xFF818CF8),
              ),
              _buildMetricChip(
                label: 'Conversões',
                value: '${affiliate.conversionsCount}',
                subtitle: 'personals ativos',
                color: MetaColors.emerald,
              ),
              _buildMetricChip(
                label: 'Taxa de Conversão',
                value: '${affiliate.conversionRate.toStringAsFixed(1)}%',
                subtitle: 'cliques em vendas',
                color: Colors.amber,
              ),
              _buildMetricChip(
                label: 'Receita Gerada',
                value: affiliate.formattedRevenue,
                subtitle: 'GMV total',
                color: Colors.white,
              ),
              _buildMetricChip(
                label: 'Comissão Devida',
                value: affiliate.formattedCommission,
                subtitle: 'saldo a pagar',
                color: affiliate.hasPendingCommission ? const Color(0xFFF43F5E) : Colors.white38,
              ),
              _buildMetricChip(
                label: 'Total Liquidado',
                value: affiliate.formattedPaidCommission,
                subtitle: 'pago via Pix',
                color: MetaColors.emerald,
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
              Expanded(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    if (affiliate.contactEmail != null)
                      Text(
                        '✉️ ${affiliate.contactEmail}',
                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    if (affiliate.pixKey != null)
                      Text(
                        '🔑 Pix: ${affiliate.pixKey}',
                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (affiliate.payouts.isNotEmpty) ...[
                    IconButton(
                      onPressed: () => _openPayoutHistoryDialog(affiliate),
                      icon: const Icon(Icons.receipt_long_rounded, size: 18, color: MetaColors.emerald),
                      tooltip: 'Ver Recibos de Repasse (${affiliate.payouts.length})',
                    ),
                    const SizedBox(width: 4),
                  ],
                  ElevatedButton.icon(
                    onPressed: () => _openPayoutDialog(affiliate),
                    icon: const Icon(Icons.payments_rounded, size: 14),
                    label: Text(
                      affiliate.hasPendingCommission ? 'Liquidar Pix' : 'Repassar Pix',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: affiliate.hasPendingCommission ? MetaColors.emerald : const Color(0xFF1F2937),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    onPressed: () => _deleteAffiliate(affiliate),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                    tooltip: 'Excluir Parceiro',
                  ),
                  const SizedBox(width: 4),
                  ElevatedButton.icon(
                    onPressed: () => _openCreateOrEditAffiliateDialog(affiliate),
                    icon: const Icon(Icons.edit_rounded, size: 14),
                    label: const Text('Editar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
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
                mainAxisSize: MainAxisSize.min,
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
              Expanded(
                child: Text(
                  '${plan.subscriberCount} treinadores inscritos neste plano',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
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
