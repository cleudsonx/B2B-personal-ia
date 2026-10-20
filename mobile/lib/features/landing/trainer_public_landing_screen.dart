// ignore_for_file: use_build_context_synchronously
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import '../../core/widgets/meta_components.dart';
import '../../services/consultancy_plan_service.dart';

class TrainerPublicLandingScreen extends StatefulWidget {
  final String username;

  const TrainerPublicLandingScreen({super.key, required this.username});

  @override
  State<TrainerPublicLandingScreen> createState() => _TrainerPublicLandingScreenState();
}

class _TrainerPublicLandingScreenState extends State<TrainerPublicLandingScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _trainerData;
  String? _errorMessage;

  List<ConsultancyPlan> _plans = [];
  bool _isLoadingPlans = true;

  @override
  void initState() {
    super.initState();
    _fetchTrainerProfile();
    _fetchPlans();
  }

  Future<void> _fetchTrainerProfile() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    try {
      final apiUrl = '${AppConfig.apiBaseUrl}/public/trainers/${Uri.encodeComponent(widget.username)}';
      
      final response = await http
          .get(Uri.parse(apiUrl))
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          _trainerData = jsonDecode(response.body);
          _isLoading = false;
        });
      } else if (response.statusCode == 404) {
        setState(() {
          _errorMessage = 'Treinador não encontrado.';
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Erro ao carregar perfil.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Falha de conexão com o servidor.';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchPlans() async {
    try {
      final list = await ConsultancyPlanService.getPublicPlans(widget.username);
      if (mounted) {
        setState(() {
          _plans = list;
          _isLoadingPlans = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingPlans = false);
    }
  }

  void _openCheckoutModal(ConsultancyPlan plan) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: MetaColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _PublicCheckoutModal(
        username: widget.username,
        plan: plan,
        trainerName: _trainerData?['full_name'] as String? ?? 'Personal Trainer',
      ),
    );
  }

  Future<void> _openTrainerWhatsapp() async {
    final rawNumber = _trainerData?['public_whatsapp']?.toString() ?? '';
    var number = rawNumber.replaceAll(RegExp(r'\D'), '');
    if (number.length == 10 || number.length == 11) {
      number = '55$number';
    }
    if (number.length != 12 && number.length != 13) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este treinador ainda não configurou o WhatsApp de contato.'),
        ),
      );
      return;
    }

    final trainerName = _trainerData?['full_name'] as String? ?? 'Treinador';
    final message = 'Olá, $trainerName! Vi seus planos de consultoria no Mr. Coach e gostaria de tirar uma dúvida.';
    final encodedMsg = Uri.encodeComponent(message);

    final nativeUri = Uri.parse('whatsapp://send?phone=$number&text=$encodedMsg');
    final apiUri = Uri.parse('https://api.whatsapp.com/send?phone=$number&text=$encodedMsg');
    final waMeUri = Uri.parse('https://wa.me/$number?text=$encodedMsg');

    try {
      if (await canLaunchUrl(nativeUri)) {
        await launchUrl(nativeUri, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(apiUri)) {
        await launchUrl(apiUri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(waMeUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      await launchUrl(waMeUri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: MetaColors.background,
        body: Center(
          child: CircularProgressIndicator(color: MetaColors.emerald),
        ),
      );
    }

    if (_errorMessage != null || _trainerData == null) {
      return Scaffold(
        backgroundColor: MetaColors.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
                const SizedBox(height: 16),
                Text(
                  _errorMessage ?? 'Erro inesperado.',
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _fetchTrainerProfile,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tentar Novamente'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MetaColors.surfaceHighlight,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final name = _trainerData!['full_name'] as String? ?? 'Treinador';
    final bio = _trainerData!['bio'] as String?;
    final specialties = (_trainerData!['specialties'] as List<dynamic>?) ?? [];
    final photoUrl = _trainerData!['photo_url'];
    final hasPhoto = photoUrl != null && photoUrl.toString().trim().isNotEmpty;

    return Scaffold(
      backgroundColor: MetaColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280.0,
            pinned: false,
            elevation: 0,
            backgroundColor: MetaColors.background,
            systemOverlayStyle: SystemUiOverlayStyle.light,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (hasPhoto)
                    Image.network(
                      photoUrl.toString().trim(),
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, err, stack) => _buildPlaceholderPhoto(name),
                    )
                  else
                    _buildPlaceholderPhoto(name),
                  
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          MetaColors.background.withValues(alpha: 0.6),
                          MetaColors.background,
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 0.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: MetaColors.emerald.withValues(alpha: 0.1),
                      border: Border.all(color: MetaColors.emerald.withValues(alpha: 0.3)),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified_rounded, color: MetaColors.emerald, size: 14),
                        SizedBox(width: 6),
                        Text(
                          'TREINADOR COM REGISTRO PROFISSIONAL',
                          style: TextStyle(
                            color: MetaColors.emerald,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0),
                  
                  const SizedBox(height: 14),

                  Text(
                    name.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      height: 1.15,
                    ),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0),
                  
                  const SizedBox(height: 14),
                  
                  if (specialties.isNotEmpty) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: specialties.map((spec) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: MetaColors.surfaceHighlight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          spec.toString().toUpperCase(), 
                          style: const TextStyle(
                            fontWeight: FontWeight.w700, 
                            color: MetaColors.textSecondary,
                            fontSize: 10,
                            letterSpacing: 0.8,
                          )
                        ),
                      )).toList(),
                    ).animate().fadeIn(delay: 300.ms).scale(),
                    const SizedBox(height: 16),
                  ],
                  
                  if (bio != null && bio.trim().isNotEmpty) ...[
                    Text(
                      bio,
                      style: const TextStyle(
                        color: MetaColors.textSecondary,
                        fontSize: 14,
                        height: 1.45,
                        fontWeight: FontWeight.w400,
                      ),
                      textAlign: TextAlign.center,
                    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1, end: 0),
                    const SizedBox(height: 12),
                  ],

                  if ((_trainerData!['cref'] as String?)?.isNotEmpty == true) ...[
                    Text(
                      'Registro profissional: ${_trainerData!['cref']}',
                      style: const TextStyle(color: MetaColors.textSecondary, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                  ] else ...[
                    const SizedBox(height: 20),
                  ],

                  // ==========================================================
                  // SEÇÃO DE PLANOS & PREÇOS (FASE 6 - PASSO 3)
                  // ==========================================================
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Planos de Consultoria',
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Assine diretamente com pagamento seguro via Pix ou Cartão:',
                      style: TextStyle(color: MetaColors.textSecondary, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (_isLoadingPlans)
                    const Center(child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: CircularProgressIndicator(color: MetaColors.emerald),
                    ))
                  else if (_plans.isEmpty)
                    MetaCard(
                      padding: const EdgeInsets.all(20),
                      child: const Column(
                        children: [
                          Icon(Icons.hourglass_empty_rounded, color: MetaColors.textSecondary, size: 36),
                          SizedBox(height: 10),
                          Text(
                            'Nenhum plano configurado no momento',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Entre em contato pelo WhatsApp para verificar valores e disponibilidade.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: MetaColors.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    )
                  else
                    ..._plans.map((plan) => _buildPublicPlanCard(plan)),

                  const SizedBox(height: 36),

                  // Como funciona o app (Social Proof)
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'O que você terá no app Mr. Coach',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildProofRow(Icons.assignment_outlined, 'Avaliação Inicial Personalizada', 'Seu treinador analisa seus objetivos, rotina e histórico articular.'),
                  const SizedBox(height: 14),
                  _buildProofRow(Icons.fitness_center_rounded, 'Treinos e Cargas Acompanhadas', 'Acesse sua ficha exclusiva, veja vídeos de execução e marque seu streak.'),
                  const SizedBox(height: 14),
                  _buildProofRow(Icons.auto_awesome_rounded, 'IA de Substituição em 1 Toque', 'Aparelho ocupado na academia? Troque por outro biomecanicamente equivalente na hora.'),
                  const SizedBox(height: 14),
                  _buildProofRow(Icons.chat_bubble_outline_rounded, 'Suporte com Seu Treinador', 'Canal direto para tirar dúvidas sobre cargas, evolução e execução.'),

                  const SizedBox(height: 32),

                  if ((_trainerData!['public_whatsapp'] as String?)?.trim().isNotEmpty == true) ...[
                    OutlinedButton.icon(
                      onPressed: _openTrainerWhatsapp,
                      icon: const Icon(Icons.chat_outlined),
                      label: const Text('Tirar Dúvidas pelo WhatsApp'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: MetaColors.emerald,
                        side: const BorderSide(color: MetaColors.emerald),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],

                  const SizedBox(height: 48),

                  const Text(
                    'Plataforma B2B Mr. Coach • Tecnologia Shaipados Labs',
                    style: TextStyle(color: MetaColors.textSecondary, fontSize: 11),
                  ),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: () {
              if (_plans.isNotEmpty) {
                _openCheckoutModal(_plans.first);
              } else {
                _openTrainerWhatsapp();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: MetaColors.emerald,
              foregroundColor: Colors.white,
              elevation: 4,
              shadowColor: MetaColors.emerald.withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            icon: const Icon(Icons.flash_on_rounded, size: 20),
            label: const Text(
              'COMEÇAR MINHA CONSULTORIA',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 0.8),
            ),
          ),
        ).animate(onPlay: (controller) => controller.repeat(reverse: true))
         .scaleXY(begin: 1.0, end: 1.02, duration: 1.5.seconds, curve: Curves.easeInOut),
      ),
    );
  }

  Widget _buildPublicPlanCard(ConsultancyPlan plan) {
    final isHighlighted = plan.billingPeriod == 'quarterly' || plan.billingPeriod == 'annual';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isHighlighted ? MetaColors.emerald : Colors.white12,
          width: isHighlighted ? 2.0 : 1.0,
        ),
      ),
      child: MetaCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isHighlighted) ...[
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: MetaColors.emerald,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'MAIS POPULAR • MELHOR CUSTO-BENEFÍCIO',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        plan.billingPeriodLabel,
                        style: const TextStyle(color: MetaColors.emerald, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'R\$ ${plan.price.toStringAsFixed(2).replaceAll('.', ',')}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (plan.billingPeriod != 'one_time')
                      Text(
                        plan.billingPeriod == 'quarterly' ? '(R\$ ${(plan.price / 3).toStringAsFixed(2).replaceAll('.', ',')}/mês)' : '/mês',
                        style: const TextStyle(color: MetaColors.textSecondary, fontSize: 11),
                      ),
                  ],
                ),
              ],
            ),

            if (plan.description != null && plan.description!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                plan.description!,
                style: const TextStyle(color: MetaColors.textSecondary, fontSize: 13, height: 1.35),
              ),
            ],

            if (plan.features.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Divider(color: Colors.white10),
              const SizedBox(height: 10),
              ...plan.features.map((feat) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle_rounded, color: MetaColors.emerald, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        feat,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              )),
            ],

            const SizedBox(height: 16),
            SquircleButton(
              label: 'Assinar Plano (${plan.billingPeriodLabel})',
              icon: Icons.lock_outline,
              isPrimary: true,
              onPressed: () => _openCheckoutModal(plan),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderPhoto(String trainerName) {
    final initials = trainerName.trim().isNotEmpty
        ? trainerName
            .trim()
            .split(RegExp(r'\s+'))
            .take(2)
            .map((e) => e.isNotEmpty ? e[0].toUpperCase() : '')
            .join()
        : 'PT';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            MetaColors.surfaceHighlight.withValues(alpha: 0.5),
            MetaColors.background,
          ],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 16.0),
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: MetaColors.emerald.withValues(alpha: 0.15),
              border: Border.all(
                color: MetaColors.emerald.withValues(alpha: 0.45),
                width: 2.5,
              ),
            ),
            child: Center(
              child: Text(
                initials,
                style: const TextStyle(
                  color: MetaColors.emerald,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProofRow(IconData icon, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: MetaColors.emerald.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: MetaColors.emerald, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title, 
                style: const TextStyle(
                  color: Colors.white, 
                  fontSize: 15, 
                  fontWeight: FontWeight.w700,
                )
              ),
              const SizedBox(height: 3),
              Text(
                subtitle, 
                style: const TextStyle(
                  color: MetaColors.textSecondary, 
                  fontSize: 13,
                  height: 1.35,
                )
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PublicCheckoutModal extends StatefulWidget {
  final String username;
  final ConsultancyPlan plan;
  final String trainerName;

  const _PublicCheckoutModal({
    required this.username,
    required this.plan,
    required this.trainerName,
  });

  @override
  State<_PublicCheckoutModal> createState() => _PublicCheckoutModalState();
}

class _PublicCheckoutModalState extends State<_PublicCheckoutModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _cpfCtrl = TextEditingController();

  String _paymentMethod = 'PIX';
  bool _isSubmitting = false;
  PublicCheckoutResult? _checkoutResult;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _cpfCtrl.dispose();
    super.dispose();
  }

  Future<void> _processPayment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final res = await ConsultancyPlanService.publicCheckout(
        username: widget.username,
        planId: widget.plan.id,
        studentName: _nameCtrl.text.trim(),
        studentEmail: _emailCtrl.text.trim().toLowerCase(),
        studentPhone: _phoneCtrl.text.trim(),
        studentCpf: _cpfCtrl.text.trim().isNotEmpty ? _cpfCtrl.text.trim() : null,
        paymentMethod: _paymentMethod,
      );

      if (mounted) {
        setState(() {
          _checkoutResult = res;
          _isSubmitting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _copyPixCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Código Pix Copia e Cola copiado com sucesso!'),
        backgroundColor: MetaColors.emerald,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: _checkoutResult == null ? _buildFormStep() : _buildSuccessPixStep(),
    );
  }

  Widget _buildFormStep() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Checkout Seguro',
                        style: TextStyle(color: MetaColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        widget.plan.name,
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                Text(
                  'R\$ ${widget.plan.price.toStringAsFixed(2).replaceAll('.', ',')}',
                  style: const TextStyle(color: MetaColors.emerald, fontSize: 20, fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: Colors.white10),
            const SizedBox(height: 14),

            const Text('Seus Dados de Acesso', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            // Nome
            TextFormField(
              controller: _nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Nome Completo',
                labelStyle: const TextStyle(color: MetaColors.textSecondary),
                filled: true,
                fillColor: MetaColors.surfaceHighlight,
                prefixIcon: const Icon(Icons.person_outline, color: MetaColors.textSecondary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              validator: (v) => (v == null || v.trim().length < 3) ? 'Informe seu nome completo' : null,
            ),
            const SizedBox(height: 12),

            // E-mail
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'E-mail para login no app',
                labelStyle: const TextStyle(color: MetaColors.textSecondary),
                filled: true,
                fillColor: MetaColors.surfaceHighlight,
                prefixIcon: const Icon(Icons.email_outlined, color: MetaColors.textSecondary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              validator: (v) => (v == null || !v.contains('@') || !v.contains('.')) ? 'Informe um e-mail válido' : null,
            ),
            const SizedBox(height: 12),

            // WhatsApp
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'WhatsApp com DDD',
                hintText: 'Ex: (11) 98888-7777',
                labelStyle: const TextStyle(color: MetaColors.textSecondary),
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: MetaColors.surfaceHighlight,
                prefixIcon: const Icon(Icons.phone_outlined, color: MetaColors.textSecondary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              validator: (v) => (v == null || v.replaceAll(RegExp(r'\D'), '').length < 10) ? 'Informe seu WhatsApp com DDD' : null,
            ),
            const SizedBox(height: 12),

            // CPF
            TextFormField(
              controller: _cpfCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'CPF (para emissão do Pix)',
                hintText: '000.000.000-00',
                labelStyle: const TextStyle(color: MetaColors.textSecondary),
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: MetaColors.surfaceHighlight,
                prefixIcon: const Icon(Icons.badge_outlined, color: MetaColors.textSecondary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),

            // Método de Pagamento
            const Text('Forma de Pagamento', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _paymentMethod = 'PIX'),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _paymentMethod == 'PIX' ? MetaColors.emerald.withValues(alpha: 0.15) : MetaColors.surfaceHighlight,
                        border: Border.all(
                          color: _paymentMethod == 'PIX' ? MetaColors.emerald : Colors.transparent,
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.pix_rounded, color: _paymentMethod == 'PIX' ? MetaColors.emerald : MetaColors.textSecondary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Pix (Instantâneo)',
                            style: TextStyle(
                              color: _paymentMethod == 'PIX' ? Colors.white : MetaColors.textSecondary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _paymentMethod = 'CREDIT_CARD'),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _paymentMethod == 'CREDIT_CARD' ? MetaColors.emerald.withValues(alpha: 0.15) : MetaColors.surfaceHighlight,
                        border: Border.all(
                          color: _paymentMethod == 'CREDIT_CARD' ? MetaColors.emerald : Colors.transparent,
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.credit_card, color: _paymentMethod == 'CREDIT_CARD' ? MetaColors.emerald : MetaColors.textSecondary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Cartão',
                            style: TextStyle(
                              color: _paymentMethod == 'CREDIT_CARD' ? Colors.white : MetaColors.textSecondary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            SquircleButton(
              label: _isSubmitting ? 'Gerando Cobrança...' : 'Confirmar e Pagar Agora',
              icon: Icons.shield_outlined,
              isPrimary: true,
              onPressed: _isSubmitting ? null : _processPayment,
            ),
            const SizedBox(height: 12),
            const Center(
              child: Text(
                '🔒 Pagamento processado com segurança via Asaas Gateway',
                style: TextStyle(color: MetaColors.textSecondary, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessPixStep() {
    final res = _checkoutResult!;
    final pixCode = res.pixCopyPaste ?? '';

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MetaColors.emerald.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_outline_rounded, color: MetaColors.emerald, size: 40),
          ),
          const SizedBox(height: 12),
          const Text(
            'Cobrança Gerada com Sucesso!',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Plano ${widget.plan.name} • R\$ ${widget.plan.price.toStringAsFixed(2).replaceAll('.', ',')}',
            style: const TextStyle(color: MetaColors.emerald, fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),

          // Código Pix Copia e Cola
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: MetaColors.surfaceHighlight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.pix_rounded, color: MetaColors.emerald, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Pix Copia e Cola:',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  pixCode,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: MetaColors.textSecondary, fontSize: 11, fontFamily: 'monospace'),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _copyPixCode(pixCode),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MetaColors.emerald,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('COPIAR CÓDIGO PIX', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          const Text(
            'Como funciona a liberação?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          const Text(
            '1. Abra o app do seu banco e pague com o Pix Copia e Cola.\n'
            '2. O Asaas confirma o pagamento instantaneamente.\n'
            '3. Seu acesso e anamnese serão liberados e o professor avisado no WhatsApp!',
            style: TextStyle(color: MetaColors.textSecondary, fontSize: 12, height: 1.45),
          ),

          const SizedBox(height: 24),
          SquircleButton(
            label: 'Concluir / Já Realizei o Pagamento',
            isPrimary: true,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
