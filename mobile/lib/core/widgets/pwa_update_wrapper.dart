import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../utils/pwa_installer.dart';
import 'meta_components.dart';
import 'app_version_footer.dart';

/// Notificador reativo de atualização disponível
class PwaUpdateNotifier extends ChangeNotifier {
  static final PwaUpdateNotifier instance = PwaUpdateNotifier._();
  PwaUpdateNotifier._();

  bool _updateAvailable = false;
  String _newVersion = '';
  int _newBuild = 0;
  Map<String, dynamic>? _remoteData;
  bool _dismissed = false;

  bool get updateAvailable => _updateAvailable && !_dismissed;
  String get newVersion => _newVersion;
  int get newBuild => _newBuild;
  Map<String, dynamic>? get remoteData => _remoteData;

  void setUpdateAvailable(String version, int build, [Map<String, dynamic>? remoteData]) {
    if (_newBuild != build || !_updateAvailable || _remoteData != remoteData) {
      _newVersion = version;
      _newBuild = build;
      _remoteData = remoteData;
      _updateAvailable = true;
      _dismissed = false;
      notifyListeners();
    }
  }

  void reset() {
    if (_updateAvailable || _dismissed) {
      _updateAvailable = false;
      _dismissed = false;
      _newVersion = '';
      _newBuild = 0;
      _remoteData = null;
      notifyListeners();
    }
  }

  void dismiss() {
    _dismissed = true;
    notifyListeners();
  }
}

/// Wrapper global para detectar e exibir atualizações do ecossistema de forma nativa e garantida
/// no Android (Chrome/WebAPK/APK), iOS (Safari/App) e Web, sem depender unicamente de eventos isolados do DOM.
class PwaUpdateWrapper extends StatefulWidget {
  final Widget child;

  /// Controla a checagem automática via timer de version.json.
  /// Pode ser desativado em testes automatizados para evitar timers pendentes.
  static bool enableAutoCheck = true;

  const PwaUpdateWrapper({super.key, required this.child});

  @override
  State<PwaUpdateWrapper> createState() => _PwaUpdateWrapperState();
}

class _PwaUpdateWrapperState extends State<PwaUpdateWrapper> with WidgetsBindingObserver {
  Timer? _checkTimer;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    if (kIsWeb) {
      // Checagem imediata via version.json se o Service Worker sinalizar update
      if (PwaInstaller.hasPendingUpdate) {
        _checkForUpdate();
      }

      // Quando o Service Worker detectar mudança, consulta /version.json como fonte da verdade
      PwaInstaller.onPwaUpdateAvailable(() {
        _checkForUpdate();
      });
    }

    if (PwaUpdateWrapper.enableAutoCheck) {
      // Checagem inicial via version.json após 1.2 segundos (Web, iOS e Android)
      Future.delayed(const Duration(milliseconds: 1200), _checkForUpdate);
      // Checagem periódica a cada 2 minutos
      _checkTimer = Timer.periodic(const Duration(minutes: 2), (_) => _checkForUpdate());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _checkTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkForUpdate();
    }
  }

  Future<void> _checkForUpdate() async {
    if (_isChecking) return;
    _isChecking = true;

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      // Garante consulta direta com cache bust e URL resolvida para cada plataforma
      final Uri uri;
      if (kIsWeb) {
        uri = Uri.base.resolve('/version.json?_t=$timestamp');
      } else {
        final apiHost = AppConfig.apiBaseUrl.replaceAll('/api/v1', '');
        final cleanBase = apiHost.isNotEmpty ? apiHost : 'https://shaipados.com';
        uri = Uri.parse('$cleanBase/version.json?_t=$timestamp');
      }
      final response = await http.get(uri).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final serverBuild = int.tryParse(data['build']?.toString() ?? '0') ?? 0;
        final serverVersion = data['version']?.toString() ?? '';

        if (serverBuild > AppConfig.buildNumber) {
          PwaUpdateNotifier.instance.setUpdateAvailable(serverVersion, serverBuild, data);
        } else {
          // Servidor está na mesma versão (ou o cliente é mais recente).
          // Cancela qualquer alerta espúrio para impedir loops infinitos.
          PwaUpdateNotifier.instance.reset();
        }
      }
    } catch (_) {
      // Falhas de rede silenciosas para não interromper a UX do usuário
    } finally {
      _isChecking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: PwaUpdateNotifier.instance,
      builder: (context, _) {
        final hasUpdate = PwaUpdateNotifier.instance.updateAvailable;

        return Stack(
          children: [
            widget.child,
            if (hasUpdate)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: _buildBanner(context),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildBanner(BuildContext context) {
    final isDark = MetaColors.isDark(context);
    final bg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: MetaColors.emerald.withValues(alpha: 0.6),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: MetaColors.emerald.withValues(alpha: 0.2),
              blurRadius: 16,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: MetaColors.emerald.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.rocket_launch_rounded,
                color: MetaColors.emerald,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: () => AppVersionFooter.showReleaseNotesModal(
                  context,
                  remoteReleaseData: PwaUpdateNotifier.instance.remoteData,
                ),
                borderRadius: BorderRadius.circular(8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Nova versão disponível!',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.info_outline_rounded, size: 14, color: MetaColors.emerald),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Toque para ver o que mudou e aplicar.',
                      style: TextStyle(
                        color: subtextColor,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                if (kIsWeb) {
                  PwaUpdateNotifier.instance.dismiss();
                  showDialog<void>(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => const ShaipadosLoaderContainer(
                      type: ShaipadosLoaderType.labShakerDna,
                      customTitle: 'Atualizando Shaipados Labs',
                      loadingMessages: [
                        'Sintetizando nova versão no Labs...',
                        'Carregando novos módulos e correções...',
                        'Reiniciando o sistema...',
                      ],
                    ),
                  );
                  Future.delayed(const Duration(milliseconds: 600), () {
                    PwaInstaller.triggerPwaReload();
                  });
                } else {
                  PwaUpdateNotifier.instance.dismiss();
                  AppVersionFooter.showReleaseNotesModal(
                    context,
                    remoteReleaseData: PwaUpdateNotifier.instance.remoteData,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: MetaColors.emerald,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Atualizar',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              icon: Icon(Icons.close_rounded, size: 18, color: subtextColor),
              onPressed: () => PwaUpdateNotifier.instance.dismiss(),
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}
