import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class RestTimerSheet extends StatefulWidget {
  final int initialSeconds;
  final String exerciseName;

  const RestTimerSheet({
    super.key,
    required this.initialSeconds,
    required this.exerciseName,
  });

  static Future<void> show(
    BuildContext context, {
    required int seconds,
    required String exerciseName,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => RestTimerSheet(
            initialSeconds: seconds > 0 ? seconds : 60,
            exerciseName: exerciseName,
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
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _totalSeconds = widget.initialSeconds;
    _remainingSeconds = widget.initialSeconds;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _isRunning = true;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        _timer?.cancel();
        setState(() {
          _isRunning = false;
        });
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
    });
  }

  void _addSeconds(int delta) {
    setState(() {
      _remainingSeconds = (_remainingSeconds + delta).clamp(0, 600);
      if (_remainingSeconds > _totalSeconds) {
        _totalSeconds = _remainingSeconds;
      }
    });
  }

  void _resetTimer() {
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

  @override
  Widget build(BuildContext context) {
    final progress =
        _totalSeconds > 0 ? (_remainingSeconds / _totalSeconds) : 0.0;
    final isFinished = _remainingSeconds == 0;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.studentSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: AppColors.studentBorder, width: 1.5),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textMuted.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TEMPO DE DESCANSO',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.studentCyan,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.exerciseName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 28),
            // Circular countdown display
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 200,
                  height: 200,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 10,
                    backgroundColor: AppColors.studentBorder,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isFinished
                          ? AppColors.danger
                          : (_remainingSeconds < 15
                              ? AppColors.studentAmber
                              : AppColors.studentCyan),
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale:
                              isFinished
                                  ? 1.0 + (_pulseController.value * 0.08)
                                  : 1.0,
                          child: Text(
                            _formatTime(_remainingSeconds),
                            style: TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.w900,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                              color:
                                  isFinished
                                      ? AppColors.danger
                                      : (_remainingSeconds < 15
                                          ? AppColors.studentAmber
                                          : AppColors.textPrimary),
                              shadows: [
                                Shadow(
                                  color:
                                      isFinished
                                          ? AppColors.danger.withValues(
                                            alpha: 0.5,
                                          )
                                          : AppColors.studentCyanGlow,
                                  blurRadius: 16,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isFinished
                          ? 'HORA DA PRÓXIMA SÉRIE!'
                          : (_isRunning ? 'Em recuperação...' : 'Pausado'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color:
                            isFinished
                                ? AppColors.danger
                                : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Quick adjust buttons: -15s and +15s
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: () => _addSeconds(-15),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.studentBorder),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('-15s'),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: () => _addSeconds(15),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.studentCyan,
                    side: const BorderSide(color: AppColors.studentCyan),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('+15s'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Primary control buttons: Play/Pause and Reset
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.replay_rounded),
                    label: const Text('Reiniciar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.studentBorder),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
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
                      _isRunning
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
                    label: Text(
                      _isRunning
                          ? 'Pausar'
                          : (isFinished ? 'Concluir' : 'Continuar'),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isFinished
                              ? AppColors.trainerEmerald
                              : AppColors.studentCyan,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    onPressed:
                        isFinished
                            ? () => Navigator.pop(context)
                            : (_isRunning ? _pauseTimer : _startTimer),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
