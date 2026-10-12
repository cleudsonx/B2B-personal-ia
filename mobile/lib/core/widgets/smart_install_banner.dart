import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/pwa_installer.dart';
import 'meta_components.dart';

class SmartInstallBanner extends StatefulWidget {
  const SmartInstallBanner({super.key});

  @override
  State<SmartInstallBanner> createState() => _SmartInstallBannerState();
}

class _SmartInstallBannerState extends State<SmartInstallBanner> {
  bool _isVisible = false;
  static const String _dismissKey = 'pwa_smart_banner_dismissed_until';

  @override
  void initState() {
    super.initState();
    _checkVisibility();
  }

  Future<void> _checkVisibility() async {
    // 1. Apenas para ambiente Web
    if (!kIsWeb) return;

    // 2. Se já estiver instalado em modo standalone, não exibe
    if (PwaInstaller.isPwaInstalled) return;

    // 3. Se foi dispensado recentemente nos últimos 7 dias, não exibe
    try {
      final prefs = await SharedPreferences.getInstance();
      final dismissedUntil = prefs.getInt(_dismissKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now < dismissedUntil) {
        return;
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _isVisible = true);
    }
  }

  Future<void> _dismissBanner() async {
    setState(() => _isVisible = false);
    try {
      final prefs = await SharedPreferences.getInstance();
      // Oculta por 7 dias
      final dismissUntil =
          DateTime.now().add(const Duration(days: 7)).millisecondsSinceEpoch;
      await prefs.setInt(_dismissKey, dismissUntil);
    } catch (_) {}
  }

  void _onInstallAction() {
    if (PwaInstaller.isIosWeb) {
      _showIosInstructions();
    } else {
      if (PwaInstaller.canPromptInstall) {
        PwaInstaller.promptInstall();
      } else {
        _showAndroidInstructions();
      }
    }
  }

  void _showIosInstructions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: MetaColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.apple_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Instalar no iPhone / iPad',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Apenas 3 passos no Safari',
                          style: TextStyle(
                            color: MetaColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildInstructionStep(
                step: '1',
                icon: Icons.ios_share_rounded,
                title: 'Toque em Compartilhar',
                description: 'Toque no ícone de compartilhamento na barra inferior do Safari.',
              ),
              const SizedBox(height: 16),
              _buildInstructionStep(
                step: '2',
                icon: Icons.add_box_outlined,
                title: 'Adicionar à Tela de Início',
                description: 'Role a lista de opções para baixo e toque em "Adicionar à Tela de Início".',
              ),
              const SizedBox(height: 16),
              _buildInstructionStep(
                step: '3',
                icon: Icons.check_circle_outline_rounded,
                title: 'Confirmar e Abrir',
                description: 'Toque em "Adicionar" no canto superior direito. Pronto! O app estará na sua tela inicial.',
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MetaColors.emerald,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'Entendido!',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAndroidInstructions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: MetaColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.android_rounded, color: MetaColors.emerald, size: 28),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Instalar no Android',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Passo a passo no Chrome',
                          style: TextStyle(
                            color: MetaColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildInstructionStep(
                step: '1',
                icon: Icons.more_vert_rounded,
                title: 'Abra o Menu do Chrome',
                description: 'Toque nos três pontinhos no canto superior direito do navegador.',
              ),
              const SizedBox(height: 16),
              _buildInstructionStep(
                step: '2',
                icon: Icons.install_mobile_rounded,
                title: 'Instalar Aplicativo',
                description: 'Selecione "Instalar aplicativo" ou "Adicionar à tela inicial".',
              ),
              const SizedBox(height: 16),
              _buildInstructionStep(
                step: '3',
                icon: Icons.check_circle_outline_rounded,
                title: 'Confirmar',
                description: 'Confirme a instalação. O Mr. Coach abrirá em tela cheia com alta performance!',
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MetaColors.emerald,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'Entendido!',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionStep({
    required String step,
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: MetaColors.emerald.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(color: MetaColors.emerald, width: 1.2),
          ),
          child: Text(
            step,
            style: const TextStyle(
              color: MetaColors.emerald,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: Colors.white70, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  color: MetaColors.textSecondary,
                  fontSize: 12.5,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) return const SizedBox.shrink();

    final isIos = PwaInstaller.isIosWeb;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MetaColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: MetaColors.emerald.withValues(alpha: 0.35),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Ícone App / PWA
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              'assets/images/mr_coach_logo_gold.jpg',
              width: 44,
              height: 44,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: 44,
                height: 44,
                color: Colors.black,
                child: const Icon(
                  Icons.fitness_center_rounded,
                  color: MetaColors.emerald,
                  size: 24,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Textos
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Instalar App Mr. Coach',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isIos
                      ? 'Adicione à tela de início para tela cheia'
                      : 'Acesso rápido e tela cheia no seu dispositivo',
                  style: const TextStyle(
                    color: MetaColors.textSecondary,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Botão Ação
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: MetaColors.emerald,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: _onInstallAction,
            child: Text(
              isIos ? 'Como instalar' : 'Instalar',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Botão Fechar (X)
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18, color: MetaColors.textSecondary),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            splashRadius: 18,
            onPressed: _dismissBanner,
            tooltip: 'Fechar',
          ),
        ],
      ),
    );
  }
}

