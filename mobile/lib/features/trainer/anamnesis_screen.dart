import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/ai_generation_stepper.dart';
import '../../core/widgets/server_config_dialog.dart';
import '../../models/workout_plan_model.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/workout_service.dart';

class TrainerAnamnesisScreen extends StatefulWidget {
  const TrainerAnamnesisScreen({super.key});

  @override
  State<TrainerAnamnesisScreen> createState() => _TrainerAnamnesisScreenState();
}

class _TrainerAnamnesisScreenState extends State<TrainerAnamnesisScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();

  String _objective = 'Hipertrofia Muscular';
  String _trainingLevel = 'Intermediário';
  int _daysPerWeek = 4;
  String _workoutLocation = 'Academia completa';
  final _restrictionsCtrl = TextEditingController(
    text: 'Leve desconforto no ombro direito (evitar abdução acima de 90° com carga pesada)',
  );
  final _notesCtrl = TextEditingController(
    text: 'Foco em peitoral superior e deltoides',
  );

  bool _isLoading = false;
  bool _isSavingPlan = false;
  WorkoutPlanModel? _generatedPlan;

  List<Map<String, dynamic>> _students = [];
  String? _selectedStudentId;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    final list = await WorkoutService.getTrainerStudents();
    if (mounted) {
      setState(() {
        _students = list;
        if (list.isNotEmpty) {
          _selectedStudentId = list.first['id'] as String;
        }
      });
    }
  }

  @override
  void dispose() {
    _restrictionsCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleGenerate() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final plan = await _apiService.generateWorkoutPlan(
        objective: _objective,
        trainingLevel: _trainingLevel,
        daysPerWeek: _daysPerWeek,
        workoutLocation: _workoutLocation,
        injuriesOrRestrictions: _restrictionsCtrl.text,
        additionalNotes: _notesCtrl.text.isNotEmpty ? _notesCtrl.text : null,
      );

      setState(() {
        _generatedPlan = plan;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.green,
            content: Text('Periodização gerada com sucesso pela IA!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade800,
            content: Text('Erro ao gerar periodização: $e'),
            action: SnackBarAction(
              label: 'Mudar IP',
              textColor: Colors.yellow,
              onPressed: () => ServerConfigDialog.show(context),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  InputDecoration _inputDecoration(String label, {IconData? prefixIcon, String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: AppColors.trainerEmerald, size: 20) : null,
      filled: true,
      fillColor: AppColors.trainerSurface,
      labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
      hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.trainerBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.trainerBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.trainerEmerald, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.trainerBg,
      appBar: AppBar(
        title: Text(_generatedPlan == null ? 'Nova Anamnese & Ficha' : 'Revisão da Ficha'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_ethernet_rounded),
            tooltip: 'Configurar IP do Servidor',
            onPressed: () => ServerConfigDialog.show(context),
          ),
          if (_generatedPlan != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Recomeçar',
              onPressed: () => setState(() => _generatedPlan = null),
            ),
        ],
      ),
      body: Stack(
        children: [
          _generatedPlan == null ? _buildForm() : _buildPlanReviewer(_generatedPlan!),
          if (_isLoading) const AIGenerationStepper(),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.trainerEmerald.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.assignment_ind_outlined, color: AppColors.trainerEmerald, size: 22),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ANAMNESE CLÍNICA',
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w700,
                      color: AppColors.trainerEmerald,
                    ),
                  ),
                  Text(
                    'Parâmetros da Periodização',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_students.isNotEmpty) ...[
            DropdownButtonFormField<String>(
              initialValue: _selectedStudentId,
              dropdownColor: AppColors.trainerSurfaceElevated,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: _inputDecoration('Aluno da Consultoria', prefixIcon: Icons.person_outline),
              items: _students.map((st) {
                return DropdownMenuItem<String>(
                  value: st['id'] as String,
                  child: Text(st['full_name'] as String? ?? 'Aluno'),
                );
              }).toList(),
              onChanged: (val) => setState(() => _selectedStudentId = val),
            ),
            const SizedBox(height: 16),
          ],
          DropdownButtonFormField<String>(
            initialValue: _objective,
            dropdownColor: AppColors.trainerSurfaceElevated,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: _inputDecoration('Objetivo Principal', prefixIcon: Icons.track_changes_outlined),
            items: ['Hipertrofia Muscular', 'Emagrecimento', 'Condicionamento Geral', 'Força Máxima']
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (val) => setState(() => _objective = val!),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _trainingLevel,
            dropdownColor: AppColors.trainerSurfaceElevated,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: _inputDecoration('Nível de Treino', prefixIcon: Icons.signal_cellular_alt_rounded),
            items: ['Iniciante', 'Intermediário', 'Avançado']
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (val) => setState(() => _trainingLevel = val!),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            initialValue: _daysPerWeek,
            dropdownColor: AppColors.trainerSurfaceElevated,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: _inputDecoration('Frequência Semanal', prefixIcon: Icons.calendar_today_outlined),
            items: [2, 3, 4, 5, 6].map((e) => DropdownMenuItem(value: e, child: Text('$e dias na semana'))).toList(),
            onChanged: (val) => setState(() => _daysPerWeek = val!),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _workoutLocation,
            dropdownColor: AppColors.trainerSurfaceElevated,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: _inputDecoration('Ambiente de Treino', prefixIcon: Icons.location_on_outlined),
            items: ['Academia completa', 'Condomínio', 'Em casa (Halteres/Peso Corporal)']
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (val) => setState(() => _workoutLocation = val!),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _restrictionsCtrl,
            maxLines: 2,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: _inputDecoration(
              'Dores, Lesões e Restrições Articulares',
              prefixIcon: Icons.health_and_safety_outlined,
              hint: 'Ex: Evitar supino reto livre devido a impacto no ombro',
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _notesCtrl,
            maxLines: 2,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: _inputDecoration(
              'Observações / Foco do Treinador',
              prefixIcon: Icons.edit_note_rounded,
              hint: 'Ex: Dar ênfase a peitoral superior e deltoides',
            ),
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            icon: const Icon(Icons.auto_awesome, color: Colors.black),
            label: const Text('Gerar Periodização com IA'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: AppColors.trainerEmerald,
              foregroundColor: Colors.black,
              elevation: 4,
              shadowColor: AppColors.trainerEmeraldGlow,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            onPressed: _handleGenerate,
          ),
        ],
      ),
    );
  }

  Future<void> _handleApprovePlan() async {
    if (_generatedPlan == null) return;
    setState(() => _isSavingPlan = true);

    try {
      final user = AuthService.currentUser;
      if (user != null) {
        final targetClientId = _selectedStudentId ?? user.id;
        await WorkoutService.saveWorkoutPlan(
          plan: _generatedPlan!,
          clientId: targetClientId,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Colors.green,
              content: Text('Ficha salva no Supabase e liberada para o aluno!'),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppColors.trainerEmerald,
              content: Text('Ficha aprovada com sucesso!'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text('Erro ao salvar no Supabase: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingPlan = false);
    }
  }

  Widget _buildPlanReviewer(WorkoutPlanModel plan) {
    return DefaultTabController(
      length: plan.splits.length,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppColors.trainerSurface,
              border: Border(bottom: BorderSide(color: AppColors.trainerBorder)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        plan.workoutPlanTitle,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.trainerEmerald.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.trainerEmerald.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        '${plan.splits.length} SPLITS',
                        style: const TextStyle(
                          color: AppColors.trainerEmerald,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Diretriz Clínica: ${plan.notesForTrainer}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.3),
                ),
              ],
            ),
          ),
          TabBar(
            isScrollable: true,
            indicatorColor: AppColors.trainerEmerald,
            labelColor: AppColors.trainerEmerald,
            unselectedLabelColor: AppColors.textMuted,
            indicatorWeight: 3,
            tabs: plan.splits
                .map((s) => Tab(text: 'Treino ${s.splitIdentifier} (${s.splitName})'))
                .toList(),
          ),
          Expanded(
            child: TabBarView(
              children: plan.splits.map((split) {
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: split.exercises.length,
                  itemBuilder: (ctx, i) {
                    final ex = split.exercises[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.trainerSurface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.trainerBorder),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.trainerEmerald.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.trainerEmerald.withValues(alpha: 0.3)),
                            ),
                            child: Center(
                              child: Text(
                                '${ex.order}',
                                style: const TextStyle(
                                  color: AppColors.trainerEmerald,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ex.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  ex.targetMuscleGroup,
                                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    _buildSplitBadge('${ex.sets} Séries'),
                                    const SizedBox(width: 6),
                                    _buildSplitBadge('${ex.reps} Reps'),
                                    const SizedBox(width: 6),
                                    _buildSplitBadge('${ex.restSeconds}s Descanso'),
                                  ],
                                ),
                                if (ex.notes.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    ex.notes,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              }).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: _isSavingPlan
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline, color: Colors.black),
                label: Text(
                  _isSavingPlan ? 'Gravando no Supabase...' : 'Aprovar e Liberar para o Aluno',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.trainerEmerald,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _isSavingPlan ? null : _handleApprovePlan,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSplitBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.trainerSurfaceElevated,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.trainerBorder),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
