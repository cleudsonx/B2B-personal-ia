import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/config/app_config.dart';
import '../models/subscription_model.dart';
import 'auth_service.dart';

class SubscriptionService {
  static final http.Client _client = http.Client();
  static const String _kSubscriptionStorageKey =
      'b2b_trainer_active_subscription';

  static final ValueNotifier<MySubscriptionModel?> activeSubscriptionNotifier =
      ValueNotifier<MySubscriptionModel?>(null);
  static MySubscriptionModel? _currentSubscriptionCache;
  static MySubscriptionModel? get currentSubscription => _currentSubscriptionCache;

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

  /// Salva a assinatura ativa no armazenamento local para persistÃªncia permanente
  static Future<void> _saveToLocalCache(MySubscriptionModel model) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _kSubscriptionStorageKey,
        jsonEncode(model.toJson()),
      );
    } catch (e) {
      debugPrint('Aviso ao salvar assinatura no cache local: $e');
    }
  }

  static Future<List<PlanModel>> getPlans() async {
    try {
      final uri = Uri.parse('${AppConfig.apiBaseUrl}/subscriptions/plans');
      final res = await _client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final list = jsonDecode(utf8.decode(res.bodyBytes)) as List<dynamic>;
        final apiPlans =
            list
                .map((p) => PlanModel.fromJson(p as Map<String, dynamic>))
                .toList();

        // Garante que TODOS os 4 planos canÃ´nicos (Starter, Pro, Elite, Studio) estejam presentes,
        // mesmo se o servidor backend remoto ainda estiver sincronizando uma versÃ£o anterior.
        final Map<String, PlanModel> merged = {
          for (final def in _defaultPlans) def.id: def,
        };
        for (final p in apiPlans) {
          merged[p.id] = p;
        }

        const canonicalOrder = ['starter', 'pro', 'elite', 'studio'];
        return canonicalOrder
            .map(
              (id) => merged[id] ?? _defaultPlans.firstWhere((d) => d.id == id),
            )
            .toList();
      }
    } catch (_) {
      // Fallback gracioso com planos padrÃ£o caso offline
    }
    return _defaultPlans;
  }

  /// Retorna o plano atual do Personal Trainer com verificaÃ§Ã£o de persistÃªncia
  static Future<MySubscriptionModel> getMySubscription() =>
      refreshMySubscription();

  static Future<MySubscriptionModel> refreshMySubscription() async {
    final trainerId = AuthService.currentUser?.id;
    if (trainerId == null) {
      throw StateError('Sessão expirada. Entre novamente para consultar o plano.');
    }

    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/subscriptions/my-subscription?trainer_id=$trainerId',
    );
    final response = await _client
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 5));
    if (response.statusCode != 200) {
      throw Exception('Não foi possível atualizar a assinatura (${response.statusCode}).');
    }

    final payload = jsonDecode(utf8.decode(response.bodyBytes))
        as Map<String, dynamic>;
    final model = MySubscriptionModel.fromJson(payload);
    _currentSubscriptionCache = model;
    activeSubscriptionNotifier.value = model;
    await _saveToLocalCache(model);
    return model;
  }

  /// Ativa ou troca o plano do Personal Trainer imediatamente e garante persistÃªncia total
  static Future<MySubscriptionModel> activatePlan({
    required String planId,
    String billingInterval = 'monthly',
    String paymentMethod = 'pix',
  }) async {
    final trainerId = AuthService.currentUser?.id;
    if (trainerId == null) {
      throw StateError('Sessão expirada. Entre novamente para ativar o plano.');
    }

    try {
      final uri = Uri.parse(
        '${AppConfig.apiBaseUrl}/subscriptions/activate-plan',
      );
      final body = jsonEncode({
        'plan_id': planId,
        'billing_interval': billingInterval,
        'payment_method': paymentMethod,
        'trainer_id': trainerId,
      });
      final res = await _client
          .post(uri, headers: _headers, body: body)
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data =
            jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        final backendModel = MySubscriptionModel.fromJson(data);
        _currentSubscriptionCache = backendModel;
        activeSubscriptionNotifier.value = backendModel;
        await _saveToLocalCache(backendModel);
        return backendModel;
      }
      String detail = 'O servidor recusou a ativação do plano (${res.statusCode}).';
      try {
        final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        detail = data['detail'] as String? ?? detail;
      } catch (_) {}
      throw Exception(detail);
    } catch (e) {
      rethrow;
    }
  }

  /// Gera a sessÃ£o de pagamento transparente (Pix ou CartÃ£o) via Asaas / InfinitePay
  static Future<CheckoutSessionModel> createCheckoutSession({
    required String planId,
    required String billingInterval,
    required String paymentMethod,
    String provider = 'asaas',
  }) async {
    try {
      final user = AuthService.currentUser;
      final uri = Uri.parse(
        '${AppConfig.apiBaseUrl}/subscriptions/checkout-session',
      );
      final body = jsonEncode({
        'plan_id': planId,
        'billing_interval': billingInterval,
        'payment_method': paymentMethod,
        'provider': provider,
        'trainer_id': user?.id ?? 'current-trainer',
        'trainer_name': user?.userMetadata?['full_name'] ?? 'Personal Trainer',
        'trainer_email': user?.email ?? 'personal@sheipados.com',
      });

      final res = await _client
          .post(uri, headers: _headers, body: body)
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data =
            jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        return CheckoutSessionModel.fromJson(data);
      }
      throw Exception('O servidor recusou a criação do checkout (${res.statusCode}).');
    } catch (_) {
      rethrow;
    }
  }

  /// Consulta em tempo real se o Pix ou pagamento foi compensado pelo gateway
  static Future<bool> checkPaymentStatus(String orderNsu) async {
    try {
      final uri = Uri.parse(
        '${AppConfig.apiBaseUrl}/subscriptions/check-status/$orderNsu',
      );
      final res = await _client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data =
            jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        return data['paid'] == true;
      }
    } catch (_) {}
    return false;
  }

  /// Realiza o pagamento com cartÃ£o com TokenizaÃ§Ã£o In-App (SoluÃ§Ã£o 1).
  /// Envia os dados criptografados para ativaÃ§Ã£o imediata e nativa,
  /// sem redirecionar para links externos ou pÃ¡ginas genÃ©ricas de fatura.
  static Future<Map<String, dynamic>> payWithCardInApp({
    required String planId,
    required String billingInterval,
    required String cardNumber,
    required String holderName,
    required String expiryMonth,
    required String expiryYear,
    required String ccv,
    String? holderCpf,
    String provider = 'asaas',
  }) async {
    try {
      final uri = Uri.parse(
        '${AppConfig.apiBaseUrl}/subscriptions/pay-with-card',
      );
      final body = jsonEncode({
        'plan_id': planId,
        'billing_interval': billingInterval,
        'card_number': cardNumber,
        'holder_name': holderName,
        'expiry_month': expiryMonth,
        'expiry_year': expiryYear,
        'ccv': ccv,
        'holder_cpf': holderCpf,
        'provider': provider,
      });

      final res = await _client
          .post(uri, headers: _headers, body: body)
          .timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        final data =
            jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        return {'success': true, 'data': data};
      } else {
        String detail = 'Erro no processamento do cartÃ£o.';
        try {
          final data =
              jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
          detail = data['detail']?.toString() ?? detail;
        } catch (_) {}
        return {'success': false, 'error': detail};
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Não foi possível confirmar o pagamento. Tente novamente.',
      };
    }
  }

  /// Simula e calcula o impacto financeiro (prÃ³-rata) e as regras de transiÃ§Ã£o de plano (Upgrade / Downgrade)
  static Future<PlanChangeSimulationModel> simulatePlanChange({
    required String currentPlanId,
    required String newPlanId,
    String billingInterval = 'monthly',
    int daysUsedInCycle = 10,
    int totalDaysInCycle = 30,
    int activeStudentsCount = 0,
  }) async {
    try {
      final uri = Uri.parse(
        '${AppConfig.apiBaseUrl}/subscriptions/calculate-change',
      );
      final body = jsonEncode({
        'current_plan_id': currentPlanId,
        'new_plan_id': newPlanId,
        'billing_interval': billingInterval,
        'days_used_in_cycle': daysUsedInCycle,
        'total_days_in_cycle': totalDaysInCycle,
        'active_students_count': activeStudentsCount,
      });

      final res = await _client
          .post(uri, headers: _headers, body: body)
          .timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data =
            jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
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
        blockReason:
            'VocÃª possui $activeStudentsCount alunos ativos. O plano ${planNames[newPlanId]} permite no mÃ¡ximo $targetMaxStudents alunos. Desative ou arquive pelo menos $excess aluno(s) antes de mudar.',
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

    final unusedCredit =
        (isUpgrade && currentPrice > 0)
            ? ((currentPrice / totalDaysInCycle) *
                    (totalDaysInCycle - daysUsedInCycle))
                .toInt()
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
      effectiveDate:
          isUpgrade ? 'Imediato apÃ³s pagamento' : 'No fim do ciclo atual',
      newStudentLimit: targetMaxStudents,
      newAiLimit: newPlanId == 'starter' ? 10 : -1,
      summaryMessage:
          isUpgrade
              ? 'Upgrade com crÃ©dito prÃ³-rata de R\$ ${(unusedCredit / 100).toStringAsFixed(2)}.'
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
        PlanFeatureModel(
          title: 'Até 3 alunos ativos simultâneos',
          included: true,
        ),
        PlanFeatureModel(
          title: '10 fichas com IA Gemini 3.5 / mês',
          included: true,
        ),
        PlanFeatureModel(
          title: 'Adaptação de exercícios no salão',
          included: true,
        ),
        PlanFeatureModel(
          title: 'Raio-X Anatômico e Split-View',
          included: true,
        ),
        PlanFeatureModel(title: 'Alunos ilimitados', included: false),
        PlanFeatureModel(
          title: 'Alertas WhatsApp via Webhook',
          included: false,
        ),
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
        PlanFeatureModel(
          title: 'Até 30 alunos ativos na consultoria',
          included: true,
          highlight: true,
        ),
        PlanFeatureModel(
          title: 'PrescriÃ§Ãµes IA Ilimitadas (Gemini Flash)',
          included: true,
          highlight: true,
        ),
        PlanFeatureModel(
          title: 'Anamnese clÃ­nica profunda e restriÃ§Ãµes',
          included: true,
        ),
        PlanFeatureModel(
          title: 'Raio-X Muscular com EMG e AnÃ¡lise de Fases',
          included: true,
          highlight: true,
        ),
        PlanFeatureModel(
          title: 'Timer de descanso interativo sincronizado',
          included: true,
        ),
        PlanFeatureModel(
          title: 'Painel de alertas de adaptaÃ§Ã£o em tempo real',
          included: true,
          highlight: true,
        ),
        PlanFeatureModel(
          title: 'Suporte prioritÃ¡rio via WhatsApp',
          included: true,
        ),
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
        PlanFeatureModel(
          title: 'Até 60 alunos ativos na consultoria',
          included: true,
          highlight: true,
        ),
        PlanFeatureModel(
          title: 'PrescriÃ§Ãµes IA Ilimitadas (Gemini Flash)',
          included: true,
          highlight: true,
        ),
        PlanFeatureModel(
          title: 'AutomaÃ§Ã£o WhatsApp (Evolution/Z-API)',
          included: true,
          highlight: true,
        ),
        PlanFeatureModel(
          title: 'Alertas automÃ¡ticos de dor e faltas no WhatsApp',
          included: true,
          highlight: true,
        ),
        PlanFeatureModel(
          title: 'RelatÃ³rios de assiduidade e retenÃ§Ã£o',
          included: true,
          highlight: true,
        ),
        PlanFeatureModel(
          title: 'Suporte prioritÃ¡rio VIP via WhatsApp',
          included: true,
        ),
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
      badge: 'ESCALA MÃXIMA',
      features: [
        PlanFeatureModel(
          title: 'Até 100 alunos ativos na assessoria',
          included: true,
          highlight: true,
        ),
        PlanFeatureModel(
          title: 'PrescriÃ§Ãµes e adaptaÃ§Ãµes IA Ilimitadas',
          included: true,
          highlight: true,
        ),
        PlanFeatureModel(
          title: 'MÃºltiplos personals sob a mesma conta',
          included: true,
          highlight: true,
        ),
        PlanFeatureModel(
          title: 'Alertas de dor e evasÃ£o no WhatsApp',
          included: true,
          highlight: true,
        ),
        PlanFeatureModel(
          title: 'RelatÃ³rios de assiduidade e retenÃ§Ã£o',
          included: true,
          highlight: true,
        ),
        PlanFeatureModel(
          title: 'Gerente de contas dedicado e suporte VIP',
          included: true,
        ),
      ],
    ),
  ];
}

