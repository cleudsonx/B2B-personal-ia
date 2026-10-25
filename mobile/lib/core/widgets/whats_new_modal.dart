import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';
import 'meta_components.dart';

class WhatsNewModal extends StatefulWidget {
  final Map<String, dynamic>? versionData;
  final String? forcedRole;

  const WhatsNewModal({super.key, this.versionData, this.forcedRole});

  /// Exibe o modal manualmente (ex: tela de Perfil ou Ajuda)
  static Future<void> show(BuildContext context, {String? forcedRole}) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => WhatsNewModal(forcedRole: forcedRole),
    );
  }

  /// Verifica se há nova build e exibe o modal automaticamente apenas 1 vez por versão
  static Future<void> checkAndShowIfUpdated(BuildContext context) async {
    if (!kIsWeb) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSeenBuild = prefs.getInt('last_seen_whats_new_build') ?? 0;

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final uri = Uri.base.resolve('/version.json?_t=$timestamp');
      final response = await http.get(uri).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final serverBuild = int.tryParse(data['build']?.toString() ?? '0') ?? 0;

        if (serverBuild > lastSeenBuild && context.mounted) {
          await showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (ctx) => WhatsNewModal(versionData: data),
          );
          await prefs.setInt('last_seen_whats_new_build', serverBuild);
        }
      }
    } catch (_) {
      // Ignora erro silencioso de checagem
    }
  }

  @override
  State<WhatsNewModal> createState() => _WhatsNewModalState();
}

class _WhatsNewModalState extends State<WhatsNewModal> {
  bool _isLoading = true;
  Map<String, dynamic>? _data;
  String _userRole = 'client'; // 'client', 'trainer', 'admin'

  @override
  void initState() {
    super.initState();
    _loadDataAndRole();
  }

