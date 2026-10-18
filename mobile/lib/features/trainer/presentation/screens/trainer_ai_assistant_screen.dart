import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/meta_components.dart';
import '../../../../models/subscription_model.dart';
import '../../../../services/subscription_service.dart';
import '../../../subscription/subscription_screen.dart';
import 'whatsapp_connection_screen.dart';

/// Cockpit One UI 7 do Consultor Ativo IA no WhatsApp.
///
/// Interface de comando do treinador para gerenciar e visualizar:
/// 1. Triagem de Custo Zero (Comandos rápidos 1, 2 e 3).
/// 2. Motor Biomecânico Gemini 2.5 Flash (IA 24h para Pro, Elite Coach e Studio).
/// 3. Status de Conexão WhatsApp e Telemetria em Tempo Real.
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

  @override
  void initState() {
    super.initState();
    _loadData();
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
      backgroundColor: MetaColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: MetaColors.text(context)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Consultor Ativo IA',
          style: TextStyle(
            color: MetaColors.text(context),
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: MetaColors.emerald),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              color: MetaColors.emerald,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeroHeader(context),
                    const SizedBox(height: 16),
                    _buildConnectionStatusBar(context),
                    const SizedBox(height: 20),
                    _buildZeroCostSection(context),
                    const SizedBox(height: 16),
                    _buildAiEngineSection(context),
                    const SizedBox(height: 20),
                    _buildTelemetryCard(context),
                    const SizedBox(height: 24),
                    SquircleButton(
                      label: 'Configurar Conexão do WhatsApp',
                      icon: Icons.chat_rounded,
                      isPrimary: true,
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
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SubscriptionScreen(),
                          ),
                        ).then((_) => _loadData());
                      },
                    ),
                    const SizedBox(height: 32),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MetaColors.card(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: hasAi ? MetaColors.emerald.withValues(alpha: 0.3) : MetaColors.cardBorder(context),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: hasAi
                        ? [const Color(0xFF10B981), const Color(0xFF06B6D4)]
                        : [const Color(0xFF64748B), const Color(0xFF475569)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.smart_toy_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Robô WhatsApp 24h',
                      style: TextStyle(
                        color: MetaColors.text(context),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: hasAi
                            ? MetaColors.emerald.withValues(alpha: 0.15)
                            : Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        hasAi
                            ? '👑 $planName • IA 24h LIBERADA'
                            : '🛡️ $planName • TRIAGEM GRATUITA',
                        style: TextStyle(
                          color: hasAi ? MetaColors.emerald : Colors.amber.shade400,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
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
              fontSize: 13.5,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionStatusBar(BuildContext context) {
    final connected = _isWhatsAppConnected;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: connected
            ? MetaColors.emerald.withValues(alpha: 0.1)
            : AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: connected
              ? MetaColors.emerald.withValues(alpha: 0.3)
              : AppColors.warning.withValues(alpha: 0.3),
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
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              connected
                  ? 'WhatsApp Conectado e Operacional'
                  : 'WhatsApp Desconectado (Aguardando Pareamento)',
              style: TextStyle(
                color: connected ? MetaColors.emerald : AppColors.warning,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Icon(
            connected ? Icons.check_circle_rounded : Icons.link_off_rounded,
            color: connected ? MetaColors.emerald : AppColors.warning,
            size: 18,
          ),
        ],
      ),
    );
  }

  Widget _buildZeroCostSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: MetaColors.card(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MetaColors.cardBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.money_off_csred_rounded, color: MetaColors.emerald, size: 20),
              const SizedBox(width: 8),
              Text(
                'Triagem de Custo Zero (Sem Gastar Tokens)',
                style: TextStyle(
                  color: MetaColors.text(context),
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Comandos rápidos disponíveis para todos os seus alunos em qualquer plano:',
            style: TextStyle(color: MetaColors.subtext(context), fontSize: 13),
          ),
          const SizedBox(height: 12),
          _buildCommandCard(context, '*1* ou *treino*', 'Envia a ficha de treino ativa completa com repetições e descanso.'),
          const SizedBox(height: 8),
          _buildCommandCard(context, '*2* ou *streak*', 'Consulta e informa a ofensiva de treinos seguidos (Streak 🔥).'),
          const SizedBox(height: 8),
          _buildCommandCard(context, '*3* ou *app*', 'Envia o link direto de acesso à plataforma do aluno.'),
          const SizedBox(height: 8),
          _buildCommandCard(context, '*oi*, *ola*, *menu*', 'Exibe o menu de opções imediato sem consumir IA.'),
        ],
      ),
    );
  }

  Widget _buildCommandCard(BuildContext context, String cmd, String desc) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: MetaColors.highlight(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: MetaColors.emerald.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              cmd,
              style: const TextStyle(
                color: MetaColors.emerald,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              desc,
              style: TextStyle(
                color: MetaColors.text(context),
                fontSize: 12.5,
                height: 1.3,
              ),
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
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasAi ? const Color(0xFF6366F1).withValues(alpha: 0.4) : MetaColors.cardBorder(context),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology_rounded, color: Color(0xFF818CF8), size: 22),
              const SizedBox(width: 8),
              Text(
                'Motor Biomecânico Gemini (IA 24h)',
                style: TextStyle(
                  color: MetaColors.text(context),
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Quando o aluno envia perguntas abertas (ex: "como posicionar os pés no leg press?", "posso trocar o crucifixo pelo voador?"), o Gemini 2.5 Flash responde no tom do seu método:',
            style: TextStyle(color: MetaColors.subtext(context), fontSize: 13, height: 1.4),
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
        const Icon(Icons.check_rounded, color: MetaColors.emerald, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: MetaColors.text(context), fontSize: 12.5),
          ),
        ),
      ],
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
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MetaColors.cardBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights_rounded, color: MetaColors.emerald, size: 20),
              const SizedBox(width: 8),
              Text(
                'Impacto do Robô no Mês',
                style: TextStyle(
                  color: MetaColors.text(context),
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMetricItem(
                  context,
                  label: 'Economizados',
                  value: '${hours}h',
                  color: MetaColors.emerald,
                ),
              ),
              Expanded(
                child: _buildMetricItem(
                  context,
                  label: 'Alunos Atendidos',
                  value: '$students',
                  color: const Color(0xFF6366F1),
                ),
              ),
              Expanded(
                child: _buildMetricItem(
                  context,
                  label: 'Mensagens',
                  value: '$total',
                  color: Colors.amber,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(
    BuildContext context, {
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: MetaColors.subtext(context),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
