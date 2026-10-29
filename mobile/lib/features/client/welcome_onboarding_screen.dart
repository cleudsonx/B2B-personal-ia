import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/widgets/meta_components.dart';
import '../../core/widgets/pwa_install_prompt_card.dart';
import '../../main.dart' show MainShellScreen;
import '../../services/auth_service.dart';
import '../../services/body_metrics_service.dart';
import '../../services/student_profile_service.dart';
import '../../services/workout_service.dart';
import '../landing/public_trainer_directory_screen.dart';

class WelcomeOnboardingScreen extends StatefulWidget {
  final String? studentName;
  final String? trainerName;
  final String? trainerId;
  final String? trainerAvatarUrl;

  final bool isReviewMode;
  final Map<String, dynamic>? initialData;

  const WelcomeOnboardingScreen({
    super.key,
    this.studentName,
    this.trainerName,
    this.trainerId,
    this.trainerAvatarUrl,
    this.isReviewMode = false,
    this.initialData,
  });

  @override
  State<WelcomeOnboardingScreen> createState() =>
      _WelcomeOnboardingScreenState();
}

class _WelcomeOnboardingScreenState extends State<WelcomeOnboardingScreen> {
  int _currentStep = 0; // 0: Boas-vindas viral, 1..5: Anamnese, 6: Sucesso
  bool _isSubmitting = false;
  final _stepFormKey = GlobalKey<FormState>();

  // Step 1: Biometria, Sexo Biológico & Recuperação
  String _biologicalSex = 'Masculino'; // 'Masculino' | 'Feminino'
  final _ageCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  String _dailyActivity = 'Sedentário (Trabalho em mesa / pouca caminhada)';
  String _sleepHours = '7 a 8 horas';
  String _stressLevel = 'Moderado';

  // Step 2: Experiência, Frequência Semanal & Cardio
  String _trainingLevel = 'Intermediário (6m a 2 anos)';
  String _trainingHistory = '6 meses a 1 ano';
  int _weeklyDays = 4;
  final Set<String> _preferredDays = {'Seg', 'Ter', 'Qui', 'Sex'};
  String _sessionDuration = '60 minutos';
  String _cardioPreference = 'Sim (Pós-musculação)';

  // Step 3: Triagem PAR-Q & Saúde Articular
  final Set<String> _clinicalConditions = {'Nenhuma restrição médica'};
  final Set<String> _selectedInjuries = {kNoRestriction};
  final _injuriesDetailsCtrl = TextEditingController();

  // Step 4: Espaço de Treino & Equipamentos
  String _workoutLocation = 'Academia comercial completa';
  final Set<String> _availableEquipment = {
    'Halteres',
    'Barras e Anilhas',
    'Polia / Cabos',
    'Máquinas Articuladas',
    'Smith Machine',
    'Leg Press',
  };
  final _avoidExercisesCtrl = TextEditingController();

  // Step 5: Objetivo, Focos Musculares & Estilo de Treino
  String _objective = 'Hipertrofia Muscular';
  final Set<String> _musclePriorities = {'Peitoral', 'Costas / Dorsais', 'Ombros'};
  String _trainingStyle = 'Equilibrado (Carga + Pump)';

  String _resolvedTrainerName = 'Seu Treinador';
  String _resolvedTrainerRegistry = 'Registro Profissional Ativo';
  String? _trainerId;
  String? _resolvedTrainerAvatarUrl;
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

  String? _calculateBmi() {
    final w = double.tryParse(_weightCtrl.text.trim().replaceAll(',', '.'));
    final h = double.tryParse(_heightCtrl.text.trim().replaceAll(',', '.'));
    if (w == null || h == null || w <= 0 || h <= 0) return null;
    final heightM = h > 3 ? h / 100 : h;
    final bmi = w / (heightM * heightM);
    String classification;
    if (bmi < 18.5) {
      classification = 'Abaixo do peso';
    } else if (bmi < 25.0) {
      classification = 'Eutrofia (Peso normal)';
    } else if (bmi < 30.0) {
      classification = 'Sobrepeso';
    } else {
      classification = 'Obesidade';
    }
    return 'IMC: ${bmi.toStringAsFixed(1)} • $classification';
  }

  @override
  void initState() {
    super.initState();
    _trainerId = widget.trainerId;
    _resolvedTrainerAvatarUrl = widget.trainerAvatarUrl;
    if (widget.isReviewMode) {
      _currentStep = 1;
      _hydrateFromInitialOrDatabase();
    }
    _loadTrainerInfo().whenComplete(() {
      if (mounted) setState(() => _isLoadingTrainerInfo = false);
    });
  }

  Future<void> _hydrateFromInitialOrDatabase() async {
    Map<String, dynamic>? data = widget.initialData;
    if (data == null) {
      final user = AuthService.currentUser;
      if (user != null) {
        data = await WorkoutService.getLatestStudentAnamnesis(user.id);
      }
    }
    if (data == null || !mounted) return;

    final details = (data['details'] as Map<String, dynamic>?) ?? {};

    setState(() {
      final sex = data!['biological_sex'] ?? details['biological_sex'];
      if (sex != null && sex.toString().isNotEmpty) {
        _biologicalSex = sex.toString();
      }

      final age = data['age'] ?? details['age'];
      if (age != null) _ageCtrl.text = age.toString();

      final weight = data['weight'] ?? details['weight'];
      if (weight != null) _weightCtrl.text = weight.toString();

      final height = data['height'] ?? details['height'];
      if (height != null) _heightCtrl.text = height.toString();

      final dailyAct = data['daily_activity'] ?? details['daily_activity'];
      if (dailyAct != null) _dailyActivity = dailyAct.toString();

      final sleep = data['sleep_hours'] ?? details['sleep_hours'];
      if (sleep != null) _sleepHours = sleep.toString();

      final stress = data['stress_level'] ?? details['stress_level'];
      if (stress != null) _stressLevel = stress.toString();

      final tLevel = data['training_level'] ?? details['training_level'];
      if (tLevel != null) _trainingLevel = tLevel.toString();

      final tHistory = data['training_history'] ?? details['training_history'];
      if (tHistory != null) _trainingHistory = tHistory.toString();

      final wDays = data['weekly_days'] ?? details['weekly_days'];
      if (wDays is int) {
        _weeklyDays = wDays;
      } else if (wDays != null) {
        _weeklyDays = int.tryParse(wDays.toString()) ?? _weeklyDays;
      }

      final prefDays = data['preferred_days'] ?? details['preferred_days'];
      if (prefDays is List && prefDays.isNotEmpty) {
        _preferredDays.clear();
        _preferredDays.addAll(prefDays.map((e) => e.toString()));
      }

      final sDuration = data['session_duration'] ?? details['session_duration'];
      if (sDuration != null) _sessionDuration = sDuration.toString();

      final cardioPref = data['cardio_preference'] ?? details['cardio_preference'];
      if (cardioPref != null) _cardioPreference = cardioPref.toString();

      final clinCond = data['clinical_conditions'] ?? details['clinical_conditions'];
      if (clinCond is List && clinCond.isNotEmpty) {
        _clinicalConditions.clear();
        _clinicalConditions.addAll(clinCond.map((e) => e.toString()));
      }

      final inj = data['injuries'] ?? details['injuries'];
      if (inj is List && inj.isNotEmpty) {
        _selectedInjuries.clear();
        _selectedInjuries.addAll(inj.map((e) => e.toString()));
      }

      final injDet = data['injuries_details'] ?? details['injuries_details'];
      if (injDet != null) _injuriesDetailsCtrl.text = injDet.toString();

      final loc = data['workout_location'] ?? details['workout_location'];
      if (loc != null) _workoutLocation = loc.toString();

      final equip = data['available_equipment'] ?? details['available_equipment'];
      if (equip is List && equip.isNotEmpty) {
        _availableEquipment.clear();
        _availableEquipment.addAll(equip.map((e) => e.toString()));
      }

      final avoid = data['exercises_to_avoid'] ?? details['exercises_to_avoid'];
      if (avoid != null) _avoidExercisesCtrl.text = avoid.toString();

      final obj = data['objective'] ?? details['objective'];
      if (obj != null) _objective = obj.toString();

      final priorities = data['muscle_priorities'] ?? details['muscle_priorities'];
      if (priorities is List && priorities.isNotEmpty) {
        _musclePriorities.clear();
        _musclePriorities.addAll(priorities.map((e) => e.toString()));
      }

      final tStyle = data['training_style'] ?? details['training_style'];
      if (tStyle != null) _trainingStyle = tStyle.toString();
    });
  }

