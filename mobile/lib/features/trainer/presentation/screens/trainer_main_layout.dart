import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/widgets/meta_components.dart';
import '../../../../services/auth_service.dart';
import '../../../auth/auth_gate.dart';
import '../../../auth/account_screen.dart';
import '../../../auth/login_screen.dart';
import '../../trainer_students_screen.dart';
import 'trainer_workouts_screen.dart';
import 'trainer_social_screen.dart';
import 'trainer_business_screen.dart';

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
  }

  void _onDestinationSelected(int index) {
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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: MetaColors.background,
          indicatorColor: MetaColors.surfaceHighlight,
          elevation: 0,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: MetaColors.emerald, size: 24);
            }
            return const IconThemeData(
              color: MetaColors.textSecondary,
              size: 24,
            );
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(
                color: MetaColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              );
            }
            return const TextStyle(
              color: MetaColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            );
          }),
        ),
        child: Scaffold(
          backgroundColor: MetaColors.background,
          body: IndexedStack(
            index: activeIndex,
            children: screens,
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: activeIndex,
            onDestinationSelected: _onDestinationSelected,
            backgroundColor: MetaColors.background,
            indicatorColor: MetaColors.surfaceHighlight,
            elevation: 0,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.chat_bubble_outline),
                selectedIcon: Icon(Icons.chat_bubble),
                label: 'Alunos',
              ),
              NavigationDestination(
                icon: Icon(Icons.list_alt),
                selectedIcon: Icon(Icons.list),
                label: 'Treinos',
              ),
              NavigationDestination(
                icon: Icon(Icons.groups_outlined),
                selectedIcon: Icon(Icons.groups),
                label: 'Social',
              ),
              NavigationDestination(
                icon: Icon(Icons.store_outlined),
                selectedIcon: Icon(Icons.store),
                label: 'Vitrine',
              ),
              NavigationDestination(
                icon: Icon(Icons.manage_accounts_outlined),
                selectedIcon: Icon(Icons.manage_accounts),
                label: 'Conta',
              ),
            ],
          ),
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
