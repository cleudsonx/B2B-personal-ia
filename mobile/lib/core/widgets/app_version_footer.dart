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
      final currentVersion = AppChangelog.current.version;
      final currentBuild = AppConfig.buildNumber > AppChangelog.current.buildNumber
          ? AppConfig.buildNumber
          : AppChangelog.current.buildNumber;

      // Abre automaticamente se nunca visualizou ou se a versão semântica mudou (ex: 1.8.0 -> 1.9.0)
      if (lastSeenVersion == null || lastSeenVersion != currentVersion) {
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
                Row(
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
      final resolved = _normalizeRole(
        profile?['is_admin'] == true ? 'admin' : profile?['role']?.toString(),
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
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: MetaColors.surfaceHighlight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: MetaColors.emerald),
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
                        title,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 6),
                      _buildBadge(badge),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: TextStyle(
                    color: subtextColor,
                    fontSize: 12,
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
    if (isAdmin) {
      pertinentCount = adminItems.length + trainerItems.length + studentItems.length;
    } else if (isTrainer) {
      pertinentCount = trainerItems.length + studentItems.length;
    } else {
      pertinentCount = studentItems.length;
    }

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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: MetaColors.surfaceHighlight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$pertinentCount novidades',
                      style: TextStyle(
                        color: subtextColor,
                        fontSize: 10,
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
                  color: (isAdmin
                          ? MetaColors.accentBlue
                          : (isTrainer ? MetaColors.emerald : const Color(0xFFF59E0B)))
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (isAdmin
                            ? MetaColors.accentBlue
                            : (isTrainer ? MetaColors.emerald : const Color(0xFFF59E0B)))
                        .withValues(alpha: 0.28),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isAdmin
                          ? Icons.admin_panel_settings_rounded
                          : (isTrainer
                              ? Icons.business_center_rounded
                              : Icons.fitness_center_rounded),
                      size: 16,
                      color: isAdmin
                          ? MetaColors.accentBlue
                          : (isTrainer ? MetaColors.emerald : const Color(0xFFF59E0B)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isAdmin
                            ? 'Visão Executiva: Novidades de Infraestrutura, Finanças e Plataforma'
                            : (isTrainer
                                ? 'Perfil Personal: Novidades para sua Consultoria e Alunos'
                                : 'Perfil Aluno: Novidades para sua Rotina de Treino e Acesso'),
                        style: TextStyle(
                          color: isAdmin
                              ? MetaColors.accentBlue
                              : (isTrainer ? MetaColors.emerald : const Color(0xFFF59E0B)),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
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
                      color: _selectedFilter == 'all' ? Colors.white : subtextColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                    backgroundColor: MetaColors.surfaceHighlight,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    side: BorderSide.none,
                  ),
                  if (studentItems.isNotEmpty)
                    ChoiceChip(
                      label: const Text('Para Alunos'),
                      selected: _selectedFilter == 'student',
                      onSelected: (_) => setState(() => _selectedFilter == 'student'),
                      selectedColor: const Color(0xFFF59E0B),
                      labelStyle: TextStyle(
                        color: _selectedFilter == 'student' ? Colors.white : subtextColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                      backgroundColor: MetaColors.surfaceHighlight,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      side: BorderSide.none,
                    ),
                  if (trainerItems.isNotEmpty && (isTrainer || isAdmin))
                    ChoiceChip(
                      label: const Text('Para Personal'),
                      selected: _selectedFilter == 'trainer',
                      onSelected: (_) => setState(() => _selectedFilter == 'trainer'),
                      selectedColor: MetaColors.emerald,
                      labelStyle: TextStyle(
                        color: _selectedFilter == 'trainer' ? Colors.white : subtextColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                      backgroundColor: MetaColors.surfaceHighlight,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      side: BorderSide.none,
                    ),
                  if (adminItems.isNotEmpty && isAdmin)
                    ChoiceChip(
                      label: const Text('Para Admin'),
                      selected: _selectedFilter == 'admin',
                      onSelected: (_) => setState(() => _selectedFilter == 'admin'),
                      selectedColor: MetaColors.accentBlue,
                      labelStyle: TextStyle(
                        color: _selectedFilter == 'admin' ? Colors.white : subtextColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                      backgroundColor: MetaColors.surfaceHighlight,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      side: BorderSide.none,
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
                      // 1. ADMIN: Vê Sistema & Infraestrutura
                      if (isAdmin && adminItems.isNotEmpty && (_selectedFilter == 'all' || _selectedFilter == 'admin')) ...[
                        _buildRoleSectionHeader('SISTEMA & INFRAESTRUTURA', Icons.admin_panel_settings_rounded, MetaColors.accentBlue),
                        ...adminItems.map(
                          (item) => _buildChangelogItem(
                            icon: item.icon,
                            title: item.title,
                            description: item.description,
                            badge: item.badge,
                            textColor: textColor,
                            subtextColor: subtextColor,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // 2. PROFESSOR e ADMIN: Vêem melhorias de Negócio / Consultoria
                      if ((isTrainer || isAdmin) && trainerItems.isNotEmpty && (_selectedFilter == 'all' || _selectedFilter == 'trainer')) ...[
                        _buildRoleSectionHeader('PARA SUA CONSULTORIA & NEGÓCIO', Icons.business_center_rounded, MetaColors.emerald),
                        ...trainerItems.map(
                          (item) => _buildChangelogItem(
                            icon: item.icon,
                            title: item.title,
                            description: item.description,
                            badge: item.badge,
                            textColor: textColor,
                            subtextColor: subtextColor,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // 3. ALUNO, PROFESSOR e ADMIN: Vêem melhorias de Treino do Aluno
                      // (Professor vê para saber o que mudou na experiência do seu aluno)
                      if (studentItems.isNotEmpty && (_selectedFilter == 'all' || _selectedFilter == 'student')) ...[
                        _buildRoleSectionHeader(
                          isClient ? 'NOVIDADES NO SEU TREINO' : 'MELHORIAS PARA OS SEUS ALUNOS',
                          Icons.fitness_center_rounded,
                          const Color(0xFFF59E0B),
                        ),
                        ...studentItems.map(
                          (item) => _buildChangelogItem(
                            icon: item.icon,
                            title: item.title,
                            description: item.description,
                            badge: item.badge,
                            textColor: textColor,
                            subtextColor: subtextColor,
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
                          PwaInstaller.triggerPwaReload();
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
