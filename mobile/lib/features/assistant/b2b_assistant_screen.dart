import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/meta_components.dart';
import '../../core/widgets/biomechanical_analysis_sheet.dart';
import '../../core/widgets/exercise_media_sheet.dart';
import '../../core/widgets/server_config_dialog.dart';
import '../../core/constants/ai_prompts.dart';
import '../../services/gemini_service.dart';
import '../../services/workout_service.dart';
import '../../services/auth_service.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/widgets/one_ui_glass_components.dart';
import '../../core/widgets/workout_guide_modal.dart';
import '../../core/widgets/whats_new_modal.dart';
import '../../core/widgets/thematic_editorial_card.dart';
import '../../core/widgets/thematic_watermarks.dart';
import '../../models/workout_plan_model.dart';
import '../../models/split_model.dart';
import '../../models/exercise_model.dart';
import '../../services/student_notification_service.dart';
import '../../core/widgets/ai_action_card.dart';
import '../client/student_profile_screen.dart';
import '../client/active_workout_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class B2BAssistantScreen extends StatefulWidget {
  final bool isStudentView;

  const B2BAssistantScreen({super.key, this.isStudentView = false});

  @override
  State<B2BAssistantScreen> createState() => _B2BAssistantScreenState();
}

class _B2BAssistantScreenState extends State<B2BAssistantScreen> {
  final TextEditingController _promptCtrl = TextEditingController();
  final List<_ChatMessage> _messages = [];
  bool _isLoading = false;
  String _selectedModelId = 'gemini-2.5-flash';

  String _selectedPillar = 'Todos';
  List<String> _studentExercises = [];
  WorkoutPlanModel? _cachedActivePlan;
  SplitModel? _todaySplit;
  List<ExerciseModel> _todaySplitExercises = [];
  final Map<String, String> _swappedExercises = {};
  String? _lastSelectedExerciseForSwap;
  bool _isTrainerPro = true;

  String? _trainerName;
  String? _trainerCref;
  String? _trainerPhotoUrl;
  String? _trainerPhone;
  String? _workoutPlanTitle;
  int _totalSplitsCount = 0;

  @override
  void initState() {
    super.initState();
    if (widget.isStudentView) {
      _loadStudentExercises();
      _loadTrainer();
      _loadTodayAdaptations();
      StudentNotificationService.instance.refreshNotifications();
    }
  }

