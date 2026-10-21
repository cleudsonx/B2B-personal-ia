import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/offline_sync_service.dart';
import '../../services/auth_service.dart';
import 'meta_components.dart';

class OfflineSyncBanner extends StatefulWidget {
  final EdgeInsetsGeometry padding;

  const OfflineSyncBanner({
    super.key,
    this.padding = const EdgeInsets.only(bottom: 12),
  });

  @override
  State<OfflineSyncBanner> createState() => _OfflineSyncBannerState();
}

class _OfflineSyncBannerState extends State<OfflineSyncBanner> {
  bool _justSynced = false;

  Future<void> _handleSync() async {
    final user = AuthService.currentUser;
    if (user == null) return;
    HapticFeedback.mediumImpact();
    final synced = await OfflineSyncService.instance.syncAllPending(user.id);

    if (mounted) {
      if (synced > 0) {
        setState(() => _justSynced = true);
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted) setState(() => _justSynced = false);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: MetaColors.emerald, size: 18),
                const SizedBox(width: 8),
                Text('$synced item(ns) sincronizado(s) com a nuvem com sucesso!'),
              ],
            ),
            backgroundColor: const Color(0xFF0F172A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: OfflineSyncService.pendingCountNotifier,
      builder: (context, count, _) {
        if (count == 0 && !_justSynced) {
          return const SizedBox.shrink();
        }

        final isDark = MetaColors.isDark(context);

        if (_justSynced && count == 0) {
          return Padding(
            padding: widget.padding,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: MetaColors.emerald.withValues(alpha: isDark ? 0.15 : 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: MetaColors.emerald.withValues(alpha: 0.35),
                  width: 0.8,
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_done_rounded, color: MetaColors.emerald, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Todos os dados foram sincronizados com a nuvem!',
                    style: TextStyle(
                      color: MetaColors.emerald,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 200.ms),
          );
        }

        return Padding(
          padding: widget.padding,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.15 : 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.cloud_queue_rounded,
                    color: Color(0xFF818CF8),
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        count == 1
                            ? '1 treino/registro salvo offline'
                            : '$count treinos/registros salvos offline',
                        style: TextStyle(
                          color: MetaColors.text(context),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Seguro no aparelho. Sincronizará com a nuvem.',
                        style: TextStyle(
                          color: MetaColors.subtext(context),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ValueListenableBuilder<bool>(
                  valueListenable: OfflineSyncService.isSyncingNotifier,
                  builder: (ctx, isSyncing, _) {
                    return InkWell(
                      onTap: isSyncing ? null : _handleSync,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isSyncing) ...[
                              const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Sincronizando',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ] else ...[
                              const Icon(Icons.sync_rounded, size: 14, color: Colors.white),
                              const SizedBox(width: 4),
                              const Text(
                                'Sincronizar',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ).animate().fadeIn(duration: 200.ms).slideY(begin: -0.05, end: 0),
        );
      },
    );
  }
}
