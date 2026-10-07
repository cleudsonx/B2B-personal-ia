import re

with open('mobile/lib/services/workout_service.dart', 'r', encoding='utf-8') as f:
    content = f.read()

new_method = '''
  static Future<List<Map<String, dynamic>>> getTrainerWorkouts() async {
    final trainer = AuthService.currentUser;
    final trainerId = trainer?.id ?? 'current-trainer';

    if (_clientOrNull != null && trainer != null) {
      try {
        final List<dynamic> response = await _client
            .from('workouts')
            .select('*, profiles!workouts_client_id_fkey(full_name, avatar_url)')
            .eq('trainer_id', trainerId)
            .eq('is_active', true)
            .order('updated_at', ascending: false);

        return response.map((e) => Map<String, dynamic>.from(e)).toList();
      } catch (e) {
        debugPrint('Aviso Supabase getTrainerWorkouts: \');
      }
    }
    
    // Fallback para API FastAPI caso exista
    try {
      final uri = Uri.parse('\/workouts/trainer/\/workouts');
      final res = await http.get(uri, headers: _apiHeaders).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final List<dynamic> data = json.decode(res.body);
        return data.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (e) {
      debugPrint('Aviso API getTrainerWorkouts: \');
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> getTrainerStudents() async {'''

content = content.replace('  static Future<List<Map<String, dynamic>>> getTrainerStudents() async {', new_method)

with open('mobile/lib/services/workout_service.dart', 'w', encoding='utf-8') as f:
    f.write(content)
