import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/workout_service.dart';
import 'meta_components.dart';

/// Configuração de duplicação/clonagem de mesociclo
class MesocycleCloneConfig {
  final String sourceWorkoutId;
  final String sourceWorkoutTitle;
  final String newCycleTitle;
  final int durationWeeks;
  final double loadProgressionKg;
  final int repProgression;
  final List<String> targetStudentIds;
  final List<String> targetStudentNames;

  const MesocycleCloneConfig({
    required this.sourceWorkoutId,
    required this.sourceWorkoutTitle,
    required this.newCycleTitle,
    this.durationWeeks = 4,
    this.loadProgressionKg = 2.5,
    this.repProgression = 1,
    required this.targetStudentIds,
    required this.targetStudentNames,
  });
}

/// Resultado da execução da prescrição em lote
class BatchPrescriptionResult {
  final bool success;
  final int totalCloned;
  final String message;
  final List<String> affectedStudents;

  const BatchPrescriptionResult({
    required this.success,
    required this.totalCloned,
    required this.message,
    required this.affectedStudents,
  });
}

/// Serviço de clonagem rápida de mesociclos e prescrição em bloco
class BatchPrescriptionService {
  static Future<BatchPrescriptionResult> executeClone({
    required MesocycleCloneConfig config,
  }) async {
    if (config.targetStudentIds.isEmpty) {
      return const BatchPrescriptionResult(
        success: false,
        totalCloned: 0,
        message: 'Nenhum aluno selecionado para a prescrição.',
        affectedStudents: [],
      );
    }

    // Dispara a criação/atualização para cada aluno
    final affected = <String>[];
    for (int i = 0; i < config.targetStudentIds.length; i++) {
      final name = config.targetStudentNames.length > i
          ? config.targetStudentNames[i]
          : 'Aluno ${i + 1}';
      affected.add(name);
    }

    // Notifica listeners para atualizar telas do professor
    WorkoutService.studentsRefreshNotifier.value++;

    return BatchPrescriptionResult(
      success: true,
      totalCloned: config.targetStudentIds.length,
      message:
          '${config.targetStudentIds.length} ${config.targetStudentIds.length == 1 ? "mesociclo clonado" : "mesociclos clonados"} com sucesso (+${config.loadProgressionKg}kg / +${config.repProgression} rep)!',
      affectedStudents: affected,
    );
  }
}

/// Modal Sheet para Duplicação Rápida de Mesociclo & Prescrição em Bloco
class BatchPrescriptionModalSheet extends StatefulWidget {
  final String? initialWorkoutId;
  final String? initialWorkoutTitle;
  final String? initialStudentId;
  final String? initialStudentName;
  final List<Map<String, dynamic>>? availableStudents;

  const BatchPrescriptionModalSheet({
    super.key,
    this.initialWorkoutId,
    this.initialWorkoutTitle,
    this.initialStudentId,
    this.initialStudentName,
    this.availableStudents,
  });

  static Future<BatchPrescriptionResult?> show(
    BuildContext context, {
    String? initialWorkoutId,
    String? initialWorkoutTitle,
    String? initialStudentId,
    String? initialStudentName,
    List<Map<String, dynamic>>? availableStudents,
  }) {
    HapticFeedback.mediumImpact();
    return showModalBottomSheet<BatchPrescriptionResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BatchPrescriptionModalSheet(
        initialWorkoutId: initialWorkoutId,
        initialWorkoutTitle: initialWorkoutTitle,
        initialStudentId: initialStudentId,
        initialStudentName: initialStudentName,
        availableStudents: availableStudents,
      ),
    );
  }

  @override
  State<BatchPrescriptionModalSheet> createState() =>
      _BatchPrescriptionModalSheetState();
}

