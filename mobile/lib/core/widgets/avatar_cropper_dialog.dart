import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'meta_components.dart';

/// Diálogo interativo e elegante para recorte, zoom, rotação e enquadramento de foto de perfil (avatar).
/// Compatível com Android APK, iOS e Web/PWA sem dependências nativas.
class AvatarCropperDialog extends StatefulWidget {
  final Uint8List imageBytes;
  final double cropSize;

  const AvatarCropperDialog({
    super.key,
    required this.imageBytes,
    this.cropSize = 280.0,
  });

  /// Abre o cropper interativo como tela cheia modal e retorna os bytes recortados em PNG
  static Future<Uint8List?> show({
    required BuildContext context,
    required Uint8List imageBytes,
    double cropSize = 280.0,
  }) {
    return Navigator.push<Uint8List>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => AvatarCropperDialog(
          imageBytes: imageBytes,
          cropSize: cropSize,
        ),
      ),
    );
  }

  @override
  State<AvatarCropperDialog> createState() => _AvatarCropperDialogState();
}

class _AvatarCropperDialogState extends State<AvatarCropperDialog> {
  final GlobalKey _cropKey = GlobalKey();
  final TransformationController _transformController = TransformationController();
  
  double _currentScale = 1.0;
  int _rotationQuarterTurns = 0;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _transformController.addListener(_onTransformChanged);
  }

  @override
  void dispose() {
    _transformController.removeListener(_onTransformChanged);
    _transformController.dispose();
    super.dispose();
  }

  void _onTransformChanged() {
    final scale = _transformController.value.getMaxScaleOnAxis();
    if ((scale - _currentScale).abs() > 0.05) {
      setState(() {
        _currentScale = scale.clamp(1.0, 4.0);
      });
    }
  }

  void _rotateImage() {
    setState(() {
      _rotationQuarterTurns = (_rotationQuarterTurns + 1) % 4;
      // Reseta escala suavemente para caber após rotação
      _transformController.value = Matrix4.identity();
      _currentScale = 1.0;
    });
  }

  void _resetTransform() {
    setState(() {
      _rotationQuarterTurns = 0;
      _transformController.value = Matrix4.identity();
      _currentScale = 1.0;
    });
  }

  void _onSliderScaleChanged(double newScale) {
    setState(() {
      _currentScale = newScale;
    });
    // Ajusta o scale mantendo a posição central aproximada
    final translation = _transformController.value.getTranslation();
    final matrix = Matrix4.identity()
      ..setTranslation(translation)
      ..scale(newScale, newScale, 1.0);
    _transformController.value = matrix;
  }

  Future<void> _confirmCrop() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      // Aguarda 1 frame para garantir estabilidade da renderização
      await Future.delayed(const Duration(milliseconds: 50));

      final boundary = _cropKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Não foi possível capturar o enquadramento.');
      }

      // pixelRatio 3.0 gera imagem em alta resolução (~840x840 px) para nitidez máxima
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final croppedBytes = byteData?.buffer.asUint8List();

      if (mounted && croppedBytes != null) {
        Navigator.pop(context, croppedBytes);
      }
    } catch (e) {
      debugPrint('Erro ao recortar imagem de perfil: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade900,
            content: Text('Falha ao processar o recorte: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = MetaColors.isDark(context);
    final bgColor = isDark ? MetaColors.background : const Color(0xFF0F172A);
    final cropSize = widget.cropSize;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
          onPressed: _isProcessing ? null : () => Navigator.pop(context),
          tooltip: 'Cancelar',
        ),
        title: const Text(
          'Ajustar Foto do Perfil',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.rotate_right_rounded, color: Colors.white, size: 26),
            onPressed: _isProcessing ? null : _rotateImage,
            tooltip: 'Girar 90°',
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 24),
            onPressed: _isProcessing ? null : _resetTransform,
            tooltip: 'Redefinir enquadramento',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            // Instrução clara
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Arraste e use o zoom para enquadrar perfeitamente seu rosto no círculo.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Área central com o Crop interativo
            Expanded(
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Área recortável (RepaintBoundary com ClipOval)
                    ClipOval(
                      child: Container(
                        width: cropSize,
                        height: cropSize,
                        color: Colors.black,
                        child: RepaintBoundary(
                          key: _cropKey,
                          child: InteractiveViewer(
                            transformationController: _transformController,
                            minScale: 0.8,
                            maxScale: 4.0,
                            panEnabled: true,
                            scaleEnabled: true,
                            boundaryMargin: EdgeInsets.all(cropSize * 0.8),
                            child: RotatedBox(
                              quarterTurns: _rotationQuarterTurns,
                              child: Image.memory(
                                widget.imageBytes,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Center(
                                  child: Icon(Icons.broken_image_rounded, color: Colors.white54, size: 48),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Moldura visual com borda esmeralda e guias
                    IgnorePointer(
                      child: Container(
                        width: cropSize,
                        height: cropSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: MetaColors.emerald,
                            width: 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: MetaColors.emerald.withValues(alpha: 0.25),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Controles inferiores (Slider de zoom e botões)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(
                  top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Slider de Zoom
                  Row(
                    children: [
                      const Icon(Icons.zoom_out_rounded, color: Colors.white70, size: 20),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: MetaColors.emerald,
                            inactiveTrackColor: Colors.white24,
                            thumbColor: MetaColors.emerald,
                            overlayColor: MetaColors.emerald.withValues(alpha: 0.2),
                            trackHeight: 3,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                          ),
                          child: Slider(
                            value: _currentScale.clamp(1.0, 4.0),
                            min: 1.0,
                            max: 4.0,
                            onChanged: _isProcessing ? null : _onSliderScaleChanged,
                          ),
                        ),
                      ),
                      const Icon(Icons.zoom_in_rounded, color: Colors.white70, size: 20),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Botão Confirmar Recorte
                  SizedBox(
                    width: double.infinity,
                    child: SquircleButton(
                      label: _isProcessing ? 'Enquadrando foto...' : 'Concluir Enquadramento',
                      icon: Icons.check_rounded,
                      isPrimary: true,
                      height: 52,
                      isLoading: _isProcessing,
                      onPressed: _isProcessing ? null : _confirmCrop,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