  Future<void> _loadStudentExercises() async {
    try {
      final activePlan = await WorkoutService.getActiveWorkoutForClient();
      if (activePlan != null && mounted) {
        final exercises = <String>{};
        SplitModel? todaySplit;
        if (activePlan.splits.isNotEmpty) {
          todaySplit = activePlan.splits.first;
        }
        for (final split in activePlan.splits) {
          for (final ex in split.exercises) {
            final name = ex.name.trim();
            if (name.isNotEmpty) {
              exercises.add(name);
            }
          }
        }
        if (mounted) {
          setState(() {
            _cachedActivePlan = activePlan;
            _workoutPlanTitle = activePlan.workoutPlanTitle;
            _totalSplitsCount = activePlan.splits.length;
            _todaySplit = todaySplit;
            _todaySplitExercises = todaySplit?.exercises ?? [];
            if (exercises.isNotEmpty) {
              _studentExercises = exercises.take(6).toList();
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Aviso ao carregar exercícios do aluno: $e');
    }
  }

  Future<void> _loadTodayAdaptations() async {
    try {
      final user = AuthService.currentUser;
      if (user != null) {
        final client = Supabase.instance.client;
        final now = DateTime.now();
        final todayStart = DateTime(now.year, now.month, now.day).toIso8601String();
        final res = await client
            .from('adaptation_logs')
            .select('original_exercise, adapted_exercise, reason, created_at')
            .eq('client_id', user.id)
            .gte('created_at', todayStart)
            .order('created_at', ascending: false);
        if (res is List && res.isNotEmpty) {
          final map = <String, String>{};
          for (final row in res) {
            final orig = (row['original_exercise'] ?? '').toString().trim();
            final adapt = (row['adapted_exercise'] ?? '').toString().trim();
            if (orig.isNotEmpty && adapt.isNotEmpty && !map.containsKey(orig)) {
              map[orig] = adapt;
            }
          }
          if (mounted && map.isNotEmpty) {
            setState(() {
              _swappedExercises.addAll(map);
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Aviso ao carregar adaptações de hoje: $e');
    }
  }

  List<String> get _quickPrompts {
    if (widget.isStudentView) {
      final prompts = <String>[];
      for (final ex in _studentExercises.take(3)) {
        prompts.add('Como executar $ex com postura perfeita?');
        prompts.add('Substituir $ex se aparelho estiver ocupado');
      }
      prompts.addAll([
        'Como substituir o Supino se o banco estiver ocupado?',
        'Qual ângulo do banco protege melhor os ombros?',
        'Sinto a lombar no agachamento: o que corrigir?',
        'Quantas repetições aguentar antes de aumentar a carga?',
        'Como evitar que os joelhos entrem no Leg Press?',
      ]);
      return prompts;
    }

    switch (_selectedPillar) {
      case 'Biomecânica':
        return [
          'Curva de resistência: Elevação Lateral Halter vs Polia',
          'Diferença biomecânica de Supino Halteres vs Supino Barra',
          'Ver Raio-X Biomecânico do Agachamento Búlgaro',
          'O que significa ativação de 92% sEMG no Deltoide?',
          'Como proteger o manguito rotador no supino pesado?',
        ];
      case 'Fisiologia':
        return [
          'Como aplicar RPE e RIR (repetições em reserva) na prática?',
          'Fadiga central vs periférica: quando prescrever deload?',
          'Intervalo de descanso ideal para hipertrofia: 60s vs 120s',
          'Estresse mecânico vs estresse metabólico na hipertrofia',
          'Como calcular volume de séries efetivas semanais por grupo?',
        ];
      case 'Treinamento':
        return [
          'Como prescrever Rest-Pause e Myo-Reps com segurança?',
          'Estrutura de treino Upper/Lower 4x por semana',
          'Divisão Push/Pull/Legs para aluno intermediário',
          'Periodização ondulatória diária (DUP) para hipertrofia',
          'Estratégia para corrigir ponto fraco em deltoides e dorsais',
        ];
      case 'Negócios B2B':
        return [
          r'Como precificar consultoria híbrida recorrente (R$ 180-250/mês)?',
          'Script de WhatsApp para reengajar aluno ausente há 15 dias',
          'Mensagem elegante de cobrança e renovação de ciclo',
          'Como apresentar os relatórios de IA para valorizar meu serviço?',
          'Como escalar de 15 para 50 alunos sem sobrecarga de horário?',
        ];
      default: // 'Todos'
        return [
          'Curva de resistência: Elevação Lateral Halter vs Polia',
          'Como aplicar RIR e RPE para controle de fadiga?',
          'Como prescrever Rest-Pause e Myo-Reps com segurança?',
          'Como precificar consultoria online recorrente?',
          'Script de WhatsApp para reengajar aluno ausente',
          'Diferença biomecânica de Supino Halteres vs Barra',
        ];
    }
  }

  @override
  void dispose() {
    _promptCtrl.dispose();
    super.dispose();
  }

  String? _detectExerciseInText(String text) {
    final lower = text.toLowerCase();
    for (final ex in _studentExercises) {
      if (lower.contains(ex.toLowerCase())) {
        return ex;
      }
    }
    if (lower.contains('supino') &&
        (lower.contains('inclinado') || lower.contains('halteres') || lower.contains('halter'))) {
      return 'Supino Inclinado com Halteres';
    } else if (lower.contains('supino')) {
      return 'Supino Reto com Barra';
    } else if (lower.contains('agachamento') || lower.contains('búlgaro') || lower.contains('bulgaro')) {
      return 'Agachamento Búlgaro';
    } else if (lower.contains('leg press') || lower.contains('legpress')) {
      return 'Leg Press 45°';
    } else if (lower.contains('puxada') || lower.contains('lat pulldown') || lower.contains('pulldown')) {
      return 'Puxada Alta (Lat Pulldown)';
    } else if (lower.contains('remada')) {
      return 'Remada Curvada';
    } else if (lower.contains('elevação lateral') || lower.contains('elevacao lateral')) {
      return 'Elevação Lateral';
    }
    return null;
  }

  String _generateBiomechanicsFallback(String exercise) {
    switch (exercise) {
      case 'Supino Inclinado com Halteres':
        return 'Aqui está a análise técnica e o parecer biomecânico do **$exercise**:\n\n'
            '🎯 **Músculo Alvo:** Peitoral Maior (Fibras Claviculares/Superior) e Deltóide Anterior.\n'
            '📐 **Ângulo do Banco:** Ajuste entre 30° e 45° (mais que isso transfere excesso de estresse para os ombros).\n'
            '⚡ **Fase Excêntrica (Descida):** Desça os halteres de forma controlada (2 a 3 segundos), mantendo os cotovelos a ~60° do tronco para proteger o manguito rotador.\n'
            '💥 **Fase Concêntrica (Subida):** Empurre convergindo suavemente os halteres sem bater no topo, mantendo o peitoral sob tensão mecânica contínua.\n'
            '🔒 **Segurança Biomecânica:** Mantenha as escápulas aduzidas e deprimidas durante todo o movimento.';
      case 'Agachamento Búlgaro':
        return 'Aqui está a análise técnica e o parecer biomecânico do **$exercise**:\n\n'
            '🎯 **Músculo Alvo:** Quadríceps e Glúteo Máximo.\n'
            '📐 **Posicionamento:** Pé traseiro no banco pelo peito do pé. Tronco levemente inclinado à frente para maior recrutamento glúteo.\n'
            '⚡ **Descida:** Desça verticalmente até o joelho traseiro quase encostar no solo, sem permitir valgo dinâmico.\n'
            '💥 **Subida:** Empurre firme através do calcanhar do pé dianteiro mantendo a pelve nivelada.\n'
            '🔒 **Segurança:** Mantenha o core rígido e olhar alinhado com o horizonte.';
      case 'Leg Press 45°':
        return 'Aqui está a análise técnica e o parecer biomecânico do **$exercise**:\n\n'
            '🎯 **Músculo Alvo:** Quadríceps, Glúteo Máximo e Isquiotibiais.\n'
            '📐 **Pés na Plataforma:** Largura dos ombros, pontas levemente rotacionadas para fora (~15°).\n'
            '⚡ **Descida:** Amplitude máxima sem descolar a região lombar do encosto (retroversão pélvica).\n'
            '💥 **Subida:** Empurre com a planta dos pés sem hiperextender ou travar os joelhos no final.\n'
            '🔒 **Segurança:** Nunca apoie as mãos nos joelhos durante cargas pesadas.';
      case 'Puxada Alta (Lat Pulldown)':
        return 'Aqui está a análise técnica e o parecer biomecânico do **$exercise**:\n\n'
            '🎯 **Músculo Alvo:** Latíssimo do Dorso (Dorsal) e Redondo Maior.\n'
            '📐 **Pegada:** Pouco além da largura dos ombros.\n'
            '⚡ **Puxada:** Puxe a barra em direção à porção superior do esterno, guiando com os cotovelos para baixo e para dentro.\n'
            '⚡ **Retorno:** Controle a fase excêntrica até alongar as dorsais sem elevar os ombros às orelhas.\n'
            '🔒 **Segurança:** Não puxe a barra atrás da nuca para não comprimir a cápsula anterior do ombro.';
      default:
        return 'Aqui está a análise biomecânica recomendada para o **$exercise**:\n\n'
            '🎯 **Músculo Alvo:** Fibras primárias e estabilizadores articulares.\n'
            '⚡ **Cadência:** 3 segundos de descida excêntrica com 1 segundo de pico isométrico.\n'
            '🔒 **Segurança:** Mantenha as escápulas alinhadas e evite impulsos do tronco durante a execução.';
    }
  }

  Future<void> _sendPrompt([String? textOverride]) async {
    final text = textOverride ?? _promptCtrl.text.trim();
    if (text.isEmpty) return;

    final detectedExercise = _detectExerciseInText(text);

    final normalized = text.toLowerCase().trim();
    if (widget.isStudentView) {
      // 1. GREETINGS & MENU (0 Tokens)
      if (normalized == 'menu' ||
          normalized == 'ajuda' ||
          normalized == '0' ||
          normalized == 'oi' ||
          normalized == 'olá' ||
          normalized == 'ola' ||
          normalized == 'bom dia' ||
          normalized == 'boa tarde' ||
          normalized == 'boa noite') {
        setState(() {
          _messages.add(
            _ChatMessage(
              text: '💪 **Olá! Eu sou o seu Copiloto de Treino no Mr. Coach.**\n\n'
                  'Aqui você adapta aparelhos ocupados, confere a execução 3D da sua série e registra sua rotina sem parar seu treino.\n\n'
                  'Toque em uma das opções abaixo para começar:',
              isUser: false,
              actionCardTitle: 'Ações Rápidas de Salão',
              actionCardIcon: Icons.fitness_center_rounded,
              actionItems: [
                AiActionCardItem(
                  label: '📋 Ficha Ativa de Hoje',
                  icon: Icons.assignment_rounded,
                  isPrimary: true,
                  onTap: () => _sendPrompt('1'),
                ),
                AiActionCardItem(
                  label: '⚠️ Aparelho Ocupado?',
                  icon: Icons.swap_horiz_rounded,
                  color: const Color(0xFFF59E0B),
                  onTap: _showBusyMachineModal,
                ),
                AiActionCardItem(
                  label: '🔥 Minha Ofensiva',
                  icon: Icons.local_fire_department_rounded,
                  color: const Color(0xFFF97316),
                  onTap: () => _sendPrompt('2'),
                ),
                AiActionCardItem(
                  label: '💧 Registrar Água (+250ml)',
                  icon: Icons.water_drop_rounded,
                  color: const Color(0xFF38BDF8),
                  onTap: () => _sendPrompt('+250ml'),
                ),
                AiActionCardItem(
                  label: '💬 Falar no WhatsApp',
                  icon: Icons.chat_rounded,
                  color: MetaColors.emerald,
                  onTap: () => _openTrainerWhatsApp(),
                ),
              ],
            ),
          );
          _isLoading = false;
        });
        return;
      }

      // 1.1 ATALHO RÁPIDO PARA APARELHO OCUPADO
      if (normalized == 'ocupado' || normalized == 'aparelho ocupado' || normalized.contains('trocar aparelho')) {
        _showBusyMachineModal();
        return;
      }
      
      // 2. CONSULTA REAL DE FICHA ATIVA / TREINO DO DIA (0 Tokens)
      if (normalized == '1' ||
          normalized == 'treino' ||
          normalized == 'meu treino' ||
          normalized == 'ficha' ||
          normalized == 'qual meu treino' ||
          normalized == 'treino de hoje' ||
          normalized.contains('qual o meu treino') ||
          normalized.contains('qual meu treino')) {
        String workoutText;
        if (_cachedActivePlan != null && _cachedActivePlan!.splits.isNotEmpty) {
          final splits = _cachedActivePlan!.splits;
          final buffer = StringBuffer();
          buffer.writeln('📋 **Sua Ficha Ativa: ${_cachedActivePlan!.workoutPlanTitle}**\n');
          buffer.writeln('Seu treinador organizou **${splits.length} divisões** para você:');
          for (final sp in splits) {
            buffer.writeln('\n• **Divisão ${sp.splitIdentifier} (${sp.splitName})** ~${sp.estimatedDurationMin} min:');
            for (int i = 0; i < sp.exercises.length; i++) {
              final ex = sp.exercises[i];
              buffer.writeln('   ${i + 1}. ${ex.name} — ${ex.sets} séries x ${ex.reps} (desc. ${ex.restSeconds}s)');
            }
          }
          buffer.writeln('\n💡 *Dica:* Toque na aba **Treino** na barra inferior para marcar suas séries e ligar o timer de descanso!');
          workoutText = buffer.toString();
        } else {
          workoutText = '📋 **Seu Treino Ativo**\n\n'
              'Sua ficha está sendo sincronizada com seu professor. Você pode acompanhar todas as divisões e marcar suas séries tocando na aba **Treino** na barra inferior.';
        }

        setState(() {
          _messages.add(
            _ChatMessage(
              text: workoutText,
              isUser: false,
              actionCardTitle: 'Ações de Treino Recomendadas',
              actionCardIcon: Icons.fitness_center_rounded,
              actionItems: [
                AiActionCardItem(
                  label: 'Abrir Treino de Hoje',
                  icon: Icons.play_arrow_rounded,
                  isPrimary: true,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ActiveWorkoutScreen()),
                    );
                  },
                ),
                AiActionCardItem(
                  label: 'Aparelho Ocupado?',
                  icon: Icons.swap_horiz_rounded,
                  color: const Color(0xFFF59E0B),
                  onTap: () => _sendPrompt('O aparelho da minha ficha está ocupado. Qual o melhor substituto biomecânico?'),
                ),
              ],
            ),
          );
          _isLoading = false;
        });
        return;
      }

      // 3. CONSULTA REAL DE STREAK / OFENSIVA (0 Tokens)
      if (normalized == '2' ||
          normalized == 'streak' ||
          normalized == 'ofensiva' ||
          normalized == 'foguinho' ||
          normalized == 'minha ofensiva' ||
          normalized.contains('quantos dias') ||
          normalized.contains('meu streak')) {
        int streak = 0;
        try {
          final user = AuthService.currentUser;
          if (user != null) {
            final profile = await AuthService.getCurrentProfile();
            streak = int.tryParse((profile?['streak_days'] ?? 0).toString()) ?? 0;
          }
        } catch (_) {}

        final streakMsg = streak > 0
            ? '🔥 **Sua Ofensiva Atual: $streak dias consecutivos!**\n\n'
                'Parabéns pela consistência! A cada treino concluído na aba **Treino**, seu foguinho é mantido aceso. '
                'Bora treinar hoje para manter esse recorde vivo! 💪'
            : '🔥 **Ofensiva & Consistência**\n\n'
                'Você está pronto para começar uma nova sequência! Complete o treino de hoje na aba **Treino** '
                'para acender seu foguinho e somar dias de consistência com seu professor! 🚀';

        setState(() {
          _messages.add(
            _ChatMessage(
              text: streakMsg,
              isUser: false,
              actionCardTitle: 'Metas e Consistência',
              actionCardIcon: Icons.local_fire_department_rounded,
              actionItems: [
                AiActionCardItem(
                  label: 'Iniciar Treino e Pontuar',
                  icon: Icons.bolt_rounded,
                  isPrimary: true,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ActiveWorkoutScreen()),
                    );
                  },
                ),
                AiActionCardItem(
                  label: 'Ver Meu Bio-Hub',
                  icon: Icons.monitor_weight_rounded,
                  color: MetaColors.accentBlue,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const StudentProfileScreen()),
                  ),
                ),
              ],
            ),
          );
          _isLoading = false;
        });
        return;
      }

      // 4. CONSULTA E REGISTRO DE ÁGUA / HIDRATAÇÃO (0 Tokens)
      if (normalized == 'agua' ||
          normalized == 'água' ||
          normalized == 'hidratacao' ||
          normalized == 'hidratação' ||
          normalized.contains('bebi agua') ||
          normalized.contains('bebi água') ||
          normalized.contains('quanto de agua') ||
          normalized.contains('meta de agua')) {
        final user = AuthService.currentUser;
        int currentIntake = 0;
        int dailyGoal = 2500;
        if (user != null) {
          try {
            currentIntake = await StudentNotificationService.instance.getTodayHydration(user.id);
            dailyGoal = await StudentNotificationService.instance.getDailyHydrationGoal(user.id);
          } catch (_) {}
        }

        // Se o usuário digitou explicitamente que bebeu água (ex: "bebi 250ml", "+250", "bebi agua")
        if (normalized.contains('+') || normalized.contains('bebi') || normalized.contains('tomei')) {
          int addMl = 250;
          final match = RegExp(r'(\d+)\s*ml').firstMatch(normalized);
          if (match != null) {
            addMl = int.tryParse(match.group(1)!) ?? 250;
          }
          if (user != null) {
            currentIntake = await StudentNotificationService.instance.addWaterIntake(user.id, addMl);
          }
        }

        final percent = dailyGoal > 0 ? ((currentIntake / dailyGoal) * 100).round() : 0;
        final waterMsg = '💧 **Controle de Hidratação de Hoje**\n\n'
            '• Consumo atual: **${currentIntake}ml** de **${dailyGoal}ml** ($percent% da meta)\n'
            '• Restante para hoje: **${(dailyGoal - currentIntake).clamp(0, dailyGoal)}ml**\n\n'
            '💡 *Dica:* A água otimiza a recuperação muscular e reduz cãibras. Você pode digitar *+250ml* ou *+500ml* aqui a qualquer momento para registrar!';

        setState(() {
          _messages.add(
            _ChatMessage(
              text: waterMsg,
              isUser: false,
              actionCardTitle: 'Registro Rápido de Água',
              actionCardIcon: Icons.water_drop_rounded,
              actionItems: [
                AiActionCardItem(
                  label: '+250ml Copo',
                  icon: Icons.add_rounded,
                  color: const Color(0xFF38BDF8),
                  isPrimary: true,
                  onTap: () => _sendPrompt('+250ml'),
                ),
                AiActionCardItem(
                  label: '+500ml Garrafa',
                  icon: Icons.local_drink_rounded,
                  color: MetaColors.emerald,
                  onTap: () => _sendPrompt('+500ml'),
                ),
              ],
            ),
          );
          _isLoading = false;
        });
        return;
      }

      // 5. GUARDRAIL CLÍNICO DE DOR / DESCONFORTO ARTICULAR (0 Tokens Local)
      final painKeywords = [
        'dor',
        'doendo',
        'machuc',
        'lesion',
        'desconforto',
        'estalo',
        'pinçando',
        'pincando',
        'travei',
        'pontada',
        'ombro doendo',
        'joelho doendo',
        'lombar doendo',
      ];
      final hasPain = painKeywords.any((kw) => normalized.contains(kw));
      if (hasPain) {
        final trainerTitle = (_trainerName != null && _trainerName!.trim().isNotEmpty)
            ? _trainerName!.trim()
            : 'seu treinador';

        setState(() {
          _messages.add(
            _ChatMessage(
              text: '🚨 **Atenção Clínica & Segurança Articular**\n\n'
                  'Ao primeiro sinal de dor aguda, estalo atípico ou pinçamento articular, interrompa a série imediatamente.\n\n'
                  '🛡️ **Protocolo de Segurança:**\n'
                  '• Não force a carga nem insista na repetição com dor;\n'
                  '• Alivie a pressão articular e descanse a musculatura envolvida;\n'
                  '• Avise imediatamente $trainerTitle para ajuste na prescrição ou substituição do movimento.',
              isUser: false,
              actionCardTitle: 'Suporte Clínico Imediato',
              actionCardIcon: Icons.health_and_safety_rounded,
              actionItems: [
                AiActionCardItem(
                  label: 'Falar com $trainerTitle',
                  icon: Icons.chat_rounded,
                  color: MetaColors.emerald,
                  isPrimary: true,
                  onTap: () => _openTrainerWhatsApp(
                    customMessage: 'Olá $trainerTitle! Senti um desconforto/dor articular durante meu treino no Mr. Coach e parei a série para falar com você.',
                  ),
                ),
                AiActionCardItem(
                  label: 'Sugerir Substituto sem Dor',
                  icon: Icons.swap_horiz_rounded,
                  color: const Color(0xFFF59E0B),
                  onTap: () => _sendPrompt('Exercício alternativo seguro que não sobrecarregue essa região'),
                ),
              ],
            ),
          );
          _isLoading = false;
        });
        return;
      }
    }

    try {
      String studentContext = '';
      if (widget.isStudentView) {
        final planName = _workoutPlanTitle ?? _cachedActivePlan?.workoutPlanTitle ?? 'Ficha Atual';
        final trainer = (_trainerName != null && _trainerName!.trim().isNotEmpty)
            ? _trainerName!.trim()
            : 'Personal Trainer';
        final buffer = StringBuffer();
        buffer.writeln('Contexto do Aluno:');
        buffer.writeln('- Treinador responsável: $trainer');
        buffer.writeln('- Ficha Ativa: $planName');
        if (_cachedActivePlan != null && _cachedActivePlan!.splits.isNotEmpty) {
          buffer.writeln('- Divisões e Exercícios prescritos:');
          for (final split in _cachedActivePlan!.splits) {
            final exNames = split.exercises
                .map((e) => e.name.trim())
                .where((n) => n.isNotEmpty)
                .join(', ');
            buffer.writeln('  * ${split.splitIdentifier} (${split.splitName}): $exNames');
          }
        }
        studentContext = buffer.toString();
      }

      if (widget.isStudentView && !_isTrainerPro) {
        // Modo Essencial (Starter): Zero custo de LLM
        final fallbackExercise = detectedExercise;
        final String fallbackText;
        if (fallbackExercise != null) {
          fallbackText = _generateBiomechanicsFallback(fallbackExercise);
        } else {
          fallbackText = 'O seu professor ($_trainerName) prescreveu sua ficha com metodologia individualizada. '
              'Para dúvidas pontuais de postura e substituição, use as ações rápidas ou envie uma mensagem direta para ele no WhatsApp!';
        }
        setState(() {
          _messages.add(
            _ChatMessage(
              text: fallbackText,
              isUser: false,
              detectedExercise: fallbackExercise,
              actionCardTitle: 'Suporte do Treinador',
              actionCardIcon: Icons.chat_rounded,
              actionItems: [
                AiActionCardItem(
                  label: 'Falar com $_trainerName no WhatsApp',
                  icon: Icons.chat_rounded,
                  color: MetaColors.emerald,
                  isPrimary: true,
                  onTap: () => _openTrainerWhatsApp(),
                ),
                AiActionCardItem(
                  label: 'Pedir Copiloto IA 24h ao Professor',
                  icon: Icons.rocket_launch_rounded,
                  color: const Color(0xFF8B5CF6),
                  onTap: _requestTrainerProUpgrade,
                ),
              ],
            ),
          );
        });
        return;
      }

      final promptWithContext =
          widget.isStudentView
              ? 'Você é o Copiloto de Salão do Mr. Coach. O aluno está treinando na academia agora.\n'
                '$studentContext\n'
                'Diretrizes obrigatórias de resposta:\n'
                '1. Formato ultra-enxuto, scannable e direto ao ponto (máximo 4 tópicos curtos: 🟢 Regra de Ouro, 📐 Ajuste de Ângulo/Pegada, 🚫 O que Evitar, 🔄 Alternativa se o Aparelho estiver Ocupado).\n'
                '2. Se o aluno pedir substituto para aparelho ocupado, recomende prioritariamente uma alternativa equivalente que trabalhe o mesmo grupo muscular respeitando a ficha prescrita.\n'
                '3. Sem introduções longas ou saudações repetitivas.\n\n'
                'Dúvida do Aluno: $text'
              : text;

      final modelToUse = widget.isStudentView ? 'gemini-2.5-flash' : _selectedModelId;
      final reply = await GeminiService.askB2BAssistant(
        prompt: promptWithContext,
        systemInstruction:
            widget.isStudentView
                ? AiPrompts.expertStudentPersona
                : AiPrompts.expertTrainerPersona,
        model: modelToUse,
      );
      if (!mounted) return;
      final replyExercise = detectedExercise ?? _detectExerciseInText(reply);

      List<AiActionCardItem>? actionItems;
      String? actionCardTitle;
      IconData? actionCardIcon;

      if (replyExercise != null && widget.isStudentView) {
        actionCardTitle = 'Ações Rápidas: $replyExercise';
        actionCardIcon = Icons.biotech_rounded;
        actionItems = [
          AiActionCardItem(
            label: 'Execução 3D',
            icon: Icons.play_circle_fill_rounded,
            color: MetaColors.emerald,
            isPrimary: true,
            onTap: () => ExerciseMediaSheet.show(
              context,
              exerciseName: replyExercise,
            ),
          ),
          AiActionCardItem(
            label: 'Raio-X Biomecânico',
            icon: Icons.biotech_rounded,
            color: const Color(0xFF6366F1),
            onTap: () => BiomechanicalAnalysisSheet.show(
              context,
              exerciseName: replyExercise,
            ),
          ),
        ];
      }

      setState(() {
        _messages.add(
          _ChatMessage(
            text: reply,
            isUser: false,
            detectedExercise: replyExercise,
            actionCardTitle: actionCardTitle,
            actionCardIcon: actionCardIcon,
            actionItems: actionItems,
          ),
        );
      });
    } catch (e) {
      if (!mounted) return;
      debugPrint('Aviso Gemini Assistant (ativando motor biomecânico local): $e');

      final fallbackExercise = detectedExercise;
      final String fallbackText;
      List<AiActionCardItem>? fallbackActionItems;
      String? fallbackCardTitle;
      IconData? fallbackCardIcon;

      if (fallbackExercise != null) {
        fallbackText = _generateBiomechanicsFallback(fallbackExercise);
        if (widget.isStudentView) {
          fallbackCardTitle = 'Ações Rápidas: $fallbackExercise';
          fallbackCardIcon = Icons.biotech_rounded;
          fallbackActionItems = [
            AiActionCardItem(
              label: 'Execução 3D',
              icon: Icons.play_circle_fill_rounded,
              color: MetaColors.emerald,
              isPrimary: true,
              onTap: () => ExerciseMediaSheet.show(
                context,
                exerciseName: fallbackExercise,
              ),
            ),
            AiActionCardItem(
              label: 'Raio-X Biomecânico',
              icon: Icons.biotech_rounded,
              color: const Color(0xFF6366F1),
              onTap: () => BiomechanicalAnalysisSheet.show(
                context,
                exerciseName: fallbackExercise,
              ),
            ),
          ];
        }
      } else {
        fallbackText = widget.isStudentView
            ? 'Estou temporariamente reconectando ao servidor em nuvem. Como posso te orientar na execução, postura ou biomecânica de algum exercício específico hoje?'
            : 'Conexão com o servidor da IA oscilou. Tente novamente em instantes ou consulte as diretrizes nos cards acima.';
      }

      setState(() {
        _messages.add(
          _ChatMessage(
            text: fallbackText,
            isUser: false,
            detectedExercise: fallbackExercise,
            isError: false,
            actionCardTitle: fallbackCardTitle,
            actionCardIcon: fallbackCardIcon,
            actionItems: fallbackActionItems,
          ),
        );
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadTrainer() async {
    try {
      final trainer = await AuthService.getTrainerForStudent();
      if (trainer != null && mounted) {
        final trainerId = trainer['id'] as String?;
        setState(() {
          _trainerName = (trainer['trainer_name'] ?? trainer['full_name']) as String?;
          _trainerCref = (trainer['cref_or_registry'] ?? trainer['cref'] ?? trainer['professional_document']) as String?;
          _trainerPhotoUrl = trainer['trainer_photo_url'] as String?;
          _trainerPhone = (trainer['phone'] ?? trainer['whatsapp']) as String?;
        });

        if (trainerId != null && trainerId.isNotEmpty) {
          try {
            final client = Supabase.instance.client;
            final sub = await client
                .from('subscriptions')
                .select('plan_id, status')
                .eq('trainer_id', trainerId)
                .maybeSingle();
            if (sub != null && mounted) {
              final planId = (sub['plan_id'] ?? '').toString().toLowerCase();
              final status = (sub['status'] ?? '').toString().toLowerCase();
              final isPro = (status == 'active' || status == 'trial') &&
                  (planId.contains('pro') || planId.contains('elite') || planId.contains('studio'));
              setState(() {
                _isTrainerPro = isPro;
              });
            }
          } catch (e) {
            debugPrint('Aviso ao consultar plano do treinador: $e');
          }
        }
      }
    } catch (_) {}
  }

  void _showTodayWorkoutCard() {
    _sendPrompt('1');
  }

  Future<void> _applySessionAdaptation({
    required String originalExercise,
    required String adaptedExercise,
    String? reason,
  }) async {
    final effectiveReason = reason ?? 'Adaptação da Sessão de Hoje (Mr. Coach AI Copiloto)';
    
    // 1. Registra no banco via WorkoutService (adaptation_logs + student_pulse_events)
    await WorkoutService.logAdaptation(
      originalExercise: originalExercise,
      adaptedExercise: adaptedExercise,
      reason: effectiveReason,
      details: {
        'source': 'app_copilot',
        'session_adaptation': true,
        'exercise': adaptedExercise,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );

    // 2. Atualiza estado em tempo real no app
    if (mounted) {
      setState(() {
        _swappedExercises[originalExercise] = adaptedExercise;
        _messages.add(
          _ChatMessage(
            text: '✅ **Adaptação Registrada para a Sessão de Hoje!**\n\n'
                '• Original: ~~$originalExercise~~\n'
                '• Substituto hoje: **$adaptedExercise**\n\n'
                'O seu professor ($_trainerName) foi notificado no radar do Mr. Coach. '
                'Sua ficha oficial do mesociclo segue 100% intacta. Excelente treino! 💪',
            isUser: false,
            detectedExercise: adaptedExercise,
            actionCardTitle: 'Ações de Execução',
            actionCardIcon: Icons.playlist_add_check_rounded,
            actionItems: [
              AiActionCardItem(
                label: 'Execução 3D de $adaptedExercise',
                icon: Icons.play_circle_fill_rounded,
                isPrimary: true,
                onTap: () => ExerciseMediaSheet.show(
                  context,
                  exerciseName: adaptedExercise,
                ),
              ),
              AiActionCardItem(
                label: 'Abrir Treino de Hoje',
                icon: Icons.fitness_center_rounded,
                color: MetaColors.emerald,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ActiveWorkoutScreen()),
                ),
              ),
            ],
          ),
        );
      });

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: MetaColors.emerald,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Adaptação "$adaptedExercise" gravada só para o treino de hoje!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  List<Map<String, String>> _getEquivalenceOptions(String exName) {
    final lower = exName.toLowerCase();
    if (lower.contains('supino') && (lower.contains('inclinado') || lower.contains('45'))) {
      return [
        {
          'name': 'Crucifixo Inclinado no Cabo (Polia Baixa)',
          'reason': 'Tensão contínua no feixe clavicular sem depender de banco livre.',
          'match': '98% Match',
        },
        {
          'name': 'Supino Inclinado com Halteres',
          'reason': 'Controle de trajetória articular sem sobrecarregar manguito.',
          'match': '96% Match',
        },
      ];
    } else if (lower.contains('supino')) {
      return [
        {
          'name': 'Supino Reto com Halteres',
          'reason': 'Mesmo vetor horizontal, maior amplitude e livre de fila na barra.',
          'match': '98% Match',
        },
        {
          'name': 'Supino Máquina Convergente',
          'reason': 'Estabilidade guiada e tensão constante no peitoral médio.',
          'match': '94% Match',
        },
      ];
    } else if (lower.contains('leg press') || lower.contains('legpress')) {
      return [
        {
          'name': 'Agachamento Búlgaro com Halteres',
          'reason': 'Alta sobrecarga unilateral em quadríceps e glúteo sem fila de máquina.',
          'match': '96% Match',
        },
        {
          'name': 'Agachamento Goblet com Halter',
          'reason': 'Padrão de movimento seguro com tronco verticalizado.',
          'match': '92% Match',
        },
      ];
    } else if (lower.contains('puxada') || lower.contains('lat pulldown') || lower.contains('pulldown')) {
      return [
        {
          'name': 'Remada Unilateral com Halter (Serrote)',
          'reason': 'Grande alongamento e recrutamento do dorsal sem depender de cabo.',
          'match': '97% Match',
        },
        {
          'name': 'Barra Fixa Assistida ou Graviton',
          'reason': 'Puxada vertical fechada com ativação dorsal idêntica.',
          'match': '95% Match',
        },
      ];
    } else if (lower.contains('remada')) {
      return [
        {
          'name': 'Remada Curvada com Halteres',
          'reason': 'Pegada neutra ou pronada sem esperar banco na academia.',
          'match': '96% Match',
        },
        {
          'name': 'Remada Baixa no Cabo Triângulo',
          'reason': 'Tensão mecânica contínua em trapézio e romboides.',
          'match': '93% Match',
        },
      ];
    } else if (lower.contains('elevação lateral') || lower.contains('elevacao lateral')) {
      return [
        {
          'name': 'Elevação Lateral na Polia Baixa',
          'reason': 'Curva de resistência uniforme desde o início do movimento.',
          'match': '98% Match',
        },
        {
          'name': 'Elevação Lateral com Halteres Sentado',
          'reason': 'Elimina o roubo do tronco e foca 100% no deltoide lateral.',
          'match': '95% Match',
        },
      ];
    } else if (lower.contains('tríceps') || lower.contains('triceps')) {
      return [
        {
          'name': 'Tríceps Francês Unilateral com Halter',
          'reason': 'Excelente alongamento da cabeça longa usando apenas 1 halter.',
          'match': '97% Match',
        },
        {
          'name': 'Tríceps Testa com Halteres no Banco',
          'reason': 'Isolamento seguro de tríceps sem depender do crossover.',
          'match': '94% Match',
        },
      ];
    } else if (lower.contains('rosca') || lower.contains('bíceps') || lower.contains('biceps')) {
      return [
        {
          'name': 'Rosca Martelo com Halteres',
          'reason': 'Foco em braquial e braquiorradial sem sobrecarregar o punho.',
          'match': '96% Match',
        },
        {
          'name': 'Rosca Inclinada 45° com Halteres',
          'reason': 'Maior tensão na cabeça longa do bíceps.',
          'match': '95% Match',
        },
      ];
    }

    return [
      {
        'name': '$exName com Halteres Livres',
        'reason': 'Variação livre com carga equivalente mantendo o grupo muscular.',
        'match': '94% Match',
      },
      {
        'name': '$exName na Polia Regulável',
        'reason': 'Tensão contínua sem depender do aparelho específico ocupado.',
        'match': '91% Match',
      },
    ];
  }

  void _triggerExerciseSwapFlow(String exName) {
    _lastSelectedExerciseForSwap = exName;
    final options = _getEquivalenceOptions(exName);
    final opt1 = options[0];
    final opt2 = options.length > 1 ? options[1] : options[0];

    setState(() {
      _messages.add(
        _ChatMessage(
          text: 'O aparelho de **$exName** está ocupado agora na academia. Qual a melhor substituição mantendo o estímulo?',
          isUser: true,
        ),
      );

      if (_isTrainerPro) {
        _messages.add(
          _ChatMessage(
            text: '⚡ **Equivalência Biomecânica IA para $exName**\n\n'
                'Identifiquei as 2 melhores variações livres de fila na academia para o seu treino de hoje.\n'
                'Ao tocar em uma opção, a adaptação é registrada exclusivamente na sua sessão de hoje e seu professor ($_trainerName) recebe um alerta no Radar:',
            isUser: false,
            detectedExercise: opt1['name'],
            actionCardTitle: 'Opções de Substituição em 1 Toque',
            actionCardIcon: Icons.swap_horiz_rounded,
            actionItems: [
              AiActionCardItem(
                label: '1. ${opt1['name']} (${opt1['match']})',
                icon: Icons.check_circle_outline_rounded,
                isPrimary: true,
                onTap: () => _applySessionAdaptation(
                  originalExercise: exName,
                  adaptedExercise: opt1['name']!,
                  reason: opt1['reason'],
                ),
              ),
              AiActionCardItem(
                label: '2. ${opt2['name']} (${opt2['match']})',
                icon: Icons.check_circle_outline_rounded,
                color: const Color(0xFF6366F1),
                onTap: () => _applySessionAdaptation(
                  originalExercise: exName,
                  adaptedExercise: opt2['name']!,
                  reason: opt2['reason'],
                ),
              ),
              AiActionCardItem(
                label: 'Ver Execução 3D de ${opt1['name']}',
                icon: Icons.play_circle_fill_rounded,
                color: MetaColors.emerald,
                onTap: () => ExerciseMediaSheet.show(
                  context,
                  exerciseName: opt1['name']!,
                ),
              ),
            ],
          ),
        );
      } else {
        // Starter Plan
        _messages.add(
          _ChatMessage(
            text: '🛡️ **Sugestão Padrão da Biblioteca (\$0 Tokens)**\n\n'
                '• Variação recomendada: **${opt1['name']}** (${opt1['match']})\n'
                '• Biomecânica: ${opt1['reason']}\n\n'
                'Seu professor ($_trainerName) está no plano Essencial. Você pode registrar essa troca gratuitamente:',
            isUser: false,
            detectedExercise: opt1['name'],
            actionCardTitle: 'Substituição Essencial',
            actionCardIcon: Icons.fitness_center_rounded,
            actionItems: [
              AiActionCardItem(
                label: 'Adaptar Só Hoje: ${opt1['name']}',
                icon: Icons.check_circle_outline_rounded,
                isPrimary: true,
                onTap: () => _applySessionAdaptation(
                  originalExercise: exName,
                  adaptedExercise: opt1['name']!,
                  reason: opt1['reason'],
                ),
              ),
              AiActionCardItem(
                label: 'Pedir Copiloto IA 24h ao Professor',
                icon: Icons.rocket_launch_rounded,
                color: const Color(0xFF8B5CF6),
                onTap: _requestTrainerProUpgrade,
              ),
            ],
          ),
        );
      }
    });
  }

  void _showBusyMachineModal() {
    final exercises = _todaySplitExercises.isNotEmpty
        ? _todaySplitExercises.map((e) => e.name).toList()
        : (_studentExercises.isNotEmpty
            ? _studentExercises
            : [
                'Supino Reto com Barra',
                'Puxada Alta (Lat Pulldown)',
                'Leg Press 45°',
                'Desenvolvimento com Halteres',
                'Tríceps Corda Polia',
                'Elevação Lateral',
              ]);

    OneUiGlassSheet.show(
      context,
      header: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.18),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
            ),
            child: const Icon(Icons.swap_horiz_rounded, color: Color(0xFFF59E0B), size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Aparelho Ocupado?',
                  style: TextStyle(
                    color: MetaColors.text(context),
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Qual exercício você precisa adaptar só hoje?',
                  style: TextStyle(
                    color: MetaColors.subtext(context),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: exercises.map((exName) {
        final isSwapped = _swappedExercises.containsKey(exName);
        final currentAdapted = _swappedExercises[exName];
        return GlassAction(
          icon: isSwapped ? Icons.check_circle_rounded : Icons.fitness_center_rounded,
          color: isSwapped ? MetaColors.emerald : const Color(0xFFF59E0B),
          label: exName,
          subtitle: isSwapped
              ? 'Já adaptado hoje para: $currentAdapted'
              : 'Toque para ver 2 opções equivalentes livres de fila',
          onTap: () {
            Navigator.of(context, rootNavigator: true).pop();
            _triggerExerciseSwapFlow(exName);
          },
        );
      }).toList(),
    );
  }

  void _openWhatsAppSyncSheet() {
    OneUiGlassSheet.show(
      context,
      header: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: MetaColors.emerald.withValues(alpha: 0.18),
              shape: BoxShape.circle,
              border: Border.all(color: MetaColors.emerald.withValues(alpha: 0.4)),
            ),
            child: const Icon(Icons.chat_rounded, color: MetaColors.emerald, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Espelho Omnichannel WhatsApp',
                  style: TextStyle(
                    color: MetaColors.text(context),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Sincronia em tempo real entre o App e o Robô',
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
      actions: [
        GlassAction(
          icon: Icons.sync_rounded,
          color: MetaColors.emerald,
          label: _swappedExercises.isNotEmpty
              ? '${_swappedExercises.length} Exercício(s) Adaptado(s) Hoje'
              : 'Ficha Sincronizada com o Robô WhatsApp',
          subtitle: _swappedExercises.isNotEmpty
              ? _swappedExercises.entries.map((e) => '${e.key} → ${e.value}').join(', ')
              : 'Nenhuma adaptação necessária até o momento.',
          onTap: () => Navigator.of(context, rootNavigator: true).pop(),
        ),
        GlassAction(
          icon: Icons.chat_bubble_rounded,
          color: MetaColors.emerald,
          label: 'Falar com o Robô Oficial no WhatsApp',
          subtitle: 'Troque exercícios, registre RPE e consulte ficha pelo WhatsApp',
          onTap: () {
            Navigator.of(context, rootNavigator: true).pop();
            _openTrainerWhatsApp(customMessage: 'Oi Mr. Coach! Gostaria de consultar meu treino de hoje.');
          },
        ),
      ],
    );
  }

  void _showVoiceInputDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: MetaColors.bg(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.mic_rounded, color: Color(0xFF8B5CF6), size: 22),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dúvidas Rápidas de Salão',
                          style: TextStyle(
                            color: MetaColors.text(context),
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'Toque para perguntar sem precisar digitar suado:',
                          style: TextStyle(
                            color: MetaColors.subtext(context),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ActionChip(
                      backgroundColor: MetaColors.card(context),
                      side: BorderSide(color: MetaColors.cardBorder(context)),
                      label: const Text('🔄 Aparelho ocupado, como substituo?'),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showBusyMachineModal();
                      },
                    ),
                    ActionChip(
                      backgroundColor: MetaColors.card(context),
                      side: BorderSide(color: MetaColors.cardBorder(context)),
                      label: const Text('📐 Qual ângulo protege o ombro?'),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _sendPrompt('Qual o melhor ângulo do banco para proteger os ombros no supino inclinado?');
                      },
                    ),
                    ActionChip(
                      backgroundColor: MetaColors.card(context),
                      side: BorderSide(color: MetaColors.cardBorder(context)),
                      label: const Text('⚖️ Como saber se a carga está leve?'),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _sendPrompt('Como saber se a carga está correta ou leve demais? Explique repetições na reserva (RIR).');
                      },
                    ),
                    ActionChip(
                      backgroundColor: MetaColors.card(context),
                      side: BorderSide(color: MetaColors.cardBorder(context)),
                      label: const Text('🚨 Sinto a lombar no agachamento'),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _sendPrompt('Sinto desconforto na lombar no agachamento: o que corrigir na postura agora?');
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _requestTrainerProUpgrade() async {
    final user = AuthService.currentUser;
    if (user != null && _trainerName != null) {
      try {
        final client = Supabase.instance.client;
        final profile = await AuthService.getCurrentProfile();
        final studentName = profile?['full_name'] as String? ?? 'Seu aluno';
        final trainerId = profile?['trainer_id'] as String?;
        if (trainerId != null) {
          await client.from('trainer_notifications').insert({
            'trainer_id': trainerId,
            'title': 'Solicitação de Copiloto IA',
            'message': '$studentName solicitou a liberação do Copiloto IA 24h para substituição de aparelhos na academia.',
            'created_at': DateTime.now().toIso8601String(),
            'is_read': false,
          });
        }
      } catch (e) {
        debugPrint('Aviso ao registrar solicitação de upgrade: $e');
      }
    }

    if (mounted) {
      setState(() {
        _messages.add(
          _ChatMessage(
            text: '🚀 **Solicitação Enviada ao Prof. $_trainerName!**\n\n'
                'Avisamos seu treinador que você gostaria de usar o Copiloto IA para adaptações automáticas de aparelhos ocupados.\n\n'
                'Enquanto isso, você pode continuar usando as trocas padrão da biblioteca e o Raio-X Biomecânico 3D normalmente!',
            isUser: false,
          ),
        );
      });
    }
  }

  void _openCoachSheet() {
    final name = _trainerName ?? 'Seu Treinador';
    final subtitle = (_trainerCref != null && _trainerCref!.isNotEmpty) ? _trainerCref! : 'CREF Ativo';
    OneUiGlassSheet.show(
      context,
      header: Row(
        children: [
          _buildCoachAvatar(size: 56),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: MetaColors.text(context),
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.verified_rounded, size: 14, color: MetaColors.emerald),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        subtitle,
                        style: TextStyle(
                          color: MetaColors.subtext(context),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        GlassAction(
          icon: Icons.chat_bubble_rounded,
          label: 'Falar no WhatsApp (24h)',
          subtitle: 'Tire dúvidas sobre execução e carga',
          onTap: _contactTrainerWhatsApp,
        ),
      ],
    );
  }

  Future<void> _openTrainerWhatsApp({String? customMessage}) async {
    final cleanPhone = (_trainerPhone ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: MetaColors.isDark(context) ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
            content: Text('Seu treinador ($_trainerName) ainda não cadastrou o WhatsApp profissional.'),
          ),
        );
      }
      return;
    }
    final message = customMessage ??
        'Olá professor(a) $_trainerName! Sou seu aluno no Mr. Coach e gostaria de tirar uma dúvida biomecânica.';
    final uri = Uri.parse(
      'https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}',
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.redAccent,
            content: Text('Não foi possível abrir o WhatsApp.'),
          ),
        );
      }
    }
  }

  Future<void> _contactTrainerWhatsApp() async {
    Navigator.of(context, rootNavigator: true).pop();
    await _openTrainerWhatsApp();
  }

  void _openMoreMenu() {
    final dark = ThemeController.instance.isEffectiveDark(context);
    OneUiGlassSheet.show(
      context,
      actions: [
        GlassAction(
          icon: dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          label: dark ? 'Modo Claro' : 'Modo Escuro',
          subtitle: 'Alterna o tema de todo o aplicativo',
          color: const Color(0xFF8B5CF6),
          onTap: () => ThemeController.instance.toggleTheme(context),
        ),
        GlassAction(
          icon: Icons.fitness_center_rounded,
          label: 'Como treinar',
          subtitle: 'Guia de execução, cargas e trocas',
          color: const Color(0xFFF59E0B),
          onTap: () => WorkoutGuideModal.show(context),
        ),
        GlassAction(
          icon: Icons.explore_rounded,
          label: 'Tour do Aluno',
          subtitle: 'Apresentação rápida das funções',
          onTap: () => InteractiveTourGuideModal.show(context, role: 'student'),
        ),
        GlassAction(
          icon: Icons.person_outline_rounded,
          label: 'Meu Perfil & Anamnese',
          color: const Color(0xFF38BDF8),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const StudentProfileScreen()),
          ),
        ),
      ],
    );
  }

  Widget _buildCoachAvatar({double size = 40}) {
    final hasPhoto = _trainerPhotoUrl != null && _trainerPhotoUrl!.isNotEmpty;
    final initials = (_trainerName ?? 'Personal')
        .trim()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .take(2)
        .map((s) => s[0].toUpperCase())
        .join();
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [MetaColors.emerald, MetaColors.accentBlue],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            image: hasPhoto
                ? DecorationImage(
                    image: _trainerPhotoUrl!.startsWith('assets/')
                        ? AssetImage(_trainerPhotoUrl!) as ImageProvider
                        : NetworkImage(_trainerPhotoUrl!),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: hasPhoto
              ? null
              : Center(
                  child: Text(
                    initials.isNotEmpty ? initials : 'P',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: size * 0.34,
                    ),
                  ),
                ),
        ),
        Positioned(
          bottom: -1,
          right: -1,
          child: Container(
            width: size * 0.36,
            height: size * 0.36,
            decoration: BoxDecoration(
              color: MetaColors.emerald,
              shape: BoxShape.circle,
              border: Border.all(color: MetaColors.bg(context), width: 2),
            ),
            child: Icon(Icons.check_rounded, color: Colors.black, size: size * 0.24),
          ),
        ),
      ],
    );
  }

  Widget _buildStudentHeader() {
    final trainerDisplay = _trainerName?.trim().isNotEmpty == true ? _trainerName! : 'Personal Trainer';
    final planDisplay = _workoutPlanTitle?.trim().isNotEmpty == true
        ? '$_workoutPlanTitle${_totalSplitsCount > 0 ? " ($_totalSplitsCount divisões)" : ""}'
        : 'Consultoria Ativa • Prescrição Individualizada';

    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. CARD HERO DA CONSULTORIA (Padrão One UI 7 / Meta)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MetaColors.card(context),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: MetaColors.cardBorder(context), width: 1.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _openCoachSheet,
                  behavior: HitTestBehavior.opaque,
                  child: _buildCoachAvatar(size: 46),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              trainerDisplay,
                              style: TextStyle(
                                color: MetaColors.text(context),
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: MetaColors.emerald.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'COACH',
                              style: TextStyle(
                                color: MetaColors.emerald,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        planDisplay,
                        style: TextStyle(
                          color: MetaColors.subtext(context),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                if (_messages.isNotEmpty) ...[
                  GlassIconButton(
                    icon: Icons.refresh_rounded,
                    tooltip: 'Limpar Conversa',
                    onTap: () => setState(() => _messages.clear()),
                  ),
                  const SizedBox(width: 6),
                ],
                GlassIconButton(
                  icon: Icons.more_vert_rounded,
                  tooltip: 'Mais Opções',
                  onTap: _openMoreMenu,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // 2. PULSE RETRÁTIL UNIFICADO: CENTRAL DE NOTIFICAÇÕES & VERSÃO DO APP
          ValueListenableBuilder<List<StudentNotificationItem>>(
            valueListenable: StudentNotificationService.notificationsNotifier,
            builder: (context, notifs, _) {
              final unreadList = notifs.where((n) => !n.isRead).toList();
              final topNotification = unreadList.isNotEmpty ? unreadList.first : null;

              return Row(
                children: [
                  // A. Alerta Proativo da Consultoria (ou Status Online)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: topNotification != null
                            ? const Color(0xFFF59E0B).withValues(alpha: 0.12)
                            : MetaColors.highlight(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: topNotification != null
                              ? const Color(0xFFF59E0B).withValues(alpha: 0.35)
                              : MetaColors.cardBorder(context),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            topNotification != null
                                ? Icons.notifications_active_rounded
                                : Icons.verified_user_rounded,
                            size: 15,
                            color: topNotification != null
                                ? const Color(0xFFF59E0B)
                                : MetaColors.emerald,
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              topNotification != null
                                  ? topNotification.title
                                  : (_isTrainerPro
                                      ? 'Mr. Coach Copiloto Pro • IA 24h Ativa'
                                      : 'Mr. Coach Essencial • Guia Biomecânico'),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: topNotification != null
                                    ? const Color(0xFFF59E0B)
                                    : MetaColors.text(context),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (unreadList.length > 1) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '+${unreadList.length - 1}',
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // B. Pílula de Sincronia Omnichannel WhatsApp
                  InkWell(
                    onTap: _openWhatsAppSyncSheet,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: _swappedExercises.isNotEmpty
                            ? MetaColors.emerald.withValues(alpha: 0.16)
                            : MetaColors.highlight(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _swappedExercises.isNotEmpty
                              ? MetaColors.emerald.withValues(alpha: 0.4)
                              : MetaColors.cardBorder(context),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.chat_rounded,
                            size: 13,
                            color: _swappedExercises.isNotEmpty ? MetaColors.emerald : MetaColors.subtext(context),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _swappedExercises.isNotEmpty
                                ? '${_swappedExercises.length} adaptado(s)'
                                : 'Sync Zap',
                            style: TextStyle(
                              color: _swappedExercises.isNotEmpty ? MetaColors.emerald : MetaColors.subtext(context),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
  PreferredSizeWidget _buildTrainerAppBar(BuildContext context, Color accentColor) {
    return AppBar(
        backgroundColor: MetaColors.bg(context),
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    accentColor.withValues(alpha: 0.25),
                    MetaColors.accentBlue.withValues(alpha: 0.15),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: accentColor.withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
              child: Icon(
                widget.isStudentView ? Icons.biotech_rounded : Icons.smart_toy_outlined,
                color: accentColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          widget.isStudentView ? 'Mr. Coach AI' : 'Mr. Coach B2B',
                          style: TextStyle(
                            color: MetaColors.text(context),
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            letterSpacing: -0.2,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: MetaColors.emerald.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: MetaColors.emerald.withValues(alpha: 0.3),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: MetaColors.emerald,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'ATIVO',
                              style: TextStyle(
                                color: MetaColors.emerald,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 1),
                  Text(
                    widget.isStudentView
                        ? 'Laboratório Biomecânico & Ativação 3D'
                        : 'Inteligência Comercial & Prescrição',
                    style: TextStyle(
                      color: MetaColors.subtext(context),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (_messages.isNotEmpty)
            IconButton(
              icon: Icon(
                Icons.refresh_rounded,
                color: MetaColors.subtext(context),
                size: 22,
              ),
              tooltip: 'Nova Análise / Limpar Chat',
              onPressed: () => setState(() => _messages.clear()),
            ),
          if (!widget.isStudentView)
            PopupMenuButton<String>(
              icon: Icon(
                _selectedModelId.contains('pro') ? Icons.psychology : Icons.bolt,
                color: accentColor,
              ),
              tooltip: 'Selecionar Modelo de IA',
              onSelected: (val) => setState(() => _selectedModelId = val),
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'gemini-3.1-pro-preview',
                  child: Row(
                    children: [
                      Icon(Icons.psychology, size: 18),
                      SizedBox(width: 8),
                      Text('Gemini 3.1 Pro (Deep Thinking)'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'gemini-2.5-flash',
                  child: Row(
                    children: [
                      Icon(Icons.bolt, size: 18),
                      SizedBox(width: 8),
                      Text('Gemini 2.5 Flash (Fast)'),
                    ],
                  ),
                ),
              ],
            ),
          if (kDebugMode)
            IconButton(
              icon: const Icon(Icons.settings_ethernet_rounded),
              tooltip: 'Configurar IP do Servidor (Dev)',
              onPressed: () => ServerConfigDialog.show(context),
            ),
        ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = widget.isStudentView ? MetaColors.emerald : AppColors.trainerIndigo;

    final bodyWidget = Column(
      children: [
        if (widget.isStudentView) _buildStudentHeader(),
        if (_messages.isEmpty) ...[
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. HERO SPOTLIGHT CARD (Estilo Nike Training Club / Whoop)
                    _buildHeroSpotlightCard(context, accentColor),
                    const SizedBox(height: 20),

                    // 2. GRADE DE AÇÕES RÁPIDAS 2x2 (Estilo Google Gemini & Apple Fitness+)
                    Row(
                      children: [
                        Icon(
                          Icons.grid_view_rounded,
                          size: 15,
                          color: MetaColors.subtext(context),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'AÇÕES RÁPIDAS DE ACADEMIA',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: MetaColors.subtext(context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildActionGrid(context),
                    const SizedBox(height: 24),

                    // 3. CARROSSEL DE PROMPTS SUGERIDOS (Estilo Chips Inteligentes)
                    _buildPromptsSection(context, accentColor),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ] else ...[
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  return Align(
                    alignment:
                        msg.isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.all(14),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.84,
                      ),
                      decoration: BoxDecoration(
                        color:
                            msg.isUser
                                ? accentColor.withValues(alpha: 0.18)
                                : msg.isError
                                ? Colors.red.shade900.withValues(alpha: 0.2)
                                : AppColors.card(context),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color:
                              msg.isUser
                                  ? accentColor.withValues(alpha: 0.4)
                                  : msg.isError
                                  ? Colors.red.shade700
                                  : AppColors.cardBorder(context),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            msg.text,
                            style: TextStyle(
                              fontSize: 13,
                              color:
                                  msg.isError
                                      ? Colors.red.shade200
                                      : AppColors.text(context),
                              height: 1.4,
                            ),
                          ),
                          // Card de Execução Biomecânica em Loop + Músculo Alvo (Padrão Ouro Mr. Coach AI)
                          if (msg.detectedExercise != null && !msg.isUser) ...[
                            const SizedBox(height: 14),
                            Container(
                              decoration: BoxDecoration(
                                color: MetaColors.highlight(context),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: MetaColors.emerald.withValues(alpha: 0.5),
                                  width: 1.2,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Mini Banner com animação de loop interativo
                                  InkWell(
                                    onTap: () {
                                      ExerciseMediaSheet.show(
                                        context,
                                        exerciseName: msg.detectedExercise!,
                                      );
                                    },
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
                                    child: Container(
                                      height: 105,
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.4),
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
                                      ),
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          // Efeito visual de gradiente e pulso biomecânico
                                          Container(
                                            decoration: BoxDecoration(
                                              gradient: RadialGradient(
                                                colors: [
                                                  MetaColors.emerald.withValues(alpha: 0.25),
                                                  Colors.transparent,
                                                ],
                                                radius: 0.8,
                                              ),
                                            ),
                                          ),
                                          Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: MetaColors.emerald.withValues(alpha: 0.2),
                                                  shape: BoxShape.circle,
                                                  border: Border.all(color: MetaColors.emerald),
                                                ),
                                                child: const Icon(
                                                  Icons.play_arrow_rounded,
                                                  color: Colors.white,
                                                  size: 28,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.touch_app_rounded, size: 12, color: Colors.white70),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'Toque para Ver Execução / GIF',
                                                    style: TextStyle(
                                                      color: MetaColors.emerald,
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          Positioned(
                                            top: 8,
                                            right: 8,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withValues(alpha: 0.6),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: const [
                                                  Icon(Icons.fiber_manual_record, color: Colors.redAccent, size: 8),
                                                  SizedBox(width: 4),
                                                  Text(
                                                    '3D LOOP',
                                                    style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  // Informações de Músculo Alvo & Ações
                                  Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          msg.detectedExercise!,
                                          style: TextStyle(
                                            color: MetaColors.text(context),
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: MetaColors.emerald.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: MetaColors.emerald.withValues(alpha: 0.3)),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.adjust_rounded, size: 12, color: MetaColors.emerald),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'Músculo Alvo: Fibras Primárias',
                                                    style: TextStyle(
                                                      color: MetaColors.emerald,
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: InkWell(
                                                onTap: () {
                                                  ExerciseMediaSheet.show(
                                                    context,
                                                    exerciseName: msg.detectedExercise!,
                                                  );
                                                },
                                                borderRadius: BorderRadius.circular(10),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                                  decoration: BoxDecoration(
                                                    color: MetaColors.highlight(context),
                                                    borderRadius: BorderRadius.circular(10),
                                                    border: Border.all(color: MetaColors.emerald.withValues(alpha: 0.5)),
                                                  ),
                                                  child: Row(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                      Icon(Icons.ondemand_video_rounded, size: 15, color: MetaColors.emerald),
                                                      const SizedBox(width: 6),
                                                      Text(
                                                        'Execução',
                                                        style: TextStyle(
                                                          color: MetaColors.emerald,
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: InkWell(
                                                onTap: () {
                                                  BiomechanicalAnalysisSheet.show(
                                                    context,
                                                    exerciseName: msg.detectedExercise!,
                                                    onAskAI: () => _sendPrompt(
                                                      'Explique a biomecânica detalhada do ${msg.detectedExercise}',
                                                    ),
                                                  );
                                                },
                                                borderRadius: BorderRadius.circular(10),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                                  decoration: BoxDecoration(
                                                    color: MetaColors.emerald,
                                                    borderRadius: BorderRadius.circular(10),
                                                  ),
                                                  child: Row(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: const [
                                                      Icon(Icons.biotech_rounded, size: 15, color: Colors.white),
                                                      SizedBox(width: 6),
                                                      Text(
                                                        'Raio-X Bio',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (widget.isStudentView) ...[
                                          const SizedBox(height: 8),
                                          SizedBox(
                                            width: double.infinity,
                                            child: FilledButton.tonalIcon(
                                              onPressed: () {
                                                _applySessionAdaptation(
                                                  originalExercise: _lastSelectedExerciseForSwap ??
                                                      (_studentExercises.isNotEmpty ? _studentExercises.first : 'Exercício Anterior'),
                                                  adaptedExercise: msg.detectedExercise!,
                                                  reason: 'Adaptação da Sessão de Hoje (Mr. Coach AI Copiloto)',
                                                );
                                              },
                                              icon: const Icon(
                                                Icons.playlist_add_check_rounded,
                                                size: 16,
                                              ),
                                              label: const Text(
                                                'Adaptar Só no Treino de Hoje',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              style: FilledButton.styleFrom(
                                                backgroundColor: MetaColors
                                                    .emerald
                                                    .withValues(alpha: 0.16),
                                                foregroundColor:
                                                    MetaColors.emerald,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  vertical: 8,
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          // Action Cards Interativos (Generative UI Mr. Coach AI)
                          if (msg.actionItems != null && msg.actionItems!.isNotEmpty) ...[
                            AiActionCard(
                              title: msg.actionCardTitle,
                              headerIcon: msg.actionCardIcon,
                              actions: msg.actionItems!,
                            ),
                          ],

                          if (msg.isError && kDebugMode) ...[
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () => ServerConfigDialog.show(context),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade900.withValues(
                                    alpha: 0.3,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.settings,
                                      size: 14,
                                      color: Colors.redAccent,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Ajustar IP do Servidor',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.redAccent,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          if (_isLoading)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              color: MetaColors.bg(context),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: accentColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    widget.isStudentView
                        ? 'Analisando biomecânica & torque articular...'
                        : 'Estruturando inteligência prescritiva...',
                    style: TextStyle(
                      fontSize: 12,
                      color: MetaColors.subtext(context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

          // BARRA INFERIOR DE DIGITAÇÃO FLUTUANTE (Ergonômica & Estilo Meta Obsidian)
          _buildFloatingPromptBar(context, accentColor),
        ],
      );

    if (widget.isStudentView) {
      return Scaffold(
        backgroundColor: MetaColors.bg(context),
        body: Stack(
          children: [
            const AmbientGlowCanvas(),
            SafeArea(
              bottom: false,
              child: bodyWidget,
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: MetaColors.bg(context),
      appBar: _buildTrainerAppBar(context, accentColor),
      body: bodyWidget,
    );
  }

  /// 1. Hero Spotlight Card - Copiloto de Salão em Tempo Real
  Widget _buildHeroSpotlightCard(BuildContext context, Color accentColor) {
    return AnimatedBuilder(
      animation: ThemeController.instance,
      builder: (context, _) {
        final isDark = MetaColors.isDark(context);
        final mode = ThemeController.instance.cardThemeMode;
        // O modo editorial 3D rico é ativo se for editorial3D E estiver em dark mode,
        // ou se for explicitamente ativado mantendo harmonia com o tema
        final useEditorialMode = mode == CardVisualThemeMode.editorial3D && isDark;

        final titleColor = useEditorialMode
            ? Colors.white
            : (isDark ? Colors.white : const Color(0xFF0F172A));
        final subtitleColor = useEditorialMode
            ? Colors.white.withValues(alpha: 0.9)
            : (isDark ? Colors.white.withValues(alpha: 0.8) : const Color(0xFF475569));
        final iconBg = useEditorialMode
            ? Colors.white.withValues(alpha: 0.16)
            : (isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0));
        final iconColor = useEditorialMode
            ? Colors.white
            : (isDark ? Colors.white70 : const Color(0xFF475569));
        final chipBg = useEditorialMode
            ? Colors.white.withValues(alpha: 0.18)
            : (isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF1F5F9));
        final chipBorder = useEditorialMode
            ? Colors.white.withValues(alpha: 0.3)
            : (isDark ? Colors.white.withValues(alpha: 0.16) : const Color(0xFFCBD5E1));
        final chipTextColor = useEditorialMode
            ? Colors.white
            : (isDark ? Colors.white : const Color(0xFF0F172A));

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: useEditorialMode
                ? (widget.isStudentView
                    ? ThematicCardPalette.aiOrchid.editorialGradient
                    : ThematicCardPalette.biomechanicsCyan.editorialGradient)
                : LinearGradient(
                    colors: isDark
                        ? [
                            const Color(0xFF0F172A), // Dark Slate
                            const Color(0xFF042F2E), // Deep Teal
                          ]
                        : [
                            Colors.white,            // Pure White Flat Card
                            const Color(0xFFF0FDF4), // Light Mint
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: useEditorialMode
                  ? Colors.white.withValues(alpha: 0.2)
                  : (isDark ? MetaColors.emerald.withValues(alpha: 0.35) : const Color(0xFFA7F3D0)),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: useEditorialMode
                    ? (widget.isStudentView
                        ? const Color(0xFF7C3AED).withValues(alpha: 0.35)
                        : const Color(0xFF0EA5E9).withValues(alpha: 0.35))
                    : (isDark
                        ? MetaColors.emerald.withValues(alpha: 0.12)
                        : Colors.black.withValues(alpha: 0.04)),
                blurRadius: isDark ? 24 : 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // Marca d'água 3D volumétrica no modo editorial
              if (useEditorialMode)
                Positioned(
                  top: -10,
                  right: -8,
                  child: ThematicWatermark(
                    type: widget.isStudentView
                        ? ThematicWatermarkType.aiCopilot
                        : ThematicWatermarkType.biomechanics,
                    size: 145,
                    opacity: 0.85,
                    baseColor: Colors.white,
                  ),
                ),

              // Efeito especular de luz superior no topo do card
              if (useEditorialMode)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 50,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0.18),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),

              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: useEditorialMode
                                ? Colors.white.withValues(alpha: 0.2)
                                : MetaColors.emerald.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: useEditorialMode
                                  ? Colors.white.withValues(alpha: 0.4)
                                  : MetaColors.emerald.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.bolt_rounded,
                                size: 13,
                                color: useEditorialMode ? Colors.white : MetaColors.emerald,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                widget.isStudentView
                                    ? (_isTrainerPro ? 'COPILOTO DE SALÃO • PRO 24/7' : 'MODO ESSENCIAL • GUIA DE SALÃO')
                                    : 'MR. COACH ENTERPRISE',
                                style: TextStyle(
                                  color: useEditorialMode ? Colors.white : MetaColors.emerald,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: iconBg,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            widget.isStudentView ? Icons.fitness_center_rounded : Icons.business_center_rounded,
                            size: 16,
                            color: iconColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      widget.isStudentView
                          ? (_todaySplit != null
                              ? 'Treino ${_todaySplit!.splitIdentifier} • ${_todaySplit!.splitName}'
                              : 'Qual a dúvida da sua série agora?')
                          : 'Inteligência Estratégica & Prescrição',
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.isStudentView
                          ? (_todaySplit != null
                              ? '${_todaySplitExercises.length} exercícios na série. Aparelho ocupado ou dúvida biomecânica? Resposta direta em 5 segundos.'
                              : 'Aparelho ocupado, ajuste de postura para evitar dor ou dúvida de carga na série. Resposta direta em 5 segundos.')
                          : 'Periodização de força, fisiologia de hipertrofia, precificação de planos e engajamento no WhatsApp.',
                      style: TextStyle(
                        color: subtitleColor,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                    if (widget.isStudentView && (_todaySplitExercises.isNotEmpty || _studentExercises.isNotEmpty)) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: (_todaySplitExercises.isNotEmpty
                                ? _todaySplitExercises.map((e) => e.name).toList()
                                : _studentExercises)
                            .take(4)
                            .map((ex) {
                          final isSwapped = _swappedExercises.containsKey(ex);
                          final adaptedName = _swappedExercises[ex];

                          return InkWell(
                            onTap: () {
                              OneUiGlassSheet.show(
                                context,
                                header: Row(
                                  children: [
                                    const Icon(Icons.fitness_center_rounded, color: MetaColors.emerald, size: 22),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            ex,
                                            style: TextStyle(
                                              color: MetaColors.text(context),
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          Text(
                                            isSwapped ? 'Adaptado hoje para $adaptedName' : 'Exercício da sua série atual',
                                            style: TextStyle(
                                              color: MetaColors.subtext(context),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                actions: [
                                  GlassAction(
                                    icon: Icons.play_circle_fill_rounded,
                                    color: MetaColors.emerald,
                                    label: 'Ver Execução 3D & Checklist',
                                    subtitle: 'Postura, escápulas e cadência recomendada',
                                    onTap: () {
                                      Navigator.of(context, rootNavigator: true).pop();
                                      ExerciseMediaSheet.show(
                                        context,
                                        exerciseName: isSwapped ? adaptedName! : ex,
                                      );
                                    },
                                  ),
                                  GlassAction(
                                    icon: Icons.swap_horiz_rounded,
                                    color: const Color(0xFFF59E0B),
                                    label: 'Aparelho Ocupado? Trocar Agora',
                                    subtitle: 'Sugere 2 variações biomecânicas livres de fila',
                                    onTap: () {
                                      Navigator.of(context, rootNavigator: true).pop();
                                      _triggerExerciseSwapFlow(ex);
                                    },
                                  ),
                                ],
                              );
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: isSwapped
                                    ? MetaColors.emerald.withValues(alpha: 0.22)
                                    : chipBg,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSwapped
                                      ? MetaColors.emerald.withValues(alpha: 0.5)
                                      : chipBorder,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isSwapped ? Icons.check_circle_rounded : Icons.fitness_center_rounded,
                                    size: 11.5,
                                    color: isSwapped
                                        ? MetaColors.emerald
                                        : (useEditorialMode ? Colors.white : MetaColors.emerald),
                                  ),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      isSwapped ? '$ex → $adaptedName' : ex,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: isSwapped
                                            ? (isDark ? Colors.white : MetaColors.emerald)
                                            : chipTextColor,
                                        fontSize: 11,
                                        fontWeight: isSwapped ? FontWeight.w800 : FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 16),
                    // Botão Funcional Útil de Salão
                    InkWell(
                      onTap: () {
                        if (widget.isStudentView) {
                          _showBusyMachineModal();
                        } else {
                          _sendPrompt(
                            'Crie um script de WhatsApp humanizado e persuasivo para reengajar alunos ausentes há mais de 10 dias.',
                          );
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: useEditorialMode ? Colors.white : MetaColors.emerald,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: useEditorialMode
                                  ? Colors.black.withValues(alpha: 0.25)
                                  : MetaColors.emerald.withValues(alpha: 0.4),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              widget.isStudentView ? Icons.swap_horiz_rounded : Icons.chat_rounded,
                              size: 17,
                              color: useEditorialMode ? const Color(0xFF6D28D9) : Colors.black,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              widget.isStudentView
                                  ? 'Aparelho Ocupado? Trocar em 1 Toque'
                                  : 'Gerar Script de WhatsApp para Alunos',
                              style: TextStyle(
                                color: useEditorialMode ? const Color(0xFF6D28D9) : Colors.black,
                                fontWeight: FontWeight.w800,
                                fontSize: 12.5,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 14,
                              color: useEditorialMode ? const Color(0xFF6D28D9) : Colors.black,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 2. Grade de Ações Rápidas 2x2 com cards de alta utilidade prática no salão
  Widget _buildActionGrid(BuildContext context) {
    final List<_ActionItem> actions;

    if (widget.isStudentView) {
      actions = [
        _ActionItem(
          title: 'Aparelho Ocupado?',
          subtitle: 'Troca por halter ou polia livre',
          icon: Icons.swap_horiz_rounded,
          color: const Color(0xFFF59E0B), // Âmbar
          onTap: () => _sendPrompt(
            'O aparelho que eu ia usar agora está ocupado na academia. Quais as melhores variações livres ou na polia mantendo o mesmo estímulo muscular?',
          ),
        ),
        _ActionItem(
          title: 'Senti Dor / Fisgada',
          subtitle: 'Ajustar pegada ou troca segura',
          icon: Icons.healing_rounded,
          color: const Color(0xFFEF4444), // Coral/Vermelho
          onTap: () => _sendPrompt(
            'Senti um desconforto/fisgada na articulação durante o exercício. Como corrigir a pegada e postura ou qual exercício alternativo seguro fazer agora?',
          ),
        ),
        _ActionItem(
          title: 'Execução em 3 Passos',
          subtitle: 'Banco, escápulas e trajetória',
          icon: Icons.checklist_rounded,
          color: MetaColors.accentBlue,
          onTap: () => _sendPrompt(
            'Me dê um checklist direto em 3 passos para executar meu exercício com máxima eficiência e segurança: ajuste de banco, escápulas/core e amplitude.',
          ),
        ),
        _ActionItem(
          title: 'Carga & Repetições',
          subtitle: 'Tá leve ou pesado? RIR e descanso',
          icon: Icons.fitness_center_rounded,
          color: MetaColors.emerald,
          onTap: () => _sendPrompt(
            'Como saber se a carga está leve ou pesada demais? Qual a regra prática de repetições em reserva (RIR) e tempo de descanso para hipertrofia?',
          ),
        ),
      ];
    } else {
      // Visão do Treinador: Estratégias e Prescrição Avançada
      actions = [
        _ActionItem(
          title: 'Prescrição & Divisão',
          subtitle: 'Upper/Lower, PPL ou DUP',
          icon: Icons.calendar_month_rounded,
          color: MetaColors.accentBlue,
          onTap: () => _sendPrompt(
            'Qual a melhor divisão de treino (Upper/Lower, PPL ou DUP) para aluno intermediário com 4 dias na semana?',
          ),
        ),
        _ActionItem(
          title: 'Fisiologia & Fadiga',
          subtitle: 'Volume semanal, RPE e Deload',
          icon: Icons.bolt_rounded,
          color: Colors.amber,
          onTap: () => _sendPrompt(
            'Como calcular volume de séries efetivas semanais por grupo muscular e quando prescrever deload?',
          ),
        ),
        _ActionItem(
          title: 'Scripts de WhatsApp',
          subtitle: 'Reengajamento e cobrança suave',
          icon: Icons.chat_rounded,
          color: MetaColors.emerald,
          onTap: () => _sendPrompt(
            'Crie mensagens persuasivas e elegantes para WhatsApp: 1) reengajar aluno ausente e 2) renovação de ciclo.',
          ),
        ),
        _ActionItem(
          title: 'Precificação & Vendas',
          subtitle: 'Planos híbridos e escala B2B',
          icon: Icons.trending_up_rounded,
          color: const Color(0xFFA855F7), // Roxo
          onTap: () => _sendPrompt(
            r'Como estruturar e precificar consultoria híbrida recorrente (R$ 180 a 250/mês) para escalar sem estafa de agenda?',
          ),
        ),
      ];
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: actions.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.45,
      ),
      itemBuilder: (context, index) {
        final item = actions[index];
        return InkWell(
          onTap: item.onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MetaColors.card(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: item.color.withValues(alpha: 0.25),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    item.icon,
                    size: 18,
                    color: item.color,
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        color: MetaColors.text(context),
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
                      style: TextStyle(
                        color: MetaColors.subtext(context),
                        fontSize: 10.5,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 3. Seção de Prompts Sugeridos com Carrossel e Pilares de Conhecimento
  Widget _buildPromptsSection(BuildContext context, Color accentColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!widget.isStudentView) ...[
          Row(
            children: [
              Icon(
                Icons.category_rounded,
                size: 15,
                color: MetaColors.subtext(context),
              ),
              const SizedBox(width: 6),
              Text(
                'PILARES DO TREINADOR',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: MetaColors.subtext(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildPillarChip(context, 'Todos', Icons.auto_awesome, accentColor),
                const SizedBox(width: 8),
                _buildPillarChip(context, 'Biomecânica', Icons.biotech_rounded, MetaColors.accentBlue),
                const SizedBox(width: 8),
                _buildPillarChip(context, 'Fisiologia', Icons.bolt, Colors.amber),
                const SizedBox(width: 8),
                _buildPillarChip(context, 'Treinamento', Icons.fitness_center_rounded, Colors.orange),
                const SizedBox(width: 8),
                _buildPillarChip(context, 'Negócios B2B', Icons.trending_up_rounded, MetaColors.emerald),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        Row(
          children: [
            Icon(
              Icons.touch_app_rounded,
              size: 15,
              color: MetaColors.subtext(context),
            ),
            const SizedBox(width: 6),
            Text(
              widget.isStudentView
                  ? 'PERGUNTAS FREQUENTES NO SALÃO'
                  : 'PROMPTS SUGERIDOS ($_selectedPillar)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: MetaColors.subtext(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Carrossel Horizontal de Chips Estilizados
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: _quickPrompts.map((prompt) {
              final is3d = prompt.contains('Raio-X') || prompt.contains('Supino');
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  backgroundColor: MetaColors.card(context),
                  side: BorderSide(
                    color: is3d
                        ? accentColor.withValues(alpha: 0.4)
                        : MetaColors.cardBorder(context),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  avatar: Icon(
                    is3d ? Icons.biotech_rounded : Icons.bolt_rounded,
                    size: 15,
                    color: is3d ? accentColor : Colors.amber,
                  ),
                  label: Text(
                    prompt,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: is3d ? MetaColors.text(context) : MetaColors.subtext(context),
                      fontWeight: is3d ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  onPressed: () => _sendPrompt(prompt),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  /// Barra Flutuante de Envio de Mensagem no padrão ergonômico Meta
  Widget _buildFloatingPromptBar(BuildContext context, Color accentColor) {
    return Container(
      decoration: BoxDecoration(
        color: MetaColors.bg(context),
        border: Border(
          top: BorderSide(color: MetaColors.cardBorder(context), width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.isStudentView) ...[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    _buildShortcutPill(
                      context,
                      icon: Icons.assignment_rounded,
                      label: '📋 Ficha de Hoje',
                      onTap: _showTodayWorkoutCard,
                    ),
                    const SizedBox(width: 8),
                    _buildShortcutPill(
                      context,
                      icon: Icons.swap_horiz_rounded,
                      label: '⚠️ Aparelho Ocupado',
                      color: const Color(0xFFF59E0B),
                      onTap: _showBusyMachineModal,
                    ),
                    const SizedBox(width: 8),
                    _buildShortcutPill(
                      context,
                      icon: Icons.local_fire_department_rounded,
                      label: '🔥 Ofensiva',
                      color: const Color(0xFFF97316),
                      onTap: () => _sendPrompt('2'),
                    ),
                    const SizedBox(width: 8),
                    _buildShortcutPill(
                      context,
                      icon: Icons.water_drop_rounded,
                      label: '💧 +250ml Água',
                      color: const Color(0xFF38BDF8),
                      onTap: () => _sendPrompt('+250ml'),
                    ),
                    const SizedBox(width: 8),
                    _buildShortcutPill(
                      context,
                      icon: Icons.chat_rounded,
                      label: '💬 Zap Sync',
                      color: MetaColors.emerald,
                      onTap: _openWhatsAppSyncSheet,
                    ),
                  ],
                ),
              ),
            ],
            Row(
              children: [
                if (widget.isStudentView) ...[
                  IconButton(
                    icon: const Icon(Icons.mic_rounded, color: Color(0xFF8B5CF6), size: 22),
                    tooltip: 'Dúvidas Rápidas de Salão',
                    onPressed: _showVoiceInputDialog,
                  ),
                ],
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: MetaColors.highlight(context),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: MetaColors.cardBorder(context),
                    width: 1,
                  ),
                ),
                child: TextField(
                  controller: _promptCtrl,
                  style: TextStyle(
                    color: MetaColors.text(context),
                    fontSize: 13.5,
                  ),
                  decoration: InputDecoration(
                    hintText: widget.isStudentView
                        ? 'Dúvida de execução, ângulo, dor ou troca...'
                        : 'Digite sua dúvida de prescrição ou negócio...',
                    hintStyle: TextStyle(
                      color: MetaColors.subtext(context),
                      fontSize: 13,
                    ),
                    prefixIcon: Icon(
                      Icons.smart_toy_outlined,
                      size: 18,
                      color: MetaColors.subtext(context),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onSubmitted: (_) => _sendPrompt(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: MetaColors.emerald,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: MetaColors.emerald.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_upward_rounded, size: 20, color: Colors.black),
                onPressed: _isLoading ? null : () => _sendPrompt(),
              ),
            ),
          ],
        ),
          ],
          ),
        ),
      ),
    );
  }

  Widget _buildShortcutPill(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final effectiveColor = color ?? MetaColors.emerald;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: effectiveColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: effectiveColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: effectiveColor),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: effectiveColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPillarChip(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
  ) {
    final isSelected = _selectedPillar == title;
    return ChoiceChip(
      selected: isSelected,
      showCheckmark: false,
      avatar: Icon(icon, size: 14, color: isSelected ? Colors.black : color),
      label: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
          color: isSelected ? Colors.black : MetaColors.text(context),
        ),
      ),
      backgroundColor: MetaColors.card(context),
      selectedColor: color,
      side: BorderSide(
        color: isSelected ? color : MetaColors.cardBorder(context),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onSelected: (_) => setState(() => _selectedPillar = title),
    );
  }
}

class _ActionItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  _ActionItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final bool isError;
  final String? detectedExercise;
  final List<AiActionCardItem>? actionItems;
  final String? actionCardTitle;
  final IconData? actionCardIcon;

  _ChatMessage({
    required this.text,
    required this.isUser,
    this.isError = false,
    this.detectedExercise,
    this.actionItems,
    this.actionCardTitle,
    this.actionCardIcon,
  });
}
