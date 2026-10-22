import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 650, maxHeight: 680),
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF374151), width: 1.2),
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
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Reprocessamento de Webhook Asaas',
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Disparo atômico de eventos com validação de idempotência e lease',
                              style: TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Color(0xFF1F2937), height: 1),

                // Form Fields
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'EVENTO ASAAS',
                          style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1F2937),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF374151)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedEvent,
                              dropdownColor: const Color(0xFF1F2937),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
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

                        const Text(
                          'PAYMENT ID',
                          style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _paymentIdCtrl,
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace'),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFF1F2937),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          ),
                        ),
                        const SizedBox(height: 14),

                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'CUSTOMER ID',
                                    style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: _customerIdCtrl,
                                    style: const TextStyle(color: Colors.white, fontSize: 13),
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: const Color(0xFF1F2937),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
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
                                  const Text(
                                    'VALOR (R\$)',
                                    style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: _valueCtrl,
                                    keyboardType: TextInputType.number,
                                    style: const TextStyle(color: Colors.white, fontSize: 13),
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: const Color(0xFF1F2937),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
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
                              color: const Color(0xFF0F172A),
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
                                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                SelectableText(
                                  _lastResult!.responseBody,
                                  style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11.5, fontFamily: 'monospace'),
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
