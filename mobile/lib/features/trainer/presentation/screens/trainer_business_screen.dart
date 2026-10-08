// ignore_for_file: unused_element, unused_local_variable, unused_field, override_on_non_overriding_member, use_build_context_synchronously
import 'package:flutter/material.dart';
import '../../../../services/auth_service.dart';
import 'package:flutter/services.dart';

import '../../../../core/widgets/meta_components.dart';
import '../../../subscription/subscription_screen.dart';
import 'whatsapp_connection_screen.dart';
import 'trainer_profile_setup_screen.dart';

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
      gradient: LinearGradient(
        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    _BusinessTip(
      title: 'Divulgue seus treinos e planos',
      description:
          'Compartilhe links diretos da sua Vitrine Pública no Instagram e WhatsApp para captar alunos com checkout instantâneo.',
      gradient: LinearGradient(
        colors: [Color(0xFFEC4899), Color(0xFFF43F5E)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    _BusinessTip(
      title: 'Automatize mensagens no WhatsApp',
      description:
          'Envie lembretes de treinos e boas-vindas automáticas para manter o engajamento e a aderência aos treinos alta.',
      gradient: LinearGradient(
        colors: [Color(0xFF10B981), Color(0xFF06B6D4)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    _BusinessTip(
      title: 'Use a IA para dobrar sua retenção',
      description:
          'O assistente de IA responde dúvidas biomecânicas dos alunos 24h por dia com base na sua metodologia de treino.',
      gradient: LinearGradient(
        colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
  ];

  // Itens da seção "Expanda sua empresa"
  final List<_BusinessToolItem> _toolItems = const [
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
  ];

  void _showTipModal(_BusinessTip tip) {
    showModalBottomSheet(
      context: context,
      backgroundColor: MetaColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
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
                    color: MetaColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                height: 120,
                decoration: BoxDecoration(
                  gradient: tip.gradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                tip.title,
                style: const TextStyle(
                  color: MetaColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                tip.description,
                style: const TextStyle(
                  color: MetaColors.textSecondary,
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
      case _ToolType.subscription:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
        );
        break;
      case _ToolType.aiAssistant:
        _showAiAssistantModal();
        break;
      case _ToolType.publicShowcase:
        if (!_hasCref) {
          _showCrefLockedModal();
        } else {
          _showPublicShowcaseModal();
        }
        break;
      case _ToolType.whatsappIntegration:
        _showWhatsAppIntegrationModal();
        break;
    }
  }

  void _showCrefLockedModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: MetaColors.surface,
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
              const Text(
                'Acesso Bloqueado',
                style: TextStyle(color: MetaColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Sua Vitrine Pública não pode ser ativada porque seu CREF/Registro Profissional ainda não foi preenchido.',
                textAlign: TextAlign.center,
                style: TextStyle(color: MetaColors.textSecondary, fontSize: 15),
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
      backgroundColor: MetaColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
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
                    color: MetaColors.border,
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
                      color: MetaColors.surfaceHighlight,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: MetaColors.border),
                    ),
                    child: const Icon(
                      Icons.workspace_premium_outlined,
                      color: MetaColors.emerald,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Assinatura Mr. Coach',
                          style: TextStyle(
                            color: MetaColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Potencialize sua consultoria fitness',
                          style: TextStyle(
                            color: MetaColors.textSecondary,
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
      backgroundColor: MetaColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
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
                    color: MetaColors.border,
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
                      color: MetaColors.surfaceHighlight,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: MetaColors.border),
                    ),
                    child: const Icon(
                      Icons.smart_toy_outlined,
                      color: MetaColors.accentBlue,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Consultor Ativo IA',
                          style: TextStyle(
                            color: MetaColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Seu assistente virtual autônomo',
                          style: TextStyle(
                            color: MetaColors.textSecondary,
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
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: MetaColors.surfaceHighlight,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: MetaColors.border),
                ),
                child: const Text(
                  'O Consultor Ativo analisa o histórico de execução de treinos dos seus alunos e envia feedbacks e respostas automáticas em tempo real para dúvidas sobre postura e intensidade.',
                  style: TextStyle(
                    color: MetaColors.textPrimary,
                    fontSize: 13.5,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SquircleButton(
                label: 'Concluir',
                isPrimary: true,
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPublicShowcaseModal() {
    final showcaseUrl = 'https://shaipados.com/#/prof/${Uri.encodeComponent(_username ?? '')}';
    showModalBottomSheet(
      context: context,
      backgroundColor: MetaColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
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
                    color: MetaColors.border,
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
                      color: MetaColors.surfaceHighlight,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: MetaColors.border),
                    ),
                    child: const Icon(
                      Icons.storefront_outlined,
                      color: Colors.amber,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Minha Vitrine Pública',
                          style: TextStyle(
                            color: MetaColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Página de conversão de alunos',
                          style: TextStyle(
                            color: MetaColors.textSecondary,
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
                  color: MetaColors.surfaceHighlight,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: MetaColors.border),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        showcaseUrl.replaceFirst('https://', ''),
                        style: TextStyle(
                          color: MetaColors.textPrimary,
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
                          const SnackBar(
                            backgroundColor: MetaColors.surfaceHighlight,
                            content: Text(
                              'Link copiado para a área de transferência!',
                              style: TextStyle(color: MetaColors.textPrimary),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
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

  void _showWhatsAppIntegrationModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: MetaColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
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
                    color: MetaColors.border,
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
                      color: MetaColors.surfaceHighlight,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: MetaColors.border),
                    ),
                    child: const Icon(
                      Icons.chat_outlined,
                      color: MetaColors.emerald,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Conexão WhatsApp',
                          style: TextStyle(
                            color: MetaColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Disparos inteligentes para seus alunos',
                          style: TextStyle(
                            color: MetaColors.textSecondary,
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
            style: const TextStyle(
              color: MetaColors.textPrimary,
              fontSize: 13.5,
            ),
          ),
        ),
      ],
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
                  const Text(
                    'Perfil Público Incompleto',
                    style: TextStyle(
                      color: MetaColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Sua vitrine pública ainda não tem informações suficientes para atrair alunos. Configure sua bio, especialidades e seu nome de usuário.',
                style: TextStyle(color: MetaColors.textSecondary, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MetaColors.surfaceHighlight,
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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: MetaColors.background,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Topo (Título Geral M3)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(
                  top: topPadding + 16,
                  left: 20,
                  right: 20,
                  bottom: 20,
                ),
                child: const Text(
                  'Ferramentas do Personal',
                  style: TextStyle(
                    color: MetaColors.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                ),
              ),
            ),

            _buildIncompleteProfileBanner(),
            // Seção 1: "Como" (Dicas de Negócio em Cards Horizontais)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: const Text(
                  'Como',
                  style: TextStyle(
                    color: MetaColors.textPrimary,
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
                height: 160,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _tips.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 14),
                  itemBuilder: (context, index) {
                    final tip = _tips[index];
                    return SizedBox(
                      width: 220,
                      child: MetaCard(
                        padding: EdgeInsets.zero,
                        borderRadius: 16.0,
                        onTap: () => _showTipModal(tip),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(15.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Metade superior: Container com gradiente vibrante e ícone de play centralizado
                              Expanded(
                                flex: 5,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: tip.gradient,
                                  ),
                                  child: Center(
                                    child: Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.35),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.play_arrow_rounded,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // Metade inferior: fundo MetaColors.surfaceHighlight com o texto
                              Container(
                                height: 68,
                                color: MetaColors.surfaceHighlight,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  tip.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: MetaColors.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    height: 1.25,
                                  ),
                                ),
                              ),
                            ],
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
                child: const Text(
                  'Expanda sua empresa',
                  style: TextStyle(
                    color: MetaColors.textPrimary,
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
                      color: MetaColors.textSecondary,
                      size: 26,
                    ),
                    title: Text(
                      item.title,
                      style: const TextStyle(
                        color: MetaColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        item.subtitle,
                        style: const TextStyle(
                          color: MetaColors.textSecondary,
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
                    const Text(
                      'from',
                      style: TextStyle(
                        color: MetaColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.science_rounded,
                          color: MetaColors.textSecondary,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Shaipados Labs',
                          style: TextStyle(
                            color: MetaColors.textSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
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
  subscription,
  aiAssistant,
  publicShowcase,
  whatsappIntegration,
}

class _BusinessTip {
  final String title;
  final String description;
  final Gradient gradient;

  const _BusinessTip({
    required this.title,
    required this.description,
    required this.gradient,
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



