import re

file_path = "mobile/lib/features/client/active_workout_screen.dart"
with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

# Add gamification call to _loadActiveWorkout
target = r"""  Future<void> _loadActiveWorkout\(\) async \{
    if \(mounted\) setState\(\(\) => _isLoadingWorkout = true\);
    final uid = AuthService\.currentUser\?\.id;
    if \(uid != null\) \{
      try \{
        await _sessionService\.flushPending\(uid\);
      \} catch \(_\) \{\}
    \}"""

replacement = """  Future<void> _loadActiveWorkout() async {
    if (mounted) setState(() => _isLoadingWorkout = true);
    
    // Buscar Gamificação
    try {
      final gData = await WorkoutService.getGamificationData();
      if (gData != null && mounted) {
        setState(() {
          currentStreak = gData['current_streak'] ?? 0;
          dailyGoalProgress = (gData['daily_goal_progress'] ?? 0.0).toDouble();
        });
      }
    } catch (_) {}

    final uid = AuthService.currentUser?.id;
    if (uid != null) {
      try {
        await _sessionService.flushPending(uid);
      } catch (_) {}
    }"""

if "await _sessionService.flushPending" in content:
    new_content = re.sub(target, replacement, content)
    with open(file_path, "w", encoding="utf-8") as f:
        f.write(new_content)
    print("Updated active_workout_screen.dart")
else:
    print("target not found")
