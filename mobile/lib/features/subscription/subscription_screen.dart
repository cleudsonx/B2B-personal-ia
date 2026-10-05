import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/widgets/meta_components.dart';
import '../../models/subscription_model.dart';
import '../../services/subscription_service.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _isLoading = true;
  bool _isYearly = false;
  List<PlanModel> _plans = [];
  MySubscriptionModel? _mySubscription;

  @override
  void initState() {
    super.initState();
    SubscriptionService.activeSubscriptionNotifier.addListener(
      _onSubscriptionChanged,
    );
    _loadData();
  }

  @override
  void dispose() {
    SubscriptionService.activeSubscriptionNotifier.removeListener(
      _onSubscriptionChanged,
    );
    super.dispose();
  }

  void _onSubscriptionChanged() {
    if (mounted) {
      final updated = SubscriptionService.activeSubscriptionNotifier.value;
      if (updated != null && updated != _mySubscription) {
        setState(() {
          _mySubscription = updated;
        });
      }
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final allPlans = await SubscriptionService.getPlans();
    final sub = await SubscriptionService.getMySubscription();
    if (mounted) {
      // Priorizar os 4 planos canônicos: Starter, Pro e Studio
      final targetIds = ['starter', 'pro', 'elite', 'studio'];
      final filteredPlans = <PlanModel>[];
      for (final id in targetIds) {
        final p = allPlans.firstWhere(
          (item) => item.id == id,
          orElse: () => allPlans.first,
        );
        if (!filteredPlans.contains(p)) {
          filteredPlans.add(p);
        }
      }

      setState(() {
        _plans = filteredPlans.isNotEmpty ? filteredPlans : allPlans;
        _mySubscription = sub;
        _isLoading = false;
      });
    }
  }

  void _selectPlan(PlanModel plan) {
    if (plan.id == 'starter' || plan.priceMonthlyCents == 0) {
      _activateDirectly(plan);
    } else {
      _openCheckout(plan);
    }
  }

  Future<void> _activateDirectly(PlanModel plan) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: MetaColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: MetaColors.border),
            ),
            title: const Row(
              children: [
                Icon(
                  Icons.rocket_launch_rounded,
                  color: MetaColors.emerald,
                  size: 24,
                ),
                SizedBox(width: 10),
                Text(
                  'Ativar Plano Starter',
                  style: TextStyle(
                    color: MetaColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: Text(
              'Deseja ativar o plano gratuito ${plan.name} com limite de até ${plan.maxStudents} alunos e 10 fichas IA mensais?',
              style: const TextStyle(
                color: MetaColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(color: MetaColors.textSecondary),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: MetaColors.emerald,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  'Confirmar Ativação',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
    );

    if (confirm == true && mounted) {
      setState(() => _isLoading = true);
      final updated = await SubscriptionService.activatePlan(
        planId: plan.id,
        billingInterval: _isYearly ? 'yearly' : 'monthly',
      );
      if (mounted) {
        setState(() {
          _mySubscription = updated;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: MetaColors.surfaceHighlight,
            content: Text(
              '🎉 Plano ${plan.name} ativado com sucesso!',
              style: const TextStyle(color: MetaColors.textPrimary),
            ),
          ),
        );
      }
    }
  }

  void _openCheckout(PlanModel plan) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => _CheckoutBottomSheet(
            plan: plan,
            isYearly: _isYearly,
            onSuccess: () async {
              Navigator.pop(ctx);
              setState(() => _isLoading = true);
              final updated = await SubscriptionService.activatePlan(
                planId: plan.id,
                billingInterval: _isYearly ? 'yearly' : 'monthly',
              );
              if (mounted) {
                setState(() {
                  _mySubscription = updated;
                  _isLoading = false;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: MetaColors.surfaceHighlight,
                    content: Text(
                      '🎉 Plano ${plan.name} ativado com sucesso!',
                      style: const TextStyle(color: MetaColors.textPrimary),
                    ),
                  ),
                );
              }
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: MetaColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            color: MetaColors.textPrimary,
            onPressed: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              }
            },
          ),
          title: const Text(
            'Planos & Assinatura',
            style: TextStyle(
              color: MetaColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 18,
              letterSpacing: -0.4,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(
                Icons.refresh_rounded,
                color: MetaColors.textSecondary,
                size: 22,
              ),
              tooltip: 'Atualizar',
              onPressed: _loadData,
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: MetaColors.emerald,
                ),
              )
            : RefreshIndicator(
                onRefresh: _loadData,
                color: MetaColors.emerald,
                backgroundColor: MetaColors.surface,
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 12,
                    bottom: bottomPadding + 32,
                  ),
                  children: [
                    // Card de Status da Assinatura Ativa
                    if (_mySubscription != null) ...[
                      _buildActiveSubscriptionCard(_mySubscription!),
                      const SizedBox(height: 24),
                    ],

                    // Cabeçalho da Seção de Planos
                    Center(
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: MetaColors.surfaceHighlight,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: MetaColors.emerald.withValues(alpha: 0.3),
                              ),
                            ),
                            child: const Text(
                              '💎 PLANOS B2B MR. COACH',
                              style: TextStyle(
                                color: MetaColors.emerald,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Escale sua Consultoria',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: MetaColors.textPrimary,
                              letterSpacing: -0.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Prescrições ilimitadas com IA biomecânica e retenção máxima no salão.',
                            style: TextStyle(
                              color: MetaColors.textSecondary,
                              fontSize: 13,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Alternador Mensal / Anual
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: MetaColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: MetaColors.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildIntervalButton(
                              label: 'Mensal',
                              isSelected: !_isYearly,
                              onTap: () => setState(() => _isYearly = false),
                            ),
                            const SizedBox(width: 4),
                            _buildIntervalButton(
                              label: 'Anual (20% OFF 🎁)',
                              isSelected: _isYearly,
                              isHighlighted: true,
                              onTap: () => setState(() => _isYearly = true),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Cards dos 3 Planos (Starter, Pro, Studio) usando MetaCard
                    ..._plans.map((p) => _buildPlanMetaCard(p)),
                    const SizedBox(height: 16),

                    // FAQ
                    _buildFaqSection(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildIntervalButton({
    required String label,
    required bool isSelected,
    bool isHighlighted = false,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? (isHighlighted ? MetaColors.emerald : MetaColors.surfaceHighlight)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected && !isHighlighted
              ? Border.all(color: MetaColors.border)
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? (isHighlighted ? Colors.white : MetaColors.textPrimary)
                : MetaColors.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildActiveSubscriptionCard(MySubscriptionModel sub) {
    final progress = sub.maxStudents > 0
        ? (sub.currentStudents / sub.maxStudents).clamp(0.0, 1.0)
        : 0.0;

    return MetaCard(
      borderColor: MetaColors.emerald.withValues(alpha: 0.5),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.verified_rounded,
                    color: MetaColors.emerald,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'PLANO ATIVO: ${sub.planName.toUpperCase()}',
                    style: const TextStyle(
                      color: MetaColors.emerald,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: MetaColors.surfaceHighlight,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: MetaColors.emerald.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  sub.status == 'active' ? 'ATIVO' : 'TRIAL',
                  style: const TextStyle(
                    color: MetaColors.emerald,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Informações de Cota
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Alunos Cadastrados: ${sub.currentStudents} / ${sub.maxStudents}',
                style: const TextStyle(
                  color: MetaColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: const TextStyle(
                  color: MetaColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              color: MetaColors.emerald,
              backgroundColor: MetaColors.surfaceHighlight,
            ),
          ),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                sub.nextBillingDate != null
                    ? 'Renovação em: ${sub.nextBillingDate}'
                    : 'Período gratuito ativo',
                style: const TextStyle(
                  color: MetaColors.textSecondary,
                  fontSize: 11,
                ),
              ),
              Text(
                sub.maxAiGenerations == -1
                    ? '✨ Fichas IA: Ilimitadas'
                    : 'Fichas IA: ${sub.aiGenerationsUsed}/${sub.maxAiGenerations}',
                style: const TextStyle(
                  color: MetaColors.accentBlue,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlanMetaCard(PlanModel plan) {
    final isCurrent = _mySubscription?.planId == plan.id;
    final isPro = plan.id == 'pro' || plan.isPopular;
    final isStudio = plan.id == 'studio';
    final price =
        _isYearly ? plan.priceYearlyMonthlyEquivalent : plan.priceMonthly;

    return MetaCard(
      backgroundColor: MetaColors.surface,
      borderColor: isPro ? MetaColors.emerald : MetaColors.border,
      borderRadius: 20.0,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Row: Nome do Plano & Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                plan.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: MetaColors.textPrimary,
                ),
              ),
              if (isPro)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: MetaColors.emerald,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'MAIS ESCOLHIDO',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                      letterSpacing: 0.6,
                    ),
                  ),
                )
              else if (plan.badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: MetaColors.surfaceHighlight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: MetaColors.border),
                  ),
                  child: Text(
                    plan.badge!,
                    style: const TextStyle(
                      color: MetaColors.textSecondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            plan.tagline,
            style: const TextStyle(
              color: MetaColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),

          // Preço
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                price == 0 ? 'Grátis' : 'R\$ ${price.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: isPro ? MetaColors.emerald : MetaColors.textPrimary,
                ),
              ),
              if (price > 0)
                const Text(
                  ' /mês',
                  style: TextStyle(
                    color: MetaColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              if (_isYearly && price > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: MetaColors.surfaceHighlight,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: MetaColors.border),
                  ),
                  child: Text(
                    'Cobrado R\$ ${plan.priceYearlyTotal.toStringAsFixed(0)}/ano',
                    style: const TextStyle(
                      color: MetaColors.emerald,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 18),
          const Divider(color: MetaColors.border, height: 1),
          const SizedBox(height: 16),

          // Lista de Recursos / Features
          ...plan.features.map((f) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(
                    f.included
                        ? Icons.check_circle_rounded
                        : Icons.cancel_outlined,
                    size: 16,
                    color: f.included
                        ? (f.highlight
                            ? MetaColors.emerald
                            : MetaColors.accentBlue)
                        : MetaColors.textSecondary.withValues(alpha: 0.4),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      f.title,
                      style: TextStyle(
                        fontSize: 12,
                        color: f.included
                            ? MetaColors.textPrimary
                            : MetaColors.textSecondary,
                        fontWeight:
                            f.highlight ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 18),

          // Botão de Ação: SquircleButton
          SquircleButton(
            label: isCurrent
                ? '✓ Plano Atual'
                : (plan.priceMonthlyCents == 0
                    ? 'Começar Grátis'
                    : 'Assinar ${plan.name}'),
            isPrimary: isPro && !isCurrent,
            backgroundColor: isCurrent
                ? MetaColors.surfaceHighlight
                : (isPro ? MetaColors.emerald : MetaColors.surfaceHighlight),
            foregroundColor: isCurrent
                ? MetaColors.textSecondary
                : (isPro ? Colors.white : MetaColors.textPrimary),
            onPressed: isCurrent ? null : () => _selectPlan(plan),
          ),
        ],
      ),
    );
  }

  Widget _buildFaqSection() {
    return MetaCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.help_outline_rounded,
                color: MetaColors.accentBlue,
                size: 18,
              ),
              SizedBox(width: 8),
              Text(
                'Perguntas Frequentes',
                style: TextStyle(
                  color: MetaColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildFaqItem(
            'Posso mudar de plano a qualquer momento?',
            'Sim, a alteração é instantânea. Calculamos a diferença de forma proporcional.',
          ),
          _buildFaqItem(
            'Como funciona o Pix instantâneo?',
            'A confirmação acontece em segundos e sua liberação de recursos é imediata.',
          ),
          _buildFaqItem(
            'Há taxa de cancelamento?',
            'Não! Não existe fidelidade no plano mensal e você cancela quando quiser.',
          ),
        ],
      ),
    );
  }

  Widget _buildFaqItem(String question, String answer) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: const TextStyle(
              color: MetaColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            answer,
            style: const TextStyle(
              color: MetaColors.textSecondary,
              fontSize: 11.5,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// CHECKOUT BOTTOM SHEET (PIX & CARTÃO)
// -----------------------------------------------------------------------------
class _CheckoutBottomSheet extends StatefulWidget {
  final PlanModel plan;
  final bool isYearly;
  final VoidCallback onSuccess;

  const _CheckoutBottomSheet({
    required this.plan,
    required this.isYearly,
    required this.onSuccess,
  });

  @override
  State<_CheckoutBottomSheet> createState() => _CheckoutBottomSheetState();
}

class _CheckoutBottomSheetState extends State<_CheckoutBottomSheet> {
  String _paymentMethod = 'pix'; // 'pix' ou 'credit_card'
  bool _isLoading = false;
  bool _isSubmittingCard = false;
  bool _isPaid = false;
  CheckoutSessionModel? _session;
  Timer? _pollingTimer;

  // Controladores do Cartão
  final TextEditingController _cardNumberController = TextEditingController();
  final TextEditingController _cardHolderController = TextEditingController();
  final TextEditingController _expiryController = TextEditingController();
  final TextEditingController _cvvController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _createSession();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _cardNumberController.dispose();
    _cardHolderController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  void _startPixPolling() {
    _pollingTimer?.cancel();
    if (_session == null) return;

    _pollingTimer = Timer.periodic(const Duration(milliseconds: 2500), (
      timer,
    ) async {
      if (!mounted || _isPaid) {
        timer.cancel();
        return;
      }
      final paid = await SubscriptionService.checkPaymentStatus(
        _session!.sessionId,
      );
      if (paid && mounted) {
        timer.cancel();
        setState(() => _isPaid = true);
        HapticFeedback.heavyImpact();
        _showSuccessNotification();
      }
    });
  }

  Future<void> _createSession() async {
    setState(() => _isLoading = true);
    final session = await SubscriptionService.createCheckoutSession(
      planId: widget.plan.id,
      billingInterval: widget.isYearly ? 'yearly' : 'monthly',
      paymentMethod: _paymentMethod,
      provider: 'asaas',
    );
    if (mounted) {
      setState(() {
        _session = session;
        _isLoading = false;
      });
      if (_paymentMethod == 'pix' || _paymentMethod == 'credit_card') {
        _startPixPolling();
      }
    }
  }

  Future<void> _submitInAppCardPayment() async {
    final rawNumber = _cardNumberController.text.replaceAll(RegExp(r'\s+'), '');
    final holder = _cardHolderController.text.trim();
    final expiry = _expiryController.text.trim();
    final cvv = _cvvController.text.trim();

    if (rawNumber.length < 13 || rawNumber.length > 19) {
      _showError('Por favor, digite um número de cartão válido.');
      return;
    }
    if (holder.isEmpty) {
      _showError('Digite o nome impresso no cartão.');
      return;
    }
    if (!expiry.contains('/') || expiry.length < 4) {
      _showError('Digite a validade no formato MM/AA.');
      return;
    }
    if (cvv.length < 3 || cvv.length > 4) {
      _showError('Digite um código CVV válido de 3 ou 4 dígitos.');
      return;
    }

    final parts = expiry.split('/');
    final month = parts[0].trim();
    final year = parts[1].trim();

    setState(() => _isSubmittingCard = true);

    try {
      final res = await SubscriptionService.payWithCardInApp(
        planId: widget.plan.id,
        billingInterval: widget.isYearly ? 'yearly' : 'monthly',
        cardNumber: rawNumber,
        holderName: holder,
        expiryMonth: month,
        expiryYear: year,
        ccv: cvv,
      );

      if (mounted) {
        setState(() => _isSubmittingCard = false);
        if (res['success'] == true) {
          setState(() => _isPaid = true);
          HapticFeedback.heavyImpact();
          _showSuccessNotification();
        } else {
          _showError(res['error'] ?? 'Não foi possível autorizar o cartão.');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmittingCard = false);
        _showError('Falha ao processar pagamento com cartão: $e');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.red.shade800,
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(message, style: const TextStyle(fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }

  void _showSuccessNotification() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: MetaColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: MetaColors.emerald, width: 1.5),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: MetaColors.emerald.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: MetaColors.emerald,
                    size: 54,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '🎉 Pagamento Aprovado!',
                  style: TextStyle(
                    color: MetaColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sua assinatura do plano ${widget.plan.name} já foi ativada com sucesso.',
                  style: const TextStyle(
                    color: MetaColors.textSecondary,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                SquircleButton(
                  label: 'Acessar Meu Painel',
                  isPrimary: true,
                  onPressed: () {
                    Navigator.pop(ctx);
                    widget.onSuccess();
                  },
                ),
              ],
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final amount =
        widget.isYearly
            ? widget.plan.priceYearlyTotal
            : widget.plan.priceMonthly;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: MetaColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: MetaColors.border, width: 1),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: MetaColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Checkout Seguro',
                      style: TextStyle(
                        color: MetaColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.plan.name} • R\$ ${amount.toStringAsFixed(2)}${widget.isYearly ? "/ano (20% OFF)" : "/mês"}',
                      style: const TextStyle(
                        color: MetaColors.emerald,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: MetaColors.textSecondary,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Seletor de Método de Pagamento
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: _buildMethodTab(
                    label: 'PIX Instantâneo',
                    icon: Icons.pix_rounded,
                    isSelected: _paymentMethod == 'pix',
                    activeColor: MetaColors.accentBlue,
                    onTap: () {
                      if (_paymentMethod != 'pix') {
                        setState(() => _paymentMethod = 'pix');
                        _createSession();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMethodTab(
                    label: 'Cartão de Crédito',
                    icon: Icons.credit_card_rounded,
                    isSelected: _paymentMethod == 'credit_card',
                    activeColor: MetaColors.emerald,
                    onTap: () {
                      if (_paymentMethod != 'credit_card') {
                        setState(() => _paymentMethod = 'credit_card');
                        _pollingTimer?.cancel();
                        _createSession();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Conteúdo Dinâmico
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: MetaColors.emerald,
                    ),
                  )
                : SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.only(
                      left: 20,
                      right: 20,
                      bottom: bottomPadding + 20,
                    ),
                    child: _paymentMethod == 'pix'
                        ? _buildPixContent()
                        : _buildCreditCardContent(amount),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMethodTab({
    required String label,
    required IconData icon,
    required bool isSelected,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? MetaColors.surfaceHighlight : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? activeColor : MetaColors.border,
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? activeColor : MetaColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? MetaColors.textPrimary : MetaColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPixContent() {
    final pixCode = _session?.pixCopyPaste ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MetaCard(
          backgroundColor: MetaColors.surfaceHighlight,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.qr_code_2_rounded, color: MetaColors.accentBlue, size: 28),
                  SizedBox(width: 8),
                  Text(
                    'PIX Copia e Cola',
                    style: TextStyle(
                      color: MetaColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Copie o código abaixo e cole no aplicativo do seu banco para pagamento instantâneo:',
                style: TextStyle(
                  color: MetaColors.textSecondary,
                  fontSize: 12.5,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: MetaColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: MetaColors.border),
                ),
                child: Text(
                  pixCode.isNotEmpty
                      ? pixCode
                      : '00020126580014br.gov.bcb.pix0136mrcoach-subscription-pix...',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: MetaColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SquircleButton(
                label: 'Copiar Chave PIX',
                icon: Icons.copy_rounded,
                isPrimary: true,
                onPressed: () {
                  Clipboard.setData(
                    ClipboardData(
                      text: pixCode.isNotEmpty
                          ? pixCode
                          : '00020126580014br.gov.bcb.pix0136mrcoach-subscription-pix',
                    ),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: MetaColors.surfaceHighlight,
                      content: Text(
                        'Código PIX copiado com sucesso!',
                        style: TextStyle(color: MetaColors.textPrimary),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: MetaColors.emerald,
              ),
            ),
            SizedBox(width: 8),
            Text(
              'Aguardando confirmação do banco...',
              style: TextStyle(
                color: MetaColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCreditCardContent(double amount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _cardNumberController,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: MetaColors.textPrimary),
          decoration: const InputDecoration(
            labelText: 'Número do Cartão',
            prefixIcon: Icon(
              Icons.credit_card_rounded,
              color: MetaColors.textSecondary,
              size: 20,
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _cardHolderController,
          style: const TextStyle(color: MetaColors.textPrimary),
          decoration: const InputDecoration(
            labelText: 'Nome no Cartão',
            prefixIcon: Icon(
              Icons.person_outline_rounded,
              color: MetaColors.textSecondary,
              size: 20,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _expiryController,
                keyboardType: TextInputType.datetime,
                style: const TextStyle(color: MetaColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Validade (MM/AA)',
                  prefixIcon: Icon(
                    Icons.date_range_outlined,
                    color: MetaColors.textSecondary,
                    size: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _cvvController,
                keyboardType: TextInputType.number,
                obscureText: true,
                style: const TextStyle(color: MetaColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'CVV',
                  prefixIcon: Icon(
                    Icons.security_outlined,
                    color: MetaColors.textSecondary,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        SquircleButton(
          label: 'Confirmar Pagamento de R\$ ${amount.toStringAsFixed(2)}',
          isPrimary: true,
          isLoading: _isSubmittingCard,
          onPressed: _submitInAppCardPayment,
        ),
      ],
    );
  }
}



