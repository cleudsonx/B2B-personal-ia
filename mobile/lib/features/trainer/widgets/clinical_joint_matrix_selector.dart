import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../models/clinical_profile_model.dart';

class ClinicalJointMatrixSelector extends StatefulWidget {
  final List<ClinicalJointRestriction> initialRestrictions;
  final ValueChanged<List<ClinicalJointRestriction>> onChanged;
  final VoidCallback? onClearAll;

  const ClinicalJointMatrixSelector({
    super.key,
    this.initialRestrictions = const [],
    required this.onChanged,
    this.onClearAll,
  });

  @override
  State<ClinicalJointMatrixSelector> createState() =>
      _ClinicalJointMatrixSelectorState();
}

class _ClinicalJointMatrixSelectorState
    extends State<ClinicalJointMatrixSelector> {
  late Map<String, ClinicalJointRestriction> _selectedMap;

  static const List<Map<String, dynamic>> _jointsMetadata = [
    {
      'id': 'shoulder',
      'label': 'Ombro',
      'subtitle': 'Manguito & Bursa',
      'icon': Icons.accessibility_new_rounded,
      'chips': ['Manguito', 'Impacto', 'Instabilidade', 'Bursite'],
    },
    {
      'id': 'lumbar_spine',
      'label': 'Coluna Lombar',
      'subtitle': 'L4-L5 / S1 & Disco',
      'icon': Icons.airline_seat_recline_normal_rounded,
      'chips': ['Hérnia de Disco', 'Lombalgia', 'Ciático', 'Espondilolistese'],
    },
    {
      'id': 'knee',
      'label': 'Joelho',
      'subtitle': 'Patela & Meniscos',
      'icon': Icons.directions_walk_rounded,
      'chips': ['Condromalácia', 'Tendinite', 'Menisco', 'Pós-LCA'],
    },
    {
      'id': 'cervical_spine',
      'label': 'Cervical',
      'subtitle': 'Pescoço & Trapézio',
      'icon': Icons.person_rounded,
      'chips': ['Hérnia Cervical', 'Tensão Trapezoidal', 'Retificação'],
    },
    {
      'id': 'hip',
      'label': 'Quadril',
      'subtitle': 'Coxofemoral & Pelve',
      'icon': Icons.accessibility_rounded,
      'chips': ['Impacto IFA', 'Bursite Trocantérica', 'Pubalgia'],
    },
    {
      'id': 'wrist_elbow',
      'label': 'Punho / Cotovelo',
      'subtitle': 'Epicôndilo & Carpo',
      'icon': Icons.pan_tool_rounded,
      'chips': ['Epicondilite', 'Túnel do Carpo', 'Tendinite'],
    },
    {
      'id': 'ankle',
      'label': 'Tornozelo',
      'subtitle': 'Aquiles & Fáscia',
      'icon': Icons.nordic_walking_rounded,
      'chips': ['Fascite Plantar', 'Entorse Crônico', 'Tendinite Aquiles'],
    },
  ];

  @override
  void initState() {
    super.initState();
    _selectedMap = {
      for (final r in widget.initialRestrictions) r.joint: r,
    };
  }

  void _notifyChange() {
    widget.onChanged(_selectedMap.values.toList());
  }

  void _toggleJoint(String jointId) {
    setState(() {
      if (_selectedMap.containsKey(jointId)) {
        _selectedMap.remove(jointId);
      } else {
        _selectedMap[jointId] = ClinicalJointRestriction(
          joint: jointId,
          severity: 'moderate',
          conditions: const [],
        );
      }
    });
    _notifyChange();
  }

  void _clearAll() {
    setState(() {
      _selectedMap.clear();
    });
    if (widget.onClearAll != null) {
      widget.onClearAll!();
    }
    _notifyChange();
  }

  void _updateSeverity(String jointId, String newSeverity) {
    setState(() {
      final current = _selectedMap[jointId];
      if (current != null) {
        _selectedMap[jointId] = ClinicalJointRestriction(
          joint: jointId,
          severity: newSeverity,
          conditions: current.conditions,
          avoidVectors: current.avoidVectors,
          notes: current.notes,
        );
      }
    });
    _notifyChange();
  }

  void _toggleCondition(String jointId, String condition) {
    setState(() {
      final current = _selectedMap[jointId];
      if (current != null) {
        final list = List<String>.from(current.conditions);
        if (list.contains(condition)) {
          list.remove(condition);
        } else {
          list.add(condition);
        }
        _selectedMap[jointId] = ClinicalJointRestriction(
          joint: jointId,
          severity: current.severity,
          conditions: list,
          avoidVectors: current.avoidVectors,
          notes: current.notes,
        );
      }
    });
    _notifyChange();
  }

  Color _severityColor(String severity) {
    switch (severity) {
      case 'severe':
        return Colors.redAccent.shade400;
      case 'mild':
        return Colors.amber.shade700;
      case 'moderate':
      default:
        return Colors.orangeAccent.shade400;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeController.instance.isEffectiveDark(context);
    final cardBg = AppColors.card(context);
    final border = AppColors.cardBorder(context);
    final textPrimary = AppColors.text(context);
    final textSecondary = AppColors.subtext(context);
    final emerald = AppColors.emerald(context);

    final bool isAllClean = _selectedMap.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cabeçalho da Matriz
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: emerald.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.healing_rounded,
                    size: 16,
                    color: emerald,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'MATRIZ ARTICULAR & LESÕES',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            // Botão "100% Saudável"
            InkWell(
              onTap: _clearAll,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isAllClean
                      ? emerald.withValues(alpha: 0.2)
                      : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isAllClean ? emerald : border,
                    width: isAllClean ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isAllClean ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                      size: 13,
                      color: isAllClean ? emerald : textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '100% Saudável',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isAllClean ? FontWeight.bold : FontWeight.w500,
                        color: isAllClean ? emerald : textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Grid com os cards das articulações
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth > 500 ? 3 : 2;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _jointsMetadata.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 2.3,
              ),
              itemBuilder: (context, index) {
                final item = _jointsMetadata[index];
                final jointId = item['id'] as String;
                final isSelected = _selectedMap.containsKey(jointId);
                final currentRestriction = _selectedMap[jointId];
                final sevColor = isSelected
                    ? _severityColor(currentRestriction?.severity ?? 'moderate')
                    : border;

                return InkWell(
                  onTap: () => _toggleJoint(jointId),
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? sevColor.withValues(alpha: isDark ? 0.15 : 0.08)
                          : cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? sevColor : border,
                        width: isSelected ? 1.8 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          item['icon'] as IconData,
                          size: 20,
                          color: isSelected ? sevColor : textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                item['label'] as String,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                  color: isSelected ? textPrimary : textSecondary,
                                ),
                              ),
                              Text(
                                isSelected
                                    ? '${currentRestriction?.severityLabel.toUpperCase()} · ${currentRestriction?.conditions.length ?? 0} notas'
                                    : (item['subtitle'] as String),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                  color: isSelected ? sevColor : textSecondary.withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          isSelected ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                          size: 16,
                          color: isSelected ? sevColor : textSecondary.withValues(alpha: 0.5),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),

        // Painel de detalhe das articulações selecionadas
        if (_selectedMap.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF131A22) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.orangeAccent.withValues(alpha: isDark ? 0.3 : 0.4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.shield_rounded,
                      size: 16,
                      color: Colors.orangeAccent,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'BLINDAGEM BIOMECÂNICA ATIVA (${_selectedMap.length})',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.4,
                        color: Colors.orangeAccent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Lista de chips de condições e severidade para cada articulação ativa
                ..._selectedMap.entries.map((entry) {
                  final jointId = entry.key;
                  final restriction = entry.value;
                  final meta = _jointsMetadata.firstWhere(
                    (m) => m['id'] == jointId,
                    orElse: () => {'label': jointId, 'chips': <String>[]},
                  );
                  final availableChips = (meta['chips'] as List<dynamic>?) ?? [];
                  final sevColor = _severityColor(restriction.severity);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              meta['label'] as String,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: textPrimary,
                              ),
                            ),
                            const Spacer(),
                            // Seletor rápido de severidade
                            for (final s in ['mild', 'moderate', 'severe']) ...[
                              InkWell(
                                onTap: () => _updateSeverity(jointId, s),
                                child: Container(
                                  margin: const EdgeInsets.only(left: 4),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: restriction.severity == s
                                        ? _severityColor(s).withValues(alpha: 0.2)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: restriction.severity == s
                                          ? _severityColor(s)
                                          : border,
                                    ),
                                  ),
                                  child: Text(
                                    s == 'mild'
                                        ? 'Leve'
                                        : (s == 'severe' ? 'Grave' : 'Mod'),
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: restriction.severity == s
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: restriction.severity == s
                                          ? _severityColor(s)
                                          : textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Chips de patologias
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: availableChips.map((chipText) {
                            final isChipSelected =
                                restriction.conditions.contains(chipText);
                            return InkWell(
                              onTap: () => _toggleCondition(jointId, chipText as String),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: isChipSelected
                                      ? sevColor.withValues(alpha: 0.15)
                                      : cardBg,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isChipSelected ? sevColor : border,
                                  ),
                                ),
                                child: Text(
                                  chipText as String,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: isChipSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: isChipSelected
                                        ? textPrimary
                                        : textSecondary,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