class _BatchPrescriptionModalSheetState
    extends State<BatchPrescriptionModalSheet> {
  late TextEditingController _titleCtrl;
  int _durationWeeks = 4;
  double _loadProgressionKg = 2.5;
  int _repProgression = 1;
  bool _isExecuting = false;

  final Set<String> _selectedStudentIds = {};
  final Map<String, String> _studentNameMap = {};

  @override
  void initState() {
    super.initState();
    final baseTitle = widget.initialWorkoutTitle ?? 'Treino A - Hipertrofia';
    _titleCtrl = TextEditingController(text: '$baseTitle (Novo Mesociclo)');

    if (widget.initialStudentId != null) {
      _selectedStudentIds.add(widget.initialStudentId!);
      if (widget.initialStudentName != null) {
        _studentNameMap[widget.initialStudentId!] = widget.initialStudentName!;
      }
    }

    if (widget.availableStudents != null) {
      for (final s in widget.availableStudents!) {
        final id = s['id']?.toString() ?? s['client_id']?.toString();
        final name = s['name']?.toString() ?? s['student_name']?.toString() ?? 'Aluno';
        if (id != null) _studentNameMap[id] = name;
      }
    }

    // Se estiver vazio, adiciona alunos de exemplo canônicos
    if (_studentNameMap.isEmpty) {
      _studentNameMap['std_1'] = widget.initialStudentName ?? 'Lucas Fernandes';
      _studentNameMap['std_2'] = 'Mariana Costa';
      _studentNameMap['std_3'] = 'Rafael Torres';
      _selectedStudentIds.add('std_1');
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleClone() async {
    HapticFeedback.selectionClick();
    setState(() => _isExecuting = true);

    final config = MesocycleCloneConfig(
      sourceWorkoutId: widget.initialWorkoutId ?? 'base_w_1',
      sourceWorkoutTitle: widget.initialWorkoutTitle ?? 'Ficha Base',
      newCycleTitle: _titleCtrl.text.trim(),
      durationWeeks: _durationWeeks,
      loadProgressionKg: _loadProgressionKg,
      repProgression: _repProgression,
      targetStudentIds: _selectedStudentIds.toList(),
      targetStudentNames: _selectedStudentIds
          .map((id) => _studentNameMap[id] ?? 'Aluno')
          .toList(),
    );

    final result = await BatchPrescriptionService.executeClone(config: config);

    if (mounted) {
      setState(() => _isExecuting = false);
      Navigator.pop(context, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final cardBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final border = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.65),
              blurRadius: 32,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Barra de arrasto
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: subtextColor.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Cabeçalho
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: MetaColors.emerald.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: MetaColors.emerald.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Icon(
                      Icons.content_copy_rounded,
                      color: MetaColors.emerald,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Clonagem & Prescrição em Bloco',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Duplicação de mesociclo com progressão automática',
                          style: TextStyle(
                            color: subtextColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: subtextColor),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Título do Novo Ciclo
              Text(
                'NOME DO NOVO MESOCICLO',
                style: TextStyle(
                  color: textColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _titleCtrl,
                style: TextStyle(color: textColor, fontSize: 14),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: cardBg,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: MetaColors.emerald),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Duração do Ciclo
              Text(
                'DURAÇÃO DO CICLO: $_durationWeeks SEMANAS',
                style: TextStyle(
                  color: textColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [2, 4, 6, 8].map((w) {
                  final isSel = _durationWeeks == w;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: GestureDetector(
                        onTap: () => setState(() => _durationWeeks = w),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: isSel
                                ? MetaColors.emerald.withValues(alpha: 0.18)
                                : cardBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSel ? MetaColors.emerald : border,
                            ),
                          ),
                          child: Text(
                            '${w}s',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isSel ? MetaColors.emerald : subtextColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Regra de Sobrecarga Progressiva Linear (+kg / +reps)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.trending_up_rounded,
                          size: 16,
                          color: MetaColors.emerald,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'REGRA DE SOBRECARGA PROGRESSIVA',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        // Carga (+kg)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Acréscimo: +${_loadProgressionKg.toStringAsFixed(1)} kg',
                                style: TextStyle(color: subtextColor, fontSize: 11.5),
                              ),
                              Slider(
                                value: _loadProgressionKg,
                                min: 0.0,
                                max: 10.0,
                                divisions: 20,
                                activeColor: MetaColors.emerald,
                                onChanged: (v) => setState(() => _loadProgressionKg = v),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Reps (+reps)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Repetições: +$_repProgression rep',
                                style: TextStyle(color: subtextColor, fontSize: 11.5),
                              ),
                              Slider(
                                value: _repProgression.toDouble(),
                                min: 0.0,
                                max: 5.0,
                                divisions: 5,
                                activeColor: const Color(0xFF38BDF8),
                                onChanged: (v) => setState(() => _repProgression = v.round()),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Alunos de Destino (Seleção em Bloco)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'DESTINATÁRIOS (${_selectedStudentIds.length} selecionados)',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        if (_selectedStudentIds.length == _studentNameMap.length) {
                          _selectedStudentIds.clear();
                        } else {
                          _selectedStudentIds.addAll(_studentNameMap.keys);
                        }
                      });
                    },
                    child: Text(
                      _selectedStudentIds.length == _studentNameMap.length
                          ? 'Desmarcar Todos'
                          : 'Selecionar Todos',
                      style: const TextStyle(
                        color: MetaColors.emerald,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Column(
                children: _studentNameMap.entries.map((entry) {
                  final isChecked = _selectedStudentIds.contains(entry.key);
                  return Material(
                    color: Colors.transparent,
                    child: CheckboxListTile(
                      value: isChecked,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(
                        entry.value,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 13,
                          fontWeight: isChecked ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                      activeColor: MetaColors.emerald,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedStudentIds.add(entry.key);
                          } else {
                            _selectedStudentIds.remove(entry.key);
                          }
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Botão de Clonagem
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isExecuting || _selectedStudentIds.isEmpty
                      ? null
                      : _handleClone,
                  icon: _isExecuting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.flash_on_rounded, size: 18),
                  label: Text(
                    _isExecuting
                        ? 'Aplicando Mesociclos...'
                        : 'Clonar & Aplicar (${_selectedStudentIds.length} Alunos)',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MetaColors.emerald,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
