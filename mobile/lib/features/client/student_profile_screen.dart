import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/student_profile_service.dart';
import '../../core/theme/app_colors.dart';

class StudentProfileScreen extends StatefulWidget {
  /// Injetáveis para testes; em produção usam o usuário autenticado e o Supabase.
  final StudentProfileService? service;
  final String? userId;

  const StudentProfileScreen({super.key, this.service, this.userId});

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  late final StudentProfileService _service;
  bool _isLoadingData = true;
  bool _isSaving = false;
  String? _loadError;
  StudentProfileData? _original;
  Map<String, String> _fieldErrors = {};

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();

  static const Map<String, String> _timezoneOptions = {
    'UTC': 'UTC',
    'America/Sao_Paulo': 'São Paulo',
    'America/Manaus': 'Manaus',
    'America/Rio_Branco': 'Rio Branco',
    'America/Noronha': 'Noronha',
  };

  final List<String> _availableRestrictions = [...kStudentRestrictionOptions];
  final Set<String> _selectedRestrictions = {kNoRestriction};
  String _selectedTimezone = 'UTC';

  String? get _userId => widget.userId ?? AuthService.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? StudentProfileService();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final uid = _userId;
    setState(() {
      _isLoadingData = true;
      _loadError = null;
    });
    if (uid == null) {
      setState(() {
        _isLoadingData = false;
        _loadError = 'Sessão expirada. Faça login novamente.';
      });
      return;
    }
    try {
      final data = await _service.load(uid);
      if (!mounted) return;
      if (data == null) {
        setState(() {
          _isLoadingData = false;
          _loadError = 'Perfil não encontrado.';
        });
        return;
      }
      _original = data;
      _nameCtrl.text = data.name;
      _ageCtrl.text = data.age?.toString() ?? '';
      _weightCtrl.text = data.weightKg?.toString() ?? '';
      _heightCtrl.text = data.heightCm?.toString() ?? '';
      _selectedTimezone =
          _timezoneOptions.containsKey(data.timezone) ? data.timezone : 'UTC';
      _selectedRestrictions
        ..clear()
        ..addAll(data.restrictions);
      for (final r in data.restrictions) {
        if (!_availableRestrictions.contains(r)) _availableRestrictions.add(r);
      }
      setState(() => _isLoadingData = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingData = false;
        _loadError = 'Não foi possível carregar seu perfil. Verifique a conexão.';
      });
    }
  }

  StudentProfileData _currentFormData() => StudentProfileData(
        name: _nameCtrl.text.trim(),
        age: int.tryParse(_ageCtrl.text.trim()),
        weightKg: StudentProfileValidator.parseDecimal(_weightCtrl.text),
        heightCm: int.tryParse(_heightCtrl.text.trim()),
        restrictions: Set.of(_selectedRestrictions),
        trainerId: _original?.trainerId,
        timezone: _selectedTimezone,
      );

  void _snack(String msg, {Color? color, SnackBarAction? action}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        action: action,
        duration: const Duration(seconds: 6),
      ),
    );
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

    final uid = _userId;
    final original = _original;
    if (uid == null || original == null) return;

    setState(() => _isSaving = true);
    try {
      final updated = _currentFormData();
      final result =
          await _service.save(userId: uid, original: original, updated: updated);
      _original = updated;
      if (!mounted) return;

      switch (result.review) {
        case ReviewStatus.notNeeded:
          _snack('Perfil atualizado.', color: AppColors.emerald(context));
          Navigator.pop(context);
          return;
        case ReviewStatus.requested:
          _snack(
            'Perfil atualizado. Seu professor foi notificado para revisar a ficha com suas novas restrições.',
            color: AppColors.emerald(context),
          );
          Navigator.pop(context);
          return;
        case ReviewStatus.noTrainer:
          _snack(
            'Perfil atualizado. Você ainda não tem professor vinculado para revisar a ficha.',
            color: AppColors.emerald(context),
          );
          Navigator.pop(context);
          return;
        case ReviewStatus.failed:
          // Dados salvos, mas a revisão NÃO foi acionada: permanece na tela.
          _snack(
            'Perfil salvo, mas não conseguimos avisar seu professor para revisar a ficha.',
            color: Colors.orange.shade800,
            action: SnackBarAction(
              label: 'Tentar novamente',
              textColor: Colors.white,
              onPressed: _retryReview,
            ),
          );
      }
    } catch (e) {
      _snack('Não foi possível salvar. Nada foi alterado.', color: Colors.red);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _retryReview() async {
    final uid = _userId;
    final data = _original;
    if (uid == null || data == null) return;
    final status = await _service.requestReview(userId: uid, data: data);
    if (!mounted) return;
    if (status == ReviewStatus.requested) {
      _snack('Seu professor foi notificado para revisar a ficha.',
          color: AppColors.emerald(context));
    } else {
      _snack('Ainda não foi possível avisar seu professor.',
          color: Colors.orange.shade800,
          action: SnackBarAction(
              label: 'Tentar novamente',
              textColor: Colors.white,
              onPressed: _retryReview));
    }
  }

  InputDecoration _decoration(String label, String? error) => InputDecoration(
        labelText: label,
        errorText: error,
        filled: true,
        fillColor: AppColors.card(context),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      );

  Widget _buildBody() {
    if (_isLoadingData) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_loadError!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.text(context))),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _load,
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'DADOS PESSOAIS',
              style: TextStyle(
                color: AppColors.emerald(context),
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('field_name'),
              controller: _nameCtrl,
              style: TextStyle(color: AppColors.text(context)),
              decoration: _decoration('Nome Completo', _fieldErrors['name']),
            ),
            const SizedBox(height: 32),
            Text(
              'ANAMNESE FÍSICA',
              style: TextStyle(
                color: AppColors.emerald(context),
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Mantenha atualizado. Mudanças de restrição avisam seu professor para revisar a ficha.',
              style: TextStyle(
                color: AppColors.subtext(context),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    key: const Key('field_age'),
                    controller: _ageCtrl,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: AppColors.text(context)),
                    decoration: _decoration('Idade', _fieldErrors['age']),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    key: const Key('field_weight'),
                    controller: _weightCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(color: AppColors.text(context)),
                    decoration:
                        _decoration('Peso (kg)', _fieldErrors['weight']),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    key: const Key('field_height'),
                    controller: _heightCtrl,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: AppColors.text(context)),
                    decoration:
                        _decoration('Altura (cm)', _fieldErrors['height']),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Text(
              'PREFERÊNCIA DE FUSO HORÁRIO',
              style: TextStyle(
                color: AppColors.emerald(context),
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _timezoneOptions.containsKey(_selectedTimezone)
                  ? _selectedTimezone
                  : 'UTC',
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
              style: TextStyle(color: AppColors.text(context)),
              dropdownColor: AppColors.card(context),
            ),
            const SizedBox(height: 32),
            Text(
              'RESTRIÇÕES OU LESÕES ATUAIS',
              style: TextStyle(
                color: AppColors.danger,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 12,
              children: _availableRestrictions.map((r) {
                final isSelected = _selectedRestrictions.contains(r);
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
                        _selectedRestrictions.remove(kNoRestriction);
                        if (selected) {
                          _selectedRestrictions.add(r);
                        } else {
                          _selectedRestrictions.remove(r);
                          if (_selectedRestrictions.isEmpty) {
                            _selectedRestrictions.add(kNoRestriction);
                          }
                        }
                      }
                    });
                  },
                  selectedColor: AppColors.danger.withValues(alpha: 0.2),
                  checkmarkColor: AppColors.danger,
                  labelStyle: TextStyle(
                    color:
                        isSelected ? AppColors.danger : AppColors.text(context),
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  backgroundColor: AppColors.card(context),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100),
                    side: BorderSide(
                      color: isSelected
                          ? AppColors.danger
                          : AppColors.cardBorder(context),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 64),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                key: const Key('btn_save_profile'),
                onPressed: _isSaving ? null : _handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.emerald(context),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Salvar Perfil',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: AppColors.text(context)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Meu Perfil & Anamnese',
          style: TextStyle(
            color: AppColors.text(context),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: _buildBody(),
    );
  }
}
