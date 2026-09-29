import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/ai_generation_stepper.dart';
import '../../core/widgets/server_config_dialog.dart';
import '../../core/widgets/theme_toggle_button.dart';
import '../../models/workout_plan_model.dart';
import '../../services/api_service.dart';
import '../../services/workout_service.dart';

class TrainerAnamnesisScreen extends StatefulWidget {
  final String? initialStudentId;
  final String? initialStudentName;

  const TrainerAnamnesisScreen({
    super.key,
    this.initialStudentId,
    this.initialStudentName,
  });

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
  final Set<String> _selectedStudentIds = {};

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
        if (widget.initialStudentId != null) {
          _selectedStudentIds.add(widget.initialStudentId!);
          final found = list.firstWhere(
            (s) => s['id'] == widget.initialStudentId,
            orElse: () => {},
          );
          if (found.isNotEmpty) {
            if (found['injuries_or_restrictions'] != null &&
                (found['injuries_or_restrictions'] as String).isNotEmpty) {
              _restrictionsCtrl.text = found['injuries_or_restrictions'];
            }
            if (found['objective'] != null) {
              final obj = found['objective'] as String;
              if (['Hipertrofia Muscular', 'Emagrecimento', 'Condicionamento Geral', 'Força Máxima'].contains(obj)) {
                _objective = obj;
              }
            }
          }
        } else if (list.isNotEmpty && _selectedStudentIds.isEmpty) {
          _selectedStudentIds.add(list.first['id'] as String);
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

  InputDecoration _inputDecoration(BuildContext context, String label, {IconData? prefixIcon, String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: AppColors.emerald(context), size: 20) : null,
      filled: true,
      fillColor: AppColors.card(context),
      labelStyle: TextStyle(color: AppColors.subtext(context), fontSize: 13),
      hintStyle: TextStyle(color: AppColors.subtext(context), fontSize: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.cardBorder(context)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.cardBorder(context)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.emerald(context), width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          _generatedPlan == null ? 'Nova Anamnese & Ficha' : 'Revisão da Ficha',
          style: TextStyle(
            color: AppColors.text(context),
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        actions: [
          const ThemeToggleButton(),
          const SizedBox(width: 4),
          if (kDebugMode)
            IconButton(
              icon: const Icon(Icons.settings_ethernet_rounded),
              tooltip: 'Configurar IP do Servidor (Dev)',
              onPressed: () => ServerConfigDialog.show(context),
            ),
          if (_generatedPlan != null)
            IconButton(
              icon: Icon(Icons.refresh_rounded, color: AppColors.subtext(context)),
              tooltip: 'Recomeçar',
              onPressed: () => setState(() => _generatedPlan = null),
            ),
          const SizedBox(width: 8),
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
                  color: AppColors.emeraldBg(context),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.assignment_ind_outlined, color: AppColors.emerald(context), size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ANAMNESE CLÍNICA',
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w700,
                      color: AppColors.emerald(context),
                    ),
                  ),
                  Text(
                    'Parâmetros da Periodização',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.text(context)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_students.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.card(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _selectedStudentIds.isEmpty ? Colors.amber.shade700 : AppColors.cardBorder(context),
                  width: _selectedStudentIds.isEmpty ? 1.5 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.group_outlined, size: 18, color: AppColors.emerald(context)),
                          const SizedBox(width: 8),
                          Text(
                            'Alunos Destinatários (${_selectedStudentIds.length}/${_students.length})',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.text(context),
                            ),
                          ),
                        ],
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: Icon(
                          _selectedStudentIds.length == _students.length
                              ? Icons.check_box_rounded
                              : Icons.select_all_rounded,
                          size: 16,
                          color: AppColors.emerald(context),
                        ),
                        label: Text(
                          _selectedStudentIds.length == _students.length ? 'Desmarcar Todos' : 'Selecionar Todos',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.emerald(context),
                          ),
                        ),
                        onPressed: () {
                          setState(() {
                            if (_selectedStudentIds.length == _students.length) {
                              _selectedStudentIds.clear();
                            } else {
                              _selectedStudentIds.clear();
                              _selectedStudentIds.addAll(_students.map((s) => s['id'] as String));
                            }
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _students.map((st) {
                      final id = st['id'] as String;
                      final name = st['full_name'] as String? ?? 'Aluno';
                      final isSelected = _selectedStudentIds.contains(id);
                      final hasAlert = st['has_alert'] == true;

                      return FilterChip(
                        selected: isSelected,
                        showCheckmark: true,
                        checkmarkColor: isSelected ? Colors.black : null,
                        avatar: CircleAvatar(
                          radius: 10,
                          backgroundColor: isSelected ? Colors.black26 : AppColors.cardBorder(context),
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'A',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.black : AppColors.text(context),
                            ),
                          ),
                        ),
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              name,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                                color: isSelected ? Colors.black : AppColors.text(context),
                              ),
                            ),
                            if (hasAlert) ...[
                              const SizedBox(width: 4),
                              Icon(Icons.warning_amber_rounded, size: 14, color: isSelected ? Colors.black : Colors.amber),
                            ],
                          ],
                        ),
                        backgroundColor: AppColors.pillBg(context),
                        selectedColor: AppColors.emerald(context),
                        side: BorderSide(
                          color: isSelected
                              ? AppColors.emerald(context)
                              : (hasAlert ? Colors.amber.shade600 : AppColors.cardBorder(context)),
                        ),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedStudentIds.add(id);
                              // Auto-preenche campos se for o primeiro aluno selecionado
                              if (st['injuries_or_restrictions'] != null &&
                                  (st['injuries_or_restrictions'] as String).isNotEmpty) {
                                _restrictionsCtrl.text = st['injuries_or_restrictions'];
                              }
                              if (st['objective'] != null) {
                                final obj = st['objective'] as String;
                                if (['Hipertrofia Muscular', 'Emagrecimento', 'Condicionamento Geral', 'Força Máxima'].contains(obj)) {
                                  _objective = obj;
                                }
                              }
                            } else {
                              _selectedStudentIds.remove(id);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  if (_selectedStudentIds.isEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Atenção: Selecione ao menos 1 aluno para liberar esta ficha.',
                      style: TextStyle(fontSize: 11, color: Colors.amber.shade700, fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          DropdownButtonFormField<String>(
            initialValue: _objective,
            dropdownColor: AppColors.card(context),
            style: TextStyle(color: AppColors.text(context)),
            decoration: _inputDecoration(context, 'Objetivo Principal', prefixIcon: Icons.track_changes_outlined),
            items: ['Hipertrofia Muscular', 'Emagrecimento', 'Condicionamento Geral', 'Força Máxima']
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (val) => setState(() => _objective = val!),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _trainingLevel,
            dropdownColor: AppColors.card(context),
            style: TextStyle(color: AppColors.text(context)),
            decoration: _inputDecoration(context, 'Nível de Treino', prefixIcon: Icons.signal_cellular_alt_rounded),
            items: ['Iniciante', 'Intermediário', 'Avançado']
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (val) => setState(() => _trainingLevel = val!),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            initialValue: _daysPerWeek,
            dropdownColor: AppColors.card(context),
            style: TextStyle(color: AppColors.text(context)),
            decoration: _inputDecoration(context, 'Frequência Semanal', prefixIcon: Icons.calendar_today_outlined),
            items: [2, 3, 4, 5, 6].map((e) => DropdownMenuItem(value: e, child: Text('$e dias na semana'))).toList(),
            onChanged: (val) => setState(() => _daysPerWeek = val!),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _workoutLocation,
            dropdownColor: AppColors.card(context),
            style: TextStyle(color: AppColors.text(context)),
            decoration: _inputDecoration(context, 'Ambiente de Treino', prefixIcon: Icons.location_on_outlined),
            items: ['Academia completa', 'Condomínio', 'Em casa (Halteres/Peso Corporal)']
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (val) => setState(() => _workoutLocation = val!),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _restrictionsCtrl,
            maxLines: 2,
            style: TextStyle(color: AppColors.text(context)),
            decoration: _inputDecoration(
              context,
              'Dores, Lesões e Restrições Articulares',
              prefixIcon: Icons.health_and_safety_outlined,
              hint: 'Ex: Evitar supino reto livre devido a impacto no ombro',
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _notesCtrl,
            maxLines: 2,
            style: TextStyle(color: AppColors.text(context)),
            decoration: _inputDecoration(
              context,
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
              backgroundColor: AppColors.emerald(context),
              foregroundColor: Colors.black,
              elevation: 4,
              shadowColor: AppColors.emerald(context).withValues(alpha: 0.35),
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
    if (_selectedStudentIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.orange,
          content: Text('Selecione ao menos um aluno para vincular a esta periodização.'),
        ),
      );
      return;
    }

    setState(() => _isSavingPlan = true);

    try {
      int successCount = 0;

      for (final studentId in _selectedStudentIds) {
        await WorkoutService.saveWorkoutPlan(
          plan: _generatedPlan!,
          clientId: studentId,
        );
        successCount++;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green.shade800,
            content: Text(
              successCount == 1
                  ? '✓ Ficha salva no Supabase e liberada para o aluno!'
                  : '✓ Ficha salva no Supabase e liberada para $successCount alunos com sucesso!',
            ),
          ),
        );
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
    final isDark = AppColors.isDark(context);

    return DefaultTabController(
      length: plan.splits.length,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card(context),
              border: Border(bottom: BorderSide(color: AppColors.cardBorder(context))),
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
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text(context),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.emeraldBg(context),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.emerald(context).withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        '${plan.splits.length} SPLITS',
                        style: TextStyle(
                          color: AppColors.emerald(context),
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
                  style: TextStyle(fontSize: 12, color: AppColors.subtext(context), height: 1.3),
                ),
              ],
            ),
          ),
          TabBar(
            isScrollable: true,
            indicatorColor: AppColors.emerald(context),
            labelColor: AppColors.emerald(context),
            unselectedLabelColor: AppColors.subtext(context),
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
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.card(context),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.cardBorder(context)),
                        boxShadow: [
                          BoxShadow(
                            color: isDark ? Colors.black26 : const Color(0x060F172A),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.emeraldBg(context),
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.emerald(context).withValues(alpha: 0.3)),
                            ),
                            child: Center(
                              child: Text(
                                '${ex.order}',
                                style: TextStyle(
                                  color: AppColors.emerald(context),
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
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: AppColors.text(context),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  ex.targetMuscleGroup,
                                  style: TextStyle(color: AppColors.subtext(context), fontSize: 12),
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
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.subtext(context),
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
                  _isSavingPlan
                      ? 'Gravando no Supabase...'
                      : (_selectedStudentIds.length > 1
                          ? 'Aprovar e Liberar para ${_selectedStudentIds.length} Alunos'
                          : 'Aprovar e Liberar para o Aluno'),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.emerald(context),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 4,
                  shadowColor: AppColors.emerald(context).withValues(alpha: 0.35),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.pillBg(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.pillBorder(context)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: AppColors.text(context),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
