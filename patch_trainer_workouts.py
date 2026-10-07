import re

with open('mobile/lib/features/trainer/presentation/screens/trainer_workouts_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Add imports if needed
if 'import \'../../../../services/workout_service.dart\';' not in content:
    content = content.replace("import '../../../../core/widgets/meta_components.dart';", "import '../../../../core/widgets/meta_components.dart';\nimport '../../../../services/workout_service.dart';")

# 2. Replace the hardcoded list with state variables and initState
mock_pattern = re.compile(r'class _TrainerWorkoutsScreenState extends State<TrainerWorkoutsScreen> \{.*?\];', re.DOTALL)
mock_match = mock_pattern.search(content)

new_state = """class _TrainerWorkoutsScreenState extends State<TrainerWorkoutsScreen> {
  List<_RecentWorkoutItem> _recentWorkouts = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadWorkouts();
  }

  Future<void> _loadWorkouts() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });
    try {
      final workouts = await WorkoutService.getTrainerWorkouts();
      if (mounted) {
        setState(() {
          _recentWorkouts = workouts.map((w) {
            final client = w['profiles'] ?? {};
            final clientName = client['full_name'] as String? ?? 'Aluno';
            final title = w['title'] as String? ?? 'Ficha de Treino';
            final updatedAt = w['updated_at'] as String?;
            
            // Format updated_at roughly
            String status = 'Atualizada recentemente';
            bool expired = false;
            if (updatedAt != null) {
              final date = DateTime.tryParse(updatedAt);
              if (date != null) {
                final diff = DateTime.now().difference(date);
                if (diff.inDays > 30) {
                  expired = true;
                  status = 'Vencida há ${diff.inDays} dias';
                } else if (diff.inDays > 0) {
                  status = 'Atualizada há ${diff.inDays} dias';
                } else {
                  status = 'Atualizada hoje';
                }
              }
            }

            // Initials
            String initials = 'AL';
            final parts = clientName.trim().split(RegExp(r'\\s+'));
            if (parts.isNotEmpty) {
              if (parts.length == 1) {
                initials = parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
              } else {
                initials = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
              }
            }

            return _RecentWorkoutItem(
              id: w['id'] ?? '',
              studentName: clientName,
              workoutTitle: title,
              splitInfo: w['notes_for_trainer'] as String? ?? 'Sem notas',
              statusText: status,
              isExpired: expired,
              initials: initials,
              useClipboardIcon: clientName == 'Aluno',
              rawWorkout: w,
            );
          }).toList();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }"""
if mock_match:
    content = content.replace(mock_match.group(0), new_state)

# 3. Add rawWorkout to _RecentWorkoutItem
item_pattern = re.compile(r'class _RecentWorkoutItem \{.*?const _RecentWorkoutItem\(\{', re.DOTALL)
item_match = item_pattern.search(content)
new_item = """class _RecentWorkoutItem {
  final String id;
  final String studentName;
  final String workoutTitle;
  final String splitInfo;
  final String statusText;
  final bool isExpired;
  final String initials;
  final bool useClipboardIcon;
  final Map<String, dynamic>? rawWorkout;

  const _RecentWorkoutItem({
    this.rawWorkout,"""
if item_match:
    content = content.replace(item_match.group(0), new_item)

# 4. Fix SliverList empty/loading states
list_pattern = re.compile(r'SliverList\(\s*delegate: SliverChildBuilderDelegate\(', re.DOTALL)
list_match = list_pattern.search(content)
new_list = """_isLoading 
                  ? const SliverFillRemaining(
                      child: Center(
                        child: CircularProgressIndicator(color: MetaColors.emerald),
                      ),
                    )
                  : _hasError
                    ? SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                              const SizedBox(height: 16),
                              Text('Erro ao carregar treinos:\\n$_errorMessage', textAlign: TextAlign.center, style: const TextStyle(color: MetaColors.textSecondary)),
                              const SizedBox(height: 16),
                              ElevatedButton(onPressed: _loadWorkouts, child: const Text('Tentar Novamente')),
                            ],
                          ),
                        ),
                      )
                    : _recentWorkouts.isEmpty 
                      ? const SliverFillRemaining(
                          child: Center(
                            child: Text(
                              'Nenhum treino encontrado.',
                              style: TextStyle(color: MetaColors.textSecondary, fontSize: 16),
                            ),
                          ),
                        )
                      : SliverList(
                    delegate: SliverChildBuilderDelegate("""
if list_match:
    content = content.replace(list_match.group(0), new_list)

with open('mobile/lib/features/trainer/presentation/screens/trainer_workouts_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
