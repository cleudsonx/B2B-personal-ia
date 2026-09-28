import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
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
    _loadData();
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

  void _openCheckout(PlanModel plan) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CheckoutBottomSheet(
        plan: plan,
        isYearly: _isYearly,
        onSuccess: () {
          Navigator.pop(ctx);
          _loadData();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.green.shade800,
              content: Text('🎉 Plano ${plan.name} ativado com sucesso!'),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.trainerBg,
      appBar: AppBar(
        title: const Text('Planos & Assinatura B2B'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar Assinatura',
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.trainerEmerald),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              color: AppColors.trainerEmerald,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.trainerEmerald.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.trainerEmerald.withValues(alpha: 0.4)),
                          ),
                          child: const Text(
                            '💎 PLANOS COMERCIAIS B2B',
                            style: TextStyle(
                              color: AppColors.trainerEmerald,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Escale sua Consultoria de Personal',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Prescrições com IA biomecânica ilimitadas e retenção de alunos no salão.',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
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
                        color: AppColors.trainerSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.trainerBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildIntervalButton(label: 'Mensal', isSelected: !_isYearly, onTap: () => setState(() => _isYearly = false)),
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
          color: isSelected
              ? (isHighlighted ? AppColors.trainerEmerald : AppColors.trainerSurfaceElevated)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected && !isHighlighted
              ? Border.all(color: AppColors.trainerBorder)
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? (isHighlighted ? Colors.black : Colors.white)
                : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildActiveSubscriptionCard(MySubscriptionModel sub) {
    final progress = sub.maxStudents > 0 ? (sub.currentStudents / sub.maxStudents).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF0F231D),
            const Color(0xFF0A121A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.trainerEmerald.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: AppColors.trainerEmerald.withValues(alpha: 0.12),
            blurRadius: 18,
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
                  const Icon(Icons.verified, color: AppColors.trainerEmerald, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'PLANO ATIVO: ${sub.planName.toUpperCase()}',
                    style: const TextStyle(
                      color: AppColors.trainerEmerald,
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
                  color: AppColors.trainerEmerald.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  sub.status == 'active' ? 'ATIVO' : 'TRIAL',
                  style: const TextStyle(color: AppColors.trainerEmerald, fontSize: 10, fontWeight: FontWeight.bold),
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
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              color: AppColors.trainerEmerald,
              backgroundColor: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                sub.nextBillingDate != null ? 'Renovação em: ${sub.nextBillingDate}' : 'Período gratuito ativo',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
              Text(
                sub.maxAiGenerations == -1 ? '✨ Fichas IA: Ilimitadas' : 'Fichas IA: ${sub.aiGenerationsUsed}/${sub.maxAiGenerations}',
                style: const TextStyle(color: AppColors.studentCyan, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(PlanModel plan) {
    final isCurrent = _mySubscription?.planId == plan.id;
    final isPro = plan.isPopular;
    final borderColor = isPro ? AppColors.trainerEmerald : AppColors.trainerBorder;
    final price = _isYearly ? plan.priceYearlyMonthlyEquivalent : plan.priceMonthly;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: AppColors.trainerSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: borderColor,
          width: isPro ? 1.8 : 1.0,
        ),
        boxShadow: isPro
            ? [
                BoxShadow(
                  color: AppColors.trainerEmerald.withValues(alpha: 0.12),
                  blurRadius: 20,
                  spreadRadius: 1,
                ),
              ]
            : null,
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
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (plan.badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isPro ? AppColors.trainerEmerald : AppColors.trainerIndigo,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      plan.badge!,
                      style: const TextStyle(
                        color: Colors.black,
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
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
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
                    color: isPro ? AppColors.trainerEmerald : AppColors.textPrimary,
                  ),
                ),
                if (price > 0)
                  const Text(
                    ' /mês',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                if (_isYearly && price > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.studentAmber.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Cobrado R\$ ${plan.priceYearlyTotal.toStringAsFixed(0)}/ano',
                      style: const TextStyle(color: AppColors.studentAmber, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 18),
            const Divider(color: AppColors.trainerBorder, height: 1),
            const SizedBox(height: 16),

            // Feature Checklist
            ...plan.features.map((f) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Icon(
                      f.included ? Icons.check_circle_rounded : Icons.cancel_outlined,
                      size: 16,
                      color: f.included
                          ? (f.highlight ? AppColors.trainerEmerald : AppColors.studentCyan)
                          : AppColors.textMuted.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        f.title,
                        style: TextStyle(
                          fontSize: 12,
                          color: f.included ? AppColors.textPrimary : AppColors.textMuted,
                          fontWeight: f.highlight ? FontWeight.bold : FontWeight.normal,
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
                backgroundColor: isCurrent
                    ? AppColors.trainerSurfaceElevated
                    : (isPro ? AppColors.trainerEmerald : AppColors.trainerIndigo),
                foregroundColor: isCurrent
                    ? AppColors.textSecondary
                    : (isPro ? Colors.black : Colors.white),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: isPro && !isCurrent ? 4 : 0,
              ),
              onPressed: isCurrent ? null : () => _openCheckout(plan),
              child: Text(
                isCurrent
                    ? '✓ Seu Plano Atual'
                    : (plan.priceMonthlyCents == 0 ? 'Começar Grátis' : 'Assinar ${plan.name}'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
        color: AppColors.trainerSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.trainerBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.help_outline_rounded, color: AppColors.studentCyan, size: 18),
              SizedBox(width: 8),
              Text(
                'Perguntas Frequentes',
                style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildFaqItem('Posso cancelar quando quiser?', 'Sim. Não há período de carência ou fidelidade. Você pode cancelar sua assinatura mensal ou anual com 1 clique a qualquer momento.'),
          const Divider(color: AppColors.trainerBorder),
          _buildFaqItem('O meu aluno paga para usar?', 'Não. O aplicativo do aluno no salão é 100% gratuito. Todo o custo do motor de inteligência artificial é coberto pela sua assinatura de Personal Trainer.'),
          const Divider(color: AppColors.trainerBorder),
          _buildFaqItem('Quais formas de pagamento são aceitas?', 'Aceitamos Pix com ativação imediata (chave copia e cola / QR Code) e todos os cartões de crédito com renovação automática.'),
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
          Text(question, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 3),
          Text(answer, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, height: 1.35)),
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

class _CheckoutBottomSheetState extends State<_CheckoutBottomSheet> {
  String _paymentMethod = 'pix'; // 'pix' ou 'credit_card'
  bool _isLoading = false;
  CheckoutSessionModel? _session;

  @override
  void initState() {
    super.initState();
    _createSession();
  }

  Future<void> _createSession() async {
    setState(() => _isLoading = true);
    final session = await SubscriptionService.createCheckoutSession(
      planId: widget.plan.id,
      billingInterval: widget.isYearly ? 'yearly' : 'monthly',
      paymentMethod: _paymentMethod,
    );
    if (mounted) {
      setState(() {
        _session = session;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final amount = widget.isYearly ? widget.plan.priceYearlyTotal : widget.plan.priceMonthly;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF090D16),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: Color(0xFF1E293B), width: 1.5)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Assinar ${widget.plan.name}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(
                      'R\$ ${amount.toStringAsFixed(2)} • ${widget.isYearly ? "Cobrança Anual (20% OFF)" : "Mensalidade"}',
                      style: const TextStyle(color: AppColors.trainerEmerald, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                IconButton(icon: const Icon(Icons.close, color: AppColors.textMuted), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Payment Method Selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: _buildPaymentMethodTab(
                    label: 'PIX Instantâneo',
                    icon: Icons.pix_rounded,
                    isSelected: _paymentMethod == 'pix',
                    activeColor: AppColors.studentCyan,
                    onTap: () {
                      setState(() => _paymentMethod = 'pix');
                      _createSession();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildPaymentMethodTab(
                    label: 'Cartão de Crédito',
                    icon: Icons.credit_card_rounded,
                    isSelected: _paymentMethod == 'credit_card',
                    activeColor: AppColors.trainerEmerald,
                    onTap: () {
                      setState(() => _paymentMethod = 'credit_card');
                      _createSession();
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.trainerEmerald))
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _paymentMethod == 'pix' ? _buildPixContent() : _buildCreditCardContent(),
                  ),
          ),

          // Confirm Action
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF070B12),
              border: Border(top: BorderSide(color: Color(0xFF161E2E))),
            ),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.trainerEmerald,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: widget.onSuccess,
              child: Text(
                _paymentMethod == 'pix' ? '✓ Já Realizei o Pix (Confirmar Ativação)' : 'Pagar R\$ ${amount.toStringAsFixed(2)} e Ativar',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodTab({
    required String label,
    required IconData icon,
    required bool isSelected,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.15) : const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? activeColor : const Color(0xFF1E293B)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: isSelected ? activeColor : AppColors.textMuted),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? activeColor : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPixContent() {
    final pixCode = _session?.pixCopyPaste ?? 'pix-demo-code';

    return Column(
      children: [
        // QR Code Simulated Container
        Container(
          width: 180,
          height: 180,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.studentCyan, width: 2),
            boxShadow: [
              BoxShadow(
                color: AppColors.studentCyan.withValues(alpha: 0.2),
                blurRadius: 16,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.qr_code_2_rounded, size: 110, color: Colors.black),
              const SizedBox(height: 4),
              const Text(
                'PIX BANCO CENTRAL',
                style: TextStyle(color: Colors.black54, fontSize: 9, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Escaneie o QR Code acima ou use o código Copia e Cola:',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),

        // Pix Copia e Cola Input with Copy Button
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF1F2937)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  pixCode,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontFamily: 'monospace'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, color: AppColors.studentCyan, size: 18),
                tooltip: 'Copiar código Pix',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: pixCode));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: Colors.green,
                      content: Text('Chave Pix copiada para a área de transferência!'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bolt, color: AppColors.studentAmber, size: 16),
            SizedBox(width: 4),
            Text(
              'Aprovação automática em até 10 segundos',
              style: TextStyle(color: AppColors.studentAmber, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCreditCardContent() {
    return Column(
      children: [
        TextField(
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Número do Cartão',
            labelStyle: const TextStyle(color: AppColors.textSecondary),
            prefixIcon: const Icon(Icons.credit_card, color: AppColors.trainerEmerald, size: 20),
            filled: true,
            fillColor: const Color(0xFF111827),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Validade (MM/AA)',
                  labelStyle: const TextStyle(color: AppColors.textSecondary),
                  filled: true,
                  fillColor: const Color(0xFF111827),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'CVV',
                  labelStyle: const TextStyle(color: AppColors.textSecondary),
                  filled: true,
                  fillColor: const Color(0xFF111827),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Nome Impresso no Cartão',
            labelStyle: const TextStyle(color: AppColors.textSecondary),
            prefixIcon: const Icon(Icons.person_outline, color: AppColors.trainerEmerald, size: 20),
            filled: true,
            fillColor: const Color(0xFF111827),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 12),
        const Row(
          children: [
            Icon(Icons.lock_outline, size: 14, color: AppColors.textMuted),
            SizedBox(width: 6),
            Text(
              'Transação criptografada de ponta a ponta (PCI-DSS)',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ],
        ),
      ],
    );
  }
}
