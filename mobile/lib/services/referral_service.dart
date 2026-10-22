import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/config/app_config.dart';

/// Informações públicas e enriquecidas de um parceiro de indicação / afiliado.
class ReferralPartnerInfo {
  final String slug;
  final String partnerName;
  final String partnerType; // 'association', 'influencer', 'studio', 'podcast'
  final String? associatedCouponCode;
  final double commissionPercent;
  final bool isActive;
  final String headline;
  final String badge;
  final String description;

  const ReferralPartnerInfo({
    required this.slug,
    required this.partnerName,
    required this.partnerType,
    this.associatedCouponCode,
    this.commissionPercent = 15.0,
    this.isActive = true,
    required this.headline,
    required this.badge,
    required this.description,
  });

  factory ReferralPartnerInfo.fromJson(Map<String, dynamic> json) {
    final slug = (json['slug'] as String? ?? '').trim().toUpperCase();
    final name = json['partner_name'] as String? ?? 'Parceiro Oficial';
    return ReferralPartnerInfo(
      slug: slug,
      partnerName: name,
      partnerType: json['partner_type'] as String? ?? 'influencer',
      associatedCouponCode: json['associated_coupon_code'] as String?,
      commissionPercent: (json['commission_percent'] as num?)?.toDouble() ?? 15.0,
      isActive: json['is_active'] as bool? ?? true,
      headline: json['headline'] as String? ?? 'Parceria Oficial $name & Mr. Coach',
      badge: json['badge'] as String? ?? 'PARCERIA EXCLUSIVA',
      description: json['description'] as String? ??
          'Condição especial e desconto VIP no ecossistema Mr. Coach para Personal Trainers.',
    );
  }

  Map<String, dynamic> toJson() => {
        'slug': slug,
        'partner_name': partnerName,
        'partner_type': partnerType,
        'associated_coupon_code': associatedCouponCode,
        'commission_percent': commissionPercent,
        'is_active': isActive,
        'headline': headline,
        'badge': badge,
        'description': description,
      };
}

/// Motor cliente para Rastreamento de Indicação, Atribuição de Afiliados e Auto-Vínculo de Cupons.
class ReferralService {
  static const String _keySlug = 'referral_active_slug';
  static const String _keyCoupon = 'referral_active_coupon';
  static const String _keyName = 'referral_active_partner_name';
  static const String _keyTimestamp = 'referral_attributed_at';

  static ReferralPartnerInfo? _activePartner;

  /// Retorna o parceiro atualmente carregado em memória.
  static ReferralPartnerInfo? get activePartner => _activePartner;

  /// Retorna o slug ativo da indicação em memória ou SharedPreferences.
  static String? getActiveReferralSlug() => _activePartner?.slug;

  /// Retorna o cupom promocional vinculado à indicação ativa.
  static String? getActiveReferralCoupon() => _activePartner?.associatedCouponCode;

  /// Dicionário canônico de fallback para resiliência offline e respostas instantâneas.
  static final Map<String, ReferralPartnerInfo> _canonicalPartners = {
    'CREFSP': const ReferralPartnerInfo(
      slug: 'CREFSP',
      partnerName: 'Conselho Regional de Educação Física (CREF-SP)',
      partnerType: 'association',
      associatedCouponCode: 'CREFSP20',
      commissionPercent: 15.0,
      isActive: true,
      headline: 'Parceria Homologada CREF-SP & Mr. Coach',
      badge: 'PARCERIA HOMOLOGADA',
      description:
          'Benefício exclusivo para profissionais registrados no CREF-SP: 20% de desconto no ecossistema de Prescrição IA e Gestão de Alunos.',
    ),
    'IRONRUNNER': const ReferralPartnerInfo(
      slug: 'IRONRUNNER',
      partnerName: 'Iron Runner Assessoria & Running Club',
      partnerType: 'influencer',
      associatedCouponCode: 'IRON30',
      commissionPercent: 20.0,
      isActive: true,
      headline: 'Vantagem Exclusiva Iron Runner Club',
      badge: 'ASSESSORIA ELITE',
      description:
          'Condição especial de 30% OFF para treinadores da comunidade Iron Runner modernizarem seu atendimento com IA.',
    ),
    'RODRIGO-VIP': const ReferralPartnerInfo(
      slug: 'RODRIGO-VIP',
      partnerName: 'Rodrigo Personal VIP',
      partnerType: 'influencer',
      associatedCouponCode: 'RODRIGO15',
      commissionPercent: 15.0,
      isActive: true,
      headline: 'Indicação Especial do Embaixador Rodrigo',
      badge: 'EMBAIXADOR OFICIAL',
      description:
          'Aproveite 15% de desconto no primeiro ano e acelere a fidelização dos seus alunos com o Mr. Coach.',
    ),
    'FITSTUDIO': const ReferralPartnerInfo(
      slug: 'FITSTUDIO',
      partnerName: 'FitStudio Rede de Academias',
      partnerType: 'studio',
      associatedCouponCode: 'STUDIO50',
      commissionPercent: 12.0,
      isActive: true,
      headline: 'Rede de Studios & Academias FitStudio',
      badge: 'REDE CORPORATIVA',
      description:
          '50% de desconto no primeiro mês para coordenadores e personals credenciados da rede FitStudio.',
    ),
  };

