import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/widgets/meta_components.dart';
import '../../../../core/widgets/thematic_editorial_card.dart';
import '../../../../core/widgets/thematic_watermarks.dart';
import '../../../../core/services/biometric_auth_service.dart';
import '../../../../services/wallet_service.dart';
import '../../../../services/auth_service.dart';
import '../../../auth/teacher_mfa_screen.dart';
import '../../../../core/utils/currency_pt_br_formatter.dart';

class TrainerWalletScreen extends StatefulWidget {
  const TrainerWalletScreen({super.key});

  @override
  State<TrainerWalletScreen> createState() => _TrainerWalletScreenState();
}

class _TrainerWalletScreenState extends State<TrainerWalletScreen> {
  bool _isLoading = true;
  WalletSummary? _summary;
  List<StudentInvoice> _invoices = [];
  String _selectedFilter = 'all';

  List<StudentInvoice> get _filteredInvoices {
    if (_selectedFilter == 'settled') {
      return _invoices.where((i) => i.isSettled).toList();
    } else if (_selectedFilter == 'pending') {
      return _invoices.where((i) => !i.isSettled && !i.isReversed).toList();
    } else if (_selectedFilter == 'reversed') {
      return _invoices.where((i) => i.isReversed).toList();
    }
    return _invoices;
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final cockpit = await WalletService.getSplitsCockpit();
    if (mounted) {
      setState(() {
        _summary = cockpit.summary;
        _invoices = cockpit.items;
        _isLoading = false;
      });
    }
  }

