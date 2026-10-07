import re

with open('mobile/lib/services/workout_service.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Let's fix the previously broken string
content = re.sub(r"final uri = Uri\.parse\('.*?/workouts/trainer/.*?/workouts'\);", "final uri = Uri.parse('${AppConfig.apiBaseUrl}/workouts/trainer/$trainerId/workouts');", content)
content = re.sub(r"debugPrint\('Aviso Supabase getTrainerWorkouts: .*?'\);", "debugPrint('Aviso Supabase getTrainerWorkouts: $e');", content)
content = re.sub(r"debugPrint\('Aviso API getTrainerWorkouts: .*?'\);", "debugPrint('Aviso API getTrainerWorkouts: $e');", content)

with open('mobile/lib/services/workout_service.dart', 'w', encoding='utf-8') as f:
    f.write(content)
