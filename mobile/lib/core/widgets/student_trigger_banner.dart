import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/student_notification_service.dart';
import '../../services/auth_service.dart';
import 'meta_components.dart';
import 'student_notification_sheet.dart';

class StudentTriggerBanner extends StatelessWidget {
  final VoidCallback? onOpenWorkout;
  final EdgeInsetsGeometry padding;

  const StudentTriggerBanner({
    super.key,
    this.onOpenWorkout,
    this.padding = const EdgeInsets.only(bottom: 12),
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<StudentNotificationItem>>(
      valueListenable: StudentNotificationService.notificationsNotifier,
      builder: (context, items, _) {
        // Encontrar a primeira notificação não lida com alta prioridade (urgente ou aviso)
        final activeList = items.where((e) => !e.isRead).toList();
        if (activeList.isEmpty) return const SizedBox.shrink();

        final active = activeList.first;
        final isDark = MetaColors.isDark(context);

        Color tintColor;
        IconData icon;

        switch (active.type) {
          case NotificationType.frequency:
            tintColor = active.severity == NotificationSeverity.urgent
                ? const Color(0xFFEF4444)
                : const Color(0xFFF59E0B);
            icon = Icons.local_fire_department_rounded;
            break;
          case NotificationType.hydration:
            tintColor = active.severity == NotificationSeverity.success
                ? const Color(0xFF10B981)
                : const Color(0xFF38BDF8);
            icon = Icons.water_drop_rounded;
            break;
          case NotificationType.workoutPlan:
            tintColor = const Color(0xFF8B5CF6);
            icon = Icons.assignment_rounded;
            break;
          case NotificationType.trainerMessage:
            tintColor = const Color(0xFF10B981);
            icon = Icons.chat_bubble_outline_rounded;
            break;
          case NotificationType.weeklyCheckin:
            tintColor = active.severity == NotificationSeverity.urgent
                ? const Color(0xFFEF4444)
                : const Color(0xFFF59E0B);
            icon = Icons.scale_rounded;
            break;
          case NotificationType.system:
            tintColor = const Color(0xFF64748B);
            icon = Icons.info_outline_rounded;
            break;
        }

        return Padding(
          padding: padding,
          child: InkWell(
            onTap: () => StudentNotificationSheet.show(
              context,
              onOpenWorkout: onOpenWorkout,
            ),
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: tintColor.withValues(alpha: isDark ? 0.14 : 0.09),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: tintColor.withValues(alpha: 0.35),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: tintColor.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: tintColor, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          active.title,
                          style: TextStyle(
                            color: MetaColors.text(context),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 1),
                        Text(
                          active.message,
                          style: TextStyle(
                            color: MetaColors.subtext(context),
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (active.actionLabel != null)
                    InkWell(
                      onTap: () async {
                        HapticFeedback.lightImpact();
                        await StudentNotificationService.instance.markAsRead(active.id);
                        if (active.type == NotificationType.hydration) {
                          final user = AuthService.currentUser;
                          if (user != null) {
                            await StudentNotificationService.instance.addWaterIntake(user.id, 250);
                          }
                        } else if (active.type == NotificationType.frequency ||
                            active.type == NotificationType.workoutPlan) {
                          onOpenWorkout?.call();
                        }
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: tintColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          active.actionLabel!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: MetaColors.subtext(context).withValues(alpha: 0.6),
                    ),
                    onPressed: () =>
                        StudentNotificationService.instance.dismiss(active.id),
                    tooltip: 'Dispensar',
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(duration: 200.ms).slideY(begin: -0.1, end: 0),
        );
      },
    );
  }
}