  /// Carrega informações do parceiro com resiliência: API Backend -> Fallback Canônico.
  static Future<ReferralPartnerInfo?> getOrFetchPartner(
    String slug, {
    bool recordClick = true,
  }) async {
    final cleanSlug = slug.trim().toUpperCase();
    if (cleanSlug.isEmpty) return null;

    try {
      final uri = Uri.parse(
        '${AppConfig.apiBaseUrl}/api/v1/subscriptions/referral-partner/$cleanSlug?record_click=$recordClick',
      );
      final response = await http
          .get(uri, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final partner = ReferralPartnerInfo.fromJson(data);
        await saveActiveReferral(partner);
        return partner;
      }
    } catch (e) {
      debugPrint('[ReferralService] Aviso ao consultar API de parceiro: $e');
    }

    // Fallback canônico
    if (_canonicalPartners.containsKey(cleanSlug)) {
      final fallback = _canonicalPartners[cleanSlug]!;
      await saveActiveReferral(fallback);
      return fallback;
    }

    // Cria fallback genérico para slugs customizados
    final generic = ReferralPartnerInfo(
      slug: cleanSlug,
      partnerName: 'Parceiro $cleanSlug',
      partnerType: 'influencer',
      associatedCouponCode: cleanSlug,
      commissionPercent: 15.0,
      isActive: true,
      headline: 'Parceria Oficial $cleanSlug & Mr. Coach',
      badge: 'CONVITE ESPECIAL',
      description: 'Você recebeu um convite VIP para ingressar no Mr. Coach com condições promocionais.',
    );
    await saveActiveReferral(generic);
    return generic;
  }

  /// Salva o parceiro ativo no cache de memória e no SharedPreferences.
  static Future<void> saveActiveReferral(ReferralPartnerInfo partner) async {
    _activePartner = partner;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keySlug, partner.slug);
      if (partner.associatedCouponCode != null) {
        await prefs.setString(_keyCoupon, partner.associatedCouponCode!);
      }
      await prefs.setString(_keyName, partner.partnerName);
      await prefs.setString(_keyTimestamp, DateTime.now().toIso8601String());
    } catch (_) {}
  }

  /// Restaura o parceiro persistido no SharedPreferences na inicialização do app.
  static Future<void> restorePersistedReferral() async {
    if (_activePartner != null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final slug = prefs.getString(_keySlug);
      final coupon = prefs.getString(_keyCoupon);
      final name = prefs.getString(_keyName);

      if (slug != null && slug.isNotEmpty) {
        if (_canonicalPartners.containsKey(slug)) {
          _activePartner = _canonicalPartners[slug];
        } else {
          _activePartner = ReferralPartnerInfo(
            slug: slug,
            partnerName: name ?? 'Parceiro $slug',
            partnerType: 'influencer',
            associatedCouponCode: coupon ?? slug,
            headline: 'Parceria Oficial ${name ?? slug} & Mr. Coach',
            badge: 'CONVITE ESPECIAL',
            description: 'Você recebeu um convite VIP com condições exclusivas no Mr. Coach.',
          );
        }
      }
    } catch (_) {}
  }

  /// Inspeciona uma Uri para extrair e registrar referências vindas de query params (`?ref=SLUG`).
  static Future<ReferralPartnerInfo?> initFromUri(Uri uri) async {
    final ref = uri.queryParameters['ref'] ?? uri.queryParameters['r'];
    if (ref != null && ref.trim().isNotEmpty) {
      return await getOrFetchPartner(ref.trim());
    }
    return null;
  }

  /// Limpa a referência ativa (por exemplo, após uso ou encerramento explícito).
  static Future<void> clearReferral() async {
    _activePartner = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keySlug);
      await prefs.remove(_keyCoupon);
      await prefs.remove(_keyName);
      await prefs.remove(_keyTimestamp);
    } catch (_) {}
  }

  /// Registra conversão de assinatura no backend.
  static Future<bool> recordReferralConversion({
    required String planId,
    required double amountBrl,
  }) async {
    final slug = getActiveReferralSlug();
    if (slug == null || slug.isEmpty) return false;

    try {
      final uri = Uri.parse('${AppConfig.apiBaseUrl}/api/v1/subscriptions/record-referral-conversion');
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'slug': slug,
              'plan_id': planId,
              'amount_brl': amountBrl,
            }),
          )
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        debugPrint('[ReferralService] Conversão registrada com sucesso para $slug');
        return true;
      }
    } catch (e) {
      debugPrint('[ReferralService] Falha ao registrar conversão no backend: $e');
    }
    return false;
  }
}

