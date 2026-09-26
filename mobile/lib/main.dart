import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/app_config.dart';
import 'services/auth_service.dart';
import 'features/auth/login_screen.dart';
import 'features/client/active_workout_screen.dart';
import 'features/trainer/anamnesis_screen.dart';
import 'features/assistant/b2b_assistant_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa o cliente Supabase com a URL e Chave Anon configuradas
  try {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabaseAnonKey,
    );
  } catch (e) {
    debugPrint('Supabase já inicializado ou aviso: $e');
  }

  runApp(const B2BPersonalIaApp());
}

class B2BPersonalIaApp extends StatelessWidget {
  const B2BPersonalIaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'B2B Personal IA',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E3A8A), // Azul atlético profundo
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3B82F6),
          brightness: Brightness.dark,
        ),
      ),
      themeMode: ThemeMode.system,
      home: const AuthGate(),
    );
  }
}

/// Controla se exibe a tela de login ou a aplicação principal
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _bypassAuth = false;

  @override
  Widget build(BuildContext context) {
    if (_bypassAuth) {
      return MainShellScreen(
        onSignOut: () => setState(() => _bypassAuth = false),
      );
    }

    return StreamBuilder<AuthState>(
      stream: AuthService.onAuthStateChange,
      builder: (context, snapshot) {
        final session = AuthService.currentSession;

        if (session != null) {
          return MainShellScreen(
            onSignOut: () async {
              await AuthService.signOut();
            },
          );
        }

        return LoginScreen(
          onLoginSuccess: () => setState(() {}),
          onBypassDev: () => setState(() => _bypassAuth = true),
        );
      },
    );
  }
}

class MainShellScreen extends StatefulWidget {
  final VoidCallback onSignOut;

  const MainShellScreen({super.key, required this.onSignOut});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    ActiveWorkoutScreen(),
    TrainerAnamnesisScreen(),
    B2BAssistantScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('B2B Personal IA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, size: 20),
            tooltip: 'Sair da Conta',
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Encerrar Sessão'),
                  content: const Text('Deseja realmente sair da sua conta?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        widget.onSignOut();
                      },
                      child: const Text('Sair'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.fitness_center),
            selectedIcon: Icon(Icons.fitness_center, color: Colors.blue),
            label: 'Salão (Aluno)',
          ),
          NavigationDestination(
            icon: Icon(Icons.edit_calendar_outlined),
            selectedIcon: Icon(Icons.edit_calendar, color: Colors.blue),
            label: 'Prescrição (Treinador)',
          ),
          NavigationDestination(
            icon: Icon(Icons.smart_toy_outlined),
            selectedIcon: Icon(Icons.smart_toy, color: Colors.blue),
            label: 'Assistente B2B',
          ),
        ],
      ),
    );
  }
}
