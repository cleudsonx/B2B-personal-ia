import 'package:flutter/material.dart';
import '../../services/student_profile_service.dart';
import 'meta_components.dart';

/// Bottom Sheet modal dedicada para edição de dados pessoais, biometria e restrições clínicas.
class ProfileEditSheet extends StatefulWidget {
  final StudentProfileData initialData;
  final Future<void> Function(StudentProfileData updated) onSave;

  const ProfileEditSheet({
    super.key,
    required this.initialData,
    required this.onSave,
  });

  static Future<bool?> show({
    required BuildContext context,
    required StudentProfileData initialData,
    required Future<void> Function(StudentProfileData updated) onSave,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ProfileEditSheet(
        initialData: initialData,
        onSave: onSave,
      ),
    );
  }

  @override
  State<ProfileEditSheet> createState() => _ProfileEditSheetState();
}

class _ProfileEditSheetState extends State<ProfileEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _ageCtrl;
  late final TextEditingController _weightCtrl;
  late final TextEditingController _heightCtrl;

  static const Map<String, String> _timezoneOptions = {
    'UTC': 'UTC',
    'America/Sao_Paulo': 'São Paulo',
    'America/Manaus': 'Manaus',
    'America/Rio_Branco': 'Rio Branco',
    'America/Noronha': 'Noronha',
  };

  final List<String> _availableRestrictions = [...kStudentRestrictionOptions];
  late final Set<String> _selectedRestrictions;
  late String _selectedTimezone;

  Map<String, String> _fieldErrors = {};
  bool _isSaving = false;
  bool _isSavedSuccess = false;

  @override
  void initState() {
    super.initState();
    final d = widget.initialData;
    _nameCtrl = TextEditingController(text: d.name);
    _ageCtrl = TextEditingController(text: d.age?.toString() ?? '');
    _weightCtrl = TextEditingController(
      text: d.weightKg != null
          ? d.weightKg!.toString().replaceAll('.', ',')
          : '',
    );
    _heightCtrl = TextEditingController(text: d.heightCm?.toString() ?? '');
    _selectedTimezone =
        _timezoneOptions.containsKey(d.timezone) ? d.timezone : 'UTC';
    _selectedRestrictions = Set.of(d.restrictions);
    for (final r in d.restrictions) {
      if (!_availableRestrictions.contains(r)) _availableRestrictions.add(r);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    super.dispose();
  }

  bool get _hasChanges {
    final d = widget.initialData;
    if (_nameCtrl.text.trim() != d.name) return true;
    final currentAge = int.tryParse(_ageCtrl.text.trim());
    if (currentAge != d.age) return true;
    final currentWeight =
        StudentProfileValidator.parseDecimal(_weightCtrl.text);
    if (currentWeight != d.weightKg) return true;
    final currentHeight = int.tryParse(_heightCtrl.text.trim());
    if (currentHeight != d.heightCm) return true;
    if (_selectedTimezone != d.timezone) return true;
    if (_selectedRestrictions.length != d.restrictions.length ||
        !_selectedRestrictions.containsAll(d.restrictions)) {
      return true;
    }
    return false;
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges || _isSaving || _isSavedSuccess) return true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MetaColors.card(ctx),
        title: Text(
          'Descartar alterações?',
          style: TextStyle(color: MetaColors.text(ctx)),
        ),
        content: Text(
          'Você fez alterações no seu perfil que ainda não foram salvas.',
          style: TextStyle(color: MetaColors.subtext(ctx)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Continuar editando'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  Future<void> _handleSave() async {
    final errors = StudentProfileValidator.validate(
      name: _nameCtrl.text,
      age: _ageCtrl.text,
      weight: _weightCtrl.text,
      height: _heightCtrl.text,
    );
    setState(() => _fieldErrors = errors);
    if (errors.isNotEmpty) return;

    setState(() => _isSaving = true);
    try {
      final updated = StudentProfileData(
        name: _nameCtrl.text.trim(),
        age: int.tryParse(_ageCtrl.text.trim()),
        weightKg: StudentProfileValidator.parseDecimal(_weightCtrl.text),
        heightCm: int.tryParse(_heightCtrl.text.trim()),
        restrictions: Set.of(_selectedRestrictions),
        trainerId: widget.initialData.trainerId,
        timezone: _selectedTimezone,
        photoUrl: widget.initialData.photoUrl,
      );

      await widget.onSave(updated);

      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _isSavedSuccess = true;
      });

      await Future.delayed(const Duration(milliseconds: 650));
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  InputDecoration _decoration(String label, String? error) => InputDecoration(
        labelText: label,
        errorText: error,
        filled: true,
        fillColor: MetaColors.highlight(context).withValues(alpha: 0.45),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: MetaColors.cardBorder(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: MetaColors.cardBorder(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: MetaColors.primaryColor(context),
            width: 1.5,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return PopScope(
      canPop: !_hasChanges || _isSavedSuccess,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _onWillPop().then((can) {
            if (can && context.mounted) Navigator.pop(context, false);
          });
        }
      },
      child: DraggableScrollableSheet(
        initialChildSize: 0.90,
        minChildSize: 0.50,
        maxChildSize: 0.95,
        builder: (ctx, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: MetaColors.bg(context),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(color: MetaColors.cardBorder(context)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 32,
                  offset: const Offset(0, -8),
                ),
              ],
            ),
            child: Column(
              children: [
                // Top Drag Handle & Title Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Column(
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4.5,
                          decoration: BoxDecoration(
                            color: MetaColors.subtext(context).withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(2.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            color: MetaColors.subtext(context),
                            onPressed: () async {
                              final can = await _onWillPop();
                              if (can && context.mounted) {
                                Navigator.pop(context, false);
                              }
                            },
                          ),
                          Text(
                            'Editar Perfil & Biometria',
                            style: TextStyle(
                              color: MetaColors.text(context),
                              fontSize: 16.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 48), // balance for close icon
                        ],
                      ),
                    ],
                  ),
                ),
                Divider(
                  height: 1,
                  thickness: 0.8,
                  color: MetaColors.cardBorder(context),
                ),
                // Form Body
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      children: [
                        Text(
                          'DADOS PESSOAIS',
                          style: TextStyle(
                            color: MetaColors.primaryColor(context),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          key: const Key('field_name'),
                          controller: _nameCtrl,
                          style: TextStyle(
                            color: MetaColors.text(context),
                            fontSize: 14.5,
                          ),
                          decoration: _decoration(
                            'Nome Completo',
                            _fieldErrors['name'],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'BIOMETRIA RÁPIDA',
                          style: TextStyle(
                            color: MetaColors.primaryColor(context),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextFormField(
                                key: const Key('field_age'),
                                controller: _ageCtrl,
                                keyboardType: TextInputType.number,
                                style: TextStyle(
                                  color: MetaColors.text(context),
                                  fontSize: 14.5,
                                ),
                                decoration: _decoration(
                                  'Idade',
                                  _fieldErrors['age'],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                key: const Key('field_weight'),
                                controller: _weightCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                style: TextStyle(
                                  color: MetaColors.text(context),
                                  fontSize: 14.5,
                                ),
                                decoration: _decoration(
                                  'Peso (kg)',
                                  _fieldErrors['weight'],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                key: const Key('field_height'),
                                controller: _heightCtrl,
                                keyboardType: TextInputType.number,
                                style: TextStyle(
                                  color: MetaColors.text(context),
                                  fontSize: 14.5,
                                ),
                                decoration: _decoration(
                                  'Altura (cm)',
                                  _fieldErrors['height'],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'FUSO HORÁRIO DO ALUNO',
                          style: TextStyle(
                            color: MetaColors.primaryColor(context),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedTimezone,
                          items: _timezoneOptions.entries
                              .map(
                                (entry) => DropdownMenuItem<String>(
                                  value: entry.key,
                                  child: Text(entry.value),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _selectedTimezone = value);
                            }
                          },
                          decoration: _decoration('Fuso horário', null),
                          style: TextStyle(
                            color: MetaColors.text(context),
                            fontSize: 14.5,
                          ),
                          dropdownColor: MetaColors.card(context),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'RESTRIÇÕES OU LESÕES ARTICULARES',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Alterar restrições avisa automaticamente seu treinador para revisão.',
                          style: TextStyle(
                            color: MetaColors.subtext(context),
                            fontSize: 11.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _availableRestrictions.map((r) {
                            final isSelected =
                                _selectedRestrictions.contains(r);
                            return FilterChip(
                              label: Text(r),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  if (r == kNoRestriction) {
                                    _selectedRestrictions
                                      ..clear()
                                      ..add(kNoRestriction);
                                  } else {
                                    _selectedRestrictions
                                        .remove(kNoRestriction);
                                    if (selected) {
                                      _selectedRestrictions.add(r);
                                    } else {
                                      _selectedRestrictions.remove(r);
                                      if (_selectedRestrictions.isEmpty) {
                                        _selectedRestrictions
                                            .add(kNoRestriction);
                                      }
                                    }
                                  }
                                });
                              },
                              selectedColor:
                                  Colors.redAccent.withValues(alpha: 0.18),
                              checkmarkColor: Colors.redAccent,
                              labelStyle: TextStyle(
                                fontSize: 12,
                                color: isSelected
                                    ? Colors.redAccent
                                    : MetaColors.text(context),
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                              backgroundColor: MetaColors.highlight(context)
                                  .withValues(alpha: 0.4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(100),
                                side: BorderSide(
                                  color: isSelected
                                      ? Colors.redAccent
                                      : MetaColors.cardBorder(context),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
                // Bottom Fixed Action Bar bleeding edge-to-edge
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(
                    18,
                    12,
                    18,
                    bottomInset > 0 ? bottomInset + 8 : 14,
                  ),
                  decoration: BoxDecoration(
                    color: MetaColors.card(context),
                    border: Border(
                      top: BorderSide(color: MetaColors.cardBorder(context)),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: SizedBox(
                      width: double.infinity,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        child: ElevatedButton(
                          key: const Key('btn_save_profile'),
                          onPressed: (_isSaving || _isSavedSuccess)
                              ? null
                              : _handleSave,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isSavedSuccess
                                ? MetaColors.emerald
                                : MetaColors.primaryColor(context),
                            disabledBackgroundColor: _isSavedSuccess
                                ? MetaColors.emerald
                                : MetaColors.primaryColor(context)
                                    .withValues(alpha: 0.6),
                            foregroundColor: Colors.white,
                            disabledForegroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : _isSavedSuccess
                                  ? const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.check_circle_rounded,
                                          color: Colors.white,
                                          size: 19,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Alterações Salvas!',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    )
                                  : const Text(
                                      'Salvar Alterações',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
