import 'package:flutter/material.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/login_screen.dart';
import 'features/client/active_workout_screen.dart';
import 'features/trainer/anamnesis_screen.dart';
import 'features/trainer/trainer_students_screen.dart';
import 'features/assistant/b2b_assistant_screen.dart';
import 'features/subscription/subscription_screen.dart';
import 'services/auth_service.dart';

import 'core/theme/theme_controller.dart';
import 'core/widgets/theme_toggle_button.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const B2BPersonalIaApp());
}

class B2BPersonalIaApp extends StatelessWidget {
  const B2BPersonalIaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        return MaterialApp(
          title: 'B2B Personal IA',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeController.instance.themeMode,
          home: const LoginScreen(),
        );
      },
    );
  }
}

class MainShellScreen extends StatefulWidget {
  final int initialIndex;
  final String activeRole; // 'trainer' ou 'client'
  final String userName;

  const MainShellScreen({
    super.key,
    this.initialIndex = 0,
    this.activeRole = 'trainer',
    this.userName = 'Carlos Personal (Demo)',
  });

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  bool get _isTrainer => widget.activeRole == 'trainer';

  List<Widget> _buildScreens() {
    if (_isTrainer) {
      return [
        TrainerStudentsScreen(
          onSelectStudentForPlan: (studentId, studentName) {
            setState(() => _currentIndex = 1); // Switch to Anamnesis
          },
        ),
        const TrainerAnamnesisScreen(),
        const B2BAssistantScreen(isStudentView: false),
        const SubscriptionScreen(),
        const ActiveWorkoutScreen(), // Simulated student view
      ];
    } else {
      return const [
        ActiveWorkoutScreen(),
        B2BAssistantScreen(isStudentView: true),
      ];
    }
  }

