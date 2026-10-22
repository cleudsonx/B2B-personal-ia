import '../../services/referral_service.dart';
// ignore_for_file: unused_element, unused_local_variable, unused_field, override_on_non_overriding_member, use_build_context_synchronously
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/widgets/meta_components.dart';
import 'presentation/screens/pix_payment_screen.dart';
import '../../models/subscription_model.dart';
import '../../services/subscription_service.dart';
import '../../services/auth_service.dart';

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
  String? _loadError;

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
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final allPlans = await SubscriptionService.getPlans();
      final sub = await SubscriptionService.refreshMySubscription();
      if (!mounted) return;
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
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Não foi possível carregar sua assinatura.';
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
      try {
        final updated = await SubscriptionService.activatePlan(
          planId: plan.id,
          billingInterval: _isYearly ? 'yearly' : 'monthly',
        );
        if (!mounted) return;
        setState(() => _mySubscription = updated);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: MetaColors.surfaceHighlight,
            content: Text('Plano ${plan.name} ativado pelo servidor.'),
          ),
        );
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Não foi possível ativar o plano: $error')),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _openCheckout(PlanModel plan) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final sheetRoute = ModalRoute.of(ctx);
        return _CheckoutBottomSheet(
            plan: plan,
            isYearly: _isYearly,
            onSuccess: () async {
              final navigator = Navigator.of(ctx);
              if (sheetRoute != null) {
                navigator.popUntil((route) => route == sheetRoute);
              }
              navigator.pop();
              setState(() => _isLoading = true);
              try {
                final updated =
                    await SubscriptionService.refreshMySubscription();
                if (updated.planId != plan.id) {
                  throw StateError(
                    'O pagamento foi confirmado, mas o plano ainda está sendo atualizado.',
                  );
                }
                if (!mounted) return;
                setState(() => _mySubscription = updated);
                try {
                  ReferralService.recordReferralConversion(
                    planId: plan.id,
                    amountBrl: _isYearly ? plan.priceYearlyTotal : plan.priceMonthly,
                  );
                } catch (_) {}
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: MetaColors.surfaceHighlight,
                    content: Text('Plano ${plan.name} confirmado pelo servidor.'),
                  ),
                );
              } catch (error) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(error.toString().replaceFirst('Bad state: ', ''))),
                  );
                }
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
          );
      },
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
            : _loadError != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _loadError!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: MetaColors.textSecondary),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _loadData,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Tentar novamente'),
                          ),
                        ],
                      ),
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
    // final isStudio = plan.id == 'studio';
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
class CardDeclineFeedback {
  final String title;
  final String message;
  final List<String> commonReasons;
  final String actionTip;
  final bool isFraudOrBlock;

  const CardDeclineFeedback({
    required this.title,
    required this.message,
    required this.commonReasons,
    required this.actionTip,
    this.isFraudOrBlock = false,
  });

