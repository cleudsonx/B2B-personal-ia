import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/meta_components.dart';

class AvatarItem {
  final String id;
  final String label;
  final String assetPath;
  final String publicUrl;

  const AvatarItem({
    required this.id,
    required this.label,
    required this.assetPath,
    required this.publicUrl,
  });
}

class SystemAvatars {
  static const String _storageBase =
      'https://rgbyfiulomxpqkuufdtg.supabase.co/storage/v1/object/public/avatars/defaults';

  static const List<AvatarItem> trainers = [
    AvatarItem(
      id: 'trainer_1',
      label: 'Coach Victor',
      assetPath: 'assets/images/avatars/trainers/trainer_1.png',
      publicUrl: '$_storageBase/trainers/trainer_1.png',
    ),
    AvatarItem(
      id: 'trainer_2',
      label: 'Coach Camila',
      assetPath: 'assets/images/avatars/trainers/trainer_2.png',
      publicUrl: '$_storageBase/trainers/trainer_2.png',
    ),
    AvatarItem(
      id: 'trainer_3',
      label: 'Coach Marcus',
      assetPath: 'assets/images/avatars/trainers/trainer_3.png',
      publicUrl: '$_storageBase/trainers/trainer_3.png',
    ),
    AvatarItem(
      id: 'trainer_4',
      label: 'Coach Larissa',
      assetPath: 'assets/images/avatars/trainers/trainer_4.png',
      publicUrl: '$_storageBase/trainers/trainer_4.png',
    ),
    AvatarItem(
      id: 'trainer_5',
      label: 'Coach Bruno',
      assetPath: 'assets/images/avatars/trainers/trainer_5.png',
      publicUrl: '$_storageBase/trainers/trainer_5.png',
    ),
    AvatarItem(
      id: 'trainer_6',
      label: 'Coach Renata',
      assetPath: 'assets/images/avatars/trainers/trainer_6.png',
      publicUrl: '$_storageBase/trainers/trainer_6.png',
    ),
    AvatarItem(
      id: 'trainer_7',
      label: 'Coach Diego',
      assetPath: 'assets/images/avatars/trainers/trainer_7.png',
      publicUrl: '$_storageBase/trainers/trainer_7.png',
    ),
    AvatarItem(
      id: 'trainer_8',
      label: 'Coach Beatriz',
      assetPath: 'assets/images/avatars/trainers/trainer_8.png',
      publicUrl: '$_storageBase/trainers/trainer_8.png',
    ),
  ];

  static const List<AvatarItem> students = [
    AvatarItem(
      id: 'student_1',
      label: 'Lucas Focado',
      assetPath: 'assets/images/avatars/students/student_1.png',
      publicUrl: '$_storageBase/students/student_1.png',
    ),
    AvatarItem(
      id: 'student_2',
      label: 'Juliana Força',
      assetPath: 'assets/images/avatars/students/student_2.png',
      publicUrl: '$_storageBase/students/student_2.png',
    ),
    AvatarItem(
      id: 'student_3',
      label: 'Rafael Atleta',
      assetPath: 'assets/images/avatars/students/student_3.png',
      publicUrl: '$_storageBase/students/student_3.png',
    ),
    AvatarItem(
      id: 'student_4',
      label: 'Mariana Zen',
      assetPath: 'assets/images/avatars/students/student_4.png',
      publicUrl: '$_storageBase/students/student_4.png',
    ),
    AvatarItem(
      id: 'student_5',
      label: 'Thiago Evolução',
      assetPath: 'assets/images/avatars/students/student_5.png',
      publicUrl: '$_storageBase/students/student_5.png',
    ),
    AvatarItem(
      id: 'student_6',
      label: 'Larissa Fit',
      assetPath: 'assets/images/avatars/students/student_6.png',
      publicUrl: '$_storageBase/students/student_6.png',
    ),
    AvatarItem(
      id: 'student_7',
      label: 'Gabriel Foco',
      assetPath: 'assets/images/avatars/students/student_7.png',
      publicUrl: '$_storageBase/students/student_7.png',
    ),
    AvatarItem(
      id: 'student_8',
      label: 'Fernanda Ritmo',
      assetPath: 'assets/images/avatars/students/student_8.png',
      publicUrl: '$_storageBase/students/student_8.png',
    ),
  ];
}

class AvatarSelectorSheet extends StatefulWidget {
  final bool isTrainer;
  final String? currentUrl;
  final String? userId;

