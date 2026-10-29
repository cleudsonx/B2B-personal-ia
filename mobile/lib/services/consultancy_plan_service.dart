import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/config/app_config.dart';
import 'auth_service.dart';

class ConsultancyPlan {
  final String id;
  final String trainerId;
  final String name;
  final String? description;
  final int priceCents;
  final String billingPeriod; // 'monthly', 'quarterly', 'semiannual', 'annual', 'one_time'
  final List<String> features;
  final bool isActive;
  final int sortOrder;
  final String? createdAt;
  final String? updatedAt;

  ConsultancyPlan({
    required this.id,
    required this.trainerId,
    required this.name,
    this.description,
    required this.priceCents,
    this.billingPeriod = 'monthly',
    this.features = const [],
    this.isActive = true,
    this.sortOrder = 0,
    this.createdAt,
    this.updatedAt,
  });

  double get price => priceCents / 100.0;

  String get billingPeriodLabel {
    switch (billingPeriod) {
      case 'monthly':
        return 'Mensal';
      case 'quarterly':
        return 'Trimestral';
      case 'semiannual':
        return 'Semestral';
      case 'annual':
        return 'Anual';
      case 'one_time':
        return 'Ficha Avulsa';
      default:
        return 'Mensal';
    }
  }

  factory ConsultancyPlan.fromJson(Map<String, dynamic> json) {
    List<String> feats = [];
    if (json['features'] != null) {
      if (json['features'] is List) {
        feats = (json['features'] as List).map((e) => e.toString()).toList();
      } else if (json['features'] is String) {
        try {
          final decoded = jsonDecode(json['features'] as String);
          if (decoded is List) {
            feats = decoded.map((e) => e.toString()).toList();
          }
        } catch (_) {}
      }
    }

    return ConsultancyPlan(
      id: json['id'] as String,
      trainerId: json['trainer_id'] as String? ?? '',
      name: json['name'] as String? ?? 'Plano de Consultoria',
      description: json['description'] as String?,
      priceCents: json['price_cents'] as int? ?? 10000,
      billingPeriod: json['billing_period'] as String? ?? 'monthly',
      features: feats,
      isActive: json['is_active'] as bool? ?? true,
      sortOrder: json['sort_order'] as int? ?? 0,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'price_cents': priceCents,
      'billing_period': billingPeriod,
      'features': features,
      'is_active': isActive,
      'sort_order': sortOrder,
    };
  }
}

class PublicCheckoutResult {
  final String invoiceId;
  final String status;
  final String paymentMethod;
  final int amountCents;
  final int netAmountCents;
  final int platformFeeCents;
  final String? pixCopyPaste;
  final String? pixQrCodeBase64;
  final String? checkoutUrl;
  final String message;
  final String trainerName;
  final String planName;
  final String? authEmail;
  final String? authToken;
  final String? accessUrl;

  PublicCheckoutResult({
    required this.invoiceId,
    required this.status,
    required this.paymentMethod,
    required this.amountCents,
    required this.netAmountCents,
    required this.platformFeeCents,
    this.pixCopyPaste,
    this.pixQrCodeBase64,
    this.checkoutUrl,
    required this.message,
    required this.trainerName,
    required this.planName,
    this.authEmail,
    this.authToken,
    this.accessUrl,
  });

  double get amount => amountCents / 100.0;
  double get netAmount => netAmountCents / 100.0;
  double get platformFee => platformFeeCents / 100.0;