  List<_NavDestinationItem> _buildNavItems() {
    if (_isTrainer) {
      return const [
        _NavDestinationItem(
          icon: Icons.people_outline_rounded,
          activeIcon: Icons.people_rounded,
          label: 'Alunos',
          activeColor: AppColors.trainerEmerald,
        ),
        _NavDestinationItem(
          icon: Icons.assignment_outlined,
          activeIcon: Icons.assignment_rounded,
          label: 'Prescrição IA',
          activeColor: AppColors.trainerEmerald,
        ),
        _NavDestinationItem(
          icon: Icons.smart_toy_outlined,
          activeIcon: Icons.smart_toy_rounded,
          label: 'Assistente B2B',
          activeColor: AppColors.trainerIndigo,
        ),
        _NavDestinationItem(
          icon: Icons.workspace_premium_outlined,
          activeIcon: Icons.workspace_premium_rounded,
          label: 'Planos SaaS',
          activeColor: AppColors.studentAmber,
        ),
        _NavDestinationItem(
          icon: Icons.fitness_center_outlined,
          activeIcon: Icons.fitness_center_rounded,
          label: 'Simular Salão',
          activeColor: AppColors.studentCyan,
        ),
      ];
    } else {
      return const [
        _NavDestinationItem(
          icon: Icons.fitness_center_outlined,
          activeIcon: Icons.fitness_center_rounded,
          label: 'Meu Treino (Salão)',
          activeColor: AppColors.studentCyan,
        ),
        _NavDestinationItem(
          icon: Icons.smart_toy_outlined,
          activeIcon: Icons.smart_toy_rounded,
          label: 'Assistente IA',
          activeColor: AppColors.studentCyan,
        ),
      ];
    }
  }

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.trainerSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.trainerBorder),
        ),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: AppColors.studentAmber),
            SizedBox(width: 8),
            Text('Trocar Perfil / Sair', style: TextStyle(color: AppColors.textPrimary, fontSize: 18)),
          ],
        ),
        content: Text(
          'Deseja sair da conta de ${widget.userName} e voltar para a tela de autenticação?',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.studentAmber,
              foregroundColor: Colors.black,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sair e Trocar', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (shouldLogout == true && mounted) {
      await AuthService.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => LoginScreen(initialRole: widget.activeRole),
          ),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screens = _buildScreens();
    final navItems = _buildNavItems();

    // Guard against index out of range when switching roles
    if (_currentIndex >= screens.length) {
      _currentIndex = 0;
    }

    final isWideScreen = MediaQuery.of(context).size.width >= 850;
    final roleColor = _isTrainer ? AppColors.trainerEmerald : AppColors.studentCyan;

    if (isWideScreen) {
      // Desktop / Web Layout with Left Sidebar
      return Scaffold(
        backgroundColor: AppColors.studentBg,
        body: Row(
          children: [
            // Left Sidebar
            Container(
              width: 250,
              decoration: const BoxDecoration(
                color: Color(0xFF070B12),
                border: Border(right: BorderSide(color: Color(0xFF161E2E), width: 1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  // App Brand Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [roleColor.withValues(alpha: 0.3), roleColor.withValues(alpha: 0.05)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(color: roleColor, width: 1.5),
                          ),
                          child: Icon(
                            _isTrainer ? Icons.sports_gymnastics : Icons.fitness_center_rounded,
                            color: roleColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'B2B PERSONAL IA',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.0,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              _isTrainer ? 'TREINADOR PRO' : 'ALUNO NO SALÃO',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: roleColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Divider(color: Color(0xFF161E2E), height: 1),
                  const SizedBox(height: 12),

                  // Navigation Links
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      itemCount: navItems.length,
                      itemBuilder: (ctx, idx) {
                        final item = navItems[idx];
                        final isSelected = _currentIndex == idx;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          child: InkWell(
                            onTap: () => setState(() => _currentIndex = idx),
                            borderRadius: BorderRadius.circular(12),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? item.activeColor.withValues(alpha: 0.12)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? item.activeColor.withValues(alpha: 0.5)
                                      : Colors.transparent,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isSelected ? item.activeIcon : item.icon,
                                    color: isSelected ? item.activeColor : AppColors.textMuted,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      item.label,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                        color: isSelected ? item.activeColor : AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  if (isSelected)
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: item.activeColor,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: item.activeColor,
                                            blurRadius: 6,
                                          ),
                                        ],
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

                  // Theme Toggle Pill in Sidebar
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'MODO VISUAL',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: AppColors.textMuted,
                          ),
                        ),
                        ThemeToggleButton(),
                      ],
                    ),
                  ),

                  // Bottom User Profile & Logout
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF1E293B)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: roleColor.withValues(alpha: 0.2),
                          child: Text(
                            widget.userName.isNotEmpty ? widget.userName[0].toUpperCase() : 'U',
                            style: TextStyle(
                              color: roleColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.userName,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                _isTrainer ? 'Treinador Pro' : 'Aluno',
                                style: TextStyle(
                                  color: roleColor,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.logout_rounded, size: 18, color: AppColors.textMuted),
                          tooltip: 'Sair / Trocar Perfil',
                          onPressed: _logout,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Main Content Area
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: screens,
              ),
            ),
          ],
        ),
      );
    } else {
      // Mobile Layout with Top Header Pill & Bottom Navigation
      return Scaffold(
        body: Column(
          children: [
            // Top Compact Role & User Banner
            Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 6,
                bottom: 8,
                left: 14,
                right: 14,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFF070B12),
                border: Border(bottom: BorderSide(color: Color(0xFF161E2E))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: roleColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: roleColor.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(color: roleColor, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _isTrainer ? 'Treinador' : 'Aluno',
                              style: TextStyle(
                                color: roleColor,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.userName,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const ThemeToggleButton(compact: true),
                      const SizedBox(width: 4),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.logout_rounded, size: 14, color: AppColors.textMuted),
                        label: const Text('Sair', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                        onPressed: _logout,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Screen Content
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: screens,
              ),
            ),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF070B12),
            border: Border(top: BorderSide(color: Color(0xFF161E2E), width: 1)),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(navItems.length, (idx) {
                  final item = navItems[idx];
                  final isSelected = _currentIndex == idx;
                  return _NavBarItem(
                    icon: isSelected ? item.activeIcon : item.icon,
                    label: item.label,
                    isSelected: isSelected,
                    activeColor: item.activeColor,
                    onTap: () => setState(() => _currentIndex = idx),
                  );
                }),
              ),
            ),
          ),
        ),
      );
    }
  }
}

class _NavDestinationItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final Color activeColor;

  const _NavDestinationItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.activeColor,
  });
}

class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final Color activeColor;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? activeColor : AppColors.textMuted,
              size: 20,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                color: isSelected ? activeColor : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
