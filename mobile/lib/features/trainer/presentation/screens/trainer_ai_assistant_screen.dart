import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/meta_components.dart';
import '../../../../core/utils/pwa_navigation_state.dart';
import '../../../../models/subscription_model.dart';
import '../../../../services/subscription_service.dart';
import '../../../subscription/subscription_screen.dart';
import 'whatsapp_connection_screen.dart';

/// Cockpit One UI 7 do Consultor Ativo IA no WhatsApp.
///
/// Interface ergonômica, 100% alinhada ao Design System Meta / One UI 7:
/// - Header polido com badge balanceado sem quebras de linha estranhas
/// - Cartão interativo de status do WhatsApp com chevron de navegação
/// - Lista de comandos de Triagem com alinhamento pixel-perfect (grid de badges fixos)
/// - Motor Biomecânico Gemini 2.5 Flash com badges de proteção e guardrails
/// - Telemetria de impacto em cards modulares de alto contraste
class TrainerAiAssistantScreen extends StatefulWidget {
  const TrainerAiAssistantScreen({super.key});

  @override
  State<TrainerAiAssistantScreen> createState() => _TrainerAiAssistantScreenState();
}

class _TrainerAiAssistantScreenState extends State<TrainerAiAssistantScreen> {
  bool _isLoading = true;
  bool _isWhatsAppConnected = false;
  MySubscriptionModel? _subscription;
  Map<String, dynamic>? _telemetry;
  final TextEditingController _simulatorController = TextEditingController();
  bool _isSimulating = false;
  Map<String, dynamic>? _simulationResult;

  @override
  void initState() {
    super.initState();
    PwaNavigationState.saveActiveSubscreen('ai_assistant');
    _loadData();
  }

  @override
  void dispose() {
    PwaNavigationState.clearActiveSubscreen();
    _simulatorController.dispose();
    super.dispose();
  }

