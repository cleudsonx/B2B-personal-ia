// ignore_for_file: unused_element, unused_local_variable, unused_field, override_on_non_overriding_member, use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/widgets/meta_components.dart';
import '../../../../core/widgets/avatar_selector_sheet.dart';
import '../../../../core/utils/pwa_navigation_state.dart';
import '../../../../core/utils/currency_pt_br_formatter.dart';
import '../../../../services/auth_service.dart';
import '../../../../services/consultancy_plan_service.dart';
import 'trainer_main_layout.dart';
import 'whatsapp_connection_screen.dart';

class TrainerProfileSetupScreen extends StatefulWidget {
  final Map<String, dynamic>? initialProfile;
  const TrainerProfileSetupScreen({super.key, this.initialProfile});

  @override
  State<TrainerProfileSetupScreen> createState() =>
      _TrainerProfileSetupScreenState();
}

class _TrainerProfileSetupScreenState extends State<TrainerProfileSetupScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _crefController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _whatsappController = TextEditingController();
  final TextEditingController _photoUrlController = TextEditingController();

  final List<String> _specialties = [
    'Hipertrofia',
    'Emagrecimento',
    'Condicionamento',
    'Reabilitação',
    'Mobilidade',
    'Powerlifting',
  ];
  final Set<String> _selectedSpecialties = {};
  bool _isSaving = false;
  bool _isLoading = true;
  bool _publishInDirectory = false;
  bool _autoSeedPlans = true;

  int get _completedTriadCount {
    int count = 0;
    if (_photoUrlController.text.trim().isNotEmpty) count++;
    final digits = _whatsappController.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 10) count++;
    if (_crefController.text.trim().isNotEmpty) count++;
    return count;
  }

  bool get _isTriadComplete => _completedTriadCount == 3;

  @override
  void initState() {
    super.initState();
    PwaNavigationState.saveActiveSubscreen('trainer_profile_setup');
    _photoUrlController.addListener(_onFieldChanged);
    _whatsappController.addListener(_onFieldChanged);
    _crefController.addListener(_onFieldChanged);
    _loadProfile();
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadProfile() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final profile = widget.initialProfile ?? await AuthService.getCurrentProfile();
      if (profile != null && mounted) {
        setState(() {
          _usernameController.text = profile['username'] ?? '';
          _bioController.text = profile['bio'] ?? '';
          _whatsappController.text = profile['public_whatsapp'] ??
              profile['phone'] ??
              '';
          _crefController.text = profile['professional_document'] ??
              profile['cref_or_registry'] ??
              '';
          _photoUrlController.text =
              profile['photo_url'] ?? profile['avatar_url'] ?? '';
          _publishInDirectory = profile['public_directory_enabled'] == true;

          if (profile['specialties'] != null) {
            final specs = List<String>.from(profile['specialties']);
            _selectedSpecialties.clear();
            _selectedSpecialties.addAll(specs);
          }
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar perfil do treinador: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    PwaNavigationState.clearActiveSubscreen();
    _photoUrlController.removeListener(_onFieldChanged);
    _whatsappController.removeListener(_onFieldChanged);
    _crefController.removeListener(_onFieldChanged);
    _usernameController.dispose();
    _crefController.dispose();
    _bioController.dispose();
    _whatsappController.dispose();
    _photoUrlController.dispose();
    super.dispose();
  }

  void _leaveProfileSetup() {
    PwaNavigationState.clearActiveSubscreen();
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      navigator.pushReplacement(
        MaterialPageRoute(builder: (_) => const TrainerMainLayout()),
      );
    }
  }

  void _showValidationError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _handleAvatarSelected(String selected) async {
    _photoUrlController.text = selected;
    if (mounted) setState(() {});

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user != null) {
        await supabase.from('profiles').update({
          'photo_url': selected,
          'avatar_url': selected,
        }).eq('id', user.id);

        await supabase.auth.updateUser(
          UserAttributes(data: {
            'photo_url': selected,
            'avatar_url': selected,
          }),
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Foto de perfil atualizada com sucesso!',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            backgroundColor: MetaColors.emerald,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 2),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      debugPrint('Aviso ao sincronizar foto de perfil: $e');
    }
  }

  Future<void> _saveProfile() async {
    if (_isLoading) return;
    final username = _usernameController.text.trim().toLowerCase();
    final usernamePattern = RegExp(r'^[a-z0-9][a-z0-9_.-]{1,28}[a-z0-9]$');
    if (username.isNotEmpty && !usernamePattern.hasMatch(username)) {
      _showValidationError(
        'O username deve ter de 3 a 30 caracteres, começar e terminar com letra ou número, e pode conter ponto, hífen ou sublinhado.',
      );
      return;
    }

    final whatsapp = _whatsappController.text.trim();
    final whatsappDigits = whatsapp.replaceAll(RegExp(r'\D'), '');
    final validBrazilianPhone =
        whatsapp.isEmpty ||
        ((whatsappDigits.length == 10 || whatsappDigits.length == 11) ||
            ((whatsappDigits.length == 12 || whatsappDigits.length == 13) &&
                whatsappDigits.startsWith('55')));
    if (!validBrazilianPhone) {
      _showValidationError(
        'Informe um WhatsApp brasileiro com DDD, usando opcionalmente o código 55.',
      );
      return;
    }

    if (_publishInDirectory &&
        (username.isEmpty ||
            _bioController.text.trim().isEmpty ||
            !_crefController.text.trim().toUpperCase().startsWith('CREF'))) {
      _showValidationError(
        'Para publicar no diretório, informe username, biografia e registro CREF válido (ex: CREF 012345-G/SP).',
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('Usuário não autenticado');

      final photoVal = _photoUrlController.text.trim();
      final crefVal = _crefController.text.trim();
      final updates = <String, dynamic>{
        'username': username.isEmpty ? null : username,
        'bio': _bioController.text.trim().isEmpty
            ? null
            : _bioController.text.trim(),
        'phone': whatsappDigits.isEmpty ? null : whatsappDigits,
        'public_whatsapp': whatsappDigits.isEmpty ? null : whatsappDigits,
        'professional_document': crefVal.isEmpty ? null : crefVal,
        'public_directory_enabled': _publishInDirectory,
        'specialties': _selectedSpecialties.toList(),
        'photo_url': photoVal.isEmpty ? null : photoVal,
        'avatar_url': photoVal.isEmpty ? null : photoVal,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      await supabase.from('profiles').update(updates).eq('id', user.id);

      try {
        await supabase.auth.updateUser(
          UserAttributes(data: {
            'username': username.isEmpty ? null : username,
            'bio': _bioController.text.trim().isEmpty ? null : _bioController.text.trim(),
            'phone': whatsappDigits.isEmpty ? null : whatsappDigits,
            'public_whatsapp': whatsappDigits.isEmpty ? null : whatsappDigits,
            'professional_document': crefVal.isEmpty ? null : crefVal,
            'photo_url': photoVal.isEmpty ? null : photoVal,
            'avatar_url': photoVal.isEmpty ? null : photoVal,
          }),
        );
      } catch (_) {}

      if (_autoSeedPlans) {
        try {
          final existingPlans = await ConsultancyPlanService.getMyPlans();
          if (existingPlans.isEmpty) {
            final defaults = ConsultancyPlanService.getDefaultTemplates();
            for (final tpl in defaults) {
              await ConsultancyPlanService.createPlan(
                name: tpl.name,
                description: tpl.description,
                priceCents: tpl.priceCents,
                billingPeriod: tpl.billingPeriod,
                features: tpl.features,
                isActive: true,
                sortOrder: tpl.sortOrder,
              );
            }
          }
        } catch (e) {
          debugPrint('Aviso ao inicializar planos padrão: $e');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Vitrine salva com sucesso!',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            backgroundColor: MetaColors.emerald,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
          ),
        );
        _leaveProfileSetup();
      }
    } catch (e) {
      if (mounted) {
        String message = 'Não foi possível salvar a vitrine. Verifique os dados e tente novamente.';
        if (e is PostgrestException) {
          if (e.code == '23505') {
            message = 'Este username já está em uso. Escolha outro endereço para sua vitrine.';
          } else {
            message = 'Erro no banco (${e.code}): ${e.message}';
          }
        } else if (e is StateError) {
          message = e.message;
        } else {
          message = 'Erro ao salvar: $e';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message, style: const TextStyle(color: Colors.white)),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _generateAiBio() {
    final specs = _selectedSpecialties.toList();
    final specText = specs.isEmpty
        ? 'hipertrofia, emagrecimento e definição física'
        : specs.join(', ').toLowerCase();

    final bio = 'Personal Trainer especialista em $specText. '
        'Metodologia fundamentada em biomecânica e fisiologia do exercício, com prescrição 100% individualizada no app. '
        'Acompanhamento próximo de cargas, suporte direto via WhatsApp e periodização inteligente para você atingir seu melhor físico com segurança e consistência.';

    setState(() {
      _bioController.text = bio;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Expanded(child: Text('Bio profissional gerada pela IA com foco em conversão!')),
          ],
        ),
        backgroundColor: MetaColors.emerald,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = MetaColors.isDark(context);
    final textTheme = Theme.of(context).textTheme;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: MetaColors.bg(context),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: MetaColors.text(context), size: 20),
            tooltip: 'Voltar',
            onPressed: _leaveProfileSetup,
          ),
          title: Text(
            'Montar Vitrine',
            style: TextStyle(
              color: MetaColors.text(context),
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: _leaveProfileSetup,
              child: Text(
                'Pular',
                style: TextStyle(
                  color: MetaColors.subtext(context),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        bottomNavigationBar: _buildBottomConfirmBar(context),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: MetaColors.emerald))
            : SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Hero Card One UI 7
                    _buildHeroHeader(context),
                    const SizedBox(height: 16),

                    // 2. Tríade da Vitrine em 60s (Progresso essencial)
                    _buildTriadProgressCard(context),
                    const SizedBox(height: 16),

                    // 3. Foto de Perfil & Avatar (Pilar 1/3)
                    _buildAvatarCard(context),
                    const SizedBox(height: 16),

                    // 4. WhatsApp & Robô Assistente (Pilar 2/3)
                    _buildContactCard(context),
                    const SizedBox(height: 16),

                    // 5. Credencial CREF & Diretório (Pilar 3/3)
                    _buildCrefCard(context),
                    const SizedBox(height: 16),

                    // 6. Especialidades
                    _buildSpecialtiesCard(context),
                    const SizedBox(height: 16),

                    // 7. Biografia com Gerador IA
                    _buildBioCard(context),
                    const SizedBox(height: 16),

                    // 8. Planos Recomendados Prontos
                    _buildDefaultPlansCard(context),
                    const SizedBox(height: 16),

                    // 9. Endereço da Vitrine (URL & Slug)
                    _buildUrlCard(context),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildTriadProgressCard(BuildContext context) {
    final count = _completedTriadCount;
    final isComplete = _isTriadComplete;
    return MetaCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isComplete
                      ? MetaColors.emerald.withValues(alpha: 0.15)
                      : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isComplete ? Icons.verified_rounded : Icons.bolt_rounded,
                  color: isComplete ? MetaColors.emerald : const Color(0xFFF59E0B),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tríade da Vitrine em 60s',
                      style: TextStyle(
                        color: MetaColors.text(context),
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      isComplete
                          ? '✨ Vitrine pronta com os 3 itens essenciais!'
                          : 'Preencha Foto, WhatsApp e CREF para começar.',
                      style: TextStyle(
                        color: MetaColors.subtext(context),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isComplete
                      ? MetaColors.emerald.withValues(alpha: 0.2)
                      : MetaColors.highlight(context),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isComplete ? MetaColors.emerald : MetaColors.cardBorder(context),
                  ),
                ),
                child: Text(
                  '$count/3',
                  style: TextStyle(
                    color: isComplete ? MetaColors.emerald : MetaColors.text(context),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: count / 3.0,
              backgroundColor: MetaColors.highlight(context),
              valueColor: AlwaysStoppedAnimation<Color>(
                isComplete ? MetaColors.emerald : const Color(0xFFF59E0B),
              ),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildTriadItemChip(
                context,
                label: '1. Foto/Avatar',
                done: _photoUrlController.text.trim().isNotEmpty,
              ),
              const SizedBox(width: 8),
              _buildTriadItemChip(
                context,
                label: '2. WhatsApp',
                done: _whatsappController.text.replaceAll(RegExp(r'\D'), '').length >= 10,
              ),
              const SizedBox(width: 8),
              _buildTriadItemChip(
                context,
                label: '3. CREF',
                done: _crefController.text.trim().isNotEmpty,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTriadItemChip(BuildContext context, {required String label, required bool done}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: done
              ? MetaColors.emerald.withValues(alpha: 0.12)
              : MetaColors.highlight(context),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: done ? MetaColors.emerald.withValues(alpha: 0.3) : MetaColors.cardBorder(context),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              size: 13,
              color: done ? MetaColors.emerald : MetaColors.subtext(context),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: done ? MetaColors.emerald : MetaColors.subtext(context),
                  fontSize: 11,
                  fontWeight: done ? FontWeight.w700 : FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroHeader(BuildContext context) {
    return MetaCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: MetaColors.emerald.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: MetaColors.emerald.withValues(alpha: 0.3)),
            ),
            child: const Icon(Icons.storefront_rounded, color: MetaColors.emerald, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sua Vitrine Pública',
                  style: TextStyle(
                    color: MetaColors.text(context),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Personalize seu link exclusivo, apresente suas credenciais e receba novos alunos direto no WhatsApp.',
                  style: TextStyle(
                    color: MetaColors.subtext(context),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarCard(BuildContext context) {
    return MetaCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MetaSectionTitle(
            title: '1. Foto ou Marca da Vitrine (Pilar 1)',
            subtitle: 'Transmita autoridade e identidade visual com sua foto profissional ou avatar esportivo.',
            fontSize: 16,
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _photoUrlController,
                builder: (context, val, _) {
                  final url = val.text.trim();
                  final hasValidUrl = url.isNotEmpty;
                  return GestureDetector(
                    onTap: () async {
                      final selected = await AvatarSelectorSheet.show(
                        context: context,
                        isTrainer: true,
                        currentUrl: url,
                      );
                      if (selected != null && mounted) {
                        await _handleAvatarSelected(selected);
                      }
                    },
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: MetaColors.highlight(context),
                            border: Border.all(
                              color: MetaColors.emerald,
                              width: 2.5,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: hasValidUrl
                              ? (url.startsWith('assets/')
                                  ? Image.asset(url, fit: BoxFit.cover)
                                  : Image.network(
                                      url,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => Icon(
                                        Icons.broken_image_rounded,
                                        color: MetaColors.subtext(context),
                                        size: 32,
                                      ),
                                    ))
                              : const Icon(
                                  Icons.person_rounded,
                                  color: MetaColors.emerald,
                                  size: 38,
                                ),
                        ),
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: MetaColors.emerald,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: MetaColors.card(context),
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              color: Colors.white,
                              size: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SquircleButton(
                      label: 'Escolher Imagem / Avatar',
                      icon: Icons.add_photo_alternate_rounded,
                      isPrimary: true,
                      height: 44,
                      fontSize: 13.5,
                      onPressed: () async {
                        final selected = await AvatarSelectorSheet.show(
                          context: context,
                          isTrainer: true,
                          currentUrl: _photoUrlController.text.trim(),
                        );
                        if (selected != null && mounted) {
                          await _handleAvatarSelected(selected);
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.check_circle_outline_rounded, size: 14, color: MetaColors.emerald),
                        const SizedBox(width: 5),
                        Text(
                          'Câmera • Galeria • 8 Avatares',
                          style: TextStyle(
                            color: MetaColors.subtext(context),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _photoUrlController,
            keyboardType: TextInputType.url,
            style: TextStyle(color: MetaColors.text(context), fontSize: 13),
            decoration: InputDecoration(
              labelText: 'Link direto da imagem (opcional)',
              labelStyle: TextStyle(color: MetaColors.subtext(context), fontSize: 13),
              hintText: 'https://exemplo.com/minha-foto.jpg',
              hintStyle: TextStyle(color: MetaColors.subtext(context).withValues(alpha: 0.5), fontSize: 13),
              prefixIcon: Icon(Icons.link_rounded, color: MetaColors.subtext(context), size: 18),
              filled: true,
              fillColor: MetaColors.highlight(context),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: MetaColors.cardBorder(context), width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: MetaColors.cardBorder(context), width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: MetaColors.emerald, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUrlCard(BuildContext context) {
    return MetaCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MetaSectionTitle(
            title: 'Endereço da sua Vitrine (URL)',
            subtitle: 'Escolha seu slug personalizado para divulgação nas redes.',
            fontSize: 16,
          ),
          const SizedBox(height: 14),

          // Domain Pill Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: MetaColors.emerald.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: MetaColors.emerald.withValues(alpha: 0.25)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.language_rounded, size: 15, color: MetaColors.emerald),
                const SizedBox(width: 8),
                const Text(
                  'shaipados.com/#/prof/',
                  style: TextStyle(
                    color: MetaColors.emerald,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Slug Input Field
          TextField(
            controller: _usernameController,
            textCapitalization: TextCapitalization.none,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9_.-]')),
            ],
            maxLength: 30,
            style: TextStyle(color: MetaColors.text(context), fontSize: 15, fontWeight: FontWeight.w600),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 14, right: 8),
                child: Text(
                  '@',
                  style: TextStyle(
                    color: MetaColors.emerald,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
              hintText: 'joao-silva',
              hintStyle: TextStyle(color: MetaColors.subtext(context).withValues(alpha: 0.5)),
              helperText: 'De 3 a 30 caracteres (letras minúsculas, números, ponto, hífen).',
              helperStyle: TextStyle(color: MetaColors.subtext(context), fontSize: 11.5),
              filled: true,
              fillColor: MetaColors.highlight(context),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: MetaColors.cardBorder(context), width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: MetaColors.cardBorder(context), width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: MetaColors.emerald, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
          ),

          // Live Link Preview
          if (_usernameController.text.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: MetaColors.highlight(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: MetaColors.cardBorder(context)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.link_rounded, size: 16, color: MetaColors.accentBlue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'https://shaipados.com/#/prof/${_usernameController.text.trim().toLowerCase()}',
                      style: const TextStyle(
                        color: MetaColors.accentBlue,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.copy_rounded, size: 16, color: MetaColors.subtext(context)),
                    tooltip: 'Copiar link',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      final url = 'https://shaipados.com/#/prof/${_usernameController.text.trim().toLowerCase()}';
                      Clipboard.setData(ClipboardData(text: url));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Link da vitrine copiado para a área de transferência!'),
                          backgroundColor: MetaColors.emerald,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCrefCard(BuildContext context) {
    return MetaCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MetaSectionTitle(
            title: '3. Credencial CREF & Diretório (Pilar 3)',
            subtitle: 'Validação profissional exigida para conformidade legal e badge de confiança pública.',
            fontSize: 16,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _crefController,
            textCapitalization: TextCapitalization.characters,
            style: TextStyle(color: MetaColors.text(context), fontSize: 14, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.verified_user_outlined, color: MetaColors.emerald, size: 20),
              labelText: 'Registro Profissional CREF',
              labelStyle: TextStyle(color: MetaColors.subtext(context), fontSize: 13),
              hintText: 'CREF 000000-G/UF',
              hintStyle: TextStyle(color: MetaColors.subtext(context).withValues(alpha: 0.5)),
              helperText: 'Exibido publicamente para garantir conformidade legal.',
              helperStyle: TextStyle(color: MetaColors.subtext(context), fontSize: 11.5),
              filled: true,
              fillColor: MetaColors.highlight(context),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: MetaColors.cardBorder(context), width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: MetaColors.cardBorder(context), width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: MetaColors.emerald, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
          ),
          const SizedBox(height: 16),
          Material(
            color: MetaColors.highlight(context),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: MetaColors.cardBorder(context)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _publishInDirectory,
                activeTrackColor: MetaColors.emerald,
                title: Text(
                  'Exibir no Diretório Shaipados',
                  style: TextStyle(
                    color: MetaColors.text(context),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  'Alunos poderão encontrar seu perfil na busca de treinadores certificados.',
                  style: TextStyle(
                    color: MetaColors.subtext(context),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
                onChanged: (value) => setState(() => _publishInDirectory = value),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecialtiesCard(BuildContext context) {
    return MetaCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MetaSectionTitle(
            title: 'Especialidades de Atuação',
            subtitle: 'Destaque as áreas em que você possui maior experiência.',
            fontSize: 16,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _specialties.map((specialty) {
              final isSelected = _selectedSpecialties.contains(specialty);
              return FilterChip(
                label: Text(
                  specialty,
                  style: TextStyle(
                    color: isSelected ? Colors.white : MetaColors.text(context),
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedSpecialties.add(specialty);
                    } else {
                      _selectedSpecialties.remove(specialty);
                    }
                  });
                },
                backgroundColor: MetaColors.highlight(context),
                selectedColor: MetaColors.emerald,
                checkmarkColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isSelected ? MetaColors.emerald : MetaColors.cardBorder(context),
                    width: 1,
                  ),
                ),
                elevation: 0,
                showCheckmark: isSelected,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBioCard(BuildContext context) {
    return MetaCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: MetaSectionTitle(
                  title: 'Biografia do Treinador',
                  subtitle: 'Conte um pouco sobre sua formação, metodologia e histórico.',
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 8),
              SquircleButton(
                label: 'Gerar com IA',
                icon: Icons.auto_awesome_rounded,
                isPrimary: false,
                height: 36,
                fontSize: 12,
                onPressed: _generateAiBio,
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _bioController,
            maxLines: 4,
            maxLength: 500,
            style: TextStyle(color: MetaColors.text(context), fontSize: 14, height: 1.4),
            decoration: InputDecoration(
              hintText: 'Ex: Especialista em hipertrofia e emagrecimento com mais de 8 anos de experiência...',
              hintStyle: TextStyle(color: MetaColors.subtext(context).withValues(alpha: 0.5)),
              filled: true,
              fillColor: MetaColors.highlight(context),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: MetaColors.cardBorder(context), width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: MetaColors.cardBorder(context), width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: MetaColors.emerald, width: 1.5),
              ),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultPlansCard(BuildContext context) {
    final templates = ConsultancyPlanService.getDefaultTemplates();
    return MetaCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: MetaColors.emerald.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.sell_rounded, color: MetaColors.emerald, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Planos de Consultoria na Vitrine',
                      style: TextStyle(
                        color: MetaColors.text(context),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '3 planos recomendados com Pix e contratação imediata.',
                      style: TextStyle(
                        color: MetaColors.subtext(context),
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...templates.map((tpl) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: MetaColors.highlight(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: MetaColors.cardBorder(context)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: MetaColors.emerald, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tpl.name,
                          style: TextStyle(
                            color: MetaColors.text(context),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          tpl.billingPeriodLabel,
                          style: TextStyle(
                            color: MetaColors.subtext(context),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    CurrencyPtBrFormatter.formatFromCents(tpl.priceCents),
                    style: const TextStyle(
                      color: MetaColors.emerald,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
          Material(
            color: MetaColors.highlight(context),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: MetaColors.cardBorder(context)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _autoSeedPlans,
                activeTrackColor: MetaColors.emerald,
                title: Text(
                  'Ativar estes 3 planos recomendados',
                  style: TextStyle(
                    color: MetaColors.text(context),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  'Você poderá alterar preços e nomes na aba Financeiro.',
                  style: TextStyle(
                    color: MetaColors.subtext(context),
                    fontSize: 11.5,
                    height: 1.3,
                  ),
                ),
                onChanged: (val) => setState(() => _autoSeedPlans = val),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard(BuildContext context) {
    return MetaCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MetaSectionTitle(
            title: '2. WhatsApp de Atendimento (Pilar 2)',
            subtitle: 'Número onde os futuros alunos e notificações de novos planos chegam.',
            fontSize: 16,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _whatsappController,
            keyboardType: TextInputType.phone,
            style: TextStyle(color: MetaColors.text(context), fontSize: 15, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.chat_bubble_outline_rounded, color: MetaColors.emerald, size: 20),
              labelText: 'WhatsApp do Treinador',
              labelStyle: TextStyle(color: MetaColors.subtext(context), fontSize: 13),
              hintText: '(11) 98765-4321',
              hintStyle: TextStyle(color: MetaColors.subtext(context).withValues(alpha: 0.5)),
              filled: true,
              fillColor: MetaColors.highlight(context),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: MetaColors.cardBorder(context), width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: MetaColors.cardBorder(context), width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: MetaColors.emerald, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
          ),
          const SizedBox(height: 16),

          // Robô Assistente Tile
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: MetaColors.highlight(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: MetaColors.cardBorder(context)),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: MetaColors.emerald.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.smart_toy_outlined, color: MetaColors.emerald, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Robô Assistente 24h',
                        style: TextStyle(
                          color: MetaColors.text(context),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Envios automáticos de fichas e triagem com custo zero de tokens.',
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
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => WhatsappConnectionScreen(
                          initialPhone: _whatsappController.text,
                        ),
                      ),
                    );
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: MetaColors.emerald,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  child: const Text('Vincular'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomConfirmBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: MetaColors.card(context),
        border: Border(
          top: BorderSide(color: MetaColors.cardBorder(context), width: 1.0),
        ),
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.paddingOf(context).bottom > 0
            ? MediaQuery.paddingOf(context).bottom + 6
            : 16,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: SquircleButton(
              label: 'Cancelar',
              isPrimary: false,
              height: 48,
              onPressed: _isSaving ? null : _leaveProfileSetup,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: SquircleButton(
              label: 'Salvar Vitrine',
              icon: Icons.check_rounded,
              isPrimary: true,
              isLoading: _isSaving,
              height: 48,
              onPressed: _isSaving || _isLoading ? null : _saveProfile,
            ),
          ),
        ],
      ),
    );
  }
}
