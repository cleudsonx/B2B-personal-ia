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

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final response = await supabase
          .from('profiles')
          .select('username, bio, public_whatsapp, specialties')
          .eq('id', user.id)
          .maybeSingle();

      if (response != null && mounted) {
        setState(() {
          _usernameController.text = response['username'] ?? '';
          _bioController.text = response['bio'] ?? '';
          _whatsappController.text = response['public_whatsapp'] ?? '';
          
          if (response['specialties'] != null) {
            final specs = List<String>.from(response['specialties']);
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
    _bioController.dispose();
    _whatsappController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    try {
      // Aqui usamos o supabase_flutter que já está inicializado no app
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('Usuário não logado');

      final updates = {
        'username': _usernameController.text.trim().toLowerCase(),
        'bio': _bioController.text.trim(),
        'public_whatsapp': _whatsappController.text.trim(),
        'specialties': _selectedSpecialties.toList(),
      };

      await supabase.from('profiles').update(updates).eq('id', user.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vitrine salva com sucesso!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $e')),
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
                  centerTitle: true, actions: [ TextButton(onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const TrainerMainLayout())), child: const Text('Pular', style: TextStyle(color: MetaColors.emerald, fontWeight: FontWeight.bold))) ], ),
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
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9\-]')),
                              ],
                              decoration: InputDecoration(
                                hintText: 'ex: joao-silva',
                                prefixText: 'app.shaipados.com/prof/',
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
                                        MaterialPageRoute(builder: (_) => const WhatsappConnectionScreen()),
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
                onPressed: _isSaving ? null : _saveProfile,
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



