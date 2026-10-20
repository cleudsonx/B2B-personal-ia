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

  WalletSummary({
    required this.balanceCents,
    required this.pendingBalanceCents,
    required this.totalBilledMonthCents,
    this.pixKey,
    this.pixKeyType = 'cpf',
    this.bankName,
  });

  factory WalletSummary.fromJson(Map<String, dynamic> json) {
    return WalletSummary(
      balanceCents: json['balance_cents'] as int? ?? 0,
      pendingBalanceCents: json['pending_balance_cents'] as int? ?? 0,
      totalBilledMonthCents: json['total_billed_month_cents'] as int? ?? 0,
      pixKey: json['pix_key'] as String?,
      pixKeyType: json['pix_key_type'] as String? ?? 'cpf',
      bankName: json['bank_name'] as String?,
    );
  }

  double get balance => balanceCents / 100.0;
  double get pendingBalance => pendingBalanceCents / 100.0;
  double get totalBilledMonth => totalBilledMonthCents / 100.0;
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
    required this.createdAt,
  });

  factory StudentInvoice.fromJson(Map<String, dynamic> json) {
    return StudentInvoice(
      id: json['id'] as String,
      trainerId: json['trainer_id'] as String,
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
      createdAt: json['created_at'] as String? ?? '',
    );
  }

  double get amount => amountCents / 100.0;
  double get netAmount => netAmountCents / 100.0;
  bool get isPaid => status == 'paid';
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

