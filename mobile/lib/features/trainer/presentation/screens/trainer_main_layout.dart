import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/widgets/meta_components.dart';
import '../../../../services/auth_service.dart';
import '../../../../services/workout_service.dart';
import '../../../auth/auth_gate.dart';
import '../../../auth/account_screen.dart';
import '../../../auth/login_screen.dart';
import '../../trainer_students_screen.dart';
import 'trainer_workouts_screen.dart';
import 'trainer_social_screen.dart';
import 'trainer_business_screen.dart';
import '../../../../core/widgets/app_version_footer.dart';

/// Layout base de navegação do aplicativo do Personal Trainer.
///
/// Implementa a fundação Edge-to-Edge nativa com o Design System da Meta
/// (Dark Mode, WhatsApp Business) e NavigationBar (Material 3).
class TrainerMainLayout extends StatefulWidget {
  final int initialIndex;
  final ValueChanged<int>? onTabChanged;
  final List<Widget>? screens;

  const TrainerMainLayout({
    super.key,
    this.initialIndex = 0,
    this.onTabChanged,
    this.screens,
  });

  @override
  State<TrainerMainLayout> createState() => _TrainerMainLayoutState();
}

class _TrainerMainLayoutState extends State<TrainerMainLayout> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        AppVersionFooter.checkAndShowAutoModal(context);
      }
    });
  }

  void _onDestinationSelected(int index) {
    if (index == 0) {
      WorkoutService.studentsRefreshNotifier.value++;
    }
    if (_currentIndex != index) {
      setState(() {
        _currentIndex = index;
      });
      widget.onTabChanged?.call(index);
    }
  }

  List<Widget> _buildScreens() => [
        ...(widget.screens ?? [
        TrainerStudentsScreen(),
        TrainerWorkoutsScreen(),
        TrainerSocialScreen(),
        TrainerBusinessScreen(),
        ]),
        AccountScreen(
          currentRole: 'trainer',
          onRoleSelected: _switchRole,
          onSignOut: _signOut,
        ),
      ];

  Future<void> _switchRole(String role) async {
    if (role == 'trainer') return;
    await AuthService.setActiveRole(role);
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AuthGate(skipBiometric: true)),
      (_) => false,
    );
  }

  Future<void> _signOut(bool allDevices) async {
    await AuthService.signOut(allDevices: allDevices);
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen(initialRole: 'trainer')),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = _buildScreens();
    final activeIndex = _currentIndex.clamp(0, screens.length - 1);
    final isDark = MetaColors.isDark(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Scaffold(
        extendBody: true,
        backgroundColor: isDark ? MetaColors.background : MetaColors.lightBackground,
        body: IndexedStack(
          index: activeIndex,
          children: screens,
        ),
        bottomNavigationBar: OneUiFloatingNavBar(
          selectedIndex: activeIndex,
          onDestinationSelected: _onDestinationSelected,
          items: const [
            OneUiNavItem(
              icon: Icons.chat_bubble_outline,
              selectedIcon: Icons.chat_bubble,
              label: 'Alunos',
            ),
            OneUiNavItem(
              icon: Icons.list_alt,
              selectedIcon: Icons.list,
              label: 'Treinos',
            ),
            OneUiNavItem(
              icon: Icons.groups_outlined,
              selectedIcon: Icons.groups,
              label: 'Social',
            ),
            OneUiNavItem(
              icon: Icons.store_outlined,
              selectedIcon: Icons.store,
              label: 'Vitrine',
            ),
            OneUiNavItem(
              icon: Icons.manage_accounts_outlined,
              selectedIcon: Icons.manage_accounts,
              label: 'Conta',
            ),
          ],
        ),
      ),
    );
  }
}

/// Placeholder simples com texto centralizado para representar abas enquanto não integradas.
class TrainerTabPlaceholder extends StatelessWidget {
  final String title;

  const TrainerTabPlaceholder({
    super.key,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        title,
        style: const TextStyle(
          color: MetaColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
      ),
    );
  }
}
