// ignore_for_file: unused_element, unused_local_variable, unused_field, override_on_non_overriding_member, use_build_context_synchronously
import 'package:flutter/material.dart';
import '../../../../services/auth_service.dart';
import 'package:flutter/services.dart';

import '../../../../core/widgets/app_version_footer.dart';
import '../../../../core/widgets/meta_components.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/widgets/thematic_editorial_card.dart';
import '../../../../core/widgets/thematic_watermarks.dart';
import '../../../../core/widgets/card_style_selection_sheet.dart';
import '../../../subscription/subscription_screen.dart';
import 'whatsapp_connection_screen.dart';
import 'trainer_profile_setup_screen.dart';
import 'trainer_ai_assistant_screen.dart';
import 'trainer_wallet_screen.dart';
import 'trainer_consultancy_plans_screen.dart';
import '../../../landing/trainer_public_landing_screen.dart';

/// Aba "Ferramentas do Personal" (Vitrine B2B)
///
/// Segue a arquitetura visual do WhatsApp Business ("Ferramentas"),
/// padrão Edge-to-Edge nativo, sem AppBar artificial e sem letterboxing.
class TrainerBusinessScreen extends StatefulWidget {
  const TrainerBusinessScreen({super.key});

  @override
  State<TrainerBusinessScreen> createState() => _TrainerBusinessScreenState();
}

class _TrainerBusinessScreenState extends State<TrainerBusinessScreen> {
  bool _isProfileIncomplete = false;
  bool _hasCref = false;
  bool _isLoadingProfile = true;
  String? _username;

  @override
  void initState() {
    super.initState();
    _checkProfileStatus();
  }

  Future<void> _checkProfileStatus() async {
    try {
      final profile = await AuthService.getCurrentProfile();
      if (profile != null) {
        final bio = profile['bio'] as String?;
        final specialties = profile['specialties'] as List<dynamic>?;
        final username = profile['username'] as String?;
        final cref = profile['professional_document'] as String?;
        
        setState(() {
          _isProfileIncomplete = (bio == null || bio.trim().isEmpty) || 
                                 (specialties == null || specialties.isEmpty) ||
                                 (username == null || username.trim().isEmpty);
          _username = username?.trim();
          _hasCref = (cref != null && cref.trim().toUpperCase().startsWith('CREF'));
          _isLoadingProfile = false;
        });
      } else {
        setState(() => _isLoadingProfile = false);
      }
    } catch (e) {
      if(mounted) setState(() => _isLoadingProfile = false);
    }
  }

  // Dados dos cards de dicas ("Como")
  final List<_BusinessTip> _tips = const [
    _BusinessTip(
      title: 'Gere confiança com seu perfil',
      description:
          'Um perfil completo com sua foto profissional, bio objetiva e credenciais aumenta em até 3x a conversão de novos alunos.',
      palette: ThematicCardPalette.businessEmerald,
      watermark: ThematicWatermarkType.biomechanics,
    ),
    _BusinessTip(
      title: 'Divulgue seus treinos e planos',
      description:
          'Compartilhe links diretos da sua Vitrine Pública no Instagram e WhatsApp para captar alunos com checkout instantâneo.',
      palette: ThematicCardPalette.businessEmerald,
      watermark: ThematicWatermarkType.walletFinance,
    ),
    _BusinessTip(
      title: 'Automatize mensagens no WhatsApp',
      description:
          'Envie lembretes de treinos e boas-vindas automáticas para manter o engajamento e a aderência aos treinos alta.',
      palette: ThematicCardPalette.aiOrchid,
      watermark: ThematicWatermarkType.aiCopilot,
    ),
    _BusinessTip(
      title: 'Use a IA para dobrar sua retenção',
      description:
          'O assistente de IA responde dúvidas biomecânicas dos alunos 24h por dia com base na sua metodologia de treino.',
      palette: ThematicCardPalette.aiOrchid,
      watermark: ThematicWatermarkType.aiCopilot,
    ),
  ];

