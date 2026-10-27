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

  /// Salva a assinatura ativa no armazenamento local para persistência permanente
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

        // Garante que TODOS os 4 planos canônicos (Starter, Pro, Elite, Studio) estejam presentes,
        // mesmo se o servidor backend remoto ainda estiver sincronizando uma versão anterior.
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
      // Fallback gracioso com planos padrão caso offline
    }
    return _defaultPlans;
  }

  /// Retorna o plano atual do Personal Trainer com verificação de persistência
  static Future<MySubscriptionModel> getMySubscription() =>
      refreshMySubscription();

  static Future<MySubscriptionModel> refreshMySubscription() async {
    final trainerId = AuthService.currentUser?.id;
    if (trainerId == null) {
      throw StateError('Sessão expirada. Entre novamente para consultar o plano.');
    }

    // 1. Tenta consulta via API Backend oficial
    try {
      final uri = Uri.parse(
        '${AppConfig.apiBaseUrl}/subscriptions/my-subscription?trainer_id=$trainerId',
      );
      final response = await _client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final payload = jsonDecode(utf8.decode(response.bodyBytes))
            as Map<String, dynamic>;
        final model = MySubscriptionModel.fromJson(payload);
        _currentSubscriptionCache = model;
        activeSubscriptionNotifier.value = model;
        await _saveToLocalCache(model);
        return model;
      }
    } catch (e) {
      debugPrint('[SubscriptionService] Falha ao consultar backend, ativando fallback Supabase: $e');
    }

    // 2. Fallback direto ao Supabase (resiliente a cold-starts de servidores externos)
    try {
      final supabase = Supabase.instance.client;
      final subRes = await supabase
          .from('subscriptions')
          .select('*, plans(*)')
          .eq('trainer_id', trainerId)
          .maybeSingle();

      if (subRes != null) {
        final planData = subRes['plans'] as Map<String, dynamic>? ?? {};
        final planId = subRes['plan_id']?.toString() ?? 'elite';
        final planName = planData['name']?.toString() ??
            (planId == 'elite'
                ? 'Elite Coach'
                : (planId == 'studio'
                    ? 'Studio Scale'
                    : (planId == 'starter' ? 'Starter Trial' : 'Personal Pro')));
        final maxStudents = (planData['max_students'] as num?)?.toInt() ??
            (planId == 'elite' ? 60 : (planId == 'studio' ? 100 : (planId == 'starter' ? 3 : 30)));

        int currentStudents = 0;
        try {
          final countRes = await supabase
              .from('profiles')
              .select('id')
              .eq('trainer_id', trainerId)
              .eq('role', 'client');
          currentStudents = (countRes as List).length;
        } catch (_) {}

        final model = MySubscriptionModel(
          planId: planId,
          planName: planName,
          status: subRes['status']?.toString() ?? 'active',
          billingInterval: subRes['billing_interval']?.toString() ?? 'monthly',
          currentStudents: currentStudents,
          maxStudents: maxStudents,
          aiGenerationsUsed: 0,
          maxAiGenerations: (planData['max_ai_generations_per_month'] as num?)?.toInt() ?? -1,
          paymentMethod: subRes['payment_provider']?.toString() ?? 'pix',
          canCreateStudent: currentStudents < maxStudents,
          canGenerateAi: true,
        );
        _currentSubscriptionCache = model;
        activeSubscriptionNotifier.value = model;
        await _saveToLocalCache(model);
        return model;
      }
    } catch (e) {
      debugPrint('[SubscriptionService] Fallback Supabase falhou: $e');
    }

    // 3. Fallback em cache local persistido
    final cached = _currentSubscriptionCache;
    if (cached != null) return cached;

    throw Exception('Não foi possível obter dados da assinatura.');
  }

  /// Ativa ou troca o plano do Personal Trainer imediatamente e garante persistência total
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

  /// Gera a sessão de pagamento transparente (Pix ou Cartão) via Asaas / InfinitePay
  static Future<CheckoutSessionModel> createCheckoutSession({
    required String planId,
    required String billingInterval,
    required String paymentMethod,
    String provider = 'asaas',
    String? cpfCnpj,
    String? couponCode,
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
        'trainer_email': user?.email ?? 'personal@shaipados.com',
        if (cpfCnpj != null && cpfCnpj.trim().isNotEmpty) 'cpf_cnpj': cpfCnpj.trim(),
        if (couponCode != null && couponCode.trim().isNotEmpty) 'coupon_code': couponCode.trim(),
      });

      final res = await _client
          .post(uri, headers: _headers, body: body)
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data =
            jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        return CheckoutSessionModel.fromJson(data);
      }
      String detail = 'O servidor recusou a criação do checkout (${res.statusCode}).';
      try {
        final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        detail = data['detail'] as String? ?? detail;
      } catch (_) {}
      throw Exception(detail);
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

  /// Realiza o pagamento com cartão com Tokenização In-App (Solução 1).
  /// Envia os dados criptografados para ativação imediata e nativa,
  /// sem redirecionar para links externos ou páginas genéricas de fatura.
  static Future<Map<String, dynamic>> payWithCardInApp({
    required String planId,
    required String billingInterval,
    required String cardNumber,
    required String holderName,
    required String expiryMonth,
    required String expiryYear,
    required String ccv,
    String? holderCpf,
    String? holderPhone,
    String? holderPostalCode,
    String? holderAddressNumber,
    String provider = 'asaas',
    String? couponCode,
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
        if (holderPhone != null && holderPhone.trim().isNotEmpty) 'holder_phone': holderPhone.trim(),
        if (holderPostalCode != null && holderPostalCode.trim().isNotEmpty) 'holder_postal_code': holderPostalCode.trim(),
        if (holderAddressNumber != null && holderAddressNumber.trim().isNotEmpty) 'holder_address_number': holderAddressNumber.trim(),
        'provider': provider,
        if (couponCode != null && couponCode.trim().isNotEmpty) 'coupon_code': couponCode.trim(),
      });

      final res = await _client
          .post(uri, headers: _headers, body: body)
          .timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        final data =
            jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        return {'success': true, 'data': data};
      } else {
        String detail = 'Erro no processamento do cartão.';
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
            'Você possui $activeStudentsCount alunos ativos. O plano ${planNames[newPlanId]} permite no máximo $targetMaxStudents alunos. Desative ou arquive pelo menos $excess aluno(s) antes de mudar.',
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
          isUpgrade ? 'Imediato após pagamento' : 'No fim do ciclo atual',
      newStudentLimit: targetMaxStudents,
      newAiLimit: newPlanId == 'starter' ? 10 : -1,
      summaryMessage:
          isUpgrade
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
        PlanFeatureModel(
          title: 'Até 3 alunos ativos simultâneos',
          included: true,
        ),
        PlanFeatureModel(
          title: '10 fichas inteligentes com IA / mês',
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
          title: 'Alertas automáticos no WhatsApp',
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
          title: 'Prescrições de Treino com IA Ilimitadas',
          included: true,
          highlight: true,
        ),
        PlanFeatureModel(
          title: 'Anamnese clínica detalhada e restrições',
          included: true,
        ),
        PlanFeatureModel(
          title: 'Raio-X Muscular e Análise de Fases',
          included: true,
          highlight: true,
        ),
        PlanFeatureModel(
          title: 'Timer de descanso interativo sincronizado',
          included: true,
        ),
        PlanFeatureModel(
          title: 'Painel de alertas de adaptação em tempo real',
          included: true,
          highlight: true,
        ),
        PlanFeatureModel(
          title: 'Suporte prioritário via WhatsApp',
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
          title: 'Prescrições de Treino com IA Ilimitadas',
          included: true,
          highlight: true,
        ),
        PlanFeatureModel(
          title: 'Automação inteligente no WhatsApp',
          included: true,
          highlight: true,
        ),
        PlanFeatureModel(
          title: 'Alertas de dor e frequência no WhatsApp',
          included: true,
          highlight: true,
        ),
        PlanFeatureModel(
          title: 'Relatórios de assiduidade e retenção',
          included: true,
          highlight: true,
        ),
        PlanFeatureModel(
          title: 'Suporte prioritário VIP via WhatsApp',
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
      badge: 'ESCALA MÁXIMA',
      features: [
        PlanFeatureModel(
          title: 'Até 100 alunos ativos na assessoria',
          included: true,
          highlight: true,
        ),
        PlanFeatureModel(
          title: 'Prescrições e adaptações com IA Ilimitadas',
          included: true,
          highlight: true,
        ),
        PlanFeatureModel(
          title: 'Múltiplos treinadores na mesma conta',
          included: true,
          highlight: true,
        ),
        PlanFeatureModel(
          title: 'Alertas de dor e retenção no WhatsApp',
          included: true,
          highlight: true,
        ),
        PlanFeatureModel(
          title: 'Relatórios de assiduidade e retenção',
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

  /// Valida cupom promocional no checkout com fallback offline inteligente
  static Future<CouponValidationResult> validateCoupon({
    required String code,
    required String planId,
    required double basePrice,
  }) async {
    final cleanCode = code.trim().toUpperCase();
    if (cleanCode.isEmpty) {
      return const CouponValidationResult(
        valid: false,
        code: '',
        discountType: 'percent',
        discountValue: 0.0,
        discountAmount: 0.0,
        finalPrice: 0.0,
        firstMonthOnly: true,
        message: 'Por favor, informe o código do cupom.',
      );
    }

    try {
      final uri = Uri.parse('${AppConfig.apiBaseUrl}/subscriptions/validate-coupon');
      final body = jsonEncode({
        'code': cleanCode,
        'plan_id': planId,
        'base_price': basePrice,
      });

      final res = await _client
          .post(uri, headers: _headers, body: body)
          .timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        return CouponValidationResult.fromJson(data);
      } else {
        try {
          if (res.bodyBytes.isNotEmpty) {
            final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
            if (data.containsKey('detail') || data.containsKey('message')) {
              return CouponValidationResult(
                valid: false,
                code: cleanCode,
                discountType: 'percent',
                discountValue: 0.0,
                discountAmount: 0.0,
                finalPrice: basePrice,
                firstMonthOnly: true,
                message: (data['detail'] ?? data['message']).toString(),
              );
            }
          }
        } catch (_) {}
        return _fallbackValidateCoupon(
          code: cleanCode,
          planId: planId,
          basePrice: basePrice,
        );
      }
    } catch (_) {
      return _fallbackValidateCoupon(
        code: cleanCode,
        planId: planId,
        basePrice: basePrice,
      );
    }
  }

  static CouponValidationResult _fallbackValidateCoupon({
    required String code,
    required String planId,
    required double basePrice,
  }) {
    final knownCoupons = {
      'LAUNCH50': {'type': 'percent', 'val': 50.0, 'plans': ['all', 'starter', 'pro', 'elite']},
      'BEMVINDO50': {'type': 'percent', 'val': 50.0, 'plans': ['all', 'starter', 'pro', 'elite']},
      'PROMOVIP20': {'type': 'fixed', 'val': 20.0, 'plans': ['all', 'pro', 'elite']},
      'CREFPRIME': {'type': 'fixed', 'val': 15.0, 'plans': ['starter', 'pro']},
      'START2026': {'type': 'fixed', 'val': 30.0, 'plans': ['all', 'pro', 'elite']},
    };

    final info = knownCoupons[code];
    if (info == null) {
      return CouponValidationResult(
        valid: false,
        code: code,
        discountType: 'percent',
        discountValue: 0.0,
        discountAmount: 0.0,
        finalPrice: basePrice,
        firstMonthOnly: true,
        message: 'Cupom "$code" não encontrado ou expirado.',
      );
    }

    final allowedPlans = (info['plans'] as List<String>);
    if (!allowedPlans.contains('all') && !allowedPlans.contains(planId.toLowerCase())) {
      return CouponValidationResult(
        valid: false,
        code: code,
        discountType: info['type'] as String,
        discountValue: info['val'] as double,
        discountAmount: 0.0,
        finalPrice: basePrice,
        firstMonthOnly: true,
        message: 'Este cupom não é aplicável ao plano selecionado.',
      );
    }

    final type = info['type'] as String;
    final val = info['val'] as double;
    final discount = type == 'percent'
        ? (basePrice * (val / 100.0))
        : (val > basePrice ? basePrice : val);
    final finalPrice = (basePrice - discount).clamp(0.0, double.infinity);

    return CouponValidationResult(
      valid: true,
      code: code,
      discountType: type,
      discountValue: val,
      discountAmount: discount,
      finalPrice: finalPrice,
      firstMonthOnly: true,
      message: 'Desconto de R\$ ${discount.toStringAsFixed(2)} aplicado!',
    );
  }
}

