import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../main.dart';
import '../../models/subscription_model.dart';
import '../../services/subscription_service.dart';

class TrainerPlanSelectionScreen extends StatefulWidget {
  final String trainerName;
  final String? trainerEmail;

  const TrainerPlanSelectionScreen({
    super.key,
    required this.trainerName,
    this.trainerEmail,
  });

  @override
  State<TrainerPlanSelectionScreen> createState() =>
      _TrainerPlanSelectionScreenState();
}

class _TrainerPlanSelectionScreenState
    extends State<TrainerPlanSelectionScreen> {
  bool _isLoading = true;
  bool _isYearly = false;
  List<PlanModel> _plans = [];

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    setState(() => _isLoading = true);
    final plans = await SubscriptionService.getPlans();
    if (mounted) {
      setState(() {
        _plans = plans;
        _isLoading = false;
      });
    }
  }

  Future<void> _proceedToApp({
    required String planId,
    required String planName,
  }) async {
    try {
      await SubscriptionService.activatePlan(
        planId: planId,
        billingInterval: _isYearly ? 'yearly' : 'monthly',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green.shade800,
          content: Text(
            '🎉 Plano $planName ativado com sucesso! Bem-vindo ao Mr. Coach.',
          ),
        ),
      );

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder:
                (_) => MainShellScreen(
                  initialIndex: 0,
                  activeRole: 'trainer',
                  userName: widget.trainerName,
                ),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade800,
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    }
  }

  void _openCheckout(PlanModel plan) {
    if (plan.id == 'starter') {
      _proceedToApp(planId: 'starter', planName: 'Starter Free');
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => _CheckoutModal(
            plan: plan,
            isYearly: _isYearly,
            trainerName: widget.trainerName,
            trainerEmail: widget.trainerEmail ?? 'treinador@demo.com',
            onSuccess: () async {
              Navigator.pop(ctx);
              try {
                await SubscriptionService.getMySubscription();
                if (!mounted) return;
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) => MainShellScreen(
                          initialIndex: 0,
                          activeRole: 'trainer',
                          userName: widget.trainerName,
                        ),
                  ),
                  (route) => false,
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: Colors.red.shade800,
                    content: Text(
                      e.toString().replaceFirst('Exception: ', ''),
                      style: const TextStyle(color: Colors.white),
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
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          TextButton(
            onPressed:
                () =>
                    _proceedToApp(planId: 'starter', planName: 'Starter Free'),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Pular para Modo Grátis',
                  style: TextStyle(
                    color: AppColors.subtext(context),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: AppColors.subtext(context),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body:
          _isLoading
              ? Center(
                child: CircularProgressIndicator(
                  color: AppColors.emerald(context),
                ),
              )
              : SafeArea(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  children: [
                    // Header
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
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
                          '🚀 BOAS-VINDAS AO MR. COACH',
                          style: TextStyle(
                            color: AppColors.emerald(context),
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Profile Photo Space
                    Center(
                      child: GestureDetector(
                        onTap: () {
                          // Opcionalmente abriria câmera ou galeria
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: AppColors.emerald(context),
                              content: const Text(
                                'Funcionalidade de upload de foto (Câmera/Galeria) será implementada em breve.',
                              ),
                            ),
                          );
                        },
                        child: Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            color: AppColors.card(context),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.emerald(context),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.emerald(
                                  context,
                                ).withValues(alpha: 0.15),
                                blurRadius: 15,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Icon(
                              Icons.add_a_photo_rounded,
                              size: 32,
                              color: AppColors.emerald(context),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        'Adicionar Foto de Perfil',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.emerald(context),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    Text(
                      'Olá, Prof. ${widget.trainerName}!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: AppColors.text(context),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Escolha o modelo ideal para iniciar sua consultoria com IA biomecânica.\nVocê pode começar 100% grátis ou acelerar com benefícios Pro.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.subtext(context),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Toggle Mensal / Anual
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

                    // Plans List
                    ..._plans.map((p) => _buildPlanCard(p)),
                    const SizedBox(height: 30),
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

  Widget _buildPlanCard(PlanModel plan) {
    final isFree = plan.id == 'starter';
    final isPopular = plan.isPopular;
    final isElite = plan.id == 'elite';
    final primaryColor =
        isPopular
            ? AppColors.emerald(context)
            : (isFree
                ? Colors.blueAccent
                : (isElite ? const Color(0xFFF59E0B) : Colors.purpleAccent));

    final price =
        _isYearly ? plan.priceYearlyMonthlyEquivalent : plan.priceMonthly;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color:
              isPopular
                  ? AppColors.emerald(context)
                  : AppColors.cardBorder(context),
          width: isPopular ? 2 : 1,
        ),
        boxShadow:
            isPopular
                ? [
                  BoxShadow(
                    color: AppColors.emerald(context).withValues(alpha: 0.12),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
                : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Badge
          if (plan.badge != null)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color:
                    isPopular
                        ? AppColors.emerald(context)
                        : primaryColor.withValues(alpha: 0.2),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(18),
                ),
              ),
              child: Text(
                plan.badge!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isPopular ? Colors.black : primaryColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  letterSpacing: 0.8,
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      plan.name,
                      style: TextStyle(
                        color: AppColors.text(context),
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                      ),
                    ),
                    if (isFree)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.blueAccent.withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Text(
                          'Sem Cartão',
                          style: TextStyle(
                            color: Colors.blueAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  plan.tagline,
                  style: TextStyle(
                    color: AppColors.subtext(context),
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 16),

                // Price display
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      isFree ? 'R\$ 0' : 'R\$ ${price.toStringAsFixed(0)}',
                      style: TextStyle(
                        color: AppColors.text(context),
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.8,
                      ),
                    ),
                    Text(
                      isFree ? ' / vitalício' : ' / mês',
                      style: TextStyle(
                        color: AppColors.subtext(context),
                        fontSize: 13,
                      ),
                    ),
                    if (_isYearly && !isFree) ...[
                      const SizedBox(width: 8),
                      Text(
                        'cobrado anualmente (R\$ ${plan.priceYearlyTotal.toStringAsFixed(0)})',
                        style: TextStyle(
                          color: AppColors.emerald(context),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 20),

                // Features list
                ...plan.features.map(
                  (f) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          f.included
                              ? Icons.check_circle_rounded
                              : Icons.cancel_outlined,
                          size: 18,
                          color:
                              f.included
                                  ? (f.highlight
                                      ? AppColors.emerald(context)
                                      : Colors.green)
                                  : AppColors.subtext(
                                    context,
                                  ).withValues(alpha: 0.4),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            f.title,
                            style: TextStyle(
                              color:
                                  f.included
                                      ? AppColors.text(context)
                                      : AppColors.subtext(
                                        context,
                                      ).withValues(alpha: 0.5),
                              fontSize: 13,
                              fontWeight:
                                  f.highlight
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Button CTA
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isPopular
                              ? AppColors.emerald(context)
                              : (isFree
                                  ? AppColors.pillBg(context)
                                  : primaryColor),
                      foregroundColor:
                          (isPopular || isElite)
                              ? Colors.black
                              : (isFree
                                  ? AppColors.text(context)
                                  : Colors.white),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side:
                            isFree
                                ? BorderSide(
                                  color: AppColors.pillBorder(context),
                                  width: 1.5,
                                )
                                : BorderSide.none,
                      ),
                    ),
                    onPressed: () => _openCheckout(plan),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isFree
                              ? Icons.rocket_launch_rounded
                              : Icons.lock_open_rounded,
                          size: 18,
                          color:
                              (isPopular || isElite)
                                  ? Colors.black
                                  : (isFree
                                      ? AppColors.text(context)
                                      : Colors.white),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isFree
                              ? 'Começar Gratuitamente (3 Alunos)'
                              : 'Assinar ${plan.name}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color:
                                (isPopular || isElite)
                                    ? Colors.black
                                    : (isFree
                                        ? AppColors.text(context)
                                        : Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckoutModal extends StatefulWidget {
  final PlanModel plan;
  final bool isYearly;
  final String trainerName;
  final String trainerEmail;
  final VoidCallback onSuccess;

  const _CheckoutModal({
    required this.plan,
    required this.isYearly,
    required this.trainerName,
    required this.trainerEmail,
    required this.onSuccess,
  });

  @override
  State<_CheckoutModal> createState() => _CheckoutModalState();
}

class _CheckoutModalState extends State<_CheckoutModal> {
  String _paymentMethod = 'pix'; // 'pix' ou 'credit_card'
  bool _isProcessing = false;
  CheckoutSessionModel? _session;

  @override
  void initState() {
    super.initState();
    _generateCheckout();
  }

  Future<void> _generateCheckout() async {
    setState(() => _isProcessing = true);
    final session = await SubscriptionService.createCheckoutSession(
      planId: widget.plan.id,
      billingInterval: widget.isYearly ? 'yearly' : 'monthly',
      paymentMethod: _paymentMethod,
    );
    if (mounted) {
      setState(() {
        _session = session;
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final price =
        widget.isYearly
            ? widget.plan.priceYearlyTotal
            : widget.plan.priceMonthly;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.cardBorder(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Icon(
                  Icons.verified_user_rounded,
                  color: AppColors.emerald(context),
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Ativação • ${widget.plan.name}',
                    style: TextStyle(
                      color: AppColors.text(context),
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Total: R\$ ${price.toStringAsFixed(2)} / ${widget.isYearly ? 'ano' : 'mês'}',
              style: TextStyle(
                color: AppColors.emerald(context),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 20),

            // Payment Methods Tabs
            Row(
              children: [
                Expanded(
                  child: _buildMethodTab(
                    id: 'pix',
                    label: 'Pix Instantâneo',
                    icon: Icons.pix_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMethodTab(
                    id: 'credit_card',
                    label: 'Cartão de Crédito',
                    icon: Icons.credit_card_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            if (_isProcessing)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_session != null) ...[
              if (_paymentMethod == 'pix') ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.pillBg(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.pillBorder(context)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Copie o código Pix abaixo e pague no app do seu banco:',
                        style: TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        _session!.pixCopyPaste ??
                            '00020126580014br.gov.bcb.pix...',
                        style: const TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.pillBg(context),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Ambiente seguro PCI-DSS com cobrança mensal automática no cartão.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // Confirm Button (Simulation / Real)
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.emerald(context),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: widget.onSuccess,
                  child: const Text(
                    'Confirmar Pagamento e Iniciar',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMethodTab({
    required String id,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _paymentMethod == id;
    return InkWell(
      onTap: () {
        setState(() => _paymentMethod = id);
        _generateCheckout();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? AppColors.emerald(context).withValues(alpha: 0.15)
                  : AppColors.pillBg(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                isSelected
                    ? AppColors.emerald(context)
                    : AppColors.cardBorder(context),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color:
                  isSelected
                      ? AppColors.emerald(context)
                      : AppColors.subtext(context),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color:
                    isSelected
                        ? AppColors.emerald(context)
                        : AppColors.text(context),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
