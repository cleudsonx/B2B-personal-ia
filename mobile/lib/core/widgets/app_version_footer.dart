import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_changelog.dart';
import '../config/app_config.dart';
import '../utils/pwa_installer.dart';
import 'meta_components.dart';
import '../../services/auth_service.dart';

/// Rodapé elegante de versionamento para o ecossistema Mr. Coach / Shaipados.
///
/// Exibe a versão oficial (`v1.3.9 • Build 2026102817`), com modal dinâmico
/// de changelog alimentado por [AppChangelog] e suporte a auto-abertura no primeiro acesso à versão.
class AppVersionFooter extends StatelessWidget {
  final EdgeInsetsGeometry padding;
  final String? userRole;
  static const String _lastSeenBuildKey = 'pwa_last_seen_changelog_build';
  static const String _lastSeenVersionKey = 'pwa_last_seen_changelog_version';

  const AppVersionFooter({
    super.key,
    this.padding = const EdgeInsets.only(top: 24, bottom: 32),
    this.userRole,
  });

  /// Controla a exibição automática do modal de novidades.
  /// Pode ser desativado em suítes de testes automatizados para evitar timers pendentes.
  static bool enableAutoModal = true;
  static bool _isCheckingOrShowing = false;
  static bool _hasAutoShown = false;

