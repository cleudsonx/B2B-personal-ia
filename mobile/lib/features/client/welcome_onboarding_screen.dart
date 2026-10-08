import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../main.dart' show MainShellScreen;
import '../../services/auth_service.dart';
import '../../services/student_profile_service.dart';
import '../../services/workout_service.dart';

class WelcomeOnboardingScreen extends StatefulWidget {
  final String? studentName;
  final String? trainerName;

  const WelcomeOnboardingScreen({
    super.key,
    this.studentName,
    this.trainerName,
  });

  @override
  State<WelcomeOnboardingScreen> createState() =>
      _WelcomeOnboardingScreenState();
}

class _WelcomeOnboardingScreenState extends State<WelcomeOnboardingScreen> {
  int _currentStep = 0; // 0: Boas-vindas viral, 1..5: Anamnese, 6: Sucesso
  bool _isSubmitting = false;
  final _stepFormKey = GlobalKey<FormState>();

  // Step 1: Biometria & Rotina
  final _ageCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  String _dailyActivity = 'Sedentário (Trabalho em escritório/computador)';
  String _sleepHours = '7 a 8 horas';

  // Step 2: Experiência & Disponibilidade
  String _trainingLevel = 'Intermediário';
  int _weeklyDays = 4;
  String _sessionDuration = '60 minutos';

  // Step 3: Articulações & Lesões
  final Set<String> _selectedInjuries = {kNoRestriction};
  final _injuriesDetailsCtrl = TextEditingController();

  // Step 4: Espaço de Treino
  String _workoutLocation = 'Academia comercial completa';

  // Step 5: Objetivo & Foco Muscular
  String _objective = 'Hipertrofia Muscular';
  final Set<String> _musclePriorities = {'Peitoral', 'Ombros'};

  String _resolvedTrainerName = 'Seu Treinador';
  String _resolvedTrainerRegistry = 'Registro Profissional Ativo';
  String? _trainerId;
  bool _isLoadingTrainerInfo = true;

  String _getTrainerInitials() {
    final clean = _resolvedTrainerName.replaceAll('Prof.', '').trim();
    if (clean.isEmpty) return 'PT';
    final parts = clean.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return clean.substring(0, clean.length >= 2 ? 2 : 1).toUpperCase();
  }

  @override
  void initState() {
    super.initState();
    _loadTrainerInfo().whenComplete(() {
      if (mounted) setState(() => _isLoadingTrainerInfo = false);
    });
  }

