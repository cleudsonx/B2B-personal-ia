import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/theme_toggle_button.dart';
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
    final plans = await SubscriptionService.getPlans();
    final sub = await SubscriptionService.getMySubscription();
    if (mounted) {
      setState(() {
        _plans = plans;
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
            backgroundColor: AppColors.card(context),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: AppColors.cardBorder(context)),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.rocket_launch_rounded,
                  color: AppColors.emerald(context),
                ),
                const SizedBox(width: 8),
                Text(
                  'Ativar ${plan.name}',
                  style: TextStyle(
                    color: AppColors.text(context),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            content: Text(
              'Deseja ativar o plano gratuito ${plan.name} com limite de até ${plan.maxStudents} alunos e 10 fichas IA mensais?',
              style: TextStyle(color: AppColors.subtext(context), fontSize: 13),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  'Cancelar',
                  style: TextStyle(color: AppColors.subtext(context)),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.emerald(context),
                  foregroundColor: Colors.black,
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
            backgroundColor: Colors.green.shade800,
            content: Text('🎉 Plano ${plan.name} ativado com sucesso!'),
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
                    backgroundColor: Colors.green.shade800,
                    content: Text('🎉 Plano ${plan.name} ativado com sucesso!'),
                  ),
                );
              }
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Planos & Assinatura B2B',
          style: TextStyle(
            color: AppColors.text(context),
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        actions: [
          const ThemeToggleButton(),
          const SizedBox(width: 4),
          IconButton(
            icon: Icon(
              Icons.refresh_rounded,
              color: AppColors.subtext(context),
            ),
            tooltip: 'Atualizar Assinatura',
            onPressed: _loadData,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body:
          _isLoading
              ? Center(
                child: CircularProgressIndicator(
                  color: AppColors.emerald(context),
                ),
              )
              : RefreshIndicator(
                onRefresh: _loadData,
                color: AppColors.emerald(context),
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  children: [
                    // Active Plan Status Card
                    if (_mySubscription != null) ...[
                      _buildActiveSubscriptionCard(_mySubscription!),
                      const SizedBox(height: 24),
                    ],

                    // Header Titles
                    Center(
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.emeraldBg(context),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.emerald(
                                  context,
                                ).withValues(alpha: 0.4),
                              ),
                            ),
                            child: Text(
                              '💎 PLANOS COMERCIAIS B2B',
                              style: TextStyle(
                                color: AppColors.emerald(context),
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Escale sua Consultoria de Personal',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: AppColors.text(context),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Prescrições com IA biomecânica ilimitadas e retenção de alunos no salão.',
                            style: TextStyle(
                              color: AppColors.subtext(context),
                              fontSize: 13,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Billing Interval Toggle (Mensal vs Anual)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.card(context),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.cardBorder(context),
                          ),
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

                    // Plans Cards
                    ..._plans.map((p) => _buildPlanCard(p)),
                    const SizedBox(height: 20),

                    // FAQ Section
                    _buildFaqSection(),
                    const SizedBox(height: 40),
                  ],
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
          color:
              isSelected
                  ? (isHighlighted
                      ? AppColors.emerald(context)
                      : AppColors.pillBg(context))
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border:
              isSelected && !isHighlighted
                  ? Border.all(color: AppColors.pillBorder(context))
                  : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color:
                isSelected
                    ? (isHighlighted ? Colors.black : AppColors.text(context))
                    : AppColors.subtext(context),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildActiveSubscriptionCard(MySubscriptionModel sub) {
    final isDark = AppColors.isDark(context);
    final progress =
        sub.maxStudents > 0
            ? (sub.currentStudents / sub.maxStudents).clamp(0.0, 1.0)
            : 0.0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.emerald(context).withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : const Color(0x060F172A),
            blurRadius: 18,
            offset: const Offset(0, 4),
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
                  Icon(
                    Icons.verified,
                    color: AppColors.emerald(context),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'PLANO ATIVO: ${sub.planName.toUpperCase()}',
                    style: TextStyle(
                      color: AppColors.emerald(context),
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
                  color: AppColors.emeraldBg(context),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  sub.status == 'active' ? 'ATIVO' : 'TRIAL',
                  style: TextStyle(
                    color: AppColors.emerald(context),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Quota Info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Alunos Cadastrados: ${sub.currentStudents} / ${sub.maxStudents}',
                style: TextStyle(
                  color: AppColors.text(context),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: TextStyle(
                  color: AppColors.subtext(context),
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
              color: AppColors.emerald(context),
              backgroundColor: AppColors.pillBg(context),
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
                style: TextStyle(
                  color: AppColors.subtext(context),
                  fontSize: 11,
                ),
              ),
              Text(
                sub.maxAiGenerations == -1
                    ? '✨ Fichas IA: Ilimitadas'
                    : 'Fichas IA: ${sub.aiGenerationsUsed}/${sub.maxAiGenerations}',
                style: TextStyle(
                  color: AppColors.accentBlue(context),
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

  Widget _buildPlanCard(PlanModel plan) {
    final isDark = AppColors.isDark(context);
    final isCurrent = _mySubscription?.planId == plan.id;
    final isPro = plan.isPopular;
    final isElite = plan.id == 'elite';
    final isStudio = plan.id == 'studio';
    final borderColor =
        isPro
            ? AppColors.emerald(context)
            : (isElite
                ? const Color(0xFFF59E0B)
                : (isStudio
                    ? const Color(0xFF8B5CF6)
                    : AppColors.cardBorder(context)));
    final price =
        _isYearly ? plan.priceYearlyMonthlyEquivalent : plan.priceMonthly;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: borderColor,
          width: (isPro || isElite || isStudio) ? 1.8 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : const Color(0x060F172A),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Row (Name & Badge)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  plan.name,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.text(context),
                  ),
                ),
                if (plan.badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isPro
                              ? AppColors.emerald(context)
                              : (isElite
                                  ? const Color(0xFFF59E0B)
                                  : (isStudio
                                      ? const Color(0xFF8B5CF6)
                                      : AppColors.accentBlue(context))),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      plan.badge!,
                      style: TextStyle(
                        color: (isPro || isElite) ? Colors.black : Colors.white,
                        fontWeight: FontWeight.w900,
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
              style: TextStyle(color: AppColors.subtext(context), fontSize: 12),
            ),
            const SizedBox(height: 16),

            // Price Display
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  price == 0 ? 'Grátis' : 'R\$ ${price.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color:
                        isPro
                            ? AppColors.emerald(context)
                            : (isElite
                                ? const Color(0xFFF59E0B)
                                : (isStudio
                                    ? const Color(0xFFA78BFA)
                                    : AppColors.text(context))),
                  ),
                ),
                if (price > 0)
                  Text(
                    ' /mês',
                    style: TextStyle(
                      color: AppColors.subtext(context),
                      fontSize: 13,
                    ),
                  ),
                if (_isYearly && price > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.tangerineBg(context),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Cobrado R\$ ${plan.priceYearlyTotal.toStringAsFixed(0)}/ano',
                      style: TextStyle(
                        color: AppColors.tangerine(context),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 18),
            Divider(color: AppColors.cardBorder(context), height: 1),
            const SizedBox(height: 16),

            // Feature Checklist
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
                      color:
                          f.included
                              ? (f.highlight
                                  ? AppColors.emerald(context)
                                  : AppColors.accentBlue(context))
                              : AppColors.subtext(
                                context,
                              ).withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        f.title,
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              f.included
                                  ? AppColors.text(context)
                                  : AppColors.subtext(context),
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

            // Action Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isCurrent
                        ? AppColors.pillBg(context)
                        : (isPro
                            ? AppColors.emerald(context)
                            : (isElite
                                ? const Color(0xFFF59E0B)
                                : (isStudio
                                    ? const Color(0xFF8B5CF6)
                                    : AppColors.accentBlue(context)))),
                foregroundColor:
                    isCurrent
                        ? AppColors.subtext(context)
                        : ((isPro || isElite) ? Colors.black : Colors.white),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: (isPro || isElite || isStudio) && !isCurrent ? 4 : 0,
              ),
              onPressed: isCurrent ? null : () => _selectPlan(plan),
              child: Text(
                isCurrent
                    ? '✓ Seu Plano Atual'
                    : (plan.priceMonthlyCents == 0
                        ? 'Começar Grátis'
                        : 'Assinar ${plan.name}'),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFaqSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.help_outline_rounded,
                color: AppColors.accentBlue(context),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Perguntas Frequentes',
                style: TextStyle(
                  color: AppColors.text(context),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildFaqItem(
            'Posso cancelar quando quiser?',
            'Sim. Não há período de carência ou fidelidade. Você pode cancelar sua assinatura mensal ou anual com 1 clique a qualquer momento.',
          ),
          Divider(color: AppColors.cardBorder(context)),
          _buildFaqItem(
            'O meu aluno paga para usar?',
            'Não. O aplicativo do aluno no salão é 100% gratuito. Todo o custo do motor de inteligência artificial é coberto pela sua assinatura de Personal Trainer.',
          ),
          Divider(color: AppColors.cardBorder(context)),
          _buildFaqItem(
            'Quais formas de pagamento são aceitas?',
            'Aceitamos Pix com ativação imediata (chave copia e cola / QR Code) e todos os cartões de crédito com renovação automática.',
          ),
        ],
      ),
    );
  }

  Widget _buildFaqItem(String question, String answer) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: TextStyle(
              color: AppColors.text(context),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            answer,
            style: TextStyle(
              color: AppColors.subtext(context),
              fontSize: 11,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// CHECKOUT MODAL (PIX & CARTÃO)
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

class _CheckoutBottomSheetState extends State<_CheckoutBottomSheet>
    with SingleTickerProviderStateMixin {
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
  final FocusNode _cvvFocusNode = FocusNode();

  // Animação 3D de Giro do Cartão
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _flipAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOutBack),
    );

    _cvvFocusNode.addListener(() {
      if (_cvvFocusNode.hasFocus) {
        _flipController.forward();
      } else {
        _flipController.reverse();
      }
    });

    _cardNumberController.addListener(() => setState(() {}));
    _cardHolderController.addListener(() => setState(() {}));
    _expiryController.addListener(() => setState(() {}));
    _cvvController.addListener(() => setState(() {}));

    _createSession();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _flipController.dispose();
    _cardNumberController.dispose();
    _cardHolderController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _cvvFocusNode.dispose();
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

  Future<void> _openCardCheckout() async {
    final url = _session?.checkoutUrl;
    if (url == null || url.isEmpty) {
      _showError(
        'Link de checkout seguro não disponível no momento. Tente novamente.',
      );
      return;
    }
    final uri = Uri.parse(url);
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
      _startPixPolling();
    } catch (e) {
      _showError('Não foi possível abrir o navegador: $e');
    }
  }

  Future<void> _verifyCardPayment() async {
    if (_session == null) return;
    setState(() => _isSubmittingCard = true);
    final paid = await SubscriptionService.checkPaymentStatus(
      _session!.sessionId,
    );
    if (mounted) {
      setState(() => _isSubmittingCard = false);
      if (paid) {
        setState(() => _isPaid = true);
        HapticFeedback.heavyImpact();
        _showSuccessNotification();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFFD97706),
            content: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Pagamento ainda não confirmado pelo Asaas. Se já realizou a transação, aguarde alguns instantes.',
                    style: TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        );
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
        backgroundColor: Colors.red.shade900,
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
            backgroundColor: AppColors.card(context),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: Color(0xFF10B981), width: 2),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF10B981),
                    size: 54,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '🎉 Pagamento Aprovado!',
                  style: TextStyle(
                    color: AppColors.text(context),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sua assinatura do plano ${widget.plan.name} já foi ativada com sucesso.',
                  style: TextStyle(
                    color: AppColors.subtext(context),
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    widget.onSuccess();
                  },
                  child: const Text(
                    'Acessar Meu Painel',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  String _detectCardBrand(String number) {
    final clean = number.replaceAll(RegExp(r'\s+'), '');
    if (clean.startsWith('4')) return 'VISA';
    if (RegExp(
      r'^(5[1-5]|222[1-9]|22[3-9]|2[3-6]|27[0-1]|2720)',
    ).hasMatch(clean))
      return 'MASTERCARD';
    if (clean.startsWith('34') || clean.startsWith('37')) return 'AMEX';
    if (RegExp(r'^(4011|4389|5041|6363|5067|4576|4011)').hasMatch(clean))
      return 'ELO';
    if (clean.startsWith('6062')) return 'HIPERCARD';
    return 'CARTÃO';
  }

  @override
  Widget build(BuildContext context) {
    final amount =
        widget.isYearly
            ? widget.plan.priceYearlyTotal
            : widget.plan.priceMonthly;

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: AppColors.cardBorder(context), width: 1.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 30,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: AppColors.subtext(context).withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 14),

          // Header Topo
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Checkout Seguro',
                          style: TextStyle(
                            color: AppColors.text(context),
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF10B981,
                            ).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: const Color(
                                0xFF10B981,
                              ).withValues(alpha: 0.4),
                            ),
                          ),
                          child: const Text(
                            '🛡️ Asaas SSL 256-bit',
                            style: TextStyle(
                              color: Color(0xFF10B981),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.plan.name} • R\$ ${amount.toStringAsFixed(2)}${widget.isYearly ? "/ano (20% OFF)" : "/mês"}',
                      style: TextStyle(
                        color: AppColors.emerald(context),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: AppColors.subtext(context),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Seletor de Método de Pagamento
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Row(
              children: [
                Expanded(
                  child: _buildMethodTab(
                    label: 'PIX Instantâneo',
                    icon: Icons.pix_rounded,
                    isSelected: _paymentMethod == 'pix',
                    activeColor: AppColors.accentBlue(context),
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
                    label: 'Cartão 3D Recorrente',
                    icon: Icons.credit_card_rounded,
                    isSelected: _paymentMethod == 'credit_card',
                    activeColor: AppColors.emerald(context),
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

          // Card de ROI de Negócio
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: _buildRoiCard(context, amount),
          ),
          const SizedBox(height: 12),

          // Conteúdo Dinâmico
          Expanded(
            child:
                _isLoading
                    ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            color: AppColors.emerald(context),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Gerando sessão de pagamento segura...',
                            style: TextStyle(
                              color: AppColors.subtext(context),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    )
                    : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      child:
                          _paymentMethod == 'pix'
                              ? _buildPixContent(context)
                              : _buildCreditCardContent(context, amount),
                    ),
          ),

          // Rodapé Fixo de Ação
          if (_paymentMethod == 'credit_card')
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.card(context),
                border: Border(
                  top: BorderSide(color: AppColors.cardBorder(context)),
                ),
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.emerald(context),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 4,
                ),
                onPressed: _isSubmittingCard ? null : _submitInAppCardPayment,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isSubmittingCard) ...[
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Tokenizando e Ativando Assinatura...',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          color: Colors.black,
                        ),
                      ),
                    ] else ...[
                      const Icon(
                        Icons.flash_on_rounded,
                        size: 18,
                        color: Colors.black,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Ativar Assinatura In-App • R\$ ${amount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ],
                ),
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
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? activeColor.withValues(alpha: 0.16)
                  : AppColors.card(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? activeColor : AppColors.cardBorder(context),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? activeColor : AppColors.subtext(context),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? activeColor : AppColors.text(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoiCard(BuildContext context, double amount) {
    final netGain = (150.0 - (amount > 150 ? amount / 2 : amount)).clamp(
      10.0,
      999.0,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.trending_up_rounded,
              color: Color(0xFF10B981),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '💡 RETORNO SOBRE O INVESTIMENTO',
                  style: TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Com apenas 1 novo aluno a R\$ 150/mês, seu plano se paga e sobra R\$ ${netGain.toStringAsFixed(0)}/mês de lucro!',
                  style: TextStyle(
                    color: AppColors.text(context),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPixContent(BuildContext context) {
    final pixCode = _session?.pixCopyPaste ?? 'pix-demo-code';

    return Column(
      children: [
        const SizedBox(height: 6),
        // QR Code Container
        Container(
          width: 180,
          height: 180,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF06B6D4), width: 2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF06B6D4).withValues(alpha: 0.2),
                blurRadius: 20,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.qr_code_2_rounded,
                size: 110,
                color: Colors.black,
              ),
              const SizedBox(height: 4),
              const Text(
                'PIX BANCO CENTRAL • ASAAS',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Escaneie o QR Code no seu banco ou use a chave Copia e Cola:',
          style: TextStyle(color: AppColors.subtext(context), fontSize: 12),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),

        // Copia e Cola
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.card(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.cardBorder(context)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  pixCode,
                  style: TextStyle(
                    color: AppColors.subtext(context),
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.copy_rounded,
                  color: Color(0xFF06B6D4),
                  size: 18,
                ),
                tooltip: 'Copiar Pix Copia e Cola',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: pixCode));
                  HapticFeedback.lightImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: Color(0xFF10B981),
                      content: Text('Chave Pix copiada com sucesso!'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Radar de Polling Ativo
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  color: Color(0xFFF59E0B),
                  strokeWidth: 2,
                ),
              ),
              SizedBox(width: 8),
              Text(
                'Aguardando pagamento no banco... Reconhecimento automático!',
                style: TextStyle(
                  color: Color(0xFFF59E0B),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () async {
            final sessionId = _session?.sessionId;
            if (sessionId == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Sessão de pagamento não identificada.'),
                  backgroundColor: Color(0xFFEF4444),
                ),
              );
              return;
            }
            final isPaid = await SubscriptionService.checkPaymentStatus(
              sessionId,
            );
            if (isPaid) {
              widget.onSuccess();
            } else {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Aguardando compensação do Pix pelo banco. Tente novamente em alguns segundos.',
                  ),
                  backgroundColor: Color(0xFFF59E0B),
                  duration: Duration(seconds: 4),
                ),
              );
            }
          },
          child: Text(
            'Já paguei pelo aplicativo do banco (Verificar Pagamento)',
            style: TextStyle(
              color: AppColors.emerald(context),
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildCreditCardContent(BuildContext context, double amount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 6),
        // CARTÃO VIRTUAL 3D INTERATIVO (Gira 180° no foco do CVV)
        _buildInteractive3DCard(context),
        const SizedBox(height: 20),

        // CAMPOS DE ENTRADA DO CARTÃO (100% IN-APP & NATIVO)
        Text(
          'DADOS DO CARTÃO DE CRÉDITO',
          style: TextStyle(
            color: AppColors.subtext(context),
            fontSize: 10.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),

        // Número do Cartão
        _buildCheckoutInputField(
          context: context,
          controller: _cardNumberController,
          label: 'Número do Cartão',
          hintText: '0000 0000 0000 0000',
          icon: Icons.credit_card_rounded,
          keyboardType: TextInputType.number,
          maxLength: 19,
          onChanged: (val) {
            final clean = val.replaceAll(' ', '');
            if (clean.length <= 16) {
              final formatted =
                  clean
                      .replaceAllMapped(
                        RegExp(r'.{1,4}'),
                        (match) => '${match.group(0)} ',
                      )
                      .trim();
              if (formatted != val) {
                _cardNumberController.value = TextEditingValue(
                  text: formatted,
                  selection: TextSelection.collapsed(offset: formatted.length),
                );
              }
            }
            setState(() {});
          },
        ),
        const SizedBox(height: 12),

        // Nome Impresso no Cartão
        _buildCheckoutInputField(
          context: context,
          controller: _cardHolderController,
          label: 'Nome Impresso no Cartão',
          hintText: 'COMO ESTÁ NO CARTÃO',
          icon: Icons.person_outline_rounded,
          keyboardType: TextInputType.name,
          textCapitalization: TextCapitalization.characters,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),

        // Linha: Validade + CVV
        Row(
          children: [
            Expanded(
              child: _buildCheckoutInputField(
                context: context,
                controller: _expiryController,
                label: 'Validade',
                hintText: 'MM/AA',
                icon: Icons.calendar_today_rounded,
                keyboardType: TextInputType.number,
                maxLength: 5,
                onChanged: (val) {
                  final clean = val.replaceAll('/', '');
                  if (clean.length == 2 && !val.contains('/')) {
                    _expiryController.value = TextEditingValue(
                      text: '$clean/',
                      selection: const TextSelection.collapsed(offset: 3),
                    );
                  }
                  setState(() {});
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildCheckoutInputField(
                context: context,
                controller: _cvvController,
                focusNode: _cvvFocusNode,
                label: 'CVV / CVC',
                hintText: '•••',
                icon: Icons.lock_outline_rounded,
                keyboardType: TextInputType.number,
                maxLength: 4,
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Selo de Tokenização Segura In-App
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF10B981).withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.shield_outlined,
                color: Color(0xFF10B981),
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Tokenização bancária direta Asaas (TLS 1.3). Seus dados não são gravados no dispositivo.',
                  style: TextStyle(
                    color: AppColors.subtext(context),
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Link alternativo para abrir o checkout web se preferir
        Center(
          child: TextButton.icon(
            onPressed: _openCardCheckout,
            icon: Icon(
              Icons.open_in_new_rounded,
              size: 14,
              color: AppColors.subtext(context),
            ),
            label: Text(
              'Prefiro pagar no checkout web externo da Asaas',
              style: TextStyle(
                color: AppColors.subtext(context),
                fontSize: 11.5,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
        Center(
          child: TextButton.icon(
            onPressed: _isSubmittingCard ? null : _verifyCardPayment,
            icon: Icon(
              Icons.refresh_rounded,
              size: 14,
              color: AppColors.subtext(context),
            ),
            label: Text(
              'Já paguei pelo link externo (Verificar Aprovação)',
              style: TextStyle(color: AppColors.subtext(context), fontSize: 11),
            ),
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _buildCheckoutInputField({
    required BuildContext context,
    required TextEditingController controller,
    required String label,
    required String hintText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    FocusNode? focusNode,
    int? maxLength,
    TextCapitalization textCapitalization = TextCapitalization.none,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.text(context),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: keyboardType,
          maxLength: maxLength,
          textCapitalization: textCapitalization,
          onChanged: onChanged,
          buildCounter:
              (_, {required currentLength, required isFocused, maxLength}) =>
                  null,
          style: TextStyle(
            color: AppColors.text(context),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(
              color: AppColors.subtext(context).withValues(alpha: 0.5),
              fontSize: 13,
            ),
            prefixIcon: Icon(icon, color: AppColors.emerald(context), size: 18),
            filled: true,
            fillColor: AppColors.bg(context),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.cardBorder(context)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.cardBorder(context)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppColors.emerald(context),
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInteractive3DCard(BuildContext context) {
    return AnimatedBuilder(
      animation: _flipAnimation,
      builder: (context, child) {
        final angle = _flipAnimation.value * math.pi;
        final isFront = angle < (math.pi / 2);

        return Transform(
          transform:
              Matrix4.identity()
                ..setEntry(3, 2, 0.0015)
                ..rotateY(angle),
          alignment: Alignment.center,
          child: isFront ? _buildCardFront(context) : _buildCardBack(context),
        );
      },
    );
  }

  Widget _buildCardFront(BuildContext context) {
    final number =
        _cardNumberController.text.isEmpty
            ? '•••• •••• •••• ••••'
            : _cardNumberController.text;
    final holder =
        _cardHolderController.text.isEmpty
            ? 'NOME DO TITULAR'
            : _cardHolderController.text.toUpperCase();
    final expiry =
        _expiryController.text.isEmpty ? 'MM/AA' : _expiryController.text;
    final brand = _detectCardBrand(_cardNumberController.text);

    return Container(
      width: 320,
      height: 185,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF064E3B), Color(0xFF047857)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Topo: Chip + Contactless + Bandeira
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  // Chip Metálico
                  Container(
                    width: 36,
                    height: 26,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAB308),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Colors.amber.shade200,
                        width: 1,
                      ),
                      gradient: LinearGradient(
                        colors: [Colors.amber.shade300, Colors.amber.shade700],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.contactless_rounded,
                    color: Colors.white70,
                    size: 22,
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  brand,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),

          // Número
          Text(
            number,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              letterSpacing: 2.2,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w700,
              shadows: [Shadow(color: Colors.black, blurRadius: 4)],
            ),
          ),

          // Rodapé: Titular e Validade
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TITULAR',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      holder,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'VALIDADE',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    expiry,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
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

  Widget _buildCardBack(BuildContext context) {
    final cvv = _cvvController.text.isEmpty ? '•••' : _cvvController.text;

    return Transform(
      transform: Matrix4.identity()..rotateY(math.pi),
      alignment: Alignment.center,
      child: Container(
        width: 320,
        height: 185,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: const Color(0xFF0F172A),
          border: Border.all(
            color: const Color(0xFF10B981).withValues(alpha: 0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            const SizedBox(height: 22),
            // Faixa Magnética
            Container(height: 38, color: Colors.black),
            const SizedBox(height: 18),

            // Tarja de Assinatura + CVV
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Container(
                      height: 34,
                      color: Colors.white70,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 8),
                      child: const Text(
                        'MR. COACH',
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 10,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Container(
                      height: 34,
                      color: Colors.white,
                      alignment: Alignment.center,
                      child: Text(
                        cvv,
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'ASAAS RECURRENT BILLED',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
