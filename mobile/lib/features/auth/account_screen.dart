import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/theme_controller.dart';
import '../../core/widgets/app_version_footer.dart';
import '../../core/widgets/meta_components.dart';
import '../../services/auth_service.dart';
import '../../services/subscription_service.dart';
import '../../services/workout_service.dart';
import '../subscription/subscription_screen.dart';
import '../trainer/presentation/screens/trainer_profile_setup_screen.dart';
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
  String? _activePlanName;
  int? _maxStudents;
  bool _loading = true;
  bool _isSwitchingRole = false;

  @override
  void initState() {
    super.initState();
    _loadAccount();
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
        try {
          final sub = await SubscriptionService.getMySubscription();
          if (mounted && sub != null) {
            _activePlanName = sub.planName;
            _maxStudents = sub.maxStudents;
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
            'whatsapp': updated,
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

    return ListView(
      cacheExtent: 1200,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      children: [
        // Topo: Título da tela
        Text(
          'Conta',
          style: TextStyle(
            color: MetaColors.text(context),
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 10),

        // 1. Card de Perfil com Avatar: Foto/iniciais, nome completo, e-mail e badge da função
        MetaCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
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
                          fontSize: 18,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _fullName ?? 'Usuário',
                      style: TextStyle(
                        color: MetaColors.text(context),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _email ?? 'Carregando...',
                      style: TextStyle(
                        color: MetaColors.subtext(context),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
          const SizedBox(height: 8),

          // 2. Selo de Registro Profissional (CREF): Indicador visual de CREF Ativo vs Pendente
          MetaCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
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
                          Text(
                            'Registro Profissional (CREF)',
                            style: TextStyle(
                              color: MetaColors.subtext(context),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
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
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 1),
                      Text(
                        (_cref != null && _cref!.isNotEmpty) ? _cref! : 'CREF Pendente • Regularize seu perfil',
                        style: TextStyle(
                          color: MetaColors.text(context),
                          fontSize: 13.5,
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

          const SizedBox(height: 8),

          // 3. Card do Plano SaaS & Limite de Vagas
          MetaCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.workspace_premium_outlined, color: Colors.amber, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Plano SaaS & Limite de Vagas',
                        style: TextStyle(
                          color: MetaColors.subtext(context),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        _activePlanName != null
                            ? 'Plano $_activePlanName - ${_maxStudents ?? 30} vagas'
                            : 'Plano Pro - 30 vagas',
                        style: TextStyle(
                          color: MetaColors.text(context),
                          fontSize: 13.5,
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

        const SizedBox(height: 8),

        // 4. Card de WhatsApp com Edição Rápida
        MetaCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: MetaColors.emerald.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.phone_android_rounded, color: MetaColors.emerald, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WhatsApp Cadastrado',
                      style: TextStyle(
                        color: MetaColors.subtext(context),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      _formatPhone(_phone),
                      style: TextStyle(
                        color: MetaColors.text(context),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.edit_outlined, size: 19),
                tooltip: 'Atualizar telefone',
                color: MetaColors.emerald,
                onPressed: _editPhoneNumber,
              ),
            ],
          ),
        ),

        if (isTrainer) ...[
          const SizedBox(height: 8),

          // 5. Card de Telemetria do Robô WhatsApp
          MetaCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WhatsappConnectionScreen()),
              );
            },
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: MetaColors.emerald.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.smart_toy_outlined, color: MetaColors.emerald, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Telemetria do Robô WhatsApp',
                        style: TextStyle(
                          color: MetaColors.text(context),
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Status Evolution API & QR Code de pareamento',
                        style: TextStyle(
                          color: MetaColors.subtext(context),
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.qr_code_scanner_rounded,
                  color: MetaColors.emerald,
                  size: 20,
                ),
              ],
            ),
          ),
        ],

        if (roles.contains('trainer')) ...[
          const SizedBox(height: 6),
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
                  label: Text(role == 'trainer' ? 'Treinador' : 'Aluno'),
                  icon: Icon(
                    role == 'trainer' ? Icons.fitness_center : Icons.person_outline,
                  ),
                ),
            ],
            selected: {
              roles.contains(widget.currentRole) ? widget.currentRole : roles.first,
            },
            onSelectionChanged: (selection) async {
              if (_isSwitchingRole) return;
              setState(() => _isSwitchingRole = true);
              try {
                await widget.onRoleSelected(selection.first);
              } catch (error) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
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