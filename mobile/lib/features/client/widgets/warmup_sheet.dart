import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/widgets/meta_components.dart';

/// Modelo de dados para um movimento de mobilidade do aquecimento.
class WarmupExercise {
  final String title;
  final String focus;
  final String tip;
  final int durationSeconds;
  final IconData icon;

  const WarmupExercise({
    required this.title,
    required this.focus,
    required this.tip,
    required this.durationSeconds,
    required this.icon,
  });
}

/// BottomSheet imersivo com timer regressivo de 3 minutos e movimentos
/// articulares dinâmicos guiados por foco muscular.
class WarmupSheet extends StatefulWidget {
  final String initialFocus;

  const WarmupSheet({
    super.key,
    this.initialFocus = 'Geral',
  });

  /// Método estático conveniente para exibir o BottomSheet.
  static Future<bool?> show(BuildContext context, {String initialFocus = 'Geral'}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WarmupSheet(initialFocus: initialFocus),
    );
  }

  @override
  State<WarmupSheet> createState() => _WarmupSheetState();
}

class _WarmupSheetState extends State<WarmupSheet> {
  late String _selectedFocus;
  late List<WarmupExercise> _exercises;
  int _currentExerciseIndex = 0;
  int _remainingSeconds = 180; // 3 minutos totais
  int _exerciseRemainingSeconds = 60;
  bool _isRunning = true;
  Timer? _timer;

  // Presets anatômicos por grupo muscular
  static const Map<String, List<WarmupExercise>> _presets = {
    'Geral': [
      WarmupExercise(
        title: 'Rotação de Manguito & Escápulas',
        focus: 'Ombros e Cintura Escapular',
        tip: 'Mantenha os cotovelos colados ao corpo a 90° e gire suavemente para lubrificar a articulação.',
        durationSeconds: 60,
        icon: Icons.sync_rounded,
      ),
      WarmupExercise(
        title: 'Alongamento Dinâmico Torácico',
        focus: 'Peitoral e Coluna Torácica',
        tip: 'Abra os braços alternando a altura para expandir a caixa torácica e preparar as escápulas.',
        durationSeconds: 60,
        icon: Icons.accessibility_new_rounded,
      ),
      WarmupExercise(
        title: 'Agachamento Profundo Dinâmico',
        focus: 'Quadril, Glúteos e Joelhos',
        tip: 'Desça controlando com os calcanhares no chão para ativar a circulação sinovial nas pernas.',
        durationSeconds: 60,
        icon: Icons.fitness_center_rounded,
      ),
    ],
    'Superiores': [
      WarmupExercise(
        title: 'Ativação de Manguito Rotador',
        focus: 'Manguito Rotador e Deltoides',
        tip: 'Giro externo controlado para proteger os ombros contra pinçamentos nas cargas pesadas.',
        durationSeconds: 60,
        icon: Icons.sync_rounded,
      ),
      WarmupExercise(
        title: 'Flexão Escapular no Solo',
        focus: 'Serrátil Anterior e Rombóides',
        tip: 'Na posição de prancha, aproxime e afaste as escápulas sem dobrar os cotovelos.',
        durationSeconds: 60,
        icon: Icons.accessibility_new_rounded,
      ),
      WarmupExercise(
        title: 'Rotação de Punhos & Extensão',
        focus: 'Punhos, Antebraço e Cotovelos',
        tip: 'Gire suavemente os punhos em ambos os sentidos para suportar as barras e halteres.',
        durationSeconds: 60,
        icon: Icons.sports_gymnastics_rounded,
      ),
    ],
    'Inferiores': [
      WarmupExercise(
        title: 'Mobilidade de Tornozelo',
        focus: 'Dorsiflexão de Tornozelo',
        tip: 'Projete o joelho para a frente sem descolar o calcanhar do chão. Melhora a profundidade do agacho.',
        durationSeconds: 60,
        icon: Icons.directions_walk_rounded,
      ),
      WarmupExercise(
        title: 'Rotação de Quadril 90/90',
        focus: 'Quadril e Cápsula Articular',
        tip: 'Sentado no chão, alterne os joelhos para os lados mantendo postura ereta.',
        durationSeconds: 60,
        icon: Icons.airline_seat_recline_normal_rounded,
      ),
      WarmupExercise(
        title: 'Agachamento Cossaco Dinâmico',
        focus: 'Adutores, Posteriores e Glúteos',
        tip: 'Afaste as pernas e desça de lado alternadamente, alongando a virilha com controle.',
        durationSeconds: 60,
        icon: Icons.fitness_center_rounded,
      ),
    ],
  };

  @override
  void initState() {
    super.initState();
    _selectedFocus = widget.initialFocus;
    _loadPreset(_selectedFocus);
    _startTimer();
  }

  void _loadPreset(String focus) {
    _exercises = _presets[focus] ?? _presets['Geral']!;
    _currentExerciseIndex = 0;
    _remainingSeconds = _exercises.fold(0, (acc, ex) => acc + ex.durationSeconds);
    _exerciseRemainingSeconds = _exercises.first.durationSeconds;
  }