  void _showPixKeyModal() {
    final keyCtrl = TextEditingController(text: _summary?.pixKey ?? '');
    final bankCtrl = TextEditingController(text: _summary?.bankName ?? '');
    String selectedType = _summary?.pixKeyType ?? 'cpf';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: MetaColors.card(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: MetaColors.cardBorder(ctx),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Chave Pix para Saques 💳',
                style: TextStyle(
                  color: MetaColors.text(ctx),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Informe sua chave Pix para receber os repasses das mensalidades dos seus alunos.',
                style: TextStyle(color: MetaColors.subtext(ctx), fontSize: 13),
              ),
              const SizedBox(height: 16),

              // Tipo de Chave
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: MetaColors.highlight(ctx),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: MetaColors.cardBorder(ctx)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedType,
                    dropdownColor: MetaColors.card(ctx),
                    isExpanded: true,
                    style: TextStyle(color: MetaColors.text(ctx), fontSize: 14),
                    items: const [
                      DropdownMenuItem(value: 'cpf', child: Text('CPF')),
                      DropdownMenuItem(value: 'cnpj', child: Text('CNPJ')),
                      DropdownMenuItem(value: 'email', child: Text('E-mail')),
                      DropdownMenuItem(value: 'phone', child: Text('Telefone Celular')),
                      DropdownMenuItem(value: 'random', child: Text('Chave Aleatória (EVP)')),
                    ],
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedType = val);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: keyCtrl,
                style: TextStyle(color: MetaColors.text(ctx)),
                decoration: InputDecoration(
                  labelText: 'Chave Pix',
                  labelStyle: TextStyle(color: MetaColors.subtext(ctx)),
                  filled: true,
                  fillColor: MetaColors.highlight(ctx),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: MetaColors.cardBorder(ctx)),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: bankCtrl,
                style: TextStyle(color: MetaColors.text(ctx)),
                decoration: InputDecoration(
                  labelText: 'Nome do Banco (Opcional)',
                  labelStyle: TextStyle(color: MetaColors.subtext(ctx)),
                  filled: true,
                  fillColor: MetaColors.highlight(ctx),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: MetaColors.cardBorder(ctx)),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              SquircleButton(
                label: 'Salvar Chave Pix',
                icon: Icons.check_rounded,
                isPrimary: true,
                onPressed: () async {
                  if (keyCtrl.text.trim().isEmpty) return;

                  // Step-Up Biométrico para segurança da Chave Pix
                  final hasBiometrics = await BiometricAuthService.isBiometricsAvailable();
                  if (hasBiometrics) {
                    final bioRes = await BiometricAuthService.authenticate(
                      localizedReason: 'Confirme com sua biometria ou Face ID para alterar sua Chave Pix',
                    );
                    if (!bioRes.success) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text(bioRes.errorMessage ?? 'Autenticação biométrica não concluída.'),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                      }
                      return;
                    }
                  }

                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  final updated = await WalletService.updatePixKey(
                    pixKey: keyCtrl.text.trim(),
                    pixKeyType: selectedType,
                    bankName: bankCtrl.text.trim().isEmpty ? null : bankCtrl.text.trim(),
                  );
                  if (updated != null && mounted) {
                    setState(() => _summary = updated);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Chave Pix atualizada com sucesso!'),
                        backgroundColor: MetaColors.emerald,
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showNewInvoiceModal() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final titleCtrl = TextEditingController(text: 'Consultoria de Musculação');
    final amountCtrl = TextEditingController(text: '150,00');
    bool sendZap = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: MetaColors.card(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: MetaColors.cardBorder(ctx),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Nova Cobrança de Aluno 🚀',
                style: TextStyle(
                  color: MetaColors.text(ctx),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Gere uma cobrança Pix transparente para seu aluno com split automático de 95% para você.',
                style: TextStyle(color: MetaColors.subtext(ctx), fontSize: 13),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: nameCtrl,
                style: TextStyle(color: MetaColors.text(ctx)),
                decoration: InputDecoration(
                  labelText: 'Nome do Aluno',
                  labelStyle: TextStyle(color: MetaColors.subtext(ctx)),
                  filled: true,
                  fillColor: MetaColors.highlight(ctx),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 10),

              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                style: TextStyle(color: MetaColors.text(ctx)),
                decoration: InputDecoration(
                  labelText: 'WhatsApp do Aluno (com DDD)',
                  hintText: 'Ex: 11999998888',
                  hintStyle: const TextStyle(color: Colors.white24),
                  labelStyle: TextStyle(color: MetaColors.subtext(ctx)),
                  filled: true,
                  fillColor: MetaColors.highlight(ctx),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 10),

              TextField(
                controller: titleCtrl,
                style: TextStyle(color: MetaColors.text(ctx)),
                decoration: InputDecoration(
                  labelText: 'Descrição / Plano',
                  labelStyle: TextStyle(color: MetaColors.subtext(ctx)),
                  filled: true,
                  fillColor: MetaColors.highlight(ctx),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 10),

              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: const [CurrencyPtBrInputFormatter(includeSymbol: false)],
                style: TextStyle(color: MetaColors.text(ctx)),
                decoration: InputDecoration(
                  prefixText: 'R\$ ',
                  prefixStyle: const TextStyle(color: MetaColors.emerald, fontWeight: FontWeight.bold),
                  labelText: 'Valor da Cobrança',
                  hintText: '150,00',
                  labelStyle: TextStyle(color: MetaColors.subtext(ctx)),
                  filled: true,
                  fillColor: MetaColors.highlight(ctx),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 10),

              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: MetaColors.emerald,
                title: Text(
                  'Enviar cobrança no WhatsApp do aluno',
                  style: TextStyle(color: MetaColors.text(ctx), fontSize: 13),
                ),
                subtitle: Text(
                  'Dispara mensagem com o link de pagamento e código Pix',
                  style: TextStyle(color: MetaColors.subtext(ctx), fontSize: 11),
                ),
                value: sendZap,
                onChanged: (val) => setModalState(() => sendZap = val),
              ),
              const SizedBox(height: 16),

              SquircleButton(
                label: 'Emitir Cobrança',
                icon: Icons.send_rounded,
                isPrimary: true,
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty) return;
                  final val = CurrencyPtBrFormatter.parse(amountCtrl.text);
                  if (val <= 0) return;

                  Navigator.pop(ctx);
                  final inv = await WalletService.createInvoice(
                    studentName: nameCtrl.text.trim(),
                    title: titleCtrl.text.trim(),
                    amountCents: (val * 100).toInt(),
                    studentPhone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                    sendWhatsapp: sendZap,
                  );

                  if (inv != null && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Cobrança de R\$ ${inv.amount.toStringAsFixed(2)} emitida com sucesso!'),
                        backgroundColor: MetaColors.emerald,
                      ),
                    );
                    _loadData();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showWithdrawModal() {
    final available = _summary?.balance ?? 0.0;
    final amountCtrl = TextEditingController(text: CurrencyPtBrFormatter.format(available, includeSymbol: false));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: MetaColors.card(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: MetaColors.cardBorder(ctx),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Solicitar Saque Pix 💸',
              style: TextStyle(
                color: MetaColors.text(ctx),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Saldo disponível: ${CurrencyPtBrFormatter.format(available)}',
              style: const TextStyle(color: MetaColors.emerald, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Chave destino: ${_summary?.pixKey ?? "Nenhuma"}',
              style: TextStyle(color: MetaColors.subtext(ctx), fontSize: 13),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: const [CurrencyPtBrInputFormatter(includeSymbol: false)],
              style: TextStyle(color: MetaColors.text(ctx)),
              decoration: InputDecoration(
                prefixText: 'R\$ ',
                prefixStyle: const TextStyle(color: MetaColors.emerald, fontWeight: FontWeight.bold),
                labelText: 'Valor a sacar',
                labelStyle: TextStyle(color: MetaColors.subtext(ctx)),
                filled: true,
                fillColor: MetaColors.highlight(ctx),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 20),

            SquircleButton(
              label: 'Confirmar Saque',
              icon: Icons.payments_outlined,
              isPrimary: true,
              onPressed: () async {
                final val = CurrencyPtBrFormatter.parse(amountCtrl.text);
                if (val <= 0) return;

                // Step-Up Biométrico: Autorização de movimentação financeira com Face ID / Biometria
                final hasBiometrics = await BiometricAuthService.isBiometricsAvailable();
                if (hasBiometrics) {
                  final bioRes = await BiometricAuthService.authenticate(
                    localizedReason: 'Autorize a retirada de ${CurrencyPtBrFormatter.format(val)} com sua biometria',
                  );
                  if (!bioRes.success) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(
                          content: Text(bioRes.errorMessage ?? 'Autenticação biométrica não concluída.'),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    }
                    return;
                  }
                }

                // Step-Up Security: Exige validação 2FA antes de movimentar fundos se configurado
                final isSatisfied = await AuthService.isCurrentSessionMfaSatisfied();
                if (!isSatisfied) {
                  final profile = await AuthService.getCurrentProfile();
                  final mfaEnrolled = profile?['mfa_enabled'] == true ||
                      (profile?['mfa_verified_at'] != null && (profile?['mfa_factors'] as List?)?.isNotEmpty == true);
                  if (mfaEnrolled && mounted) {
                    final verified = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TeacherMfaScreen(
                          allowEnrollment: false,
                        ),
                      ),
                    );
                    if (verified != true) return;
                  }
                }

                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                final res = await WalletService.requestWithdrawal((val * 100).toInt());
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(res['message'] as String),
                      backgroundColor: res['success'] == true ? MetaColors.emerald : Colors.redAccent,
                    ),
                  );
                  _loadData();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showSplitAuditModal(StudentInvoice inv) {
    final isSettled = inv.isSettled;
    final isReversed = inv.isReversed;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: MetaColors.card(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 28,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: MetaColors.cardBorder(ctx),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSettled
                        ? MetaColors.emerald.withValues(alpha: 0.2)
                        : (isReversed
                            ? Colors.redAccent.withValues(alpha: 0.2)
                            : Colors.amber.withValues(alpha: 0.2)),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isSettled
                        ? Icons.verified_user_rounded
                        : (isReversed ? Icons.replay_rounded : Icons.hourglass_top_rounded),
                    color: isSettled
                        ? MetaColors.emerald
                        : (isReversed ? Colors.redAccent : Colors.amber),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Comprovante Fiscal de Split',
                        style: TextStyle(
                          color: MetaColors.text(ctx),
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Conformidade Resolução BCB nº 4.893',
                        style: TextStyle(color: MetaColors.subtext(ctx), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Card com resumo financeiro
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: MetaColors.highlight(ctx),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: MetaColors.cardBorder(ctx)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Aluno:', style: TextStyle(color: MetaColors.subtext(ctx), fontSize: 13)),
                      Text(inv.studentName, style: TextStyle(color: MetaColors.text(ctx), fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Plano / Descrição:', style: TextStyle(color: MetaColors.subtext(ctx), fontSize: 13)),
                      Flexible(
                        child: Text(
                          inv.title,
                          style: TextStyle(color: MetaColors.text(ctx), fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Método de Pagamento:', style: TextStyle(color: MetaColors.subtext(ctx), fontSize: 13)),
                      Text(
                        inv.paymentMethod == 'credit_card' ? 'Cartão de Crédito' : 'Pix EMV (Banco Central)',
                        style: TextStyle(color: MetaColors.text(ctx), fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Valor Bruto Pago:', style: TextStyle(color: MetaColors.subtext(ctx), fontSize: 13)),
                      Text(
                        'R\$ ${inv.amount.toStringAsFixed(2)}',
                        style: TextStyle(color: MetaColors.text(ctx), fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Repasse do Treinador (95% Líquido):',
                        style: TextStyle(color: MetaColors.emerald, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Text(
                        'R\$ ${inv.netAmount.toStringAsFixed(2)}',
                        style: const TextStyle(color: MetaColors.emerald, fontWeight: FontWeight.w900, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Taxa Operacional SaaS (5%):', style: TextStyle(color: MetaColors.subtext(ctx), fontSize: 13)),
                      Text('R\$ ${inv.platformFee.toStringAsFixed(2)}', style: TextStyle(color: MetaColors.subtext(ctx), fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Trilha de Auditoria Bancária
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: MetaColors.highlight(ctx),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: MetaColors.cardBorder(ctx)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.account_balance_outlined, size: 14, color: MetaColors.emerald),
                      const SizedBox(width: 6),
                      Text(
                        'Conciliação Bancária Asaas',
                        style: TextStyle(color: MetaColors.text(ctx), fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Subconta Destino: ${inv.asaasWalletId ?? _summary?.asaasWalletId ?? "wlt_regulado_asaas"}',
                    style: TextStyle(color: MetaColors.subtext(ctx), fontSize: 11),
                  ),
                  if (inv.asaasPaymentId != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'ID Asaas: ${inv.asaasPaymentId}',
                      style: TextStyle(color: MetaColors.subtext(ctx), fontSize: 11),
                    ),
                  ],
                  if (inv.hasJwsAudit) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: MetaColors.card(ctx),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: MetaColors.emerald.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.key_rounded, size: 12, color: MetaColors.emerald),
                                  SizedBox(width: 4),
                                  Text(
                                    'Assinatura JWS (RFC 7515)',
                                    style: TextStyle(color: MetaColors.emerald, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              InkWell(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: inv.jwsSplitToken!));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Assinatura digital JWS copiada para auditoria!'),
                                      backgroundColor: MetaColors.emerald,
                                    ),
                                  );
                                },
                                child: const Text(
                                  'Copiar',
                                  style: TextStyle(color: MetaColors.accentBlue, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${inv.jwsSplitToken!.substring(0, inv.jwsSplitToken!.length > 40 ? 40 : inv.jwsSplitToken!.length)}...',
                            style: TextStyle(color: MetaColors.subtext(ctx), fontSize: 10, fontFamily: 'monospace'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),

            SquircleButton(
              label: 'Fechar Comprovante',
              isPrimary: true,
              height: 44,
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips(BuildContext context) {
    final filters = [
      {'key': 'all', 'label': 'Todos', 'count': _invoices.length},
      {'key': 'settled', 'label': 'Liquidados 95%', 'count': _invoices.where((i) => i.isSettled).length},
      {'key': 'pending', 'label': 'Em Compensação', 'count': _invoices.where((i) => !i.isSettled && !i.isReversed).length},
      {'key': 'reversed', 'label': 'Estornos', 'count': _invoices.where((i) => i.isReversed).length},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final isSelected = _selectedFilter == f['key'];
          final count = f['count'] as int;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text('${f['label']} ($count)'),
              selected: isSelected,
              selectedColor: MetaColors.emerald.withValues(alpha: 0.2),
              backgroundColor: MetaColors.highlight(context),
              labelStyle: TextStyle(
                color: isSelected ? MetaColors.emerald : MetaColors.subtext(context),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
              side: BorderSide(
                color: isSelected ? MetaColors.emerald : MetaColors.cardBorder(context),
              ),
              onSelected: (val) {
                if (val) setState(() => _selectedFilter = f['key'] as String);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAsaasRegulationBanner(BuildContext context) {
    final isLinked = _summary?.isAsaasActive ?? false;
    final walletId = _summary?.asaasWalletId;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isLinked
            ? MetaColors.emerald.withValues(alpha: 0.1)
            : MetaColors.highlight(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLinked
              ? MetaColors.emerald.withValues(alpha: 0.3)
              : MetaColors.cardBorder(context),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isLinked ? MetaColors.emerald : MetaColors.cardBorder(context),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isLinked ? Icons.verified_user_rounded : Icons.account_balance_wallet_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        isLinked
                            ? 'Subconta Asaas Vinculada'
                            : 'Split 95/5 Automático Habilitado',
                        style: TextStyle(
                          color: MetaColors.text(context),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isLinked
                            ? MetaColors.emerald.withValues(alpha: 0.2)
                            : Colors.blueAccent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isLinked ? 'BCB 4.893' : 'SPLIT ATIVO',
                        style: TextStyle(
                          color: isLinked ? MetaColors.emerald : Colors.blueAccent,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  isLinked
                      ? 'Wallet: ${walletId ?? "Ativa"} • Liquidação direta sem bitributação'
                      : '95% líquido vai direto para você no checkout da vitrine',
                  style: TextStyle(color: MetaColors.subtext(context), fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiscalBreakdown(BuildContext context) {
    if ((_summary?.totalSplitsCount ?? 0) == 0 && (_summary?.balance ?? 0) == 0) {
      return const SizedBox.shrink();
    }

    final gross = _summary?.settledGross ?? 0.0;
    final net = _summary?.settledNet ?? 0.0;
    final fee = _summary?.settledFee ?? 0.0;

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MetaColors.highlight(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MetaColors.cardBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined, size: 14, color: MetaColors.emerald),
              const SizedBox(width: 6),
              Text(
                'Transparência Fiscal & Segregação Bancária',
                style: TextStyle(
                  color: MetaColors.text(context),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Bruto Total:',
                style: TextStyle(color: MetaColors.subtext(context), fontSize: 11.5),
              ),
              Text(
                'R\$ ${gross.toStringAsFixed(2)}',
                style: TextStyle(color: MetaColors.text(context), fontSize: 11.5, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Repasse Líquido Personal (95%):',
                style: TextStyle(color: MetaColors.emerald, fontSize: 11.5, fontWeight: FontWeight.bold),
              ),
              Text(
                'R\$ ${net.toStringAsFixed(2)}',
                style: const TextStyle(color: MetaColors.emerald, fontSize: 11.5, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Taxa Operacional SaaS (5%):',
                style: TextStyle(color: MetaColors.subtext(context), fontSize: 11.5),
              ),
              Text(
                'R\$ ${fee.toStringAsFixed(2)}',
                style: TextStyle(color: MetaColors.subtext(context), fontSize: 11.5),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MetaColors.bg(context),
      appBar: AppBar(
        backgroundColor: MetaColors.bg(context),
        elevation: 0,
        title: Text(
          'Carteira do Personal',
          style: TextStyle(
            color: MetaColors.text(context),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: MetaColors.subtext(context)),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: MetaColors.emerald))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: MetaColors.emerald,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildAsaasRegulationBanner(context),

                    // Card Principal: Saldo Disponível (One UI 7 Health / Samsung Health Editorial)
                    ThematicEditorialCard(
                      category: 'CARTEIRA B2B • REPASSE AUTOMÁTICO',
                      palette: ThematicCardPalette.businessEmerald,
                      customWatermark: ThematicWatermarkType.walletFinance,
                      padding: const EdgeInsets.all(20),
                      trailingBadge: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.bolt_rounded, size: 14, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              'Pix Imediato',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      customContent: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Saldo Disponível',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'R\$ ${(_summary?.balance ?? 0.0).toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(Icons.qr_code_rounded, size: 14, color: Colors.white.withValues(alpha: 0.8)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _summary?.pixKey != null
                                      ? 'Pix: ${_summary!.pixKey}'
                                      : 'Nenhuma chave cadastrada',
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              InkWell(
                                onTap: _showPixKeyModal,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.22),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    _summary?.pixKey != null ? 'Alterar' : 'Cadastrar',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: SquircleButton(
                                  label: 'Sacar via Pix',
                                  icon: Icons.payments_outlined,
                                  isPrimary: true,
                                  height: 46,
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xFF065F46),
                                  onPressed: (_summary?.balance ?? 0) > 0 ? _showWithdrawModal : null,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: SquircleButton(
                                  label: 'Chave Pix',
                                  icon: Icons.edit_note_rounded,
                                  isPrimary: false,
                                  height: 46,
                                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                                  foregroundColor: Colors.white,
                                  onPressed: _showPixKeyModal,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Grid de Métricas
                    Row(
                      children: [
                        Expanded(
                          child: MetaCard(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.hourglass_top_rounded, size: 13, color: Colors.amberAccent),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        'Em Compensação',
                                        style: TextStyle(color: MetaColors.subtext(context), fontSize: 11),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'R\$ ${((_summary?.pendingNet ?? _summary?.pendingBalance) ?? 0.0).toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: Colors.amberAccent,
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${_summary?.pendingSplitsCount ?? 0} split(s) a liberar',
                                  style: TextStyle(color: MetaColors.subtext(context), fontSize: 10),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: MetaCard(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.trending_up_rounded, size: 13, color: MetaColors.emerald),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        'Líquido no Mês',
                                        style: TextStyle(color: MetaColors.subtext(context), fontSize: 11),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'R\$ ${(_summary?.totalBilledMonth ?? 0.0).toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: MetaColors.emerald,
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '95% direto na subconta',
                                  style: TextStyle(color: MetaColors.subtext(context), fontSize: 10),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    _buildFiscalBreakdown(context),
                    const SizedBox(height: 24),

                    // Cabeçalho da Lista de Cobranças
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cobranças de Alunos & Splits',
                              style: TextStyle(
                                color: MetaColors.text(context),
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Extrato em tempo real com conciliação automática',
                              style: TextStyle(color: MetaColors.subtext(context), fontSize: 11),
                            ),
                          ],
                        ),
                        TextButton.icon(
                          onPressed: _showNewInvoiceModal,
                          icon: const Icon(Icons.add_rounded, size: 16, color: MetaColors.emerald),
                          label: const Text(
                            'Nova Cobrança',
                            style: TextStyle(color: MetaColors.emerald, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildFilterChips(context),
                    const SizedBox(height: 12),

                    // Lista de Cobranças Filtradas
                    if (_filteredInvoices.isEmpty)
                      MetaCard(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(Icons.receipt_long_rounded, size: 40, color: MetaColors.subtext(context)),
                            const SizedBox(height: 12),
                            Text(
                              _invoices.isEmpty
                                  ? 'Nenhuma cobrança emitida ainda'
                                  : 'Nenhuma cobrança encontrada neste filtro',
                              style: TextStyle(color: MetaColors.text(context), fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _invoices.isEmpty
                                  ? 'Gere cobranças Pix para seus alunos e receba mensalidades com split transparente.'
                                  : 'Alterne os filtros acima para visualizar todas as transações ou pendências.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: MetaColors.subtext(context), fontSize: 12),
                            ),
                            if (_invoices.isEmpty) ...[
                              const SizedBox(height: 16),
                              SquircleButton(
                                label: 'Criar Primeira Cobrança',
                                icon: Icons.add_rounded,
                                isPrimary: true,
                                height: 44,
                                onPressed: _showNewInvoiceModal,
                              ),
                            ],
                          ],
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _filteredInvoices.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final inv = _filteredInvoices[index];
                          final isPaid = inv.isPaid;
                          final isSettled = inv.isSettled;
                          final isReversed = inv.isReversed;

                          return InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => _showSplitAuditModal(inv),
                            child: MetaCard(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 18,
                                        backgroundColor: isSettled
                                            ? MetaColors.emerald.withValues(alpha: 0.15)
                                            : (isReversed
                                                ? Colors.redAccent.withValues(alpha: 0.15)
                                                : Colors.amber.withValues(alpha: 0.15)),
                                        child: Icon(
                                          isSettled
                                              ? Icons.check_circle_rounded
                                              : (isReversed ? Icons.replay_rounded : Icons.pending_rounded),
                                          size: 18,
                                          color: isSettled
                                              ? MetaColors.emerald
                                              : (isReversed ? Colors.redAccent : Colors.amber),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              inv.studentName,
                                              style: TextStyle(
                                                color: MetaColors.text(context),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                            Text(
                                              inv.title,
                                              style: TextStyle(color: MetaColors.subtext(context), fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            'R\$ ${inv.amount.toStringAsFixed(2)}',
                                            style: TextStyle(
                                              color: MetaColors.text(context),
                                              fontWeight: FontWeight.w900,
                                              fontSize: 15,
                                            ),
                                          ),
                                          Text(
                                            isSettled
                                                ? 'LIQUIDADO (95%)'
                                                : (isReversed ? 'ESTORNADO' : 'PENDENTE'),
                                            style: TextStyle(
                                              color: isSettled
                                                  ? MetaColors.emerald
                                                  : (isReversed ? Colors.redAccent : Colors.amberAccent),
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),

                                  // Detalhamento do Split 95/5
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: MetaColors.highlight(context),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Text(
                                          '95% Líquido: R\$ ${inv.netAmount.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            color: MetaColors.emerald,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '•  5% SaaS: R\$ ${inv.platformFee.toStringAsFixed(2)}',
                                          style: TextStyle(color: MetaColors.subtext(context), fontSize: 11),
                                        ),
                                        const Spacer(),
                                        if (inv.hasJwsAudit) ...[
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: MetaColors.emerald.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.verified_user_rounded, size: 10, color: MetaColors.emerald),
                                                SizedBox(width: 3),
                                                Text(
                                                  'BCB 4.893',
                                                  style: TextStyle(color: MetaColors.emerald, fontSize: 9, fontWeight: FontWeight.bold),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton.icon(
                                        onPressed: () => _showSplitAuditModal(inv),
                                        icon: const Icon(Icons.receipt_outlined, size: 14, color: MetaColors.accentBlue),
                                        label: const Text(
                                          'Auditoria Fiscal',
                                          style: TextStyle(color: MetaColors.accentBlue, fontSize: 12),
                                        ),
                                      ),
                                      if (!isPaid) ...[
                                        if (inv.pixCopyPaste != null) ...[
                                          const SizedBox(width: 4),
                                          TextButton.icon(
                                            onPressed: () {
                                              Clipboard.setData(ClipboardData(text: inv.pixCopyPaste!));
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text('Código Pix Copia e Cola copiado!'),
                                                  backgroundColor: MetaColors.emerald,
                                                ),
                                              );
                                            },
                                            icon: const Icon(Icons.copy_rounded, size: 14, color: MetaColors.accentBlue),
                                            label: const Text(
                                              'Copiar Pix',
                                              style: TextStyle(color: MetaColors.accentBlue, fontSize: 12),
                                            ),
                                          ),
                                        ],
                                        const SizedBox(width: 4),
                                        TextButton.icon(
                                          onPressed: () async {
                                            final messenger = ScaffoldMessenger.of(context);
                                            final updated = await WalletService.markPaid(inv.id);
                                            if (updated != null && mounted) {
                                              messenger.showSnackBar(
                                                const SnackBar(
                                                  content: Text('Pagamento registrado com sucesso! Saldo creditado.'),
                                                  backgroundColor: MetaColors.emerald,
                                                ),
                                              );
                                              _loadData();
                                            }
                                          },
                                          icon: const Icon(Icons.check_rounded, size: 14, color: MetaColors.emerald),
                                          label: const Text(
                                            'Registrar Pago',
                                            style: TextStyle(color: MetaColors.emerald, fontSize: 12),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

