import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/config/app_config.dart';
import '../models/subscription_model.dart';
import 'auth_service.dart';

class SubscriptionService {
  static final http.Client _client = http.Client();

  static Map<String, String> get _headers {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final token = AuthService.accessToken;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// Busca os planos SaaS disponíveis no backend
  static Future<List<PlanModel>> getPlans() async {
    try {
      final uri = Uri.parse('${AppConfig.apiBaseUrl}/subscriptions/plans');
      final res = await _client.get(uri, headers: _headers).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final list = jsonDecode(utf8.decode(res.bodyBytes)) as List<dynamic>;
        return list.map((p) => PlanModel.fromJson(p as Map<String, dynamic>)).toList();
      }
    } catch (_) {
      // Fallback gracioso com planos padrão caso offline
    }
    return _defaultPlans;
  }

  /// Retorna o plano atual do Personal Trainer
  static Future<MySubscriptionModel> getMySubscription() async {
    try {
      final uri = Uri.parse('${AppConfig.apiBaseUrl}/subscriptions/my-subscription');
      final res = await _client.get(uri, headers: _headers).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        return MySubscriptionModel.fromJson(data);
      }
    } catch (_) {
      // Fallback gracioso
    }
    return MySubscriptionModel(
      planId: 'pro',
      planName: 'Personal Pro',
      status: 'active',
      billingInterval: 'monthly',
      currentStudents: 4,
      maxStudents: 30,
      aiGenerationsUsed: 12,
      maxAiGenerations: -1,
      trialDaysRemaining: null,
      nextBillingDate: '24/10/2026',
      paymentMethod: 'pix',
      canCreateStudent: true,
      canGenerateAi: true,
    );
  }

  /// Gera a sessão de pagamento via Pix ou Cartão
  static Future<CheckoutSessionModel> createCheckoutSession({
    required String planId,
    required String billingInterval,
    required String paymentMethod,
  }) async {
    try {
      final uri = Uri.parse('${AppConfig.apiBaseUrl}/subscriptions/checkout-session');
      final body = jsonEncode({
        'plan_id': planId,
        'billing_interval': billingInterval,
        'payment_method': paymentMethod,
      });

      final res = await _client.post(uri, headers: _headers, body: body).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        return CheckoutSessionModel.fromJson(data);
      }
    } catch (_) {
      // Fallback simulado
    }

    final isYearly = billingInterval == 'yearly';
    final amount = planId == 'studio'
        ? (isYearly ? 190800 : 19900)
        : (planId == 'pro' ? (isYearly ? 85200 : 8900) : 0);

    return CheckoutSessionModel(
      sessionId: 'sess_simulated_${DateTime.now().millisecondsSinceEpoch}',
      planId: planId,
      planName: planId == 'studio' ? 'Studio Scale' : (planId == 'pro' ? 'Personal Pro' : 'Starter'),
      amountCents: amount,
      billingInterval: billingInterval,
      paymentMethod: paymentMethod,
      pixCopyPaste: '00020126580014br.gov.bcb.pix0136b2b-personal-ia-demo520400005303986540${(amount / 100).toStringAsFixed(2)}5802BR5920B2B PERSONAL IA6009SAO PAULO62070503***6304ABCD',
      status: 'pending',
      expiresAt: 'Hoje às 23:59',
    );
  }

  /// Simula e calcula o impacto financeiro (pró-rata) e as regras de transição de plano (Upgrade / Downgrade)
  static Future<PlanChangeSimulationModel> simulatePlanChange({
    required String currentPlanId,
    required String newPlanId,
    String billingInterval = 'monthly',
    int daysUsedInCycle = 10,
    int totalDaysInCycle = 30,
    int activeStudentsCount = 0,
  }) async {
    try {
      final uri = Uri.parse('${AppConfig.apiBaseUrl}/subscriptions/calculate-change');
      final body = jsonEncode({
        'current_plan_id': currentPlanId,
        'new_plan_id': newPlanId,
        'billing_interval': billingInterval,
        'days_used_in_cycle': daysUsedInCycle,
        'total_days_in_cycle': totalDaysInCycle,
        'active_students_count': activeStudentsCount,
      });

      final res = await _client.post(uri, headers: _headers, body: body).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        return PlanChangeSimulationModel.fromJson(data);
      }
    } catch (_) {}

    final isYearly = billingInterval == 'yearly';
    final planPrices = {
      'starter': isYearly ? 0 : 0,
      'pro': isYearly ? 85200 : 8900,
      'elite': isYearly ? 142800 : 14900,
      'studio': isYearly ? 190800 : 19900,
    };
    final planTiers = {'starter': 1, 'pro': 2, 'elite': 3, 'studio': 4};
    final planStudents = {'starter': 3, 'pro': 30, 'elite': 60, 'studio': 100};
    final planNames = {
      'starter': 'Starter Trial',
      'pro': 'Personal Pro',
      'elite': 'Elite Coach',
      'studio': 'Studio Scale',
    };

    final targetPrice = planPrices[newPlanId] ?? 0;
    final currentPrice = planPrices[currentPlanId] ?? 0;
    final currentTier = planTiers[currentPlanId] ?? 1;
    final targetTier = planTiers[newPlanId] ?? 1;

    final isUpgrade = targetTier > currentTier;
    final isDowngrade = targetTier < currentTier;

    final targetMaxStudents = planStudents[newPlanId] ?? 3;
    if (isDowngrade && activeStudentsCount > targetMaxStudents) {
      final excess = activeStudentsCount - targetMaxStudents;
      return PlanChangeSimulationModel(
        changeType: 'downgrade',
        isBlocked: true,
        blockReason: 'Você possui $activeStudentsCount alunos ativos. O plano ${planNames[newPlanId]} permite no máximo $targetMaxStudents alunos. Desative ou arquive pelo menos $excess aluno(s) antes de mudar.',
        currentPlanName: planNames[currentPlanId] ?? 'Plano Atual',
        newPlanName: planNames[newPlanId] ?? 'Novo Plano',
        currentPlanPriceCents: currentPrice,
        newPlanPriceCents: targetPrice,
        unusedCreditCents: 0,
        netChargeCents: 0,
        effectiveDate: 'Bloqueado por cota de alunos',
        newStudentLimit: targetMaxStudents,
        newAiLimit: newPlanId == 'starter' ? 10 : -1,
        summaryMessage: 'Downgrade bloqueado por excesso de alunos ativos.',
      );
    }

    final unusedCredit = (isUpgrade && currentPrice > 0)
        ? ((currentPrice / totalDaysInCycle) * (totalDaysInCycle - daysUsedInCycle)).toInt()
        : 0;
    final netCharge = (targetPrice - unusedCredit).clamp(0, 9999999);

    return PlanChangeSimulationModel(
      changeType: isUpgrade ? 'upgrade' : (isDowngrade ? 'downgrade' : 'same'),
      isBlocked: false,
      blockReason: null,
      currentPlanName: planNames[currentPlanId] ?? 'Plano Atual',
      newPlanName: planNames[newPlanId] ?? 'Novo Plano',
      currentPlanPriceCents: currentPrice,
      newPlanPriceCents: targetPrice,
      unusedCreditCents: unusedCredit,
      netChargeCents: netCharge,
      effectiveDate: isUpgrade ? 'Imediato após pagamento' : 'No fim do ciclo atual',
      newStudentLimit: targetMaxStudents,
      newAiLimit: newPlanId == 'starter' ? 10 : -1,
      summaryMessage: isUpgrade
          ? 'Upgrade com crédito pró-rata de R\$ ${(unusedCredit / 100).toStringAsFixed(2)}.'
          : 'Downgrade agendado para o final do ciclo atual.',
    );
  }

  static final List<PlanModel> _defaultPlans = [
    PlanModel(
      id: 'starter',
      name: 'Starter Trial',
      tagline: 'Degustação para começar sua consultoria com IA',
      priceMonthlyCents: 0,
      priceYearlyCents: 0,
      priceYearlyMonthlyEquivalentCents: 0,
      maxStudents: 3,
      maxAiGenerationsPerMonth: 10,
      isPopular: false,
      badge: 'GRATUITO',
      features: [
        PlanFeatureModel(title: 'Até 3 alunos ativos simultâneos', included: true),
        PlanFeatureModel(title: '10 fichas com IA Gemini 3.5 / mês', included: true),
        PlanFeatureModel(title: 'Adaptação de exercícios no salão', included: true),
        PlanFeatureModel(title: 'Raio-X Anatômico e Split-View', included: true),
        PlanFeatureModel(title: 'Alunos ilimitados', included: false),
        PlanFeatureModel(title: 'Alertas WhatsApp via Webhook', included: false),
      ],
    ),
    PlanModel(
      id: 'pro',
      name: 'Personal Pro',
      tagline: 'O plano definitivo para o Personal Trainer autônomo',
      priceMonthlyCents: 8900,
      priceYearlyCents: 85200,
      priceYearlyMonthlyEquivalentCents: 7100,
      maxStudents: 30,
      maxAiGenerationsPerMonth: -1,
      isPopular: true,
      badge: 'MAIS POPULAR',
      features: [
        PlanFeatureModel(title: 'Até 30 alunos ativos na consultoria', included: true, highlight: true),
        PlanFeatureModel(title: 'Prescrições IA Ilimitadas (Gemini Flash)', included: true, highlight: true),
        PlanFeatureModel(title: 'Anamnese clínica profunda e restrições', included: true),
        PlanFeatureModel(title: 'Raio-X Muscular com EMG e Análise de Fases', included: true, highlight: true),
        PlanFeatureModel(title: 'Timer de descanso interativo sincronizado', included: true),
        PlanFeatureModel(title: 'Painel de alertas de adaptação em tempo real', included: true, highlight: true),
        PlanFeatureModel(title: 'Suporte prioritário via WhatsApp', included: true),
      ],
    ),
    PlanModel(
      id: 'elite',
      name: 'Elite Coach',
      tagline: 'Consultoria de alta escala com canal WhatsApp automatizado',
      priceMonthlyCents: 14900,
      priceYearlyCents: 142800,
      priceYearlyMonthlyEquivalentCents: 11900,
      maxStudents: 60,
      maxAiGenerationsPerMonth: -1,
      isPopular: false,
      badge: 'ALTA ESCALA',
      features: [
        PlanFeatureModel(title: 'Até 60 alunos ativos na consultoria', included: true, highlight: true),
        PlanFeatureModel(title: 'Prescrições IA Ilimitadas (Gemini Flash)', included: true, highlight: true),
        PlanFeatureModel(title: 'Automação WhatsApp (Evolution/Z-API)', included: true, highlight: true),
        PlanFeatureModel(title: 'Alertas automáticos de dor e faltas no WhatsApp', included: true, highlight: true),
        PlanFeatureModel(title: 'Relatórios de assiduidade e retenção', included: true, highlight: true),
        PlanFeatureModel(title: 'Suporte prioritário VIP via WhatsApp', included: true),
      ],
    ),
    PlanModel(
      id: 'studio',
      name: 'Studio Scale',
      tagline: 'Para assessorias esportivas e estúdios que buscam escala',
      priceMonthlyCents: 19900,
      priceYearlyCents: 190800,
      priceYearlyMonthlyEquivalentCents: 15900,
      maxStudents: 100,
      maxAiGenerationsPerMonth: -1,
      isPopular: false,
      badge: 'ESCALA MÁXIMA',
      features: [
        PlanFeatureModel(title: 'Até 100 alunos ativos na assessoria', included: true, highlight: true),
        PlanFeatureModel(title: 'Prescrições e adaptações IA Ilimitadas', included: true, highlight: true),
        PlanFeatureModel(title: 'Múltiplos personals sob a mesma conta', included: true, highlight: true),
        PlanFeatureModel(title: 'Alertas de dor e evasão no WhatsApp', included: true, highlight: true),
        PlanFeatureModel(title: 'Relatórios de assiduidade e retenção', included: true, highlight: true),
        PlanFeatureModel(title: 'Gerente de contas dedicado e suporte VIP', included: true),
      ],
    ),
  ];
}