  factory PublicCheckoutResult.fromJson(Map<String, dynamic> json) {
    return PublicCheckoutResult(
      invoiceId: json['invoice_id'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      paymentMethod: json['payment_method'] as String? ?? 'PIX',
      amountCents: json['amount_cents'] as int? ?? 0,
      netAmountCents: json['net_amount_cents'] as int? ?? 0,
      platformFeeCents: json['platform_fee_cents'] as int? ?? 0,
      pixCopyPaste: json['pix_copy_paste'] as String?,
      pixQrCodeBase64: json['pix_qr_code_base64'] as String?,
      checkoutUrl: json['checkout_url'] as String?,
      message: json['message'] as String? ?? 'Cobrança gerada com sucesso!',
      trainerName: json['trainer_name'] as String? ?? 'Personal Trainer',
      planName: json['plan_name'] as String? ?? 'Consultoria',
      authEmail: json['auth_email'] as String?,
      authToken: json['auth_token'] as String?,
      accessUrl: json['access_url'] as String?,
    );
  }
}

class ConsultancyPlanService {
  static Map<String, String> get _headers {
    final token = AuthService.currentSession?.accessToken;
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Lista todos os planos de consultoria do personal autenticado
  static Future<List<ConsultancyPlan>> getMyPlans() async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/trainers/consultancy-plans');
    try {
      final res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        final List<dynamic> list = jsonDecode(utf8.decode(res.bodyBytes));
        return list.map((item) => ConsultancyPlan.fromJson(item as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return _defaultTemplates();
  }

  /// Cria um novo plano de consultoria
  static Future<ConsultancyPlan> createPlan({
    required String name,
    String? description,
    required int priceCents,
    String billingPeriod = 'monthly',
    List<String> features = const [],
    bool isActive = true,
    int sortOrder = 0,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/trainers/consultancy-plans');
    final body = jsonEncode({
      'name': name,
      'description': description,
      'price_cents': priceCents,
      'billing_period': billingPeriod,
      'features': features,
      'is_active': isActive,
      'sort_order': sortOrder,
    });

    final res = await http.post(uri, headers: _headers, body: body).timeout(const Duration(seconds: 15));
    if (res.statusCode == 201) {
      return ConsultancyPlan.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    }
    throw Exception('Falha ao criar plano de consultoria (${res.statusCode})');
  }

  /// Atualiza dados de um plano existente
  static Future<ConsultancyPlan> updatePlan({
    required String planId,
    String? name,
    String? description,
    int? priceCents,
    String? billingPeriod,
    List<String>? features,
    bool? isActive,
    int? sortOrder,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/trainers/consultancy-plans/$planId');
    final payload = <String, dynamic>{
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (priceCents != null) 'price_cents': priceCents,
      if (billingPeriod != null) 'billing_period': billingPeriod,
      if (features != null) 'features': features,
      if (isActive != null) 'is_active': isActive,
      if (sortOrder != null) 'sort_order': sortOrder,
    };

    final res = await http.put(uri, headers: _headers, body: jsonEncode(payload)).timeout(const Duration(seconds: 15));
    if (res.statusCode == 200) {
      return ConsultancyPlan.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    }
    throw Exception('Falha ao atualizar plano (${res.statusCode})');
  }

  /// Exclui um plano de consultoria
  static Future<bool> deletePlan(String planId) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/trainers/consultancy-plans/$planId');
    final res = await http.delete(uri, headers: _headers).timeout(const Duration(seconds: 12));
    return res.statusCode == 200;
  }

  /// Lista planos ativos de um treinador pelo seu username na Vitrine Pública
  static Future<List<ConsultancyPlan>> getPublicPlans(String username) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/public/trainers/$username/plans');
    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        final List<dynamic> list = jsonDecode(utf8.decode(res.bodyBytes));
        return list.map((item) => ConsultancyPlan.fromJson(item as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return _defaultTemplates();
  }

  /// Realiza checkout transparente de um novo aluno na vitrine do treinador
  static Future<PublicCheckoutResult> publicCheckout({
    required String username,
    required String planId,
    required String studentName,
    required String studentEmail,
    required String studentPhone,
    String? studentCpf,
    String paymentMethod = 'PIX',
    Map<String, dynamic>? creditCard,
  }) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/public/trainers/$username/checkout');
    final body = jsonEncode({
      'plan_id': planId,
      'student_name': studentName,
      'student_email': studentEmail,
      'student_phone': studentPhone,
      if (studentCpf != null) 'student_cpf': studentCpf,
      'payment_method': paymentMethod,
      if (creditCard != null) 'credit_card': creditCard,
    });

    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: body,
    ).timeout(const Duration(seconds: 20));

    if (res.statusCode == 201) {
      return PublicCheckoutResult.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    }

    String errorMsg = 'Erro ao processar checkout.';
    try {
      final err = jsonDecode(utf8.decode(res.bodyBytes));
      if (err['detail'] != null) errorMsg = err['detail'].toString();
    } catch (_) {}
    throw Exception(errorMsg);
  }


  /// Consulta o status de pagamento de uma fatura de checkout (Pix/Cartão)
  static Future<Map<String, dynamic>> checkInvoiceStatus(
    String invoiceId, {
    bool simulatePaid = false,
  }) async {
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/public/invoices/$invoiceId/status${simulatePaid ? "?simulate_paid=true" : ""}',
    );
    final res = await http.get(
      uri,
      headers: {'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 15));

    if (res.statusCode == 200) {
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    }
    String errorMsg = 'Falha ao consultar fatura.';
    try {
      final err = jsonDecode(utf8.decode(res.bodyBytes));
      if (err['detail'] != null) errorMsg = err['detail'].toString();
    } catch (_) {}
    throw Exception(errorMsg);
  }

  /// Templates padrão caso a internet esteja offline ou início rápido
  static List<ConsultancyPlan> getDefaultTemplates() => _defaultTemplates();

  static List<ConsultancyPlan> _defaultTemplates() {
    return [
      ConsultancyPlan(
        id: 'tpl-1',
        trainerId: '',
        name: 'Consultoria Mensal Pro',
        description: 'Acompanhamento individualizado com treino personalizado, suporte e ajustes no app.',
        priceCents: 15000,
        billingPeriod: 'monthly',
        features: [
          'Prescrição biomecânica completa no app',
          'Substituição inteligente de exercícios',
          'Suporte tira-dúvidas via WhatsApp',
          'Feedback e análise de cargas semanais',
        ],
        isActive: true,
        sortOrder: 1,
      ),
      ConsultancyPlan(
        id: 'tpl-2',
        trainerId: '',
        name: 'Plano Trimestral Evolução',
        description: 'Foco em resultados consistentes: 3 meses de acompanhamento com desconto exclusivo.',
        priceCents: 39000,
        billingPeriod: 'quarterly',
        features: [
          'Periodização completa em 3 mesociclos',
          'Ajustes de carga e volume a cada 4 semanas',
          'Prioridade nas respostas do WhatsApp',
          'Acesso full a todas as funcionalidades do app',
        ],
        isActive: true,
        sortOrder: 2,
      ),
      ConsultancyPlan(
        id: 'tpl-3',
        trainerId: '',
        name: 'Ficha de Treino Avulsa',
        description: 'Prescrição sob medida para seu objetivo específico, sem mensalidade recorrente.',
        priceCents: 8000,
        billingPeriod: 'one_time',
        features: [
          'Anamnese postural e clínica',
          'Ficha A/B ou A/B/C montada no app',
          'Vídeos e instruções biomecânicas',
          'Validade de 6 semanas',
        ],
        isActive: true,
        sortOrder: 3,
      ),
    ];
  }
}

