// ignore_for_file: unused_element, unused_local_variable, unused_field, override_on_non_overriding_member, use_build_context_synchronously
import '../../../../core/widgets/meta_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'trainer_main_layout.dart';
import 'whatsapp_connection_screen.dart';

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
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) throw StateError('Usuário não autenticado.');

      final response = await supabase
          .from('profiles')
          .select('username, bio, public_whatsapp, specialties, professional_document, public_directory_enabled')
          .eq('id', user.id)
          .maybeSingle();

      if (response == null) {
        throw StateError('Perfil profissional não encontrado.');
      }
      if (mounted) {
        setState(() {
          _usernameController.text = response['username'] ?? '';
          _bioController.text = response['bio'] ?? '';
          _whatsappController.text = response['public_whatsapp'] ?? '';
          _crefController.text = response['professional_document'] ?? '';
          _publishInDirectory = response['public_directory_enabled'] == true;
          
          if (response['specialties'] != null) {
            final specs = List<String>.from(response['specialties']);
            _selectedSpecialties.addAll(specs);
          }
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar perfil: $e');
      if (mounted) setState(() => _profileLoadFailed = true);
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

  Future<void> _saveProfile() async {
    if (_isLoading || _profileLoadFailed) return;
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
      // Aqui usamos o supabase_flutter que já está inicializado no app
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('Usuário não logado');

      final updates = {
        'username': username.isEmpty ? null : username,
        'bio': _bioController.text.trim().isEmpty
            ? null
            : _bioController.text.trim(),
        'public_whatsapp': whatsappDigits.isEmpty ? null : whatsappDigits,
        'professional_document': _crefController.text.trim(),
        'public_directory_enabled': _publishInDirectory,
        'specialties': _selectedSpecialties.toList(),
      };

      final savedProfile = await supabase
          .from('profiles')
          .update(updates)
          .eq('id', user.id)
          .select('id')
          .maybeSingle();
      if (savedProfile == null) {
        throw StateError('Nenhum perfil foi atualizado.');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Vitrine salva com sucesso!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), backgroundColor: MetaColors.emerald, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), margin: const EdgeInsets.all(16)),
        );
        
        _leaveProfileSetup();
      }
    } catch (e) {
      if (mounted) {
        final message =
            e is PostgrestException && e.code == '23505'
                ? 'Este username já está em uso. Escolha outro endereço para sua vitrine.'
                : 'Não foi possível salvar a vitrine. Verifique os dados e tente novamente.';
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
                            if (_profileLoadFailed) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.red.withValues(alpha: 0.35),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Não foi possível carregar os dados salvos. Salvar está bloqueado para evitar sobrescrevê-los.',
                                    ),
                                    TextButton.icon(
                                      onPressed: _loadProfile,
                                      icon: const Icon(Icons.refresh),
                                      label: const Text('Tentar novamente'),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
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
                              activeColor: colorScheme.primary,
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
                onPressed: _isSaving || _isLoading || _profileLoadFailed
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