  // Itens da seção "Expanda sua empresa"
  final List<_BusinessToolItem> _toolItems = const [
    _BusinessToolItem(
      title: 'Planos de Consultoria & Preços',
      subtitle: 'Configure seus planos, fichas e valores para a Vitrine',
      icon: Icons.sell_outlined,
      type: _ToolType.consultancyPlans,
    ),
    _BusinessToolItem(
      title: 'Carteira do Personal',
      subtitle: 'Saldo, cobranças de alunos e saques via Pix',
      icon: Icons.account_balance_wallet_outlined,
      type: _ToolType.wallet,
    ),
    _BusinessToolItem(
      title: 'Assinatura Mr. Coach',
      subtitle: 'Desbloqueie recursos premium na sua consultoria',
      icon: Icons.workspace_premium_outlined,
      type: _ToolType.subscription,
    ),
    _BusinessToolItem(
      title: 'Consultor Ativo IA',
      subtitle: 'Agente inteligente para responder alunos 24h por dia',
      icon: Icons.smart_toy_outlined,
      type: _ToolType.aiAssistant,
    ),
    _BusinessToolItem(
      title: 'Minha Vitrine Pública',
      subtitle: 'Sua página de vendas de planos e treinos',
      icon: Icons.storefront_outlined,
      type: _ToolType.publicShowcase,
    ),
    _BusinessToolItem(
      title: 'Conexão WhatsApp',
      subtitle: 'Configure envios automáticos para seus alunos',
      icon: Icons.chat_outlined,
      type: _ToolType.whatsappIntegration,
    ),
    _BusinessToolItem(
      title: 'Aparência do App',
      subtitle: 'Alterne entre Modo Escuro, Modo Claro e Automático',
      icon: Icons.palette_outlined,
      type: _ToolType.themeMode,
    ),
    _BusinessToolItem(
      title: 'Estilo dos Cards (One UI 7)',
      subtitle: 'Editorial 3D, Minimalista ou Pastel Suave',
      icon: Icons.view_carousel_outlined,
      type: _ToolType.cardStyle,
    ),
  ];

  void _showTipModal(_BusinessTip tip) {
    showModalBottomSheet(
      context: context,
      backgroundColor: MetaColors.card(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final isDark = MetaColors.isDark(ctx);
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.paddingOf(ctx).bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ThematicEditorialCard(
                category: 'DICA DE ESCALABILIDADE',
                title: tip.title,
                palette: tip.palette,
                customWatermark: tip.watermark,
                minHeight: 110,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              const SizedBox(height: 18),
              Text(
                tip.title,
                style: TextStyle(
                  color: MetaColors.text(ctx),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                tip.description,
                style: TextStyle(
                  color: MetaColors.subtext(ctx),
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 24),
              SquircleButton(
                label: 'Entendido',
                isPrimary: true,
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleToolTap(_BusinessToolItem item) {
    switch (item.type) {
      case _ToolType.consultancyPlans:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TrainerConsultancyPlansScreen()),
        );
        break;
      case _ToolType.wallet:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TrainerWalletScreen()),
        );
        break;
      case _ToolType.subscription:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
        );
        break;
      case _ToolType.aiAssistant:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TrainerAiAssistantScreen()),
        );
        break;
      case _ToolType.publicShowcase:
        _showPublicShowcaseModal();
        break;
      case _ToolType.whatsappIntegration:
        _showWhatsAppIntegrationModal();
        break;
      case _ToolType.themeMode:
        _showThemeModal();
        break;
      case _ToolType.cardStyle:
        CardStyleSelectionSheet.show(context);
        break;
    }
  }

