import 'package:flutter/material.dart';
import '../../../core/widgets/meta_components.dart';
import '../../../core/widgets/exercise_media_sheet.dart';
import '../services/admin_data_service.dart';

/// Módulo 4: Catálogo Global de Exercícios & Biomecânica
class AdminExercisesScreen extends StatefulWidget {
  const AdminExercisesScreen({super.key});

  @override
  State<AdminExercisesScreen> createState() => _AdminExercisesScreenState();
}

class _AdminExercisesScreenState extends State<AdminExercisesScreen> {
  final TextEditingController _searchCtrl = TextEditingController();

  bool _isLoading = true;
  List<AdminExerciseItem> _exercises = [];
  String _muscleFilter = 'all'; // 'all', 'Peitoral', 'Costas', 'Pernas', 'Ombros', 'Braços'
  bool _hasMediaOnly = false;

  @override
  void initState() {
    super.initState();
    _loadExercises();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExercises() async {
    setState(() => _isLoading = true);
    final list = await AdminDataService.getExercises(
      muscleFilter: _muscleFilter,
      searchQuery: _searchCtrl.text,
      hasMediaOnly: _hasMediaOnly ? true : null,
    );
    if (mounted) {
      setState(() {
        _exercises = list;
        _isLoading = false;
      });
    }
  }

  int get _withMediaCount => _exercises.where((e) => e.hasMedia).length;
  int get _withoutMediaCount => _exercises.where((e) => !e.hasMedia).length;

  void _showAddEditExerciseDialog([AdminExerciseItem? existing]) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final slugCtrl = TextEditingController(text: existing?.slug ?? '');
    final muscleCtrl = TextEditingController(text: existing?.muscleGroup ?? 'Peitoral');
    final secondaryCtrl = TextEditingController(text: existing?.secondaryMuscles ?? '');
    final equipmentCtrl = TextEditingController(text: existing?.equipment ?? 'Barra');
    final motorPatternCtrl = TextEditingController(text: existing?.motorPattern ?? '');
    final cuesCtrl = TextEditingController(text: existing?.executionCues ?? '');
    final mediaUrlCtrl = TextEditingController(text: existing?.mediaUrl ?? '');

    String selectedMuscle = ['Peitoral', 'Costas', 'Pernas', 'Ombros', 'Braços', 'Abdômen'].contains(existing?.muscleGroup)
        ? existing!.muscleGroup
        : 'Peitoral';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF111827),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF1F2937), width: 1.2),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.fitness_center_rounded, color: Color(0xFF818CF8), size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                existing == null ? 'Novo Exercício Global' : 'Editar Exercício',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildDialogTextField(
                    controller: nameCtrl,
                    label: 'Nome do Exercício',
                    hint: 'Ex: Supino Inclinado com Halteres',
                    onChanged: (val) {
                      if (existing == null) {
                        slugCtrl.text = val
                            .trim()
                            .toLowerCase()
                            .replaceAll(RegExp(r'[^\w\s]'), '')
                            .replaceAll(' ', '_');
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  // Dropdown de Grupo Muscular
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Grupo Muscular Principal', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF090D16),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF1F2937)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedMuscle,
                            dropdownColor: const Color(0xFF111827),
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            isExpanded: true,
                            items: ['Peitoral', 'Costas', 'Pernas', 'Ombros', 'Braços', 'Abdômen']
                                .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() {
                                  selectedMuscle = val;
                                  muscleCtrl.text = val;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildDialogTextField(
                    controller: secondaryCtrl,
                    label: 'Músculos Secundários (Sinergistas)',
                    hint: 'Ex: Tríceps Braquial, Deltoide Anterior',
                  ),
                  const SizedBox(height: 12),
                  _buildDialogTextField(
                    controller: equipmentCtrl,
                    label: 'Equipamento',
                    hint: 'Ex: Halteres, Barra, Polia, Máquina, Peso Corporal',
                  ),
                  const SizedBox(height: 12),
                  _buildDialogTextField(
                    controller: motorPatternCtrl,
                    label: 'Padrão Motor',
                    hint: 'Ex: Empurrar Horizontal, Dominante de Quadril',
                  ),
                  const SizedBox(height: 12),
                  _buildDialogTextField(
                    controller: mediaUrlCtrl,
                    label: 'URL da Mídia / Animação / GIF',
                    hint: 'Link Google Drive, Supabase Storage ou URL pública',
                  ),
                  const SizedBox(height: 12),
                  _buildDialogTextField(
                    controller: cuesCtrl,
                    label: 'Orientações Biomecânicas (Cues)',
                    hint: 'Dicas posturais de segurança e eficiência articular...',
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                final messenger = ScaffoldMessenger.of(context);
                final item = AdminExerciseItem(
                  id: existing?.id ?? slugCtrl.text.trim(),
                  name: nameCtrl.text.trim(),
                  slug: slugCtrl.text.trim().isNotEmpty
                      ? slugCtrl.text.trim()
                      : nameCtrl.text.trim().toLowerCase().replaceAll(' ', '_'),
                  muscleGroup: selectedMuscle,
                  secondaryMuscles: secondaryCtrl.text.trim().isNotEmpty ? secondaryCtrl.text.trim() : null,
                  equipment: equipmentCtrl.text.trim().isNotEmpty ? equipmentCtrl.text.trim() : 'Geral',
                  motorPattern: motorPatternCtrl.text.trim().isNotEmpty ? motorPatternCtrl.text.trim() : null,
                  executionCues: cuesCtrl.text.trim().isNotEmpty ? cuesCtrl.text.trim() : null,
                  mediaSource: 'custom',
                  mediaUrl: mediaUrlCtrl.text.trim(),
                  thumbnailUrl: null,
                );

                Navigator.pop(ctx);
                final success = await AdminDataService.upsertExercise(item);
                if (success) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Exercício salvo com sucesso na biblioteca global!'),
                      backgroundColor: MetaColors.emerald,
                    ),
                  );
                  _loadExercises();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Salvar Exercício'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          onChanged: onChanged,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
            filled: true,
            fillColor: const Color(0xFF090D16),
            contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF1F2937)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF1F2937)),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      body: RefreshIndicator(
        onRefresh: _loadExercises,
        color: const Color(0xFF6366F1),
        backgroundColor: const Color(0xFF111827),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 768 ? 16 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header do Módulo
              LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 700;

                  final titleBlock = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Row(
                        children: [
                          Icon(Icons.fitness_center_rounded, color: Color(0xFF818CF8), size: 24),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Catálogo Global de Exercícios & Biomecânica',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Curadoria de exercícios, vídeos em loop, dicas posturais e análise articular para toda a plataforma',
                        style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.3),
                      ),
                    ],
                  );

                  final addBtn = ElevatedButton.icon(
                    onPressed: () => _showAddEditExerciseDialog(),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Novo Exercício', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 4,
                    ),
                  );

                  if (isMobile) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        titleBlock,
                        const SizedBox(height: 14),
                        addBtn,
                      ],
                    );
                  }

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: titleBlock),
                      const SizedBox(width: 16),
                      addBtn,
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),

              // KPI Badges de Cobertura
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _buildCoveragePill('Total Catalogado', _exercises.length.toString(), const Color(0xFF818CF8)),
                  _buildCoveragePill('Com Demonstração/GIF', _withMediaCount.toString(), MetaColors.emerald),
                  _buildCoveragePill('Sem Mídia Vinculada', _withoutMediaCount.toString(), Colors.amber),
                ],
              ),
              const SizedBox(height: 20),

              // Barra de Busca e Filtros por Músculo
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF1F2937)),
                ),
                child: Column(
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isMobile = constraints.maxWidth < 650;
                        final searchField = TextField(
                          controller: _searchCtrl,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          onChanged: (_) => _loadExercises(),
                          decoration: InputDecoration(
                            hintText: 'Buscar por nome, equipamento ou padrão...',
                            hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                            prefixIcon: const Icon(Icons.search_rounded, color: Colors.white38, size: 20),
                            suffixIcon: _searchCtrl.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, size: 18, color: Colors.white38),
                                    onPressed: () {
                                      _searchCtrl.clear();
                                      _loadExercises();
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: const Color(0xFF090D16),
                            contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFF1F2937)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFF1F2937)),
                            ),
                          ),
                        );

                        final mediaToggle = InkWell(
                          onTap: () {
                            setState(() => _hasMediaOnly = !_hasMediaOnly);
                            _loadExercises();
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: _hasMediaOnly
                                  ? MetaColors.emerald.withValues(alpha: 0.15)
                                  : const Color(0xFF090D16),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _hasMediaOnly ? MetaColors.emerald : const Color(0xFF1F2937),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.play_circle_fill_rounded,
                                  size: 16,
                                  color: _hasMediaOnly ? MetaColors.emerald : Colors.white38,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Apenas com GIF/Vídeo',
                                  style: TextStyle(
                                    color: _hasMediaOnly ? MetaColors.emerald : Colors.white70,
                                    fontSize: 12,
                                    fontWeight: _hasMediaOnly ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );

                        if (isMobile) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              searchField,
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: mediaToggle,
                              ),
                            ],
                          );
                        }

                        return Row(
                          children: [
                            Expanded(child: searchField),
                            const SizedBox(width: 12),
                            mediaToggle,
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    // Chips de Grupo Muscular
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildMuscleChip('all', 'Todos os Grupos'),
                          const SizedBox(width: 8),
                          _buildMuscleChip('Peitoral', 'Peitoral'),
                          const SizedBox(width: 8),
                          _buildMuscleChip('Costas', 'Costas & Dorsal'),
                          const SizedBox(width: 8),
                          _buildMuscleChip('Pernas', 'Pernas & Glúteos'),
                          const SizedBox(width: 8),
                          _buildMuscleChip('Ombros', 'Ombros / Deltoides'),
                          const SizedBox(width: 8),
                          _buildMuscleChip('Braços', 'Braços (Bíceps/Tríceps)'),
                          const SizedBox(width: 8),
                          _buildMuscleChip('Abdômen', 'Abdômen & Core'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Lista de Exercícios
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(48),
                    child: CircularProgressIndicator(color: Color(0xFF6366F1)),
                  ),
                )
              else if (_exercises.isEmpty)
                Container(
                  padding: const EdgeInsets.all(48),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF1F2937)),
                  ),
                  child: Column(
                    children: const [
                      Icon(Icons.fitness_center_outlined, size: 48, color: Colors.white24),
                      SizedBox(height: 12),
                      Text(
                        'Nenhum exercício encontrado com os filtros selecionados',
                        style: TextStyle(color: Colors.white60, fontSize: 14),
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _exercises.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final ex = _exercises[index];
                    return _buildExerciseCard(ex);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCoveragePill(String title, String count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(color: Colors.white60, fontSize: 12)),
          const SizedBox(width: 8),
          Text(
            count,
            style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  Widget _buildMuscleChip(String key, String label) {
    final isSelected = _muscleFilter == key;

    return InkWell(
      onTap: () {
        setState(() => _muscleFilter = key);
        _loadExercises();
      },
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6366F1).withValues(alpha: 0.2) : const Color(0xFF090D16),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF818CF8) : const Color(0xFF1F2937),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white60,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildExerciseCard(AdminExerciseItem ex) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Miniatura de Demonstração / Player
          InkWell(
            onTap: () {
              ExerciseMediaSheet.show(context, exerciseName: ex.name);
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFF090D16),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: ex.hasMedia ? MetaColors.emerald.withValues(alpha: 0.5) : const Color(0xFF1F2937),
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (ex.hasMedia)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: Image.network(
                        ex.displayMediaUrl,
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Center(
                          child: Icon(Icons.fitness_center_rounded, color: Colors.white24, size: 26),
                        ),
                      ),
                    )
                  else
                    const Icon(Icons.videocam_off_rounded, color: Colors.white24, size: 26),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      ex.hasMedia ? Icons.play_arrow_rounded : Icons.add_link_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Informações Biomecânicas
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ex.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 6),
                // Badges de Classificação & Status de Mídia juntos no Wrap (evita esmagamento horizontal)
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Badge de Mídia
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: ex.hasMedia
                            ? MetaColors.emerald.withValues(alpha: 0.15)
                            : Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: ex.hasMedia
                              ? MetaColors.emerald.withValues(alpha: 0.4)
                              : Colors.amber.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            ex.hasMedia ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                            size: 11,
                            color: ex.hasMedia ? MetaColors.emerald : Colors.amber,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            ex.hasMedia ? 'GIF ATIVO' : 'SEM MÍDIA',
                            style: TextStyle(
                              color: ex.hasMedia ? MetaColors.emerald : Colors.amber,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildAttributeBadge(ex.muscleGroup, const Color(0xFF6366F1)),
                    _buildAttributeBadge(ex.equipment, Colors.teal),
                    if (ex.motorPattern != null)
                      _buildAttributeBadge(ex.motorPattern!, const Color(0xFF818CF8)),
                  ],
                ),
                if (ex.executionCues != null && ex.executionCues!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '💡 ${ex.executionCues}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white60, fontSize: 12, height: 1.3),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 6),

          // Ações do Card
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_rounded, size: 18, color: Color(0xFF818CF8)),
                tooltip: 'Editar Exercício',
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(),
                onPressed: () => _showAddEditExerciseDialog(ex),
              ),
              const SizedBox(height: 8),
              IconButton(
                icon: const Icon(Icons.ondemand_video_rounded, size: 18, color: MetaColors.emerald),
                tooltip: 'Testar Player In-App',
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(),
                onPressed: () => ExerciseMediaSheet.show(context, exerciseName: ex.name),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAttributeBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
