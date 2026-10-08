import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
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
  String? _totpFactorId;
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
      final roles = AuthService.availableRoles(profile);
      final factorId = roles.contains('trainer')
          ? await AuthService.getVerifiedTotpFactorId()
          : null;
      if (!mounted) return;
      setState(() {
        _roles = roles;
        _email = AuthService.currentUser?.email;
        _totpFactorId = factorId;
      });
    } catch (_) {
      if (mounted) setState(() => _roles = [widget.currentRole]);
    } finally {
      if (mounted) setState(() => _loading = false);
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

  @override
  Widget build(BuildContext context) {
    final roles = _roles.isEmpty ? [widget.currentRole] : _roles;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 36),
      children: [
        Text('Conta', style: Theme.of(context).textTheme.headlineSmall),
        if (_email != null) ...[
          const SizedBox(height: 6),
          Text(_email!, style: Theme.of(context).textTheme.bodyMedium),
        ],
        if (_loading) const LinearProgressIndicator(),
        if (roles.length > 1) ...[
          const SizedBox(height: 28),
          Text('Usar como', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
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
        if (roles.contains('trainer')) ...[
          const SizedBox(height: 32),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.security_outlined),
            title: const Text('Verificação em duas etapas'),
            subtitle: Text(
              _totpFactorId == null
                  ? 'Configuração obrigatória no primeiro acesso de treinador'
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
        const SizedBox(height: 36),
        OutlinedButton.icon(
          onPressed: () => _signOut(false),
          icon: const Icon(Icons.logout),
          label: const Text('Sair neste aparelho'),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: () => _signOut(true),
          icon: const Icon(Icons.phonelink_erase_outlined),
          label: const Text('Sair de todos os dispositivos'),
        ),
      ],
    );
  }
}