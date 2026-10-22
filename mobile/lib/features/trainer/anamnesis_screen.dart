import '../../core/theme/theme_controller.dart';
import '../../core/widgets/theme_toggle_button.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/meta_components.dart';
import '../../core/widgets/ai_generation_stepper.dart';
import '../../core/widgets/exercise_media_sheet.dart';
import '../../core/widgets/server_config_dialog.dart';
import '../../models/exercise_model.dart';
import '../../models/split_model.dart';
import '../../models/workout_plan_model.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
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
  bool get _isDark => ThemeController.instance.isEffectiveDark(context);
  Color get _bg => MetaColors.bg(context);
  Color get _cardBg => MetaColors.card(context);
  Color get _border => MetaColors.cardBorder(context);
  Color get _textPrimary => MetaColors.text(context);
  Color get _textSecondary => MetaColors.subtext(context);
  Color get _highlight => MetaColors.highlight(context);

  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();

  String _objective = 'Hipertrofia Muscular';
  String _trainingLevel = 'Intermediário';
  int _daysPerWeek = 4;
  String _splitType = 'Automático (IA Sugere o Ideal)';
  String _targetFocus = 'Geral / Equilibrado';
  String _workoutLocation = 'Academia completa';
  final _restrictionsCtrl = TextEditingController(
    text:
        'Leve desconforto no ombro direito (evitar abdução acima de 90° com carga pesada)',
  );
  final _notesCtrl = TextEditingController(
    text: 'Foco em peitoral superior e deltoides',
  );

  bool _isLoading = false;
  bool _isSavingPlan = false;
  bool _isClinicalNotesExpanded = false;
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

  Map<String, dynamic>? _selectedStudentAnamnesis;
  bool _isLoadingAnamnesis = false;

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
            'Força Máxima',
          ].contains(obj)) {
        _objective = obj as String;
      }
    }
    _loadStudentAnamnesis(studentId);
  }

  Future<void> _loadStudentAnamnesis(String studentId) async {
    setState(() => _isLoadingAnamnesis = true);
    try {
      final anamnesis = await WorkoutService.getLatestStudentAnamnesis(studentId);
      if (mounted && _selectedIndividualStudentId == studentId) {
        setState(() {
          _selectedStudentAnamnesis = anamnesis;
          _isLoadingAnamnesis = false;
          if (anamnesis != null) {
            final details = (anamnesis['details'] as Map<String, dynamic>?) ?? {};

            // Objetivo
            final obj = anamnesis['objective'] ?? details['objective'];
            if (obj != null && obj.toString().isNotEmpty) {
              final objStr = obj.toString();
              if (objStr.contains('Hipertrofia')) {
                _objective = 'Hipertrofia Muscular';
              } else if (objStr.contains('Emagrecimento') || objStr.contains('Definição')) {
                _objective = 'Emagrecimento';
              } else if (objStr.contains('Força')) {
                _objective = 'Força Máxima';
              } else {
                _objective = 'Condicionamento Geral';
              }
            }

            // Nível
            final lvl = anamnesis['training_level'] ?? details['training_level'];
            if (lvl != null && lvl.toString().isNotEmpty) {
              final lvlStr = lvl.toString();
              if (lvlStr.contains('Iniciante')) {
                _trainingLevel = 'Iniciante';
              } else if (lvlStr.contains('Avançado')) {
                _trainingLevel = 'Avançado';
              } else {
                _trainingLevel = 'Intermediário';
              }
            }

            // Frequência semanal
            final days = anamnesis['weekly_days'] ?? details['weekly_days'];
            if (days is int && days >= 2 && days <= 6) {
              _daysPerWeek = days;
            } else if (days != null) {
              final parsed = int.tryParse(days.toString());
              if (parsed != null && parsed >= 2 && parsed <= 6) {
                _daysPerWeek = parsed;
              }
            }

            // Restrições / Dores
            final inj = anamnesis['injuries_summary'] ??
                (anamnesis['injuries'] as List?)?.join(', ') ??
                details['injuries_details'];
            if (inj != null && inj.toString().isNotEmpty && !inj.toString().toLowerCase().contains('nenhuma')) {
              _restrictionsCtrl.text = inj.toString();
            }

            // Local
            final loc = anamnesis['workout_location'] ?? details['workout_location'];
            if (loc != null && loc.toString().isNotEmpty) {
              final locStr = loc.toString();
              if (locStr.contains('Casa') && locStr.contains('Halteres')) {
                _workoutLocation = 'Em casa com halteres';
              } else if (locStr.contains('Casa') || locStr.contains('corpo')) {
                _workoutLocation = 'Em casa (peso do corpo)';
              } else if (locStr.contains('Condomínio') || locStr.contains('básica')) {
                _workoutLocation = 'Academia de condomínio / básica';
              } else {
                _workoutLocation = 'Academia completa';
              }
            }

            // Observações / Foco
            final priorities = anamnesis['muscle_priorities'] ?? details['muscle_priorities'];
            if (priorities is List && priorities.isNotEmpty) {
              _notesCtrl.text = 'Foco em: ${priorities.join(", ")}. '
                  'Estilo: ${anamnesis['training_style'] ?? details['training_style'] ?? "Equilibrado"}. '
                  'Duração: ${anamnesis['session_duration'] ?? details['session_duration'] ?? "60 min"}.';
            }
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingAnamnesis = false);
    }
  }

  @override
  void dispose() {
    _restrictionsCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  bool _isStudentPending(Map<String, dynamic>? st) {
    if (st == null || st.isEmpty) return false;
    final status = (st['status'] as String? ?? '').toLowerCase();
    final recent = (st['recent_status'] as String? ?? '').toLowerCase();
    return status.contains('pendente') ||
        status.contains('aguardando') ||
        recent.contains('pendente') ||
        recent.contains('aguardando');
  }

  Future<void> _openWhatsAppReminder(Map<String, dynamic> student) async {
    final phone = student['phone'] as String? ?? '';
    final name = student['full_name'] as String? ?? 'Aluno';
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final trainer = AuthService.currentUser;
    final trainerName =
        trainer?.userMetadata?['full_name'] as String? ?? 'Seu Treinador';

    final message = Uri.encodeComponent(
      'Olá $name! Aqui é o seu treinador $trainerName. '
      'Estou pronto para montar sua periodização personalizada no Mr. Coach. '
      'Acesse o link do convite para concluir seu cadastro e liberar seu treino!',
    );

    if (cleanPhone.isNotEmpty) {
      final url = Uri.parse('https://wa.me/$cleanPhone?text=$message');
      try {
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
          return;
        }
      } catch (_) {}
    }

    if (mounted) {
      final inviteLink = student['invitation_link'] as String? ?? '';
      if (inviteLink.isNotEmpty) {
        await Clipboard.setData(ClipboardData(text: inviteLink));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: MetaColors.emerald,
            content: Text('Link do convite copiado para a área de transferência!'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.amber.shade900,
            content: Text('Aluno $name ainda não cadastrou telefone WhatsApp.'),
          ),
        );
      }
    }
  }

  void _showPendingStudentWarningDialog(List<Map<String, dynamic>> pendingStudents) {
    final firstName = pendingStudents.first['full_name'] as String? ?? 'o aluno';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.lock_clock_rounded, color: Color(0xFFF59E0B)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Proteção de Créditos IA',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          pendingStudents.length == 1
              ? '$firstName ainda não concluiu o cadastro através do link de convite.\n\nPara proteger seus créditos de IA e garantir que a periodização seja salva com segurança, a prescrição será liberada assim que o aluno ativar a conta.'
              : 'Alguns alunos selecionados ainda possuem convites pendentes de confirmação.\n\nPara proteger seus créditos de IA, desmarque os alunos pendentes para gerar a periodização da turma.',
          style: TextStyle(
            color: _textSecondary,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        actions: [
          if (pendingStudents.length == 1)
            TextButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _openWhatsAppReminder(pendingStudents.first);
              },
              icon: const Icon(Icons.chat_bubble_outline, size: 16, color: Color(0xFFF59E0B)),
              label: const Text(
                'Lembrar no WhatsApp',
                style: TextStyle(
                  color: Color(0xFFF59E0B),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendi', style: TextStyle(color: MetaColors.emerald)),
          ),
        ],
      ),
    );
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

    final pendingStudents = _students.where((st) {
      if (!_selectedStudentIds.contains(st['id'])) return false;
      return _isStudentPending(st);
    }).toList();

    if (pendingStudents.isNotEmpty) {
      _showPendingStudentWarningDialog(pendingStudents);
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
          SnackBar(
            backgroundColor: MetaColors.emerald,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Periodização gerada com sucesso pela IA!',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final cleanMsg = e.toString().replaceFirst(RegExp(r'^(Exception|ClientException):\s*'), '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade800,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Text('Falha ao gerar periodização: $cleanMsg'),
            action: SnackBarAction(
              label: 'Servidor',
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
      fillColor: _cardBg,
      labelStyle: TextStyle(color: _textSecondary, fontSize: 13),
      hintStyle: TextStyle(color: _textSecondary, fontSize: 12),
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
    final isDark = _isDark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _bg,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: _textPrimary,
              size: 20,
            ),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: Text(
            _generatedPlan == null ? 'Nova Periodização' : 'Revisão da Ficha',
            style: TextStyle(
              color: _textPrimary,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              fontSize: 18,
            ),
          ),
          actions: [
            const ThemeToggleButton(compact: true),
            const SizedBox(width: 4),
            if (kDebugMode)
              IconButton(
                icon: Icon(
                  Icons.settings_ethernet_rounded,
                  color: _textSecondary,
                ),
                tooltip: 'Configurar IP do Servidor (Dev)',
                onPressed: () => ServerConfigDialog.show(context),
              ),
            if (_generatedPlan != null)
              IconButton(
                icon: Icon(
                  Icons.refresh_rounded,
                  color: _textSecondary,
                ),
                tooltip: 'Recomeçar',
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
      ),
    );
  }

  Widget _buildSectionHeader(String tag, String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tag,
          style: const TextStyle(
            fontSize: 11,
            letterSpacing: 1.1,
            fontWeight: FontWeight.w700,
            color: MetaColors.emerald,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: _textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildObjectiveSelector() {
    const objectives = [
      {
        'title': 'Hipertrofia Muscular',
        'subtitle': 'Volume & Densidade',
        'icon': Icons.fitness_center_rounded,
      },
      {
        'title': 'Emagrecimento',
        'subtitle': 'Déficit & Queima',
        'icon': Icons.local_fire_department_rounded,
      },
      {
        'title': 'Condicionamento Geral',
        'subtitle': 'Resistência & Saúde',
        'icon': Icons.directions_run_rounded,
      },
      {
        'title': 'Força Máxima',
        'subtitle': 'Potência & Cargas',
        'icon': Icons.bolt_rounded,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('OBJETIVO PRINCIPAL', 'Metodologia Alvo'),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.3,
          ),
          itemCount: objectives.length,
          itemBuilder: (ctx, idx) {
            final obj = objectives[idx];
            final title = obj['title'] as String;
            final isSelected = _objective == title;
            return InkWell(
              onTap: () => setState(() => _objective = title),
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? MetaColors.emerald.withValues(alpha: 0.15)
                      : _cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? MetaColors.emerald : _border,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      obj['icon'] as IconData,
                      size: 20,
                      color: isSelected ? MetaColors.emerald : _textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              color: isSelected ? _textPrimary : _textSecondary,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            obj['subtitle'] as String,
                            style: TextStyle(
                              color: isSelected ? MetaColors.emerald : _textSecondary.withValues(alpha: 0.7),
                              fontSize: 9,
                            ),
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildLevelSelector() {
    const levels = ['Iniciante', 'Intermediário', 'Avançado'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('NÍVEL DE EXPERIÊNCIA', 'Capacidade Neuromuscular'),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
          ),
          child: Row(
            children: levels.map((lvl) {
              final isSelected = _trainingLevel == lvl;
              return Expanded(
                child: InkWell(
                  onTap: () => setState(() => _trainingLevel = lvl),
                  borderRadius: BorderRadius.circular(10),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected ? MetaColors.emerald : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      lvl,
                      style: TextStyle(
                        color: isSelected ? Colors.black : _textPrimary,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildDaysPerWeekSelector() {
    const days = [2, 3, 4, 5, 6];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('FREQUÊNCIA SEMANAL', 'Dias de Treino por Semana'),
        const SizedBox(height: 10),
        Row(
          children: days.map((d) {
            final isSelected = _daysPerWeek == d;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: InkWell(
                  onTap: () => setState(() => _daysPerWeek = d),
                  borderRadius: BorderRadius.circular(14),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? MetaColors.emerald
                          : _cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? MetaColors.emerald : _border,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      children: [
                        Text(
                          '${d}x',
                          style: TextStyle(
                            color: isSelected ? Colors.black : _textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          'dias',
                          style: TextStyle(
                            color: isSelected ? Colors.black87 : _textSecondary,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildLocationSelector() {
    const locations = [
      {
        'title': 'Academia completa',
        'label': 'Academia',
        'icon': Icons.domain_rounded,
      },
      {
        'title': 'Condomínio',
        'label': 'Condomínio',
        'icon': Icons.apartment_rounded,
      },
      {
        'title': 'Em casa (Halteres/Peso Corporal)',
        'label': 'Em Casa',
        'icon': Icons.home_rounded,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('AMBIENTE DE TREINO', 'Disponibilidade de Aparelhos'),
        const SizedBox(height: 10),
        Row(
          children: locations.map((loc) {
            final val = loc['title'] as String;
            final isSelected = _workoutLocation == val;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: InkWell(
                  onTap: () => setState(() => _workoutLocation = val),
                  borderRadius: BorderRadius.circular(14),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? MetaColors.emerald.withValues(alpha: 0.15)
                          : _cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? MetaColors.emerald : _border,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      children: [
                        Icon(
                          loc['icon'] as IconData,
                          size: 22,
                          color: isSelected ? MetaColors.emerald : _textSecondary,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          loc['label'] as String,
                          style: TextStyle(
                            color: isSelected ? _textPrimary : _textSecondary,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            fontSize: 11,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSplitTypeSelector() {
    final splitOptions = [
      {'title': 'Automático IA', 'subtitle': 'A IA escolhe o melhor split', 'icon': Icons.auto_awesome, 'val': 'Automático (IA Sugere o Ideal)'},
      {'title': 'Full Body', 'subtitle': '1 a 3 dias • Corpo inteiro', 'icon': Icons.accessibility_new_rounded, 'val': 'Full Body (1 a 3 dias - Corpo Inteiro)'},
      {'title': 'Upper / Lower', 'subtitle': '2 ou 4 dias • Sup/Inf', 'icon': Icons.swap_vert_rounded, 'val': 'Upper / Lower (2 ou 4 dias - Superiores / Inferiores)'},
      {'title': 'Push / Pull / Legs', 'subtitle': '3 a 6 dias • Empurrar/Puxar/Pernas', 'icon': Icons.fitness_center_rounded, 'val': 'Push / Pull / Legs (PPL - 3 a 6 dias)'},
      {'title': 'Divisão ABC', 'subtitle': '3 dias • Tradicional', 'icon': Icons.view_column_rounded, 'val': 'Divisão ABC Tradicional'},
      {'title': 'Divisão ABCD', 'subtitle': '4 dias • Clássico', 'icon': Icons.grid_view_rounded, 'val': 'Divisão ABCD Clássica (4 dias)'},
      {'title': 'Divisão ABCDE', 'subtitle': '5 dias • 1 músculo/dia', 'icon': Icons.dashboard_rounded, 'val': 'Divisão ABCDE Avançada (1 grupo/dia)'},
      {'title': 'Agonista / Antag.', 'subtitle': 'Superséries eficientes', 'icon': Icons.compare_arrows_rounded, 'val': 'Agonista / Antagonista (Superséries eficientes)'},
      {'title': 'Ponto Fraco', 'subtitle': 'Especialização muscular', 'icon': Icons.filter_center_focus_rounded, 'val': 'Especialização de Ponto Fraco'},
      {'title': 'Reabilitação', 'subtitle': 'Articularmente poupadora', 'icon': Icons.healing_rounded, 'val': 'Reabilitação / Articularmente Poupadora'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('DIVISÃO / SPLIT', 'Estrutura dos Treinos'),
        const SizedBox(height: 10),
        SizedBox(
          height: 68,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: splitOptions.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (ctx, idx) {
              final opt = splitOptions[idx];
              final val = opt['val'] as String;
              final isSel = _splitType == val;
              return InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _splitType = val);
                },
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSel
                        ? MetaColors.emerald.withValues(alpha: 0.16)
                        : _cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSel ? MetaColors.emerald : _border,
                      width: isSel ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: isSel
                              ? MetaColors.emerald.withValues(alpha: 0.22)
                              : _highlight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          opt['icon'] as IconData,
                          size: 18,
                          color: isSel ? MetaColors.emerald : _textSecondary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            opt['title'] as String,
                            style: TextStyle(
                              color: isSel ? MetaColors.emerald : _textPrimary,
                              fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                              fontSize: 12.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            opt['subtitle'] as String,
                            style: TextStyle(
                              color: isSel
                                  ? MetaColors.emerald.withValues(alpha: 0.8)
                                  : _textSecondary,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTargetFocusSelector() {
    const focusOptions = [
      {'name': 'Geral / Equilibrado', 'icon': '⚖️'},
      {'name': 'Glúteos & Posterior de Coxa', 'icon': '🍑'},
      {'name': 'Deltoides & Ombros 3D', 'icon': '🥥'},
      {'name': 'Peitoral Superior (Clavicular)', 'icon': '🛡️'},
      {'name': 'Dorsais & V-Taper (Largura)', 'icon': '🦅'},
      {'name': 'Braços (Bíceps e Tríceps)', 'icon': '💪'},
      {'name': 'Quadríceps & Vasto Medial', 'icon': '🦵'},
      {'name': 'Core & Fortalecimento Postural', 'icon': '🧱'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('FOCO MUSCULAR / PONTO FRACO', 'Ênfase e Prioridade de Volume'),
        const SizedBox(height: 10),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: focusOptions.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (ctx, idx) {
              final item = focusOptions[idx];
              final name = item['name']!;
              final icon = item['icon']!;
              final isSelected = _targetFocus == name;

              return InkWell(
                onTap: () => setState(() => _targetFocus = name),
                borderRadius: BorderRadius.circular(50),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? MetaColors.emerald
                        : _cardBg,
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(
                      color: isSelected ? MetaColors.emerald : _border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(icon, style: const TextStyle(fontSize: 13)),
                      const SizedBox(width: 6),
                      Text(
                        name,
                        style: TextStyle(
                          color: isSelected ? Colors.black : _textPrimary,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRestrictionsSection() {
    const quickRestrictions = [
      'Ombro',
      'Coluna Lombar',
      'Joelho',
      'Punho',
      'Cervical',
      'Sem Restrições',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('BLINDAGEM ARTICULAR', 'Dores, Lesões ou Limitações'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: quickRestrictions.map((tag) {
            final isNone = tag == 'Sem Restrições';
            final text = _restrictionsCtrl.text.toLowerCase();
            final isSelected = isNone
                ? (text.isEmpty || text.contains('sem restriç') || text.contains('nenhum'))
                : text.contains(tag.toLowerCase());

            return InkWell(
              onTap: () {
                setState(() {
                  if (isNone) {
                    _restrictionsCtrl.clear();
                  } else {
                    final current = _restrictionsCtrl.text.trim();
                    if (isSelected) {
                      _restrictionsCtrl.text = current
                          .replaceAll(RegExp(tag, caseSensitive: false), '')
                          .replaceAll(RegExp(r',\s*,|\s*,\s*$|^\s*,\s*'), '')
                          .trim();
                    } else {
                      _restrictionsCtrl.text = current.isEmpty ? tag : '$current, $tag';
                    }
                  }
                });
              },
              borderRadius: BorderRadius.circular(20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isNone
                          ? MetaColors.emerald.withValues(alpha: 0.15)
                          : Colors.amber.shade900.withValues(alpha: 0.2))
                      : _cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? (isNone ? MetaColors.emerald : Colors.amber)
                        : _border,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSelected ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                      size: 13,
                      color: isSelected
                          ? (isNone ? MetaColors.emerald : Colors.amber)
                          : _textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      tag,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected
                            ? (isNone ? MetaColors.emerald : Colors.amber)
                            : _textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _restrictionsCtrl,
          maxLines: 2,
          style: TextStyle(color: _textPrimary),
          decoration: _inputDecoration(
            context,
            'Detalhes das Restrições (Opcional)',
            prefixIcon: Icons.health_and_safety_outlined,
            hint: 'Ex: Evitar supino reto livre devido a impacto no ombro',
          ),
        ),
      ],
    );
  }

  Widget _buildStudentAnamnesisXRayCard() {
    final student = _selectedIndividualStudent;
    if (student == null) return const SizedBox.shrink();

    final name = student['full_name'] as String? ?? 'Aluno';
    final anamnesis = _selectedStudentAnamnesis;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: anamnesis != null
              ? MetaColors.emerald.withValues(alpha: 0.35)
              : Colors.amber.shade700.withValues(alpha: 0.35),
          width: 1.2,
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
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: (anamnesis != null ? MetaColors.emerald : Colors.amber)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      anamnesis != null ? Icons.health_and_safety_rounded : Icons.pending_actions_rounded,
                      color: anamnesis != null ? MetaColors.emerald : Colors.amber,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Raio-X da Anamnese • $name',
                            style: TextStyle(
                              color: _textPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 13.5,
                            ),
                          ),
                          if (anamnesis != null) ...[
                            const SizedBox(width: 5),
                            const Icon(Icons.verified_rounded, size: 14, color: MetaColors.emerald),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        anamnesis != null
                            ? 'Auto-hidratado • Atualizado em ${_formatDate(anamnesis['created_at']?.toString())}'
                            : 'Anamnese pendente no aplicativo do aluno',
                        style: TextStyle(
                          color: anamnesis != null ? MetaColors.emerald : Colors.amber,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (_isLoadingAnamnesis)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: MetaColors.emerald),
                ),
            ],
          ),
          const SizedBox(height: 14),

          if (anamnesis != null) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (anamnesis['weight'] != null)
                  _buildXRayBadge(
                    icon: Icons.monitor_weight_outlined,
                    label: '${anamnesis['weight']} kg',
                    color: MetaColors.emerald,
                  ),
                if (anamnesis['height'] != null)
                  _buildXRayBadge(
                    icon: Icons.height_rounded,
                    label: '${anamnesis['height']} cm',
                    color: _textSecondary,
                  ),
                if (anamnesis['training_level'] != null)
                  _buildXRayBadge(
                    icon: Icons.bolt_rounded,
                    label: '${anamnesis['training_level']}',
                    color: const Color(0xFF38BDF8),
                  ),
                if (anamnesis['session_duration'] != null)
                  _buildXRayBadge(
                    icon: Icons.schedule_rounded,
                    label: '${anamnesis['session_duration']}',
                    color: _textSecondary,
                  ),
                if (anamnesis['sleep_hours'] != null)
                  _buildXRayBadge(
                    icon: Icons.bedtime_outlined,
                    label: 'Sono ${anamnesis['sleep_hours']}',
                    color: _textSecondary,
                  ),
                _buildInjuriesBadge(anamnesis),
              ],
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () => _showFullAnamnesisBottomSheet(anamnesis),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _highlight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.visibility_outlined, size: 15, color: MetaColors.emerald),
                        SizedBox(width: 8),
                        Text(
                          'Ver Detalhes Clínicos & Respostas Completas',
                          style: TextStyle(
                            color: _textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Icon(Icons.chevron_right_rounded, size: 16, color: _textSecondary),
                  ],
                ),
              ),
            ),
          ] else ...[
            Text(
              'O aluno ainda não respondeu as 5 etapas da anamnese expandida. '
              'Você pode prescrever usando seus próprios parâmetros ou solicitar a resposta agora.',
              style: TextStyle(color: _textSecondary, fontSize: 12, height: 1.35),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.chat_outlined, size: 15, color: MetaColors.emerald),
                    label: const Text(
                      'Cobrar Anamnese no WhatsApp',
                      style: TextStyle(color: MetaColors.emerald, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      side: const BorderSide(color: MetaColors.emerald),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _openWhatsAppReminder(student),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildXRayBadge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildInjuriesBadge(Map<String, dynamic> anamnesis) {
    final inj = (anamnesis['injuries_summary'] ?? (anamnesis['injuries'] as List?)?.join(', ') ?? '').toString();
    final hasPain = inj.isNotEmpty && !inj.toLowerCase().contains('nenhuma');
    final color = hasPain ? Colors.amber.shade600 : MetaColors.emerald;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(hasPain ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            hasPain ? 'Atenção: $inj' : 'Sem Restrições Articulares',
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  void _showFullAnamnesisBottomSheet(Map<String, dynamic> anamnesis) {
    final details = (anamnesis['details'] as Map<String, dynamic>?) ?? {};
    final student = _selectedIndividualStudent;
    final name = student?['full_name'] as String? ?? 'Aluno';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollCtrl) {
            return Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: MetaColors.subtext(context).withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Anamnese Completa • $name',
                            style: TextStyle(
                              color: _textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Respondida em ${_formatDate(anamnesis['created_at']?.toString())}',
                            style: const TextStyle(color: MetaColors.emerald, fontSize: 12),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: _textSecondary),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                Divider(color: _border, height: 1),
                Expanded(
                  child: ListView(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.all(20),
                    children: [
                      _buildModalSectionTitle('1. Biometria & Recuperação'),
                      _buildModalDataRow('Sexo Biológico', anamnesis['biological_sex'] ?? details['biological_sex'] ?? 'Não informado'),
                      _buildModalDataRow('Idade', '${anamnesis['age'] ?? details['age'] ?? "--"} anos'),
                      _buildModalDataRow('Peso / Altura', '${anamnesis['weight'] ?? details['weight'] ?? "--"} kg • ${anamnesis['height'] ?? details['height'] ?? "--"} cm'),
                      _buildModalDataRow('Atividade Diária', anamnesis['daily_activity'] ?? details['daily_activity'] ?? 'Sedentário'),
                      _buildModalDataRow('Sono / Estresse', '${anamnesis['sleep_hours'] ?? details['sleep_hours'] ?? "7-8h"} • Estresse: ${anamnesis['stress_level'] ?? details['stress_level'] ?? "Normal"}'),
                      const SizedBox(height: 16),

                      _buildModalSectionTitle('2. Rotina de Treino & Cardio'),
                      _buildModalDataRow('Nível de Treino', anamnesis['training_level'] ?? details['training_level'] ?? 'Intermediário'),
                      _buildModalDataRow('Frequência', '${anamnesis['weekly_days'] ?? details['weekly_days'] ?? "4"} dias por semana'),
                      _buildModalDataRow('Dias Preferidos', (anamnesis['preferred_days'] ?? details['preferred_days'] as List?)?.join(', ') ?? 'Não especificado'),
                      _buildModalDataRow('Duração da Sessão', anamnesis['session_duration'] ?? details['session_duration'] ?? '60 min'),
                      _buildModalDataRow('Cardio', anamnesis['cardio_preference'] ?? details['cardio_preference'] ?? 'Não especificado'),
                      const SizedBox(height: 16),

                      _buildModalSectionTitle('3. Saúde Articular & Limitações'),
                      _buildModalDataRow('Condições Médicas', (details['clinical_conditions'] as List?)?.join(', ') ?? 'Nenhuma restrição médica'),
                      _buildModalDataRow('Lesões / Dores', anamnesis['injuries_summary'] ?? (anamnesis['injuries'] as List?)?.join(', ') ?? 'Nenhuma restrição articular'),
                      if (details['injuries_details'] != null && details['injuries_details'].toString().isNotEmpty)
                        _buildModalDataRow('Detalhe da Dor', details['injuries_details'].toString()),
                      const SizedBox(height: 16),

                      _buildModalSectionTitle('4. Espaço & Equipamentos'),
                      _buildModalDataRow('Local de Treino', anamnesis['workout_location'] ?? details['workout_location'] ?? 'Academia completa'),
                      _buildModalDataRow('Equipamentos', (anamnesis['available_equipment'] ?? details['available_equipment'] as List?)?.join(', ') ?? 'Completo'),
                      if (anamnesis['exercises_to_avoid'] != null && anamnesis['exercises_to_avoid'].toString().isNotEmpty)
                        _buildModalDataRow('Exercícios a Evitar', anamnesis['exercises_to_avoid'].toString()),
                      const SizedBox(height: 16),

                      _buildModalSectionTitle('5. Metas Estéticas & Estilo'),
                      _buildModalDataRow('Objetivo Principal', anamnesis['objective'] ?? details['objective'] ?? 'Hipertrofia Muscular'),
                      _buildModalDataRow('Focos Musculares', (anamnesis['muscle_priorities'] ?? details['muscle_priorities'] as List?)?.join(', ') ?? 'Geral / Equilibrado'),
                      _buildModalDataRow('Estilo de Treino', anamnesis['training_style'] ?? details['training_style'] ?? 'Equilibrado'),
                      const SizedBox(height: 24),

                      SquircleButton(
                        label: 'Fechar Detalhes',
                        icon: Icons.check_rounded,
                        isPrimary: true,
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildModalSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: MetaColors.emerald,
          fontWeight: FontWeight.bold,
          fontSize: 13,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildModalDataRow(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _highlight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(color: _textSecondary, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: _textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? isoString) {
    if (isoString == null || isoString.isEmpty) return 'Recente';
    try {
      final dt = DateTime.parse(isoString);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return 'Recente';
    }
  }

  Widget _buildForm() {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Form(
      key: _formKey,
      child: ListView(
        padding: EdgeInsets.only(
          left: 18,
          right: 18,
          top: 16,
          bottom: bottomInset + 30,
        ),
        children: [
          // 1. Destinatário da Periodização (no topo!)
          _buildDispatchSection(context),
          const SizedBox(height: 16),

          // 2. Raio-X da Anamnese (se for individual)
          if (_dispatchMode == StudentDispatchMode.individual)
            _buildStudentAnamnesisXRayCard(),

          // 3. Parâmetros de Prescrição Auto-Hidratados
          _buildObjectiveSelector(),
          const SizedBox(height: 20),
          _buildLevelSelector(),
          const SizedBox(height: 20),
          _buildDaysPerWeekSelector(),
          const SizedBox(height: 20),
          _buildLocationSelector(),
          const SizedBox(height: 20),
          _buildSplitTypeSelector(),
          const SizedBox(height: 20),
          _buildTargetFocusSelector(),
          const SizedBox(height: 20),
          _buildRestrictionsSection(),
          const SizedBox(height: 20),
          TextFormField(
            controller: _notesCtrl,
            maxLines: 2,
            style: TextStyle(color: _textPrimary),
            decoration: _inputDecoration(
              context,
              'Observações / Foco do Treinador',
              prefixIcon: Icons.edit_note_rounded,
              hint: 'Ex: Dar ênfase a peitoral superior e deltoides',
            ),
          ),
          const SizedBox(height: 24),
          Builder(
            builder: (ctx) {
              final selectedStudent = _selectedIndividualStudent;
              final isPendingIndividual = _dispatchMode == StudentDispatchMode.individual &&
                  _isStudentPending(selectedStudent);
              final hasPendingInMultiple = _dispatchMode == StudentDispatchMode.multiple &&
                  _selectedMultipleStudentIds.any((id) {
                    final st = _students.firstWhere((s) => s['id'] == id, orElse: () => {});
                    return _isStudentPending(st);
                  });
              final isBlockedByPending = isPendingIndividual || hasPendingInMultiple;

              return SquircleButton(
                icon: isBlockedByPending ? Icons.lock_clock_rounded : Icons.auto_awesome,
                label: isBlockedByPending
                    ? (isPendingIndividual
                        ? 'Aguardando Ativação de ${selectedStudent?['full_name'] ?? 'Aluno'}'
                        : 'Remova Alunos Pendentes para Gerar')
                    : (_dispatchMode == StudentDispatchMode.individual
                        ? (selectedStudent != null
                            ? 'Gerar para ${selectedStudent['full_name']}'
                            : 'Gerar Individual')
                        : (_selectedMultipleStudentIds.isNotEmpty
                            ? 'Gerar para ${_selectedMultipleStudentIds.length} Alunos'
                            : 'Gerar para Vários')),
                isPrimary: !isBlockedByPending,
                foregroundColor: isBlockedByPending ? const Color(0xFFF59E0B) : Colors.black,
                onPressed: isBlockedByPending
                    ? () {
                        final pendingList = isPendingIndividual && selectedStudent != null
                            ? [selectedStudent]
                            : _students
                                .where((s) =>
                                    _selectedMultipleStudentIds.contains(s['id']) &&
                                    _isStudentPending(s))
                                .toList();
                        _showPendingStudentWarningDialog(pendingList);
                      }
                    : _handleGenerate,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDispatchSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
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
                      'DESTINATÁRIOS DO TREINO',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w700,
                        color: MetaColors.emerald,
                      ),
                    ),
                    Text(
                      'Modo de Envio & Atribuição',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _textPrimary,
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
              color: _highlight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
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
              color: isSelected ? Colors.black : _textSecondary,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? Colors.black : _textPrimary,
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
                  color: isSelected ? Colors.black : _textSecondary,
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
          'Selecione o aluno que receberá esta prescrição exclusiva:',
          style: TextStyle(fontSize: 12, color: _textSecondary),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _students.any((s) => s['id'] == _selectedIndividualStudentId) ? _selectedIndividualStudentId : null,
          dropdownColor: _cardBg,
          style: TextStyle(color: _textPrimary, fontSize: 13),
          isExpanded: true,
          decoration: _inputDecoration(
            context,
            'Aluno Destinatário',
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
              color: _highlight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
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
                        color: _textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Builder(
                      builder: (_) {
                        final isPending = _isStudentPending(selectedStudent);
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isPending
                                ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                                : AppColors.emeraldBg(context),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isPending
                                ? 'Pendente'
                                : (selectedStudent['status'] as String? ?? 'Ativo'),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isPending
                                  ? const Color(0xFFF59E0B)
                                  : MetaColors.emerald,
                            ),
                          ),
                        );
                      },
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
                          'Restrição no cadastro: ${selectedStudent['injuries_or_restrictions']}',
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
          if (_isStudentPending(selectedStudent)) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.lock_clock_rounded,
                        color: Color(0xFFF59E0B),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Aguardando Ativação do Convite',
                          style: const TextStyle(
                            color: Color(0xFFF59E0B),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${selectedStudent['full_name']} ainda não concluiu o cadastro no app. Para proteger seus créditos e garantir dados precisos, a prescrição com IA será liberada assim que o aluno ativar a conta.',
                    style: TextStyle(
                      color: _textSecondary,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: SquircleButton(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: 'Lembrar Aluno no WhatsApp',
                      isPrimary: false,
                      foregroundColor: const Color(0xFFF59E0B),
                      onPressed: () => _openWhatsAppReminder(selectedStudent),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
                    color: _textSecondary,
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
                            isSelected ? Colors.black : _textPrimary,
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
                                  : _textPrimary,
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
                      if (_isStudentPending(st)) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.black26
                                : const Color(0xFFF59E0B).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Pendente',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.black : const Color(0xFFF59E0B),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  backgroundColor: _highlight,
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
                    'A mesma periodização será sincronizada para os ${_selectedMultipleStudentIds.length} alunos selecionados.',
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
              'Nenhum aluno cadastrado ainda. A periodização poderá ser salva e vinculada posteriormente.',
              style: TextStyle(fontSize: 12, color: _textPrimary),
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

        // Retorna para a tela anterior (ex: detalhes do aluno) notificando sucesso
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted && Navigator.canPop(context)) {
            Navigator.pop(context, true);
          }
        });
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
            decoration: BoxDecoration(
              color: _cardBg,
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
                          color: _textPrimary,
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
                InkWell(
                  onTap: () {
                    setState(() {
                      _isClinicalNotesExpanded = !_isClinicalNotesExpanded;
                    });
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: _highlight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.lightbulb_outline_rounded,
                              size: 15,
                              color: MetaColors.emerald,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Diretriz Clínica do Treinador',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: _textPrimary,
                                ),
                              ),
                            ),
                            Text(
                              _isClinicalNotesExpanded
                                  ? 'Ocultar'
                                  : 'Ver diretriz',
                              style: const TextStyle(
                                fontSize: 11,
                                color: MetaColors.emerald,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              _isClinicalNotesExpanded
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              size: 16,
                              color: MetaColors.emerald,
                            ),
                          ],
                        ),
                        if (_isClinicalNotesExpanded) ...[
                          const SizedBox(height: 6),
                          Text(
                            plan.notesForTrainer,
                            style: TextStyle(
                              fontSize: 12,
                              color: _textSecondary,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _highlight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _border),
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
                                  ? 'Destinatário Individual'
                                  : 'Destinatários em Lote (${_selectedMultipleStudentIds.length} alunos)',
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
                                color: _textPrimary,
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
            unselectedLabelColor: _textSecondary,
            indicatorWeight: 3,
            labelPadding: const EdgeInsets.symmetric(horizontal: 18),
            tabs:
                plan.splits
                    .map(
                      (s) => Tab(
                        text: 'Treino ${s.splitIdentifier}',
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
                  itemCount: split.exercises.length + 2,
                  itemBuilder: (ctx, i) {
                    if (i == 0) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: _highlight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: AppColors.emeraldBg(context),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.fitness_center_rounded,
                                size: 15,
                                color: MetaColors.emerald,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Treino ${split.splitIdentifier}: ${split.splitName}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: _textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    '${split.exercises.length} exercícios • ~${split.estimatedDurationMin} min estimados',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: _textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final exerciseIndex = i - 1;
                    // BOTÃO INCLUIR NOVO EXERCÍCIO AO FINAL DO SPLIT
                    if (exerciseIndex == split.exercises.length) {
                      return Container(
                        margin: const EdgeInsets.only(top: 8, bottom: 24),
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(
                            Icons.add_circle_outline_rounded,
                            color: MetaColors.emerald,
                            size: 18,
                          ),
                          label: Text(
                            'Incluir Novo Exercício no Treino ${split.splitIdentifier}',
                            style: const TextStyle(
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

                    final ex = split.exercises[exerciseIndex];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _border,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
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
                                    '${exerciseIndex + 1}',
                                    style: const TextStyle(
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
                                        fontSize: 14.5,
                                        color: _textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      ex.targetMuscleGroup,
                                      style: TextStyle(
                                        color: _textSecondary,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.play_circle_fill_rounded,
                                  size: 24,
                                ),
                                color: MetaColors.emerald,
                                tooltip: 'Ver demonstração in-app',
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.all(4),
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                                onPressed:
                                    () => ExerciseMediaSheet.show(
                                      context,
                                      exerciseName: ex.name,
                                    ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.swap_horiz_rounded,
                                  size: 20,
                                ),
                                color: _textSecondary,
                                tooltip: 'Substituir exercício',
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.all(4),
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                                onPressed:
                                    () => _showSwapExerciseDialog(
                                      splitIndex,
                                      exerciseIndex,
                                      ex,
                                    ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 19,
                                ),
                                color: Colors.red.shade400,
                                tooltip: 'Remover exercício',
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.all(4),
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                                onPressed:
                                    () => _confirmRemoveExercise(
                                      splitIndex,
                                      exerciseIndex,
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
                                  color: _textSecondary,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          // CONTROLES DE AJUSTE RÁPIDO: SÉRIES, REPS, DESCANSO
                          Row(
                            children: [
                              _buildParamStepper(
                                label: 'Séries',
                                value: '${ex.sets}',
                                onDecrement:
                                    () => _updateExerciseSets(
                                      splitIndex,
                                      exerciseIndex,
                                      -1,
                                    ),
                                onIncrement:
                                    () => _updateExerciseSets(
                                      splitIndex,
                                      exerciseIndex,
                                      1,
                                    ),
                              ),
                              const SizedBox(width: 8),
                              _buildParamStepper(
                                label: 'Reps',
                                value: ex.reps,
                                onDecrement:
                                    () => _cycleExerciseReps(
                                      splitIndex,
                                      exerciseIndex,
                                      -1,
                                    ),
                                onIncrement:
                                    () => _cycleExerciseReps(
                                      splitIndex,
                                      exerciseIndex,
                                      1,
                                    ),
                                onTapValue:
                                    () => _editRepsDirectly(
                                      splitIndex,
                                      exerciseIndex,
                                      ex.reps,
                                    ),
                              ),
                              const SizedBox(width: 8),
                              _buildParamStepper(
                                label: 'Descanso',
                                value: '${ex.restSeconds}s',
                                onDecrement:
                                    () => _updateExerciseRest(
                                      splitIndex,
                                      exerciseIndex,
                                      -15,
                                    ),
                                onIncrement:
                                    () => _updateExerciseRest(
                                      splitIndex,
                                      exerciseIndex,
                                      15,
                                    ),
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
                          ? 'Aprovar e Liberar para ${_selectedIndividualStudent?['full_name'] ?? 'o Aluno'}'
                          : 'Aprovar e Liberar para ${_selectedMultipleStudentIds.length} Alunos'),
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
      backgroundColor: _cardBg,
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
                        'Destinatários da Prescrição',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _textPrimary,
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
                      color: _highlight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _border),
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
                                          : _textPrimary,
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
                                          : _textPrimary,
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
                                        : _highlight,
                                child: Text(
                                  (st['full_name'] as String? ?? 'A')[0]
                                      .toUpperCase(),
                                  style: TextStyle(
                                    color:
                                        isSel
                                            ? Colors.black
                                            : _textPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                st['full_name'] as String? ?? 'Aluno',
                                style: TextStyle(
                                  color: _textPrimary,
                                  fontWeight:
                                      isSel
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                ),
                              ),
                              subtitle: Text(
                                st['goal'] ?? st['objective'] ?? 'Consultoria',
                                style: TextStyle(
                                  color: _textSecondary,
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
                                  color: _textPrimary,
                                ),
                              ),
                              subtitle: Text(
                                st['goal'] ?? st['objective'] ?? 'Consultoria',
                                style: TextStyle(
                                  color: _textSecondary,
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
                        'Confirmar Destinatários',
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
    'Até a Falha',
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
          color: _highlight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _border),
        ),
        child: Column(
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: _textSecondary,
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
                      color: _cardBg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.cardBorder(context)),
                    ),
                    child: Icon(
                      Icons.remove,
                      size: 13,
                      color: _textPrimary,
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
                        color: _textPrimary,
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
                      color: _cardBg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.cardBorder(context)),
                    ),
                    child: Icon(
                      Icons.add,
                      size: 13,
                      color: _textPrimary,
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
            backgroundColor: _cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              'Ajustar Repetições',
              style: TextStyle(color: _textPrimary, fontSize: 16),
            ),
            content: TextField(
              controller: ctrl,
              autofocus: true,
              style: TextStyle(color: _textPrimary),
              decoration: InputDecoration(
                hintText: 'Ex: 10-12, 4x8, Até a falha',
                filled: true,
                fillColor: _highlight,
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
                  style: TextStyle(color: _textSecondary),
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
            backgroundColor: _cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              'Remover Exercício?',
              style: TextStyle(color: _textPrimary),
            ),
            content: Text(
              'Deseja remover "$exerciseName" desta divisão?',
              style: TextStyle(color: _textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'Cancelar',
                  style: TextStyle(color: _textSecondary),
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

  void _swapExercise(
    int splitIndex,
    int exerciseIndex,
    ExerciseModel newExercise,
  ) {
    if (_generatedPlan == null) return;
    final splits = List<SplitModel>.from(_generatedPlan!.splits);
    final split = splits[splitIndex];
    final exercises = List<ExerciseModel>.from(split.exercises);
    exercises[exerciseIndex] = newExercise.copyWith(order: exerciseIndex + 1);
    splits[splitIndex] = split.copyWith(exercises: exercises);
    setState(() {
      _generatedPlan = _generatedPlan!.copyWith(splits: splits);
    });
  }

  void _showSwapExerciseDialog(
    int splitIndex,
    int exerciseIndex,
    ExerciseModel currentEx,
  ) {
    if (_generatedPlan == null) return;
    final split = _generatedPlan!.splits[splitIndex];

    final nameCtrl = TextEditingController(text: currentEx.name);
    final notesCtrl = TextEditingController(text: currentEx.notes);
    String selectedMuscle =
        currentEx.targetMuscleGroup.isNotEmpty
            ? currentEx.targetMuscleGroup
            : 'Peitoral';
    int sets = currentEx.sets;
    String reps = currentEx.reps;
    int restSeconds = currentEx.restSeconds;

    const muscleOptions = [
      'Peitoral',
      'Dorsais / Costas',
      'Deltoides / Ombros',
      'Quadríceps',
      'Posterior de Coxa',
      'Glúteos',
      'Bíceps',
      'Tríceps',
      'Panturrilhas',
      'Abdômen / Core',
      'Geral',
    ];

    const suggestions = [
      'Supino Inclinado com Halteres',
      'Puxada Alta (Lat Pulldown)',
      'Elevação Lateral na Polia',
      'Agachamento Búlgaro',
      'Leg Press 45°',
      'Cadeira Extensora',
      'Tríceps na Polia com Corda',
      'Rosca Direta com Barra W',
      'Mesa Flexora',
      'Elevação Pélvica',
      'Crucifixo Reto com Halteres',
      'Remada Curvada com Barra',
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: _cardBg,
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
                            const Icon(
                              Icons.swap_horiz_rounded,
                              color: MetaColors.emerald,
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Substituir Exercício',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _textPrimary,
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
                    const SizedBox(height: 4),
                    Text(
                      'Substituindo "${currentEx.name}" no Treino ${split.splitIdentifier}',
                      style: TextStyle(
                        fontSize: 12,
                        color: _textSecondary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: nameCtrl,
                      style: TextStyle(color: _textPrimary),
                      decoration: _inputDecoration(
                        context,
                        'Novo Nome do Exercício',
                        prefixIcon: Icons.fitness_center_rounded,
                        hint: 'Ex: Supino Inclinado com Halteres',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children:
                          suggestions.take(6).map((sug) {
                            return ActionChip(
                              label: Text(
                                sug,
                                style: const TextStyle(fontSize: 10),
                              ),
                              backgroundColor: _highlight,
                              side: BorderSide(
                                color: _border,
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
                      initialValue:
                          muscleOptions.contains(selectedMuscle)
                              ? selectedMuscle
                              : 'Peitoral',
                      dropdownColor: _cardBg,
                      style: TextStyle(
                        color: _textPrimary,
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
                        if (val != null) {
                          setModalState(() => selectedMuscle = val);
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _highlight,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _border,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'SÉRIES',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: _textSecondary,
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
                                        color: _textPrimary,
                                      ),
                                    ),
                                    Text(
                                      '$sets',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: _textPrimary,
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
                                        color: _textPrimary,
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
                              color: _highlight,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _border,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'REPETIÇÕES',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: _textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                DropdownButton<String>(
                                  value:
                                      _commonRepRanges.contains(reps)
                                          ? reps
                                          : '10-12',
                                  dropdownColor: _cardBg,
                                  underline: const SizedBox(),
                                  isDense: true,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: _textPrimary,
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
                                    if (val != null) {
                                      setModalState(() => reps = val);
                                    }
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
                              color: _highlight,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _border,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'DESCANSO',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: _textSecondary,
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
                                        color: _textPrimary,
                                      ),
                                    ),
                                    Text(
                                      '${restSeconds}s',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: _textPrimary,
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
                                        color: _textPrimary,
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
                        color: _textPrimary,
                        fontSize: 13,
                      ),
                      decoration: _inputDecoration(
                        context,
                        'Notas de Execução / Ajuste',
                        prefixIcon: Icons.notes_rounded,
                        hint: 'Ex: Movimento controlado sem impulso',
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(
                          Icons.check_rounded,
                          color: Colors.black,
                        ),
                        label: const Text(
                          'Confirmar Substituição',
                          style: TextStyle(
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

                          final updatedExercise = currentEx.copyWith(
                            name: name,
                            targetMuscleGroup: selectedMuscle,
                            sets: sets,
                            reps: reps,
                            restSeconds: restSeconds,
                            notes: notesCtrl.text.trim(),
                          );

                          _swapExercise(
                            splitIndex,
                            exerciseIndex,
                            updatedExercise,
                          );
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
      'Quadríceps',
      'Posterior de Coxa',
      'Glúteos',
      'Bíceps',
      'Tríceps',
      'Panturrilhas',
      'Abdômen / Core',
      'Geral',
    ];

    const suggestions = [
      'Supino Inclinado com Halteres',
      'Puxada Alta (Lat Pulldown)',
      'Elevação Lateral na Polia',
      'Agachamento Búlgaro',
      'Leg Press 45°',
      'Cadeira Extensora',
      'Tríceps na Polia com Corda',
      'Rosca Direta com Barra W',
      'Mesa Flexora',
      'Elevação Pélvica',
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: _cardBg,
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
                              'Novo Exercício • Treino ${split.splitIdentifier}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _textPrimary,
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
                      style: TextStyle(color: _textPrimary),
                      decoration: _inputDecoration(
                        context,
                        'Nome do Exercício',
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
                              backgroundColor: _highlight,
                              side: BorderSide(
                                color: _border,
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
                      dropdownColor: _cardBg,
                      style: TextStyle(
                        color: _textPrimary,
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
                        if (val != null) {
                          setModalState(() => selectedMuscle = val);
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _highlight,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _border,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'SÉRIES',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: _textSecondary,
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
                                        color: _textPrimary,
                                      ),
                                    ),
                                    Text(
                                      '$sets',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: _textPrimary,
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
                                        color: _textPrimary,
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
                              color: _highlight,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _border,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'REPETIÇÕES',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: _textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                DropdownButton<String>(
                                  value:
                                      _commonRepRanges.contains(reps)
                                          ? reps
                                          : '10-12',
                                  dropdownColor: _cardBg,
                                  underline: const SizedBox(),
                                  isDense: true,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: _textPrimary,
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
                                    if (val != null) {
                                      setModalState(() => reps = val);
                                    }
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
                              color: _highlight,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _border,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'DESCANSO',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: _textSecondary,
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
                                        color: _textPrimary,
                                      ),
                                    ),
                                    Text(
                                      '${restSeconds}s',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: _textPrimary,
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
                                        color: _textPrimary,
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
                        color: _textPrimary,
                        fontSize: 13,
                      ),
                      decoration: _inputDecoration(
                        context,
                        'Diretriz / Notas de Execução (Opcional)',
                        prefixIcon: Icons.notes_rounded,
                        hint: 'Ex: Cadência 3-0-1-0 com pico de contração',
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