  Future<void> _runSimulation(String question) async {
    if (question.trim().isEmpty) return;
    setState(() {
      _isSimulating = true;
      _simulatorController.text = question;
    });

    try {
      final token = Supabase.instance.client.auth.currentSession?.accessToken;
      final res = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/whatsapp/simulate'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'question': question}),
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200 && mounted) {
        setState(() {
          _simulationResult = jsonDecode(res.body);
          _isSimulating = false;
        });
      } else {
        if (mounted) {
          setState(() => _isSimulating = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Falha ao simular: ${res.statusCode}'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSimulating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro de conexão ao simular: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final subFuture = SubscriptionService.getMySubscription();
      final statusFuture = _fetchWhatsAppStatus();
      final telemetryFuture = _fetchTelemetry();

      final results = await Future.wait([subFuture, statusFuture, telemetryFuture]);
      if (mounted) {
        setState(() {
          _subscription = results[0] as MySubscriptionModel?;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchWhatsAppStatus() async {
    try {
      final token = Supabase.instance.client.auth.currentSession?.accessToken;
      if (token == null) return;

      final res = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/whatsapp/status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final state = (data['state'] ?? data['status'] ?? '').toString().toLowerCase();
        if (mounted) {
          setState(() {
            _isWhatsAppConnected = state == 'open' || state == 'connected';
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchTelemetry() async {
    try {
      final token = Supabase.instance.client.auth.currentSession?.accessToken;
      if (token == null) return;

      final res = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/whatsapp/telemetry'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200 && mounted) {
        setState(() {
          _telemetry = jsonDecode(res.body);
        });
      }
    } catch (_) {}
  }

  bool get _hasAiActive {
    if (_subscription == null) return false;
    final pid = _subscription!.planId.toLowerCase();
    final name = _subscription!.planName.toLowerCase();
    if (pid == 'starter' || name.contains('starter')) return false;
    return pid.contains('pro') ||
        pid.contains('elite') ||
        pid.contains('studio') ||
        name.contains('pro') ||
        name.contains('elite') ||
        name.contains('studio');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = MetaColors.isDark(context);

    return Scaffold(
      backgroundColor: MetaColors.bg(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: MetaColors.text(context), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Consultor Ativo IA',
          style: TextStyle(
            color: MetaColors.text(context),
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: MetaColors.text(context), size: 22),
            tooltip: 'Atualizar Diagnóstico',
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: MetaColors.emerald),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              color: MetaColors.emerald,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Hero Card One UI 7
                    _buildHeroHeader(context),
                    const SizedBox(height: 14),

                    // 2. Status Interativo do WhatsApp (Click-to-Manage)
                    _buildConnectionStatusBar(context),
                    const SizedBox(height: 18),

                    // 3. Triagem de Custo Zero (Comandos Alinhados)
                    _buildZeroCostSection(context),
                    const SizedBox(height: 18),

                    // 4. Motor Biomecânico Gemini 2.5 Flash
                    _buildAiEngineSection(context),
                    const SizedBox(height: 18),

                    // 4.1 Simulador Interativo do Robô no WhatsApp
                    _buildSimulatorSection(context),
                    const SizedBox(height: 18),

                    // 5. Telemetria Modular em Cards
                    _buildTelemetryCard(context),
                    const SizedBox(height: 24),

                    // 6. Ações Principais
                    SquircleButton(
                      label: _isWhatsAppConnected ? 'Gerenciar Conexão do WhatsApp' : 'Conectar WhatsApp Agora',
                      icon: Icons.chat_rounded,
                      isPrimary: true,
                      height: 52,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const WhatsappConnectionScreen(),
                          ),
                        ).then((_) => _loadData());
                      },
                    ),
                    const SizedBox(height: 10),
                    SquircleButton(
                      label: 'Ver Planos & Upgrades (Elite / Pro)',
                      icon: Icons.workspace_premium_outlined,
                      isPrimary: false,
                      height: 50,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SubscriptionScreen(),
                          ),
                        ).then((_) => _loadData());
                      },
                    ),
                    const SizedBox(height: 36),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeroHeader(BuildContext context) {
    final planName = _subscription?.planName ?? 'Plano Starter';
    final hasAi = _hasAiActive;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: MetaColors.card(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: hasAi ? MetaColors.emerald.withValues(alpha: 0.35) : MetaColors.cardBorder(context),
          width: 1.4,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: hasAi
                        ? [const Color(0xFF10B981), const Color(0xFF0EA5E9)]
                        : [const Color(0xFF64748B), const Color(0xFF475569)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.smart_toy_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Robô WhatsApp 24h',
                      style: TextStyle(
                        color: MetaColors.text(context),
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: hasAi
                                ? MetaColors.emerald.withValues(alpha: 0.15)
                                : Colors.amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: hasAi
                                  ? MetaColors.emerald.withValues(alpha: 0.4)
                                  : Colors.amber.withValues(alpha: 0.4),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                hasAi ? Icons.verified_rounded : Icons.shield_outlined,
                                size: 12,
                                color: hasAi ? MetaColors.emerald : Colors.amber,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                planName,
                                style: TextStyle(
                                  color: hasAi ? MetaColors.emerald : Colors.amber,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: hasAi
                                ? MetaColors.accentBlue.withValues(alpha: 0.15)
                                : MetaColors.surfaceHighlight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            hasAi ? 'IA 24h Liberada' : 'Triagem Gratuita',
                            style: TextStyle(
                              color: hasAi ? MetaColors.accentBlue : MetaColors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            hasAi
                ? 'Seus alunos contam com atendimento contínuo para tirar dúvidas de postura, cadência e substituição de aparelhos direto pelo seu WhatsApp.'
                : 'O seu plano Starter inclui todas as automações de custo zero (envio de fichas e streak). Para liberar o consultor biomecânico inteligente 24h, faça upgrade para os planos Pro, Elite Coach ou Studio.',
            style: TextStyle(
              color: MetaColors.subtext(context),
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionStatusBar(BuildContext context) {
    final connected = _isWhatsAppConnected;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const WhatsappConnectionScreen(),
            ),
          ).then((_) => _loadData());
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: connected
                ? MetaColors.emerald.withValues(alpha: 0.12)
                : AppColors.warning.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: connected
                  ? MetaColors.emerald.withValues(alpha: 0.4)
                  : AppColors.warning.withValues(alpha: 0.4),
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: connected ? MetaColors.emerald : AppColors.warning,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (connected ? MetaColors.emerald : AppColors.warning).withValues(alpha: 0.5),
                      blurRadius: 6,
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
                      connected ? 'WhatsApp Conectado e Operacional' : 'WhatsApp Desconectado',
                      style: TextStyle(
                        color: connected ? MetaColors.emerald : AppColors.warning,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      connected ? 'Toque para gerenciar ou disparar teste' : 'Toque para parear seu QR Code / Código',
                      style: TextStyle(
                        color: MetaColors.subtext(context),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: connected ? MetaColors.emerald : AppColors.warning,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildZeroCostSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: MetaColors.card(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: MetaColors.cardBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: MetaColors.emerald.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.flash_on_rounded, color: MetaColors.emerald, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Triagem de Custo Zero',
                      style: TextStyle(
                        color: MetaColors.text(context),
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Text(
                      'Respostas instantâneas sem gastar tokens de IA',
                      style: TextStyle(
                        color: MetaColors.subtext(context),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: MetaColors.emerald.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '0 Tokens',
                  style: TextStyle(
                    color: MetaColors.emerald,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Comandos rápidos disponíveis para todos os seus alunos em qualquer plano:',
            style: TextStyle(color: MetaColors.textSecondary, fontSize: 12.5),
          ),
          const SizedBox(height: 12),
          _buildCommandCard(
            context,
            badge: '1',
            commandLabel: '1 ou treino',
            title: 'Ficha de Treino Ativa',
            description: 'Envia o resumo da ficha completa com exercícios, séries e descanso.',
          ),
          const SizedBox(height: 8),
          _buildCommandCard(
            context,
            badge: '2',
            commandLabel: '2 ou streak',
            title: 'Ofensiva & Consistência',
            description: 'Informa os dias seguidos de treino do aluno (Streak 🔥).',
          ),
          const SizedBox(height: 8),
          _buildCommandCard(
            context,
            badge: '3',
            commandLabel: '3 ou app',
            title: 'Acesso Direto ao App',
            description: 'Envia o link direto seguro para o aluno acessar a plataforma.',
          ),
          const SizedBox(height: 8),
          _buildCommandCard(
            context,
            badge: '0',
            commandLabel: 'oi, ola ou menu',
            title: 'Menu de Opções Imediato',
            description: 'Recepciona o aluno e exibe as opções de atendimento automático.',
          ),
        ],
      ),
    );
  }

  Widget _buildCommandCard(
    BuildContext context, {
    required String badge,
    required String commandLabel,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: MetaColors.highlight(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MetaColors.border.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badge Numérico de Largura Fixa para Alinhamento Perfeito
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: MetaColors.emerald.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: MetaColors.emerald.withValues(alpha: 0.4),
                width: 1,
              ),
            ),
            child: Center(
              child: Text(
                badge,
                style: const TextStyle(
                  color: MetaColors.emerald,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
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
                        title,
                        style: TextStyle(
                          color: MetaColors.text(context),
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: MetaColors.card(context),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        commandLabel,
                        style: const TextStyle(
                          color: MetaColors.emerald,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: TextStyle(
                    color: MetaColors.subtext(context),
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiEngineSection(BuildContext context) {
    final hasAi = _hasAiActive;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: MetaColors.card(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: hasAi ? const Color(0xFF6366F1).withValues(alpha: 0.4) : MetaColors.cardBorder(context),
          width: 1.3,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.psychology_rounded, color: Color(0xFF818CF8), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Motor Biomecânico Gemini',
                      style: TextStyle(
                        color: MetaColors.text(context),
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const Text(
                      'IA 24h para dúvidas técnicas de exercícios',
                      style: TextStyle(
                        color: Color(0xFF818CF8),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Quando o aluno envia perguntas abertas (ex: "como posicionar os pés no leg press?", "posso trocar o crucifixo pelo voador?"), o Gemini 2.5 Flash responde no tom do seu método:',
            style: TextStyle(color: MetaColors.subtext(context), fontSize: 12.5, height: 1.4),
          ),
          const SizedBox(height: 12),
          _buildBulletItem(context, 'Baseado estritamente na ficha prescrita por você.'),
          const SizedBox(height: 6),
          _buildBulletItem(context, 'Guardrails médicos: nunca medica e orienta procurar você em caso de dor.'),
          const SizedBox(height: 6),
          _buildBulletItem(context, 'Cota de segurança: até 15 dúvidas diárias por aluno para evitar abusos.'),
          const SizedBox(height: 6),
          _buildBulletItem(context, 'Liberado para: Personal Pro, Elite Coach e Studio.'),
        ],
      ),
    );
  }

  Widget _buildBulletItem(BuildContext context, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(Icons.check_circle_rounded, color: MetaColors.emerald, size: 15),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: MetaColors.text(context), fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildSimulatorSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: MetaColors.card(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: MetaColors.emerald.withValues(alpha: 0.35),
          width: 1.3,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: MetaColors.emerald.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.science_rounded, color: MetaColors.emerald, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Simulador do Robô no WhatsApp',
                      style: TextStyle(
                        color: MetaColors.text(context),
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Text(
                      'Teste as respostas em tempo real como se fosse seu aluno',
                      style: TextStyle(
                        color: MetaColors.subtext(context),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Testes rápidos de 1 toque:',
            style: TextStyle(color: MetaColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildQuickTestChip(context, '📋 1 - Treino', '1'),
                const SizedBox(width: 8),
                _buildQuickTestChip(context, '🔥 2 - Streak', '2'),
                const SizedBox(width: 8),
                _buildQuickTestChip(context, '💡 Substituir Peito', 'Posso trocar supino por peck deck?'),
                const SizedBox(width: 8),
                _buildQuickTestChip(context, '⚠️ Alerta de Dor', 'Estou sentindo muita dor no joelho'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _simulatorController,
                  style: TextStyle(color: MetaColors.text(context), fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Digite uma mensagem de teste...',
                    hintStyle: TextStyle(color: MetaColors.subtext(context), fontSize: 12.5),
                    filled: true,
                    fillColor: MetaColors.highlight(context),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: MetaColors.border.withValues(alpha: 0.5)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: MetaColors.border.withValues(alpha: 0.5)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: MetaColors.emerald, width: 1.5),
                    ),
                  ),
                  onSubmitted: _runSimulation,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: const BoxDecoration(
                  color: MetaColors.emerald,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: _isSimulating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  onPressed: _isSimulating
                      ? null
                      : () => _runSimulation(_simulatorController.text),
                ),
              ),
            ],
          ),
          if (_simulationResult != null) ...[
            const SizedBox(height: 14),
            _buildSimulationBubble(context),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickTestChip(BuildContext context, String label, String query) {
    return ActionChip(
      label: Text(
        label,
        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
      ),
      backgroundColor: MetaColors.highlight(context),
      side: BorderSide(color: MetaColors.border.withValues(alpha: 0.6)),
      onPressed: _isSimulating ? null : () => _runSimulation(query),
    );
  }

  Widget _buildSimulationBubble(BuildContext context) {
    final reply = _simulationResult?['reply'] ?? '';
    final cost = _simulationResult?['cost_type'] ?? 'free';
    final tokens = _simulationResult?['tokens_used'] ?? 0;
    final isAlert = _simulationResult?['is_alert'] == true;
    final isFree = cost == 'free';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAlert
              ? Colors.amber.withValues(alpha: 0.6)
              : (isFree ? MetaColors.emerald.withValues(alpha: 0.4) : const Color(0xFF6366F1).withValues(alpha: 0.4)),
          width: 1.2,
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
                  const Icon(Icons.chat_bubble_rounded, size: 14, color: Color(0xFF25D366)),
                  const SizedBox(width: 6),
                  const Text(
                    'Resposta do Robô no WhatsApp:',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: isAlert
                      ? Colors.amber.withValues(alpha: 0.2)
                      : (isFree ? MetaColors.emerald.withValues(alpha: 0.2) : const Color(0xFF6366F1).withValues(alpha: 0.2)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isAlert
                      ? '⚠️ Alerta de Dor'
                      : (isFree ? '⚡ Custo Zero (0 tokens)' : '🧠 IA Gemini ($tokens tokens)'),
                  style: TextStyle(
                    color: isAlert
                        ? Colors.amber
                        : (isFree ? MetaColors.emerald : const Color(0xFF818CF8)),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SelectableText(
            reply,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryCard(BuildContext context) {
    final total = _telemetry?['total_interactions'] ?? 0;
    final students = _telemetry?['unique_students'] ?? 0;
    final hours = _telemetry?['hours_saved'] ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: MetaColors.card(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: MetaColors.cardBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: MetaColors.emerald.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.insights_rounded, color: MetaColors.emerald, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Impacto do Robô no Mês',
                  style: TextStyle(
                    color: MetaColors.text(context),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  context,
                  label: 'Tempo Poupado',
                  value: '${hours}h',
                  color: MetaColors.emerald,
                  icon: Icons.timer_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricTile(
                  context,
                  label: 'Alunos Atendidos',
                  value: '$students',
                  color: const Color(0xFF6366F1),
                  icon: Icons.people_outline_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricTile(
                  context,
                  label: 'Mensagens',
                  value: '$total',
                  color: Colors.amber,
                  icon: Icons.chat_bubble_outline_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(
    BuildContext context, {
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: MetaColors.highlight(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MetaColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: MetaColors.subtext(context),
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
