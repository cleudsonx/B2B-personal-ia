class PlanFeatureModel {
  final String title;
  final bool included;
  final bool highlight;

  PlanFeatureModel({
    required this.title,
    required this.included,
    this.highlight = false,
  });

  factory PlanFeatureModel.fromJson(Map<String, dynamic> json) {
    return PlanFeatureModel(
      title: json['title'] ?? '',
      included: json['included'] ?? true,
      highlight: json['highlight'] ?? false,
    );
  }
}

class PlanModel {
  final String id;
  final String name;
  final String tagline;
  final int priceMonthlyCents;
  final int priceYearlyCents;
  final int priceYearlyMonthlyEquivalentCents;
  final int maxStudents;
  final int maxAiGenerationsPerMonth;
  final bool isPopular;
  final String? badge;
  final List<PlanFeatureModel> features;

  PlanModel({
    required this.id,
    required this.name,
    required this.tagline,
    required this.priceMonthlyCents,
    required this.priceYearlyCents,
    required this.priceYearlyMonthlyEquivalentCents,
    required this.maxStudents,
    required this.maxAiGenerationsPerMonth,
    required this.isPopular,
    this.badge,
    required this.features,
  });

  double get priceMonthly => priceMonthlyCents / 100.0;
  double get priceYearlyMonthlyEquivalent => priceYearlyMonthlyEquivalentCents / 100.0;
  double get priceYearlyTotal => priceYearlyCents / 100.0;

  factory PlanModel.fromJson(Map<String, dynamic> json) {
    return PlanModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      tagline: json['tagline'] ?? '',
      priceMonthlyCents: json['price_monthly_cents'] ?? 0,
      priceYearlyCents: json['price_yearly_cents'] ?? 0,
      priceYearlyMonthlyEquivalentCents: json['price_yearly_monthly_equivalent_cents'] ?? 0,
      maxStudents: json['max_students'] ?? 3,
      maxAiGenerationsPerMonth: json['max_ai_generations_per_month'] ?? 10,
      isPopular: json['is_popular'] ?? false,
      badge: json['badge'],
      features: (json['features'] as List<dynamic>?)
              ?.map((f) => PlanFeatureModel.fromJson(f as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class MySubscriptionModel {
  final String planId;
  final String planName;
  final String status;
  final String billingInterval;
  final int currentStudents;
  final int maxStudents;
  final int aiGenerationsUsed;
  final int maxAiGenerations;
  final int? trialDaysRemaining;
  final String? nextBillingDate;
  final String? paymentMethod;
  final bool canCreateStudent;
  final bool canGenerateAi;

  MySubscriptionModel({
    required this.planId,
    required this.planName,
    required this.status,
    required this.billingInterval,
    required this.currentStudents,
    required this.maxStudents,
    required this.aiGenerationsUsed,
    required this.maxAiGenerations,
    this.trialDaysRemaining,
    this.nextBillingDate,
    this.paymentMethod,
    required this.canCreateStudent,
    required this.canGenerateAi,
  });

  factory MySubscriptionModel.fromJson(Map<String, dynamic> json) {
    return MySubscriptionModel(
      planId: json['plan_id'] ?? 'pro',
      planName: json['plan_name'] ?? 'Personal Pro',
      status: json['status'] ?? 'active',
      billingInterval: json['billing_interval'] ?? 'monthly',
      currentStudents: json['current_students'] ?? 4,
      maxStudents: json['max_students'] ?? 30,
      aiGenerationsUsed: json['ai_generations_used'] ?? 12,
      maxAiGenerations: json['max_ai_generations'] ?? -1,
      trialDaysRemaining: json['trial_days_remaining'],
      nextBillingDate: json['next_billing_date'],
      paymentMethod: json['payment_method'] ?? 'pix',
      canCreateStudent: json['can_create_student'] ?? true,
      canGenerateAi: json['can_generate_ai'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'plan_id': planId,
      'plan_name': planName,
      'status': status,
      'billing_interval': billingInterval,
      'current_students': currentStudents,
      'max_students': maxStudents,
      'ai_generations_used': aiGenerationsUsed,
      'max_ai_generations': maxAiGenerations,
      'trial_days_remaining': trialDaysRemaining,
      'next_billing_date': nextBillingDate,
      'payment_method': paymentMethod,
      'can_create_student': canCreateStudent,
      'can_generate_ai': canGenerateAi,
    };
  }
}

class CheckoutSessionModel {
  final String sessionId;
  final String planId;
  final String planName;
  final int amountCents;
  final String billingInterval;
  final String paymentMethod;
  final String? pixCopyPaste;
  final String? checkoutUrl;
  final String? provider;
  final String status;
  final String expiresAt;

  CheckoutSessionModel({
    required this.sessionId,
    required this.planId,
    required this.planName,
    required this.amountCents,
    required this.billingInterval,
    required this.paymentMethod,
    this.pixCopyPaste,
    this.checkoutUrl,
    this.provider,
    required this.status,
    required this.expiresAt,
  });

  double get amount => amountCents / 100.0;

  factory CheckoutSessionModel.fromJson(Map<String, dynamic> json) {
    return CheckoutSessionModel(
      sessionId: json['session_id'] ?? '',
      planId: json['plan_id'] ?? '',
      planName: json['plan_name'] ?? '',
      amountCents: json['amount_cents'] ?? 0,
      billingInterval: json['billing_interval'] ?? 'monthly',
      paymentMethod: json['payment_method'] ?? 'pix',
      pixCopyPaste: json['pix_copy_paste'],
      checkoutUrl: json['checkout_url'],
      provider: json['provider'],
      status: json['status'] ?? 'pending',
      expiresAt: json['expires_at'] ?? '',
    );
  }
}

class PlanChangeSimulationModel {
  final String changeType; // 'upgrade', 'downgrade', 'same'
  final bool isBlocked;
  final String? blockReason;
  final String currentPlanName;
  final String newPlanName;
  final int currentPlanPriceCents;
  final int newPlanPriceCents;
  final int unusedCreditCents;
  final int netChargeCents;
  final String effectiveDate;
  final int newStudentLimit;
  final int newAiLimit;
  final String summaryMessage;

  PlanChangeSimulationModel({
    required this.changeType,
    required this.isBlocked,
    this.blockReason,
    required this.currentPlanName,
    required this.newPlanName,
    required this.currentPlanPriceCents,
    required this.newPlanPriceCents,
    required this.unusedCreditCents,
    required this.netChargeCents,
    required this.effectiveDate,
    required this.newStudentLimit,
    required this.newAiLimit,
    required this.summaryMessage,
  });

  double get unusedCredit => unusedCreditCents / 100.0;
  double get netCharge => netChargeCents / 100.0;

  factory PlanChangeSimulationModel.fromJson(Map<String, dynamic> json) {
    return PlanChangeSimulationModel(
      changeType: json['change_type'] ?? 'upgrade',
      isBlocked: json['is_blocked'] ?? false,
      blockReason: json['block_reason'],
      currentPlanName: json['current_plan_name'] ?? '',
      newPlanName: json['new_plan_name'] ?? '',
      currentPlanPriceCents: json['current_plan_price_cents'] ?? 0,
      newPlanPriceCents: json['new_plan_price_cents'] ?? 0,
      unusedCreditCents: json['unused_credit_cents'] ?? 0,
      netChargeCents: json['net_charge_cents'] ?? 0,
      effectiveDate: json['effective_date'] ?? 'Imediato',
      newStudentLimit: json['new_student_limit'] ?? 30,
      newAiLimit: json['new_ai_limit'] ?? -1,
      summaryMessage: json['summary_message'] ?? '',
    );
  }
}