  /// Verifica se o usuário já viu as novidades desta versão. Se for a primeira vez
  /// de uma nova versão semântica, exibe o modal automaticamente após o carregamento da tela.
  static Future<void> checkAndShowAutoModal(
    BuildContext context, {
    String? roleOverride,
  }) async {
    if (!enableAutoModal || _isCheckingOrShowing || _hasAutoShown) return;
    _isCheckingOrShowing = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSeenVersion = prefs.getString(_lastSeenVersionKey);
      final lastSeenBuild = prefs.getInt(_lastSeenBuildKey);
      final currentVersion = AppChangelog.current.version;
      final currentBuild = AppConfig.buildNumber > AppChangelog.current.buildNumber
          ? AppConfig.buildNumber
          : AppChangelog.current.buildNumber;

      // Abre automaticamente se o usuário ainda não visualizou a versão semântica
      // OU se um novo build superior foi publicado (garantindo que o alerta chegue no iOS, Android e Web)
      final bool isFirstTimeOrNewVersion = lastSeenVersion == null || lastSeenVersion != currentVersion;
      final bool isNewerBuild = lastSeenBuild == null ? (lastSeenVersion == null) : (currentBuild > lastSeenBuild);

      if (isFirstTimeOrNewVersion || isNewerBuild) {
        await prefs.setString(_lastSeenVersionKey, currentVersion);
        await prefs.setInt(_lastSeenBuildKey, currentBuild);
        _hasAutoShown = true;
        if (context.mounted) {
          Future.delayed(const Duration(milliseconds: 1000), () {
            if (context.mounted) {
              showReleaseNotesModal(context, roleOverride: roleOverride);
            }
          });
        }
      }
    } catch (_) {
    } finally {
      Future.delayed(const Duration(milliseconds: 1500), () {
        _isCheckingOrShowing = false;
      });
    }
  }

  /// Exibe o modal interativo com as novidades da versão atual ou de atualização remota disponível
  static void showReleaseNotesModal(
    BuildContext context, {
    String? roleOverride,
    Map<String, dynamic>? remoteReleaseData,
  }) {
    if (!context.mounted) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _ReleaseNotesModalContent(
        roleOverride: roleOverride,
        remoteReleaseData: remoteReleaseData,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = MetaColors.isDark(context);
    final textColor = isDark ? MetaColors.textPrimary : MetaColors.lightTextPrimary;
    final subtextColor = isDark ? MetaColors.textSecondary : MetaColors.lightTextSecondary;
    final pillBg = isDark
        ? MetaColors.surfaceHighlight.withValues(alpha: 0.5)
        : MetaColors.lightSurfaceHighlight;
    final pillBorder = isDark ? MetaColors.border : MetaColors.lightBorder;

    return Padding(
      padding: padding,
      child: Center(
        child: InkWell(
          onTap: () => showReleaseNotesModal(context, roleOverride: userRole),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: pillBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: pillBorder),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: MetaColors.emerald,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x6610B981),
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Mr. Coach AI',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '•',
                        style: TextStyle(
                          color: subtextColor,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        AppConfig.fullVersionString,
                        style: const TextStyle(
                          color: MetaColors.emerald,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Toque para ver as novidades',
                  style: TextStyle(
                    color: subtextColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReleaseNotesModalContent extends StatefulWidget {
  final String? roleOverride;
  final Map<String, dynamic>? remoteReleaseData;

  const _ReleaseNotesModalContent({
    this.roleOverride,
    this.remoteReleaseData,
  });

  @override
  State<_ReleaseNotesModalContent> createState() => _ReleaseNotesModalContentState();
}

class _ReleaseNotesModalContentState extends State<_ReleaseNotesModalContent> {
  bool _showPreviousReleases = false;
  String _selectedFilter = 'all';
  late String _currentRole;

  static String _normalizeRole(String? role) {
    final r = role?.trim().toLowerCase() ?? 'client';
    if (r == 'admin' || r == 'administrator') return 'admin';
    if (r == 'trainer' || r == 'coach' || r == 'personal') return 'trainer';
    return 'client';
  }

  @override
  void initState() {
    super.initState();
    _currentRole = _normalizeRole(widget.roleOverride);
    if (widget.roleOverride == null) {
      _loadUserRole();
    }
  }

  Future<void> _loadUserRole() async {
    try {
      final profile = await AuthService.getCurrentProfile();
      final roles = AuthService.availableRoles(profile);
      final resolved = _normalizeRole(
        roles.contains('admin') ? 'admin' : profile?['role']?.toString(),
      );
      if (mounted) {
        setState(() {
          _currentRole = resolved;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _currentRole = 'client';
        });
      }
    }
  }

  List<ChangelogItem> _filterItems(List<ChangelogItem> allItems, String targetRole) {
    return allItems.where((it) {
      if (it.targetRoles.contains(targetRole)) return true;
      if ((targetRole == 'student' || targetRole == 'client') &&
          (it.targetRoles.contains('student') || it.targetRoles.contains('client'))) {
        return true;
      }
      return false;
    }).toList();
  }

  String _getRoleSummary(String role, [String filter = 'all']) {
    if (filter == 'student') {
      return 'Para seus Treinos: Treine com a nova experiência editorial One UI 7, cards temáticos vivos, marcas d\'água 3D vetoriais, seletor de estilo de cards, descanso háptico e autenticação 2FA inteligente!';
    }
    if (filter == 'trainer') {
      return 'Para sua Consultoria: Cockpit moderno com cards de dicas de negócio e saque Pix no padrão One UI 7, pareamento do WhatsApp por código de 8 dígitos e 2FA confiável de 30 dias.';
    }
    if (filter == 'admin') {
      return 'Plataforma & Infra: Blindagem de segurança 2FA HMAC-SHA256 multi-canal (WhatsApp, e-mail e códigos de backup), persistência de volumes na VPS e cache Redis na Evolution API.';
    }
    if (role == 'admin') {
      return 'Visão Estratégica: Arquitetura offline-first, blindagem de segurança 2FA multi-canal, redesign One UI 7 para alunos e cockpit tático para treinadores.';
    }
    if (role == 'trainer') {
      return 'Para sua Consultoria: Design editorial One UI 7 para suas dicas de negócio e alunos, pareamento WhatsApp com código de 8 dígitos e 2FA confiável de 30 dias.';
    }
    return 'Para seus Treinos: Treine com a nova experiência editorial One UI 7, cards temáticos vivos, marcas d\'água 3D vetoriais, seletor de estilo de cards e 2FA inteligente!';
  }

  Widget _buildRoleSectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 7),
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String badge) {
    Color bg = MetaColors.emerald.withValues(alpha: 0.15);
    Color border = MetaColors.emerald.withValues(alpha: 0.35);
    Color text = MetaColors.emerald;

    switch (badge.toUpperCase()) {
      case 'NOVO':
        bg = MetaColors.emerald.withValues(alpha: 0.15);
        border = MetaColors.emerald.withValues(alpha: 0.4);
        text = MetaColors.emerald;
        break;
      case 'MELHORIA':
      case 'UX':
        bg = Colors.amber.withValues(alpha: 0.15);
        border = Colors.amber.withValues(alpha: 0.4);
        text = Colors.amber;
        break;
      case 'CORREÇÃO':
        bg = Colors.lightBlue.withValues(alpha: 0.15);
        border = Colors.lightBlue.withValues(alpha: 0.4);
        text = Colors.lightBlueAccent;
        break;
      case 'ESTABILIDADE':
      case 'SEGURANÇA':
      case 'PRIVACIDADE':
        bg = Colors.purple.withValues(alpha: 0.15);
        border = Colors.purple.withValues(alpha: 0.4);
        text = Colors.purpleAccent;
        break;
      case 'B2B':
      case 'IA':
        bg = const Color(0xFF6366F1).withValues(alpha: 0.18);
        border = const Color(0xFF6366F1).withValues(alpha: 0.45);
        text = const Color(0xFF818CF8);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border, width: 0.8),
      ),
      child: Text(
        badge,
        style: TextStyle(
          color: text,
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildChangelogItem({
    required IconData icon,
    required String title,
    required String description,
    required Color textColor,
    required Color subtextColor,
    String? badge,
    bool isFeatured = false,
    bool isDark = true,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isFeatured ? 10 : 8),
      child: Container(
        padding: isFeatured ? const EdgeInsets.all(10) : const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        decoration: isFeatured
            ? BoxDecoration(
                color: MetaColors.emerald.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: MetaColors.emerald.withValues(alpha: 0.35),
                  width: 1.2,
                ),
              )
            : null,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isFeatured
                    ? MetaColors.emerald.withValues(alpha: 0.2)
                    : (isDark ? MetaColors.surfaceHighlight : const Color(0xFFF1F5F9)),
                borderRadius: BorderRadius.circular(8),
                border: isFeatured
                    ? null
                    : Border.all(
                        color: isDark ? MetaColors.border.withValues(alpha: 0.4) : const Color(0xFFE2E8F0),
                        width: 1,
                      ),
              ),
              child: Icon(icon, size: 16, color: MetaColors.emerald),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isFeatured || (badge != null && badge.isNotEmpty)) ...[
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (badge != null && badge.isNotEmpty) _buildBadge(badge),
                        if (isFeatured)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: MetaColors.emerald.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: MetaColors.emerald.withValues(alpha: 0.4), width: 0.8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.star_rounded, size: 10, color: MetaColors.emerald),
                                SizedBox(width: 3),
                                Text(
                                  'DESTAQUE',
                                  style: TextStyle(
                                    color: MetaColors.emerald,
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    title,
                    style: TextStyle(
                      color: textColor,
                      fontSize: isFeatured ? 13.5 : 12.5,
                      fontWeight: isFeatured ? FontWeight.bold : FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: TextStyle(
                      color: subtextColor,
                      fontSize: isFeatured ? 12 : 11.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = MetaColors.isDark(context);
    final bg = isDark ? MetaColors.surface : MetaColors.lightSurface;
    final border = isDark ? MetaColors.border : MetaColors.lightBorder;
    final textColor = isDark ? MetaColors.textPrimary : MetaColors.lightTextPrimary;
    final subtextColor = isDark ? MetaColors.textSecondary : MetaColors.lightTextSecondary;

    final isRemoteUpdate = widget.remoteReleaseData != null;
    final remoteVersion = widget.remoteReleaseData?['version']?.toString() ?? '';
    final remoteBuild = widget.remoteReleaseData?['build']?.toString() ?? '';
    final remoteNotes = widget.remoteReleaseData?['notes']?.toString();
    final remoteChangelog = widget.remoteReleaseData?['changelog'];

    final currentRelease = AppChangelog.current;
    final previousReleases = AppChangelog.previousReleases;

    final isTrainer = _currentRole == 'trainer';
    final isAdmin = _currentRole == 'admin';
    final isClient = _currentRole == 'client';

    List<ChangelogItem> trainerItems = [];
    List<ChangelogItem> studentItems = [];
    List<ChangelogItem> adminItems = [];

    if (isRemoteUpdate && remoteChangelog is Map) {
      ChangelogItem parseRemoteItem(Map item, List<String> roles) {
        return ChangelogItem(
          icon: roles.contains('trainer')
              ? Icons.business_center_rounded
              : roles.contains('admin')
                  ? Icons.admin_panel_settings_rounded
                  : Icons.fitness_center_rounded,
          title: item['title']?.toString() ?? '',
          description: item['description']?.toString() ?? '',
          badge: item['badge']?.toString() ?? 'NOVO',
          targetRoles: roles,
        );
      }

      if (remoteChangelog['student'] is List) {
        studentItems = (remoteChangelog['student'] as List)
            .whereType<Map>()
            .map((it) => parseRemoteItem(it, ['student']))
            .toList();
      }
      if (remoteChangelog['trainer'] is List) {
        trainerItems = (remoteChangelog['trainer'] as List)
            .whereType<Map>()
            .map((it) => parseRemoteItem(it, ['trainer']))
            .toList();
      }
      if (remoteChangelog['admin'] is List) {
        adminItems = (remoteChangelog['admin'] as List)
            .whereType<Map>()
            .map((it) => parseRemoteItem(it, ['admin']))
            .toList();
      }
    } else if (isRemoteUpdate && (remoteNotes != null && remoteNotes.isNotEmpty)) {
      studentItems = [
        ChangelogItem(
          icon: Icons.rocket_launch_rounded,
          title: 'Melhorias de Desempenho e Estabilidade',
          description: remoteNotes,
          badge: 'ATUALIZAÇÃO',
          targetRoles: ['student'],
        ),
      ];
    } else {
      trainerItems = _filterItems(currentRelease.highlights, 'trainer');
      studentItems = _filterItems(currentRelease.highlights, 'student');
      adminItems = _filterItems(currentRelease.highlights, 'admin');
    }

    int pertinentCount = 0;
    if (_selectedFilter == 'all') {
      if (isAdmin) {
        pertinentCount = adminItems.length + trainerItems.length + studentItems.length;
      } else if (isTrainer) {
        pertinentCount = trainerItems.length + studentItems.length;
      } else {
        pertinentCount = studentItems.length;
      }
    } else if (_selectedFilter == 'student') {
      pertinentCount = studentItems.length;
    } else if (_selectedFilter == 'trainer') {
      pertinentCount = trainerItems.length;
    } else if (_selectedFilter == 'admin') {
      pertinentCount = adminItems.length;
    }

    final activeBannerColor = _selectedFilter == 'admin'
        ? MetaColors.accentBlue
        : (_selectedFilter == 'trainer'
            ? MetaColors.emerald
            : (_selectedFilter == 'student'
                ? const Color(0xFFF59E0B)
                : (isAdmin
                    ? MetaColors.accentBlue
                    : (isTrainer ? MetaColors.emerald : const Color(0xFFF59E0B)))));

    final activeBannerIcon = _selectedFilter == 'admin'
        ? Icons.admin_panel_settings_rounded
        : (_selectedFilter == 'trainer'
            ? Icons.business_center_rounded
            : (_selectedFilter == 'student'
                ? Icons.fitness_center_rounded
                : (isAdmin
                    ? Icons.admin_panel_settings_rounded
                    : (isTrainer ? Icons.business_center_rounded : Icons.fitness_center_rounded))));

    final activeBannerTitle = _selectedFilter == 'admin'
        ? 'Visão Executiva: Novidades de Infraestrutura, Finanças e Plataforma'
        : (_selectedFilter == 'trainer'
            ? 'Perfil Personal: Novidades para sua Consultoria e Alunos'
            : (_selectedFilter == 'student'
                ? 'Perfil Aluno: Novidades para sua Rotina de Treino e Acesso'
                : (isAdmin
                    ? 'Visão Executiva: Novidades de Infraestrutura, Finanças e Plataforma'
                    : (isTrainer
                        ? 'Perfil Personal: Novidades para sua Consultoria e Alunos'
                        : 'Perfil Aluno: Novidades para sua Rotina de Treino e Acesso'))));

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.82,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: subtextColor.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: MetaColors.emerald.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: MetaColors.emerald.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Icon(
                      Icons.rocket_launch_rounded,
                      color: MetaColors.emerald,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mr. Coach Personal IA',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Wrap(
                          spacing: 6,
                          runSpacing: 2,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              isRemoteUpdate
                                  ? 'v$remoteVersion (Build $remoteBuild)'
                                  : currentRelease.fullTitle,
                              style: const TextStyle(
                                color: MetaColors.emerald,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                            Text(
                              isRemoteUpdate
                                  ? '• Atualização Disponível'
                                  : '• ${currentRelease.date}',
                              style: TextStyle(
                                color: isRemoteUpdate ? MetaColors.emerald : subtextColor,
                                fontSize: 11,
                                fontWeight: isRemoteUpdate ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Divider(color: border, height: 1),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    isRemoteUpdate ? 'O QUE VEM NA NOVA VERSÃO' : 'NOVIDADES DESTA VERSÃO',
                    style: TextStyle(
                      color: subtextColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? MetaColors.surfaceHighlight : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark ? MetaColors.border.withValues(alpha: 0.6) : const Color(0xFFCBD5E1),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      '$pertinentCount ${pertinentCount == 1 ? 'novidade' : 'novidades'}',
                      style: TextStyle(
                        color: isDark ? subtextColor : const Color(0xFF475569),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              // Banner de Segmentação de Perfil Ativo
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: activeBannerColor.withValues(alpha: isDark ? 0.12 : 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: activeBannerColor.withValues(alpha: isDark ? 0.28 : 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      activeBannerIcon,
                      size: 16,
                      color: activeBannerColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        activeBannerTitle,
                        style: TextStyle(
                          color: activeBannerColor,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // Resumo Textual Segmentado por Perfil
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? MetaColors.surfaceHighlight.withValues(alpha: 0.6)
                      : MetaColors.lightSurfaceHighlight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 16,
                      color: activeBannerColor,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _getRoleSummary(_currentRole, _selectedFilter),
                        style: TextStyle(
                          color: textColor,
                          fontSize: 12,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // Chips interativos de filtragem por perfil
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  ChoiceChip(
                    label: const Text('Visão Completa'),
                    selected: _selectedFilter == 'all',
                    onSelected: (_) => setState(() => _selectedFilter = 'all'),
                    selectedColor: MetaColors.emerald,
                    labelStyle: TextStyle(
                      color: _selectedFilter == 'all'
                          ? Colors.white
                          : (isDark ? subtextColor : const Color(0xFF475569)),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                    backgroundColor: isDark ? MetaColors.surfaceHighlight : const Color(0xFFF1F5F9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    side: BorderSide(
                      color: _selectedFilter == 'all'
                          ? Colors.transparent
                          : (isDark ? MetaColors.border.withValues(alpha: 0.6) : const Color(0xFFCBD5E1)),
                      width: 1,
                    ),
                  ),
                  if (studentItems.isNotEmpty)
                    ChoiceChip(
                      label: const Text('Para Alunos'),
                      selected: _selectedFilter == 'student',
                      onSelected: (_) => setState(() => _selectedFilter == 'student'),
                      selectedColor: const Color(0xFFF59E0B),
                      labelStyle: TextStyle(
                        color: _selectedFilter == 'student'
                            ? Colors.white
                            : (isDark ? subtextColor : const Color(0xFF475569)),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                      backgroundColor: isDark ? MetaColors.surfaceHighlight : const Color(0xFFF1F5F9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      side: BorderSide(
                        color: _selectedFilter == 'student'
                            ? Colors.transparent
                            : (isDark ? MetaColors.border.withValues(alpha: 0.6) : const Color(0xFFCBD5E1)),
                        width: 1,
                      ),
                    ),
                  if (trainerItems.isNotEmpty)
                    ChoiceChip(
                      label: const Text('Para Personal'),
                      selected: _selectedFilter == 'trainer',
                      onSelected: (_) => setState(() => _selectedFilter == 'trainer'),
                      selectedColor: MetaColors.emerald,
                      labelStyle: TextStyle(
                        color: _selectedFilter == 'trainer'
                            ? Colors.white
                            : (isDark ? subtextColor : const Color(0xFF475569)),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                      backgroundColor: isDark ? MetaColors.surfaceHighlight : const Color(0xFFF1F5F9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      side: BorderSide(
                        color: _selectedFilter == 'trainer'
                            ? Colors.transparent
                            : (isDark ? MetaColors.border.withValues(alpha: 0.6) : const Color(0xFFCBD5E1)),
                        width: 1,
                      ),
                    ),
                  if (adminItems.isNotEmpty)
                    ChoiceChip(
                      label: const Text('Plataforma & Negócio'),
                      selected: _selectedFilter == 'admin',
                      onSelected: (_) => setState(() => _selectedFilter == 'admin'),
                      selectedColor: MetaColors.accentBlue,
                      labelStyle: TextStyle(
                        color: _selectedFilter == 'admin'
                            ? Colors.white
                            : (isDark ? subtextColor : const Color(0xFF475569)),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                      backgroundColor: isDark ? MetaColors.surfaceHighlight : const Color(0xFFF1F5F9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      side: BorderSide(
                        color: _selectedFilter == 'admin'
                            ? Colors.transparent
                            : (isDark ? MetaColors.border.withValues(alpha: 0.6) : const Color(0xFFCBD5E1)),
                        width: 1,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              // Renderização segmentada e inteligente por perfil
              Builder(
                builder: (context) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. ADMIN / PLATAFORMA: Vê Sistema & Infraestrutura
                      if (adminItems.isNotEmpty && (_selectedFilter == 'admin' || (_selectedFilter == 'all' && isAdmin))) ...[
                        _buildRoleSectionHeader(
                          'SISTEMA & INFRAESTRUTURA',
                          Icons.admin_panel_settings_rounded,
                          MetaColors.accentBlue,
                        ),
                        ...adminItems.asMap().entries.map(
                          (entry) => _buildChangelogItem(
                            icon: entry.value.icon,
                            title: entry.value.title,
                            description: entry.value.description,
                            badge: entry.value.badge,
                            textColor: textColor,
                            subtextColor: subtextColor,
                            isFeatured: entry.key < 2,
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // 2. PROFESSOR / PERSONAL: Vê melhorias de Negócio / Consultoria
                      if (trainerItems.isNotEmpty && (_selectedFilter == 'trainer' || (_selectedFilter == 'all' && (isTrainer || isAdmin)))) ...[
                        _buildRoleSectionHeader(
                          'PARA SUA CONSULTORIA & NEGÓCIO',
                          Icons.business_center_rounded,
                          MetaColors.emerald,
                        ),
                        ...trainerItems.asMap().entries.map(
                          (entry) => _buildChangelogItem(
                            icon: entry.value.icon,
                            title: entry.value.title,
                            description: entry.value.description,
                            badge: entry.value.badge,
                            textColor: textColor,
                            subtextColor: subtextColor,
                            isFeatured: entry.key < 2,
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // 3. ALUNO: Vê melhorias de Treino do Aluno
                      if (studentItems.isNotEmpty && (_selectedFilter == 'student' || _selectedFilter == 'all')) ...[
                        _buildRoleSectionHeader(
                          isClient ? 'NOVIDADES NO SEU TREINO' : 'MELHORIAS PARA OS SEUS ALUNOS',
                          Icons.fitness_center_rounded,
                          const Color(0xFFF59E0B),
                        ),
                        ...studentItems.asMap().entries.map(
                          (entry) => _buildChangelogItem(
                            icon: entry.value.icon,
                            title: entry.value.title,
                            description: entry.value.description,
                            badge: entry.value.badge,
                            textColor: textColor,
                            subtextColor: subtextColor,
                            isFeatured: entry.key < 2,
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),

              if (previousReleases.isNotEmpty) ...[
                const SizedBox(height: 6),
                Center(
                  child: TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _showPreviousReleases = !_showPreviousReleases;
                      });
                    },
                    icon: Icon(
                      _showPreviousReleases
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.history_rounded,
                      size: 16,
                      color: subtextColor,
                    ),
                    label: Text(
                      _showPreviousReleases
                          ? 'Ocultar versões anteriores'
                          : 'Ver versões anteriores (${previousReleases.length})',
                      style: TextStyle(
                        color: subtextColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],

              if (_showPreviousReleases) ...[
                const SizedBox(height: 8),
                Divider(color: border, height: 1),
                const SizedBox(height: 14),
                ...previousReleases.map((release) {
                  final histItems = _filterItems(release.highlights, _currentRole);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 2,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              release.fullTitle,
                              style: TextStyle(
                                color: textColor.withValues(alpha: 0.85),
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              release.date,
                              style: TextStyle(
                                color: subtextColor,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (histItems.isNotEmpty)
                          ...histItems.map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Icon(
                                      item.icon,
                                      size: 13,
                                      color: MetaColors.emerald,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: RichText(
                                      text: TextSpan(
                                        style: TextStyle(
                                          color: subtextColor,
                                          fontSize: 11.5,
                                          height: 1.3,
                                        ),
                                        children: [
                                          TextSpan(
                                            text: '${item.title}: ',
                                            style: TextStyle(
                                              color: textColor.withValues(alpha: 0.9),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          TextSpan(text: item.description),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          Text(
                            release.summary,
                            style: TextStyle(
                              color: subtextColor,
                              fontSize: 11.5,
                              height: 1.3,
                            ),
                          ),
                      ],
                    ),
                  );
                }),
              ],

              const SizedBox(height: 14),
              if (isRemoteUpdate) ...[
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          Future.delayed(const Duration(milliseconds: 150), () {
                            PwaInstaller.triggerPwaReload();
                          });
                        },
                        icon: const Icon(Icons.bolt_rounded, size: 20),
                        label: const Text(
                          'Atualizar e Recarregar Agora',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: MetaColors.emerald,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Lembrar mais tarde',
                      style: TextStyle(
                        color: subtextColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ] else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      try {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setString(
                          AppVersionFooter._lastSeenVersionKey,
                          currentRelease.version,
                        );
                        await prefs.setInt(
                          AppVersionFooter._lastSeenBuildKey,
                          currentRelease.buildNumber,
                        );
                      } catch (_) {}
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MetaColors.emerald,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Entendido',
                      style: TextStyle(fontWeight: FontWeight.bold),
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
