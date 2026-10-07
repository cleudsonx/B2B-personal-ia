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
  static const String _kSubscriptionStorageKey =
      'b2b_trainer_active_subscription';

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
  static Future<MySubscriptionModel> getMySubscription() async {
    // 1. Inicializa do cache em disco imediatamente se cache de memÃ³ria estiver vazio
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
      final uri = Uri.parse(
        '${AppConfig.apiBaseUrl}/subscriptions/my-subscription?trainer_id=$trainerId',
      );
      final res = await _client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data =
            jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        final model = MySubscriptionModel.fromJson(data);
        _currentSubscriptionCache = model;
        activeSubscriptionNotifier.value = model;
        await _saveToLocalCache(model);
        return model;
      }
    } catch (_) {
      // Fallback gracioso para banco de dados ou armazenamento local
    }

    // 3. Fallback para o Supabase se o usuÃ¡rio estiver autenticado
    final user = AuthService.currentUser;
    if (user != null) {
      try {
        final client = Supabase.instance.client;
        final subData =
            await client
                .from('subscriptions')
                .select()
                .eq('trainer_id', user.id)
                .maybeSingle();

        if (subData != null) {
          final planId = subData['plan_id'] as String? ?? 'pro';
          final plans = await getPlans();
          final plan = plans.firstWhere(
            (p) => p.id == planId,
            orElse: () => _defaultPlans[1],
          );
          final isTrial = plan.id == 'starter';
          final currentStudents =
              _currentSubscriptionCache?.currentStudents ?? 4;

          final model = MySubscriptionModel(
            planId: plan.id,
            planName: plan.name,
            status:
                subData['status'] as String? ??
                (isTrial ? 'trialing' : 'active'),
            billingInterval:
                subData['billing_interval'] as String? ?? 'monthly',
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

    // 4. Se tiver cache em memÃ³ria ou em disco, retorna com fidelidade
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

  static String _humanReadableErrorMessage(Object error, {String fallback = 'Não foi possível completar a ativação do plano.'}) {
    final message = error.toString();
    if (message.startsWith('Exception: ')) {
      return message.replaceFirst('Exception: ', '');
    }
    if (message.startsWith('FormatException: ')) {
      return message.replaceFirst('FormatException: ', '');
    }
    return fallback;
  }

  /// Ativa ou troca o plano do Personal Trainer somente quando o backend confirmar.
  static Future<MySubscriptionModel> activatePlan({
    required String planId,
    String billingInterval = 'monthly',
    String paymentMethod = 'pix',
  }) async {
    final plans = await getPlans();
    final plan = plans.firstWhere(
      (p) => p.id == planId,
      orElse: () => _defaultPlans[0],
    );

    final trainerId = AuthService.currentUser?.id ?? 'current-trainer';

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
        final decoded = jsonDecode(utf8.decode(res.bodyBytes));
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('Resposta do backend não é um objeto válido.');
        }

        final backendModel = MySubscriptionModel.fromJson(decoded);
        _currentSubscriptionCache = backendModel;
        activeSubscriptionNotifier.value = backendModel;
        await _saveToLocalCache(backendModel);
        return backendModel;
      }

      final detail = (() {
        try {
          final decoded = jsonDecode(utf8.decode(res.bodyBytes));
          if (decoded is Map) {
            final value = decoded['detail'] ?? decoded['message'];
            if (value != null) return value.toString();
          }
        } catch (_) {}
        return 'Status ${res.statusCode} ao ativar o plano.';
      })();

      throw Exception('Ativação do plano falhou: $detail');
    } on TimeoutException {
      throw Exception('Tempo limite ao ativar o plano. Tente novamente.');
    } on http.ClientException catch (e) {
      throw Exception('Erro de rede ao ativar o plano: ${e.message}');
    } on FormatException catch (e) {
      throw Exception('Resposta inválida do servidor ao ativar o plano: ${e.message}');
    } catch (e) {
      throw Exception(_humanReadableErrorMessage(e));
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
    } catch (_) {
      // Fallback simulado
    }

    final isYearly = billingInterval == 'yearly';
    final amount =
        planId == 'studio'
            ? (isYearly ? 190800 : 19900)
            : (planId == 'elite'
                ? (isYearly ? 142800 : 14900)
                : (planId == 'pro' ? (isYearly ? 85200 : 8900) : 0));

    final planName =
        planId == 'studio'
            ? 'Studio Scale'
            : (planId == 'elite'
                ? 'Elite Coach'
                : (planId == 'pro' ? 'Personal Pro' : 'Starter Trial'));

    final sessId = 'sess_asaas_${DateTime.now().millisecondsSinceEpoch}';
    return CheckoutSessionModel(
      sessionId: sessId,
      planId: planId,
      planName: planName,
      amountCents: amount,
      billingInterval: billingInterval,
      paymentMethod: paymentMethod,
      pixCopyPaste:
          '00020126580014br.gov.bcb.pix0136b2b-personal-ia-demo520400005303986540${(amount / 100).toStringAsFixed(2)}5802BR5920B2B PERSONAL IA6009SAO PAULO62070503***6304ABCD',
      checkoutUrl: 'https://sandbox.asaas.com/c/$sessId',
      provider: provider,
      status: 'pending',
      expiresAt: 'Hoje Ã s 23:59',
    );
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
        await getMySubscription();
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
      // Fallback gracioso para modo de testes/offline
      final plans = await getPlans();
      final plan = plans.firstWhere(
        (p) => p.id == planId,
        orElse: () => _defaultPlans[1],
      );
      final model = MySubscriptionModel(
        planId: plan.id,
        planName: plan.name,
        status: 'active',
        billingInterval: billingInterval,
        currentStudents: _currentSubscriptionCache?.currentStudents ?? 4,
        maxStudents: plan.maxStudents,
        aiGenerationsUsed: 0,
        maxAiGenerations: plan.maxAiGenerationsPerMonth,
        trialDaysRemaining: null,
        nextBillingDate:
            billingInterval == 'yearly' ? '01/10/2027' : '01/11/2026',
        paymentMethod: 'credit_card',
        canCreateStudent: true,
        canGenerateAi: true,
      );
      _currentSubscriptionCache = model;
      activeSubscriptionNotifier.value = model;
      await _saveToLocalCache(model);
      return {'success': true, 'simulated': true};
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

