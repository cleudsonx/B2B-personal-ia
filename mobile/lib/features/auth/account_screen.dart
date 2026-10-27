import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/widgets/theme_toggle_button.dart';
import '../../core/widgets/app_version_footer.dart';
import '../../core/widgets/meta_components.dart';
import '../../services/auth_service.dart';
import '../../services/subscription_service.dart';
import '../../services/workout_service.dart';
import '../subscription/subscription_screen.dart';
import '../trainer/presentation/screens/trainer_profile_setup_screen.dart';
import '../trainer/presentation/screens/trainer_ai_assistant_screen.dart';
import '../trainer/presentation/screens/whatsapp_connection_screen.dart';
import 'teacher_mfa_screen.dart';

class AccountScreen extends StatefulWidget {
  final String currentRole;
  final Future<void> Function(String role) onRoleSelected;
  final Future<void> Function(bool allDevices) onSignOut;

  const AccountScreen({
    super.key,
    required this.currentRole,
    required this.onRoleSelected,
    required this.onSignOut,
  });

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  List<String> _roles = const [];
  String? _email;
  String? _fullName;
  String? _phone;
  String? _photoUrl;
  String? _cref;
  String? _totpFactorId;
  String? _activePlanName = SubscriptionService.currentSubscription?.planName;
  int? _maxStudents = SubscriptionService.currentSubscription?.maxStudents;
  bool _loading = true;
  bool _isSwitchingRole = false;
  bool _isWhatsAppConnected = false;
  int _robotInteractionsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadAccount();
  }

  Future<void> _fetchWhatsAppAndAiStatus() async {
    final user = AuthService.currentUser;
    if (user == null) return;
    bool connected = false;
    int totalInteractions = 0;

    try {
      final baseUrl = AppConfig.apiBaseUrl;
      final session = Supabase.instance.client.auth.currentSession;
      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (session != null) 'Authorization': 'Bearer ${session.accessToken}',
      };

      final statusResp = await http
          .get(
            Uri.parse('$baseUrl/whatsapp/status?trainer_id=${user.id}'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 4));
      if (statusResp.statusCode == 200) {
        final data = jsonDecode(statusResp.body) as Map<String, dynamic>;
        final st = (data['status']?.toString() ?? '').toLowerCase();
        connected = st == 'open' || st == 'connected';
      }

      final telResp = await http
          .get(
            Uri.parse('$baseUrl/whatsapp/telemetry?trainer_id=${user.id}'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 4));
      if (telResp.statusCode == 200) {
        final data = jsonDecode(telResp.body) as Map<String, dynamic>;
        totalInteractions = (data['total_interactions'] as num?)?.toInt() ?? 0;
      }
    } catch (_) {}

    try {
      final logs = await Supabase.instance.client
          .from('trainer_whatsapp_logs')
          .select('id')
          .eq('trainer_id', user.id);
      if ((logs as List).length > totalInteractions) {
        totalInteractions = logs.length;
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _isWhatsAppConnected = connected;
        _robotInteractionsCount = totalInteractions;
      });
    }
  }

  Future<void> _loadAccount() async {
    try {
      final profile = await AuthService.getCurrentProfile();
      final roles = profile != null
          ? AuthService.availableRoles(profile)
          : [widget.currentRole];
      final factorId = roles.contains('trainer')
          ? await AuthService.getVerifiedTotpFactorId()
          : null;

      if (roles.contains('trainer')) {
        _fetchWhatsAppAndAiStatus();
        try {
          final sub = await SubscriptionService.getMySubscription();
          if (mounted) {
            setState(() {
              _activePlanName = sub.planName;
              _maxStudents = sub.maxStudents;
            });
          }
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _roles = roles;
        _email = AuthService.currentUser?.email;
        _fullName = profile?['full_name'] as String? ?? 'Usuário';
        _phone = (profile?['phone'] ??
            profile?['public_whatsapp'] ??
            profile?['whatsapp']) as String?;
        _photoUrl = (profile?['photo_url'] ?? profile?['avatar_url']) as String?;
        _cref = (profile?['professional_document'] ?? profile?['cref']) as String?;
        _totpFactorId = factorId;
      });
    } catch (_) {
      if (mounted) setState(() => _roles = [widget.currentRole]);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editPhoneNumber() async {
    final phoneController = TextEditingController(text: _phone ?? '');
    final formKey = GlobalKey<FormState>();
    final isDark = MetaColors.isDark(context);

    final updated = await showDialog<String?>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: MetaColors.card(dialogCtx),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: MetaColors.cardBorder(dialogCtx)),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: MetaColors.emerald.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.phone_rounded, color: MetaColors.emerald, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Atualizar Telefone / WhatsApp',
                style: TextStyle(
                  color: MetaColors.text(dialogCtx),
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Este número será sincronizado no seu perfil, na vitrine pública e nos disparos do WhatsApp.',
                style: TextStyle(color: MetaColors.subtext(dialogCtx), fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                style: TextStyle(color: MetaColors.text(dialogCtx)),
                decoration: InputDecoration(
                  labelText: 'Telefone com DDD',
                  hintText: 'Ex: 61982912174',
                  prefixIcon: const Icon(Icons.call_outlined, size: 20),
                  filled: true,
                  fillColor: isDark ? MetaColors.surfaceHighlight : const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: MetaColors.cardBorder(dialogCtx)),
                  ),
                ),
                validator: (val) {
                  final digits = (val ?? '').replaceAll(RegExp(r'\D'), '');
                  if (digits.isEmpty) return 'Informe o número do telefone';
                  if (digits.length < 10 || digits.length > 13) {
                    return 'Telefone inválido (use DDD + número)';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, null),
            child: Text('Cancelar', style: TextStyle(color: MetaColors.subtext(dialogCtx))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: MetaColors.emerald,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final digits = phoneController.text.replaceAll(RegExp(r'\D'), '');
                Navigator.pop(dialogCtx, digits);
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (updated != null && updated != _phone) {
      setState(() => _loading = true);
      try {
        final client = Supabase.instance.client;
        final uid = client.auth.currentUser?.id;
        if (uid != null) {
          final payload = {
            'phone': updated,
            'public_whatsapp': updated,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          };
          await client.from('profiles').update(payload).eq('id', uid);
        }
        WorkoutService.studentsRefreshNotifier.value++;
        if (mounted) {
          setState(() {
            _phone = updated;
            _loading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: MetaColors.emerald,
              content: Text(
                'Telefone atualizado e sincronizado em todo o sistema!',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _loading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.red.shade900,
              content: Text('Erro ao atualizar telefone: $e'),
            ),
          );
        }
      }
    }
  }

  Future<void> _signOut(bool allDevices) async {
    if (allDevices) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Sair de todos os dispositivos?'),
          content: const Text(
            'Isso revoga todas as sessões da conta. Será necessário entrar novamente em cada aparelho.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Revogar sessões'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    try {
      await widget.onSignOut(allDevices);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  String _formatPhone(String? p) {
    if (p == null || p.isEmpty) return 'Não cadastrado';
    final digits = p.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 11) {
      return '(${digits.substring(0, 2)}) ${digits.substring(2, 7)}-${digits.substring(7)}';
    } else if (digits.length == 10) {
      return '(${digits.substring(0, 2)}) ${digits.substring(2, 6)}-${digits.substring(6)}';
    } else if (digits.length == 13 && digits.startsWith('55')) {
      return '+55 (${digits.substring(2, 4)}) ${digits.substring(4, 9)}-${digits.substring(9)}';
    }
    return p;
  }

  @override
  Widget build(BuildContext context) {
    final roles = _roles.isEmpty ? [widget.currentRole] : _roles;
    final isTrainer = widget.currentRole == 'trainer';
    final hasActiveCref = _cref != null && _cref!.toUpperCase().startsWith('CREF');

    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return ListView(
      padding: EdgeInsets.fromLTRB(20, topInset + 16, 20, bottomInset + 110),
      children: [
        // Topo: Título da tela
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Conta',
              style: TextStyle(
                color: MetaColors.text(context),
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            const ThemeToggleButton(compact: true),
          ],
        ),
        const SizedBox(height: 16),

        // 1. Card de Perfil com Avatar: Foto/iniciais, nome completo, e-mail e badge da função
        MetaCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: MetaColors.highlight(context),
                backgroundImage: safeImageProvider(_photoUrl),
                child: safeImageProvider(_photoUrl) == null
                    ? Text(
                        (_fullName != null && _fullName!.isNotEmpty)
                            ? _fullName![0].toUpperCase()
                            : 'U',
                        style: const TextStyle(
                          color: MetaColors.emerald,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _fullName ?? 'Usuário',
                      style: TextStyle(
                        color: MetaColors.text(context),
                        fontSize: 16.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _email ?? 'Carregando...',
                      style: TextStyle(
                        color: MetaColors.subtext(context),
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: MetaColors.emerald.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isTrainer ? 'TREINADOR PROFISSIONAL' : 'ALUNO',
                        style: const TextStyle(
                          color: MetaColors.emerald,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        if (isTrainer) ...[
          const SizedBox(height: 16),

          // 2. Selo de Registro Profissional (CREF): Indicador visual de CREF Ativo vs Pendente
          MetaCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: hasActiveCref
                        ? MetaColors.emerald.withValues(alpha: 0.12)
                        : Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.verified_outlined,
                    color: hasActiveCref ? MetaColors.emerald : Colors.orangeAccent,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Registro Profissional (CREF)',
                            style: TextStyle(
                              color: MetaColors.subtext(context),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: hasActiveCref
                                  ? MetaColors.emerald.withValues(alpha: 0.15)
                                  : Colors.orange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              hasActiveCref ? 'ATIVO' : 'PENDENTE',
                              style: TextStyle(
                                color: hasActiveCref ? MetaColors.emerald : Colors.orangeAccent,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        (_cref != null && _cref!.isNotEmpty) ? _cref! : 'CREF Pendente • Regularize seu perfil',
                        style: TextStyle(
                          color: MetaColors.text(context),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TrainerProfileSetupScreen()),
                    );
                    await _loadAccount();
                  },
                  child: Text(hasActiveCref ? 'Editar' : 'Regularizar'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 3. Card do Plano SaaS & Limite de Vagas
          MetaCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.workspace_premium_outlined, color: Colors.amber, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Plano SaaS & Limite de Vagas',
                        style: TextStyle(
                          color: MetaColors.subtext(context),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _activePlanName != null
                            ? 'Plano $_activePlanName - ${_maxStudents ?? 60} vagas'
                            : (_loading ? 'Carregando plano...' : 'Plano Elite Coach - 60 vagas'),
                        style: TextStyle(
                          color: MetaColors.text(context),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                    );
                    await _loadAccount();
                  },
                  child: const Text('Upgrade'),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 16),

        // 4. Card de Conexão WhatsApp & Número com Edição Rápida
        MetaCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          onTap: isTrainer
              ? () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => WhatsappConnectionScreen(initialPhone: _phone),
                    ),
                  ).then((_) => _loadAccount());
                }
              : _editPhoneNumber,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: MetaColors.emerald.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.phone_android_rounded, color: MetaColors.emerald, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            isTrainer ? 'Conexão WhatsApp & Número' : 'WhatsApp Cadastrado',
                            style: TextStyle(
                              color: MetaColors.subtext(context),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (isTrainer)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: (_isWhatsAppConnected ? MetaColors.emerald : Colors.orangeAccent)
                                  .withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              _isWhatsAppConnected ? 'CONECTADO 24H' : 'PAREAR ROBÔ',
                              style: TextStyle(
                                color: _isWhatsAppConnected ? MetaColors.emerald : Colors.orangeAccent,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _formatPhone(_phone),
                      style: TextStyle(
                        color: MetaColors.text(context),
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (isTrainer) ...[
                      const SizedBox(height: 2),
                      Text(
                        _isWhatsAppConnected
                            ? 'Robô 24h ativo • Toque para pareamento e logs'
                            : 'Toque para parear seu WhatsApp via QR ou Código',
                        style: TextStyle(
                          color: MetaColors.subtext(context),
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.edit_outlined, size: 20),
                tooltip: 'Atualizar telefone',
                color: MetaColors.emerald,
                onPressed: _editPhoneNumber,
              ),
              if (isTrainer)
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: MetaColors.emerald,
                  size: 16,
                ),
            ],
          ),
        ),

        if (isTrainer) ...[
          const SizedBox(height: 16),

          // 5. Card do Consultor Ativo IA & WhatsApp (Cockpit One UI 7)
          MetaCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TrainerAiAssistantScreen()),
              ).then((_) => _loadAccount());
            },
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: MetaColors.emerald.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.smart_toy_rounded, color: MetaColors.emerald, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Consultor Ativo IA & WhatsApp',
                              style: TextStyle(
                                color: MetaColors.text(context),
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: MetaColors.emerald.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              _robotInteractionsCount > 0
                                  ? '$_robotInteractionsCount ATIVOS'
                                  : 'LIVE PULSE 3.0',
                              style: const TextStyle(
                                color: MetaColors.emerald,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _robotInteractionsCount > 0
                            ? 'Cockpit 24h • Live Pulse 3.0 e $_robotInteractionsCount interações de IA/Robô'
                            : 'Cockpit 24h • Live Pulse 3.0, Triagem Custo Zero e IA',
                        style: TextStyle(
                          color: MetaColors.subtext(context),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: MetaColors.emerald,
                  size: 18,
                ),
              ],
            ),
          ),
        ],

        if (roles.contains('trainer')) ...[
          const SizedBox(height: 16),
          ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.security_outlined, size: 20),
            title: const Text('Verificação em duas etapas'),
            subtitle: Text(
              _totpFactorId == null
                  ? 'Configuração recomendada para segurança da consultoria'
                  : 'Aplicativo autenticador ativo',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TeacherMfaScreen()),
              );
              await _loadAccount();
            },
          ),
        ],

        if (_loading) const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: LinearProgressIndicator(),
        ),

        if (roles.length > 1) ...[
          const SizedBox(height: 24),
          Text(
            'Usar como',
            style: TextStyle(
              color: MetaColors.text(context),
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          SegmentedButton<String>(
            segments: [
              for (final role in roles)
                ButtonSegment<String>(
                  value: role,
                  label: Text(
                    role == 'admin'
                        ? 'Admin ⚡'
                        : (role == 'trainer' ? 'Treinador' : 'Aluno'),
                  ),
                  icon: Icon(
                    role == 'admin'
                        ? Icons.admin_panel_settings_rounded
                        : (role == 'trainer' ? Icons.fitness_center : Icons.person_outline),
                  ),
                ),
            ],
            selected: {
              roles.contains(widget.currentRole) ? widget.currentRole : roles.first,
            },
            onSelectionChanged: (selection) async {
              if (_isSwitchingRole) return;
              final messenger = ScaffoldMessenger.of(context);
              setState(() => _isSwitchingRole = true);
              try {
                await widget.onRoleSelected(selection.first);
              } catch (error) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        error.toString().replaceFirst('Exception: ', ''),
                      ),
                    ),
                  );
                }
              } finally {
                if (mounted) setState(() => _isSwitchingRole = false);
              }
            },
            emptySelectionAllowed: false,
          ),
          if (_isSwitchingRole) const LinearProgressIndicator(),
        ],

        const SizedBox(height: 24),
        Text(
          'Aparência',
          style: TextStyle(
            color: MetaColors.text(context),
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        ListenableBuilder(
          listenable: ThemeController.instance,
          builder: (context, _) {
            final currentMode = ThemeController.instance.themeMode;
            return SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment<ThemeMode>(
                  value: ThemeMode.dark,
                  label: Text('Escuro'),
                  icon: Icon(Icons.dark_mode_rounded),
                ),
                ButtonSegment<ThemeMode>(
                  value: ThemeMode.light,
                  label: Text('Claro'),
                  icon: Icon(Icons.light_mode_rounded),
                ),
                ButtonSegment<ThemeMode>(
                  value: ThemeMode.system,
                  label: Text('Sistema'),
                  icon: Icon(Icons.brightness_auto_rounded),
                ),
              ],
              selected: {currentMode},
              onSelectionChanged: (selection) {
                if (selection.isNotEmpty) {
                  ThemeController.instance.setThemeMode(selection.first);
                }
              },
              emptySelectionAllowed: false,
            );
          },
        ),

        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () => _signOut(false),
          icon: const Icon(Icons.logout),
          label: const Text('Sair neste aparelho'),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => _signOut(true),
          icon: const Icon(Icons.phonelink_erase_outlined),
          label: const Text('Sair de todos os dispositivos'),
        ),
        const AppVersionFooter(
          padding: EdgeInsets.only(top: 14, bottom: 8),
        ),
      ],
    );
  }
}