import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/config/app_config.dart';
import 'auth_service.dart';

class WalletSummary {
  final int balanceCents;
  final int pendingBalanceCents;
  final int totalBilledMonthCents;
  final String? pixKey;
  final String pixKeyType;
  final String? bankName;
  final String? asaasAccountId;
  final String? asaasWalletId;
  final String asaasAccountStatus;
  final int totalSplitsCount;
  final int settledSplitsCount;
  final int pendingSplitsCount;
  final int settledGrossCents;
  final int settledNetCents;
  final int settledFeeCents;
  final int pendingGrossCents;
  final int pendingNetCents;

  WalletSummary({
    required this.balanceCents,
    required this.pendingBalanceCents,
    required this.totalBilledMonthCents,
    this.pixKey,
    this.pixKeyType = 'cpf',
    this.bankName,
    this.asaasAccountId,
    this.asaasWalletId,
    this.asaasAccountStatus = 'unlinked',
    this.totalSplitsCount = 0,
    this.settledSplitsCount = 0,
    this.pendingSplitsCount = 0,
    this.settledGrossCents = 0,
    this.settledNetCents = 0,
    this.settledFeeCents = 0,
    this.pendingGrossCents = 0,
    this.pendingNetCents = 0,
  });

  factory WalletSummary.fromJson(Map<String, dynamic> json) {
    return WalletSummary(
      balanceCents: json['balance_cents'] as int? ?? 0,
      pendingBalanceCents: json['pending_balance_cents'] as int? ?? 0,
      totalBilledMonthCents: json['total_billed_month_cents'] as int? ?? 0,
      pixKey: json['pix_key'] as String?,
      pixKeyType: json['pix_key_type'] as String? ?? 'cpf',
      bankName: json['bank_name'] as String?,
      asaasAccountId: json['asaas_account_id'] as String?,
      asaasWalletId: json['asaas_wallet_id'] as String?,
      asaasAccountStatus: json['asaas_account_status'] as String? ?? 'unlinked',
      totalSplitsCount: json['total_splits_count'] as int? ?? 0,
      settledSplitsCount: json['settled_splits_count'] as int? ?? 0,
      pendingSplitsCount: json['pending_splits_count'] as int? ?? 0,
      settledGrossCents: json['settled_gross_cents'] as int? ?? 0,
      settledNetCents: json['settled_net_cents'] as int? ?? 0,
      settledFeeCents: json['settled_fee_cents'] as int? ?? 0,
      pendingGrossCents: json['pending_gross_cents'] as int? ?? 0,
      pendingNetCents: json['pending_net_cents'] as int? ?? 0,
    );
  }

  double get balance => balanceCents / 100.0;
  double get pendingBalance => pendingBalanceCents / 100.0;
  double get totalBilledMonth => totalBilledMonthCents / 100.0;
  double get settledGross => settledGrossCents / 100.0;
  double get settledNet => settledNetCents / 100.0;
  double get settledFee => settledFeeCents / 100.0;
  double get pendingGross => pendingGrossCents / 100.0;
  double get pendingNet => pendingNetCents / 100.0;
  bool get isAsaasActive => asaasAccountStatus == 'active' || (asaasWalletId != null && asaasWalletId!.isNotEmpty);
}

class StudentInvoice {
  final String id;
  final String trainerId;
  final String? studentId;
  final String studentName;
  final String? studentPhone;
  final String? studentEmail;
  final String title;
  final String? description;
  final int amountCents;
  final int platformFeeCents;
  final int netAmountCents;
  final String status; // 'pending', 'paid', 'canceled'
  final String dueDate;
  final String? paidAt;
  final String? paymentLink;
  final String? pixCopyPaste;
  final String? paymentMethod;
  final String? asaasPaymentId;
  final String? asaasWalletId;
  final String? jwsSplitToken;
  final String splitStatus; // 'pending', 'settled', 'reversed'
  final String createdAt;

  StudentInvoice({
    required this.id,
    required this.trainerId,
    this.studentId,
    required this.studentName,
    this.studentPhone,
    this.studentEmail,
    required this.title,
    this.description,
    required this.amountCents,
    required this.platformFeeCents,
    required this.netAmountCents,
    required this.status,
    required this.dueDate,
    this.paidAt,
    this.paymentLink,
    this.pixCopyPaste,
    this.paymentMethod = 'pix',
    this.asaasPaymentId,
    this.asaasWalletId,
    this.jwsSplitToken,
    this.splitStatus = 'pending',
    required this.createdAt,
  });