  void _changeFocus(String newFocus) {
    if (newFocus == _selectedFocus) return;
    setState(() {
      _selectedFocus = newFocus;
      _loadPreset(newFocus);
    });
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isRunning) return;

      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
          if (_exerciseRemainingSeconds > 0) {
            _exerciseRemainingSeconds--;
          } else if (_currentExerciseIndex < _exercises.length - 1) {
            _currentExerciseIndex++;
            _exerciseRemainingSeconds = _exercises[_currentExerciseIndex].durationSeconds;
            HapticFeedback.mediumImpact();
          }
        });
      } else {
        _timer?.cancel();
        _onCompleted();
      }
    });
  }

  void _togglePlayPause() {
    setState(() => _isRunning = !_isRunning);
    HapticFeedback.selectionClick();
  }

  void _nextExercise() {
    if (_currentExerciseIndex < _exercises.length - 1) {
      setState(() {
        _currentExerciseIndex++;
        _exerciseRemainingSeconds = _exercises[_currentExerciseIndex].durationSeconds;
      });
      HapticFeedback.lightImpact();
    } else {
      _onCompleted();
    }
  }

  void _onCompleted() {
    HapticFeedback.heavyImpact();
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatTime(int totalSeconds) {
    final m = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = MetaColors.isDark(context);
    final bg = isDark ? MetaColors.background : MetaColors.lightBackground;
    final cardBg = isDark ? MetaColors.surface : MetaColors.lightSurface;
    final border = isDark ? MetaColors.border : MetaColors.lightBorder;
    final textColor = isDark ? MetaColors.textPrimary : MetaColors.lightTextPrimary;
    final subtextColor = isDark ? MetaColors.textSecondary : MetaColors.lightTextSecondary;

    final currentExercise = _exercises[_currentExerciseIndex];
    final totalPresetSeconds = _exercises.fold(0, (acc, ex) => acc + ex.durationSeconds);
    final progress = totalPresetSeconds > 0
        ? (1.0 - (_remainingSeconds / totalPresetSeconds)).clamp(0.0, 1.0)
        : 0.0;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.90,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: border, width: 1.5)),
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: subtextColor.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 2. Top Header: Título & Botão Fechar
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: MetaColors.emerald.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.timer_outlined,
                      color: MetaColors.emerald,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Aquecimento Específico',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Mobilidade articular ativa • 3 Minutos',
                          style: TextStyle(
                            color: subtextColor,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: subtextColor, size: 20),
                    onPressed: () => Navigator.pop(context, false),
                    tooltip: 'Fechar',
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // 3. Seletor de Foco Muscular (Chips)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['Geral', 'Superiores', 'Inferiores'].map((focus) {
                    final isSelected = _selectedFocus == focus;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(focus == 'Geral'
                            ? '🎯 Full Body'
                            : (focus == 'Superiores'
                                ? '🦾 Superiores'
                                : '🦵 Inferiores')),
                        selected: isSelected,
                        onSelected: (_) => _changeFocus(focus),
                        selectedColor: MetaColors.emerald.withValues(alpha: 0.2),
                        labelStyle: TextStyle(
                          color: isSelected ? MetaColors.emerald : subtextColor,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          fontSize: 11,
                        ),
                        backgroundColor: cardBg,
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: isSelected ? MetaColors.emerald : border,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),

              // 4. Miolo com Scroll
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Display Digital do Cronômetro & Barra de Progresso
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: border),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'TEMPO RESTANTE',
                                      style: TextStyle(
                                        color: subtextColor,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _formatTime(_remainingSeconds),
                                      style: TextStyle(
                                        color: textColor,
                                        fontSize: 28,
                                        fontWeight: FontWeight.w900,
                                        fontFeatures: const [FontFeature.tabularFigures()],
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _isRunning
                                        ? MetaColors.emerald.withValues(alpha: 0.15)
                                        : Colors.orange.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _isRunning ? MetaColors.emerald : Colors.orange,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        _isRunning ? Icons.play_arrow_rounded : Icons.pause_rounded,
                                        size: 14,
                                        color: _isRunning ? MetaColors.emerald : Colors.orange,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _isRunning ? 'Em Andamento' : 'Pausado',
                                        style: TextStyle(
                                          color: _isRunning ? MetaColors.emerald : Colors.orange,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: progress,
                                backgroundColor: isDark ? Colors.white12 : Colors.black12,
                                valueColor: const AlwaysStoppedAnimation<Color>(MetaColors.emerald),
                                minHeight: 6,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Card do Exercício de Aquecimento Atual
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: MetaColors.emerald.withValues(alpha: 0.35),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: MetaColors.emerald.withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    currentExercise.icon,
                                    color: MetaColors.emerald,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Movimento ${_currentExerciseIndex + 1} de ${_exercises.length}',
                                        style: const TextStyle(
                                          color: MetaColors.emerald,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        currentExercise.title,
                                        style: TextStyle(
                                          color: textColor,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isDark ? MetaColors.surfaceHighlight : MetaColors.lightSurfaceHighlight,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _formatTime(_exerciseRemainingSeconds),
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      fontFeatures: const [FontFeature.tabularFigures()],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Foco: ${currentExercise.focus}',
                              style: TextStyle(
                                color: subtextColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? MetaColors.surfaceHighlight.withValues(alpha: 0.5)
                                    : MetaColors.lightSurfaceHighlight,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.lightbulb_outline_rounded,
                                    color: MetaColors.emerald,
                                    size: 15,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      currentExercise.tip,
                                      style: TextStyle(
                                        color: subtextColor,
                                        fontSize: 11,
                                        height: 1.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // 5. Linha de Ações Fixa no Rodapé (Pausar/Play, Próximo, Concluir)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _togglePlayPause,
                      icon: Icon(
                        _isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: textColor,
                        size: 18,
                      ),
                      label: Text(
                        _isRunning ? 'Pausar' : 'Continuar',
                        style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: border),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_currentExerciseIndex < _exercises.length - 1)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _nextExercise,
                        icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 18),
                        label: const Text(
                          'Próximo',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? MetaColors.surfaceHighlight : MetaColors.lightEmerald,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _onCompleted,
                      icon: const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                      label: const Text(
                        'Concluir',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MetaColors.emerald,
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
            ],
          ),
        ),
      ),
    );
  }
}

