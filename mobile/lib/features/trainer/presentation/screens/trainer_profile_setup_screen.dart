// ignore_for_file: unused_element, unused_local_variable, unused_field, override_on_non_overriding_member, use_build_context_synchronously
import '../../../../core/widgets/meta_components.dart';
import '../../../../core/widgets/avatar_selector_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'trainer_main_layout.dart';
import 'whatsapp_connection_screen.dart';
import '../../../../services/auth_service.dart';

class TrainerProfileSetupScreen extends StatefulWidget {
  const TrainerProfileSetupScreen({super.key});

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
  ];
  final Set<String> _selectedSpecialties = {};
  bool _isSaving = false;
  bool _isLoading = true;
  bool _profileLoadFailed = false;
  bool _publishInDirectory = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _profileLoadFailed = false;
      });
    }
    try {
      final profile = await AuthService.getCurrentProfile();
      if (profile != null && mounted) {
        setState(() {
          _usernameController.text = profile['username'] ?? '';
          _bioController.text = profile['bio'] ?? '';
          _whatsappController.text = profile['public_whatsapp'] ??
              profile['phone'] ??
              profile['whatsapp'] ??
              '';
          _crefController.text = profile['professional_document'] ??
              profile['cref_or_registry'] ??
              '';
          _photoUrlController.text = profile['photo_url'] ?? profile['avatar_url'] ?? '';
          _publishInDirectory = profile['public_directory_enabled'] == true;
          
          if (profile['specialties'] != null) {
            final specs = List<String>.from(profile['specialties']);
            _selectedSpecialties.clear();
            _selectedSpecialties.addAll(specs);
          }
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar perfil: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _crefController.dispose();
    _bioController.dispose();
    _whatsappController.dispose();
    _photoUrlController.dispose();
    super.dispose();
  }

  void _leaveProfileSetup() {
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
      SnackBar(content: Text(message)),
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
        'Para publicar, informe username, biografia e registro CREF válido.',
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('Usuário não logado');

      final photoVal = _photoUrlController.text.trim();
      final crefVal = _crefController.text.trim();
      final updates = <String, dynamic>{
        'id': user.id,
        'username': username.isEmpty ? null : username,
        'bio': _bioController.text.trim().isEmpty
            ? null
            : _bioController.text.trim(),
        'phone': whatsappDigits.isEmpty ? null : whatsappDigits,
        'whatsapp': whatsappDigits.isEmpty ? null : whatsappDigits,
        'public_whatsapp': whatsappDigits.isEmpty ? null : whatsappDigits,
        'professional_document': crefVal.isEmpty ? null : crefVal,
        'public_directory_enabled': _publishInDirectory,
        'specialties': _selectedSpecialties.toList(),
        'photo_url': photoVal.isEmpty ? null : photoVal,
        'avatar_url': photoVal.isEmpty ? null : photoVal,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      await supabase.from('profiles').upsert(updates);

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
              backgroundColor: Colors.red,
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final padding = MediaQuery.paddingOf(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        extendBody: true,
        extendBodyBehindAppBar: true,
        body: Stack(
          children: [
            CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverAppBar(
                  backgroundColor: colorScheme.surface.withValues(alpha: 0.9),
                  pinned: true,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  title: const Text('Montar Vitrine'),
                  centerTitle: true,
                  actions: [
                    TextButton(
                      onPressed: _leaveProfileSetup,
                      child: const Text(
                        'Pular',
                        style: TextStyle(
                          color: MetaColors.emerald,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                SliverPadding(
                  padding: EdgeInsets.only(
                    left: 24,
                    right: 24,
                    top: 24,
                    bottom:
                        padding.bottom +
                        120, // Extra space for the floating button
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      if (index == 0) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Configure seu perfil público. Estes dados serão visíveis na sua Landing Page.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 32),
                            _buildSectionTitle(context, 'Nome de Usuário (Sua URL)'),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _usernameController,
                              textCapitalization: TextCapitalization.none,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[a-z0-9_.-]'),
                                ),
                              ],
                              maxLength: 30,
                              decoration: InputDecoration(
                                hintText: 'ex: joao-silva',
                                helperText:
                                    '3 a 30 caracteres; use letras minúsculas, números, ponto, hífen ou sublinhado.',
                                prefixText: 'shaipados.com/#/prof/',
                                prefixStyle: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold),
                                filled: true,
                                fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              ),
                            ),
                            const SizedBox(height: 24),
                            _buildSectionTitle(context, 'Foto de Perfil ou Marca da Vitrine'),
                            const SizedBox(height: 8),
                            Text(
                              'Tire uma foto pela câmera, escolha da sua galeria ou use um dos nossos 8 avatares exclusivos de treinador.',
                              style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                            ),
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Column(
                                children: [
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
                                            child: Container(
                                              width: 72,
                                              height: 72,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: MetaColors.surfaceHighlight,
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
                                                          errorBuilder: (_, _, _) => const Icon(
                                                            Icons.broken_image_rounded,
                                                            color: MetaColors.textSecondary,
                                                            size: 32,
                                                          ),
                                                        ))
                                                  : const Icon(
                                                      Icons.add_a_photo_outlined,
                                                      color: MetaColors.emerald,
                                                      size: 30,
                                                    ),
                                            ),
                                          );
                                        },
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            ElevatedButton.icon(
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
                                              icon: const Icon(Icons.add_photo_alternate_rounded, size: 18),
                                              label: const Text('Escolher Imagem / Avatar'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: MetaColors.emerald,
                                                foregroundColor: Colors.white,
                                                elevation: 0,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              'Câmera • Galeria • 8 Avatares',
                                              style: theme.textTheme.bodySmall?.copyWith(
                                                color: colorScheme.onSurfaceVariant,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: _photoUrlController,
                                    keyboardType: TextInputType.url,
                                    decoration: InputDecoration(
                                      labelText: 'Link direto da imagem (opcional)',
                                      hintText: 'https://exemplo.com/minha-foto.jpg',
                                      filled: true,
                                      fillColor: colorScheme.surface.withValues(alpha: 0.5),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            _buildSectionTitle(context, 'Biografia'),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _bioController,
                              maxLines: 5,
                              maxLength: 500,
                              decoration: InputDecoration(
                                hintText:
                                    'Conte um pouco sobre sua trajetória...',
                                filled: true,
                                fillColor: colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.3),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.all(16),
                              ),
                            ),
                            const SizedBox(height: 24),
                            _buildSectionTitle(context, 'Registro CREF'),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _crefController,
                              decoration: InputDecoration(
                                hintText: 'CREF 00000-G/UF',
                                helperText: 'Exibido no diretório público para identificação profissional.',
                                filled: true,
                                fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              ),
                            ),
                            const SizedBox(height: 24),
                            SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              value: _publishInDirectory,
                              activeTrackColor: colorScheme.primary,
                              title: const Text('Exibir no diretório Shaipados'),
                              subtitle: const Text('Seu perfil e registro CREF poderão ser encontrados publicamente.'),
                              onChanged: (value) => setState(() => _publishInDirectory = value),
                            ),
                            const SizedBox(height: 16),
                            _buildSectionTitle(context, 'Especialidades'),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children:
                                  _specialties.map((specialty) {
                                    final isSelected = _selectedSpecialties
                                        .contains(specialty);
                                    return FilterChip(
                                      label: Text(specialty),
                                      selected: isSelected,
                                      onSelected: (selected) {
                                        setState(() {
                                          if (selected) {
                                            _selectedSpecialties.add(specialty);
                                          } else {
                                            _selectedSpecialties.remove(
                                              specialty,
                                            );
                                          }
                                        });
                                      },
                                      backgroundColor: colorScheme
                                          .surfaceContainerHighest
                                          .withValues(alpha: 0.3),
                                      selectedColor:
                                          colorScheme.primaryContainer,
                                      labelStyle: TextStyle(
                                        color:
                                            isSelected
                                                ? colorScheme.onPrimaryContainer
                                                : colorScheme.onSurfaceVariant,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: BorderSide.none,
                                      ),
                                      elevation: 0,
                                      showCheckmark: false,
                                    );
                                  }).toList(),
                            ),
                            const SizedBox(height: 24),
                            _buildSectionTitle(context, 'WhatsApp Público (Atendimento)'),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _whatsappController,
                              keyboardType: TextInputType.phone,
                              decoration: InputDecoration(
                                hintText: '(11) 90000-0000',
                                prefixIcon: Icon(
                                  Icons.phone,
                                  color: colorScheme.primary,
                                ),
                                filled: true,
                                fillColor: colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.3),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: colorScheme.secondaryContainer.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.qr_code, color: colorScheme.onSecondaryContainer, size: 32),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Robô Assistente', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                                        Text('Vincule o WhatsApp para disparar notificações.', style: theme.textTheme.bodySmall),
                                      ],
                                    ),
                                  ),
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
                                    child: const Text('Vincular'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }
                      return null;
                    }, childCount: 1),
                  ),
                ),
              ],
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: padding.bottom > 0 ? padding.bottom : 24,
              child: FilledButton(
                onPressed: _isSaving || _isLoading
                  ? null
                  : _saveProfile,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Salvar Vitrine',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
    );
  }
}