  factory StudentInvoice.fromJson(Map<String, dynamic> json) {
    return StudentInvoice(
      id: json['id'] as String? ?? '',
      trainerId: json['trainer_id'] as String? ?? '',
      studentId: json['student_id'] as String?,
      studentName: json['student_name'] as String? ?? 'Aluno',
      studentPhone: json['student_phone'] as String?,
      studentEmail: json['student_email'] as String?,
      title: json['title'] as String? ?? 'Consultoria',
      description: json['description'] as String?,
      amountCents: json['amount_cents'] as int? ?? 0,
      platformFeeCents: json['platform_fee_cents'] as int? ?? 0,
      netAmountCents: json['net_amount_cents'] as int? ?? 0,
      status: json['status'] as String? ?? 'pending',
      dueDate: json['due_date'] as String? ?? '',
      paidAt: json['paid_at'] as String?,
      paymentLink: json['payment_link'] as String?,
      pixCopyPaste: json['pix_copy_paste'] as String?,
      paymentMethod: json['payment_method'] as String? ?? 'pix',
      asaasPaymentId: json['asaas_payment_id'] as String?,
      asaasWalletId: json['asaas_wallet_id'] as String?,
      jwsSplitToken: json['jws_split_token'] as String?,
      splitStatus: json['split_status'] as String? ?? 'pending',
      createdAt: json['created_at'] as String? ?? '',
    );
  }

  double get amount => amountCents / 100.0;
  double get netAmount => netAmountCents / 100.0;
  double get platformFee => platformFeeCents / 100.0;
  bool get isPaid => status == 'paid';
  bool get isSettled => splitStatus == 'settled' || status == 'paid';
  bool get isReversed => splitStatus == 'reversed' || status == 'canceled';
  bool get hasJwsAudit => jwsSplitToken != null && jwsSplitToken!.isNotEmpty;
}

class WalletSplitsCockpitData {
  final WalletSummary summary;
  final List<StudentInvoice> items;

  WalletSplitsCockpitData({
    required this.summary,
    required this.items,
  });

  factory WalletSplitsCockpitData.fromJson(Map<String, dynamic> json) {
    return WalletSplitsCockpitData(
      summary: WalletSummary.fromJson(json['summary'] as Map<String, dynamic>? ?? {}),
      items: (json['items'] as List<dynamic>? ?? [])
          .map((e) => StudentInvoice.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class WalletService {
  static Future<Map<String, String>> _headers() async {
    final token = AuthService.accessToken;
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<WalletSummary> getSummary() async {
    try {
      final res = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/wallet/summary'),
        headers: await _headers(),
      );
      if (res.statusCode == 200) {
        return WalletSummary.fromJson(jsonDecode(res.body));
      }
    } catch (_) {}
    return WalletSummary(balanceCents: 0, pendingBalanceCents: 0, totalBilledMonthCents: 0);
  }

  static Future<WalletSummary?> updatePixKey({
    required String pixKey,
    required String pixKeyType,
    String? bankName,
  }) async {
    try {
      final res = await http.put(
        Uri.parse('${AppConfig.apiBaseUrl}/wallet/pix-key'),
        headers: await _headers(),
        body: jsonEncode({
          'pix_key': pixKey,
          'pix_key_type': pixKeyType,
          'bank_name': bankName,
        }),
      );
      if (res.statusCode == 200) {
        return WalletSummary.fromJson(jsonDecode(res.body));
      }
    } catch (_) {}
    return null;
  }

  static Future<List<StudentInvoice>> getInvoices() async {
    try {
      final res = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/wallet/invoices'),
        headers: await _headers(),
      );
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List<dynamic>;
        return list.map((item) => StudentInvoice.fromJson(item)).toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<WalletSplitsCockpitData> getSplitsCockpit() async {
    try {
      final res = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/wallet/splits'),
        headers: await _headers(),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        return WalletSplitsCockpitData.fromJson(data);
      }
    } catch (_) {}
    // Fallback unificado combinando resumo e faturas
    final summary = await getSummary();
    final items = await getInvoices();
    return WalletSplitsCockpitData(summary: summary, items: items);
  }

  static Future<StudentInvoice?> createInvoice({
    required String studentName,
    required String title,
    required int amountCents,
    String? studentPhone,
    String? studentEmail,
    String? studentId,
    String? dueDate,
    bool sendWhatsapp = true,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/wallet/invoices'),
        headers: await _headers(),
        body: jsonEncode({
          'student_name': studentName,
          'title': title,
          'amount_cents': amountCents,
          'student_phone': studentPhone,
          'student_email': studentEmail,
          'student_id': studentId,
          'due_date': dueDate,
          'send_whatsapp': sendWhatsapp,
        }),
      );
      if (res.statusCode == 201) {
        return StudentInvoice.fromJson(jsonDecode(res.body));
      }
    } catch (_) {}
    return null;
  }

  static Future<StudentInvoice?> markPaid(String invoiceId) async {
    try {
      final res = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/wallet/invoices/$invoiceId/mark-paid'),
        headers: await _headers(),
      );
      if (res.statusCode == 200) {
        return StudentInvoice.fromJson(jsonDecode(res.body));
      }
    } catch (_) {}
    return null;
  }

  static Future<Map<String, dynamic>> requestWithdrawal(int amountCents) async {
    try {
      final res = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/wallet/withdraw'),
        headers: await _headers(),
        body: jsonEncode({'amount_cents': amountCents}),
      );
      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        return {'success': true, 'message': data['message'] ?? 'Saque realizado com sucesso!'};
      }
      return {'success': false, 'message': data['detail'] ?? 'Erro ao processar saque.'};
    } catch (e) {
      return {'success': false, 'message': 'Falha na conexão ao solicitar saque.'};
    }
  }
}