  Future<void> _loadDataAndRole() async {
    // 1. Carrega dados de versão se não foram passados
    if (widget.versionData != null) {
      _data = widget.versionData;
    } else {
      try {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final uri = kIsWeb
            ? Uri.base.resolve('/version.json?_t=$timestamp')
            : Uri.parse('/version.json?_t=$timestamp');
        final res = await http.get(uri).timeout(const Duration(seconds: 5));
        if (res.statusCode == 200) {
          _data = jsonDecode(res.body);
        }
      } catch (_) {}
    }

    // 2. Determina o perfil do usuário ativo
    if (widget.forcedRole != null) {
      _userRole = widget.forcedRole!;
    } else {
      try {
        final profile = await AuthService.getCurrentProfile();
        final rawRole = profile?['role']?.toString().toLowerCase();
        if (rawRole == 'admin' || profile?['is_admin'] == true) {
          _userRole = 'admin';
        } else if (rawRole == 'trainer' || rawRole == 'coach' || rawRole == 'personal') {
          _userRole = 'trainer';
        } else {
          _userRole = 'client';
        }
      } catch (_) {
        _userRole = 'client';
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  IconData _mapIcon(String? iconKey) {
    switch (iconKey) {
      case 'message':
      case 'whatsapp':
        return Icons.chat_bubble_outline_rounded;
      case 'bolt':
        return Icons.bolt_rounded;
      case 'credit_card':
      case 'payments':
        return Icons.credit_card_rounded;
      case 'fire':
        return Icons.local_fire_department_rounded;
      case 'speed':
        return Icons.speed_rounded;
      case 'verified':
        return Icons.verified_user_rounded;
      case 'account_balance':
        return Icons.account_balance_rounded;
      case 'database':
        return Icons.storage_rounded;
      case 'hub':
        return Icons.hub_rounded;
      default:
        return Icons.auto_awesome_rounded;
    }
  }

  Color _mapTagColor(String? tag) {
    final t = (tag ?? '').toUpperCase();
    if (t.contains('TEMPO REAL') || t.contains('RECEITA')) return MetaColors.emerald;
    if (t.contains('PAGAMENTO') || t.contains('FINANCEIRO')) return const Color(0xFF10B981);
    if (t.contains('GAMIFICAÇÃO') || t.contains('AUTOMAÇÃO')) return const Color(0xFFF59E0B);
    if (t.contains('PERFORMANCE') || t.contains('INFRA')) return MetaColors.accentBlue;
    return MetaColors.textSecondary;
  }

  @override
  Widget build(BuildContext context) {
    final version = _data?['version'] ?? '1.8.0';
    final changelog = _data?['changelog'] as Map<String, dynamic>? ?? {};

    final studentItems = (changelog['student'] as List<dynamic>?) ?? [];
    final trainerItems = (changelog['trainer'] as List<dynamic>?) ?? [];
    final adminItems = (changelog['admin'] as List<dynamic>?) ?? [];

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: MetaColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: MetaColors.surfaceHighlight, width: 1.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle Bar
            const SizedBox(height: 12),
            Container(
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: MetaColors.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 18),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: MetaColors.emerald.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.celebration_rounded,
                      color: MetaColors.emerald,
                      size: 24,
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
                              'Versão $version',
                              style: const TextStyle(
                                color: MetaColors.emerald,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: MetaColors.surfaceHighlight,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _userRole == 'trainer'
                                    ? 'PROFESSOR'
                                    : (_userRole == 'admin' ? 'ADMIN' : 'ALUNO'),
                                style: const TextStyle(
                                  color: MetaColors.textSecondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Novidades da Atualização',
                          style: TextStyle(
                            color: MetaColors.textPrimary,
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: MetaColors.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),
            const Divider(color: MetaColors.surfaceHighlight, height: 1),

            // Conteúdo dinâmico filtrado por perfil
            Flexible(
              child: _isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40.0),
                        child: CircularProgressIndicator(color: MetaColors.emerald),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. ADMIN: Vê Sistema & Infraestrutura
                          if (_userRole == 'admin' && adminItems.isNotEmpty) ...[
                            _buildSectionHeader(
                              title: 'SISTEMA & INFRAESTRUTURA',
                              icon: Icons.admin_panel_settings_rounded,
                              color: MetaColors.accentBlue,
                            ),
                            const SizedBox(height: 10),
                            ...adminItems.map((it) => _buildChangeItem(it)),
                            const SizedBox(height: 22),
                          ],

                          // 2. PROFESSOR e ADMIN: Vêem melhorias de Consultoria do Professor
                          if ((_userRole == 'trainer' || _userRole == 'admin') &&
                              trainerItems.isNotEmpty) ...[
                            _buildSectionHeader(
                              title: 'PARA SUA CONSULTORIA & NEGÓCIO',
                              icon: Icons.business_center_rounded,
                              color: MetaColors.emerald,
                            ),
                            const SizedBox(height: 10),
                            ...trainerItems.map((it) => _buildChangeItem(it)),
                            const SizedBox(height: 22),
                          ],

                          // 3. ALUNO, PROFESSOR e ADMIN: Vêem melhorias do Aluno
                          // (Professor vê para saber o que mudou na experiência do seu aluno)
                          if (studentItems.isNotEmpty) ...[
                            _buildSectionHeader(
                              title: _userRole == 'client'
                                  ? 'MELHORIAS NO SEU TREINO'
                                  : 'PARA OS SEUS ALUNOS',
                              icon: Icons.fitness_center_rounded,
                              color: const Color(0xFFF59E0B),
                            ),
                            const SizedBox(height: 10),
                            ...studentItems.map((it) => _buildChangeItem(it)),
                          ],
                        ],
                      ),
                    ),
            ),

            // Rodapé com botão de confirmação
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: SquircleButton(
                  label: 'Entendido, vamos lá!',
                  icon: Icons.check_circle_outline_rounded,
                  isPrimary: true,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: color,
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  Widget _buildChangeItem(dynamic item) {
    final title = item['title']?.toString() ?? '';
    final desc = item['description']?.toString() ?? '';
    final iconKey = item['icon']?.toString();
    final tag = item['tag']?.toString();

    final icon = _mapIcon(iconKey);
    final tagColor = _mapTagColor(tag);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MetaColors.surfaceHighlight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: MetaColors.surfaceHighlight.withValues(alpha: 0.8),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: tagColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: tagColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (tag != null && tag.isNotEmpty) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: tagColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      tag,
                      style: TextStyle(
                        color: tagColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
                Text(
                  title,
                  style: const TextStyle(
                    color: MetaColors.textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  desc,
                  style: const TextStyle(
                    color: MetaColors.textSecondary,
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
}

