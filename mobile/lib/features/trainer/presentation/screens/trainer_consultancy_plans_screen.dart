// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import '../../../../core/widgets/meta_components.dart';
import '../../../../services/consultancy_plan_service.dart';
import '../../../../core/utils/currency_pt_br_formatter.dart';

class TrainerConsultancyPlansScreen extends StatefulWidget {
  const TrainerConsultancyPlansScreen({super.key});

  @override
  State<TrainerConsultancyPlansScreen> createState() => _TrainerConsultancyPlansScreenState();
}

class _TrainerConsultancyPlansScreenState extends State<TrainerConsultancyPlansScreen> {
  bool _isLoading = true;
  List<ConsultancyPlan> _plans = [];

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    setState(() => _isLoading = true);
    try {
      final list = await ConsultancyPlanService.getMyPlans();
      if (mounted) {
        setState(() {
          _plans = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _togglePlanStatus(ConsultancyPlan plan, bool newStatus) async {
    setState(() {
      final idx = _plans.indexWhere((p) => p.id == plan.id);
      if (idx != -1) {
        _plans[idx] = ConsultancyPlan(
          id: plan.id,
          trainerId: plan.trainerId,
          name: plan.name,
          description: plan.description,
          priceCents: plan.priceCents,
          billingPeriod: plan.billingPeriod,
          features: plan.features,
          isActive: newStatus,
          sortOrder: plan.sortOrder,
          createdAt: plan.createdAt,
          updatedAt: plan.updatedAt,
        );
      }
    });

    try {
      await ConsultancyPlanService.updatePlan(planId: plan.id, isActive: newStatus);
    } catch (_) {
      _loadPlans();
    }
  }

  void _openPlanEditor({ConsultancyPlan? existingPlan}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: MetaColors.card(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _PlanEditorModal(
        existingPlan: existingPlan,
        onSaved: () {
          Navigator.pop(ctx);
          _loadPlans();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                existingPlan == null ? 'Plano criado com sucesso!' : 'Plano atualizado com sucesso!',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              backgroundColor: MetaColors.emerald,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(ConsultancyPlan plan) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MetaColors.card(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Excluir Plano', style: TextStyle(color: MetaColors.text(context))),
        content: Text(
          'Deseja realmente remover o plano "${plan.name}" da sua vitrine?',
          style: TextStyle(color: MetaColors.subtext(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: TextStyle(color: MetaColors.subtext(context))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ConsultancyPlanService.deletePlan(plan.id);
        _loadPlans();
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MetaColors.bg(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_ios_new, color: MetaColors.text(context), size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Planos de Consultoria',
                      style: TextStyle(
                        color: MetaColors.text(context),
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.refresh, color: MetaColors.subtext(context)),
                    onPressed: _loadPlans,
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: MetaColors.emerald))
                  : ListView(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.paddingOf(context).bottom + 24),
                      children: [
                        // Banner informativo de Split & Carteira
                        MetaCard(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: MetaColors.emerald.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.account_balance_wallet, color: MetaColors.emerald, size: 24),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Venda Direta na sua Vitrine',
                                      style: TextStyle(
                                        color: MetaColors.text(context),
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Seus alunos assinam via Pix ou Cartão no Asaas. Você recebe 95% líquido na sua Carteira do Personal e saca quando quiser.',
                                      style: TextStyle(
                                        color: MetaColors.subtext(context),
                                        fontSize: 13,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Seus Planos Configurados',
                              style: TextStyle(
                                color: MetaColors.text(context),
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${_plans.length} planos',
                              style: TextStyle(color: MetaColors.subtext(context), fontSize: 13),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        if (_plans.isEmpty)
                          MetaCard(
                            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                            child: Column(
                              children: [
                                Icon(Icons.inventory_2_outlined, color: MetaColors.subtext(context).withValues(alpha: 0.5), size: 48),
                                const SizedBox(height: 12),
                                Text(
                                  'Nenhum plano cadastrado',
                                  style: TextStyle(color: MetaColors.text(context), fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Crie seu primeiro plano para que futuros alunos possam contratar pela sua Vitrine Pública.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: MetaColors.subtext(context), fontSize: 13),
                                ),
                              ],
                            ),
                          )
                        else
                          ..._plans.map((plan) => _buildPlanCard(plan)),

                        const SizedBox(height: 80),
                      ],
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: MetaColors.card(context),
          border: Border(top: BorderSide(color: MetaColors.cardBorder(context), width: 0.5)),
        ),
        child: SquircleButton(
          label: 'Adicionar Novo Plano',
          icon: Icons.add,
          isPrimary: true,
          onPressed: () => _openPlanEditor(),
        ),
      ),
    );
  }

  Widget _buildPlanCard(ConsultancyPlan plan) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: MetaCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Periodicidade Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: plan.isActive
                        ? MetaColors.emerald.withValues(alpha: 0.15)
                        : Colors.grey.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    plan.billingPeriodLabel.toUpperCase(),
                    style: TextStyle(
                      color: plan.isActive ? MetaColors.emerald : MetaColors.subtext(context),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const Spacer(),
                // Toggle Ativo/Inativo
                Row(
                  children: [
                    Text(
                      plan.isActive ? 'Ativo' : 'Pausado',
                      style: TextStyle(
                        color: plan.isActive ? MetaColors.emerald : MetaColors.subtext(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Transform.scale(
                      scale: 0.75,
                      child: Switch(
                        value: plan.isActive,
                        activeThumbColor: MetaColors.emerald,
                        onChanged: (val) => _togglePlanStatus(plan, val),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Nome e Preço
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(
                    plan.name,
                    style: TextStyle(
                      color: MetaColors.text(context),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  'R\$ ${plan.price.toStringAsFixed(2).replaceAll('.', ',')}',
                  style: TextStyle(
                    color: MetaColors.text(context),
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (plan.billingPeriod != 'one_time')
                  Text(
                    ' /mês',
                    style: TextStyle(color: MetaColors.subtext(context), fontSize: 12),
                  ),
              ],
            ),

            if (plan.description != null && plan.description!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                plan.description!,
                style: TextStyle(color: MetaColors.subtext(context), fontSize: 13, height: 1.35),
              ),
            ],

            if (plan.features.isNotEmpty) ...[
              const SizedBox(height: 12),
              Divider(color: MetaColors.cardBorder(context)),
              const SizedBox(height: 8),
              ...plan.features.map(
                (feat) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle_rounded, color: MetaColors.emerald, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          feat,
                          style: TextStyle(color: MetaColors.text(context), fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _confirmDelete(plan),
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                  label: const Text('Excluir', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _openPlanEditor(existingPlan: plan),
                  icon: Icon(Icons.edit_outlined, size: 18, color: MetaColors.text(context)),
                  label: Text('Editar', style: TextStyle(color: MetaColors.text(context), fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanEditorModal extends StatefulWidget {
  final ConsultancyPlan? existingPlan;
  final VoidCallback onSaved;

  const _PlanEditorModal({this.existingPlan, required this.onSaved});

  @override
  State<_PlanEditorModal> createState() => _PlanEditorModalState();
}

class _PlanEditorModalState extends State<_PlanEditorModal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _priceCtrl;
  late String _billingPeriod;
  late List<String> _features;
  final TextEditingController _newFeatureCtrl = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.existingPlan;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _descCtrl = TextEditingController(text: p?.description ?? '');
    _priceCtrl = TextEditingController(text: CurrencyPtBrFormatter.format(p?.price ?? 150.0, includeSymbol: false));
    _billingPeriod = p?.billingPeriod ?? 'monthly';
    _features = p != null
        ? List.from(p.features)
        : [
            'Prescrição biomecânica completa no app',
            'Substituição inteligente de exercícios',
            'Suporte tira-dúvidas via WhatsApp',
          ];
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _newFeatureCtrl.dispose();
    super.dispose();
  }

  void _addFeature() {
    final text = _newFeatureCtrl.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        _features.add(text);
        _newFeatureCtrl.clear();
      });
    }
  }

  void _removeFeature(int idx) {
    setState(() => _features.removeAt(idx));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final priceVal = CurrencyPtBrFormatter.parse(_priceCtrl.text);
    final priceCents = (priceVal * 100).round();

    if (priceCents < 1000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('O valor mínimo é R\$ 10,00.'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      if (widget.existingPlan == null) {
        await ConsultancyPlanService.createPlan(
          name: _nameCtrl.text.trim(),
          description: _descCtrl.text.trim().isNotEmpty ? _descCtrl.text.trim() : null,
          priceCents: priceCents,
          billingPeriod: _billingPeriod,
          features: _features,
        );
      } else {
        await ConsultancyPlanService.updatePlan(
          planId: widget.existingPlan!.id,
          name: _nameCtrl.text.trim(),
          description: _descCtrl.text.trim().isNotEmpty ? _descCtrl.text.trim() : null,
          priceCents: priceCents,
          billingPeriod: _billingPeriod,
          features: _features,
        );
      }
      widget.onSaved();
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.existingPlan == null ? 'Novo Plano de Consultoria' : 'Editar Plano',
                    style: TextStyle(
                      color: MetaColors.text(context),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: MetaColors.subtext(context)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Nome do Plano
              Text('Nome do Plano', style: TextStyle(color: MetaColors.subtext(context), fontSize: 13)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nameCtrl,
                style: TextStyle(color: MetaColors.text(context)),
                decoration: InputDecoration(
                  hintText: 'Ex: Consultoria Mensal Pro',
                  hintStyle: const TextStyle(color: Colors.white30),
                  filled: true,
                  fillColor: MetaColors.highlight(context),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o nome do plano' : null,
              ),
              const SizedBox(height: 14),

              // Preço e Periodicidade
              Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Preço (R\$)', style: TextStyle(color: MetaColors.subtext(context), fontSize: 13)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _priceCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: const [CurrencyPtBrInputFormatter(includeSymbol: false)],
                          style: TextStyle(color: MetaColors.text(context), fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            prefixText: 'R\$ ',
                            prefixStyle: const TextStyle(color: MetaColors.emerald, fontWeight: FontWeight.bold),
                            filled: true,
                            fillColor: MetaColors.highlight(context),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Informe o valor';
                            if (CurrencyPtBrFormatter.parse(v) <= 0) return 'Valor deve ser maior que zero';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Periodicidade', style: TextStyle(color: MetaColors.subtext(context), fontSize: 13)),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: MetaColors.highlight(context),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _billingPeriod,
                              dropdownColor: MetaColors.card(context),
                              style: TextStyle(color: MetaColors.text(context), fontSize: 14),
                              isExpanded: true,
                              items: const [
                                DropdownMenuItem(value: 'monthly', child: Text('Mensal')),
                                DropdownMenuItem(value: 'quarterly', child: Text('Trimestral')),
                                DropdownMenuItem(value: 'semiannual', child: Text('Semestral')),
                                DropdownMenuItem(value: 'annual', child: Text('Anual')),
                                DropdownMenuItem(value: 'one_time', child: Text('Ficha Avulsa')),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => _billingPeriod = val);
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

              // Descrição
              Text('Descrição Curta', style: TextStyle(color: MetaColors.subtext(context), fontSize: 13)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _descCtrl,
                maxLines: 2,
                style: TextStyle(color: MetaColors.text(context)),
                decoration: InputDecoration(
                  hintText: 'Ex: Acompanhamento individualizado com foco em hipertrofia.',
                  hintStyle: const TextStyle(color: Colors.white30),
                  filled: true,
                  fillColor: MetaColors.highlight(context),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),

              // Benefícios / Features
              Text('Diferenciais Inclusos', style: TextStyle(color: MetaColors.subtext(context), fontSize: 13)),
              const SizedBox(height: 8),
              ..._features.asMap().entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.check, color: MetaColors.emerald, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(entry.value, style: TextStyle(color: MetaColors.text(context), fontSize: 13)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 18),
                        onPressed: () => _removeFeature(entry.key),
                      ),
                    ],
                  ),
                );
              }),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _newFeatureCtrl,
                      style: TextStyle(color: MetaColors.text(context), fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Novo benefício (ex: Análise de vídeo)',
                        hintStyle: const TextStyle(color: Colors.white30),
                        isDense: true,
                        filled: true,
                        fillColor: MetaColors.highlight(context),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      ),
                      onSubmitted: (_) => _addFeature(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: MetaColors.emerald, size: 28),
                    onPressed: _addFeature,
                  ),
                ],
              ),

              const SizedBox(height: 24),
              SquircleButton(
                label: _isSaving ? 'Salvando...' : 'Salvar Plano',
                icon: Icons.check,
                isPrimary: true,
                onPressed: _isSaving ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