  void _showThemeModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: MetaColors.card(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return ListenableBuilder(
          listenable: ThemeController.instance,
          builder: (ctx, _) {
            final currentMode = ThemeController.instance.themeMode;

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.paddingOf(ctx).bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: MetaColors.cardBorder(ctx),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Aparência do App',
                    style: TextStyle(
                      color: MetaColors.text(ctx),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Selecione o padrão visual Meta para o aplicativo:',
                    style: TextStyle(
                      color: MetaColors.subtext(ctx),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _buildThemeOption(
                    ctx: ctx,
                    title: 'Modo Escuro',
                    subtitle: 'Visual escuro e confortável. Menor cansaço visual e economia de bateria.',
                    icon: Icons.dark_mode_rounded,
                    isSelected: currentMode == ThemeMode.dark,
                    onTap: () {
                      ThemeController.instance.setThemeMode(ThemeMode.dark);
                      Navigator.pop(ctx);
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildThemeOption(
                    ctx: ctx,
                    title: 'Modo Claro',
                    subtitle: 'Visual iluminado com alta nitidez e contraste para ambientes ensolarados.',
                    icon: Icons.light_mode_rounded,
                    isSelected: currentMode == ThemeMode.light,
                    onTap: () {
                      ThemeController.instance.setThemeMode(ThemeMode.light);
                      Navigator.pop(ctx);
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildThemeOption(
                    ctx: ctx,
                    title: 'Automático (Padrão do Aparelho)',
                    subtitle: 'Acompanha automaticamente as preferências do seu dispositivo.',
                    icon: Icons.brightness_auto_rounded,
                    isSelected: currentMode == ThemeMode.system,
                    onTap: () {
                      ThemeController.instance.setThemeMode(ThemeMode.system);
                      Navigator.pop(ctx);
                    },
                  ),
                  const SizedBox(height: 16),
                  Divider(color: MetaColors.cardBorder(ctx).withValues(alpha: 0.5)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Estilo dos Cards',
                            style: TextStyle(
                              color: MetaColors.text(ctx),
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            ThemeController.instance.cardThemeMode.label,
                            style: TextStyle(
                              color: MetaColors.subtext(ctx),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          CardStyleSelectionSheet.show(context);
                        },
                        icon: const Icon(Icons.tune_rounded, size: 16),
                        label: const Text('Alterar'),
                        style: TextButton.styleFrom(
                          foregroundColor: MetaColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildThemeOption({
    required BuildContext ctx,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? MetaColors.highlight(ctx)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? MetaColors.primaryColor(ctx)
                : MetaColors.cardBorder(ctx),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? MetaColors.primaryColor(ctx)
                  : MetaColors.subtext(ctx),
              size: 24,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: MetaColors.text(ctx),
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: MetaColors.subtext(ctx),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                color: MetaColors.primaryColor(ctx),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  void _showCrefLockedModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: MetaColors.card(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_person_rounded, color: Colors.amber, size: 48),
              const SizedBox(height: 16),
              Text(
                'Acesso Bloqueado',
                style: TextStyle(color: MetaColors.text(context), fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                'Sua Vitrine Pública não pode ser ativada porque seu CREF/Registro Profissional ainda não foi preenchido.',
                textAlign: TextAlign.center,
                style: TextStyle(color: MetaColors.subtext(context), fontSize: 15),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: SquircleButton(
                  label: 'Preencher CREF agora',
                  isPrimary: true,
                  icon: Icons.badge,
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TrainerProfileSetupScreen()),
                    ).then((_) => _checkProfileStatus());
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showSubscriptionDetailsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: MetaColors.card(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final isDark = MetaColors.isDark(ctx);
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.paddingOf(ctx).bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: MetaColors.highlight(ctx),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    child: const Icon(
                      Icons.workspace_premium_outlined,
                      color: MetaColors.emerald,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Assinatura Mr. Coach',
                          style: TextStyle(
                            color: MetaColors.text(ctx),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Potencialize sua consultoria fitness',
                          style: TextStyle(
                            color: MetaColors.subtext(ctx),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildFeatureRow(
                Icons.check_circle_outline_rounded,
                'Prescrições biomecânicas ilimitadas com IA',
              ),
              const SizedBox(height: 10),
              _buildFeatureRow(
                Icons.check_circle_outline_rounded,
                'Página Vitrine personalizada com seu link',
              ),
              const SizedBox(height: 10),
              _buildFeatureRow(
                Icons.check_circle_outline_rounded,
                'Agente de suporte aos alunos no WhatsApp 24/7',
              ),
              const SizedBox(height: 24),
              SquircleButton(
                label: 'Fechar',
                isPrimary: true,
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAiAssistantModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: MetaColors.card(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final isDark = MetaColors.isDark(ctx);
        return DraggableScrollableSheet(
          initialChildSize: 0.72,
          minChildSize: 0.5,
          maxChildSize: 0.92,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 14,
                bottom: MediaQuery.paddingOf(ctx).bottom + 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF10B981), Color(0xFF06B6D4)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.smart_toy_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Consultor Ativo IA 24h',
                              style: TextStyle(
                                color: MetaColors.text(ctx),
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Suporte autônomo aos seus alunos no WhatsApp',
                              style: TextStyle(
                                color: MetaColors.subtext(ctx),
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Card 1: Triagem Custo Zero
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: MetaColors.highlight(ctx),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: MetaColors.emerald.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'CUSTO ZERO • TODOS OS PLANOS',
                                style: TextStyle(
                                  color: MetaColors.emerald,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Comandos Rápidos Automáticos',
                          style: TextStyle(
                            color: MetaColors.text(ctx),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Seus alunos recebem respostas imediatas sem consumir cotas de IA:',
                          style: TextStyle(
                            color: MetaColors.subtext(ctx),
                            fontSize: 12.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildAiFeatureRow(Icons.description_outlined, '*1* ou *treino*', 'Envia a ficha de treino ativa do aluno na hora.'),
                        const SizedBox(height: 6),
                        _buildAiFeatureRow(Icons.local_fire_department_outlined, '*2* ou *streak*', 'Informa os dias seguidos de treino (ofensiva).'),
                        const SizedBox(height: 6),
                        _buildAiFeatureRow(Icons.open_in_browser_rounded, '*3* ou *app*', 'Envia o link direto de acesso à plataforma.'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Card 2: Consultor Biomecânico com Gemini
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: MetaColors.highlight(ctx),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6366F1).withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'IA AVANÇADA • PLANOS PRO & STUDIO',
                                style: TextStyle(
                                  color: Color(0xFF818CF8),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Dúvidas Biomecânicas e de Exercícios',
                          style: TextStyle(
                            color: MetaColors.text(ctx),
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Quando o aluno manda perguntas abertas ("como posicionar os pés no agachamento?", "posso trocar o crucifixo por voador?"), o robô responde com base na prescrição atual, com tom amigável e limite diário seguro.',
                          style: TextStyle(
                            color: MetaColors.subtext(ctx),
                            fontSize: 12.5,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.shield_outlined, color: Colors.amber, size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Guardrail médico: nunca medica e orienta procurar você em caso de dor.',
                                style: TextStyle(
                                  color: isDark ? Colors.amber.shade300 : Colors.amber.shade900,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  SquircleButton(
                    label: 'Central do WhatsApp & Telemetria',
                    isPrimary: true,
                    icon: Icons.chat_rounded,
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const WhatsappConnectionScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  SquircleButton(
                    label: 'Ver Planos & Upgrades',
                    isPrimary: false,
                    icon: Icons.workspace_premium_outlined,
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SubscriptionScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAiFeatureRow(IconData icon, String cmd, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: MetaColors.emerald),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 12, color: MetaColors.text(context)),
              children: [
                TextSpan(
                  text: '$cmd: ',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: MetaColors.emerald),
                ),
                TextSpan(
                  text: desc,
                  style: TextStyle(color: MetaColors.subtext(context)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showPublicShowcaseModal() {
    final cleanUser = (_username != null && _username!.isNotEmpty)
        ? _username!.replaceFirst(RegExp(r'^@'), '')
        : 'mrcoach';
    final showcaseUrl = 'https://shaipados.com/#/prof/${Uri.encodeComponent(cleanUser)}';
    showModalBottomSheet(
      context: context,
      backgroundColor: MetaColors.card(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final isDark = MetaColors.isDark(ctx);
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.paddingOf(ctx).bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: MetaColors.highlight(ctx),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    child: const Icon(
                      Icons.storefront_outlined,
                      color: Colors.amber,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Minha Vitrine Pública',
                          style: TextStyle(
                            color: MetaColors.text(ctx),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Página de conversão de alunos',
                          style: TextStyle(
                            color: MetaColors.subtext(ctx),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: MetaColors.highlight(ctx),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        showcaseUrl.replaceFirst('https://', ''),
                        style: TextStyle(
                          color: MetaColors.text(ctx),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 20),
                      color: MetaColors.emerald,
                      tooltip: 'Copiar link',
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(text: showcaseUrl),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
                            content: const Text(
                              'Link copiado para a área de transferência!',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                        foregroundColor: MetaColors.text(ctx),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Editar Perfil', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const TrainerProfileSetupScreen(),
                          ),
                        ).then((_) => _checkProfileStatus());
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MetaColors.emerald,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                      label: const Text('Ver Vitrine', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () {
                        Navigator.pop(ctx);
                        if (_username != null && _username!.isNotEmpty) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TrainerPublicLandingScreen(
                                username: _username!,
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SquircleButton(
                label: 'Fechar',
                isPrimary: false,
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showWhatsAppIntegrationModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: MetaColors.card(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final isDark = MetaColors.isDark(ctx);
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.paddingOf(ctx).bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: MetaColors.highlight(ctx),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    child: const Icon(
                      Icons.chat_outlined,
                      color: MetaColors.emerald,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Conexão WhatsApp',
                          style: TextStyle(
                            color: MetaColors.text(ctx),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Disparos inteligentes para seus alunos',
                          style: TextStyle(
                            color: MetaColors.subtext(ctx),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildFeatureRow(
                Icons.mark_chat_read_outlined,
                'Lembrete automático de treino pendente',
              ),
              const SizedBox(height: 10),
              _buildFeatureRow(
                Icons.mark_chat_read_outlined,
                'Envio de link de ativação com 1 clique',
              ),
              const SizedBox(height: 10),
              _buildFeatureRow(
                Icons.mark_chat_read_outlined,
                'Mensagens motivacionais de consistência',
                ),
                const SizedBox(height: 24),
                SquircleButton(
                  label: 'Concluir',
                  isPrimary: true,
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const WhatsappConnectionScreen(),
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFeatureRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: MetaColors.emerald, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: MetaColors.text(context),
              fontSize: 13.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSalesLinkCard() {
    final cleanUser = (_username != null && _username!.isNotEmpty)
        ? _username!.replaceFirst(RegExp(r'^@'), '')
        : 'mrcoach';
    final displayUrl = 'shaipados.com/#/prof/$cleanUser';
    final fullUrl = 'https://shaipados.com/#/prof/$cleanUser';

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: MetaCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: MetaColors.emerald.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.link_rounded,
                      color: MetaColors.emerald,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Link Direto da sua Vitrine B2B',
                          style: TextStyle(
                            color: MetaColors.subtext(context),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          displayUrl,
                          style: TextStyle(
                            color: MetaColors.text(context),
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Configurar @username',
                    icon: Icon(
                      Icons.tune_rounded,
                      color: MetaColors.subtext(context),
                      size: 20,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TrainerProfileSetupScreen(),
                        ),
                      ).then((_) => _checkProfileStatus());
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: SquircleButton(
                  icon: Icons.copy_rounded,
                  label: 'Copiar meu link de vendas',
                  isPrimary: true,
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: fullUrl));
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: MetaColors.emerald,
                        content: Text(
                          'Link copiado: $displayUrl',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIncompleteProfileBanner() {
    if (_isLoadingProfile || !_isProfileIncomplete) return const SliverToBoxAdapter(child: SizedBox.shrink());
    
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: MetaCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: MetaColors.emerald, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Perfil Público Incompleto',
                    style: TextStyle(
                      color: MetaColors.text(context),
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Sua vitrine pública ainda não tem informações suficientes para atrair alunos. Configure sua bio, especialidades e seu nome de usuário.',
                style: TextStyle(color: MetaColors.subtext(context), fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MetaColors.highlight(context),
                    foregroundColor: MetaColors.emerald,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    Navigator.pushNamed(context, '/trainer_profile_setup').then((_) => _checkProfileStatus());
                  },
                  child: const Text('Completar Perfil', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final isDark = MetaColors.isDark(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: MetaColors.bg(context),
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Topo (Título Geral M3 + Popover One UI)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(
                  top: topPadding + 16,
                  left: 20,
                  right: 20,
                  bottom: 20,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Ferramentas do Personal',
                      style: TextStyle(
                        color: MetaColors.text(context),
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                    OneUiPopoverMenuButton(
                      showBadgeDot: true,
                      items: [
                        OneUiPopoverItem(
                          label: 'Novidades da versão',
                          icon: Icons.new_releases_outlined,
                          showOrangeDot: true,
                          onTap: () => AppVersionFooter.showReleaseNotesModal(
                            context,
                          ),
                        ),
                        OneUiPopoverItem(
                          label: 'Alternar modo visual',
                          icon: isDark
                              ? Icons.light_mode_outlined
                              : Icons.dark_mode_outlined,
                          onTap: () => ThemeController.instance.toggleTheme(),
                        ),
                        OneUiPopoverItem(
                          label: 'Configurar Vitrine',
                          icon: Icons.storefront_outlined,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const TrainerProfileSetupScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            _buildSalesLinkCard(),
            _buildIncompleteProfileBanner(),
            // Seção 1: "Como" (Dicas de Negócio em Cards Horizontais)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Como',
                  style: TextStyle(
                    color: MetaColors.text(context),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: SizedBox(height: 12),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 165,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _tips.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 14),
                  itemBuilder: (context, index) {
                    final tip = _tips[index];
                    return SizedBox(
                      width: 230,
                      child: ThematicEditorialCard(
                        category: 'COMO ESCALAR',
                        title: tip.title,
                        palette: tip.palette,
                        customWatermark: tip.watermark,
                        minHeight: 165,
                        padding: const EdgeInsets.all(16),
                        onTap: () => _showTipModal(tip),
                        trailingBadge: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.22),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            const SliverToBoxAdapter(
              child: SizedBox(height: 32),
            ),

            // Seção 2: "Expanda sua empresa" (Listagem Vertical)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Expanda sua empresa',
                  style: TextStyle(
                    color: MetaColors.text(context),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: SizedBox(height: 8),
            ),

            // Itens de lista sem bordas ou separadores
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final item = _toolItems[index];
                  return ListTile(
                    onTap: () => _handleToolTap(item),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 6,
                    ),
                    leading: Icon(
                      item.icon,
                      color: MetaColors.subtext(context),
                      size: 26,
                    ),
                    title: Text(
                      item.title,
                      style: TextStyle(
                        color: MetaColors.text(context),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        item.subtitle,
                        style: TextStyle(
                          color: MetaColors.subtext(context),
                          fontSize: 13,
                          height: 1.3,
                        ),
                      ),
                    ),
                  );
                },
                childCount: _toolItems.length,
              ),
            ),

            // Branding Footer
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: 24, bottom: bottomPadding + 32),
                child: Column(
                  children: [
                    Text(
                      'Mr. Coach',
                      style: TextStyle(
                        color: MetaColors.subtext(context),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Plataforma para Treinadores',
                      style: TextStyle(
                        color: MetaColors.subtext(context).withValues(alpha: 0.7),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _ToolType {
  wallet,
  consultancyPlans,
  subscription,
  aiAssistant,
  publicShowcase,
  whatsappIntegration,
  themeMode,
  cardStyle,
}

class _BusinessTip {
  final String title;
  final String description;
  final ThematicCardPalette palette;
  final ThematicWatermarkType watermark;

  const _BusinessTip({
    required this.title,
    required this.description,
    required this.palette,
    required this.watermark,
  });
}

class _BusinessToolItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final _ToolType type;

  const _BusinessToolItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.type,
  });
}



