import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:personal_ia/core/widgets/meta_components.dart';
import '../services/admin_data_service.dart';

/// Modal para teste, auditoria e reprocessamento manual de Webhooks Asaas com idempotência
class AdminWebhookReprocessModal extends StatefulWidget {
  const AdminWebhookReprocessModal({super.key});

  static Future<void> show(BuildContext context) {
    HapticFeedback.mediumImpact();
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (_) => const AdminWebhookReprocessModal(),
    );
  }

  @override
  State<AdminWebhookReprocessModal> createState() => _AdminWebhookReprocessModalState();
}

class _AdminWebhookReprocessModalState extends State<AdminWebhookReprocessModal> {
  String _selectedEvent = 'PAYMENT_RECEIVED';
  final TextEditingController _paymentIdCtrl =
      TextEditingController(text: 'pay_test_manual_${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}');
  final TextEditingController _customerIdCtrl = TextEditingController(text: 'cus_admin_sim_01');
  final TextEditingController _valueCtrl = TextEditingController(text: '199.90');

  bool _isProcessing = false;
  AdminWebhookReprocessResult? _lastResult;

  static const List<String> _events = [
    'PAYMENT_RECEIVED',
    'PAYMENT_CONFIRMED',
    'PAYMENT_OVERDUE',
    'PAYMENT_REFUNDED',
  ];

  @override
  void dispose() {
    _paymentIdCtrl.dispose();
    _customerIdCtrl.dispose();
    _valueCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleReprocess() async {
    HapticFeedback.selectionClick();
    setState(() {
      _isProcessing = true;
      _lastResult = null;
    });

    final val = double.tryParse(_valueCtrl.text.replaceAll(',', '.').trim()) ?? 199.90;

    final result = await AdminDataService.reprocessWebhook(
      eventType: _selectedEvent,
      paymentId: _paymentIdCtrl.text.trim(),
      customerId: _customerIdCtrl.text.trim(),
      value: val,
    );

    if (mounted) {
      setState(() {
        _isProcessing = false;
        _lastResult = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = MetaColors.isDark(context);
    final cardBg = isDark ? const Color(0xFF111827) : Colors.white;
    final borderCol = isDark ? const Color(0xFF374151) : const Color(0xFFE2E8F0);
    final controlBg = isDark ? const Color(0xFF1F2937) : const Color(0xFFF1F5F9);
    final controlBorder = isDark ? const Color(0xFF374151) : const Color(0xFFCBD5E1);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? Colors.grey : const Color(0xFF64748B);
    final textLabel = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF475569);
    final dividerCol = isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0);
    final codeBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final codeText = isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 650, maxHeight: 680),
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderCol, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.8),
                  blurRadius: 36,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 16, 14),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEC4899).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.bolt_rounded, color: Color(0xFFF472B6), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Reprocessamento de Webhook Asaas',
                              style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Disparo atômico de eventos com validação de idempotência e lease',
                              style: TextStyle(color: textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.close_rounded, color: textSecondary),
                      ),
                    ],
                  ),
                ),
                Divider(color: dividerCol, height: 1),

                // Form Fields
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'EVENTO ASAAS',
                          style: TextStyle(color: textLabel, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                          decoration: BoxDecoration(
                            color: controlBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: controlBorder),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedEvent,
                              dropdownColor: cardBg,
                              style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                              items: _events
                                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedEvent = val);
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        Text(
                          'PAYMENT ID',
                          style: TextStyle(color: textLabel, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _paymentIdCtrl,
                          style: TextStyle(color: textPrimary, fontSize: 13, fontFamily: 'monospace'),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: controlBg,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: isDark ? BorderSide.none : BorderSide(color: controlBorder)),
                          ),
                        ),
                        const SizedBox(height: 14),

                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'CUSTOMER ID',
                                    style: TextStyle(color: textLabel, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: _customerIdCtrl,
                                    style: TextStyle(color: textPrimary, fontSize: 13),
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: controlBg,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: isDark ? BorderSide.none : BorderSide(color: controlBorder)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'VALOR (R\$)',
                                    style: TextStyle(color: textLabel, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: _valueCtrl,
                                    keyboardType: TextInputType.number,
                                    style: TextStyle(color: textPrimary, fontSize: 13),
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: controlBg,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: isDark ? BorderSide.none : BorderSide(color: controlBorder)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Action Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isProcessing ? null : _handleReprocess,
                            icon: _isProcessing
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.send_rounded, size: 18),
                            label: Text(
                              _isProcessing ? 'Processando Webhook...' : 'Executar Reprocessamento',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEC4899),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),

                        // Result Card
                        if (_lastResult != null) ...[
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: codeBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _lastResult!.success ? const Color(0xFF10B981) : Colors.redAccent,
                                width: 1.2,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      _lastResult!.success ? Icons.check_circle_rounded : Icons.error_rounded,
                                      color: _lastResult!.success ? const Color(0xFF10B981) : Colors.redAccent,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _lastResult!.success ? 'Processado com Sucesso' : 'Falha na Resposta',
                                      style: TextStyle(
                                        color: _lastResult!.success ? const Color(0xFF10B981) : Colors.redAccent,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '${_lastResult!.durationMs}ms • HTTP ${_lastResult!.statusCode}',
                                      style: TextStyle(color: textSecondary, fontSize: 11),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                SelectableText(
                                  _lastResult!.responseBody,
                                  style: TextStyle(color: codeText, fontSize: 11.5, fontFamily: 'monospace'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
