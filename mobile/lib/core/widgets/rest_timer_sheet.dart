import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'meta_components.dart';

/// BottomSheet imersivo e tátil de descanso entre séries (Padrão Ouro Mr. Coach AI).
///
/// Recursos:
/// - Temporizador regressivo circular com animação de pulso.
/// - Cadência Háptica & Sonora nos últimos 3 segundos (3, 2, 1, GO!).
/// - Suporte conceitual e visual a Audio Ducking (aviso para não perder o timing enquanto ouve música).
/// - Presets rápidos de descanso (30s, 60s, 90s, 120s) e botões de ajuste fino (+15s, +30s, -15s).
/// - Transição de cores e auras dinâmicas (Esmeralda -> Âmbar em <15s -> Vermelho urgente em <=3s).
class RestTimerSheet extends StatefulWidget {
  final int initialSeconds;
  final String exerciseName;
  final VoidCallback? onFinished;

  const RestTimerSheet({
    super.key,
    required this.initialSeconds,
    required this.exerciseName,
    this.onFinished,
  });

  /// Executa o feedback háptico e sonoro cadenciado (pode ser invocado por qualquer tela de treino)
  static void triggerCadencedFeedback(
    int secondsRemaining, {
    bool soundEnabled = true,
    bool hapticEnabled = true,
  }) {
    try {
      if (secondsRemaining == 3) {
        if (hapticEnabled) HapticFeedback.lightImpact();
        if (soundEnabled) SystemSound.play(SystemSoundType.click);
      } else if (secondsRemaining == 2) {
        if (hapticEnabled) HapticFeedback.mediumImpact();
        if (soundEnabled) SystemSound.play(SystemSoundType.click);
      } else if (secondsRemaining == 1) {
        if (hapticEnabled) HapticFeedback.heavyImpact();
        if (soundEnabled) SystemSound.play(SystemSoundType.click);
      } else if (secondsRemaining <= 0) {
        if (hapticEnabled) {
          HapticFeedback.heavyImpact();
          Future.delayed(
            const Duration(milliseconds: 140),
            () => HapticFeedback.heavyImpact(),
          );
        }
        if (soundEnabled) SystemSound.play(SystemSoundType.alert);
      }
    } catch (_) {}
  }

  /// Exibe o BottomSheet com abertura suave e haptic inicial
  static Future<void> show(
    BuildContext context, {
    required int seconds,
    required String exerciseName,
    VoidCallback? onFinished,
  }) {
    HapticFeedback.selectionClick();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RestTimerSheet(
        initialSeconds: seconds > 0 ? seconds : 60,
        exerciseName: exerciseName,
        onFinished: onFinished,
      ),
    );
  }

  @override
  State<RestTimerSheet> createState() => _RestTimerSheetState();
}

