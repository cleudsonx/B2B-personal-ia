import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/meta_components.dart';
import '../../core/widgets/ai_generation_stepper.dart';
import '../../core/widgets/server_config_dialog.dart';
import '../../core/widgets/theme_toggle_button.dart';
import '../../models/exercise_model.dart';
import '../../models/split_model.dart';
import '../../models/workout_plan_model.dart';
import '../../services/api_service.dart';
import '../../services/workout_service.dart';

enum StudentDispatchMode { individual, multiple }

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
  String _trainingLevel = 'IntermediÃ¡rio';
  int _daysPerWeek = 4;
  String _splitType = 'AutomÃ¡tico (IA Sugere o Ideal)';
  String _targetFocus = 'Geral / Equilibrado';
  String _workoutLocation = 'Academia completa';
  final _restrictionsCtrl = TextEditingController(
    text:
        'Leve desconforto no ombro direito (evitar abduÃ§Ã£o acima de 90Â° com carga pesada)',
  );
  final _notesCtrl = TextEditingController(
    text: 'Foco em peitoral superior e deltoides',
  );

  bool _isLoading = false;
  bool _isSavingPlan = false;
  WorkoutPlanModel? _generatedPlan;

  List<Map<String, dynamic>> _students = [];
  StudentDispatchMode _dispatchMode = StudentDispatchMode.individual;
  String? _selectedIndividualStudentId;
  final Set<String> _selectedMultipleStudentIds = {};

  Set<String> get _selectedStudentIds {
    if (_dispatchMode == StudentDispatchMode.individual) {
      return _selectedIndividualStudentId != null
          ? {_selectedIndividualStudentId!}
          : {};
    }
    return _selectedMultipleStudentIds;
  }

  Map<String, dynamic>? get _selectedIndividualStudent {
    if (_selectedIndividualStudentId == null) return null;
    return _students.firstWhere(
      (s) => s['id'] == _selectedIndividualStudentId,
      orElse: () => {},
    );
  }

  String _getRecipientsSummaryText() {
    if (_dispatchMode == StudentDispatchMode.individual) {
      final st = _selectedIndividualStudent;
      return st?['full_name'] as String? ?? 'Nenhum aluno selecionado';
    }
    if (_selectedMultipleStudentIds.isEmpty) {
      return 'Nenhum aluno selecionado';
    }
    final names =
        _students
            .where((s) => _selectedMultipleStudentIds.contains(s['id']))
            .map((s) => s['full_name'] as String? ?? 'Aluno')
            .toList();
    if (names.isEmpty) return 'Nenhum aluno selecionado';
    if (names.length == 1) return names.first;
    if (names.length == 2) return '${names[0]} e ${names[1]}';
    return '${names[0]}, ${names[1]} e mais ${names.length - 2} alunos';
  }

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
          _dispatchMode = StudentDispatchMode.individual;
          _onSelectIndividualStudent(widget.initialStudentId!);
        } else if (list.isNotEmpty) {
          _onSelectIndividualStudent(list.first['id'] as String);
        }
      });
    }
  }

  void _onSelectIndividualStudent(String studentId) {
    _selectedIndividualStudentId = studentId;
    if (!_selectedMultipleStudentIds.contains(studentId)) {
      _selectedMultipleStudentIds.add(studentId);
    }
    final found = _students.firstWhere(
      (s) => s['id'] == studentId,
      orElse: () => {},
    );
    if (found.isNotEmpty) {
      if (found['injuries_or_restrictions'] != null &&
          (found['injuries_or_restrictions'] as String).isNotEmpty) {
        _restrictionsCtrl.text = found['injuries_or_restrictions'];
      }
      final obj = found['goal'] ?? found['objective'];
      if (obj != null &&
          [
            'Hipertrofia Muscular',
            'Emagrecimento',
            'Condicionamento Geral',
            'ForÃ§a MÃ¡xima',
          ].contains(obj)) {
        _objective = obj as String;
      }
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

    if (_selectedStudentIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.amber.shade900,
          content: Text(
            _dispatchMode == StudentDispatchMode.individual
                ? 'Selecione um aluno destinatário antes de gerar a periodização.'
                : 'Selecione ao menos 1 aluno para o envio em lote.',
          ),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final plan = await _apiService.generateWorkoutPlan(
        objective: _objective,
        trainingLevel: _trainingLevel,
        daysPerWeek: _daysPerWeek,
        workoutLocation: _workoutLocation,
        injuriesOrRestrictions: _restrictionsCtrl.text,
        splitType: _splitType,
        targetFocus:
            _targetFocus == 'Geral / Equilibrado' ? null : _targetFocus,
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

  InputDecoration _inputDecoration(
    BuildContext context,
    String label, {
    IconData? prefixIcon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon:
          prefixIcon != null
              ? Icon(prefixIcon, color: MetaColors.emerald, size: 20)
              : null,
      filled: true,
      fillColor: MetaColors.surface,
      labelStyle: TextStyle(color: MetaColors.textSecondary, fontSize: 13),
      hintStyle: TextStyle(color: MetaColors.textSecondary, fontSize: 12),
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
        borderSide: BorderSide(color: MetaColors.emerald, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MetaColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          _generatedPlan == null ? 'Nova Anamnese & Ficha' : 'RevisÃ£o da Ficha',
          style: TextStyle(
            color: MetaColors.textPrimary,
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
              icon: Icon(
                Icons.refresh_rounded,
                color: MetaColors.textSecondary,
              ),
              tooltip: 'RecomeÃ§ar',
              onPressed: () => setState(() => _generatedPlan = null),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          _generatedPlan == null
              ? _buildForm()
              : _buildPlanReviewer(_generatedPlan!),
          if (_isLoading) const AIGenerationStepper(),
        ],
      ),
    );
  }

  Widget _buildForm() {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Form(
      key: _formKey,
      child: ListView(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: bottomInset + 30,
        ),
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.emeraldBg(context),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.assignment_ind_outlined,
                  color: MetaColors.emerald,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ANAMNESE CLÃNICA',
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w700,
                      color: MetaColors.emerald,
                    ),
                  ),
                  Text(
                    'ParÃ¢metros da Periodização',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: MetaColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            initialValue: _objective,
            dropdownColor: MetaColors.surface,
            style: TextStyle(color: MetaColors.textPrimary),
            decoration: _inputDecoration(
              context,
              'Objetivo Principal',
              prefixIcon: Icons.track_changes_outlined,
            ),
            items:
                [
                      'Hipertrofia Muscular',
                      'Emagrecimento',
                      'Condicionamento Geral',
                      'ForÃ§a MÃ¡xima',
                    ]
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
            onChanged: (val) => setState(() => _objective = val!),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _trainingLevel,
            dropdownColor: MetaColors.surface,
            style: TextStyle(color: MetaColors.textPrimary),
            decoration: _inputDecoration(
              context,
              'NÃ­vel de Treino',
              prefixIcon: Icons.signal_cellular_alt_rounded,
            ),
            items:
                ['Iniciante', 'IntermediÃ¡rio', 'AvanÃ§ado']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
            onChanged: (val) => setState(() => _trainingLevel = val!),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            initialValue: _daysPerWeek,
            dropdownColor: MetaColors.surface,
            style: TextStyle(color: MetaColors.textPrimary),
            decoration: _inputDecoration(
              context,
              'FrequÃªncia Semanal',
              prefixIcon: Icons.calendar_today_outlined,
            ),
            items:
                [2, 3, 4, 5, 6]
                    .map(
                      (e) => DropdownMenuItem(
                        value: e,
                        child: Text('$e dias na semana'),
                      ),
                    )
                    .toList(),
            onChanged: (val) => setState(() => _daysPerWeek = val!),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _splitType,
            dropdownColor: MetaColors.surface,
            style: TextStyle(color: MetaColors.textPrimary, fontSize: 13),
            isExpanded: true,
            decoration: _inputDecoration(
              context,
              'Estrutura de DivisÃ£o / Split',
              prefixIcon: Icons.alt_route_rounded,
            ),
            items:
                [
                      'AutomÃ¡tico (IA Sugere o Ideal)',
                      'Full Body (1 a 3 dias - Corpo Inteiro)',
                      'Upper / Lower (2 ou 4 dias - Superiores / Inferiores)',
                      'Push / Pull / Legs (PPL - 3 a 6 dias)',
                      'Agonista / Antagonista (SupersÃ©ries eficientes)',
                      'DivisÃ£o ABC Tradicional',
                      'DivisÃ£o ABCD ClÃ¡ssica (4 dias)',
                      'DivisÃ£o ABCDE AvanÃ§ada (1 grupo/dia)',
                      'EspecializaÃ§Ã£o de Ponto Fraco',
                      'ReabilitaÃ§Ã£o / Articularmente Poupadora',
                    ]
                    .map(
                      (e) => DropdownMenuItem(
                        value: e,
                        child: Text(e, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
            onChanged: (val) => setState(() => _splitType = val!),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _targetFocus,
            dropdownColor: MetaColors.surface,
            style: TextStyle(color: MetaColors.textPrimary, fontSize: 13),
            isExpanded: true,
            decoration: _inputDecoration(
              context,
              'Foco Muscular / Ponto Fraco',
              prefixIcon: Icons.fitness_center_rounded,
            ),
            items:
                [
                      'Geral / Equilibrado',
                      'GlÃºteos & Posterior de Coxa',
                      'Deltoides & Ombros 3D',
                      'Peitoral Superior (Clavicular)',
                      'Dorsais & V-Taper (Largura)',
                      'BraÃ§os (BÃ­ceps e TrÃ­ceps)',
                      'QuadrÃ­ceps & Vasto Medial',
                      'Core & Fortalecimento Postural',
                    ]
                    .map(
                      (e) => DropdownMenuItem(
                        value: e,
                        child: Text(e, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
            onChanged: (val) => setState(() => _targetFocus = val!),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _workoutLocation,
            dropdownColor: MetaColors.surface,
            style: TextStyle(color: MetaColors.textPrimary),
            decoration: _inputDecoration(
              context,
              'Ambiente de Treino',
              prefixIcon: Icons.location_on_outlined,
            ),
            items:
                [
                      'Academia completa',
                      'CondomÃ­nio',
                      'Em casa (Halteres/Peso Corporal)',
                    ]
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
            onChanged: (val) => setState(() => _workoutLocation = val!),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _restrictionsCtrl,
            maxLines: 2,
            style: TextStyle(color: MetaColors.textPrimary),
            decoration: _inputDecoration(
              context,
              'Dores, LesÃµes e Restrições Articulares',
              prefixIcon: Icons.health_and_safety_outlined,
              hint: 'Ex: Evitar supino reto livre devido a impacto no ombro',
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _notesCtrl,
            maxLines: 2,
            style: TextStyle(color: MetaColors.textPrimary),
            decoration: _inputDecoration(
              context,
              'Observações / Foco do Treinador',
              prefixIcon: Icons.edit_note_rounded,
              hint: 'Ex: Dar Ãªnfase a peitoral superior e deltoides',
            ),
          ),
          const SizedBox(height: 20),
          _buildDispatchSection(context),
          const SizedBox(height: 10),
          SquircleButton(
            icon: Icons.auto_awesome,
            label: _dispatchMode == StudentDispatchMode.individual
                ? (_selectedIndividualStudent != null
                    ? 'Gerar para $(_selectedIndividualStudent!['full_name']})'
                    : 'Gerar Individual')
                : (_selectedMultipleStudentIds.isNotEmpty
                    ? 'Gerar para $(_selectedMultipleStudentIds.length}) Alunos'
                    : 'Gerar para Vários'),
            isPrimary: true,
            foregroundColor: Colors.black,
            onPressed: _handleGenerate,
          ),
        ],
      ),
    );
  }

  Widget _buildDispatchSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MetaColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color:
              _selectedStudentIds.isEmpty
                  ? Colors.amber.shade700
                  : AppColors.cardBorder(context),
          width: _selectedStudentIds.isEmpty ? 1.5 : 1,
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
                  color: AppColors.emeraldBg(context),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.send_rounded,
                  color: MetaColors.emerald,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DESTINATÃRIOS DO TREINO',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w700,
                        color: MetaColors.emerald,
                      ),
                    ),
                    Text(
                      'Modo de Envio & AtribuiÃ§Ã£o',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: MetaColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // SEGMENTED SWITCHER
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: MetaColors.surfaceHighlight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: MetaColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildModeTabButton(
                    mode: StudentDispatchMode.individual,
                    title: 'Aluno Individual',
                    icon: Icons.person_rounded,
                    badgeText: '1 Aluno',
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildModeTabButton(
                    mode: StudentDispatchMode.multiple,
                    title: 'Vários Alunos',
                    icon: Icons.groups_rounded,
                    badgeText: '${_selectedMultipleStudentIds.length}',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (_dispatchMode == StudentDispatchMode.individual)
            _buildIndividualModeContent(context)
          else
            _buildMultipleModeContent(context),
        ],
      ),
    );
  }

  Widget _buildModeTabButton({
    required StudentDispatchMode mode,
    required String title,
    required IconData icon,
    required String badgeText,
  }) {
    final isSelected = _dispatchMode == mode;
    return InkWell(
      onTap: () {
        setState(() {
          _dispatchMode = mode;
          if (mode == StudentDispatchMode.individual) {
            if (_selectedIndividualStudentId == null && _students.isNotEmpty) {
              _onSelectIndividualStudent(_students.first['id'] as String);
            }
          }
        });
      },
      borderRadius: BorderRadius.circular(11),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? MetaColors.emerald : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.black : MetaColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? Colors.black : MetaColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color:
                    isSelected ? Colors.black12 : AppColors.cardBorder(context),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                badgeText,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.black : MetaColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIndividualModeContent(BuildContext context) {
    if (_students.isEmpty) {
      return _buildEmptyStudentsWarning(context);
    }

    final selectedStudent = _selectedIndividualStudent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Selecione o aluno que receberÃ¡ esta prescriÃ§Ã£o exclusiva:',
          style: TextStyle(fontSize: 12, color: MetaColors.textSecondary),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _selectedIndividualStudentId,
          dropdownColor: MetaColors.surface,
          style: TextStyle(color: MetaColors.textPrimary, fontSize: 13),
          isExpanded: true,
          decoration: _inputDecoration(
            context,
            'Aluno DestinatÃ¡rio',
            prefixIcon: Icons.person_outline_rounded,
          ),
          items:
              _students.map((st) {
                final name = st['full_name'] as String? ?? 'Aluno';
                final goal = st['goal'] ?? st['objective'] ?? 'Consultoria';
                return DropdownMenuItem(
                  value: st['id'] as String,
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 11,
                        backgroundColor: AppColors.emeraldBg(context),
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'A',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: MetaColors.emerald,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$name ($goal)',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _onSelectIndividualStudent(val);
              });
            }
          },
        ),
        if (selectedStudent != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MetaColors.surfaceHighlight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: MetaColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.verified_user_outlined,
                      size: 15,
                      color: MetaColors.emerald,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      selectedStudent['full_name'] as String? ?? 'Aluno',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: MetaColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.emeraldBg(context),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        selectedStudent['status'] as String? ?? 'Ativo',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: MetaColors.emerald,
                        ),
                      ),
                    ),
                  ],
                ),
                if (selectedStudent['injuries_or_restrictions'] != null &&
                    (selectedStudent['injuries_or_restrictions'] as String)
                        .isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        size: 14,
                        color: Colors.amber,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'RestriÃ§Ã£o no cadastro: ${selectedStudent['injuries_or_restrictions']}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.amber,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMultipleModeContent(BuildContext context) {
    if (_students.isEmpty) {
      return _buildEmptyStudentsWarning(context);
    }

    final allSelected = _selectedMultipleStudentIds.length == _students.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  'Selecione os Alunos',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: MetaColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.emeraldBg(context),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${_selectedMultipleStudentIds.length}/${_students.length}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: MetaColors.emerald,
                    ),
                  ),
                ),
              ],
            ),
            TextButton.icon(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                visualDensity: VisualDensity.compact,
              ),
              icon: Icon(
                allSelected
                    ? Icons.check_box_rounded
                    : Icons.select_all_rounded,
                size: 15,
                color: MetaColors.emerald,
              ),
              label: Text(
                allSelected ? 'Desmarcar Todos' : 'Selecionar Todos',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: MetaColors.emerald,
                ),
              ),
              onPressed: () {
                setState(() {
                  if (allSelected) {
                    _selectedMultipleStudentIds.clear();
                  } else {
                    _selectedMultipleStudentIds.clear();
                    _selectedMultipleStudentIds.addAll(
                      _students.map((s) => s['id'] as String),
                    );
                  }
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              _students.map((st) {
                final id = st['id'] as String;
                final name = st['full_name'] as String? ?? 'Aluno';
                final isSelected = _selectedMultipleStudentIds.contains(id);
                final hasAlert = st['has_alert'] == true;

                return FilterChip(
                  selected: isSelected,
                  showCheckmark: true,
                  checkmarkColor: isSelected ? Colors.black : null,
                  avatar: CircleAvatar(
                    radius: 10,
                    backgroundColor:
                        isSelected
                            ? Colors.black26
                            : AppColors.cardBorder(context),
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'A',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color:
                            isSelected ? Colors.black : MetaColors.textPrimary,
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
                          fontWeight:
                              isSelected ? FontWeight.w800 : FontWeight.w500,
                          color:
                              isSelected
                                  ? Colors.black
                                  : MetaColors.textPrimary,
                        ),
                      ),
                      if (hasAlert) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 14,
                          color: isSelected ? Colors.black : Colors.amber,
                        ),
                      ],
                    ],
                  ),
                  backgroundColor: MetaColors.surfaceHighlight,
                  selectedColor: MetaColors.emerald,
                  side: BorderSide(
                    color:
                        isSelected
                            ? MetaColors.emerald
                            : (hasAlert
                                ? Colors.amber.shade600
                                : AppColors.cardBorder(context)),
                  ),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedMultipleStudentIds.add(id);
                      } else {
                        _selectedMultipleStudentIds.remove(id);
                      }
                    });
                  },
                );
              }).toList(),
        ),
        if (_selectedMultipleStudentIds.isEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Selecione ao menos 1 aluno para o envio em lote.',
            style: TextStyle(
              fontSize: 11,
              color: Colors.amber.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
        ] else ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.emeraldBg(context),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: MetaColors.emerald.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.bolt_rounded,
                  size: 16,
                  color: MetaColors.emerald,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'A mesma periodização serÃ¡ sincronizada para os ${_selectedMultipleStudentIds.length} alunos selecionados.',
                    style: TextStyle(
                      fontSize: 11,
                      color: MetaColors.emerald,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEmptyStudentsWarning(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade900.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade700.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Nenhum aluno cadastrado ainda. A periodização poderÃ¡ ser salva e vinculada posteriormente.',
              style: TextStyle(fontSize: 12, color: MetaColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleApprovePlan() async {
    if (_generatedPlan == null) return;
    if (_selectedStudentIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.orange.shade800,
          content: Text(
            _dispatchMode == StudentDispatchMode.individual
                ? 'Selecione um aluno para vincular a esta periodização.'
                : 'Selecione ao menos 1 aluno para vincular a esta periodização.',
          ),
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
        final individualStudent = _selectedIndividualStudent;
        final message =
            (_dispatchMode == StudentDispatchMode.individual &&
                    individualStudent != null)
                ? '✓ Ficha liberada com sucesso para ${individualStudent['full_name']}!'
                : '✓ Ficha salva e liberada com sucesso para $successCount alunos!';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green.shade800,
            content: Text(message),
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
              color: MetaColors.surface,
              border: Border(
                bottom: BorderSide(color: AppColors.cardBorder(context)),
              ),
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
                          color: MetaColors.textPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.emeraldBg(context),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.emerald(
                            context,
                          ).withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        '${plan.splits.length} SPLITS',
                        style: TextStyle(
                          color: MetaColors.emerald,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Diretriz ClÃ­nica: ${plan.notesForTrainer}',
                  style: TextStyle(
                    fontSize: 12,
                    color: MetaColors.textSecondary,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: MetaColors.surfaceHighlight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: MetaColors.border),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _dispatchMode == StudentDispatchMode.individual
                            ? Icons.person_rounded
                            : Icons.groups_rounded,
                        size: 18,
                        color: MetaColors.emerald,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _dispatchMode == StudentDispatchMode.individual
                                  ? 'DestinatÃ¡rio Individual'
                                  : 'DestinatÃ¡rios em Lote (${_selectedMultipleStudentIds.length} alunos)',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: MetaColors.emerald,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              _getRecipientsSummaryText(),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: MetaColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (_students.isNotEmpty)
                        TextButton.icon(
                          icon: const Icon(Icons.edit_outlined, size: 14),
                          label: const Text(
                            'Alterar',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: MetaColors.emerald,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: _showChangeRecipientsSheet,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          TabBar(
            isScrollable: true,
            indicatorColor: MetaColors.emerald,
            labelColor: MetaColors.emerald,
            unselectedLabelColor: MetaColors.textSecondary,
            indicatorWeight: 3,
            tabs:
                plan.splits
                    .map(
                      (s) => Tab(
                        text: 'Treino ${s.splitIdentifier} (${s.splitName})',
                      ),
                    )
                    .toList(),
          ),
          Expanded(
            child: TabBarView(
              children: List.generate(plan.splits.length, (splitIndex) {
                final split = plan.splits[splitIndex];
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: split.exercises.length + 1,
                  itemBuilder: (ctx, i) {
                    // BOTÃƒO INCLUIR NOVO EXERCÃCIO AO FINAL DO SPLIT
                    if (i == split.exercises.length) {
                      return Container(
                        margin: const EdgeInsets.only(top: 8, bottom: 24),
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: Icon(
                            Icons.add_circle_outline_rounded,
                            color: MetaColors.emerald,
                            size: 18,
                          ),
                          label: Text(
                            'Incluir Novo ExercÃ­cio no Treino ${split.splitIdentifier}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: MetaColors.emerald,
                              fontSize: 13,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(
                              color: AppColors.emerald(
                                context,
                              ).withValues(alpha: 0.5),
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            backgroundColor: AppColors.emerald(
                              context,
                            ).withValues(alpha: 0.05),
                          ),
                          onPressed: () => _showAddExerciseDialog(splitIndex),
                        ),
                      );
                    }

                    final ex = split.exercises[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: MetaColors.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: AppColors.cardBorder(context),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                isDark
                                    ? Colors.black26
                                    : const Color(0x060F172A),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: AppColors.emeraldBg(context),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.emerald(
                                      context,
                                    ).withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    '${i + 1}',
                                    style: TextStyle(
                                      color: MetaColors.emerald,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      ex.name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: MetaColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      ex.targetMuscleGroup,
                                      style: TextStyle(
                                        color: MetaColors.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 19,
                                ),
                                color: Colors.red.shade400,
                                tooltip: 'Remover exercÃ­cio',
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                                onPressed:
                                    () => _confirmRemoveExercise(
                                      splitIndex,
                                      i,
                                      ex.name,
                                    ),
                              ),
                            ],
                          ),
                          if (ex.notes.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Padding(
                              padding: const EdgeInsets.only(left: 38),
                              child: Text(
                                ex.notes,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: MetaColors.textSecondary,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          // CONTROLES DE AJUSTE RÃPIDO: SÃ‰RIES, REPS, DESCANSO
                          Row(
                            children: [
                              _buildParamStepper(
                                label: 'SÃ©ries',
                                value: '${ex.sets}',
                                onDecrement:
                                    () =>
                                        _updateExerciseSets(splitIndex, i, -1),
                                onIncrement:
                                    () => _updateExerciseSets(splitIndex, i, 1),
                              ),
                              const SizedBox(width: 8),
                              _buildParamStepper(
                                label: 'Reps',
                                value: ex.reps,
                                onDecrement:
                                    () => _cycleExerciseReps(splitIndex, i, -1),
                                onIncrement:
                                    () => _cycleExerciseReps(splitIndex, i, 1),
                                onTapValue:
                                    () => _editRepsDirectly(
                                      splitIndex,
                                      i,
                                      ex.reps,
                                    ),
                              ),
                              const SizedBox(width: 8),
                              _buildParamStepper(
                                label: 'Descanso',
                                value: '${ex.restSeconds}s',
                                onDecrement:
                                    () =>
                                        _updateExerciseRest(splitIndex, i, -15),
                                onIncrement:
                                    () =>
                                        _updateExerciseRest(splitIndex, i, 15),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              }),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(
              left: 16.0,
              right: 16.0,
              top: 16.0,
              bottom: 16.0 + MediaQuery.paddingOf(context).bottom,
            ),
            child: SizedBox(
              width: double.infinity,
              child: SquircleButton(
                  label: _isSavingPlan
                      ? 'Gravando no Supabase...'
                      : (_dispatchMode == StudentDispatchMode.individual
                          ? 'Aprovar e Liberar para $(_selectedIndividualStudent?['full_name'] ?? 'o Aluno'})'
                          : 'Aprovar e Liberar para $(_selectedMultipleStudentIds.length}) Alunos'),
                  icon: _isSavingPlan ? Icons.hourglass_empty : Icons.check_circle_outline,
                  isPrimary: true,
                  onPressed: _isSavingPlan ? () {} : _handleApprovePlan,
                ),
            ),
          ),
        ],
      ),
    );
  }

  void _showChangeRecipientsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: MetaColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'DestinatÃ¡rios da PrescriÃ§Ã£o',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: MetaColors.textPrimary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: MetaColors.surfaceHighlight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: MetaColors.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              setSheetState(
                                () =>
                                    _dispatchMode =
                                        StudentDispatchMode.individual,
                              );
                              setState(() {});
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color:
                                    _dispatchMode ==
                                            StudentDispatchMode.individual
                                        ? MetaColors.emerald
                                        : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Aluno Individual',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      _dispatchMode ==
                                              StudentDispatchMode.individual
                                          ? Colors.black
                                          : MetaColors.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              setSheetState(
                                () =>
                                    _dispatchMode =
                                        StudentDispatchMode.multiple,
                              );
                              setState(() {});
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color:
                                    _dispatchMode ==
                                            StudentDispatchMode.multiple
                                        ? MetaColors.emerald
                                        : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Vários Alunos (${_selectedMultipleStudentIds.length})',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      _dispatchMode ==
                                              StudentDispatchMode.multiple
                                          ? Colors.black
                                          : MetaColors.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.45,
                    ),
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        if (_dispatchMode ==
                            StudentDispatchMode.individual) ...[
                          ..._students.map((st) {
                            final isSel =
                                _selectedIndividualStudentId == st['id'];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                backgroundColor:
                                    isSel
                                        ? MetaColors.emerald
                                        : MetaColors.surfaceHighlight,
                                child: Text(
                                  (st['full_name'] as String? ?? 'A')[0]
                                      .toUpperCase(),
                                  style: TextStyle(
                                    color:
                                        isSel
                                            ? Colors.black
                                            : MetaColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                st['full_name'] as String? ?? 'Aluno',
                                style: TextStyle(
                                  color: MetaColors.textPrimary,
                                  fontWeight:
                                      isSel
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                ),
                              ),
                              subtitle: Text(
                                st['goal'] ?? st['objective'] ?? 'Consultoria',
                                style: TextStyle(
                                  color: MetaColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              trailing:
                                  isSel
                                      ? Icon(
                                        Icons.check_circle_rounded,
                                        color: MetaColors.emerald,
                                      )
                                      : null,
                              onTap: () {
                                setSheetState(
                                  () => _selectedIndividualStudentId = st['id'],
                                );
                                setState(
                                  () => _selectedIndividualStudentId = st['id'],
                                );
                              },
                            );
                          }),
                        ] else ...[
                          ..._students.map((st) {
                            final id = st['id'] as String;
                            final isSel = _selectedMultipleStudentIds.contains(
                              id,
                            );
                            return CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              activeColor: MetaColors.emerald,
                              checkColor: Colors.black,
                              value: isSel,
                              title: Text(
                                st['full_name'] as String? ?? 'Aluno',
                                style: TextStyle(
                                  color: MetaColors.textPrimary,
                                ),
                              ),
                              subtitle: Text(
                                st['goal'] ?? st['objective'] ?? 'Consultoria',
                                style: TextStyle(
                                  color: MetaColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              onChanged: (val) {
                                setSheetState(() {
                                  if (val == true) {
                                    _selectedMultipleStudentIds.add(id);
                                  } else {
                                    _selectedMultipleStudentIds.remove(id);
                                  }
                                });
                                setState(() {});
                              },
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MetaColors.emerald,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text(
                        'Confirmar DestinatÃ¡rios',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  static const List<String> _commonRepRanges = [
    '4-6',
    '6-8',
    '8-10',
    '10-12',
    '12-15',
    '15-20',
    '20-25',
    'AtÃ© a Falha',
  ];

  Widget _buildParamStepper({
    required String label,
    required String value,
    required VoidCallback onDecrement,
    required VoidCallback onIncrement,
    VoidCallback? onTapValue,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
        decoration: BoxDecoration(
          color: MetaColors.surfaceHighlight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: MetaColors.border),
        ),
        child: Column(
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: MetaColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap: onDecrement,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: MetaColors.surface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.cardBorder(context)),
                    ),
                    child: Icon(
                      Icons.remove,
                      size: 13,
                      color: MetaColors.textPrimary,
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: onTapValue,
                    child: Text(
                      value,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: MetaColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                InkWell(
                  onTap: onIncrement,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: MetaColors.surface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.cardBorder(context)),
                    ),
                    child: Icon(
                      Icons.add,
                      size: 13,
                      color: MetaColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _updateExerciseSets(int splitIndex, int exerciseIndex, int delta) {
    if (_generatedPlan == null) return;
    final splits = List<SplitModel>.from(_generatedPlan!.splits);
    final split = splits[splitIndex];
    final exercises = List<ExerciseModel>.from(split.exercises);
    final ex = exercises[exerciseIndex];
    final newSets = (ex.sets + delta).clamp(1, 10);
    if (newSets == ex.sets) return;

    exercises[exerciseIndex] = ex.copyWith(sets: newSets);
    splits[splitIndex] = split.copyWith(exercises: exercises);
    setState(() {
      _generatedPlan = _generatedPlan!.copyWith(splits: splits);
    });
  }

  void _cycleExerciseReps(int splitIndex, int exerciseIndex, int delta) {
    if (_generatedPlan == null) return;
    final splits = List<SplitModel>.from(_generatedPlan!.splits);
    final split = splits[splitIndex];
    final exercises = List<ExerciseModel>.from(split.exercises);
    final ex = exercises[exerciseIndex];

    int currentIdx = _commonRepRanges.indexOf(ex.reps.trim());
    if (currentIdx == -1) {
      currentIdx = 3;
    }
    final newIdx = (currentIdx + delta).clamp(0, _commonRepRanges.length - 1);
    final newReps = _commonRepRanges[newIdx];

    exercises[exerciseIndex] = ex.copyWith(reps: newReps);
    splits[splitIndex] = split.copyWith(exercises: exercises);
    setState(() {
      _generatedPlan = _generatedPlan!.copyWith(splits: splits);
    });
  }

  void _editRepsDirectly(
    int splitIndex,
    int exerciseIndex,
    String currentReps,
  ) {
    final ctrl = TextEditingController(text: currentReps);
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: MetaColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              'Ajustar RepetiÃ§Ãµes',
              style: TextStyle(color: MetaColors.textPrimary, fontSize: 16),
            ),
            content: TextField(
              controller: ctrl,
              autofocus: true,
              style: TextStyle(color: MetaColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Ex: 10-12, 4x8, AtÃ© a falha',
                filled: true,
                fillColor: MetaColors.surfaceHighlight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'Cancelar',
                  style: TextStyle(color: MetaColors.textSecondary),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: MetaColors.emerald,
                  foregroundColor: Colors.black,
                ),
                onPressed: () {
                  final val = ctrl.text.trim();
                  if (val.isNotEmpty) {
                    final splits = List<SplitModel>.from(
                      _generatedPlan!.splits,
                    );
                    final split = splits[splitIndex];
                    final exercises = List<ExerciseModel>.from(split.exercises);
                    exercises[exerciseIndex] = exercises[exerciseIndex]
                        .copyWith(reps: val);
                    splits[splitIndex] = split.copyWith(exercises: exercises);
                    setState(() {
                      _generatedPlan = _generatedPlan!.copyWith(splits: splits);
                    });
                  }
                  Navigator.pop(ctx);
                },
                child: const Text('Salvar'),
              ),
            ],
          ),
    );
  }

  void _updateExerciseRest(
    int splitIndex,
    int exerciseIndex,
    int deltaSeconds,
  ) {
    if (_generatedPlan == null) return;
    final splits = List<SplitModel>.from(_generatedPlan!.splits);
    final split = splits[splitIndex];
    final exercises = List<ExerciseModel>.from(split.exercises);
    final ex = exercises[exerciseIndex];
    final newRest = (ex.restSeconds + deltaSeconds).clamp(15, 300);
    if (newRest == ex.restSeconds) return;

    exercises[exerciseIndex] = ex.copyWith(restSeconds: newRest);
    splits[splitIndex] = split.copyWith(exercises: exercises);
    setState(() {
      _generatedPlan = _generatedPlan!.copyWith(splits: splits);
    });
  }

  void _confirmRemoveExercise(
    int splitIndex,
    int exerciseIndex,
    String exerciseName,
  ) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: MetaColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              'Remover ExercÃ­cio?',
              style: TextStyle(color: MetaColors.textPrimary),
            ),
            content: Text(
              'Deseja remover "$exerciseName" desta divisÃ£o?',
              style: TextStyle(color: MetaColors.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'Cancelar',
                  style: TextStyle(color: MetaColors.textSecondary),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _deleteExercise(splitIndex, exerciseIndex);
                },
                child: const Text('Remover'),
              ),
            ],
          ),
    );
  }

  void _deleteExercise(int splitIndex, int exerciseIndex) {
    if (_generatedPlan == null) return;
    final splits = List<SplitModel>.from(_generatedPlan!.splits);
    final split = splits[splitIndex];
    final exercises = List<ExerciseModel>.from(split.exercises);
    exercises.removeAt(exerciseIndex);

    final reordered = <ExerciseModel>[];
    for (int k = 0; k < exercises.length; k++) {
      reordered.add(exercises[k].copyWith(order: k + 1));
    }
    splits[splitIndex] = split.copyWith(exercises: reordered);
    setState(() {
      _generatedPlan = _generatedPlan!.copyWith(splits: splits);
    });
  }

  void _addNewExercise(int splitIndex, ExerciseModel newExercise) {
    if (_generatedPlan == null) return;
    final splits = List<SplitModel>.from(_generatedPlan!.splits);
    final split = splits[splitIndex];
    final exercises = List<ExerciseModel>.from(split.exercises);
    exercises.add(newExercise.copyWith(order: exercises.length + 1));
    splits[splitIndex] = split.copyWith(exercises: exercises);
    setState(() {
      _generatedPlan = _generatedPlan!.copyWith(splits: splits);
    });
  }

  void _showAddExerciseDialog(int splitIndex) {
    if (_generatedPlan == null) return;
    final split = _generatedPlan!.splits[splitIndex];

    final nameCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String selectedMuscle = 'Peitoral';
    int sets = 3;
    String reps = '10-12';
    int restSeconds = 60;

    const muscleOptions = [
      'Peitoral',
      'Dorsais / Costas',
      'Deltoides / Ombros',
      'QuadrÃ­ceps',
      'Posterior de Coxa',
      'GlÃºteos',
      'BÃ­ceps',
      'TrÃ­ceps',
      'Panturrilhas',
      'AbdÃ´men / Core',
      'Geral',
    ];

    const suggestions = [
      'Supino Inclinado com Halteres',
      'Puxada Alta (Lat Pulldown)',
      'ElevaÃ§Ã£o Lateral na Polia',
      'Agachamento BÃºlgaro',
      'Leg Press 45Â°',
      'Cadeira Extensora',
      'TrÃ­ceps na Polia com Corda',
      'Rosca Direta com Barra W',
      'Mesa Flexora',
      'ElevaÃ§Ã£o PÃ©lvica',
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: MetaColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.fitness_center_rounded,
                              color: MetaColors.emerald,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Novo ExercÃ­cio â€¢ Treino ${split.splitIdentifier}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: MetaColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameCtrl,
                      style: TextStyle(color: MetaColors.textPrimary),
                      decoration: _inputDecoration(
                        context,
                        'Nome do ExercÃ­cio',
                        prefixIcon: Icons.edit_outlined,
                        hint: 'Ex: Supino Inclinado com Halteres',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children:
                          suggestions.take(5).map((sug) {
                            return ActionChip(
                              label: Text(
                                sug,
                                style: const TextStyle(fontSize: 10),
                              ),
                              backgroundColor: MetaColors.surfaceHighlight,
                              side: BorderSide(
                                color: MetaColors.border,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              onPressed: () {
                                setModalState(() {
                                  nameCtrl.text = sug;
                                });
                              },
                            );
                          }).toList(),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: selectedMuscle,
                      dropdownColor: MetaColors.surface,
                      style: TextStyle(
                        color: MetaColors.textPrimary,
                        fontSize: 13,
                      ),
                      decoration: _inputDecoration(
                        context,
                        'Grupo Muscular Alvo',
                        prefixIcon: Icons.accessibility_new_rounded,
                      ),
                      items:
                          muscleOptions
                              .map(
                                (m) =>
                                    DropdownMenuItem(value: m, child: Text(m)),
                              )
                              .toList(),
                      onChanged: (val) {
                        if (val != null)
                          setModalState(() => selectedMuscle = val);
                      },
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: MetaColors.surfaceHighlight,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: MetaColors.border,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'SÃ‰RIES',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: MetaColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    InkWell(
                                      onTap:
                                          sets > 1
                                              ? () =>
                                                  setModalState(() => sets--)
                                              : null,
                                      child: Icon(
                                        Icons.remove_circle_outline,
                                        size: 20,
                                        color: MetaColors.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      '$sets',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: MetaColors.textPrimary,
                                      ),
                                    ),
                                    InkWell(
                                      onTap:
                                          sets < 10
                                              ? () =>
                                                  setModalState(() => sets++)
                                              : null,
                                      child: Icon(
                                        Icons.add_circle_outline,
                                        size: 20,
                                        color: MetaColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: MetaColors.surfaceHighlight,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: MetaColors.border,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'REPETIÃ‡Ã•ES',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: MetaColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                DropdownButton<String>(
                                  value:
                                      _commonRepRanges.contains(reps)
                                          ? reps
                                          : '10-12',
                                  dropdownColor: MetaColors.surface,
                                  underline: const SizedBox(),
                                  isDense: true,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: MetaColors.textPrimary,
                                  ),
                                  items:
                                      _commonRepRanges
                                          .map(
                                            (r) => DropdownMenuItem(
                                              value: r,
                                              child: Text(r),
                                            ),
                                          )
                                          .toList(),
                                  onChanged: (val) {
                                    if (val != null)
                                      setModalState(() => reps = val);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: MetaColors.surfaceHighlight,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: MetaColors.border,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'DESCANSO',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: MetaColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    InkWell(
                                      onTap:
                                          restSeconds > 15
                                              ? () => setModalState(
                                                () => restSeconds -= 15,
                                              )
                                              : null,
                                      child: Icon(
                                        Icons.remove_circle_outline,
                                        size: 20,
                                        color: MetaColors.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      '${restSeconds}s',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: MetaColors.textPrimary,
                                      ),
                                    ),
                                    InkWell(
                                      onTap:
                                          restSeconds < 300
                                              ? () => setModalState(
                                                () => restSeconds += 15,
                                              )
                                              : null,
                                      child: Icon(
                                        Icons.add_circle_outline,
                                        size: 20,
                                        color: MetaColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: notesCtrl,
                      style: TextStyle(
                        color: MetaColors.textPrimary,
                        fontSize: 13,
                      ),
                      decoration: _inputDecoration(
                        context,
                        'Diretriz / Notas de ExecuÃ§Ã£o (Opcional)',
                        prefixIcon: Icons.notes_rounded,
                        hint: 'Ex: CadÃªncia 3-0-1-0 com pico de contraÃ§Ã£o',
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(
                          Icons.add_rounded,
                          color: Colors.black,
                        ),
                        label: Text(
                          'Adicionar ao Treino ${split.splitIdentifier}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: MetaColors.emerald,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          final name = nameCtrl.text.trim();
                          if (name.isEmpty) return;

                          final newExercise = ExerciseModel(
                            order: split.exercises.length + 1,
                            name: name,
                            targetMuscleGroup: selectedMuscle,
                            sets: sets,
                            reps: reps,
                            restSeconds: restSeconds,
                            notes: notesCtrl.text.trim(),
                            substitutionVector: '',
                          );

                          _addNewExercise(splitIndex, newExercise);
                          Navigator.pop(ctx);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}




