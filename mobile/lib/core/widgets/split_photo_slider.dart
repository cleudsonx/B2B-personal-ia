import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/widgets/meta_components.dart';

/// Componente One UI 7 de Comparação Visual Antes x Depois (Split Slider).
///
/// Permite ao aluno e ao treinador arrastar a barra divisória horizontalmente
/// para visualizar a transformação corporal sobreposta com precisão milimétrica.
class SplitPhotoSlider extends StatefulWidget {
  final String beforeImageUrl;
  final String afterImageUrl;
  final String beforeLabel;
  final String afterLabel;
  final double? beforeWeightKg;
  final double? afterWeightKg;
  final DateTime? beforeDate;
  final DateTime? afterDate;
  final double height;
  final bool enableFullscreen;

  const SplitPhotoSlider({
    super.key,
    required this.beforeImageUrl,
    required this.afterImageUrl,
    this.beforeLabel = 'Início',
    this.afterLabel = 'Atual',
    this.beforeWeightKg,
    this.afterWeightKg,
    this.beforeDate,
    this.afterDate,
    this.height = 380,
    this.enableFullscreen = true,
  });

  static ImageProvider getImageProvider(String url) {
    if (url.startsWith('data:image')) {
      final commaIndex = url.indexOf(',');
      if (commaIndex != -1) {
        final b64 = url.substring(commaIndex + 1);
        try {
          return MemoryImage(base64Decode(b64));
        } catch (_) {}
      }
    }
    return NetworkImage(url);
  }

  @override
  State<SplitPhotoSlider> createState() => _SplitPhotoSliderState();
}

class _SplitPhotoSliderState extends State<SplitPhotoSlider> {
  double _splitPosition = 0.5; // De 0.05 a 0.95

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  void _openFullscreen(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.95),
      builder: (dialogCtx) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
              onPressed: () => Navigator.pop(dialogCtx),
            ),
            title: const Text(
              'Comparador Visual de Alta Resolução',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: SplitPhotoSlider(
                beforeImageUrl: widget.beforeImageUrl,
                afterImageUrl: widget.afterImageUrl,
                beforeLabel: widget.beforeLabel,
                afterLabel: widget.afterLabel,
                beforeWeightKg: widget.beforeWeightKg,
                afterWeightKg: widget.afterWeightKg,
                beforeDate: widget.beforeDate,
                afterDate: widget.afterDate,
                height: MediaQuery.of(dialogCtx).size.height * 0.75,
                enableFullscreen: false,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final beforeProvider = SplitPhotoSlider.getImageProvider(widget.beforeImageUrl);
    final afterProvider = SplitPhotoSlider.getImageProvider(widget.afterImageUrl);

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;

        return ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Container(
            height: widget.height,
            width: totalWidth,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: MetaColors.emerald.withValues(alpha: 0.35),
                width: 1.2,
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1. Imagem de Fundo Completa: "Depois / Atual"
                Positioned.fill(
                  child: Image(
                    image: afterProvider,
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    errorBuilder: (context, error, stackTrace) => const Center(
                      child: Icon(Icons.broken_image_rounded, color: Colors.white54, size: 40),
                    ),
                  ),
                ),

                // 2. Imagem Superior Recortada: "Antes / Início"
                Positioned.fill(
                  child: ClipRect(
                    clipper: _SliderClipper(_splitPosition),
                    child: Image(
                      image: beforeProvider,
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                      errorBuilder: (context, error, stackTrace) => const Center(
                        child: Icon(Icons.broken_image_rounded, color: Colors.white54, size: 40),
                      ),
                    ),
                  ),
                ),

                // 3. Linha Divisória Vertical com Alça Tátil
                Positioned(
                  left: (totalWidth * _splitPosition) - 1.5,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 3,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),

                // 4. Handle Circular de Arraste (Centro da Linha)
                Positioned(
                  left: (totalWidth * _splitPosition) - 20,
                  top: (widget.height / 2) - 20,
                  child: GestureDetector(
                    onHorizontalDragUpdate: (details) {
                      setState(() {
                        _splitPosition += details.delta.dx / totalWidth;
                        _splitPosition = _splitPosition.clamp(0.04, 0.96);
                      });
                      HapticFeedback.selectionClick();
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                        border: Border.all(color: MetaColors.emerald, width: 2.5),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.swap_horiz_rounded,
                          color: Color(0xFF0F172A),
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ),

                // 5. Gestos de Arraste em toda a área
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragUpdate: (details) {
                      setState(() {
                        _splitPosition += details.delta.dx / totalWidth;
                        _splitPosition = _splitPosition.clamp(0.04, 0.96);
                      });
                    },
                  ),
                ),

                // 6. Badges Superiores Informativos
                // Badge Esquerdo (Antes)
                Positioned(
                  top: 12,
                  left: 12,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white24, width: 0.8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.beforeLabel.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                          if (widget.beforeWeightKg != null || widget.beforeDate != null)
                            Text(
                              [
                                if (widget.beforeWeightKg != null) '${widget.beforeWeightKg!.toStringAsFixed(1)} kg',
                                if (widget.beforeDate != null) _formatDate(widget.beforeDate),
                              ].join(' • '),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Badge Direito (Depois)
                Positioned(
                  top: 12,
                  right: 12,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: MetaColors.emerald.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white38, width: 0.8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.afterLabel.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                          if (widget.afterWeightKg != null || widget.afterDate != null)
                            Text(
                              [
                                if (widget.afterWeightKg != null) '${widget.afterWeightKg!.toStringAsFixed(1)} kg',
                                if (widget.afterDate != null) _formatDate(widget.afterDate),
                              ].join(' • '),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

                // 7. Rodapé com Instrução e Botão Fullscreen
                Positioned(
                  bottom: 10,
                  left: 12,
                  right: 12,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.touch_app_rounded, color: Colors.white70, size: 13),
                            SizedBox(width: 5),
                            Text(
                              'Arraste para comparar',
                              style: TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      if (widget.enableFullscreen)
                        InkWell(
                          onTap: () => _openFullscreen(context),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.fullscreen_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SliderClipper extends CustomClipper<Rect> {
  final double position;
  _SliderClipper(this.position);

  @override
  Rect getClip(Size size) {
    return Rect.fromLTRB(0, 0, size.width * position, size.height);
  }

  @override
  bool shouldReclip(_SliderClipper oldClipper) => oldClipper.position != position;
}

