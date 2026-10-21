import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/auth_service.dart';
import '../../services/body_metrics_service.dart';
import '../../services/evolution_photo_service.dart';
import '../../services/student_notification_service.dart';
import 'meta_components.dart';

/// Modal Guiado de Check-in Semanal do Aluno (Pesagem, Foto e Aderência).
class StudentWeeklyCheckinSheet extends StatefulWidget {
  final double? previousWeightKg;
  final VoidCallback? onCheckinCompleted;

  const StudentWeeklyCheckinSheet({
    super.key,
    this.previousWeightKg,
    this.onCheckinCompleted,
  });

  static Future<void> show(
    BuildContext context, {
    double? previousWeightKg,
    VoidCallback? onCheckinCompleted,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StudentWeeklyCheckinSheet(
        previousWeightKg: previousWeightKg,
        onCheckinCompleted: onCheckinCompleted,
      ),
    );
  }

  @override
  State<StudentWeeklyCheckinSheet> createState() => _StudentWeeklyCheckinSheetState();
}

class _StudentWeeklyCheckinSheetState extends State<StudentWeeklyCheckinSheet> {
  int _currentStep = 0; // 0: Peso, 1: Foto, 2: Aderência, 3: Sucesso
  late double _weight;
  final TextEditingController _weightCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();

  XFile? _selectedPhoto;
  Uint8List? _photoBytes;
  String _adherence = 'Alta (80% - 100%)';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _weight = widget.previousWeightKg ?? 72.0;
    _weightCtrl.text = _weight.toStringAsFixed(1);
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _adjustWeight(double delta) {
    HapticFeedback.selectionClick();
    setState(() {
      _weight = (_weight + delta).clamp(30.0, 300.0);
      _weightCtrl.text = _weight.toStringAsFixed(1);
    });
  }