  factory CardDeclineFeedback.fromError(String rawError, double amount) {
    final lower = rawError.toLowerCase();
    final amountFormatted = 'R\$ ${amount.toStringAsFixed(2)}';

    if (lower.contains('saldo') || lower.contains('limite') || lower.contains('insuficiente') || lower.contains('insufficient')) {
      return CardDeclineFeedback(
        title: 'Limite Insuficiente no Cartão',
        message: 'A operadora do cartão recusou a cobrança de $amountFormatted por limite indisponível.',
        commonReasons: [
          'Limite de crédito total atingido no momento',
          'Limite diário para compras online atingido',
        ],
        actionTip: 'Dica: você pode pagar via PIX Instantâneo agora para ativar seu plano imediatamente.',
      );
    }

    if (lower.contains('cvv') || lower.contains('segurança') || lower.contains('security code') || lower.contains('código')) {
      return CardDeclineFeedback(
        title: 'Código de Segurança (CVV) Incorreto',
        message: 'O código de segurança de 3 dígitos (ou 4 para Amex) não conferiu com a emissora.',
        commonReasons: [
          'Dígito digitado incorretamente',
          'Cartão virtual com código dinâmico que expirou',
        ],
        actionTip: 'Verifique no app do seu banco o CVV atualizado do seu cartão virtual.',
      );
    }

    if (lower.contains('validade') || lower.contains('expirad') || lower.contains('vencid') || lower.contains('expiry')) {
      return CardDeclineFeedback(
        title: 'Data de Validade Incorreta ou Vencida',
        message: 'A data de validade informada (MM/AA) foi recusada pela operadora.',
        commonReasons: [
          'Cartão físico ou virtual já expirou',
          'Mês ou ano digitados invertidos',
        ],
        actionTip: 'Confira a validade impressa ou gere um novo cartão virtual no app do banco.',
      );
    }

    if (lower.contains('cpf') || lower.contains('cnpj') || lower.contains('titular')) {
      return CardDeclineFeedback(
        title: 'CPF/CNPJ do Titular Divergente',
        message: 'O documento do titular precisa ser exatamente o mesmo registrado no banco emissor.',
        commonReasons: [
          'Cartão emitido em nome de outra pessoa ou CNPJ corporativo',
          'Dígitos do CPF/CNPJ digitados incorretamente',
        ],
        actionTip: 'Informe o CPF do titular exato deste cartão ou utilize o PIX com o seu documento.',
      );
    }

    return CardDeclineFeedback(
      title: 'Compra Não Autorizada pelo Seu Banco',
      message: 'A emissora do seu cartão (ex: Itaú, Nubank, Bradesco) recusou a cobrança de $amountFormatted.',
      commonReasons: [
        'Bloqueio temporário para novas assinaturas ou compras online no app do banco',
        'Bloqueio preventivo de segurança (antifraude do banco)',
        'Cartão virtual desativado ou com limite diário atingido',
      ],
      actionTip: 'Abra o aplicativo do seu banco para autorizar a compra, ou escolha PIX Instantâneo para aprovação na hora sem depender do banco emissor.',
      isFraudOrBlock: true,
    );
  }
}

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
  bool _isCheckingPayment = false;
  bool _pollingExpired = false;
  int _pollAttempts = 0;
  CheckoutSessionModel? _session;
  String? _checkoutError;
  CardDeclineFeedback? _declineFeedback;
  Timer? _pollingTimer;
  static const int _maxPixPollAttempts = 100;

  // Controladores do Cartão e Faturamento
  final TextEditingController _cardNumberController = TextEditingController();
  final TextEditingController _cardHolderController = TextEditingController();
  final TextEditingController _expiryController = TextEditingController();
  final TextEditingController _cvvController = TextEditingController();
  final TextEditingController _cpfCnpjController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _postalCodeController = TextEditingController();
  final TextEditingController _addressNumberController = TextEditingController();

  // Cupom Promocional
  final TextEditingController _couponController = TextEditingController();
  bool _isValidatingCoupon = false;
  CouponValidationResult? _appliedCoupon;
  String? _couponError;

  @override
  void initState() {
    super.initState();
    _prefillUserData();
    final refCoupon = ReferralService.getActiveReferralCoupon();
    if (refCoupon != null && refCoupon.isNotEmpty) {
      _couponController.text = refCoupon;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _applyCoupon();
        }
      });
    }
    final cleanCpf = _cpfCnpjController.text.replaceAll(RegExp(r'\D'), '');
    if (_paymentMethod == 'pix' && (cleanCpf.length == 11 || cleanCpf.length == 14)) {
      _createSession();
    } else {
      _isLoading = false;
    }
  }

  void _prefillUserData() {
    final user = AuthService.currentUser;
    if (user != null) {
      final meta = user.userMetadata ?? {};
      final name = (meta['full_name'] as String?) ?? '';
      if (name.isNotEmpty) {
        _cardHolderController.text = name.toUpperCase();
      }
      final phone = (meta['phone'] as String?) ?? user.phone ?? '';
      if (phone.isNotEmpty) {
        final digits = phone.replaceAll(RegExp(r'\D'), '');
        if (digits.length == 11) {
          _phoneController.text = '(${digits.substring(0, 2)}) ${digits.substring(2, 7)}-${digits.substring(7)}';
        } else {
          _phoneController.text = phone;
        }
      }
      final cpf = (meta['cpf'] as String?) ?? (meta['cpf_cnpj'] as String?) ?? '';
      if (cpf.isNotEmpty) {
        final digits = cpf.replaceAll(RegExp(r'\D'), '');
        if (digits.length == 11) {
          _cpfCnpjController.text = '${digits.substring(0, 3)}.${digits.substring(3, 6)}.${digits.substring(6, 9)}-${digits.substring(9)}';
        } else {
          _cpfCnpjController.text = cpf;
        }
      }
      final postalCode = (meta['postal_code'] as String?) ?? (meta['cep'] as String?) ?? '';
      if (postalCode.isNotEmpty) {
        final digits = postalCode.replaceAll(RegExp(r'\D'), '');
        if (digits.length == 8) {
          _postalCodeController.text = '${digits.substring(0, 5)}-${digits.substring(5)}';
        } else {
          _postalCodeController.text = postalCode;
        }
      }
      final addrNum = (meta['address_number'] as String?) ?? (meta['numero'] as String?) ?? '';
      if (addrNum.isNotEmpty) {
        _addressNumberController.text = addrNum;
      }
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _cardNumberController.dispose();
    _cardHolderController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _cpfCnpjController.dispose();
    _phoneController.dispose();
    _postalCodeController.dispose();
    _addressNumberController.dispose();
    _couponController.dispose();
    super.dispose();
  }

  String _detectCardBrand(String rawNumber) {
    final clean = rawNumber.replaceAll(RegExp(r'\D'), '');
    if (clean.startsWith('4')) return 'Visa';
    if (RegExp(r'^(5[1-5]|222[1-9]|22[3-9]\d|2[3-6]\d{2}|27[01]\d|2720)').hasMatch(clean)) {
      return 'Mastercard';
    }
    if (RegExp(r'^(4011|438935|451416|4576|504175|5067|5090|627780|636297|636368)').hasMatch(clean)) {
      return 'Elo';
    }
    if (RegExp(r'^(34|37)').hasMatch(clean)) return 'Amex';
    if (RegExp(r'^(606282)').hasMatch(clean)) return 'Hipercard';
    return '';
  }

  Widget _buildCardBrandBadge(String brand) {
    if (brand.isEmpty) {
      return const Icon(
        Icons.credit_card_rounded,
        color: MetaColors.textSecondary,
        size: 20,
      );
    }
    Color badgeColor = MetaColors.surfaceHighlight;
    Color textColor = MetaColors.textPrimary;
    if (brand == 'Visa') {
      badgeColor = const Color(0xFF1A1F71);
      textColor = Colors.white;
    } else if (brand == 'Mastercard') {
      badgeColor = const Color(0xFFEB001B);
      textColor = Colors.white;
    } else if (brand == 'Elo') {
      badgeColor = const Color(0xFF00A4E8);
      textColor = Colors.white;
    } else if (brand == 'Amex') {
      badgeColor = const Color(0xFF007BC1);
      textColor = Colors.white;
    }

    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: MetaColors.border, width: 0.8),
      ),
      child: Text(
        brand.toUpperCase(),
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w900,
          fontSize: 10,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  void _startPixPolling() {
    _pollingTimer?.cancel();
    _pollAttempts = 0;
    _pollingExpired = false;
    if (_session == null || _paymentMethod != 'pix') return;
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!mounted || _isPaid) {
        timer.cancel();
        return;
      }
      if (_pollAttempts >= _maxPixPollAttempts) {
        timer.cancel();
        if (mounted) setState(() => _pollingExpired = true);
        return;
      }
      await _checkPaymentStatus();
    });
  }

  Future<void> _checkPaymentStatus({bool manual = false}) async {
    final session = _session;
    if (session == null || _isCheckingPayment || _isPaid) return;
    setState(() => _isCheckingPayment = true);
    _pollAttempts++;
    try {
      final paid = await SubscriptionService.checkPaymentStatus(
        session.sessionId,
      );
      if (!mounted) return;
      if (paid) {
        _pollingTimer?.cancel();
        setState(() => _isPaid = true);
        HapticFeedback.heavyImpact();
        _showSuccessNotification();
      } else if (manual) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('O banco ainda não confirmou o pagamento.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingPayment = false;
          if (_pollAttempts >= _maxPixPollAttempts && !_isPaid) {
            _pollingTimer?.cancel();
            _pollingExpired = true;
          }
        });
      }
    }
  }

  Future<void> _createSession() async {
    if (_paymentMethod != 'pix') {
      setState(() {
        _isLoading = false;
        _checkoutError = null;
      });
      return;
    }

    final cleanCpf = _cpfCnpjController.text.replaceAll(RegExp(r'\D'), '');
    if (cleanCpf.length != 11 && cleanCpf.length != 14) {
      setState(() {
        _checkoutError = 'Informe um CPF (11 dígitos) ou CNPJ (14 dígitos) para emitir o Pix.';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _checkoutError = null;
    });
    try {
      final session = await SubscriptionService.createCheckoutSession(
        planId: widget.plan.id,
        billingInterval: widget.isYearly ? 'yearly' : 'monthly',
        paymentMethod: _paymentMethod,
        provider: 'asaas',
        cpfCnpj: cleanCpf,
        couponCode: _appliedCoupon?.code,
      );
      if (session.sessionId.isEmpty ||
          (_paymentMethod == 'pix' &&
              (session.pixCopyPaste == null ||
                  session.pixCopyPaste!.trim().isEmpty))) {
        throw const FormatException('O provedor retornou dados de pagamento incompletos.');
      }
      if (!mounted) return;
      setState(() {
        _session = session;
        _isLoading = false;
        _checkoutError = null;
      });
      if (_paymentMethod == 'pix') {
        _startPixPolling();
      }
    } catch (error) {
      if (!mounted) return;
      final msg = error.toString().replaceAll('Exception: ', '');
      setState(() {
        _session = null;
        _checkoutError = msg.isNotEmpty && !msg.contains('Format')
            ? msg
            : 'Não foi possível iniciar o pagamento Pix. Verifique o CPF/CNPJ informado.';
        _isLoading = false;
      });
    }
  }

  Future<void> _submitInAppCardPayment() async {
    final rawNumber = _cardNumberController.text.replaceAll(RegExp(r'\D'), '');
    final holder = _cardHolderController.text.trim();
    final expiry = _expiryController.text.trim();
    final cvv = _cvvController.text.trim();
    final cleanCpf = _cpfCnpjController.text.replaceAll(RegExp(r'\D'), '');
    final cleanPhone = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    final cleanCep = _postalCodeController.text.replaceAll(RegExp(r'\D'), '');
    final addrNumber = _addressNumberController.text.trim();

    if (rawNumber.length < 13 || rawNumber.length > 19) {
      _showError('Por favor, digite um número de cartão válido.');
      return;
    }
    if (holder.length < 3) {
      _showError('Digite o nome completo impresso no cartão.');
      return;
    }
    if (!expiry.contains('/') || expiry.length < 5) {
      _showError('Digite a validade completa no formato MM/AA (ex: 08/29).');
      return;
    }
    final parts = expiry.split('/');
    final monthInt = int.tryParse(parts[0]) ?? 0;
    if (monthInt < 1 || monthInt > 12) {
      _showError('Mês de validade inválido. Digite um mês entre 01 e 12.');
      return;
    }
    if (cvv.length < 3 || cvv.length > 4) {
      _showError('Digite o código de segurança CVV (3 ou 4 dígitos).');
      return;
    }
    if (cleanCpf.length != 11 && cleanCpf.length != 14) {
      _showError('O campo CPF ou CNPJ do titular é obrigatório para emissão da assinatura.');
      return;
    }
    if (cleanCep.length != 8) {
      _showError('Informe o CEP de cobrança do cartão com 8 dígitos.');
      return;
    }

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
        holderCpf: cleanCpf,
        holderPhone: cleanPhone.isNotEmpty ? cleanPhone : null,
        holderPostalCode: cleanCep,
        holderAddressNumber: addrNumber.isNotEmpty ? addrNumber : 'S/N',
        couponCode: _appliedCoupon?.code,
      );

      if (mounted) {
        setState(() => _isSubmittingCard = false);
        if (res['success'] == true) {
          setState(() {
            _isPaid = true;
            _declineFeedback = null;
            _checkoutError = null;
          });
          HapticFeedback.heavyImpact();
          _showSuccessNotification();
        } else {
          final errorRaw = res['error']?.toString() ?? 'Não foi possível autorizar o cartão.';
          final amount = widget.isYearly ? widget.plan.priceYearlyTotal : widget.plan.priceMonthly;
          final feedback = CardDeclineFeedback.fromError(errorRaw, amount);
          setState(() {
            _declineFeedback = feedback;
            _checkoutError = feedback.message;
          });
          HapticFeedback.mediumImpact();
          _showDeclineDialog(feedback);
        }
      }
    } catch (e) {
      if (mounted) {
        final amount = widget.isYearly ? widget.plan.priceYearlyTotal : widget.plan.priceMonthly;
        final feedback = CardDeclineFeedback.fromError(e.toString(), amount);
        setState(() {
          _isSubmittingCard = false;
          _declineFeedback = feedback;
          _checkoutError = feedback.message;
        });
        HapticFeedback.mediumImpact();
        _showDeclineDialog(feedback);
      }
    }
  }

  void _showDeclineDialog(CardDeclineFeedback feedback) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131B2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(
            color: Colors.amber.shade600.withValues(alpha: 0.6),
            width: 1.5,
          ),
        ),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.credit_card_off_rounded,
                color: Colors.amberAccent,
                size: 26,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                feedback.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              feedback.message,
              style: const TextStyle(
                color: Color(0xFFE2E8F0),
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Motivos mais comuns:',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...feedback.commonReasons.map(
                    (r) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• ', style: TextStyle(color: Colors.amberAccent, fontSize: 13)),
                          Expanded(
                            child: Text(
                              r,
                              style: const TextStyle(
                                color: Color(0xFFCBD5E1),
                                fontSize: 11.5,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: MetaColors.accentBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: MetaColors.accentBlue.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_outline_rounded, color: MetaColors.accentBlue, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      feedback.actionTip,
                      style: const TextStyle(
                        color: Color(0xFF93C5FD),
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SquircleButton(
              label: 'Pagar com PIX Instantâneo',
              icon: Icons.pix_rounded,
              isPrimary: true,
              onPressed: () {
                Navigator.pop(ctx);
                setState(() {
                  _paymentMethod = 'pix';
                  _declineFeedback = null;
                  _checkoutError = null;
                });
                _createSession();
              },
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Revisar dados do Cartão',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showError(String message) {
    setState(() => _checkoutError = message);
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

  Future<void> _applyCoupon() async {
    final code = _couponController.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _couponError = 'Digite o código do cupom.');
      return;
    }

    final baseAmount = widget.isYearly
        ? widget.plan.priceYearlyTotal
        : widget.plan.priceMonthly;

    setState(() {
      _isValidatingCoupon = true;
      _couponError = null;
    });

    final result = await SubscriptionService.validateCoupon(
      code: code,
      planId: widget.plan.id,
      basePrice: baseAmount,
    );

    if (!mounted) return;

    setState(() {
      _isValidatingCoupon = false;
      if (result.valid) {
        _appliedCoupon = result;
        _couponError = null;
      } else {
        _appliedCoupon = null;
        _couponError = result.message;
      }
    });

    if (result.valid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Cupom ${result.code} aplicado! ${result.formattedSavings}'),
              ),
            ],
          ),
          backgroundColor: MetaColors.emerald,
          duration: const Duration(seconds: 3),
        ),
      );

      if (_paymentMethod == 'pix') {
        _createSession();
      }
    }
  }

  void _removeCoupon() {
    setState(() {
      _appliedCoupon = null;
      _couponController.clear();
      _couponError = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cupom promocional removido.'),
        backgroundColor: Colors.white24,
        duration: Duration(seconds: 2),
      ),
    );

    if (_paymentMethod == 'pix') {
      _createSession();
    }
  }

  Widget _buildCouponSection(double originalAmount) {
    if (_appliedCoupon != null) {
      return Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: MetaColors.emerald.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: MetaColors.emerald.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: MetaColors.emerald.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.confirmation_number_rounded, color: MetaColors.emerald, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        _appliedCoupon!.code,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: MetaColors.emerald,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _appliedCoupon!.formattedSavings,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _appliedCoupon!.firstMonthOnly
                        ? 'Desconto aplicado no 1º mês de assinatura.'
                        : 'Desconto promocional aplicado.',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 18, color: Colors.white70),
              tooltip: 'Remover cupom',
              onPressed: _removeCoupon,
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MetaColors.surfaceHighlight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MetaColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.confirmation_number_outlined, color: MetaColors.accentBlue, size: 18),
              SizedBox(width: 8),
              Text(
                'Possui cupom de desconto?',
                style: TextStyle(
                  color: MetaColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: TextField(
                    controller: _couponController,
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(color: MetaColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      hintText: 'EX: LAUNCH50',
                      hintStyle: const TextStyle(color: MetaColors.textSecondary, fontSize: 12),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                      filled: true,
                      fillColor: MetaColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: MetaColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: MetaColors.border),
                      ),
                    ),
                    onSubmitted: (_) => _applyCoupon(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 42,
                child: ElevatedButton(
                  onPressed: _isValidatingCoupon ? null : _applyCoupon,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MetaColors.accentBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: _isValidatingCoupon
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Aplicar',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                ),
              ),
            ],
          ),
          if (_couponError != null) ...[
            const SizedBox(height: 6),
            Text(
              _couponError!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    final originalAmount =
        widget.isYearly
            ? widget.plan.priceYearlyTotal
            : widget.plan.priceMonthly;
    final effectiveAmount = _appliedCoupon != null
        ? _appliedCoupon!.finalPrice
        : originalAmount;
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
                    if (_appliedCoupon != null)
                      Row(
                        children: [
                          Text(
                            '${widget.plan.name} • ',
                            style: const TextStyle(color: MetaColors.textSecondary, fontSize: 13),
                          ),
                          Text(
                            'R\$ ${originalAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: MetaColors.textSecondary,
                              fontSize: 12,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'R\$ ${effectiveAmount.toStringAsFixed(2)}${widget.isYearly ? "/ano" : "/mês"}',
                            style: const TextStyle(
                              color: MetaColors.emerald,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      )
                    else
                      Text(
                        '${widget.plan.name} • R\$ ${originalAmount.toStringAsFixed(2)}${widget.isYearly ? "/ano (20% OFF)" : "/mês"}',
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_checkoutError != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _checkoutError!,
                                    style: const TextStyle(color: MetaColors.textPrimary, fontSize: 12.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],
                        _buildCouponSection(originalAmount),
                        _paymentMethod == 'pix'
                            ? _buildPixContent()
                            : _buildCreditCardContent(effectiveAmount),
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

    if (pixCode.trim().isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MetaCard(
            backgroundColor: MetaColors.surfaceHighlight,
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.pix_rounded, color: MetaColors.accentBlue, size: 26),
                    SizedBox(width: 10),
                    Text(
                      'Gerar Cobrança Pix',
                      style: TextStyle(
                        color: MetaColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'O Banco Central e o Asaas exigem a identificação por CPF ou CNPJ para emissão do QR Code instantâneo com conciliação automática.',
                  style: TextStyle(
                    color: MetaColors.textSecondary,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _cpfCnpjController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    CpfCnpjInputFormatter(),
                  ],
                  style: const TextStyle(color: MetaColors.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'CPF ou CNPJ do Pagador *',
                    hintText: '000.000.000-00',
                    prefixIcon: Icon(
                      Icons.badge_outlined,
                      color: MetaColors.textSecondary,
                      size: 20,
                    ),
                    helperText: 'Exigido pelo BACEN para emissão de Pix nominal',
                    helperStyle: TextStyle(color: Color(0xFFCBD5E1), fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(height: 18),
                SquircleButton(
                  label: 'Gerar QR Code Pix',
                  icon: Icons.qr_code_2_rounded,
                  isPrimary: true,
                  isLoading: _isLoading,
                  onPressed: () {
                    final clean = _cpfCnpjController.text.replaceAll(RegExp(r'\D'), '');
                    if (clean.length != 11 && clean.length != 14) {
                      _showError('Digite um CPF (11 dígitos) ou CNPJ (14 dígitos) válido.');
                      return;
                    }
                    _createSession();
                  },
                ),
              ],
            ),
          ),
        ],
      );
    }

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
                  pixCode,
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
                label: 'Ir para o Pagamento',
                icon: Icons.account_balance_wallet_rounded,
                isPrimary: true,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PixPaymentScreen(pixCode: pixCode),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_pollingExpired)
          Column(
            children: [
              const Text(
                'Ainda não recebemos a confirmação. Confira o pagamento no banco e tente verificar novamente.',
                textAlign: TextAlign.center,
                style: TextStyle(color: MetaColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _isCheckingPayment
                    ? null
                    : () => _checkPaymentStatus(manual: true),
                icon: _isCheckingPayment
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: const Text('Verificar pagamento'),
              ),
            ],
          )
        else
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
    final currentBrand = _detectCardBrand(_cardNumberController.text);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Banner de Alerta de Recusa do Banco (Stripe / Nubank / Mercado Pago Pattern)
        if (_declineFeedback != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2A1515), // Dark Crimson / Amber
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.amber.shade500.withValues(alpha: 0.8),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.credit_card_off_rounded,
                        color: Colors.amberAccent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _declineFeedback!.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _declineFeedback!.message,
                  style: const TextStyle(
                    color: Color(0xFFF1F5F9),
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () {
                    setState(() {
                      _paymentMethod = 'pix';
                      _declineFeedback = null;
                      _checkoutError = null;
                    });
                    _createSession();
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: MetaColors.accentBlue,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.pix_rounded, color: Colors.white, size: 16),
                        SizedBox(width: 8),
                        Text(
                          'Pagar com PIX Instantâneo (Ativação na Hora)',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Security Banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: MetaColors.emerald.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: MetaColors.emerald.withValues(alpha: 0.25)),
          ),
          child: const Row(
            children: [
              Icon(Icons.shield_outlined, color: MetaColors.emerald, size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Seus dados estão protegidos com criptografia de ponta a ponta (PCI-DSS).',
                  style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 11.5, height: 1.3),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Número do Cartão
        TextFormField(
          controller: _cardNumberController,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            CardNumberInputFormatter(),
          ],
          onChanged: (_) => setState(() {}),
          style: const TextStyle(color: MetaColors.textPrimary, letterSpacing: 1.2),
          decoration: InputDecoration(
            labelText: 'Número do Cartão *',
            hintText: '0000 0000 0000 0000',
            prefixIcon: const Icon(
              Icons.credit_card_rounded,
              color: MetaColors.textSecondary,
              size: 20,
            ),
            suffixIcon: _buildCardBrandBadge(currentBrand),
            helperText: 'Bandeiras: Visa, Mastercard, Elo, Amex e Hipercard',
            helperStyle: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(height: 14),

        // Nome no Cartão
        TextFormField(
          controller: _cardHolderController,
          textCapitalization: TextCapitalization.characters,
          style: const TextStyle(color: MetaColors.textPrimary),
          decoration: const InputDecoration(
            labelText: 'Nome no Cartão *',
            hintText: 'Como impresso no cartão',
            prefixIcon: Icon(
              Icons.person_outline_rounded,
              color: MetaColors.textSecondary,
              size: 20,
            ),
            helperText: 'Ex: CLEUDSON J CAVALCANTE',
            helperStyle: TextStyle(color: Color(0xFFCBD5E1), fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(height: 14),

        // Validade e CVV
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                controller: _expiryController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  CardExpiryInputFormatter(),
                ],
                style: const TextStyle(color: MetaColors.textPrimary, letterSpacing: 1.1),
                decoration: const InputDecoration(
                  labelText: 'Validade *',
                  hintText: 'MM/AA',
                  prefixIcon: Icon(
                    Icons.date_range_outlined,
                    color: MetaColors.textSecondary,
                    size: 20,
                  ),
                  helperText: 'Ex: 08/29',
                  helperStyle: TextStyle(color: Color(0xFFCBD5E1), fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _cvvController,
                keyboardType: TextInputType.number,
                obscureText: true,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                style: const TextStyle(color: MetaColors.textPrimary, letterSpacing: 2),
                decoration: InputDecoration(
                  labelText: 'CVV *',
                  hintText: '123',
                  prefixIcon: const Icon(
                    Icons.lock_outline_rounded,
                    color: MetaColors.textSecondary,
                    size: 20,
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.help_outline_rounded, size: 18, color: MetaColors.textSecondary),
                    tooltip: 'Código no verso do cartão',
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('CVV é o código de segurança de 3 dígitos no verso do cartão (ou 4 na frente para Amex).'),
                          duration: Duration(seconds: 4),
                        ),
                      );
                    },
                  ),
                  helperText: '3 dígitos no verso',
                  helperStyle: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // CPF / CNPJ do Titular (Campo Crítico Solicitado)
        TextFormField(
          controller: _cpfCnpjController,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            CpfCnpjInputFormatter(),
          ],
          style: const TextStyle(color: MetaColors.textPrimary),
          decoration: const InputDecoration(
            labelText: 'CPF ou CNPJ do Titular *',
            hintText: '000.000.000-00',
            prefixIcon: Icon(
              Icons.badge_outlined,
              color: MetaColors.textSecondary,
              size: 20,
            ),
            helperText: 'Exigido pelo Banco Central e Asaas para emissão de nota fiscal',
            helperStyle: TextStyle(color: Color(0xFFCBD5E1), fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(height: 14),

        // Telefone / WhatsApp do Titular
        TextFormField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            PhoneInputFormatter(),
          ],
          style: const TextStyle(color: MetaColors.textPrimary),
          decoration: const InputDecoration(
            labelText: 'Telefone / WhatsApp',
            hintText: '(00) 00000-0000',
            prefixIcon: Icon(
              Icons.phone_outlined,
              color: MetaColors.textSecondary,
              size: 20,
            ),
            helperText: 'Para envio de comprovantes e confirmação de pagamento',
            helperStyle: TextStyle(color: Color(0xFFCBD5E1), fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(height: 14),

        // Endereço de Cobrança do Cartão (Item 2: Sem truncamento, 100% legível)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: _postalCodeController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  PostalCodeInputFormatter(),
                ],
                style: const TextStyle(color: MetaColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'CEP da Fatura *',
                  hintText: '00000-000',
                  prefixIcon: Icon(
                    Icons.location_on_outlined,
                    color: MetaColors.textSecondary,
                    size: 20,
                  ),
                  helperText: null,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: _addressNumberController,
                keyboardType: TextInputType.text,
                style: const TextStyle(color: MetaColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Número',
                  hintText: 'Ex: 100',
                  prefixIcon: Icon(
                    Icons.home_outlined,
                    color: MetaColors.textSecondary,
                    size: 20,
                  ),
                  helperText: 'Ou S/N',
                  helperStyle: TextStyle(
                    color: Color(0xFFCBD5E1),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // Explicação em largura total (100% legível, com ícone e alto contraste)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: const Row(
            children: [
              Icon(Icons.shield_outlined, size: 14, color: MetaColors.emerald),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'CEP e número de cobrança do cartão (exigido pelos bancos para validação antifraude).',
                  style: TextStyle(
                    color: Color(0xFFE2E8F0),
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),

        // Botão de Confirmação In-App
        SquircleButton(
          label: 'Assinar por R\$ ${amount.toStringAsFixed(2)}${widget.isYearly ? "/ano" : "/mês"}',
          isPrimary: true,
          isLoading: _isSubmittingCard,
          icon: Icons.check_circle_outline_rounded,
          onPressed: _submitInAppCardPayment,
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// FORMATADORES DE ENTRADA (MÁSCARAS NATIVAS MOBILE)
// -----------------------------------------------------------------------------

class CardNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (text.length > 19) return oldValue;
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(text[i]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class CardExpiryInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (text.length > 4) return oldValue;

    if (text.length == 1 && int.tryParse(text) != null && int.parse(text) > 1) {
      text = '0$text';
    }

    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      if (i == 2) buffer.write('/');
      buffer.write(text[i]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class CpfCnpjInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 14) return oldValue;

    final buffer = StringBuffer();
    if (digits.length <= 11) {
      for (int i = 0; i < digits.length; i++) {
        if (i == 3 || i == 6) buffer.write('.');
        if (i == 9) buffer.write('-');
        buffer.write(digits[i]);
      }
    } else {
      for (int i = 0; i < digits.length; i++) {
        if (i == 2 || i == 5) buffer.write('.');
        if (i == 8) buffer.write('/');
        if (i == 12) buffer.write('-');
        buffer.write(digits[i]);
      }
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 11) return oldValue;

    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i == 0) buffer.write('(');
      if (i == 2) buffer.write(') ');
      if (digits.length > 10) {
        if (i == 7) buffer.write('-');
      } else {
        if (i == 6) buffer.write('-');
      }
      buffer.write(digits[i]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class PostalCodeInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 8) return oldValue;

    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i == 5) buffer.write('-');
      buffer.write(digits[i]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}



