import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/widgets/avatar_selector_sheet.dart';
import '../../services/auth_service.dart';
import '../../services/student_profile_service.dart';
import '../auth/teacher_mfa_screen.dart';
import 'welcome_onboarding_screen.dart';

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
  String? _photoUrl;
  String? _email;
  List<String> _roles = const [];
  String? _totpFactorId;
  bool _isSwitchingRole = false;

  // Informações do Treinador Associado
  String? _trainerName;
  String? _trainerCref;
  String? _trainerPhotoUrl;
  bool _isLoadingTrainer = true;

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
      _photoUrl = data.photoUrl;
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

      // Carregar dados de conta e sessão
      _email = AuthService.currentUser?.email;
      try {
        final profile = await AuthService.getCurrentProfile();
        if (profile != null) {
          _roles = AuthService.availableRoles(profile);
          if (_roles.contains('trainer')) {
            _totpFactorId = await AuthService.getVerifiedTotpFactorId();
          }
        }
      } catch (_) {}

      // Carregar dados do treinador associado
      _loadTrainerInfo();

      setState(() => _isLoadingData = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingData = false;
        _loadError = 'Não foi possível carregar seu perfil. Verifique a conexão.';
      });
    }
  }

  Future<void> _loadTrainerInfo() async {
    try {
      final trainer = await AuthService.getTrainerForStudent();
      if (!mounted) return;
      if (trainer != null) {
        setState(() {
          _trainerName = trainer['full_name'] as String?;
          _trainerCref = trainer['professional_document'] as String?;
          _trainerPhotoUrl =
              (trainer['photo_url'] ?? trainer['avatar_url']) as String?;
          _isLoadingTrainer = false;
        });
      } else {
        setState(() => _isLoadingTrainer = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingTrainer = false);
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
        photoUrl: _photoUrl,
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
          _snack('Perfil atualizado com sucesso.', color: AppColors.emerald(context));
          if (Navigator.canPop(context)) Navigator.pop(context);
          return;
        case ReviewStatus.requested:
          _snack(
            'Perfil atualizado. Seu professor foi notificado para revisar a ficha com suas novas restrições.',
            color: AppColors.emerald(context),
          );
          if (Navigator.canPop(context)) Navigator.pop(context);
          return;
        case ReviewStatus.noTrainer:
          _snack(
            'Perfil atualizado. Você ainda não tem professor vinculado para revisar a ficha.',
            color: AppColors.emerald(context),
          );
          if (Navigator.canPop(context)) Navigator.pop(context);
          return;
        case ReviewStatus.failed:
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
      final cleanMsg = e.toString().replaceFirst('Exception: ', '').trim();
      _snack(
        cleanMsg.isNotEmpty ? 'Não foi possível salvar: $cleanMsg' : 'Não foi possível salvar. Nada foi alterado.',
        color: Colors.red,
      );
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
      _snack(
        'Ainda não foi possível avisar seu professor.',
        color: Colors.orange.shade800,
        action: SnackBarAction(
          label: 'Tentar novamente',
          textColor: Colors.white,
          onPressed: _retryReview,
        ),
      );
    }
  }

  Future<void> _signOut(bool allDevices) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(allDevices ? 'Sair de todos os dispositivos?' : 'Sair deste aparelho?'),
        content: Text(
          allDevices
              ? 'Isso revogará todas as sessões ativas da sua conta em qualquer dispositivo. Você precisará fazer login novamente.'
              : 'Deseja realmente encerrar a sessão neste dispositivo?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(allDevices ? 'Revogar e Sair' : 'Sair'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await AuthService.signOut(allDevices: allDevices);
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    } catch (error) {
      if (mounted) {
        _snack(error.toString().replaceFirst('Exception: ', ''), color: Colors.red);
      }
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

  Widget _buildTrainerCard() {
    if (_isLoadingTrainer) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.cardBorder(context)),
        ),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final hasTrainer = _trainerName != null && _trainerName!.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasTrainer
              ? AppColors.emerald(context).withValues(alpha: 0.3)
              : AppColors.cardBorder(context),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.emerald(context).withValues(alpha: 0.15),
              border: Border.all(
                color: AppColors.emerald(context).withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: (_trainerPhotoUrl != null && _trainerPhotoUrl!.isNotEmpty)
                ? (_trainerPhotoUrl!.startsWith('assets/')
                    ? Image.asset(_trainerPhotoUrl!, fit: BoxFit.cover)
                    : Image.network(
                        _trainerPhotoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Icon(
                          Icons.person_rounded,
                          color: AppColors.emerald(context),
                        ),
                      ))
                : Icon(
                    Icons.fitness_center_rounded,
                    color: AppColors.emerald(context),
                    size: 24,
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'TREINADOR RESPONSÁVEL',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                        color: AppColors.emerald(context),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: hasTrainer
                            ? AppColors.emerald(context).withValues(alpha: 0.2)
                            : Colors.orange.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        hasTrainer ? 'Ativo' : 'Pendente',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: hasTrainer
                              ? AppColors.emerald(context)
                              : Colors.orangeAccent,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  hasTrainer ? _trainerName! : 'Nenhum treinador vinculado',
                  style: TextStyle(
                    color: AppColors.text(context),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_trainerCref != null && _trainerCref!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'CREF: $_trainerCref',
                    style: TextStyle(
                      color: AppColors.subtext(context),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnamnesisHeroCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.emerald(context).withValues(alpha: 0.18),
            AppColors.card(context),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.emerald(context).withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.emerald(context).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.assignment_turned_in_rounded,
                  color: AppColors.emerald(context),
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Anamnese Completa',
                      style: TextStyle(
                        color: AppColors.text(context),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Renovação de Periodização & Rotina',
                      style: TextStyle(
                        color: AppColors.subtext(context),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Precisa ajustar suas metas, dias disponíveis, foco muscular ou o professor solicitou uma nova periodização? Refaça o formulário interativo de 5 passos.',
            style: TextStyle(
              color: AppColors.subtext(context),
              fontSize: 13,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => WelcomeOnboardingScreen(
                      studentName: _nameCtrl.text.isNotEmpty
                          ? _nameCtrl.text
                          : _original?.name,
                      trainerId: _original?.trainerId,
                    ),
                  ),
                );
                // Ao retornar da anamnese, recarrega para atualizar peso/idade/restrições
                if (mounted) _load();
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text(
                'Refazer / Atualizar Anamnese Completa',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.emerald(context),
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
    );
  }

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
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 48),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header do Aluno: Foto, Nome e E-mail
            Center(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () async {
                      final uid = _userId;
                      final selected = await AvatarSelectorSheet.show(
                        context: context,
                        isTrainer: false,
                        currentUrl: _photoUrl,
                        userId: uid,
                      );
                      if (selected != null && mounted) {
                        setState(() => _photoUrl = selected.isEmpty ? null : selected);
                      }
                    },
                    child: Stack(
                      children: [
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.card(context),
                            border: Border.all(
                              color: AppColors.emerald(context),
                              width: 3,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: (_photoUrl != null && _photoUrl!.isNotEmpty)
                              ? (_photoUrl!.startsWith('assets/')
                                  ? Image.asset(_photoUrl!, fit: BoxFit.cover)
                                  : Image.network(
                                      _photoUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => const Icon(
                                        Icons.person_rounded,
                                        size: 48,
                                        color: Colors.grey,
                                      ),
                                    ))
                              : Icon(
                                  Icons.person_rounded,
                                  size: 48,
                                  color: AppColors.emerald(context),
                                ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: AppColors.emerald(context),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Theme.of(context).scaffoldBackgroundColor,
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              size: 15,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: () async {
                      final uid = _userId;
                      final selected = await AvatarSelectorSheet.show(
                        context: context,
                        isTrainer: false,
                        currentUrl: _photoUrl,
                        userId: uid,
                      );
                      if (selected != null && mounted) {
                        setState(() => _photoUrl = selected.isEmpty ? null : selected);
                      }
                    },
                    icon: Icon(Icons.edit_rounded, size: 16, color: AppColors.emerald(context)),
                    label: Text(
                      'Alterar Foto ou Avatar',
                      style: TextStyle(
                        color: AppColors.emerald(context),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (_email != null && _email!.isNotEmpty) ...[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.email_outlined, size: 14, color: AppColors.subtext(context)),
                        const SizedBox(width: 6),
                        Text(
                          _email!,
                          style: TextStyle(
                            color: AppColors.subtext(context),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Card do Treinador Vinculado
            _buildTrainerCard(),
            const SizedBox(height: 20),

            // Card Hero de Anamnese & Periodização
            _buildAnamnesisHeroCard(),
            const SizedBox(height: 28),

            // Seção de Alternância de Papel (se o usuário for trainer e aluno)
            if (_roles.length > 1) ...[
              Text(
                'USAR APLICATIVO COMO',
                style: TextStyle(
                  color: AppColors.emerald(context),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: [
                  for (final role in _roles)
                    ButtonSegment<String>(
                      value: role,
                      label: Text(role == 'trainer' ? 'Treinador' : 'Aluno'),
                      icon: Icon(
                        role == 'trainer' ? Icons.fitness_center : Icons.person_outline,
                      ),
                    ),
                ],
                selected: {'client'},
                onSelectionChanged: (selection) async {
                  if (_isSwitchingRole) return;
                  final nextRole = selection.first;
                  if (nextRole == 'client') return;
                  setState(() => _isSwitchingRole = true);
                  try {
                    await AuthService.setActiveRole(nextRole);
                    if (mounted) {
                      Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false);
                    }
                  } catch (e) {
                    if (mounted) _snack(e.toString().replaceFirst('Exception: ', ''));
                  } finally {
                    if (mounted) setState(() => _isSwitchingRole = false);
                  }
                },
              ),
              const SizedBox(height: 28),
            ],

            // Seção: Dados Pessoais
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
            const SizedBox(height: 28),

            // Seção: Biometria Rápida
            Text(
              'BIOMETRIA RÁPIDA',
              style: TextStyle(
                color: AppColors.emerald(context),
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Mantenha atualizado. Seu professor utiliza esses dados para calibrar o volume e intensidade.',
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
            const SizedBox(height: 28),

            // Fuso Horário
            Text(
              'FUSO HORÁRIO DO ALUNO',
              style: TextStyle(
                color: AppColors.emerald(context),
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
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
            const SizedBox(height: 28),

            // Restrições e Lesões
            Text(
              'RESTRIÇÕES OU LESÕES ATUAIS',
              style: TextStyle(
                color: AppColors.danger,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Alterar restrições notifica automaticamente seu treinador para revisão de segurança.',
              style: TextStyle(
                color: AppColors.subtext(context),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 14),
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
            const SizedBox(height: 36),

            // Botão Principal de Salvar Perfil
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
                    borderRadius: BorderRadius.circular(16),
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
                        'Salvar Alterações',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 40),

            // Divisor decorativo
            Divider(color: AppColors.cardBorder(context), thickness: 1),
            const SizedBox(height: 28),

            // Seção: Aparência do Aplicativo
            Text(
              'APARÊNCIA DO APLICATIVO',
              style: TextStyle(
                color: AppColors.emerald(context),
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 14),
            ListenableBuilder(
              listenable: ThemeController.instance,
              builder: (context, _) {
                final currentMode = ThemeController.instance.themeMode;
                return SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.dark,
                        label: Text('Escuro'),
                        icon: Icon(Icons.dark_mode_rounded),
                      ),
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.light,
                        label: Text('Claro'),
                        icon: Icon(Icons.light_mode_rounded),
                      ),
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.system,
                        label: Text('Sistema'),
                        icon: Icon(Icons.brightness_auto_rounded),
                      ),
                    ],
                    selected: {currentMode},
                    onSelectionChanged: (selection) {
                      if (selection.isNotEmpty) {
                        ThemeController.instance.setThemeMode(selection.first);
                      }
                    },
                    emptySelectionAllowed: false,
                  ),
                );
              },
            ),

            // MFA se for professor
            if (_roles.contains('trainer')) ...[
              const SizedBox(height: 28),
              Text(
                'SEGURANÇA DA CONTA',
                style: TextStyle(
                  color: AppColors.emerald(context),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: AppColors.cardBorder(context)),
                ),
                tileColor: AppColors.card(context),
                leading: const Icon(Icons.security_outlined),
                title: const Text('Verificação em duas etapas (2FA)'),
                subtitle: Text(
                  _totpFactorId == null
                      ? 'Recomendado para proteger acesso de treinador'
                      : 'Autenticador ativo e verificado',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TeacherMfaScreen()),
                  );
                  _load();
                },
              ),
            ],

            const SizedBox(height: 36),
            Text(
              'SESSÃO E CONECTIVIDADE',
              style: TextStyle(
                color: AppColors.emerald(context),
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _signOut(false),
                icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                label: const Text(
                  'Sair neste aparelho',
                  style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () => _signOut(true),
                icon: Icon(Icons.phonelink_erase_rounded, color: AppColors.subtext(context)),
                label: Text(
                  'Sair de todos os dispositivos',
                  style: TextStyle(color: AppColors.subtext(context), fontSize: 13),
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
    final canPop = Navigator.canPop(context);
    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: canPop
            ? IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: AppColors.text(context)),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: Text(
          'Meu Perfil & Conta',
          style: TextStyle(
            color: AppColors.text(context),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            tooltip: 'Sair deste aparelho',
            onPressed: () => _signOut(false),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }
}
