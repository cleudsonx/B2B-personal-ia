import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../utils/pwa_installer.dart';
import 'meta_components.dart';

/// Notificador reativo de atualização disponível
class PwaUpdateNotifier extends ChangeNotifier {
  static final PwaUpdateNotifier instance = PwaUpdateNotifier._();
  PwaUpdateNotifier._();

  bool _updateAvailable = false;
  String _newVersion = '';
  int _newBuild = 0;
  bool _dismissed = false;

  bool get updateAvailable => _updateAvailable && !_dismissed;
  String get newVersion => _newVersion;
  int get newBuild => _newBuild;

  void setUpdateAvailable(String version, int build) {
    if (_newBuild != build || !_updateAvailable) {
      _newVersion = version;
      _newBuild = build;
      _updateAvailable = true;
      _dismissed = false;
      notifyListeners();
    }
  }

  void dismiss() {
    _dismissed = true;
    notifyListeners();
  }
}

/// Wrapper global para detectar e exibir atualizações do PWA de forma nativa e garantida
/// no Android (Chrome/WebAPK) e iOS (Safari), sem depender unicamente de eventos do DOM.
class PwaUpdateWrapper extends StatefulWidget {
  final Widget child;

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
    if (kIsWeb) {
      WidgetsBinding.instance.addObserver(this);
      // Checagem inicial após 2 segundos
      Future.delayed(const Duration(seconds: 2), _checkForUpdate);
      // Checagem periódica a cada 2 minutos
      _checkTimer = Timer.periodic(const Duration(minutes: 2), (_) => _checkForUpdate());
    }
  }

  @override
  void dispose() {
    if (kIsWeb) {
      WidgetsBinding.instance.removeObserver(this);
      _checkTimer?.cancel();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && kIsWeb) {
      _checkForUpdate();
    }
  }

  Future<void> _checkForUpdate() async {
    if (_isChecking || !kIsWeb) return;
    _isChecking = true;

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      // Garante consulta direta na raiz com cache bust
      final uri = Uri.parse('/version.json?_t=$timestamp');
      final response = await http.get(uri).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final serverBuild = int.tryParse(data['build']?.toString() ?? '0') ?? 0;
        final serverVersion = data['version']?.toString() ?? '';

        if (serverBuild > AppConfig.buildNumber) {
          PwaUpdateNotifier.instance.setUpdateAvailable(serverVersion, serverBuild);
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
    if (!kIsWeb) {
      return widget.child;
    }

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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nova versão disponível!',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Toque para aplicar as melhorias.',
                    style: TextStyle(
                      color: subtextColor,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => PwaInstaller.triggerPwaReload(),
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

