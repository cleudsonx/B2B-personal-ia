import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/widgets/theme_toggle_button.dart';
import '../../core/widgets/app_version_footer.dart';
import '../../core/widgets/avatar_selector_sheet.dart';
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
  int _currentStudents = SubscriptionService.currentSubscription?.currentStudents ?? 0;
  bool _loading = true;
  bool _isSwitchingRole = false;
  bool _isWhatsAppConnected = false;
  bool _isPlatformBotConnected = false;
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
    bool platformBotConnected = false;
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
        final st = (data['status']?.toString() ?? data['state']?.toString() ?? '').toLowerCase();
        final isConn = data['is_connected'] == true || data['trainer_connected'] == true;
        connected = isConn || st == 'open' || st == 'connected';
        platformBotConnected = data['platform_bot_connected'] == true || st == 'platform_active';
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
        _isPlatformBotConnected = platformBotConnected;
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
          int studentCount = sub.currentStudents;
          final uid = AuthService.currentUser?.id;
          if (studentCount == 0 && uid != null) {
            try {
              final rows = await Supabase.instance.client
                  .from('profiles')
                  .select('id')
                  .eq('trainer_id', uid);
              studentCount = (rows as List).length;
            } catch (_) {}
          }
          int effectiveMaxStudents = sub.maxStudents;
          final profMax = (profile?['max_students'] as num?)?.toInt();
          final isVipOrAdmin = profile?['is_vip'] == true || profile?['is_admin'] == true;
          if (profMax != null && profMax > 0) {
            effectiveMaxStudents = profMax;
          } else if (isVipOrAdmin && effectiveMaxStudents < 999) {
            effectiveMaxStudents = 999;
          }

          if (mounted) {
            setState(() {
              _activePlanName = profile?['current_plan'] as String? ?? sub.planName;
              _maxStudents = effectiveMaxStudents;
              _currentStudents = studentCount;
            });
          }
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _roles = roles;
        _email = AuthService.currentUser?.email;
        _fullName = profile?['full_name'] as String? ??
            AuthService.currentUser?.userMetadata?['full_name'] as String? ??
            'Usuário';
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

  Future<void> _updateProfileAvatar() async {
    final isTrainer = widget.currentRole == 'trainer';
    final selected = await AvatarSelectorSheet.show(
      context: context,
      isTrainer: isTrainer,
      currentUrl: _photoUrl,
    );
    if (selected != null && mounted) {
      setState(() => _loading = true);
      try {
        final client = Supabase.instance.client;
        final uid = client.auth.currentUser?.id;
        if (uid != null) {
          await client.from('profiles').update({
            'photo_url': selected,
            'avatar_url': selected,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          }).eq('id', uid);

          await client.auth.updateUser(
            UserAttributes(data: {
              'photo_url': selected,
              'avatar_url': selected,
            }),
          );
        }
        WorkoutService.studentsRefreshNotifier.value++;
        if (mounted) {
          setState(() {
            _photoUrl = selected;
            _loading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: MetaColors.emerald,
              content: Text(
                'Foto de perfil atualizada com sucesso!',
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
              content: Text('Erro ao atualizar foto: $e'),
            ),
          );
        }
      }
    }
  }

  Future<void> _editFullName() async {
    final nameController = TextEditingController(text: _fullName ?? '');
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
              child: const Icon(Icons.badge_outlined, color: MetaColors.emerald, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Editar Nome de Exibição',
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
                'Este nome será exibido no seu perfil, na vitrine pública, nos treinos dos alunos e nas mensagens do WhatsApp.',
                style: TextStyle(color: MetaColors.subtext(dialogCtx), fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: nameController,
                textCapitalization: TextCapitalization.words,
                style: TextStyle(color: MetaColors.text(dialogCtx)),
                decoration: InputDecoration(
                  labelText: 'Nome completo ou profissional',
                  hintText: 'Ex: Prof. Rafael Silva',
                  prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                  filled: true,
                  fillColor: isDark ? MetaColors.surfaceHighlight : const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: MetaColors.cardBorder(dialogCtx)),
                  ),
                ),
                validator: (val) {
                  final text = (val ?? '').trim();
                  if (text.isEmpty) return 'Informe o seu nome';
                  if (text.length < 2) return 'Nome muito curto';
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
                Navigator.pop(dialogCtx, nameController.text.trim());
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (updated != null && updated.isNotEmpty && updated != _fullName) {
      setState(() => _loading = true);
      try {
        final client = Supabase.instance.client;
        final uid = client.auth.currentUser?.id;
        if (uid != null) {
          await client.from('profiles').update({
            'full_name': updated,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          }).eq('id', uid);

          await client.auth.updateUser(
            UserAttributes(data: {'full_name': updated}),
          );
        }
        WorkoutService.studentsRefreshNotifier.value++;
        if (mounted) {
          setState(() {
            _fullName = updated;
            _loading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: MetaColors.emerald,
              content: Text(
                'Nome atualizado e sincronizado em todo o sistema!',
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
              content: Text('Erro ao atualizar nome: $e'),
            ),
          );
        }
      }
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
                fontSize: 26,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            const ThemeToggleButton(compact: true),
          ],
        ),
        const SizedBox(height: 16),

        // 1. Hero Card de Identidade + Edição de Nome/Foto + CREF Integrado
        _buildIdentityAndCrefCard(context, isTrainer: isTrainer, hasActiveCref: hasActiveCref),

        if (isTrainer) ...[
          const SizedBox(height: 14),
          // 2. Card de Assinatura SaaS & Ocupação de Vagas
          _buildSaaSPlanCard(context),
        ],

        const SizedBox(height: 14),

        // 3. Hub Unificado: WhatsApp & Consultor IA 24h (Sem duplicidade!)
        _buildUnifiedWhatsAppAndAiCard(context, isTrainer: isTrainer),

        if (roles.contains('trainer')) ...[
          const SizedBox(height: 14),
          // 4. Card de Segurança (2FA)
          _buildSecurityCard(context),
        ],

        if (_loading || _isSwitchingRole) ...[
          const SizedBox(height: 14),
          const SizedBox(
            height: 76,
            child: ShaipadosLoaderContainer(
              type: ShaipadosLoaderType.executiveShimmer,
              isOverlay: false,
              customTitle: 'Sincronizando dados da conta...',
            ),
          ),
        ],

        const SizedBox(height: 18),

        // 5. Seção de Preferências do Sistema ("Usar como" e "Aparência")
        _buildPreferencesCard(context, roles: roles),

        const SizedBox(height: 20),

        // 6. Ações de Sessão & Dispositivos
        _buildSessionActions(context),

        const AppVersionFooter(
          padding: EdgeInsets.only(top: 14, bottom: 8),
        ),
      ],
    );
  }

  Widget _buildIdentityAndCrefCard(
    BuildContext context, {
    required bool isTrainer,
    required bool hasActiveCref,
  }) {
    final imgProvider = safeImageProvider(_photoUrl);

    return MetaCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar Interativo com badge de câmera
              GestureDetector(
                onTap: _updateProfileAvatar,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2.5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: MetaColors.emerald.withValues(alpha: 0.45),
                          width: 2,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 28,
                        backgroundColor: MetaColors.highlight(context),
                        backgroundImage: imgProvider,
                        child: imgProvider == null
                            ? Text(
                                (_fullName != null && _fullName!.isNotEmpty)
                                    ? _fullName![0].toUpperCase()
                                    : 'U',
                                style: const TextStyle(
                                  color: MetaColors.emerald,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 22,
                                ),
                              )
                            : null,
                      ),
                    ),
                    Positioned(
                      bottom: -2,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: MetaColors.emerald,
                          shape: BoxShape.circle,
                          border: Border.all(color: MetaColors.card(context), width: 2),
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          size: 11,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: _editFullName,
                            child: Text(
                              _fullName ?? 'Usuário',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: MetaColors.text(context),
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: _editFullName,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: MetaColors.emerald.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.edit_outlined, size: 13, color: MetaColors.emerald),
                                SizedBox(width: 4),
                                Text(
                                  'Nome',
                                  style: TextStyle(
                                    color: MetaColors.emerald,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _email ?? 'Carregando...',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: MetaColors.subtext(context),
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 7),
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
          if (isTrainer) ...[
            const SizedBox(height: 14),
            Divider(height: 1, color: MetaColors.cardBorder(context)),
            const SizedBox(height: 12),
            // Linha integrada de Registro Profissional (CREF) sem desalinhamento
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: hasActiveCref
                        ? MetaColors.emerald.withValues(alpha: 0.12)
                        : Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.verified_outlined,
                    color: hasActiveCref ? MetaColors.emerald : Colors.orangeAccent,
                    size: 20,
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
                              'Registro Profissional (CREF)',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: MetaColors.subtext(context),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: hasActiveCref
                                  ? MetaColors.emerald.withValues(alpha: 0.15)
                                  : Colors.orange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              hasActiveCref ? 'ATIVO' : 'PENDENTE',
                              style: TextStyle(
                                color: hasActiveCref ? MetaColors.emerald : Colors.orangeAccent,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        (_cref != null && _cref!.isNotEmpty)
                            ? _cref!
                            : 'CREF Pendente • Regularize seu perfil',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: MetaColors.text(context),
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TrainerProfileSetupScreen()),
                    );
                    await _loadAccount();
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: MetaColors.highlight(context),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: MetaColors.cardBorder(context)),
                    ),
                    child: Center(
                      child: Text(
                        hasActiveCref ? 'Editar' : 'Regularizar',
                        style: TextStyle(
                          color: MetaColors.emerald,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSaaSPlanCard(BuildContext context) {
    final maxVagas = _maxStudents ?? 60;
    final usedVagas = _currentStudents;
    final ratio = maxVagas > 0 ? (usedVagas / maxVagas).clamp(0.0, 1.0) : 0.0;
    final pct = (ratio * 100).round();

    final Color barColor = ratio >= 0.9
        ? const Color(0xFFF43F5E)
        : (ratio >= 0.75 ? const Color(0xFFF59E0B) : MetaColors.emerald);

    return MetaCard(
      padding: const EdgeInsets.all(16),
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
        );
        await _loadAccount();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.workspace_premium_outlined, color: Colors.amber, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Plano SaaS & Capacidade',
                      style: TextStyle(
                        color: MetaColors.subtext(context),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _activePlanName != null
                          ? 'Plano $_activePlanName'
                          : (_loading ? 'Carregando plano...' : 'Plano Elite Coach'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: MetaColors.text(context),
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: MetaColors.emerald.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: MetaColors.emerald.withValues(alpha: 0.35)),
                ),
                child: const Center(
                  child: Text(
                    '💎 Upgrade',
                    style: TextStyle(
                      color: MetaColors.emerald,
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$usedVagas de $maxVagas vagas ativas',
                style: TextStyle(
                  color: MetaColors.subtext(context),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '$pct% ocupado',
                style: TextStyle(
                  color: barColor,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: MetaColors.highlight(context),
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnifiedWhatsAppAndAiCard(BuildContext context, {required bool isTrainer}) {
    if (!isTrainer) {
      // Versão limpa para o Aluno
      return MetaCard(
        padding: const EdgeInsets.all(16),
        onTap: _editPhoneNumber,
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
                  Text(
                    'WhatsApp Cadastrado',
                    style: TextStyle(
                      color: MetaColors.subtext(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
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
          ],
        ),
      );
    }

    // Hub Unificado para o Professor (Elimina a duplicidade entre Conexão WhatsApp e Consultor IA)
    final bool isPersonalActive = _isWhatsAppConnected;
    final bool isFallbackActive = !isPersonalActive && _isPlatformBotConnected;
    final Color statusColor = isPersonalActive
        ? MetaColors.emerald
        : (isFallbackActive ? const Color(0xFF06B6D4) : Colors.orangeAccent);
    final String badgeText = isPersonalActive
        ? 'SEU NÚMERO ATIVO'
        : (isFallbackActive ? 'ROBÔ GERAL 24H' : 'PAREAR ROBÔ');
    final String subtitleText = isPersonalActive
        ? 'Cockpit 24h • Seu WhatsApp conectado • $_robotInteractionsCount interações'
        : (isFallbackActive
            ? 'Alunos protegidos via Central Mr. Coach (61) 99149-7852'
            : 'Cockpit 24h • Live Pulse 3.0 e Triagem Custo Zero');

    return MetaCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho em 1 linha sem quebra tripla
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.smart_toy_rounded, color: statusColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'WhatsApp & Consultor IA',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: MetaColors.text(context),
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitleText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
          const SizedBox(height: 12),

          // Faixa do Número Vinculado + Edição Rápida
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: MetaColors.highlight(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: MetaColors.cardBorder(context)),
            ),
            child: Row(
              children: [
                const Icon(Icons.phone_android_rounded, size: 16, color: MetaColors.emerald),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Número: ${_formatPhone(_phone)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: MetaColors.text(context),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                InkWell(
                  onTap: _editPhoneNumber,
                  borderRadius: BorderRadius.circular(6),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit_outlined, size: 14, color: MetaColors.emerald),
                        SizedBox(width: 4),
                        Text(
                          'Alterar',
                          style: TextStyle(
                            color: MetaColors.emerald,
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Barra Dupla de Ações Simétricas (36px)
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => WhatsappConnectionScreen(initialPhone: _phone),
                      ),
                    ).then((_) => _loadAccount());
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: MetaColors.highlight(context),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: MetaColors.cardBorder(context)),
                    ),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _isWhatsAppConnected ? '🔗 Conexão & Logs' : '🔗 Parear WhatsApp',
                          maxLines: 1,
                          style: TextStyle(
                            color: MetaColors.text(context),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TrainerAiAssistantScreen()),
                    ).then((_) => _loadAccount());
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: MetaColors.emerald.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: MetaColors.emerald.withValues(alpha: 0.35)),
                    ),
                    child: const Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '🤖 Abrir Cockpit IA',
                          maxLines: 1,
                          style: TextStyle(
                            color: MetaColors.emerald,
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityCard(BuildContext context) {
    final isProtected = _totpFactorId != null;

    return MetaCard(
      padding: const EdgeInsets.all(16),
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TeacherMfaScreen()),
        );
        await _loadAccount();
      },
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: (isProtected ? MetaColors.emerald : Colors.orangeAccent)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.security_rounded,
              color: isProtected ? MetaColors.emerald : Colors.orangeAccent,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Verificação em duas etapas',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: MetaColors.text(context),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: (isProtected ? MetaColors.emerald : Colors.orangeAccent)
                            .withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        isProtected ? 'PROTEGIDO' : 'RECOMENDADO',
                        style: TextStyle(
                          color: isProtected ? MetaColors.emerald : Colors.orangeAccent,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  isProtected
                      ? 'Aplicativo autenticador TOTP ativo na sua conta'
                      : 'Ative o autenticador para blindar sua consultoria',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: MetaColors.subtext(context),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            Icons.chevron_right_rounded,
            color: MetaColors.subtext(context),
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildPreferencesCard(BuildContext context, {required List<String> roles}) {
    final activeRole = roles.contains(widget.currentRole) ? widget.currentRole : roles.first;

    return MetaCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (roles.length > 1) ...[
            Text(
              'Usar como',
              style: TextStyle(
                color: MetaColors.text(context),
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: MetaColors.highlight(context),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: MetaColors.cardBorder(context)),
              ),
              child: Row(
                children: [
                  for (final role in roles)
                    Expanded(
                      child: _buildPillOption(
                        context: context,
                        isSelected: activeRole == role,
                        label: role == 'admin'
                            ? 'Admin ⚡'
                            : (role == 'trainer' ? 'Treinador' : 'Aluno'),
                        icon: role == 'admin'
                            ? Icons.admin_panel_settings_rounded
                            : (role == 'trainer' ? Icons.fitness_center_rounded : Icons.person_outline_rounded),
                        onTap: () async {
                          if (_isSwitchingRole || activeRole == role) return;
                          final messenger = ScaffoldMessenger.of(context);
                          setState(() => _isSwitchingRole = true);
                          try {
                            await widget.onRoleSelected(role);
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
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            'Aparência',
            style: TextStyle(
              color: MetaColors.text(context),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          ListenableBuilder(
            listenable: ThemeController.instance,
            builder: (context, _) {
              final currentMode = ThemeController.instance.themeMode;
              return Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: MetaColors.highlight(context),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: MetaColors.cardBorder(context)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildPillOption(
                        context: context,
                        isSelected: currentMode == ThemeMode.dark,
                        label: 'Escuro',
                        icon: Icons.dark_mode_rounded,
                        onTap: () => ThemeController.instance.setThemeMode(ThemeMode.dark),
                      ),
                    ),
                    Expanded(
                      child: _buildPillOption(
                        context: context,
                        isSelected: currentMode == ThemeMode.light,
                        label: 'Claro',
                        icon: Icons.light_mode_rounded,
                        onTap: () => ThemeController.instance.setThemeMode(ThemeMode.light),
                      ),
                    ),
                    Expanded(
                      child: _buildPillOption(
                        context: context,
                        isSelected: currentMode == ThemeMode.system,
                        label: 'Sistema',
                        icon: Icons.brightness_auto_rounded,
                        onTap: () => ThemeController.instance.setThemeMode(ThemeMode.system),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPillOption({
    required BuildContext context,
    required bool isSelected,
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: isSelected ? MetaColors.emerald : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 15,
                  color: isSelected ? Colors.white : MetaColors.subtext(context),
                ),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : MetaColors.text(context),
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSessionActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => _signOut(false),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: MetaColors.card(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: MetaColors.cardBorder(context)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.logout_rounded, size: 18, color: MetaColors.emerald),
                SizedBox(width: 8),
                Text(
                  'Sair neste aparelho',
                  style: TextStyle(
                    color: MetaColors.emerald,
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => _signOut(true),
          icon: const Icon(Icons.phonelink_erase_outlined, size: 17),
          label: const Text(
            'Sair de todos os dispositivos',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
