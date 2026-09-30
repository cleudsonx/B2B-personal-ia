import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/document_validator.dart';
import '../../services/auth_service.dart';
import '../client/welcome_onboarding_screen.dart';
import '../trainer/trainer_plan_selection_screen.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  final String initialRole;

  const RegisterScreen({super.key, this.initialRole = 'trainer'});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  final _documentCtrl = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  late String _role; // 'trainer' ou 'client'
  String _docType = 'CREF'; // 'CREF', 'CBMF', 'CPF'
  DocumentValidationResult? _docValidation;

  @override
  void initState() {
    super.initState();
    _role = widget.initialRole;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _documentCtrl.dispose();
    super.dispose();
  }

  Future<void> _openUrl(String urlStr) async {
    final uri = Uri.parse(urlStr);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;

    String? validDocFormatted;
    if (_role == 'trainer') {
      final docRes = DocumentValidator.validate(type: _docType, value: _documentCtrl.text.trim());
      if (!docRes.isValid) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade800,
            content: Text(docRes.errorMessage ?? 'Documento do professor inválido.'),
          ),
        );
        return;
      }
      validDocFormatted = docRes.formatted ?? _documentCtrl.text.trim();
    }

    setState(() => _isLoading = true);
    final fullName = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();

    try {
      await AuthService.signUp(
        email: email,
        password: password,
        fullName: fullName,
        role: _role,
        phone: phone,
        professionalDocumentType: _role == 'trainer' ? _docType : null,
        professionalDocument: _role == 'trainer' ? validDocFormatted : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.green,
            content: Text('Conta criada com sucesso! Redirecionando...'),
          ),
        );
        _navigateToApp(fullName, _role, email);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade800,
            content: Text(e.toString().replaceAll('Exception: ', '')),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToApp(String name, String role, String email) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => role == 'client'
            ? WelcomeOnboardingScreen(studentName: name)
            : TrainerPlanSelectionScreen(
                trainerName: name,
                trainerEmail: email,
              ),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTrainer = _role == 'trainer';
    final primaryAccent = isTrainer ? AppColors.trainerEmerald : AppColors.studentCyan;

    String docLabel = 'Registro Profissional CREF';
    String docHint = 'Ex: 019284-G/SP';
    IconData docIcon = Icons.workspace_premium_rounded;
    String docHelperNote = 'Formato CONFEF: 000000-G/UF (G=Graduado, P=Provisionado)';
    String docLinkText = 'Consultar no CONFEF';
    String docVerificationUrl = 'https://www.confef.org.br/confef/registrados/';

    if (_docType == 'CBMF') {
      docLabel = 'Registro de Filiado CBMF';
      docHint = 'Ex: CBMF-10294';
      docIcon = Icons.sports_gymnastics_rounded;
      docHelperNote = 'Confederação Brasileira de Musculação e Fitness';
      docLinkText = 'Portal do Filiado CBMF';
      docVerificationUrl = 'https://portaldofiliadocbmf.abacusai.app/';
    } else if (_docType == 'CPF') {
      docLabel = 'CPF do Treinador';
      docHint = '000.000.000-00';
      docIcon = Icons.badge_outlined;
      docHelperNote = 'Validação oficial pelos dígitos da Receita Federal';
      docLinkText = 'Consultar na Receita Federal';
      docVerificationUrl = 'https://servicos.receita.fazenda.gov.br/servicos/cpf/consultasituacao/consultapublica.asp';
    }

    return Scaffold(
      backgroundColor: AppColors.studentBg,
      appBar: AppBar(
        title: const Text('Criar Nova Conta'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Icon & Text
                    Center(
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: primaryAccent.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                          border: Border.all(color: primaryAccent.withValues(alpha: 0.5), width: 1.5),
                        ),
                        child: Icon(
                          isTrainer ? Icons.sports_gymnastics : Icons.fitness_center_rounded,
                          color: primaryAccent,
                          size: 30,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Center(
                      child: Text(
                        'Junte-se à Revolução IA',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: Text(
                        isTrainer
                            ? 'Cadastre-se para gerenciar alunos e prescrever com IA'
                            : 'Cadastre-se para treinar com adaptações biomecânicas em tempo real',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Role Selector Toggle
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.studentSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.studentBorder),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildRoleTab(
                              title: 'Treinador Pro',
                              icon: Icons.assignment_ind_outlined,
                              isSelected: isTrainer,
                              activeColor: AppColors.trainerEmerald,
                              onTap: () => setState(() => _role = 'trainer'),
                            ),
                          ),
                          Expanded(
                            child: _buildRoleTab(
                              title: 'Aluno no Salão',
                              icon: Icons.fitness_center_rounded,
                              isSelected: !isTrainer,
                              activeColor: AppColors.studentCyan,
                              onTap: () => setState(() => _role = 'client'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Nome Completo
                    TextFormField(
                      controller: _nameCtrl,
                      style: const TextStyle(color: AppColors.textPrimary),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe seu nome completo' : null,
                      decoration: InputDecoration(
                        labelText: 'Nome Completo',
                        labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        prefixIcon: Icon(Icons.person_outline, color: primaryAccent, size: 20),
                        filled: true,
                        fillColor: AppColors.studentSurface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: primaryAccent, width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // E-mail
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: AppColors.textPrimary),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Informe seu e-mail';
                        if (!v.contains('@')) return 'Informe um e-mail válido';
                        return null;
                      },
                      decoration: InputDecoration(
                        labelText: 'E-mail',
                        labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        prefixIcon: Icon(Icons.email_outlined, color: primaryAccent, size: 20),
                        filled: true,
                        fillColor: AppColors.studentSurface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: primaryAccent, width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Telefone / WhatsApp
                    TextFormField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'WhatsApp / Telefone (Opcional)',
                        labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        prefixIcon: Icon(Icons.phone_outlined, color: primaryAccent, size: 20),
                        filled: true,
                        fillColor: AppColors.studentSurface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: primaryAccent, width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Registro Profissional (Obrigatório para Treinador: CREF, CBMF ou CPF)
                    if (isTrainer) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.studentSurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _docValidation?.isValid == true
                                ? AppColors.trainerEmerald.withValues(alpha: 0.6)
                                : AppColors.studentBorder,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.verified_user_outlined, size: 16, color: primaryAccent),
                                    const SizedBox(width: 6),
                                    Text(
                                      'REGISTRO PROFISSIONAL',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.6,
                                        color: primaryAccent,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: primaryAccent.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Obrigatório',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: primaryAccent),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // Pílulas seletoras: CREF | CBMF | CPF
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: AppColors.studentBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.studentBorder),
                              ),
                              child: Row(
                                children: [
                                  _buildDocTypePill(
                                    type: 'CREF',
                                    title: 'CONFEF',
                                    icon: Icons.workspace_premium_rounded,
                                    activeColor: primaryAccent,
                                  ),
                                  _buildDocTypePill(
                                    type: 'CBMF',
                                    title: 'Filiado CBMF',
                                    icon: Icons.sports_gymnastics_rounded,
                                    activeColor: primaryAccent,
                                  ),
                                  _buildDocTypePill(
                                    type: 'CPF',
                                    title: 'Receita Federal',
                                    icon: Icons.badge_outlined,
                                    activeColor: primaryAccent,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Campo de Texto do Documento com Validação Dinâmica
                            TextFormField(
                              controller: _documentCtrl,
                              keyboardType: _docType == 'CPF' ? TextInputType.number : TextInputType.text,
                              style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                              onChanged: (val) {
                                setState(() {
                                  _docValidation = val.isNotEmpty
                                      ? DocumentValidator.validate(type: _docType, value: val)
                                      : null;
                                });
                              },
                              validator: (v) {
                                if (!isTrainer) return null;
                                final res = DocumentValidator.validate(type: _docType, value: v);
                                if (!res.isValid) {
                                  return res.errorMessage ?? 'Documento inválido';
                                }
                                return null;
                              },
                              decoration: InputDecoration(
                                labelText: docLabel,
                                hintText: docHint,
                                labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                hintStyle: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.6), fontSize: 12),
                                prefixIcon: Icon(docIcon, color: primaryAccent, size: 20),
                                suffixIcon: _documentCtrl.text.isNotEmpty
                                    ? Icon(
                                        _docValidation?.isValid == true ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                                        color: _docValidation?.isValid == true ? Colors.greenAccent : Colors.redAccent,
                                        size: 20,
                                      )
                                    : null,
                                filled: true,
                                fillColor: AppColors.studentBg,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: primaryAccent, width: 1.5),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Linha de Status de Validação + Link Oficial para Consulta
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    _docValidation?.isValid == true
                                        ? '✓ Documento Válido: ${_docValidation?.formatted}'
                                        : (_documentCtrl.text.isNotEmpty
                                            ? (_docValidation?.errorMessage ?? '')
                                            : docHelperNote),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: _docValidation?.isValid == true ? FontWeight.bold : FontWeight.normal,
                                      color: _docValidation?.isValid == true
                                          ? Colors.greenAccent
                                          : (_documentCtrl.text.isNotEmpty ? Colors.redAccent : AppColors.textMuted),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () => _openUrl(docVerificationUrl),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        docLinkText,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: primaryAccent,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      Icon(Icons.open_in_new, size: 11, color: primaryAccent),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Senha
                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: _obscurePassword,
                      style: const TextStyle(color: AppColors.textPrimary),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Informe uma senha';
                        if (v.length < 6) return 'A senha deve ter no mínimo 6 dígitos';
                        return null;
                      },
                      decoration: InputDecoration(
                        labelText: 'Senha de Acesso',
                        labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        prefixIcon: Icon(Icons.lock_outline, color: primaryAccent, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: AppColors.textMuted,
                            size: 20,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                        filled: true,
                        fillColor: AppColors.studentSurface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: primaryAccent, width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Confirmar Senha
                    TextFormField(
                      controller: _confirmPasswordCtrl,
                      obscureText: _obscureConfirmPassword,
                      style: const TextStyle(color: AppColors.textPrimary),
                      validator: (v) {
                        if (v != _passwordCtrl.text) return 'As senhas não coincidem';
                        return null;
                      },
                      decoration: InputDecoration(
                        labelText: 'Confirmar Senha',
                        labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        prefixIcon: Icon(Icons.lock_reset_outlined, color: primaryAccent, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: AppColors.textMuted,
                            size: 20,
                          ),
                          onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                        ),
                        filled: true,
                        fillColor: AppColors.studentSurface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: primaryAccent, width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Botão Cadastrar
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryAccent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 4,
                        shadowColor: primaryAccent.withValues(alpha: 0.4),
                      ),
                      onPressed: _isLoading ? null : _handleSignUp,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                            )
                          : Text(
                              'Criar Conta como ${isTrainer ? 'Treinador Pro' : 'Aluno no Salão'}',
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                            ),
                    ),
                    const SizedBox(height: 20),

                    // Já tem conta? Login
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Já possui uma conta? ',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                        GestureDetector(
                          onTap: () {
                            if (Navigator.canPop(context)) {
                              Navigator.pop(context);
                            } else {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(builder: (_) => LoginScreen(initialRole: _role)),
                              );
                            }
                          },
                          child: Text(
                            'Faça Login',
                            style: TextStyle(
                              color: primaryAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleTab({
    required String title,
    required IconData icon,
    required bool isSelected,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? activeColor : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: isSelected ? activeColor : AppColors.textMuted),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? activeColor : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocTypePill({
    required String type,
    required String title,
    required IconData icon,
    required Color activeColor,
  }) {
    final isSelected = _docType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _docType = type;
            _docValidation = _documentCtrl.text.isNotEmpty
                ? DocumentValidator.validate(type: _docType, value: _documentCtrl.text.trim())
                : null;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? activeColor.withValues(alpha: 0.18) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? activeColor : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: isSelected ? activeColor : AppColors.textMuted),
              const SizedBox(height: 3),
              Text(
                type,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? activeColor : AppColors.textPrimary,
                ),
              ),
              Text(
                title,
                style: TextStyle(
                  fontSize: 9,
                  color: isSelected ? activeColor.withValues(alpha: 0.9) : AppColors.textMuted,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

