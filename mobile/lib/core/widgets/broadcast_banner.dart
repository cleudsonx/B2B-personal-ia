import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/admin/services/admin_data_service.dart';
import 'meta_components.dart';

/// Banner dinâmico de comunicados globais e avisos do sistema (Módulo 6 Admin)
class BroadcastBanner extends StatefulWidget {
  final String audience; // 'trainers' ou 'students'
  final EdgeInsetsGeometry padding;

  const BroadcastBanner({
    super.key,
    required this.audience,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  });

  @override
  State<BroadcastBanner> createState() => _BroadcastBannerState();
}

class _BroadcastBannerState extends State<BroadcastBanner> {
  AdminBroadcastMessage? _activeBroadcast;
  bool _isDismissed = false;

  @override
  void initState() {
    super.initState();
    _loadBroadcast();
  }

  Future<void> _loadBroadcast() async {
    try {
      final list = await AdminDataService.getBroadcasts();
      final prefs = await SharedPreferences.getInstance();
      final dismissedList = prefs.getStringList('dismissed_broadcast_ids') ?? [];

      final valid = list.where((b) {
        if (!b.isActive) return false;
        if (dismissedList.contains(b.id)) return false;
        return b.targetAudience == 'all' || b.targetAudience == widget.audience;
      }).toList();

      if (valid.isNotEmpty && mounted) {
        setState(() {
          _activeBroadcast = valid.first;
        });
      }
    } catch (e) {
      debugPrint('[BroadcastBanner] Aviso ao carregar comunicados: $e');
    }
  }

  Future<void> _dismiss(String id) async {
    setState(() => _isDismissed = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final dismissedList = prefs.getStringList('dismissed_broadcast_ids') ?? [];
      if (!dismissedList.contains(id)) {
        dismissedList.add(id);
        await prefs.setStringList('dismissed_broadcast_ids', dismissedList);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_isDismissed || _activeBroadcast == null) {
      return const SizedBox.shrink();
    }

    final bc = _activeBroadcast!;
    Color bgTint;
    Color borderTint;
    Color iconColor;
    IconData icon;

    if (bc.severity == 'urgent') {
      bgTint = const Color(0xFFEF4444).withValues(alpha: 0.12);
      borderTint = const Color(0xFFEF4444).withValues(alpha: 0.4);
      iconColor = const Color(0xFFEF4444);
      icon = Icons.error_outline_rounded;
    } else if (bc.severity == 'warning') {
      bgTint = const Color(0xFFF59E0B).withValues(alpha: 0.12);
      borderTint = const Color(0xFFF59E0B).withValues(alpha: 0.4);
      iconColor = const Color(0xFFF59E0B);
      icon = Icons.warning_amber_rounded;
    } else {
      bgTint = const Color(0xFF6366F1).withValues(alpha: 0.12);
      borderTint = const Color(0xFF6366F1).withValues(alpha: 0.4);
      iconColor = const Color(0xFF818CF8);
      icon = Icons.campaign_rounded;
    }

    final isDark = MetaColors.isDark(context);

    return Padding(
      padding: widget.padding,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? bgTint : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderTint, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: iconColor.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    bc.title,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    bc.message,
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black54,
                      fontSize: 11.5,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.close_rounded, size: 16, color: isDark ? Colors.white54 : Colors.black45),
              tooltip: 'Dispensar aviso',
              splashRadius: 16,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => _dismiss(bc.id),
            ),
          ],
        ),
      )
          .animate()
          .fadeIn(duration: 300.ms)
          .slideY(begin: -0.15, end: 0, duration: 300.ms),
    );
  }
}