  Future<void> _loadTrainerInfo() async {
    try {
      await AuthService.completePendingInvite();
    } catch (e) {
      debugPrint('Convite não pôde ser concluído durante o onboarding: $e');
    }

    // 1. Prioriza o nome passado explicitamente para o widget
    if (widget.trainerName != null && widget.trainerName!.isNotEmpty) {
      _resolvedTrainerName = widget.trainerName!;
    }

    // 2. Extrai da URL atual do navegador (Web query parameters ou fragment query)
    try {
      final queryParams = Map<String, String>.from(Uri.base.queryParameters);
      final fragment = Uri.base.fragment;
      if (fragment.contains('?')) {
        final fragmentQuery = fragment.split('?')[1];
        queryParams.addAll(Uri.splitQueryString(fragmentQuery));
      }

      if (queryParams.containsKey('trainer_id') &&
          queryParams['trainer_id']!.isNotEmpty) {
        _trainerId = queryParams['trainer_id'];
      }

      if (queryParams.containsKey('trainer_name') &&
          queryParams['trainer_name']!.isNotEmpty) {
        final tName = queryParams['trainer_name']!;
        _resolvedTrainerName =
            tName.startsWith('Prof.') ? tName : 'Prof. $tName';
      }

      if (queryParams.containsKey('cref') && queryParams['cref']!.isNotEmpty) {
        _resolvedTrainerRegistry = queryParams['cref']!;
      }

      // 3. Se temos o trainer_id, busca o perfil real no Supabase para garantir os dados mais recentes
      if (_trainerId != null && _trainerId!.isNotEmpty) {
        try {
          final client = Supabase.instance.client;
          final trainerData =
              await client
                  .from('profiles')
                  .select('id, full_name, professional_document')
                  .eq('id', _trainerId!)
                  .maybeSingle();

          if (trainerData != null && mounted) {
            setState(() {
              final name = trainerData['full_name'] as String?;
              if (name != null && name.isNotEmpty) {
                _resolvedTrainerName =
                    name.startsWith('Prof.') ? name : 'Prof. $name';
              }
              final reg =
                  (trainerData['cref_or_registry'] ??
                          trainerData['cref'] ??
                          trainerData['professional_document'])
                      as String?;
              if (reg != null && reg.isNotEmpty) {
                _resolvedTrainerRegistry = reg;
              }
            });
            return;
          }
        } catch (_) {}
      }
    } catch (_) {}

    // 4. Se o aluno já estiver autenticado, busca pelo vínculo do perfil dele
    try {
      final trainer = await AuthService.getTrainerForStudent();
      if (trainer != null && mounted) {
        setState(() {
          _trainerId = trainer['id'] as String?;
          final name = trainer['full_name'] as String?;
          if (name != null && name.isNotEmpty) {
            _resolvedTrainerName =
                name.startsWith('Prof.') ? name : 'Prof. $name';
          }
          final reg =
              (trainer['cref_or_registry'] ??
                      trainer['cref'] ??
                      trainer['professional_document'])
                  as String?;
          if (reg != null && reg.isNotEmpty) {
            _resolvedTrainerRegistry = reg;
          }
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _ageCtrl.dispose();
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    _injuriesDetailsCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitAnamnesis() async {
    if (AuthService.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entre na sua conta para salvar sua avaliação.')),
      );
      return;
    }
    if (_trainerId == null || _trainerId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vincule-se a um treinador antes de enviar sua avaliação.')),
      );
      return;
    }
    setState(() => _isSubmitting = true);

    try {
      final user = AuthService.currentUser!;
      final clientId = user.id;

        final selectedInjuries = _selectedInjuries.isEmpty
          ? {kNoRestriction}
          : _selectedInjuries;
        final injuriesSummary = selectedInjuries.contains(kNoRestriction)
          ? kNoRestriction
          : selectedInjuries.join(', ');

      final anamnesisPayload = {
        'client_id': clientId,
        'age': int.parse(_ageCtrl.text.trim()),
        'weight': double.parse(_weightCtrl.text.trim().replaceAll(',', '.')),
        'height': double.parse(_heightCtrl.text.trim().replaceAll(',', '.')),
        'daily_activity': _dailyActivity,
        'sleep_hours': _sleepHours,
        'training_level': _trainingLevel,
        'weekly_days': _weeklyDays,
        'session_duration': _sessionDuration,
        'injuries': selectedInjuries.toList(),
        'injuries_details': _injuriesDetailsCtrl.text.trim(),
        'injuries_summary': injuriesSummary,
        'workout_location': _workoutLocation,
        'objective': _objective,
        'muscle_priorities': _musclePriorities.toList(),
        'completed_at': DateTime.now().toIso8601String(),
        if (_trainerId != null) 'trainer_id': _trainerId,
      };

      // Persiste na tabela client_anamnesis e atualiza perfil do aluno
      final saved = await WorkoutService.saveClientAnamnesis(
        clientId: clientId,
        data: anamnesisPayload,
      );
      if (!saved) throw Exception('Não foi possível salvar sua avaliação. Tente novamente.');

      // Garante o vínculo relacional do aluno com o personal trainer no Supabase
      if (_trainerId != null && _trainerId!.isNotEmpty && user != null) {
        try {
          final client = Supabase.instance.client;
          await client
              .from('profiles')
              .update({'trainer_id': _trainerId})
              .eq('id', clientId);
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _currentStep = 6; // Tela de sucesso e transição
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade800,
            content: Text('Erro ao salvar avaliação: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _finishAndEnterApp() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => MainShellScreen(
          activeRole: 'client',
          userName: widget.studentName ?? 'Aluno',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      body: SafeArea(
        child:
            _currentStep == 0
                ? _buildWelcomeScreen(isDark)
                : _currentStep == 6
                ? _buildSuccessScreen(isDark)
                : _buildOnboardingStepScaffold(isDark),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // ETAPA 0: Tela Viral de Boas-Vindas (Apple Fitness / Equinox Minimalist)
  // -------------------------------------------------------------------------
  Widget _buildWelcomeScreen(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Brand Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Image.asset(
                    'assets/images/logo_shaipados.png',
                    height: 42,
                    fit: BoxFit.contain,
                    errorBuilder:
                        (context, error, stackTrace) => Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.emerald(context),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Center(
                            child: Text(
                              'S',
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SHAIPADOS',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.8,
                          color: AppColors.text(context),
                        ),
                      ),
                      Text(
                        'MR. COACH INTELLIGENCE',
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: AppColors.emerald(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.emeraldBg(context),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.emerald(context).withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  'CONVITE EXCLUSIVO',
                  style: TextStyle(
                    color: AppColors.emerald(context),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),

          const Spacer(),

          // Editorial Headline
          Text(
            'Treinamento de elite\nsob medida para você.',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.2,
              height: 1.15,
              color: AppColors.text(context),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Uma experiência de musculação e biomecânica de precisão, conectada em tempo real ao seu treinador.',
            style: TextStyle(
              fontSize: 15,
              color: AppColors.subtext(context),
              height: 1.45,
            ),
          ),

          const SizedBox(height: 28),

          // Card do Personal Trainer com Check
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card(context),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.cardBorder(context)),
              boxShadow: [
                BoxShadow(
                  color: isDark ? Colors.black26 : const Color(0x080F172A),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.emerald(context),
                        AppColors.accentBlue(context),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.emerald(
                          context,
                        ).withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Center(
                        child: Text(
                          _getTrainerInitials(),
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 2,
                        bottom: 2,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              _resolvedTrainerName,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.text(context),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.verified_rounded,
                            size: 16,
                            color: AppColors.accentBlue(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$_resolvedTrainerRegistry • Personal Trainer',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.emerald(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Aguardando sua avaliação para liberar sua periodização.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.subtext(context),
                        ),
                      ),
                      if (_isLoadingTrainerInfo) ...[
                        const SizedBox(height: 8),
                        const LinearProgressIndicator(),
                      ] else if (_trainerId == null || _trainerId!.isEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Não encontramos o vínculo com seu treinador. Abra o convite recebido ou peça um novo link antes de iniciar.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.danger(context),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // Botão Iniciar Avaliação
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.black,
              ),
              label: const Text('Iniciar Avaliação Biomecânica (3 min)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.emerald(context),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
                shadowColor: AppColors.emerald(context).withValues(alpha: 0.35),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
                onPressed: _isLoadingTrainerInfo ||
                    _trainerId == null ||
                    _trainerId!.isEmpty
                  ? null
                  : () => setState(() => _currentStep = 1),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Garantia de sigilo médico e conformidade biomecânica.',
              style: TextStyle(fontSize: 11, color: AppColors.subtext(context)),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // ESTRUTURA DO STEPPER (Passos 1 a 5)
  // -------------------------------------------------------------------------
  Widget _buildOnboardingStepScaffold(bool isDark) {
    return Column(
      children: [
        // Top Step Progress Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                color: AppColors.subtext(context),
                onPressed: () => setState(() => _currentStep--),
              ),
              Column(
                children: [
                  Text(
                    'AVALIAÇÃO DO ALUNO',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: AppColors.emerald(context),
                    ),
                  ),
                  Text(
                    'Etapa $_currentStep de 5',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 40),
            ],
          ),
        ),

        // Linear Progress Bar
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: _currentStep / 5.0,
            minHeight: 4,
            color: AppColors.emerald(context),
            backgroundColor: AppColors.cardBorder(context),
          ),
        ),

        // Step Content Body
        Expanded(
          child: Form(
            key: _stepFormKey,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                if (_currentStep == 1) _buildStep1Biometrics(),
                if (_currentStep == 2) _buildStep2Experience(),
                if (_currentStep == 3) _buildStep3Injuries(),
                if (_currentStep == 4) _buildStep4Environment(),
                if (_currentStep == 5) _buildStep5Goals(),
              ],
            ),
          ),
        ),

        // Bottom Navigation Bar
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.card(context),
            border: Border(
              top: BorderSide(color: AppColors.cardBorder(context)),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.emerald(context),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 3,
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  onPressed:
                      _isSubmitting
                          ? null
                          : () {
                            if (_currentStep == 1 &&
                                !_stepFormKey.currentState!.validate()) {
                              return;
                            }
                            if (_currentStep < 5) {
                              setState(() => _currentStep++);
                            } else {
                              _submitAnamnesis();
                            }
                          },
                  child:
                      _isSubmitting
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.black,
                              strokeWidth: 2,
                            ),
                          )
                          : Text(
                            _currentStep < 5
                                ? 'Continuar →'
                                : 'Enviar Avaliação ao Treinador ✓',
                          ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ETAPA 1: Biometria & Rotina
  Widget _buildStep1Biometrics() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Perfil Biométrico & Rotina',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.text(context),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Dados fundamentais para calcular a taxa metabólica e a capacidade recuperativa.',
          style: TextStyle(fontSize: 13, color: AppColors.subtext(context)),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                'Idade (anos)',
                _ageCtrl,
                keyboardType: TextInputType.number,
                validator: (input) {
                  final age = int.tryParse(input?.trim() ?? '');
                  if (age == null) return 'Informe a idade.';
                  if (age < 10 || age > 100) return 'Use uma idade entre 10 e 100.';
                  return null;
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTextField(
                'Peso (kg)',
                _weightCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (input) {
                  final weight = double.tryParse(
                    (input ?? '').trim().replaceAll(',', '.'),
                  );
                  if (weight == null) return 'Informe o peso.';
                  if (weight < 20 || weight > 300) return 'Use 20 a 300 kg.';
                  return null;
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTextField(
                'Altura (cm)',
                _heightCtrl,
                keyboardType: TextInputType.number,
                validator: (input) {
                  final height = int.tryParse(input?.trim() ?? '');
                  if (height == null) return 'Informe a altura em centímetros.';
                  if (height < 100 || height > 250) return 'Use 100 a 250 cm.';
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _buildDropdown(
          label: 'Rotina de Trabalho / Atividade Diária',
          value: _dailyActivity,
          items: [
            'Sedentário (Trabalho em escritório/computador)',
            'Moderado (Boa parte do dia em pé ou caminhando)',
            'Ativo (Trabalho braçal ou atividade física contínua)',
          ],
          onChanged: (val) => setState(() => _dailyActivity = val!),
        ),
        const SizedBox(height: 16),
        _buildDropdown(
          label: 'Média de Sono por Noite',
          value: _sleepHours,
          items: [
            'Menos de 6 horas',
            '6 a 7 horas',
            '7 a 8 horas',
            'Mais de 8 horas',
          ],
          onChanged: (val) => setState(() => _sleepHours = val!),
        ),
      ],
    );
  }

  // ETAPA 2: Experiência & Disponibilidade
  Widget _buildStep2Experience() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Experiência & Disponibilidade',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.text(context),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Define o volume semanal e a complexidade técnica dos movimentos.',
          style: TextStyle(fontSize: 13, color: AppColors.subtext(context)),
        ),
        const SizedBox(height: 24),
        _buildDropdown(
          label: 'Nível de Treino Atual',
          value: _trainingLevel,
          items: [
            'Iniciante (Nunca treinou ou menos de 6 meses)',
            'Intermediário (6 meses a 2 anos consistentes)',
            'Avançado (+2 anos de musculação contínua)',
          ],
          onChanged: (val) => setState(() => _trainingLevel = val!),
        ),
        const SizedBox(height: 16),
        _buildDropdown(
          label: 'Frequência Semanal Pretendida',
          value: '$_weeklyDays dias por semana',
          items: [2, 3, 4, 5, 6].map((e) => '$e dias por semana').toList(),
          onChanged: (val) {
            setState(() {
              _weeklyDays = int.parse(val!.split(' ')[0]);
            });
          },
        ),
        const SizedBox(height: 16),
        _buildDropdown(
          label: 'Tempo Disponível por Sessão',
          value: _sessionDuration,
          items: [
            '30 a 45 minutos',
            '45 a 60 minutos',
            '60 minutos',
            '75 a 90 minutos',
          ],
          onChanged: (val) => setState(() => _sessionDuration = val!),
        ),
      ],
    );
  }

  // ETAPA 3: Articulações & Lesões
  Widget _buildStep3Injuries() {
    final options = kStudentRestrictionOptions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mapeamento Articular & Lesões',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.text(context),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Crucial para que o Mr. Coach AI e seu treinador excluam vetores de sobrecarga articular lesiva.',
          style: TextStyle(fontSize: 13, color: AppColors.subtext(context)),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              options.map((opt) {
                final isSelected = _selectedInjuries.contains(opt);
                return FilterChip(
                  selected: isSelected,
                  showCheckmark: true,
                  checkmarkColor: isSelected ? Colors.black : null,
                  label: Text(
                    opt,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.w800 : FontWeight.w500,
                      color:
                          isSelected ? Colors.black : AppColors.text(context),
                    ),
                  ),
                  backgroundColor: AppColors.pillBg(context),
                  selectedColor: AppColors.emerald(context),
                  side: BorderSide(
                    color:
                        isSelected
                            ? AppColors.emerald(context)
                            : AppColors.cardBorder(context),
                  ),
                  onSelected: (selected) {
                    setState(() {
                      if (opt == kNoRestriction) {
                        _selectedInjuries.clear();
                        if (selected) _selectedInjuries.add(opt);
                      } else {
                        _selectedInjuries.remove(kNoRestriction);
                        if (selected) {
                          _selectedInjuries.add(opt);
                        } else {
                          _selectedInjuries.remove(opt);
                          if (_selectedInjuries.isEmpty) {
                            _selectedInjuries.add(kNoRestriction);
                          }
                        }
                      }
                    });
                  },
                );
              }).toList(),
        ),
        const SizedBox(height: 20),
        TextFormField(
          controller: _injuriesDetailsCtrl,
          maxLines: 3,
          style: TextStyle(color: AppColors.text(context), fontSize: 13),
          decoration: InputDecoration(
            labelText: 'Detalhes ou Diagnósticos Médicos (Opcional)',
            hintText:
                'Ex: Tenho leve impacto subacromial no ombro direito quando faço abdução acima de 90°...',
            filled: true,
            fillColor: AppColors.card(context),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ],
    );
  }

  // ETAPA 4: Espaço de Treino
  Widget _buildStep4Environment() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Espaço de Treino & Estrutura',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.text(context),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Permite selecionar máquinas guiadas, cabos ou halteres compatíveis com seu local.',
          style: TextStyle(fontSize: 13, color: AppColors.subtext(context)),
        ),
        const SizedBox(height: 24),
        _buildDropdown(
          label: 'Ambiente Onde Irá Treinar',
          value: _workoutLocation,
          items: [
            'Academia comercial completa',
            'Espaço de musculação em condomínio / prédio',
            'Em casa (Halteres, elásticos e peso corporal)',
          ],
          onChanged: (val) => setState(() => _workoutLocation = val!),
        ),
      ],
    );
  }

  // ETAPA 5: Objetivos & Focos
  Widget _buildStep5Goals() {
    final muscles = [
      'Peitoral',
      'Costas / Dorsais',
      'Ombros',
      'Quadríceps',
      'Glúteos',
      'Braços / Tríceps',
      'Abdômen',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Metas & Prioridades Estéticas',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.text(context),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Qual é o seu objetivo de resultado principal?',
          style: TextStyle(fontSize: 13, color: AppColors.subtext(context)),
        ),
        const SizedBox(height: 20),
        _buildDropdown(
          label: 'Objetivo Principal',
          value: _objective,
          items: [
            'Hipertrofia Muscular',
            'Emagrecimento & Definição',
            'Força & Performance Atlética',
            'Reabilitação Postural & Longevidade',
          ],
          onChanged: (val) => setState(() => _objective = val!),
        ),
        const SizedBox(height: 24),
        Text(
          'Músculos com Maior Foco / Prioridade:',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.text(context),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              muscles.map((m) {
                final isSelected = _musclePriorities.contains(m);
                return FilterChip(
                  selected: isSelected,
                  showCheckmark: true,
                  checkmarkColor: isSelected ? Colors.black : null,
                  label: Text(
                    m,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.w800 : FontWeight.w500,
                      color:
                          isSelected ? Colors.black : AppColors.text(context),
                    ),
                  ),
                  backgroundColor: AppColors.pillBg(context),
                  selectedColor: AppColors.emerald(context),
                  side: BorderSide(
                    color:
                        isSelected
                            ? AppColors.emerald(context)
                            : AppColors.cardBorder(context),
                  ),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _musclePriorities.add(m);
                      } else {
                        _musclePriorities.remove(m);
                      }
                    });
                  },
                );
              }).toList(),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // ETAPA 6: Tela de Sucesso & Boas-Vindas Confirmadas
  // -------------------------------------------------------------------------
  Widget _buildSuccessScreen(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: AppColors.emeraldBg(context),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.emerald(context), width: 2),
            ),
            child: Icon(
              Icons.check_rounded,
              color: AppColors.emerald(context),
              size: 44,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Avaliação Concluída!',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: AppColors.text(context),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Seus dados biomecânicos foram transmitidos com sucesso para o $_resolvedTrainerName.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.subtext(context),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cardBorder(context)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.mark_chat_read_rounded,
                  color: AppColors.emerald(context),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Sua avaliação foi salva e está disponível para o seu treinador.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.text(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 36),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.emerald(context),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              onPressed: _finishAndEnterApp,
              child: const Text('Entrar no Espaço de Treino →'),
            ),
          ),
        ],
      ),
    );
  }

  // Auxiliares de UI
  Widget _buildTextField(
    String label,
    TextEditingController ctrl, {
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(color: AppColors.text(context), fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.card(context),
        labelStyle: TextStyle(color: AppColors.subtext(context), fontSize: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.cardBorder(context)),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: items.contains(value) ? value : items.first,
      dropdownColor: AppColors.card(context),
      style: TextStyle(color: AppColors.text(context), fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.card(context),
        labelStyle: TextStyle(color: AppColors.subtext(context), fontSize: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.cardBorder(context)),
        ),
      ),
      items:
          items
              .map(
                (e) => DropdownMenuItem(
                  value: e,
                  child: Text(e, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
      onChanged: onChanged,
    );
  }
}