  Future<void> _loadTrainerInfo() async {
    try {
      await AuthService.completePendingInvite();
    } catch (e) {
      debugPrint('Convite não pôde ser concluído durante o onboarding: $e');
    }

    if (widget.trainerName != null && widget.trainerName!.isNotEmpty) {
      _resolvedTrainerName = widget.trainerName!;
    }
    if (widget.trainerId != null && widget.trainerId!.isNotEmpty) {
      _trainerId = widget.trainerId;
    }
    if (widget.trainerAvatarUrl != null && widget.trainerAvatarUrl!.isNotEmpty) {
      _resolvedTrainerAvatarUrl = widget.trainerAvatarUrl;
    }

    try {
      final queryParams = Map<String, String>.from(Uri.base.queryParameters);
      final fragment = Uri.base.fragment;
      if (fragment.contains('?')) {
        final fragmentQuery = fragment.split('?')[1];
        queryParams.addAll(Uri.splitQueryString(fragmentQuery));
      }

      if (queryParams.containsKey('trainer_id') &&
          queryParams['trainer_id']!.isNotEmpty) {
        _trainerId ??= queryParams['trainer_id'];
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
    } catch (_) {}

    if (_trainerId != null && _trainerId!.isNotEmpty) {
      try {
        final client = Supabase.instance.client;
        final trainerData = await client
            .from('profiles')
            .select('id, full_name, professional_document, photo_url, avatar_url')
            .eq('id', _trainerId!)
            .maybeSingle();

        if (trainerData != null && mounted) {
          setState(() {
            final name = trainerData['full_name'] as String?;
            if (name != null && name.isNotEmpty) {
              _resolvedTrainerName =
                  name.startsWith('Prof.') ? name : 'Prof. $name';
            }
            final reg = (trainerData['professional_document'] ??
                    trainerData['cref'] ??
                    trainerData['cref_or_registry']) as String?;
            if (reg != null && reg.isNotEmpty) {
              _resolvedTrainerRegistry = reg;
            }
            final avatar = (trainerData['photo_url'] ?? trainerData['avatar_url']) as String?;
            if (avatar != null && avatar.isNotEmpty) {
              _resolvedTrainerAvatarUrl = avatar;
            }
          });
          return;
        }
      } catch (_) {}
    }

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
          final reg = (trainer['professional_document'] ??
                  trainer['cref'] ??
                  trainer['cref_or_registry']) as String?;
          if (reg != null && reg.isNotEmpty) {
            _resolvedTrainerRegistry = reg;
          }
          final avatar = (trainer['photo_url'] ?? trainer['avatar_url']) as String?;
          if (avatar != null && avatar.isNotEmpty) {
            _resolvedTrainerAvatarUrl = avatar;
          }
        });
        return;
      }
    } catch (_) {}

    try {
      final client = Supabase.instance.client;
      final currentUser = client.auth.currentUser;
      if (currentUser != null) {
        String? foundTrainerId;

        final phone = currentUser.phone ?? (currentUser.userMetadata?['phone'] as String?);
        final email = currentUser.email;

        if (phone != null && phone.isNotEmpty) {
          final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
          final inviteByPhone = await client
              .from('invite_tokens')
              .select('trainer_id')
              .eq('target_phone', cleanPhone)
              .order('created_at', ascending: false)
              .limit(1)
              .maybeSingle();
          if (inviteByPhone != null) {
            foundTrainerId = inviteByPhone['trainer_id'] as String?;
          }
        }

        if (foundTrainerId == null && email != null && email.isNotEmpty) {
          final inviteByEmail = await client
              .from('invite_tokens')
              .select('trainer_id')
              .eq('target_email', email)
              .order('created_at', ascending: false)
              .limit(1)
              .maybeSingle();
          if (inviteByEmail != null) {
            foundTrainerId = inviteByEmail['trainer_id'] as String?;
          }
        }

        if (foundTrainerId == null && _resolvedTrainerName != 'Seu Treinador') {
          final cleanName = _resolvedTrainerName.replaceAll('Prof.', '').trim();
          final trainerProfile = await client
              .from('profiles')
              .select('id, full_name, professional_document, photo_url, avatar_url')
              .ilike('full_name', '%$cleanName%')
              .eq('role', 'trainer')
              .limit(1)
              .maybeSingle();
          if (trainerProfile != null) {
            foundTrainerId = trainerProfile['id'] as String?;
          }
        }

        if (foundTrainerId != null && foundTrainerId.isNotEmpty) {
          _trainerId = foundTrainerId;
          await client
              .from('profiles')
              .update({'trainer_id': foundTrainerId})
              .eq('id', currentUser.id);

          final trainerData = await client
              .from('profiles')
              .select('id, full_name, professional_document, photo_url, avatar_url')
              .eq('id', foundTrainerId)
              .maybeSingle();

          if (trainerData != null && mounted) {
            setState(() {
              final name = trainerData['full_name'] as String?;
              if (name != null && name.isNotEmpty) {
                _resolvedTrainerName =
                    name.startsWith('Prof.') ? name : 'Prof. $name';
              }
              final reg = (trainerData['professional_document'] ??
                      trainerData['cref'] ??
                      trainerData['cref_or_registry']) as String?;
              if (reg != null && reg.isNotEmpty) {
                _resolvedTrainerRegistry = reg;
              }
              final avatar = (trainerData['photo_url'] ?? trainerData['avatar_url']) as String?;
              if (avatar != null && avatar.isNotEmpty) {
                _resolvedTrainerAvatarUrl = avatar;
              }
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Aviso na auto-recuperação de vínculo de treinador: $e');
    }
  }

  @override
  void dispose() {
    _ageCtrl.dispose();
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    _injuriesDetailsCtrl.dispose();
    _avoidExercisesCtrl.dispose();
    super.dispose();
  }

  void _showRedeemInviteDialog() {
    final codeCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: MetaColors.card(dlgCtx),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.link_rounded, color: MetaColors.emerald, size: 22),
            const SizedBox(width: 8),
            Text(
              'Vincular Treinador',
              style: TextStyle(
                color: MetaColors.text(dlgCtx),
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cole o link de convite recebido pelo WhatsApp ou digite o código de token do seu personal:',
              style: TextStyle(
                color: MetaColors.subtext(dlgCtx),
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: codeCtrl,
              style: TextStyle(color: MetaColors.text(dlgCtx), fontSize: 14),
              decoration: InputDecoration(
                hintText: 'https://mrcoach.app/i/... ou token',
                hintStyle: TextStyle(
                  color: MetaColors.subtext(dlgCtx).withOpacity(0.5),
                ),
                filled: true,
                fillColor: MetaColors.bg(dlgCtx),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: MetaColors.cardBorder(dlgCtx)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: Text(
              'Cancelar',
              style: TextStyle(color: MetaColors.subtext(dlgCtx)),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final raw = codeCtrl.text.trim();
              if (raw.isEmpty) return;
              Navigator.pop(dlgCtx);
              final token =
                  raw.contains('/') ? raw.split('/').last.split('?').first : raw;
              await _linkWithInviteToken(token);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: MetaColors.emerald,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Vincular',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _linkWithInviteToken(String token) async {
    setState(() => _isLoadingTrainerInfo = true);
    try {
      await AuthService.consumeInviteToken(token);
      await _loadTrainerInfo();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: MetaColors.emerald,
            content: Text(
              'Vínculo com $_resolvedTrainerName ativado com sucesso!',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Código inválido ou expirado: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingTrainerInfo = false);
    }
  }

  Future<void> _submitAnamnesis() async {
    if (AuthService.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entre na sua conta para salvar sua avaliação.')),
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

      final parsedAge = int.parse(_ageCtrl.text.trim());
      final parsedWeight = double.parse(_weightCtrl.text.trim().replaceAll(',', '.'));
      final parsedHeight = double.parse(_heightCtrl.text.trim().replaceAll(',', '.'));

      final anamnesisPayload = {
        'client_id': clientId,
        'biological_sex': _biologicalSex,
        'age': parsedAge,
        'weight': parsedWeight,
        'height': parsedHeight,
        'daily_activity': _dailyActivity,
        'sleep_hours': _sleepHours,
        'stress_level': _stressLevel,
        'training_level': _trainingLevel,
        'training_history': _trainingHistory,
        'weekly_days': _weeklyDays,
        'preferred_days': _preferredDays.toList(),
        'session_duration': _sessionDuration,
        'cardio_preference': _cardioPreference,
        'clinical_conditions': _clinicalConditions.toList(),
        'injuries': selectedInjuries.toList(),
        'injuries_details': _injuriesDetailsCtrl.text.trim(),
        'injuries_summary': injuriesSummary,
        'workout_location': _workoutLocation,
        'available_equipment': _availableEquipment.toList(),
        'exercises_to_avoid': _avoidExercisesCtrl.text.trim(),
        'objective': _objective,
        'muscle_priorities': _musclePriorities.toList(),
        'training_style': _trainingStyle,
        'completed_at': DateTime.now().toIso8601String(),
        if (_trainerId != null) 'trainer_id': _trainerId,
      };

      final saved = await WorkoutService.saveClientAnamnesis(
        clientId: clientId,
        data: anamnesisPayload,
      );
      if (!saved) throw Exception('Não foi possível salvar sua avaliação. Tente novamente.');

      // Sincroniza Peso, Altura e Idade diretamente com o Bio-Hub 2.0 e Perfil
      try {
        await BodyMetricsService.saveMetrics(
          targetStudentId: clientId,
          weightKg: parsedWeight,
          heightCm: parsedHeight,
          notes: widget.isReviewMode ? 'Revisão de Anamnese' : 'Marco Inicial (Anamnese)',
        );
      } catch (_) {}

      try {
        final client = Supabase.instance.client;
        final normalizedHeight = parsedHeight < 3.0 ? (parsedHeight * 100).round() : parsedHeight.round();
        await client.from('profiles').update({
          'age': parsedAge,
          'weight_kg': parsedWeight,
          'height_cm': normalizedHeight,
          if (_trainerId != null && _trainerId!.isNotEmpty) 'trainer_id': _trainerId,
        }).eq('id', clientId);
      } catch (_) {}

      if (_trainerId != null && _trainerId!.isNotEmpty) {
        WorkoutService.notifyTrainerOnboardingCompleted(
          clientId: clientId,
          trainerId: _trainerId!,
          studentName: widget.studentName ??
              (user.userMetadata?['full_name'] as String?) ??
              'Sua Aluna',
          objective: _objective,
          trainingLevel: _trainingLevel,
          weeklyDays: _weeklyDays,
          injuriesOrRestrictions: injuriesSummary,
        );
      }

      if (mounted) {
        setState(() {
          _currentStep = 6;
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
    if (widget.isReviewMode) {
      Navigator.pop(context, true);
      return;
    }
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
    final isDark = MetaColors.isDark(context);

    return Scaffold(
      backgroundColor: MetaColors.bg(context),
      body: SafeArea(
        child: _currentStep == 0
            ? _buildWelcomeScreen(isDark)
            : _currentStep == 6
                ? _buildSuccessScreen(isDark)
                : _buildOnboardingStepScaffold(isDark),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // ETAPA 0: Tela Viral de Boas-Vindas (One UI 7 / Meta)
  // -------------------------------------------------------------------------
  Widget _buildWelcomeScreen(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Image.asset(
                    'assets/images/logo_shaipados.png',
                    height: 40,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: MetaColors.emerald,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Text(
                          'S',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
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
                          letterSpacing: 1.5,
                          color: MetaColors.text(context),
                        ),
                      ),
                      const Text(
                        'MR. COACH INTELLIGENCE',
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: MetaColors.emerald,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: MetaColors.emerald.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: MetaColors.emerald.withValues(alpha: 0.4),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lock_rounded, size: 12, color: MetaColors.emerald),
                    SizedBox(width: 4),
                    Text(
                      'CONVITE VIP',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: MetaColors.emerald,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 36),

          Text(
            'Seu Treinador Conectado.',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
              height: 1.15,
              color: MetaColors.text(context),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Responda a anamnese em 5 etapas rápidas. Seu personal terá os dados biomecânicos e clínicos necessários para prescrever seu treino exclusivo.',
            style: TextStyle(
              fontSize: 14.5,
              color: MetaColors.subtext(context),
              height: 1.45,
            ),
          ),

          const SizedBox(height: 28),

          // Card do Personal Trainer ou Hub do Aluno Explorador
          if (_trainerId != null && _trainerId!.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: MetaColors.card(context),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: MetaColors.cardBorder(context)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: MetaColors.highlight(context),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: MetaColors.emerald.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (_resolvedTrainerAvatarUrl != null &&
                            _resolvedTrainerAvatarUrl!.trim().isNotEmpty) ...[
                          ClipOval(
                            child: _resolvedTrainerAvatarUrl!.trim().startsWith('assets/')
                                ? Image.asset(
                                    _resolvedTrainerAvatarUrl!.trim(),
                                    width: 54,
                                    height: 54,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => Center(
                                      child: Text(
                                        _getTrainerInitials(),
                                        style: TextStyle(
                                          color: MetaColors.text(context),
                                          fontWeight: FontWeight.w900,
                                          fontSize: 18,
                                        ),
                                      ),
                                    ),
                                  )
                                : Image.network(
                                    _resolvedTrainerAvatarUrl!.trim(),
                                    width: 54,
                                    height: 54,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => Center(
                                      child: Text(
                                        _getTrainerInitials(),
                                        style: TextStyle(
                                          color: MetaColors.text(context),
                                          fontWeight: FontWeight.w900,
                                          fontSize: 18,
                                        ),
                                      ),
                                    ),
                                  ),
                          ),
                        ] else ...[
                          Center(
                            child: Text(
                              _getTrainerInitials(),
                              style: TextStyle(
                                color: MetaColors.text(context),
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ],
                        Positioned(
                          right: 2,
                          bottom: 2,
                          child: Container(
                            width: 13,
                            height: 13,
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981),
                              shape: BoxShape.circle,
                              border: Border.all(color: MetaColors.card(context), width: 2),
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
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                  color: MetaColors.text(context),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 5),
                            const Icon(
                              Icons.verified_rounded,
                              size: 16,
                              color: Color(0xFF38BDF8),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$_resolvedTrainerRegistry • Personal Trainer',
                          style: const TextStyle(
                            fontSize: 12,
                            color: MetaColors.emerald,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Aguardando sua avaliação para liberar sua periodização.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: MetaColors.subtext(context),
                          ),
                        ),
                        if (_isLoadingTrainerInfo) ...[
                          const SizedBox(height: 8),
                          const LinearProgressIndicator(color: MetaColors.emerald),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // HUB DO ALUNO EXPLORADOR
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: MetaColors.card(context),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: MetaColors.accentBlue.withValues(alpha: 0.35),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: MetaColors.accentBlue.withValues(alpha: 0.06),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: MetaColors.accentBlue.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.travel_explore_rounded,
                          color: MetaColors.accentBlue,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Aluno Explorador',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: MetaColors.text(context),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: MetaColors.accentBlue
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'DEGUSTAÇÃO',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      color: MetaColors.accentBlue,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Você ainda não possui um treinador conectado.',
                              style: TextStyle(
                                fontSize: 12,
                                color: MetaColors.subtext(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Você pode fazer sua avaliação biomecânica agora para calibrar seu treino experimental com IA, ou escolher um Personal Trainer credenciado na nossa Vitrine pública.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: MetaColors.subtext(context),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PublicTrainerDirectoryScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.storefront_rounded, size: 16),
                    label: const Text(
                      'Conhecer e Escolher Personal Trainer',
                      style:
                          TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MetaColors.accentBlue,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 42),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton.icon(
                      onPressed: _showRedeemInviteDialog,
                      icon: const Icon(Icons.link_rounded, size: 15),
                      label: const Text(
                        'Já tem um convite do seu personal? Inserir código',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: MetaColors.emerald,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                      ),
                    ),
                  ),
                  if (AuthService.isCurrentUserAdminSync()) ...[
                    const SizedBox(height: 4),
                    Center(
                      child: TextButton.icon(
                        onPressed: () async {
                          await AuthService.setActiveRole('trainer');
                          if (context.mounted) {
                            Navigator.pushReplacementNamed(
                                context, '/trainer');
                          }
                        },
                        icon: const Icon(Icons.sports_gymnastics, size: 15),
                        label: const Text(
                          'Alternar para Perfil de Professor / Admin',
                          style: TextStyle(fontSize: 11.5),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],

          const Spacer(),

          // Botão Iniciar Avaliação One UI 7 (Habilitado para todos!)
          InkWell(
            onTap: _isLoadingTrainerInfo
                ? null
                : () {
                    HapticFeedback.mediumImpact();
                    setState(() => _currentStep = 1);
                  },
            borderRadius: BorderRadius.circular(18),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                color: _isLoadingTrainerInfo
                    ? MetaColors.highlight(context)
                    : MetaColors.emerald,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _trainerId == null || _trainerId!.isEmpty
                        ? 'Iniciar Calibração Biomecânica (3 min)'
                        : 'Iniciar Avaliação (3 min)',
                    style: TextStyle(
                      color: _isLoadingTrainerInfo
                          ? MetaColors.subtext(context)
                          : Colors.black,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: _isLoadingTrainerInfo
                        ? MetaColors.subtext(context)
                        : Colors.black,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Garantia de sigilo médico e conformidade biomecânica.',
              style: TextStyle(fontSize: 11.5, color: MetaColors.subtext(context)),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // ESTRUTURA DO STEPPER (Passos 1 a 5 no Padrão One UI 7 / Meta)
  // -------------------------------------------------------------------------
  Widget _buildOnboardingStepScaffold(bool isDark) {
    return Column(
      children: [
        // Top Step Progress Header One UI 7
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 20, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                color: MetaColors.text(context),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  if (_currentStep == 1 && widget.isReviewMode) {
                    Navigator.pop(context);
                  } else {
                    setState(() => _currentStep--);
                  }
                },
              ),
              Column(
                children: [
                  Text(
                    widget.isReviewMode ? 'CHECK-IN BIOMÉDICO' : 'AVALIAÇÃO DO ALUNO',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: MetaColors.emerald,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Etapa $_currentStep de 5',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: MetaColors.text(context),
                    ),
                  ),
                ],
              ),
              if (widget.isReviewMode)
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 22),
                  color: MetaColors.subtext(context),
                  tooltip: 'Fechar',
                  onPressed: () => Navigator.pop(context),
                )
              else
                const SizedBox(width: 44),
            ],
          ),
        ),

        // Linear Progress Bar One UI 7
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          height: 5,
          decoration: BoxDecoration(
            color: MetaColors.highlight(context),
            borderRadius: BorderRadius.circular(10),
          ),
          child: LayoutBuilder(
            builder: (ctx, constraints) => Stack(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  width: constraints.maxWidth * (_currentStep / 5.0),
                  decoration: BoxDecoration(
                    color: MetaColors.emerald,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Step Content Body
        Expanded(
          child: Form(
            key: _stepFormKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
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

        // Bottom Navigation Bar One UI 7
        Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
          decoration: BoxDecoration(
            color: MetaColors.card(context),
            border: Border(
              top: BorderSide(color: MetaColors.cardBorder(context)),
            ),
          ),
          child: InkWell(
            onTap: _isSubmitting
                ? null
                : () {
                    HapticFeedback.lightImpact();
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
            borderRadius: BorderRadius.circular(18),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: MetaColors.emerald,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Center(
                child: _isSubmitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.black,
                          strokeWidth: 2.2,
                        ),
                      )
                    : Text(
                        _currentStep < 5
                            ? 'Continuar →'
                            : 'Enviar Avaliação ao Treinador ✓',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // ETAPA 1: Biometria, Sexo Biológico & Sono/Estresse
  // -------------------------------------------------------------------------
  Widget _buildStep1Biometrics() {
    final bmiText = _calculateBmi();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Perfil Biométrico & Rotina',
          'Fundamental para estimar sua taxa metabólica, recuperação tecidual e distribuição de volume.',
        ),
        const SizedBox(height: 22),

        // Sexo Biológico One UI 7
        _buildLabel('Sexo Biológico (Fórmulas metabólicas & hormonais)'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildSelectablePill(
                label: 'Masculino',
                icon: Icons.male_rounded,
                isSelected: _biologicalSex == 'Masculino',
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _biologicalSex = 'Masculino');
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildSelectablePill(
                label: 'Feminino',
                icon: Icons.female_rounded,
                isSelected: _biologicalSex == 'Feminino',
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _biologicalSex = 'Feminino');
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Idade, Peso e Altura em 3 colunas táteis
        _buildLabel('Medidas Principais'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildBiometricField(
                label: 'Idade',
                unit: 'anos',
                ctrl: _ageCtrl,
                keyboardType: TextInputType.number,
                validator: (input) {
                  final v = int.tryParse(input?.trim() ?? '');
                  if (v == null || v < 10 || v > 100) return 'Inválido';
                  return null;
                },
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildBiometricField(
                label: 'Peso',
                unit: 'kg',
                ctrl: _weightCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (input) {
                  final v = double.tryParse((input ?? '').trim().replaceAll(',', '.'));
                  if (v == null || v < 25 || v > 300) return 'Inválido';
                  return null;
                },
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildBiometricField(
                label: 'Altura',
                unit: 'cm',
                ctrl: _heightCtrl,
                keyboardType: TextInputType.number,
                validator: (input) {
                  final v = int.tryParse(input?.trim() ?? '');
                  if (v == null || v < 100 || v > 240) return 'Inválido';
                  return null;
                },
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),

        // IMC Informativo em Tempo Real
        if (bmiText != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: MetaColors.emerald.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: MetaColors.emerald.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.bolt_rounded, size: 16, color: MetaColors.emerald),
                const SizedBox(width: 8),
                Text(
                  bmiText,
                  style: const TextStyle(
                    color: MetaColors.emerald,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 22),

        // Nível de Atividade Diária / NEAT
        _buildLabel('Rotina de Trabalho & Atividade Diária'),
        const SizedBox(height: 8),
        _buildSelectionCard(
          title: 'Sedentário',
          subtitle: 'Trabalho sentado / mesa maior parte do dia',
          icon: Icons.chair_rounded,
          isSelected: _dailyActivity.contains('Sedentário'),
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _dailyActivity = 'Sedentário (Trabalho em mesa / pouca caminhada)');
          },
        ),
        const SizedBox(height: 8),
        _buildSelectionCard(
          title: 'Moderadamente Ativo',
          subtitle: 'Boa parte do dia em pé, deslocamentos a pé frequentes',
          icon: Icons.directions_walk_rounded,
          isSelected: _dailyActivity.contains('Moderada') || _dailyActivity.contains('Moderado'),
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _dailyActivity = 'Moderado (Boa parte do dia em pé ou caminhando)');
          },
        ),
        const SizedBox(height: 8),
        _buildSelectionCard(
          title: 'Muito Ativo / Braçal',
          subtitle: 'Trabalho físico contínuo ou treinos múltiplos',
          icon: Icons.flash_on_rounded,
          isSelected: _dailyActivity.contains('Ativo') || _dailyActivity.contains('Braçal'),
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _dailyActivity = 'Ativo (Trabalho braçal ou atividade física contínua)');
          },
        ),

        const SizedBox(height: 22),

        // Média de Sono
        _buildLabel('Média de Sono por Noite'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ['Menos de 6h', '6 a 7 horas', '7 a 8 horas', 'Mais de 8h'].map((s) {
            final isSel = _sleepHours.contains(s.split(' ')[0]);
            return _buildOptionChip(
              label: s,
              isSelected: isSel,
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _sleepHours = s);
              },
            );
          }).toList(),
        ),

        const SizedBox(height: 22),

        // Nível de Estresse
        _buildLabel('Nível de Estresse / Carga de Cortisol'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildSelectablePill(
                label: 'Baixo',
                icon: Icons.sentiment_satisfied_alt_rounded,
                isSelected: _stressLevel == 'Baixo',
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _stressLevel = 'Baixo');
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSelectablePill(
                label: 'Moderado',
                icon: Icons.sentiment_neutral_rounded,
                isSelected: _stressLevel == 'Moderado',
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _stressLevel = 'Moderado');
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSelectablePill(
                label: 'Elevado',
                icon: Icons.sentiment_very_dissatisfied_rounded,
                isSelected: _stressLevel == 'Elevado',
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _stressLevel = 'Elevado');
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // ETAPA 2: Experiência, Frequência Semanal & Cardio
  // -------------------------------------------------------------------------
  Widget _buildStep2Experience() {
    final daysOfWeek = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Experiência & Disponibilidade',
          'Ajusta o volume semanal de séries e a curva de adaptação neuromuscular do plano.',
        ),
        const SizedBox(height: 22),

        // Nível de Musculação
        _buildLabel('Nível de Experiência Atual'),
        const SizedBox(height: 8),
        _buildSelectionCard(
          title: 'Iniciante',
          subtitle: 'Menos de 6 meses de treino contínuo ou retornando agora',
          icon: Icons.fitness_center_outlined,
          isSelected: _trainingLevel.contains('Iniciante'),
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _trainingLevel = 'Iniciante (<6 meses)');
          },
        ),
        const SizedBox(height: 8),
        _buildSelectionCard(
          title: 'Intermediário',
          subtitle: '6 meses a 2 anos de treino consistente e boa técnica',
          icon: Icons.fitness_center_rounded,
          isSelected: _trainingLevel.contains('Intermediário'),
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _trainingLevel = 'Intermediário (6m a 2 anos)');
          },
        ),
        const SizedBox(height: 8),
        _buildSelectionCard(
          title: 'Avançado',
          subtitle: '+2 anos ininterruptos com domínio de cargas e periodização',
          icon: Icons.workspace_premium_rounded,
          isSelected: _trainingLevel.contains('Avançado'),
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _trainingLevel = 'Avançado (+2 anos)');
          },
        ),

        const SizedBox(height: 22),

        // Tempo de Prática Contínua
        _buildLabel('Há quanto tempo você treina de forma consistente?'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            '< 6 meses',
            '6 meses a 1 ano',
            '1 a 3 anos',
            '+3 anos',
          ].map((hist) {
            final isSel = _trainingHistory == hist;
            return _buildOptionChip(
              label: hist,
              isSelected: isSel,
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _trainingHistory = hist);
              },
            );
          }).toList(),
        ),

        const SizedBox(height: 22),

        // Frequência Semanal
        _buildLabel('Quantos dias por semana pretende treinar?'),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [2, 3, 4, 5, 6].map((days) {
            final isSel = _weeklyDays == days;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _weeklyDays = days);
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSel ? MetaColors.emerald : MetaColors.card(context),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSel ? MetaColors.emerald : MetaColors.cardBorder(context),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${days}x',
                        style: TextStyle(
                          color: isSel ? Colors.black : MetaColors.text(context),
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 22),

        // Dias preferidos da semana
        _buildLabel('Quais dias da semana prefere treinar? (Toque para selecionar)'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 8,
          children: daysOfWeek.map((day) {
            final isSel = _preferredDays.contains(day);
            return InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  if (isSel) {
                    if (_preferredDays.length > 1) _preferredDays.remove(day);
                  } else {
                    _preferredDays.add(day);
                  }
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isSel
                      ? MetaColors.emerald.withValues(alpha: 0.16)
                      : MetaColors.card(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSel
                        ? MetaColors.emerald
                        : MetaColors.cardBorder(context),
                  ),
                ),
                child: Text(
                  day,
                  style: TextStyle(
                    color: isSel ? MetaColors.emerald : MetaColors.text(context),
                    fontWeight: isSel ? FontWeight.w800 : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 22),

        // Duração da Sessão
        _buildLabel('Tempo Médio Disponível por Sessão'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            '30 a 45 min',
            '45 a 60 min',
            '60 minutos',
            '75 a 90 min',
          ].map((dur) {
            final isSel = _sessionDuration.contains(dur.split(' ')[0]);
            return _buildOptionChip(
              label: dur,
              isSelected: isSel,
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _sessionDuration = dur);
              },
            );
          }).toList(),
        ),

        const SizedBox(height: 22),

        // Preferência de Cardio
        _buildLabel('Incluir Treino Aeróbio / Cardio?'),
        const SizedBox(height: 8),
        Column(
          children: [
            _buildSelectionCard(
              title: 'Sim, logo após a musculação',
              subtitle: '15 a 30 min no mesmo dia (esteira, bike, etc.)',
              icon: Icons.directions_run_rounded,
              isSelected: _cardioPreference.contains('Pós-musculação') ||
                  _cardioPreference.contains('Pós-treino'),
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _cardioPreference = 'Sim (Pós-musculação)');
              },
            ),
            const SizedBox(height: 8),
            _buildSelectionCard(
              title: 'Sim, em horário ou dias separados',
              subtitle: 'Cardio em turno oposto ou nos dias de descanso',
              icon: Icons.timer_outlined,
              isSelected: _cardioPreference.contains('outro turno') ||
                  _cardioPreference.contains('separado'),
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _cardioPreference = 'Sim (Em turno separado)');
              },
            ),
            const SizedBox(height: 8),
            _buildSelectionCard(
              title: 'Apenas musculação por enquanto',
              subtitle: 'Foco total no ganho de força e hipertrofia',
              icon: Icons.block_rounded,
              isSelected: _cardioPreference.contains('Apenas'),
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _cardioPreference = 'Apenas musculação');
              },
            ),
          ],
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // ETAPA 3: Triagem de Saúde (PAR-Q) & Mapeamento Articular
  // -------------------------------------------------------------------------
  Widget _buildStep3Injuries() {
    final clinicalOptions = [
      'Nenhuma restrição médica',
      'Hipertensão arterial',
      'Diabetes / Resistência à insulina',
      'Problemas cardíacos',
      'Labirintite / Tonturas',
      'Hérnia de disco / Coluna',
      'Gestante',
    ];

    final jointOptions = [
      kNoRestriction,
      'Ombro (Manguito/Impacto)',
      'Joelho (Patela/Menisco)',
      'Lombar / Coluna',
      'Quadril',
      'Cotovelo (Epicondilite)',
      'Punho',
      'Tornozelo',
      'Cervical',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Saúde & Mapeamento Articular',
          'Segurança biomecânica: estes dados impedem que o sistema e seu treinador prescrevam ângulos ou vetores de sobrecarga lesiva.',
        ),
        const SizedBox(height: 22),

        // Triagem Clínica PAR-Q
        _buildLabel('Triagem de Saúde Geral (PAR-Q)'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: clinicalOptions.map((cond) {
            final isSel = _clinicalConditions.contains(cond);
            return _buildFilterChipOneUi(
              label: cond,
              isSelected: isSel,
              onSelected: (selected) {
                HapticFeedback.selectionClick();
                setState(() {
                  if (cond == 'Nenhuma restrição médica') {
                    _clinicalConditions.clear();
                    if (selected) _clinicalConditions.add(cond);
                  } else {
                    _clinicalConditions.remove('Nenhuma restrição médica');
                    if (selected) {
                      _clinicalConditions.add(cond);
                    } else {
                      _clinicalConditions.remove(cond);
                      if (_clinicalConditions.isEmpty) {
                        _clinicalConditions.add('Nenhuma restrição médica');
                      }
                    }
                  }
                });
              },
            );
          }).toList(),
        ),

        const SizedBox(height: 24),

        // Mapeamento Articular
        _buildLabel('Articulações com Desconforto ou Histórico de Lesão'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: jointOptions.map((joint) {
            final isSel = _selectedInjuries.contains(joint);
            return _buildFilterChipOneUi(
              label: joint,
              isSelected: isSel,
              onSelected: (selected) {
                HapticFeedback.selectionClick();
                setState(() {
                  if (joint == kNoRestriction) {
                    _selectedInjuries.clear();
                    if (selected) _selectedInjuries.add(joint);
                  } else {
                    _selectedInjuries.remove(kNoRestriction);
                    if (selected) {
                      _selectedInjuries.add(joint);
                    } else {
                      _selectedInjuries.remove(joint);
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

        const SizedBox(height: 24),

        // Detalhes Médicos
        _buildLabel('Detalhes ou Diagnósticos Médicos (Opcional)'),
        const SizedBox(height: 8),
        TextFormField(
          controller: _injuriesDetailsCtrl,
          maxLines: 3,
          style: TextStyle(color: MetaColors.text(context), fontSize: 13.5),
          decoration: InputDecoration(
            hintText: 'Ex: Tenho leve condromalácia no joelho esquerdo quando agacho abaixo de 90°...',
            hintStyle: TextStyle(color: MetaColors.subtext(context).withValues(alpha: 0.6), fontSize: 12.5),
            filled: true,
            fillColor: MetaColors.card(context),
            contentPadding: const EdgeInsets.all(16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: MetaColors.cardBorder(context)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: MetaColors.emerald),
            ),
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // ETAPA 4: Espaço de Treino & Estrutura
  // -------------------------------------------------------------------------
  Widget _buildStep4Environment() {
    final equipmentOptions = [
      'Halteres',
      'Barras e Anilhas',
      'Polia / Cabos',
      'Máquinas Articuladas',
      'Smith Machine',
      'Leg Press',
      'Barra Fixa / Paralelas',
      'Elásticos / Bands',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Espaço de Treino & Equipamentos',
          'Garante que as prescrições utilizem apenas os aparelhos que você realmente tem à disposição.',
        ),
        const SizedBox(height: 22),

        // Ambiente Principal
        _buildLabel('Onde você irá treinar?'),
        const SizedBox(height: 8),
        _buildSelectionCard(
          title: 'Academia Comercial Completa',
          subtitle: 'Smart Fit, Bluefit, Ironberg, Bodytech ou similar',
          icon: Icons.domain_rounded,
          isSelected: _workoutLocation.contains('comercial') || _workoutLocation.contains('completa'),
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _workoutLocation = 'Academia comercial completa');
          },
        ),
        const SizedBox(height: 8),
        _buildSelectionCard(
          title: 'Academia de Condomínio / Prédio',
          subtitle: 'Equipamentos selecionados ou halteres até peso moderado',
          icon: Icons.apartment_rounded,
          isSelected: _workoutLocation.contains('condomínio') || _workoutLocation.contains('prédio'),
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _workoutLocation = 'Espaço de musculação em condomínio / prédio');
          },
        ),
        const SizedBox(height: 8),
        _buildSelectionCard(
          title: 'Em Casa / Calistenia',
          subtitle: 'Halteres ajustáveis, elásticos e peso corporal',
          icon: Icons.home_rounded,
          isSelected: _workoutLocation.contains('casa') || _workoutLocation.contains('calistenia'),
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _workoutLocation = 'Em casa (Halteres, elásticos e peso corporal)');
          },
        ),
        const SizedBox(height: 8),
        _buildSelectionCard(
          title: 'Studio / Box de Funcional',
          subtitle: 'Espaço com barras olímpicas, kettlebells e racks',
          icon: Icons.sports_gymnastics_rounded,
          isSelected: _workoutLocation.contains('Studio') || _workoutLocation.contains('Box'),
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _workoutLocation = 'Studio / Box de Funcional');
          },
        ),

        const SizedBox(height: 24),

        // Equipamentos disponíveis
        _buildLabel('Equipamentos Disponíveis no seu Local (Toque para marcar)'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: equipmentOptions.map((eq) {
            final isSel = _availableEquipment.contains(eq);
            return _buildFilterChipOneUi(
              label: eq,
              isSelected: isSel,
              onSelected: (selected) {
                HapticFeedback.selectionClick();
                setState(() {
                  if (selected) {
                    _availableEquipment.add(eq);
                  } else {
                    _availableEquipment.remove(eq);
                  }
                });
              },
            );
          }).toList(),
        ),

        const SizedBox(height: 24),

        // Exercícios que prefere evitar
        _buildLabel('Exercícios que você prefere evitar ou não gosta (Opcional)'),
        const SizedBox(height: 8),
        TextFormField(
          controller: _avoidExercisesCtrl,
          maxLines: 2,
          style: TextStyle(color: MetaColors.text(context), fontSize: 13.5),
          decoration: InputDecoration(
            hintText: 'Ex: Agachamento livre com barra nas costas, elevação frontal...',
            hintStyle: TextStyle(color: MetaColors.subtext(context).withValues(alpha: 0.6), fontSize: 12.5),
            filled: true,
            fillColor: MetaColors.card(context),
            contentPadding: const EdgeInsets.all(16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: MetaColors.cardBorder(context)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: MetaColors.emerald),
            ),
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // ETAPA 5: Metas Estéticas, Focos & Estilo de Treino
  // -------------------------------------------------------------------------
  Widget _buildStep5Goals() {
    final muscleOptions = [
      'Peitoral',
      'Costas / Dorsais',
      'Ombros',
      'Quadríceps',
      'Glúteos',
      'Posteriores de Coxa',
      'Braços (Bíceps/Tríceps)',
      'Abdômen / Core',
      'Panturrilhas',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Metas & Prioridades Estéticas',
          'Personaliza as ênfases de volume e a intensidade metabólica do seu treino.',
        ),
        const SizedBox(height: 22),

        // Objetivo Principal
        _buildLabel('Objetivo Principal de Resultado'),
        const SizedBox(height: 8),
        _buildSelectionCard(
          title: 'Hipertrofia Muscular',
          subtitle: 'Ganho acelerado de massa muscular e volume estético',
          icon: Icons.fitness_center_rounded,
          isSelected: _objective == 'Hipertrofia Muscular',
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _objective = 'Hipertrofia Muscular');
          },
        ),
        const SizedBox(height: 8),
        _buildSelectionCard(
          title: 'Emagrecimento & Definição',
          subtitle: 'Queima de gordura preservando o tônus muscular',
          icon: Icons.local_fire_department_rounded,
          isSelected: _objective.contains('Emagrecimento') || _objective.contains('Definição'),
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _objective = 'Emagrecimento & Definição');
          },
        ),
        const SizedBox(height: 8),
        _buildSelectionCard(
          title: 'Recomposição Corporal',
          subtitle: 'Perda simultânea de gordura com ganho de massa magra',
          icon: Icons.swap_horiz_rounded,
          isSelected: _objective.contains('Recomposição'),
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _objective = 'Recomposição Corporal');
          },
        ),
        const SizedBox(height: 8),
        _buildSelectionCard(
          title: 'Força Máxima & Performance',
          subtitle: 'Progressão agressiva de carga e capacidade atlética',
          icon: Icons.bolt_rounded,
          isSelected: _objective.contains('Força') || _objective.contains('Performance'),
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _objective = 'Força & Performance Atlética');
          },
        ),
        const SizedBox(height: 8),
        _buildSelectionCard(
          title: 'Reabilitação & Longevidade',
          subtitle: 'Correção postural, mobilidade e fortalecimento preventivo',
          icon: Icons.spa_rounded,
          isSelected: _objective.contains('Reabilitação') || _objective.contains('Longevidade'),
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _objective = 'Reabilitação Postural & Longevidade');
          },
        ),

        const SizedBox(height: 24),

        // Prioridade Muscular
        _buildLabel('Músculos com Maior Prioridade (Foco de Volume)'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: muscleOptions.map((m) {
            final isSel = _musclePriorities.contains(m);
            return _buildFilterChipOneUi(
              label: m,
              isSelected: isSel,
              onSelected: (selected) {
                HapticFeedback.selectionClick();
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

        const SizedBox(height: 24),

        // Estilo de Treino
        _buildLabel('Estilo de Treino de sua Preferência'),
        const SizedBox(height: 8),
        Column(
          children: [
            _buildSelectionCard(
              title: 'Cargas Mais Altas & Força',
              subtitle: '6 a 10 repetições, mais descanso e tensão mecânica',
              icon: Icons.trending_up_rounded,
              isSelected: _trainingStyle.contains('Carga'),
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _trainingStyle = 'Cargas Mais Altas (Força / Tensão)');
              },
            ),
            const SizedBox(height: 8),
            _buildSelectionCard(
              title: 'Mais Repetições & Pump',
              subtitle: '10 a 15 repetições, menor descanso e estresse metabólico',
              icon: Icons.bloodtype_outlined,
              isSelected: _trainingStyle.contains('Pump') || _trainingStyle.contains('Mais Reps'),
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _trainingStyle = 'Mais Reps & Pump (Estresse Metabólico)');
              },
            ),
            const SizedBox(height: 8),
            _buildSelectionCard(
              title: 'Equilibrado / Híbrido',
              subtitle: 'Mix balanceado entre movimentos pesados e isoladores',
              icon: Icons.tune_rounded,
              isSelected: _trainingStyle.contains('Equilibrado'),
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _trainingStyle = 'Equilibrado (Carga + Pump)');
              },
            ),
          ],
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // ETAPA 6: Tela de Sucesso One UI 7
  // -------------------------------------------------------------------------
  Widget _buildSuccessScreen(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: MetaColors.emerald.withValues(alpha: 0.16),
              shape: BoxShape.circle,
              border: Border.all(color: MetaColors.emerald, width: 2),
            ),
            child: const Icon(
              Icons.check_rounded,
              color: MetaColors.emerald,
              size: 46,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _trainerId == null || _trainerId!.isEmpty
                ? 'Calibração Concluída!'
                : 'Avaliação Concluída!',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              color: MetaColors.text(context),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _trainerId == null || _trainerId!.isEmpty
                ? 'Seus dados biomédicos e objetivos foram salvos com sucesso. Quando você contratar um Personal Trainer na Vitrine, ele receberá sua ficha completa pronta para prescrição.'
                : 'Seus dados biomédicos e preferências foram salvos e transmitidos com segurança para o $_resolvedTrainerName.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: MetaColors.subtext(context),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 26),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: MetaColors.card(context),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: MetaColors.cardBorder(context)),
            ),
            child: Row(
              children: [
                Icon(
                  _trainerId == null || _trainerId!.isEmpty
                      ? Icons.verified_user_rounded
                      : Icons.mark_chat_read_rounded,
                  color: MetaColors.emerald,
                  size: 24,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    _trainerId == null || _trainerId!.isEmpty
                        ? 'Você já pode experimentar a plataforma ou escolher um Personal credenciado na nossa Vitrine.'
                        : 'Seu treinador foi alertado em tempo real e já pode prescrever sua periodização personalizada.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: MetaColors.text(context),
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Indução inteligente de instalação do PWA na tela inicial
          const PwaInstallPromptCard(
            title: 'Instale o App para seus Treinos',
            subtitle: 'Adicione à tela inicial para abrir seus treinos na academia sem barras de navegador, com suporte offline e alertas instantâneos.',
            margin: EdgeInsets.only(top: 20),
          ),
          const SizedBox(height: 24),
          if (_trainerId == null || _trainerId!.isEmpty) ...[
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PublicTrainerDirectoryScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.storefront_rounded, size: 18),
              label: const Text(
                'Escolher Meu Personal na Vitrine',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: MetaColors.accentBlue,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          InkWell(
            onTap: () {
              HapticFeedback.mediumImpact();
              _finishAndEnterApp();
            },
            borderRadius: BorderRadius.circular(18),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                color: _trainerId == null || _trainerId!.isEmpty
                    ? MetaColors.card(context)
                    : MetaColors.emerald,
                border: _trainerId == null || _trainerId!.isEmpty
                    ? Border.all(color: MetaColors.cardBorder(context))
                    : null,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.isReviewMode
                        ? 'Concluir e Voltar ao Perfil'
                        : (_trainerId == null || _trainerId!.isEmpty
                            ? 'Entrar no Espaço de Treino (Degustação)'
                            : 'Entrar no Espaço de Treino'),
                    style: TextStyle(
                      color: _trainerId == null || _trainerId!.isEmpty
                          ? MetaColors.text(context)
                          : Colors.black,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: _trainerId == null || _trainerId!.isEmpty
                        ? MetaColors.text(context)
                        : Colors.black,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // COMPONENTES ATÔMICOS ONE UI 7 / META
  // -------------------------------------------------------------------------
  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.4,
            color: MetaColors.text(context),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 13,
            color: MetaColors.subtext(context),
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: MetaColors.text(context),
        letterSpacing: -0.1,
      ),
    );
  }

  Widget _buildBiometricField({
    required String label,
    required String unit,
    required TextEditingController ctrl,
    required TextInputType keyboardType,
    required String? Function(String?) validator,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: MetaColors.subtext(context),
          ),
        ),
        const SizedBox(height: 5),
        TextFormField(
          controller: ctrl,
          keyboardType: keyboardType,
          validator: validator,
          onChanged: onChanged,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: MetaColors.text(context),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          decoration: InputDecoration(
            suffixText: unit,
            suffixStyle: TextStyle(
              color: MetaColors.subtext(context),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            filled: true,
            fillColor: MetaColors.card(context),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: MetaColors.cardBorder(context)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: MetaColors.emerald),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectablePill({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? MetaColors.emerald.withValues(alpha: 0.16)
              : MetaColors.card(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? MetaColors.emerald : MetaColors.cardBorder(context),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? MetaColors.emerald : MetaColors.subtext(context),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? MetaColors.emerald : MetaColors.text(context),
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? MetaColors.emerald.withValues(alpha: 0.14)
              : MetaColors.card(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? MetaColors.emerald : MetaColors.cardBorder(context),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isSelected
                    ? MetaColors.emerald.withValues(alpha: 0.22)
                    : MetaColors.highlight(context),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected ? MetaColors.emerald : MetaColors.subtext(context),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? MetaColors.emerald : MetaColors.text(context),
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: MetaColors.subtext(context),
                      fontSize: 11.5,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? MetaColors.emerald : Colors.transparent,
                border: Border.all(
                  color: isSelected ? MetaColors.emerald : MetaColors.subtext(context),
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? const Center(
                      child: Icon(Icons.check, size: 13, color: Colors.black),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? MetaColors.emerald.withValues(alpha: 0.16)
              : MetaColors.card(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? MetaColors.emerald : MetaColors.cardBorder(context),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? MetaColors.emerald : MetaColors.text(context),
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            fontSize: 12.5,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChipOneUi({
    required String label,
    required bool isSelected,
    required ValueChanged<bool> onSelected,
  }) {
    return InkWell(
      onTap: () => onSelected(!isSelected),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected
              ? MetaColors.emerald.withValues(alpha: 0.16)
              : MetaColors.card(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? MetaColors.emerald : MetaColors.cardBorder(context),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              const Icon(Icons.check_rounded, size: 14, color: MetaColors.emerald),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected ? MetaColors.emerald : MetaColors.text(context),
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