class _RestTimerSheetState extends State<RestTimerSheet>
    with SingleTickerProviderStateMixin {
  late int _remainingSeconds;
  late int _totalSeconds;
  Timer? _timer;
  bool _isRunning = true;
  bool _soundAlertEnabled = true;
  bool _hapticAlertEnabled = true;
  late AnimationController _pulseController;

  static const String _kSoundPrefKey = 'rest_timer_sound_enabled';
  static const String _kHapticPrefKey = 'rest_timer_haptic_enabled';

  @override
  void initState() {
    super.initState();
    _totalSeconds = widget.initialSeconds;
    _remainingSeconds = widget.initialSeconds;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _loadPreferences();
    _startTimer();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _soundAlertEnabled = prefs.getBool(_kSoundPrefKey) ?? true;
          _hapticAlertEnabled = prefs.getBool(_kHapticPrefKey) ?? true;
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleSoundAlert() async {
    HapticFeedback.selectionClick();
    final newVal = !_soundAlertEnabled;
    setState(() {
      _soundAlertEnabled = newVal;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kSoundPrefKey, newVal);
    } catch (_) {}
  }

  Future<void> _toggleHapticAlert() async {
    HapticFeedback.selectionClick();
    final newVal = !_hapticAlertEnabled;
    setState(() {
      _hapticAlertEnabled = newVal;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kHapticPrefKey, newVal);
    } catch (_) {}
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = true;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_remainingSeconds > 1) {
        setState(() {
          _remainingSeconds--;
        });
        if (_remainingSeconds <= 3) {
          RestTimerSheet.triggerCadencedFeedback(
            _remainingSeconds,
            soundEnabled: _soundAlertEnabled,
            hapticEnabled: _hapticAlertEnabled,
          );
        }
      } else {
        _timer?.cancel();
        setState(() {
          _remainingSeconds = 0;
          _isRunning = false;
        });
        RestTimerSheet.triggerCadencedFeedback(
          0,
          soundEnabled: _soundAlertEnabled,
          hapticEnabled: _hapticAlertEnabled,
        );
        widget.onFinished?.call();
      }
    });
  }

  void _pauseTimer() {
    HapticFeedback.selectionClick();
    _timer?.cancel();
    setState(() {
      _isRunning = false;
    });
  }

  void _addSeconds(int delta) {
    HapticFeedback.selectionClick();
    setState(() {
      _remainingSeconds = (_remainingSeconds + delta).clamp(0, 900);
      if (_remainingSeconds > _totalSeconds) {
        _totalSeconds = _remainingSeconds;
      }
    });
  }

  void _setPresetDuration(int seconds) {
    HapticFeedback.selectionClick();
    _timer?.cancel();
    setState(() {
      _totalSeconds = seconds;
      _remainingSeconds = seconds;
    });
    _startTimer();
  }

  void _resetTimer() {
    HapticFeedback.selectionClick();
    _timer?.cancel();
    setState(() {
      _remainingSeconds = widget.initialSeconds;
      _totalSeconds = widget.initialSeconds;
      _isRunning = false;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  String _formatTime(int totalSecs) {
    final mins = totalSecs ~/ 60;
    final secs = totalSecs % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Color _getTimerThemeColor(bool isFinished) {
    if (isFinished) return MetaColors.emerald;
    if (_remainingSeconds <= 3) return Colors.redAccent;
    if (_remainingSeconds < 15) return Colors.amber;
    return MetaColors.emerald;
  }

  String _getUrgentCountdownLabel(bool isFinished) {
    if (isFinished) return 'HORA DA PRÓXIMA SÉRIE! GO! 🔥';
    if (_remainingSeconds == 3) return '3 • PREPARE-SE!';
    if (_remainingSeconds == 2) return '2 • RESPIRE FUNDO!';
    if (_remainingSeconds == 1) return '1 • POSICIONE-SE!';
    return _isRunning ? 'Em recuperação ativa...' : 'Descanso pausado';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = MetaColors.isDark(context);
    final bg = isDark ? MetaColors.background : MetaColors.lightSurface;
    final textPrimary = isDark ? MetaColors.textPrimary : MetaColors.lightTextPrimary;
    final textSecondary = isDark ? MetaColors.textSecondary : MetaColors.lightTextSecondary;
    final border = isDark ? MetaColors.border : MetaColors.lightBorder;

    final progress = _totalSeconds > 0 ? (_remainingSeconds / _totalSeconds).clamp(0.0, 1.0) : 0.0;
    final isFinished = _remainingSeconds == 0;
    final themeColor = _getTimerThemeColor(isFinished);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(
          top: BorderSide(
            color: themeColor.withValues(alpha: 0.5),
            width: 1.8,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.7),
            blurRadius: 32,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Barra de arrasto do modal
              Center(
                child: Container(
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: textSecondary.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Cabeçalho: Nome do Exercício & Botão Fechar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: themeColor,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: themeColor.withValues(alpha: 0.6),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'TEMPO DE DESCANSO ATIVO',
                              style: TextStyle(
                                fontSize: 11,
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.w900,
                                color: themeColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.exerciseName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: textSecondary, size: 22),
                    tooltip: 'Minimizar Descanso',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Mostrador Circular Regressivo com Pulso
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 210,
                    height: 210,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 12,
                      backgroundColor: isDark
                          ? const Color(0xFF131B2E)
                          : MetaColors.lightSurfaceHighlight,
                      valueColor: AlwaysStoppedAnimation<Color>(themeColor),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          final scale = (isFinished || (_remainingSeconds <= 3 && _remainingSeconds > 0))
                              ? 1.0 + (_pulseController.value * 0.08)
                              : 1.0;
                          return Transform.scale(
                            scale: scale,
                            child: Text(
                              _formatTime(_remainingSeconds),
                              style: TextStyle(
                                fontSize: 52,
                                fontWeight: FontWeight.w900,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                                color: themeColor,
                                shadows: [
                                  BoxShadow(
                                    color: themeColor.withValues(alpha: 0.4),
                                    blurRadius: 20,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getUrgentCountdownLabel(isFinished),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: (_remainingSeconds <= 3 && _remainingSeconds > 0)
                              ? Colors.redAccent
                              : (isFinished ? MetaColors.emerald : textSecondary),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Presets Rápidos de Descanso (30s, 60s, 90s, 120s)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [30, 60, 90, 120].map((preset) {
                  final isSelected = _totalSeconds == preset && _isRunning;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: InkWell(
                      onTap: () => _setPresetDuration(preset),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? MetaColors.emerald.withValues(alpha: 0.2)
                              : (isDark ? const Color(0xFF131B2E) : MetaColors.lightSurfaceHighlight),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? MetaColors.emerald
                                : border,
                            width: isSelected ? 1.4 : 1.0,
                          ),
                        ),
                        child: Text(
                          '${preset}s',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: isSelected ? MetaColors.emerald : textSecondary,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

              // Botões de Ajuste Fino (-15s e +15s / +30s)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: () => _addSeconds(-15),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textSecondary,
                      side: BorderSide(color: border),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('-15s', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () => _addSeconds(15),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: MetaColors.emerald,
                      side: const BorderSide(color: MetaColors.emerald),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('+15s', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () => _addSeconds(30),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: MetaColors.emerald,
                      side: const BorderSide(color: MetaColors.emerald),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('+30s', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Painel de Audio Ducking & Hápticos
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF131B2E) : MetaColors.lightSurfaceHighlight,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            _soundAlertEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                            size: 18,
                            color: _soundAlertEnabled ? MetaColors.emerald : textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Feedback Cadenciado (3-2-1 GO)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: textPrimary,
                                  ),
                                ),
                                Text(
                                  'Sinais sonoros e vibrações nos últimos segundos',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            _soundAlertEnabled ? Icons.notifications_active_rounded : Icons.notifications_off_outlined,
                            size: 19,
                            color: _soundAlertEnabled ? MetaColors.emerald : textSecondary,
                          ),
                          tooltip: 'Alternar Som',
                          onPressed: _toggleSoundAlert,
                        ),
                        IconButton(
                          icon: Icon(
                            _hapticAlertEnabled ? Icons.vibration_rounded : Icons.smartphone_rounded,
                            size: 19,
                            color: _hapticAlertEnabled ? MetaColors.emerald : textSecondary,
                          ),
                          tooltip: 'Alternar Vibração',
                          onPressed: _toggleHapticAlert,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Botões Principais: Reiniciar / Play-Pause / Concluir
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.replay_rounded, size: 18),
                      label: const Text('Reiniciar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: textSecondary,
                        side: BorderSide(color: border),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: _resetTimer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      icon: Icon(
                        _isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        size: 20,
                      ),
                      label: Text(
                        _isRunning
                            ? 'Pausar'
                            : (isFinished ? 'Pronto para a Série!' : 'Continuar'),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeColor,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14.5,
                        ),
                      ),
                      onPressed: isFinished
                          ? () => Navigator.pop(context)
                          : (_isRunning ? _pauseTimer : _startTimer),
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