  const AvatarSelectorSheet({
    super.key,
    required this.isTrainer,
    this.currentUrl,
    this.userId,
  });

  static Future<String?> show({
    required BuildContext context,
    required bool isTrainer,
    String? currentUrl,
    String? userId,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AvatarSelectorSheet(
        isTrainer: isTrainer,
        currentUrl: currentUrl,
        userId: userId,
      ),
    );
  }

  @override
  State<AvatarSelectorSheet> createState() => _AvatarSelectorSheetState();
}

class _AvatarSelectorSheetState extends State<AvatarSelectorSheet> {
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  String? _uploadStatusText;
  String? _selectedAvatarUrl;

  @override
  void initState() {
    super.initState();
    _selectedAvatarUrl = widget.currentUrl;
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(() {
        _isUploading = true;
        _uploadStatusText = 'Processando imagem...';
      });

      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);
      final mimeType = image.mimeType ?? 'image/jpeg';

      setState(() {
        _uploadStatusText = 'Enviando foto com segurança...';
      });

      // 1. Tentar upload seguro via endpoint do backend
      final resolvedUserId = widget.userId ?? Supabase.instance.client.auth.currentUser?.id;
      final response = await http.post(
        Uri.parse('https://api.shaipados.com/api/v1/public/upload-avatar'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'image_base64': base64Image,
          'user_id': resolvedUserId,
          'content_type': mimeType,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final avatarUrl = data['avatar_url'] as String?;
        if (avatarUrl != null && mounted) {
          Navigator.of(context).pop(avatarUrl);
          return;
        }
      }

      // 2. Fallback: upload direto no Supabase Storage
      final supabase = Supabase.instance.client;
      final fileExt = mimeType.contains('png') ? 'png' : 'jpg';
      final fileName = 'uploads/${resolvedUserId ?? "user"}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      await supabase.storage.from('avatars').uploadBinary(
        fileName,
        bytes,
        fileOptions: FileOptions(contentType: mimeType, upsert: true),
      );

      final publicUrl = supabase.storage.from('avatars').getPublicUrl(fileName);
      if (mounted) {
        Navigator.of(context).pop(publicUrl);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Não foi possível carregar a foto: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadStatusText = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final avatars = widget.isTrainer ? SystemAvatars.trainers : SystemAvatars.students;
    final title = widget.isTrainer ? 'Foto ou Avatar da Vitrine' : 'Foto ou Avatar do Aluno';

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.paddingOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Header
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Escolha como deseja se apresentar: tire uma foto, escolha da sua galeria ou selecione um dos nossos 8 avatares exclusivos.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),

          if (_isUploading) ...[
            Container(
              padding: const EdgeInsets.all(24),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: MetaColors.emerald),
                  const SizedBox(height: 16),
                  Text(
                    _uploadStatusText ?? 'Carregando...',
                    style: TextStyle(color: colorScheme.onSurface, fontSize: 14),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Quick Actions: Camera & Galeria
            Row(
              children: [
                Expanded(
                  child: _buildActionCard(
                    context,
                    icon: Icons.camera_alt_rounded,
                    label: 'Câmera',
                    subtitle: 'Tirar foto agora',
                    onTap: () => _pickImage(ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionCard(
                    context,
                    icon: Icons.photo_library_rounded,
                    label: 'Galeria',
                    subtitle: 'Enviar do arquivo',
                    onTap: () => _pickImage(ImageSource.gallery),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Avatares Padrões Section
            Row(
              children: [
                Text(
                  'Avatares Disponíveis (8 opções)',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                const Icon(Icons.auto_awesome_rounded, size: 16, color: MetaColors.emerald),
              ],
            ),
            const SizedBox(height: 12),

            // 8 Avatares Grid
            SizedBox(
              height: 130,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: avatars.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final item = avatars[index];
                  final isSelected = _selectedAvatarUrl == item.publicUrl;

                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedAvatarUrl = item.publicUrl);
                      Navigator.of(context).pop(item.publicUrl);
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? MetaColors.emerald
                                  : colorScheme.outlineVariant.withValues(alpha: 0.5),
                              width: isSelected ? 3 : 1.5,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: MetaColors.emerald.withValues(alpha: 0.4),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    )
                                  ]
                                : null,
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              item.assetPath,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Image.network(
                                item.publicUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(Icons.person),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: 85,
                          child: Text(
                            item.label,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? MetaColors.emerald : colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: MetaColors.emerald.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: MetaColors.emerald, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      subtitle,
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
        ),
      ),
    );
  }
}