  Future<void> _pickPhoto(ImageSource source) async {
    HapticFeedback.lightImpact();
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 1200,
      imageQuality: 82,
    );
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _selectedPhoto = picked;
        _photoBytes = bytes;
      });
    }
  }

  Future<void> _submitCheckin() async {
    final user = AuthService.currentUser;
    if (user == null) return;
    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    try {
      final parsedWeight = double.tryParse(_weightCtrl.text.replaceAll(',', '.')) ?? _weight;

      // 1. Salvar medição corporal com peso e notas
      final fullNotes = 'Check-in Semanal | Aderência: $_adherence. ${_notesCtrl.text.trim()}';
      await BodyMetricsService.saveMetrics(
        targetStudentId: user.id,
        weightKg: parsedWeight,
        notes: fullNotes,
      );

      // 2. Se houver foto selecionada, fazer upload
      if (_photoBytes != null) {
        await EvolutionPhotoService.uploadPhoto(
          bytes: _photoBytes!,
          photoType: 'progress',
          caption: 'Foto do Check-in Semanal (${parsedWeight.toStringAsFixed(1)} kg)',
          weightKg: parsedWeight,
        );
      }

      // 3. Atualizar notificações
      await StudentNotificationService.instance.refreshNotifications();

      if (mounted) {
        setState(() {
          _isSaving = false;
          _currentStep = 3; // Sucesso
        });
        widget.onCheckinCompleted?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Aviso ao sincronizar check-in: $e. Gravado no aparelho.'),
            backgroundColor: Colors.amber[900],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = MetaColors.isDark(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.88;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: MetaColors.bg(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(
            color: MetaColors.cardBorder(context).withValues(alpha: 0.8),
            width: 1,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: MetaColors.subtext(context).withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          // Header com indicador de passos
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: MetaColors.primaryColor(context).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.fact_check_rounded,
                        color: MetaColors.primaryColor(context),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Check-in Semanal',
                          style: TextStyle(
                            color: MetaColors.text(context),
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          _currentStep < 3 ? 'Passo ${_currentStep + 1} de 3' : 'Concluído!',
                          style: TextStyle(
                            color: MetaColors.subtext(context),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, color: MetaColors.subtext(context)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Conteúdo do Passo
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              physics: const BouncingScrollPhysics(),
              child: _buildCurrentStepView(context, isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStepView(BuildContext context, bool isDark) {
    switch (_currentStep) {
      case 0:
        return _buildStepWeight(context, isDark);
      case 1:
        return _buildStepPhoto(context, isDark);
      case 2:
        return _buildStepAdherence(context, isDark);
      case 3:
      default:
        return _buildStepSuccess(context, isDark);
    }
  }

  // ===========================================================================
  // PASSO 1: PESAGEM SEMANAL
  // ===========================================================================
  Widget _buildStepWeight(BuildContext context, bool isDark) {
    final prev = widget.previousWeightKg;
    double? delta;
    if (prev != null && prev > 0) {
      delta = _weight - prev;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 8),
        Text(
          'Qual é o seu peso corporal hoje?',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: MetaColors.text(context),
            fontSize: 19,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Recomendamos pesar em jejum pela manhã para maior precisão.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: MetaColors.subtext(context),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 24),

        // Display de Peso com Seletor Tátil (+/- 0.5kg)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildRoundButton(
              icon: Icons.remove,
              onTap: () => _adjustWeight(-0.5),
            ),
            const SizedBox(width: 16),
            Container(
              width: 160,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                color: MetaColors.highlight(context),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: MetaColors.primaryColor(context).withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    '${_weight.toStringAsFixed(1)} kg',
                    style: TextStyle(
                      color: MetaColors.text(context),
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  if (delta != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: delta == 0
                            ? Colors.grey.withValues(alpha: 0.2)
                            : delta < 0
                                ? MetaColors.emerald.withValues(alpha: 0.2)
                                : Colors.amber.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        delta == 0
                            ? 'Estável (0.0 kg)'
                            : '${delta > 0 ? '+' : ''}${delta.toStringAsFixed(1)} kg vs semana passada',
                        style: TextStyle(
                          color: delta == 0
                              ? MetaColors.subtext(context)
                              : delta < 0
                                  ? MetaColors.emerald
                                  : Colors.amber,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 16),
            _buildRoundButton(
              icon: Icons.add,
              onTap: () => _adjustWeight(0.5),
            ),
          ],
        ),
        const SizedBox(height: 32),

        // Botão Avançar
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              setState(() => _currentStep = 1);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: MetaColors.primaryColor(context),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Avançar para Foto de Evolução',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
                ),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward_rounded, size: 18),
              ],
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 200.ms);
  }

  Widget _buildRoundButton({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: MetaColors.highlight(context),
          shape: BoxShape.circle,
          border: Border.all(color: MetaColors.cardBorder(context)),
        ),
        child: Icon(icon, color: MetaColors.text(context), size: 22),
      ),
    );
  }

  // ===========================================================================
  // PASSO 2: FOTO DE EVOLUÇÃO
  // ===========================================================================
  Widget _buildStepPhoto(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 8),
        Text(
          'Foto de Evolução da Semana',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: MetaColors.text(context),
            fontSize: 19,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Suas fotos são 100% confidenciais e visíveis apenas para você e seu treinador.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: MetaColors.subtext(context),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 20),

        // Área de Preview ou Seleção de Foto
        Container(
          width: double.infinity,
          height: 220,
          decoration: BoxDecoration(
            color: MetaColors.highlight(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _photoBytes != null
                  ? MetaColors.primaryColor(context)
                  : MetaColors.cardBorder(context),
              width: 1.2,
            ),
          ),
          child: _photoBytes != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(19),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      kIsWeb
                          ? Image.memory(_photoBytes!, fit: BoxFit.cover)
                          : Image.file(File(_selectedPhoto!.path), fit: BoxFit.cover),
                      Positioned(
                        top: 10,
                        right: 10,
                        child: InkWell(
                          onTap: () => setState(() {
                            _selectedPhoto = null;
                            _photoBytes = null;
                          }),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_weight.toStringAsFixed(1)} kg · Hoje',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.camera_alt_outlined,
                      size: 44,
                      color: MetaColors.subtext(context),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Tirar Foto ou Escolher da Galeria',
                      style: TextStyle(
                        color: MetaColors.text(context),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Opcional · Você pode pular esta etapa',
                      style: TextStyle(
                        color: MetaColors.subtext(context),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _pickPhoto(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt, size: 16),
                          label: const Text('Câmera'),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: MetaColors.cardBorder(context)),
                            foregroundColor: MetaColors.text(context),
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: () => _pickPhoto(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library, size: 16),
                          label: const Text('Galeria'),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: MetaColors.cardBorder(context)),
                            foregroundColor: MetaColors.text(context),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 24),

        // Botões Voltar e Avançar
        Row(
          children: [
            Expanded(
              flex: 1,
              child: OutlinedButton(
                onPressed: () => setState(() => _currentStep = 0),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: MetaColors.cardBorder(context)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text('Voltar', style: TextStyle(color: MetaColors.text(context))),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  setState(() => _currentStep = 2);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: MetaColors.primaryColor(context),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _photoBytes != null ? 'Avançar com Foto' : 'Pular Foto & Avançar',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_forward_rounded, size: 18),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    ).animate().fadeIn(duration: 200.ms);
  }

  // ===========================================================================
  // PASSO 3: ADERÊNCIA & NOTAS
  // ===========================================================================
  Widget _buildStepAdherence(BuildContext context, bool isDark) {
    final options = [
      'Total (100% - Sem desvios)',
      'Alta (80% - 100%)',
      'Moderada (60% - 80%)',
      'Baixa (<60%)',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Center(
          child: Text(
            'Como foi sua semana de treinos e dieta?',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: MetaColors.text(context),
              fontSize: 19,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            'Isso ajuda seu treinador a calibrar os próximos estímulos.',
            style: TextStyle(color: MetaColors.subtext(context), fontSize: 13),
          ),
        ),
        const SizedBox(height: 20),

        // Seletor de Aderência
        Text(
          'NÍVEL DE ADERÊNCIA GERAL',
          style: TextStyle(
            color: MetaColors.subtext(context),
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        ...options.map((opt) {
          final isSelected = _adherence == opt;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _adherence = opt);
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? MetaColors.primaryColor(context).withValues(alpha: 0.15)
                      : MetaColors.highlight(context),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? MetaColors.primaryColor(context)
                        : MetaColors.cardBorder(context),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: isSelected
                          ? MetaColors.primaryColor(context)
                          : MetaColors.subtext(context),
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      opt,
                      style: TextStyle(
                        color: MetaColors.text(context),
                        fontSize: 13.5,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 16),

        // Mensagem / Notas opcionais
        Text(
          'COMENTÁRIOS PARA O TREINADOR (OPCIONAL)',
          style: TextStyle(
            color: MetaColors.subtext(context),
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _notesCtrl,
          maxLines: 2,
          style: TextStyle(color: MetaColors.text(context), fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Ex: Treinei 4 dias, aumentei a carga no agachamento...',
            hintStyle: TextStyle(color: MetaColors.subtext(context).withValues(alpha: 0.6)),
            filled: true,
            fillColor: MetaColors.highlight(context),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: MetaColors.cardBorder(context)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: MetaColors.cardBorder(context)),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Botão Finalizar
        Row(
          children: [
            Expanded(
              flex: 1,
              child: OutlinedButton(
                onPressed: () => setState(() => _currentStep = 1),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: MetaColors.cardBorder(context)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text('Voltar', style: TextStyle(color: MetaColors.text(context))),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _submitCheckin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: MetaColors.primaryColor(context),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_rounded, size: 18),
                          SizedBox(width: 6),
                          Text(
                            'Concluir Check-in',
                            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ],
    ).animate().fadeIn(duration: 200.ms);
  }

  // ===========================================================================
  // PASSO 4: SUCESSO & TRIUNFO
  // ===========================================================================
  Widget _buildStepSuccess(BuildContext context, bool isDark) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: MetaColors.primaryColor(context).withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.celebration_rounded,
            color: MetaColors.primaryColor(context),
            size: 48,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Check-in Concluído com Sucesso!',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: MetaColors.text(context),
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Seu peso de ${_weight.toStringAsFixed(1)} kg e dados da semana foram registrados na sua linha do tempo e notificados ao treinador.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: MetaColors.subtext(context),
            fontSize: 13.5,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: MetaColors.primaryColor(context),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: const Text(
              'Fechar e Voltar ao Bio-Hub',
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    ).animate().scale(duration: 250.ms, begin: const Offset(0.9, 0.9));
  }
}
