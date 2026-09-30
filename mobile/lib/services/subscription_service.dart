import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/app_config.dart';
import '../models/subscription_model.dart';
import 'auth_service.dart';

class SubscriptionService {
  static final http.Client _client = http.Client();
  static const String _kSubscriptionStorageKey = 'b2b_trainer_active_subscription';

  static MySubscriptionModel? _currentSubscriptionCache;
  static final ValueNotifier<MySubscriptionModel?> activeSubscriptionNotifier =
      ValueNotifier<MySubscriptionModel?>(null);

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

  /// Carrega a assinatura persistida no armazenamento local do dispositivo
  static Future<MySubscriptionModel?> _loadFromLocalCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kSubscriptionStorageKey);
      if (raw != null && raw.isNotEmpty) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        return MySubscriptionModel.fromJson(data);
      }
    } catch (e) {
      debugPrint('Aviso ao carregar assinatura do cache local: $e');
    }
    return null;
  }

  /// Salva a assinatura ativa no armazenamento local para persistência permanente
  static Future<void> _saveToLocalCache(MySubscriptionModel model) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kSubscriptionStorageKey, jsonEncode(model.toJson()));
    } catch (e) {
      debugPrint('Aviso ao salvar assinatura no cache local: $e');
    }
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

  /// Retorna o plano atual do Personal Trainer com verificação de persistência
  static Future<MySubscriptionModel> getMySubscription() async {
    // 1. Inicializa do cache em disco imediatamente se cache de memória estiver vazio
    if (_currentSubscriptionCache == null) {
      final local = await _loadFromLocalCache();
      if (local != null) {
        _currentSubscriptionCache = local;
        activeSubscriptionNotifier.value = local;
      }
    }

    final trainerId = AuthService.currentUser?.id ?? 'current-trainer';

    // 2. Consulta a API FastAPI backend com o identificador do treinador
    try {
      final uri = Uri.parse('${AppConfig.apiBaseUrl}/subscriptions/my-subscription?trainer_id=$trainerId');
      final res = await _client.get(uri, headers: _headers).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        final model = MySubscriptionModel.fromJson(data);
        _currentSubscriptionCache = model;
        activeSubscriptionNotifier.value = model;
        await _saveToLocalCache(model);
        return model;
      }
    } catch (_) {
      // Fallback gracioso para banco de dados ou armazenamento local
    }

    // 3. Fallback para o Supabase se o usuário estiver autenticado
    final user = AuthService.currentUser;
    if (user != null) {
      try {
        final client = Supabase.instance.client;
        final subData = await client
            .from('subscriptions')
            .select()
            .eq('trainer_id', user.id)
            .maybeSingle();

        if (subData != null) {
          final planId = subData['plan_id'] as String? ?? 'pro';
          final plans = await getPlans();
          final plan = plans.firstWhere((p) => p.id == planId, orElse: () => _defaultPlans[1]);
          final isTrial = plan.id == 'starter';
          final currentStudents = _currentSubscriptionCache?.currentStudents ?? 4;

          final model = MySubscriptionModel(
            planId: plan.id,
            planName: plan.name,
            status: subData['status'] as String? ?? (isTrial ? 'trialing' : 'active'),
            billingInterval: subData['billing_interval'] as String? ?? 'monthly',
            currentStudents: currentStudents,
            maxStudents: plan.maxStudents,
            aiGenerationsUsed: isTrial ? 3 : 12,
            maxAiGenerations: plan.maxAiGenerationsPerMonth,
            trialDaysRemaining: isTrial ? 14 : null,
            nextBillingDate: '24/10/2026',
            paymentMethod: subData['payment_provider'] as String? ?? 'pix',
            canCreateStudent: currentStudents < plan.maxStudents,
            canGenerateAi: true,
          );

          _currentSubscriptionCache = model;
          activeSubscriptionNotifier.value = model;
          await _saveToLocalCache(model);
          return model;
        }
      } catch (_) {}
    }

    // 4. Se tiver cache em memória ou em disco, retorna com fidelidade
    if (_currentSubscriptionCache != null) {
      return _currentSubscriptionCache!;
    }

    // 5. Default: Personal Pro ativo
    final defaultModel = MySubscriptionModel(
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
    _currentSubscriptionCache = defaultModel;
    activeSubscriptionNotifier.value = defaultModel;
    await _saveToLocalCache(defaultModel);
    return defaultModel;
  }

  /// Ativa ou troca o plano do Personal Trainer imediatamente e garante persistência total
  static Future<MySubscriptionModel> activatePlan({
    required String planId,
    String billingInterval = 'monthly',
    String paymentMethod = 'pix',
  }) async {
    final plans = await getPlans();
    final plan = plans.firstWhere((p) => p.id == planId, orElse: () => _defaultPlans[0]);
    final isTrial = plan.id == 'starter';
    final now = DateTime.now();
    final nextDate = '${now.day.toString().padLeft(2, '0')}/${((now.month + 1) > 12 ? 1 : now.month + 1).toString().padLeft(2, '0')}/${now.year}';
    final currentStudentsCount = _currentSubscriptionCache?.currentStudents ?? 4;

    final immediateModel = MySubscriptionModel(
      planId: plan.id,
      planName: plan.name,
      status: isTrial ? 'trialing' : 'active',
      billingInterval: billingInterval,
      currentStudents: currentStudentsCount,
      maxStudents: plan.maxStudents,
      aiGenerationsUsed: isTrial ? 3 : 12,
      maxAiGenerations: plan.maxAiGenerationsPerMonth,
      trialDaysRemaining: isTrial ? 14 : null,
      nextBillingDate: nextDate,
      paymentMethod: paymentMethod,
      canCreateStudent: currentStudentsCount < plan.maxStudents,
      canGenerateAi: true,
    );

    // Imediatamente atualiza memória, reatividade e armazenamento persistente do celular
    _currentSubscriptionCache = immediateModel;
    activeSubscriptionNotifier.value = immediateModel;
    await _saveToLocalCache(immediateModel);

    final trainerId = AuthService.currentUser?.id ?? 'current-trainer';

    // 1. Tenta persistir no Supabase (se autenticado)
    final user = AuthService.currentUser;
    if (user != null) {
      try {
        final client = Supabase.instance.client;
        await client.from('subscriptions').upsert({
          'trainer_id': user.id,
          'plan_id': plan.id,
          'status': isTrial ? 'trialing' : 'active',
          'billing_interval': billingInterval,
          'payment_provider': paymentMethod,
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'trainer_id');
      } catch (e) {
        debugPrint('Aviso ao sincronizar assinatura com Supabase: $e');
      }
    }

    // 2. Notifica o backend FastAPI para atualizar o estado e limites em tempo real
    try {
      final uri = Uri.parse('${AppConfig.apiBaseUrl}/subscriptions/activate-plan');
      final body = jsonEncode({
        'plan_id': planId,
        'billing_interval': billingInterval,
        'payment_method': paymentMethod,
        'trainer_id': trainerId,
      });
      final res = await _client.post(uri, headers: _headers, body: body).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        final backendModel = MySubscriptionModel.fromJson(data);
        _currentSubscriptionCache = backendModel;
        activeSubscriptionNotifier.value = backendModel;
        await _saveToLocalCache(backendModel);
        return backendModel;
      }
    } catch (e) {
      debugPrint('Aviso ao sincronizar plano com backend: $e');
    }

    return immediateModel;
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
