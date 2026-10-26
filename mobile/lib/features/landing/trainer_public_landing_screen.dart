// ignore_for_file: use_build_context_synchronously
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import '../../core/utils/currency_pt_br_formatter.dart';
import '../../core/widgets/meta_components.dart';
import '../../core/widgets/theme_toggle_button.dart';
import '../../services/consultancy_plan_service.dart';
import '../auth/login_screen.dart';

class TrainerPublicLandingScreen extends StatefulWidget {
  final String username;
  final Map<String, dynamic>? initialTrainerData;
  final List<ConsultancyPlan>? initialPlans;

  const TrainerPublicLandingScreen({
    super.key,
    required this.username,
    this.initialTrainerData,
    this.initialPlans,
  });

  @override
  State<TrainerPublicLandingScreen> createState() => _TrainerPublicLandingScreenState();
}

class _TrainerPublicLandingScreenState extends State<TrainerPublicLandingScreen> {
  bool get isDark => MetaColors.isDark(context);
  bool _isLoading = true;
  Map<String, dynamic>? _trainerData;
  String? _errorMessage;

  List<ConsultancyPlan> _plans = [];
  bool _isLoadingPlans = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialTrainerData != null) {
      _trainerData = widget.initialTrainerData;
      _isLoading = false;
    } else {
      _fetchTrainerProfile();
    }
    if (widget.initialPlans != null) {
      _plans = widget.initialPlans!;
      _isLoadingPlans = false;
    } else {
      _fetchPlans();
    }
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
      backgroundColor: MetaColors.card(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _PublicCheckoutModal(
        username: widget.username,
        plan: plan,
        trainerName: _trainerData?['full_name'] as String? ?? 'Personal Trainer',
        trainerWhatsapp: _trainerData?['public_whatsapp'] as String?,
      ),
    );
  }

  bool get _acceptsNewStudents => _trainerData?['accepts_new_students'] != false;

  Future<void> _openTrainerWhatsapp({String? customMessage}) async {
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
    final message = customMessage ?? 'Olá, $trainerName! Vi seus planos de consultoria no Mr. Coach e gostaria de tirar uma dúvida.';
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

  Future<void> _openWaitlistWhatsapp(ConsultancyPlan plan) async {
    final trainerName = _trainerData?['full_name'] as String? ?? 'Personal';
    final msg = 'Olá, professor(a) $trainerName! Vi o plano "${plan.name}" na sua vitrine, mas vi que as vagas estão lotadas no momento. Gostaria de entrar na lista de espera para ser avisado assim que abrir uma vaga! 💪';
    await _openTrainerWhatsapp(customMessage: msg);
  }

  Future<void> _openTrainerWhatsappForPlan(ConsultancyPlan plan) async {
    final trainerName = _trainerData?['full_name'] as String? ?? 'Treinador';
    final priceStr = CurrencyPtBrFormatter.format(plan.price);
    final msg = 'Olá, professor(a) $trainerName! Vi o plano "${plan.name}" ($priceStr) na sua vitrine Mr. Coach e gostaria de tirar uma dúvida antes de fechar a contratação! 💪';
    await _openTrainerWhatsapp(customMessage: msg);
  }

  void _copyConsultancyLink() {
    final link = 'https://mrcoach.shaipados.com/p/${widget.username}';
    Clipboard.setData(ClipboardData(text: link));
    HapticFeedback.lightImpact();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: MetaColors.emerald, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Link da vitrine copiado: $link',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: MetaColors.isDark(context) ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildCrefBadge() {
    final cref = (_trainerData?['cref'] as String?)?.trim();
    final hasCref = cref != null && cref.isNotEmpty;
    final isDark = MetaColors.isDark(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F2618) : const Color(0xFFECFDF5),
        border: Border.all(
          color: isDark ? const Color(0xFF1B4D30) : const Color(0xFFA7F3D0),
          width: 1.2,
        ),
        borderRadius: BorderRadius.circular(50),
        boxShadow: [
          BoxShadow(
            color: MetaColors.emerald.withValues(alpha: isDark ? 0.15 : 0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.verified_rounded, color: MetaColors.emerald, size: 15),
          const SizedBox(width: 6),
          Text(
            hasCref ? 'CREF $cref • VERIFICADO' : 'TREINADOR COM REGISTRO PROFISSIONAL',
            style: const TextStyle(
              color: MetaColors.emerald,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0);
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
    final isDark = MetaColors.isDark(context);

    return Scaffold(
      backgroundColor: MetaColors.bg(context),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280.0,
            pinned: false,
            elevation: 0,
            backgroundColor: MetaColors.bg(context),
            systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
            actions: [
              IconButton(
                tooltip: 'Compartilhar Vitrine',
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.65),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
                    ),
                  ),
                  child: const Icon(Icons.share_rounded, size: 16),
                ),
                onPressed: _copyConsultancyLink,
              ),
              const Padding(
                padding: EdgeInsets.only(right: 12.0),
                child: ThemeToggleButton(compact: true),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Ambient Glow Verde Esmeralda (Estética One UI)
                  Positioned(
                    top: -40,
                    left: 0,
                    right: 0,
                    height: 240,
                    child: Center(
                      child: Container(
                        width: 260,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: MetaColors.emerald.withValues(alpha: isDark ? 0.20 : 0.12),
                        ),
                      ),
                    ),
                  ),
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
                          MetaColors.bg(context).withValues(alpha: 0.65),
                          MetaColors.bg(context),
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
                  _buildCrefBadge(),
                  const SizedBox(height: 14),

                  Text(
                    name.toUpperCase(),
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
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
                      style: TextStyle(
                        color: isDark ? MetaColors.textSecondary : MetaColors.lightTextSecondary,
                        fontSize: 14,
                        height: 1.45,
                        fontWeight: FontWeight.w400,
                      ),
                      textAlign: TextAlign.center,
                    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1, end: 0),
                    const SizedBox(height: 18),
                  ] else ...[
                    const SizedBox(height: 10),
                  ],

                  // 1. BIG NUMBERS DE AUTORIDADE
                  _buildAuthorityStatsBar(),
                  const SizedBox(height: 36),

                  // 2. METODOLOGIA DO TREINADOR
                  _buildMethodologySection(name),
                  const SizedBox(height: 36),

                  // 3. CASOS REAIS & TRANSFORMAÇÕES ANTES/DEPOIS
                  BeforeAfterCaseViewer(
                    onSelectPlan: () {
                      if (_plans.isNotEmpty) {
                        _openCheckoutModal(_plans.first);
                      } else {
                        _openTrainerWhatsapp();
                      }
                    },
                  ),
                  const SizedBox(height: 36),

                  // 4. PARA QUEM É A CONSULTORIA
                  _buildTargetAudienceSection(),
                  const SizedBox(height: 36),

                  // 5. A EXPERIÊNCIA COM O APP MR. COACH
                  _buildAppExperienceSection(),
                  const SizedBox(height: 40),

                  // 6. PLANOS DE CONSULTORIA & CHECKOUT PIX
                  _buildPlansSection(),
                  const SizedBox(height: 36),

                  // 7. PASSO A PASSO PÓS-COMPRA & FAQ
                  _buildPostPurchaseStepsSection(),
                  const SizedBox(height: 32),

                  _buildFaqSection(),
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
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Row(
            children: [
              if ((_trainerData?['public_whatsapp'] as String?)?.trim().isNotEmpty == true) ...[
                Container(
                  height: 54,
                  width: 54,
                  margin: const EdgeInsets.only(right: 10),
                  child: FloatingActionButton(
                    heroTag: 'trainer_whatsapp_fab',
                    onPressed: _openTrainerWhatsapp,
                    backgroundColor: const Color(0xFF25D366),
                    elevation: 3,
                    child: const Icon(Icons.chat_rounded, color: Colors.white, size: 24),
                  ),
                ),
              ],
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (_plans.isNotEmpty) {
                        _openCheckoutModal(_plans.first);
                      } else {
                        _openTrainerWhatsapp();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? MetaColors.emerald : MetaColors.lightEmerald,
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shadowColor: MetaColors.emerald.withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    icon: const Icon(Icons.flash_on_rounded, size: 20),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'CONTRATAR CONSULTORIA PIX',
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
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
          color: isHighlighted ? (isDark ? MetaColors.emerald : MetaColors.lightEmerald) : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
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
                      color: isDark ? MetaColors.emerald : MetaColors.lightEmerald,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'MAIS POPULAR • MELHOR CUSTO-BENEFÍCIO',
                      style: TextStyle(
                        color: Colors.white,
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
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        plan.billingPeriodLabel,
                        style: TextStyle(
                          color: isDark ? MetaColors.emerald : MetaColors.lightEmerald,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      CurrencyPtBrFormatter.format(plan.price),
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (plan.billingPeriod != 'one_time')
                      Text(
                        plan.billingPeriod == 'quarterly'
                            ? '(${CurrencyPtBrFormatter.format(plan.price / 3)}/mês)'
                            : '/mês',
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

            if (!_acceptsNewStudents) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.hourglass_top_rounded, color: Colors.amber, size: 14),
                    SizedBox(width: 6),
                    Text(
                      'TURMA LOTADA • LISTA DE ESPERA',
                      style: TextStyle(
                        color: Colors.amber,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),
            if (_acceptsNewStudents) ...[
              // Selos de Confiança e Escassez One UI
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (isDark ? MetaColors.emerald : MetaColors.lightEmerald).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: (isDark ? MetaColors.emerald : MetaColors.lightEmerald).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shield_outlined, size: 12, color: isDark ? MetaColors.emerald : MetaColors.lightEmerald),
                        const SizedBox(width: 4),
                        Text(
                          'Garantia de 7 Dias',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? MetaColors.emerald : MetaColors.lightEmerald,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt_rounded, size: 12, color: Colors.amber),
                        SizedBox(width: 4),
                        Text(
                          'Vagas Limitadas',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.amber,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Botão Primário: Pix Copia e Cola / Cartão Imediato Asaas
              SquircleButton(
                label: 'Contratar Imediato (Pix / Cartão)',
                icon: Icons.pix_rounded,
                isPrimary: true,
                onPressed: () => _openCheckoutModal(plan),
              ),
              const SizedBox(height: 8),

              // Botão Secundário: Fechamento Assistido via WhatsApp CRM
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _openTrainerWhatsappForPlan(plan),
                  icon: const Icon(Icons.chat_outlined, size: 16),
                  label: const Text('Tirar Dúvidas no WhatsApp'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? const Color(0xFFB4C8BE) : const Color(0xFF334155),
                    side: BorderSide(
                      color: isDark ? const Color(0xFF2C4033) : const Color(0xFFCBD5E1),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  '🔒 Pagamento processado com segurança • Acesso instantâneo',
                  style: TextStyle(color: MetaColors.textSecondary, fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ),
            ] else ...[
              SquircleButton(
                label: 'Entrar na Lista de Espera',
                icon: Icons.mark_chat_unread_outlined,
                isPrimary: false,
                onPressed: () => _openWaitlistWhatsapp(plan),
              ),
            ],
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
    final isDark = MetaColors.isDark(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: (isDark ? MetaColors.emerald : MetaColors.lightEmerald).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: isDark ? MetaColors.emerald : MetaColors.lightEmerald, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title, 
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A), 
                  fontSize: 15, 
                  fontWeight: FontWeight.w700,
                )
              ),
              const SizedBox(height: 3),
              Text(
                subtitle, 
                style: TextStyle(
                  color: isDark ? MetaColors.textSecondary : MetaColors.lightTextSecondary, 
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

  Widget _buildAuthorityStatsBar() {
    final isDark = MetaColors.isDark(context);
    final studentsCount = _trainerData?['students_count'] ?? _trainerData?['active_students_count'];
    final studentsStr = studentsCount != null ? '+$studentsCount' : '+500';
    final experienceYears = _trainerData?['experience_years']?.toString() ?? '10+';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141F18) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF26392D) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatBadge(
              number: experienceYears,
              unit: 'Anos',
              label: 'Experiência',
              icon: Icons.workspace_premium_rounded,
            ),
          ),
          SizedBox(height: 30, child: VerticalDivider(color: isDark ? const Color(0xFF2C4033) : const Color(0xFFE2E8F0))),
          Expanded(
            child: _StatBadge(
              number: studentsStr,
              unit: 'Alunos',
              label: 'Acompanhados',
              icon: Icons.people_alt_rounded,
            ),
          ),
          SizedBox(height: 30, child: VerticalDivider(color: isDark ? const Color(0xFF2C4033) : const Color(0xFFE2E8F0))),
          const Expanded(
            child: _StatBadge(
              number: '5.0',
              unit: '★',
              label: 'Avaliação Média',
              icon: Icons.star_rounded,
              isGold: true,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 450.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildMethodologySection(String name) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Metodologia & Prescrição Inteligente',
            style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 4),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Cada repetição, carga e exercício possui fundamentação anatômica e científica.',
            style: TextStyle(color: MetaColors.textSecondary, fontSize: 13),
          ),
        ),
        const SizedBox(height: 16),
        _buildMethodCard(
          icon: Icons.accessibility_new_rounded,
          title: 'Prescrição Biomecânica Fina',
          description:
              'Ajuste do braço de momento, alinhamento articular e seleção de exercícios adaptados à sua anatomia individual.',
        ),
        const SizedBox(height: 12),
        _buildMethodCard(
          icon: Icons.trending_up_rounded,
          title: 'Sobrecarga Progressiva com Fórmulas de IA',
          description:
              'Volume de séries e intensidade dosados matematicamente com estimativas de 1RM por Epley/Brzycki para hipertrofia sem lesão.',
        ),
        const SizedBox(height: 12),
        _buildMethodCard(
          icon: Icons.forum_rounded,
          title: 'Acompanhamento Ativo & Presença no WhatsApp',
          description:
              'Suporte contínuo para tirar dúvidas de execução, analisar vídeos de séries pesadas e ajustar o treino conforme seu feedback.',
        ),
      ],
    );
  }

  Widget _buildMethodCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    final isDark = MetaColors.isDark(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131D17) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF26382D) : const Color(0xFFE2E8F0)),
        boxShadow: isDark ? null : [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (isDark ? MetaColors.emerald : MetaColors.lightEmerald).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: isDark ? MetaColors.emerald : MetaColors.lightEmerald, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: isDark ? MetaColors.textSecondary : MetaColors.lightTextSecondary,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetAudienceSection() {
    final isDark = MetaColors.isDark(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF101914) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF223528) : const Color(0xFFE2E8F0)),
        boxShadow: isDark ? null : [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.checklist_rounded, color: isDark ? MetaColors.emerald : MetaColors.lightEmerald, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Esta consultoria é ideal para você se:',
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildAudienceCheckItem('Quer hipertrofia ou queima de gordura consistente sem estagnação.'),
          _buildAudienceCheckItem('Sente dores no ombro, joelho ou coluna e precisa de correção biomecânica.'),
          _buildAudienceCheckItem('Trabalha muito e quer treinos objetivos de 45 a 60 minutos com alta densidade.'),
          _buildAudienceCheckItem('Treina em academia comercial, condomínio ou casa e quer saber exatamente o que fazer.'),
        ],
      ),
    );
  }

  Widget _buildAudienceCheckItem(String text) {
    final isDark = MetaColors.isDark(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_rounded, color: isDark ? MetaColors.emerald : MetaColors.lightEmerald, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: isDark ? const Color(0xFFCFDBD2) : const Color(0xFF334155),
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppExperienceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'A Experiência no App Mr. Coach',
            style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 4),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Você não recebe um PDF frio de gaveta. Você ganha um ecossistema inteligente:',
            style: TextStyle(color: MetaColors.textSecondary, fontSize: 13),
          ),
        ),
        const SizedBox(height: 16),
        _buildProofRow(Icons.assignment_outlined, 'Avaliação Inicial Personalizada', 'Anamnese completa dos seus objetivos, rotina diária e histórico articular.'),
        const SizedBox(height: 14),
        _buildProofRow(Icons.fitness_center_rounded, 'Treinos e Cargas Acompanhadas', 'Ficha exclusiva com vídeos em HD, orientações de execução e streak de consistência.'),
        const SizedBox(height: 14),
        _buildProofRow(Icons.auto_awesome_rounded, 'Substituição por IA em 5 Segundos', 'Aparelho ocupado na academia? Troque por outro biomecanicamente equivalente na hora.'),
        const SizedBox(height: 14),
        _buildProofRow(Icons.timer_outlined, 'Rest Timer Cadenciado na Tela', 'Descanso monitorado com avisos táteis e sonoros para manter a intensidade hipertrófica.'),
      ],
    );
  }

  Widget _buildPlansSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Planos de Consultoria',
            style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 20, fontWeight: FontWeight.bold),
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
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: CircularProgressIndicator(color: MetaColors.emerald),
            ),
          )
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
      ],
    );
  }

  Widget _buildPostPurchaseStepsSection() {
    final isDark = MetaColors.isDark(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131D17) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF25392D) : const Color(0xFFE2E8F0)),
        boxShadow: isDark ? null : [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Como funciona após a matrícula?',
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          _buildStepRow('1', 'Pagamento confirmado instantaneamente', 'O Pix é reconhecido em segundos e seu acesso é liberado.'),
          const SizedBox(height: 12),
          _buildStepRow('2', 'Preencha sua avaliação no app', 'Informe sua rotina, lesões antigas e equipamentos disponíveis.'),
          const SizedBox(height: 12),
          _buildStepRow('3', 'Alinhamento & Liberação da Ficha', 'O treinador conversa com você no WhatsApp e libera seu treino em até 48h.'),
        ],
      ),
    );
  }

  Widget _buildStepRow(String number, String title, String subtitle) {
    final isDark = MetaColors.isDark(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: isDark ? MetaColors.emerald : MetaColors.lightEmerald,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            number,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: isDark ? MetaColors.textSecondary : MetaColors.lightTextSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFaqSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Perguntas Frequentes (FAQ)',
            style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 12),
        _buildFaqItem(
          'Nunca treinei antes na vida, a consultoria serve para mim?',
          'Sim! O treino é prescrito exatamente para o seu nível atual, com vídeos demonstrativos de cada exercício e foco total em postura e segurança articular.',
        ),
        _buildFaqItem(
          'E se eu tiver dor no joelho ou problema na coluna?',
          'Na avaliação inicial você relata suas queixas articulares. Todos os exercícios são filtrados para descompressão articular e fortalecimento das estruturas vulneráveis.',
        ),
        _buildFaqItem(
          'Posso treinar na academia do condomínio ou em casa?',
          'Com certeza. O treinador monta a ficha adaptada aos aparelhos e pesos que você realmente tem à disposição.',
        ),
        _buildFaqItem(
          'Como tiro dúvidas durante os treinos?',
          'Você tem canal direto pelo WhatsApp e pode registrar comentários na própria ficha do app Mr. Coach.',
        ),
      ],
    );
  }

  Widget _buildFaqItem(String question, String answer) {
    final isDark = MetaColors.isDark(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: isDark ? const Color(0xFF121B15) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: isDark ? const Color(0xFF24352A) : const Color(0xFFE2E8F0)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            collapsedIconColor: isDark ? MetaColors.emerald : MetaColors.lightEmerald,
            iconColor: isDark ? MetaColors.emerald : MetaColors.lightEmerald,
            title: Text(
              question,
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: Text(
                  answer,
                  style: TextStyle(
                    color: isDark ? MetaColors.textSecondary : MetaColors.lightTextSecondary,
                    fontSize: 12.5,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// ONDA 1: VITRINE 2.0 - COMPARADOR DE ANTES/DEPOIS & RESULTADOS REAIS
// =============================================================================

class BeforeAfterCaseViewer extends StatefulWidget {
  final VoidCallback onSelectPlan;

  const BeforeAfterCaseViewer({super.key, required this.onSelectPlan});

  @override
  State<BeforeAfterCaseViewer> createState() => _BeforeAfterCaseViewerState();
}

class _CaseItem {
  final String title;
  final String category;
  final String duration;
  final String studentQuote;
  final String beforeWeight;
  final String afterWeight;
  final String beforeMetric;
  final String afterMetric;
  final String metricLabel;
  final String biomechanicalNote;
  final IconData icon;

  const _CaseItem({
    required this.title,
    required this.category,
    required this.duration,
    required this.studentQuote,
    required this.beforeWeight,
    required this.afterWeight,
    required this.beforeMetric,
    required this.afterMetric,
    required this.metricLabel,
    required this.biomechanicalNote,
    required this.icon,
  });
}

class _BeforeAfterCaseViewerState extends State<BeforeAfterCaseViewer> {
  int _selectedCaseIndex = 0;

  static const List<_CaseItem> _cases = [
    _CaseItem(
      title: 'Rodrigo M. (32 anos)',
      category: 'Hipertrofia & Força',
      duration: '16 semanas de consultoria',
      studentQuote:
          'Treinava há 2 anos estagnado e achando que consultoria online era só PDF pronto. O acompanhamento com recálculo de cargas e ajuste biomecânico destravou meus ganhos.',
      beforeWeight: '74 kg • 18% gordura',
      afterWeight: '79 kg • 11% gordura',
      metricLabel: '1RM Estimada no Supino',
      beforeMetric: '60 kg (estagnado)',
      afterMetric: '94 kg (+34 kg)',
      biomechanicalNote:
          'Ajuste do ângulo cotovelo-tronco de 75° para 50° eliminou dor na cápsula anterior do ombro, permitindo sobrecarga linear.',
      icon: Icons.fitness_center_rounded,
    ),
    _CaseItem(
      title: 'Juliana S. (28 anos)',
      category: 'Reabilitação Lombar',
      duration: '12 semanas de consultoria',
      studentQuote:
          'Tinha pânico de fazer agachamento por causa de uma hérnia de disco L5-S1. Meu treinador usou a IA para calibrar substituições exatas e hoje treino sem nenhuma dor.',
      beforeWeight: '68 kg • Crises constantes',
      afterWeight: '62 kg • 100% sem dor',
      metricLabel: 'Capacidade de Carga em Pernas',
      beforeMetric: '0 kg (repouso forçado)',
      afterMetric: '140 kg no Leg Press 45°',
      biomechanicalNote:
          'Substituição do agachamento axial por variações com tronco verticalizado e vetor de força sem cisalhamento sobre os discos vertebrais.',
      icon: Icons.health_and_safety_rounded,
    ),
    _CaseItem(
      title: 'Marcos T. (41 anos)',
      category: 'Emagrecimento & Definição',
      duration: '20 semanas de consultoria',
      studentQuote:
          'Trabalho mais de 10 horas por dia. O timer de descanso cadenciado e a praticidade de registrar o treino no celular me mantiveram constante pela primeira vez.',
      beforeWeight: '96 kg • 31% gordura',
      afterWeight: '81 kg (-15 kg) • 16% gordura',
      metricLabel: 'Assiduidade & Streak de Treino',
      beforeMetric: '1x na semana (desistia)',
      afterMetric: '94% de consistência no app',
      biomechanicalNote:
          'Periodização ondulatória diária respeitando os dias de maior estresse corporativo, com foco em densidade metabólica de 45 minutos.',
      icon: Icons.trending_up_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final currentCase = _cases[_selectedCaseIndex];

    final isDark = MetaColors.isDark(context);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141F18) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? MetaColors.emerald.withValues(alpha: 0.25) : const Color(0xFFE2E8F0),
        ),
        boxShadow: isDark ? null : [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: MetaColors.emerald.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.stars_rounded, color: MetaColors.emerald, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TRANSFORMAÇÕES REAIS',
                      style: TextStyle(
                        color: MetaColors.emerald,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Resultados Comprovados com Mr. Coach',
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Category chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < _cases.length; i++)
                InkWell(
                  onTap: () => setState(() => _selectedCaseIndex = i),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _selectedCaseIndex == i
                          ? (isDark ? MetaColors.emerald : MetaColors.lightEmerald)
                          : (isDark ? const Color(0xFF1C2B22) : const Color(0xFFF1F5F9)),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _selectedCaseIndex == i
                            ? (isDark ? MetaColors.emerald : MetaColors.lightEmerald)
                            : (isDark ? const Color(0xFF2C3E33) : const Color(0xFFCBD5E1)),
                      ),
                    ),
                    child: Text(
                      _cases[i].category,
                      style: TextStyle(
                        color: _selectedCaseIndex == i
                            ? Colors.white
                            : (isDark ? MetaColors.textSecondary : const Color(0xFF475569)),
                        fontSize: 12,
                        fontWeight: _selectedCaseIndex == i ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          // Student & Case Header
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                currentCase.title,
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                currentCase.duration,
                style: TextStyle(
                  color: isDark ? MetaColors.textSecondary : MetaColors.lightTextSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Slider Interativo Antes & Depois (One UI Drag Split)
          _BeforeAfterSplitCard(
            caseItem: currentCase,
            isDark: isDark,
          ),
          const SizedBox(height: 14),
          // Biomechanical note
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F1713) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? const Color(0xFF26362C) : const Color(0xFFE2E8F0)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.psychology_outlined, color: MetaColors.emerald, size: 17),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'DIFERENCIAL BIOMECÂNICO APLICADO:',
                        style: TextStyle(
                          color: MetaColors.emerald,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        currentCase.biomechanicalNote,
                        style: const TextStyle(
                          color: Color(0xFFB4C8BE),
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Student Quote
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(left: BorderSide(color: MetaColors.emerald, width: 3)),
            ),
            child: Text(
              '"${currentCase.studentQuote}"',
              style: const TextStyle(
                color: MetaColors.textSecondary,
                fontSize: 12.5,
                fontStyle: FontStyle.italic,
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Action button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: widget.onSelectPlan,
              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
              label: const Text('Quero Uma Transformação Assim'),
              style: OutlinedButton.styleFrom(
                foregroundColor: MetaColors.emerald,
                side: const BorderSide(color: MetaColors.emerald),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

}

class _BeforeAfterSplitCard extends StatefulWidget {
  final _CaseItem caseItem;
  final bool isDark;

  const _BeforeAfterSplitCard({
    required this.caseItem,
    required this.isDark,
  });

  @override
  State<_BeforeAfterSplitCard> createState() => _BeforeAfterSplitCardState();
}

class _BeforeAfterSplitCardState extends State<_BeforeAfterSplitCard> {
  double _splitRatio = 0.5;

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final item = widget.caseItem;

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final dividerX = totalWidth * _splitRatio;

        return Column(
          children: [
            GestureDetector(
              onHorizontalDragUpdate: (details) {
                setState(() {
                  _splitRatio = (details.localPosition.dx / totalWidth).clamp(0.08, 0.92);
                });
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  width: totalWidth,
                  height: 190,
                  child: Stack(
                    children: [
                      // Camada 1: ANTES (Fundo Completo)
                      Positioned.fill(
                        child: Container(
                          color: isDark ? const Color(0xFF1F1616) : const Color(0xFFFFF1F2),
                          padding: const EdgeInsets.all(16),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: SizedBox(
                              width: totalWidth * 0.75,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.history_rounded, size: 12, color: Color(0xFFEF4444)),
                                            SizedBox(width: 4),
                                            Text(
                                              'ANTES',
                                              style: TextStyle(
                                                color: Color(0xFFEF4444),
                                                fontSize: 10,
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: 0.8,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    item.beforeWeight,
                                    style: TextStyle(
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.5,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${item.metricLabel}:',
                                    style: TextStyle(
                                      color: isDark ? MetaColors.textSecondary : MetaColors.lightTextSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                  Text(
                                    item.beforeMetric,
                                    style: TextStyle(
                                      color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Camada 2: DEPOIS (Clipped Right Layer)
                      Positioned(
                        left: dividerX,
                        top: 0,
                        bottom: 0,
                        right: 0,
                        child: ClipRect(
                          child: OverflowBox(
                            alignment: Alignment.topRight,
                            minWidth: totalWidth,
                            maxWidth: totalWidth,
                            minHeight: 190,
                            maxHeight: 190,
                            child: Container(
                              width: totalWidth,
                              height: 190,
                              color: isDark ? const Color(0xFF0D2517) : const Color(0xFFECFDF5),
                              padding: const EdgeInsets.all(16),
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: SizedBox(
                                  width: totalWidth * 0.75,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: MetaColors.emerald.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: MetaColors.emerald.withValues(alpha: 0.3)),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.verified_rounded, size: 12, color: MetaColors.emerald),
                                                SizedBox(width: 4),
                                                Text(
                                                  'DEPOIS',
                                                  style: TextStyle(
                                                    color: MetaColors.emerald,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w900,
                                                    letterSpacing: 0.8,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        item.afterWeight,
                                        style: TextStyle(
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -0.5,
                                        ),
                                        textAlign: TextAlign.right,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '${item.metricLabel}:',
                                        style: TextStyle(
                                          color: isDark ? MetaColors.textSecondary : MetaColors.lightTextSecondary,
                                          fontSize: 11,
                                        ),
                                        textAlign: TextAlign.right,
                                      ),
                                      Text(
                                        item.afterMetric,
                                        style: const TextStyle(
                                          color: MetaColors.emerald,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                        ),
                                        textAlign: TextAlign.right,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Camada 3: Linha Divisória Luminous e Handle de Arraste
                      Positioned(
                        left: dividerX - 1.5,
                        top: 0,
                        bottom: 0,
                        width: 3,
                        child: Container(
                          decoration: BoxDecoration(
                            color: MetaColors.emerald,
                            boxShadow: [
                              BoxShadow(
                                color: MetaColors.emerald.withValues(alpha: 0.5),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: dividerX - 18,
                        top: 77,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0B140F) : Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: MetaColors.emerald, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.compare_arrows_rounded,
                            size: 20,
                            color: MetaColors.emerald,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Instrução tátil e botões de atalho rápido
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.touch_app_rounded,
                      size: 13,
                      color: isDark ? MetaColors.textSecondary : MetaColors.lightTextSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Arraste a linha para comparar',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? MetaColors.textSecondary : MetaColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    _buildQuickPreset('Antes', _splitRatio > 0.8, () => setState(() => _splitRatio = 0.92)),
                    const SizedBox(width: 6),
                    _buildQuickPreset('50/50', (_splitRatio - 0.5).abs() < 0.1, () => setState(() => _splitRatio = 0.5)),
                    const SizedBox(width: 6),
                    _buildQuickPreset('Depois', _splitRatio < 0.2, () => setState(() => _splitRatio = 0.08)),
                  ],
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildQuickPreset(String label, bool isSelected, VoidCallback onTap) {
    final isDark = widget.isDark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected
              ? MetaColors.emerald.withValues(alpha: 0.2)
              : (isDark ? const Color(0xFF1E2922) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? MetaColors.emerald
                : (isDark ? const Color(0xFF2C3E33) : const Color(0xFFE2E8F0)),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? MetaColors.emerald
                : (isDark ? MetaColors.textSecondary : const Color(0xFF475569)),
            fontSize: 10.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String number;
  final String unit;
  final String label;
  final IconData? icon;
  final bool isGold;

  const _StatBadge({
    required this.number,
    required this.unit,
    required this.label,
    this.icon,
    this.isGold = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = MetaColors.isDark(context);
    final accentColor = isGold ? const Color(0xFFF59E0B) : MetaColors.emerald;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: accentColor),
              const SizedBox(width: 3),
            ],
            Text(
              number,
              style: TextStyle(
                color: MetaColors.text(context),
                fontSize: 17,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(width: 2),
            Text(
              unit,
              style: TextStyle(
                color: accentColor,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            color: isDark ? MetaColors.textSecondary : MetaColors.lightTextSecondary,
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _PublicCheckoutModal extends StatefulWidget {
  final String username;
  final ConsultancyPlan plan;
  final String trainerName;
  final String? trainerWhatsapp;

  const _PublicCheckoutModal({
    required this.username,
    required this.plan,
    required this.trainerName,
    this.trainerWhatsapp,
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

  // Dados do Cartão de Crédito
  final _cardNumberCtrl = TextEditingController();
  final _cardHolderCtrl = TextEditingController();
  final _cardExpiryCtrl = TextEditingController();
  final _cardCcvCtrl = TextEditingController();
  final _cardCpfCtrl = TextEditingController();

  String _paymentMethod = 'PIX';
  bool _isSubmitting = false;
  PublicCheckoutResult? _checkoutResult;
  String? _checkoutError;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _cpfCtrl.dispose();
    _cardNumberCtrl.dispose();
    _cardHolderCtrl.dispose();
    _cardExpiryCtrl.dispose();
    _cardCcvCtrl.dispose();
    _cardCpfCtrl.dispose();
    super.dispose();
  }

  Future<void> _shareOnWhatsapp(String customMessage) async {
    final rawNumber = widget.trainerWhatsapp ?? '';
    var number = rawNumber.replaceAll(RegExp(r'\D'), '');
    if (number.length == 10 || number.length == 11) {
      number = '55$number';
    }
    if (number.length != 12 && number.length != 13) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('WhatsApp do treinador não informado no perfil.'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }
    final uri = Uri.parse('https://wa.me/$number?text=${Uri.encodeComponent(customMessage)}');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  Future<void> _processPayment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _checkoutError = null;
    });
    try {
      Map<String, dynamic>? creditCardData;
      if (_paymentMethod == 'CREDIT_CARD') {
        final cleanExp = _cardExpiryCtrl.text.replaceAll(RegExp(r'\D'), '');
        final expMonth = cleanExp.length >= 2 ? cleanExp.substring(0, 2) : '';
        var expYear = cleanExp.length >= 4 ? cleanExp.substring(2, 4) : (cleanExp.length >= 2 ? cleanExp.substring(2) : '');
        if (expYear.length == 2) {
          expYear = '20$expYear';
        }

        final holderCpf = _cardCpfCtrl.text.trim().isNotEmpty
            ? _cardCpfCtrl.text.replaceAll(RegExp(r'\D'), '')
            : _cpfCtrl.text.replaceAll(RegExp(r'\D'), '');

        creditCardData = {
          'holder_name': _cardHolderCtrl.text.trim().toUpperCase(),
          'number': _cardNumberCtrl.text.replaceAll(RegExp(r'\D'), ''),
          'expiry_month': expMonth,
          'expiry_year': expYear,
          'ccv': _cardCcvCtrl.text.trim(),
          'holder_cpf': holderCpf,
          'postal_code': '70000-000',
          'address_number': '1',
        };
      }

      final res = await ConsultancyPlanService.publicCheckout(
        username: widget.username,
        planId: widget.plan.id,
        studentName: _nameCtrl.text.trim(),
        studentEmail: _emailCtrl.text.trim().toLowerCase(),
        studentPhone: _phoneCtrl.text.trim(),
        studentCpf: _cpfCtrl.text.trim().isNotEmpty ? _cpfCtrl.text.trim() : null,
        paymentMethod: _paymentMethod,
        creditCard: creditCardData,
      );

      if (mounted) {
        setState(() {
          _checkoutResult = res;
          _isSubmitting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _checkoutError = e.toString().replaceAll('Exception: ', '');
        });
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
    final isDark = MetaColors.isDark(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: _checkoutResult == null
          ? _buildFormStep(isDark)
          : (_checkoutResult!.paymentMethod == 'CREDIT_CARD'
              ? _buildSuccessCardStep(isDark)
              : _buildSuccessPixStep(isDark)),
    );
  }

  Widget _buildFormStep(bool isDark) {
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtextColor = isDark ? MetaColors.textSecondary : MetaColors.lightTextSecondary;
    final inputFill = isDark ? MetaColors.surfaceHighlight : const Color(0xFFF1F5F9);
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: isDark ? BorderSide.none : const BorderSide(color: Color(0xFFCBD5E1)),
    );
    final hintColor = isDark ? Colors.white24 : const Color(0xFF94A3B8);

    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle Bar
            Center(
              child: Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Checkout Seguro',
                        style: TextStyle(color: subtextColor, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        widget.plan.name,
                        style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                Text(
                  'R\$ ${widget.plan.price.toStringAsFixed(2).replaceAll('.', ',')}',
                  style: const TextStyle(color: MetaColors.emerald, fontSize: 20, fontWeight: FontWeight.w900),
                ),
              ],
            ).animate().fadeIn(duration: 300.ms),
            const SizedBox(height: 16),
            Divider(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
            const SizedBox(height: 14),

            Text('Seus Dados de Acesso', style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            // Nome
            TextFormField(
              controller: _nameCtrl,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                labelText: 'Nome Completo',
                labelStyle: TextStyle(color: subtextColor),
                filled: true,
                fillColor: inputFill,
                prefixIcon: Icon(Icons.person_outline, color: subtextColor),
                border: inputBorder,
                enabledBorder: inputBorder,
              ),
              validator: (v) => (v == null || v.trim().length < 3) ? 'Informe seu nome completo' : null,
            ),
            const SizedBox(height: 12),

            // E-mail
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                labelText: 'E-mail para login no app',
                labelStyle: TextStyle(color: subtextColor),
                filled: true,
                fillColor: inputFill,
                prefixIcon: Icon(Icons.email_outlined, color: subtextColor),
                border: inputBorder,
                enabledBorder: inputBorder,
              ),
              validator: (v) => (v == null || !v.contains('@') || !v.contains('.')) ? 'Informe um e-mail válido' : null,
            ),
            const SizedBox(height: 12),

            // WhatsApp
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                labelText: 'WhatsApp com DDD',
                hintText: 'Ex: (11) 98888-7777',
                labelStyle: TextStyle(color: subtextColor),
                hintStyle: TextStyle(color: hintColor),
                filled: true,
                fillColor: inputFill,
                prefixIcon: Icon(Icons.phone_outlined, color: subtextColor),
                border: inputBorder,
                enabledBorder: inputBorder,
              ),
              validator: (v) => (v == null || v.replaceAll(RegExp(r'\D'), '').length < 10) ? 'Informe seu WhatsApp com DDD' : null,
            ),
            const SizedBox(height: 12),

            // CPF
            TextFormField(
              controller: _cpfCtrl,
              keyboardType: TextInputType.number,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                labelText: 'CPF (para nota e cadastro)',
                hintText: '000.000.000-00',
                labelStyle: TextStyle(color: subtextColor),
                hintStyle: TextStyle(color: hintColor),
                filled: true,
                fillColor: inputFill,
                prefixIcon: Icon(Icons.badge_outlined, color: subtextColor),
                border: inputBorder,
                enabledBorder: inputBorder,
              ),
              validator: (v) {
                if (_paymentMethod == 'PIX') return null;
                if (_cardCpfCtrl.text.trim().isEmpty) {
                  final clean = (v ?? '').replaceAll(RegExp(r'\D'), '');
                  if (clean.length < 11) return 'Informe o CPF';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Método de Pagamento
            Text('Forma de Pagamento', style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.bold)),
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
                        color: _paymentMethod == 'PIX' ? MetaColors.emerald.withValues(alpha: 0.15) : inputFill,
                        border: Border.all(
                          color: _paymentMethod == 'PIX'
                              ? MetaColors.emerald
                              : (isDark ? Colors.transparent : const Color(0xFFE2E8F0)),
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.pix_rounded, color: _paymentMethod == 'PIX' ? MetaColors.emerald : subtextColor, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Pix (Instantâneo)',
                            style: TextStyle(
                              color: _paymentMethod == 'PIX' ? (isDark ? Colors.white : MetaColors.emerald) : subtextColor,
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
                        color: _paymentMethod == 'CREDIT_CARD' ? MetaColors.emerald.withValues(alpha: 0.15) : inputFill,
                        border: Border.all(
                          color: _paymentMethod == 'CREDIT_CARD'
                              ? MetaColors.emerald
                              : (isDark ? Colors.transparent : const Color(0xFFE2E8F0)),
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.credit_card, color: _paymentMethod == 'CREDIT_CARD' ? MetaColors.emerald : subtextColor, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Cartão',
                            style: TextStyle(
                              color: _paymentMethod == 'CREDIT_CARD' ? (isDark ? Colors.white : MetaColors.emerald) : subtextColor,
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

            if (_paymentMethod == 'CREDIT_CARD') ...[
              const SizedBox(height: 20),
              Row(
                children: [
                  const Icon(Icons.credit_card_rounded, color: MetaColors.emerald, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Dados do Cartão de Crédito',
                    style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Número do Cartão
              TextFormField(
                controller: _cardNumberCtrl,
                keyboardType: TextInputType.number,
                style: TextStyle(color: textColor),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  _CardNumberInputFormatter(),
                ],
                decoration: InputDecoration(
                  labelText: 'Número do Cartão',
                  hintText: '0000 0000 0000 0000',
                  labelStyle: TextStyle(color: subtextColor),
                  hintStyle: TextStyle(color: hintColor),
                  filled: true,
                  fillColor: inputFill,
                  prefixIcon: Icon(Icons.payment_rounded, color: subtextColor),
                  border: inputBorder,
                  enabledBorder: inputBorder,
                ),
                validator: (v) {
                  if (_paymentMethod != 'CREDIT_CARD') return null;
                  final clean = (v ?? '').replaceAll(RegExp(r'\D'), '');
                  if (clean.length < 13 || clean.length > 19) {
                    return 'Número de cartão inválido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Nome impresso no Cartão
              TextFormField(
                controller: _cardHolderCtrl,
                textCapitalization: TextCapitalization.characters,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: 'Nome do Titular (como no cartão)',
                  hintText: 'NOME C SOBRENOME',
                  labelStyle: TextStyle(color: subtextColor),
                  hintStyle: TextStyle(color: hintColor),
                  filled: true,
                  fillColor: inputFill,
                  prefixIcon: Icon(Icons.person_pin_outlined, color: subtextColor),
                  border: inputBorder,
                  enabledBorder: inputBorder,
                ),
                validator: (v) {
                  if (_paymentMethod != 'CREDIT_CARD') return null;
                  if (v == null || v.trim().length < 3) {
                    return 'Informe o nome impresso no cartão';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Validade e CVV
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _cardExpiryCtrl,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: textColor),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        _CardExpiryInputFormatter(),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Validade',
                        hintText: 'MM/AA',
                        labelStyle: TextStyle(color: subtextColor),
                        hintStyle: TextStyle(color: hintColor),
                        filled: true,
                        fillColor: inputFill,
                        prefixIcon: Icon(Icons.calendar_month_outlined, color: subtextColor),
                        border: inputBorder,
                        enabledBorder: inputBorder,
                      ),
                      validator: (v) {
                        if (_paymentMethod != 'CREDIT_CARD') return null;
                        final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
                        if (digits.length < 4) return 'Informe MM/AA (ex: 05/34)';
                        final month = int.tryParse(digits.substring(0, 2));
                        if (month == null || month < 1 || month > 12) return 'Mês inválido (01 a 12)';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _cardCcvCtrl,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: textColor),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                      decoration: InputDecoration(
                        labelText: 'CVV',
                        hintText: '123',
                        labelStyle: TextStyle(color: subtextColor),
                        hintStyle: TextStyle(color: hintColor),
                        filled: true,
                        fillColor: inputFill,
                        prefixIcon: Icon(Icons.lock_outline, color: subtextColor),
                        border: inputBorder,
                        enabledBorder: inputBorder,
                      ),
                      validator: (v) {
                        if (_paymentMethod != 'CREDIT_CARD') return null;
                        if (v == null || v.trim().length < 3) return 'CVV inválido';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // CPF do Titular
              TextFormField(
                controller: _cardCpfCtrl,
                keyboardType: TextInputType.number,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: 'CPF do Titular do Cartão',
                  hintText: 'Deixe em branco se for o mesmo CPF acima',
                  labelStyle: TextStyle(color: subtextColor),
                  hintStyle: TextStyle(color: hintColor),
                  filled: true,
                  fillColor: inputFill,
                  prefixIcon: Icon(Icons.badge_outlined, color: subtextColor),
                  border: inputBorder,
                  enabledBorder: inputBorder,
                ),
                validator: (v) {
                  if (_paymentMethod != 'CREDIT_CARD') return null;
                  final holderCpf = (v != null && v.trim().isNotEmpty) ? v : _cpfCtrl.text;
                  final clean = holderCpf.replaceAll(RegExp(r'\D'), '');
                  if (clean.length < 11) {
                    return 'Informe o CPF do titular do cartão';
                  }
                  return null;
                },
              ),
            ].animate().fadeIn(duration: 300.ms).slideY(begin: 0.08, end: 0),

            const SizedBox(height: 24),

            if (_checkoutError != null) ...[
              Builder(builder: (context) {
                final isWaitlist = _checkoutError!.toLowerCase().contains('vagas') ||
                    _checkoutError!.toLowerCase().contains('esgotad');
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isWaitlist
                        ? Colors.amber.withValues(alpha: 0.12)
                        : Colors.redAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isWaitlist
                          ? Colors.amber.withValues(alpha: 0.45)
                          : Colors.redAccent.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isWaitlist
                                ? Icons.hourglass_top_rounded
                                : Icons.error_outline_rounded,
                            color: isWaitlist ? Colors.amber : Colors.redAccent,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isWaitlist
                                  ? 'Vagas Temporariamente Esgotadas'
                                  : 'Atenção no Pagamento',
                              style: TextStyle(
                                color: isWaitlist ? Colors.amber : Colors.redAccent,
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _checkoutError!,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                      ),
                      if (isWaitlist) ...[
                        const SizedBox(height: 14),
                        SquircleButton(
                          label: 'Falar no WhatsApp (Lista de Espera)',
                          icon: Icons.chat_bubble_outline,
                          isPrimary: false,
                          onPressed: () {
                            final msg = 'Olá, professor(a) ${widget.trainerName}! Vi o plano "${widget.plan.name}", mas notei que as vagas estão esgotadas no momento. Gostaria de entrar na lista de espera para ser avisado assim que abrir uma vaga! 💪';
                            _shareOnWhatsapp(msg);
                          },
                        ),
                      ],
                    ],
                  ),
                ).animate().fadeIn(duration: 250.ms);
              }),
            ],

            SquircleButton(
              label: _isSubmitting
                  ? (_paymentMethod == 'CREDIT_CARD' ? 'Processando Cartão...' : 'Gerando Cobrança...')
                  : (_paymentMethod == 'CREDIT_CARD'
                      ? 'Pagar R\$ ${widget.plan.price.toStringAsFixed(2).replaceAll('.', ',')} no Cartão'
                      : 'Confirmar e Pagar com Pix'),
              icon: Icons.shield_outlined,
              isPrimary: true,
              onPressed: _isSubmitting ? null : _processPayment,
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                '🔒 Pagamento processado com segurança via Asaas Gateway',
                style: TextStyle(color: subtextColor, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessCardStep(bool isDark) {
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtextColor = isDark ? MetaColors.textSecondary : MetaColors.lightTextSecondary;
    final cardBg = isDark ? MetaColors.background : const Color(0xFFF8FAFC);
    final cardBorder = Border.all(color: isDark ? MetaColors.border : const Color(0xFFE2E8F0));

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle pill
          Center(
            child: Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Emoji celebração em movimento
          const Center(
            child: Text('🎉', style: TextStyle(fontSize: 48)),
          )
              .animate()
              .scale(duration: 500.ms, curve: Curves.easeOutBack)
              .shake(delay: 450.ms, duration: 600.ms),

          const SizedBox(height: 10),

          // Título principal
          Center(
            child: Text(
              'Assinatura Concluída com Sucesso!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: textColor,
              ),
            ),
          ).animate().fadeIn(duration: 350.ms, delay: 100.ms).slideY(begin: 0.1, end: 0),

          const SizedBox(height: 6),

          // Subtítulo
          Center(
            child: Text(
              '${widget.plan.name} · ${widget.trainerName}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: subtextColor,
              ),
            ),
          ).animate().fadeIn(duration: 350.ms, delay: 150.ms),

          const SizedBox(height: 24),

          // Métricas em Cards One UI 7 (Padrão do Sistema)
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: cardBorder,
                  ),
                  child: Column(
                    children: [
                      Text(
                        'VALOR',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: subtextColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'R\$ ${widget.plan.price.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: cardBorder,
                  ),
                  child: Column(
                    children: [
                      Text(
                        'STATUS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: subtextColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Aprovado',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: MetaColors.emerald,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: cardBorder,
                  ),
                  child: Column(
                    children: [
                      Text(
                        'ACESSO',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: subtextColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Imediato ⚡',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ).animate().fadeIn(duration: 400.ms, delay: 200.ms).slideY(begin: 0.15, end: 0),

          const SizedBox(height: 14),

          // Banner de Status / Matrícula (Estilo Streak One UI)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              children: [
                const Text('🔥', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Matrícula Ativa: Acesso Imediato!',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: textColor,
                        ),
                      ),
                      Text(
                        'Vínculo criado com ${widget.trainerName}. Você já pode entrar e fazer sua anamnese.',
                        style: TextStyle(
                          fontSize: 12,
                          color: subtextColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 280.ms).slideY(begin: 0.15, end: 0),

          const SizedBox(height: 24),

          // Botão 1: Compartilhar no WhatsApp do Treinador (Padrão Screenshot)
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () {
                _shareOnWhatsapp(
                  'Olá, ${widget.trainerName}! Acabei de assinar o plano ${widget.plan.name} pelo Mr. Coach. Meu e-mail de acesso é ${_emailCtrl.text.trim()}!',
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: MetaColors.emerald,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.send_rounded, size: 20),
              label: Text(
                'Compartilhar no WhatsApp de ${widget.trainerName}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 350.ms).scale(begin: const Offset(0.96, 0.96), end: const Offset(1, 1)),

          const SizedBox(height: 12),

          // Botão 2: Concluir e Acessar o App
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context); // Fechar modal
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LoginScreen(
                      initialRole: 'client',
                      initialEmail: _emailCtrl.text.trim(),
                    ),
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: MetaColors.emerald,
                side: const BorderSide(color: MetaColors.emerald, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
              label: const Text(
                'Concluir e Entrar no App',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 420.ms),
        ],
      ),
    );
  }

  Widget _buildSuccessPixStep(bool isDark) {
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtextColor = isDark ? MetaColors.textSecondary : MetaColors.lightTextSecondary;
    final cardBg = isDark ? MetaColors.background : const Color(0xFFF8FAFC);
    final cardBorder = Border.all(color: isDark ? MetaColors.border : const Color(0xFFE2E8F0));
    final pixBoxBg = isDark ? MetaColors.surfaceHighlight : const Color(0xFFF1F5F9);
    final pixBoxBorder = Border.all(color: isDark ? Colors.white12 : const Color(0xFFCBD5E1));

    final res = _checkoutResult!;
    final pixCode = res.pixCopyPaste ?? '';

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle pill
          Center(
            child: Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Ícone animado
          const Center(
            child: Text('⚡', style: TextStyle(fontSize: 48)),
          )
              .animate()
              .scale(duration: 500.ms, curve: Curves.easeOutBack)
              .shake(delay: 450.ms, duration: 600.ms),

          const SizedBox(height: 10),

          Center(
            child: Text(
              'Cobrança Pix Gerada com Sucesso!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: textColor,
              ),
            ),
          ).animate().fadeIn(duration: 350.ms, delay: 100.ms).slideY(begin: 0.1, end: 0),

          const SizedBox(height: 6),

          Center(
            child: Text(
              '${widget.plan.name} · ${widget.trainerName}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: subtextColor,
              ),
            ),
          ).animate().fadeIn(duration: 350.ms, delay: 150.ms),

          const SizedBox(height: 24),

          // Métricas em Cards One UI 7
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: cardBorder,
                  ),
                  child: Column(
                    children: [
                      Text(
                        'VALOR',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: subtextColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'R\$ ${widget.plan.price.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: cardBorder,
                  ),
                  child: Column(
                    children: [
                      Text(
                        'MÉTODO',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: subtextColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Pix ⚡',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: MetaColors.emerald,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: cardBorder,
                  ),
                  child: Column(
                    children: [
                      Text(
                        'LIBERAÇÃO',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: subtextColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Automática',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ).animate().fadeIn(duration: 400.ms, delay: 200.ms).slideY(begin: 0.15, end: 0),

          const SizedBox(height: 14),

          // Banner Asaas
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: MetaColors.emerald.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: MetaColors.emerald.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              children: [
                const Text('🛡️', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Compensação Instantânea via Asaas',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: textColor,
                        ),
                      ),
                      Text(
                        'Pague no app do seu banco com o código abaixo. O acesso é liberado em segundos.',
                        style: TextStyle(
                          fontSize: 12,
                          color: subtextColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 280.ms).slideY(begin: 0.15, end: 0),

          const SizedBox(height: 18),

          // Código Pix Copia e Cola
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: pixBoxBg,
              borderRadius: BorderRadius.circular(16),
              border: pixBoxBorder,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.pix_rounded, color: MetaColors.emerald, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Código Pix Copia e Cola:',
                      style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  pixCode,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: subtextColor, fontSize: 11, fontFamily: 'monospace'),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () => _copyPixCode(pixCode),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MetaColors.emerald,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('COPIAR CÓDIGO PIX', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 340.ms),

          const SizedBox(height: 20),

          // Botão WhatsApp se disponível
          if (widget.trainerWhatsapp != null && widget.trainerWhatsapp!.trim().isNotEmpty) ...[
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () {
                  _shareOnWhatsapp(
                    'Olá, ${widget.trainerName}! Acabei de gerar o Pix do plano ${widget.plan.name} pelo Mr. Coach. Meu e-mail é ${_emailCtrl.text.trim()}!',
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: MetaColors.emerald,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.send_rounded, size: 20),
                label: Text(
                  'Avisar no WhatsApp de ${widget.trainerName}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ).animate().fadeIn(duration: 400.ms, delay: 400.ms),
            const SizedBox(height: 12),
          ],

          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: textColor,
                side: BorderSide(color: isDark ? Colors.white24 : const Color(0xFFCBD5E1), width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
              label: const Text(
                'Concluir e Sair',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 450.ms),
        ],
      ),
    );
  }
}

/// Formata a validade do cartão no padrão MM/AA
class _CardExpiryInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (text.length > 4) return oldValue;

    // Se o usuário está apagando e o caractere anterior era a barra
    if (oldValue.text.length > newValue.text.length &&
        oldValue.text.endsWith('/') &&
        text.isNotEmpty) {
      text = text.substring(0, text.length - 1);
    }

    // Se primeiro dígito for > 1 (ex: digitou '5'), formata para '05/'
    if (text.length == 1 && int.tryParse(text) != null && int.parse(text) > 1) {
      text = '0$text';
    }

    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      if (i == 2) buffer.write('/');
      buffer.write(text[i]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Formata o número do cartão com espaçamento a cada 4 dígitos
class _CardNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (text.length > 16) return oldValue;
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(text[i]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
