import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/student_notification_service.dart';
import '../../services/auth_service.dart';
import 'meta_components.dart';

class StudentNotificationSheet extends StatefulWidget {
  final VoidCallback? onOpenWorkout;

  const StudentNotificationSheet({
    super.key,
    this.onOpenWorkout,
  });

  static Future<void> show(BuildContext context, {VoidCallback? onOpenWorkout}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StudentNotificationSheet(onOpenWorkout: onOpenWorkout),
    );
  }

  @override
  State<StudentNotificationSheet> createState() => _StudentNotificationSheetState();
}

class _StudentNotificationSheetState extends State<StudentNotificationSheet> {
  int _dailyGoal = 2500;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = AuthService.currentUser;
    if (user != null) {
      final goal = await StudentNotificationService.instance.getDailyHydrationGoal(user.id);
      if (mounted) {
        setState(() {
          _dailyGoal = goal;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
    await StudentNotificationService.instance.refreshNotifications();
  }

  Future<void> _addWater(int ml) async {
    HapticFeedback.mediumImpact();
    final user = AuthService.currentUser;
    if (user == null) return;
    await StudentNotificationService.instance.addWaterIntake(user.id, ml);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.water_drop_rounded, color: Color(0xFF38BDF8), size: 18),
            const SizedBox(width: 8),
            Text('+$ml ml de água registrado com sucesso!'),
          ],
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = MetaColors.isDark(context);
    final maxHeight = MediaQuery.of(context).size.height * 0.88;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
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
          // Drag handle One UI 7
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

          // Header
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
                        Icons.notifications_active_rounded,
                        color: MetaColors.primaryColor(context),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Notificações & Lembretes',
                          style: TextStyle(
                            color: MetaColors.text(context),
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        ValueListenableBuilder<int>(
                          valueListenable: StudentNotificationService.unreadCountNotifier,
                          builder: (context, count, child) {
                            return Text(
                              count == 0
                                  ? 'Tudo em dia!'
                                  : '$count ${count == 1 ? 'pendência ativa' : 'pendências ativas'}',
                              style: TextStyle(
                                color: count == 0
                                    ? MetaColors.subtext(context)
                                    : MetaColors.primaryColor(context),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert_rounded, color: MetaColors.subtext(context)),
                  color: MetaColors.card(context),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  onSelected: (val) {
                    if (val == 'read_all') {
                      StudentNotificationService.instance.markAllAsRead();
                    } else if (val == 'clear_read') {
                      StudentNotificationService.instance.clearReadNotifications();
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'read_all',
                      child: Row(
                        children: [
                          Icon(Icons.done_all_rounded, size: 18),
                          SizedBox(width: 8),
                          Text('Marcar todas como lidas'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'clear_read',
                      child: Row(
                        children: [
                          Icon(Icons.cleaning_services_rounded, size: 18),
                          SizedBox(width: 8),
                          Text('Limpar lidas'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Scrollable Body
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: MetaColors.primaryColor(context),
                    ),
                  )
                : ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    children: [
                      // 1. Card Interativo de Hidratação Rápida
                      _buildHydrationCard(context, isDark),
                      const SizedBox(height: 16),

                      // 2. Título de Alertas e Notificações
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Gatilhos & Avisos Inteligentes',
                            style: TextStyle(
                              color: MetaColors.text(context),
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          ValueListenableBuilder<List<StudentNotificationItem>>(
                            valueListenable:
                                StudentNotificationService.notificationsNotifier,
                            builder: (context, items, child) {
                              return Text(
                                '${items.length} ${items.length == 1 ? 'item' : 'itens'}',
                                style: TextStyle(
                                  color: MetaColors.subtext(context),
                                  fontSize: 12,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // 3. Lista de Notificações
                      ValueListenableBuilder<List<StudentNotificationItem>>(
                        valueListenable:
                            StudentNotificationService.notificationsNotifier,
                        builder: (ctx, items, _) {
                          if (items.isEmpty) {
                            return _buildEmptyState(context);
                          }

                          return Column(
                            children: items.map((item) {
                              return _buildNotificationCard(context, item, isDark);
                            }).toList(),
                          );
                        },
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // WIDGET: CARD DE HIDRATAÇÃO RÁPIDA
  // ===========================================================================
  Widget _buildHydrationCard(BuildContext context, bool isDark) {
    return ValueListenableBuilder<int>(
      valueListenable: StudentNotificationService.todayHydrationNotifier,
      builder: (context, current, child) {
        final progress = _dailyGoal > 0 ? (current / _dailyGoal).clamp(0.0, 1.0) : 0.0;
        final pct = (progress * 100).toInt();

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [
                      const Color(0xFF0C243B),
                      const Color(0xFF0F172A),
                    ]
                  : [
                      const Color(0xFFE0F2FE),
                      const Color(0xFFF0F9FF),
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: const Color(0xFF38BDF8).withValues(alpha: 0.35),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFF38BDF8).withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.water_drop_rounded,
                          color: Color(0xFF38BDF8),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Hidratação de Hoje',
                        style: TextStyle(
                          color: MetaColors.text(context),
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: progress >= 1.0
                          ? const Color(0xFF10B981).withValues(alpha: 0.2)
                          : const Color(0xFF38BDF8).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      progress >= 1.0 ? '🎉 Meta Atingida!' : '$pct% Concluído',
                      style: TextStyle(
                        color: progress >= 1.0
                            ? const Color(0xFF10B981)
                            : const Color(0xFF38BDF8),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Volume atual e meta
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '$current',
                    style: TextStyle(
                      color: MetaColors.text(context),
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    ' / $_dailyGoal ml',
                    style: TextStyle(
                      color: MetaColors.subtext(context),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Barra de Progresso
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: MetaColors.cardBorder(context).withValues(alpha: 0.5),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progress >= 1.0 ? const Color(0xFF10B981) : const Color(0xFF38BDF8),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Botões Rápidos de Registro (+200ml, +350ml, +500ml)
              Row(
                children: [
                  Expanded(
                    child: _buildQuickWaterButton(
                      label: '+200ml',
                      icon: Icons.local_drink_rounded,
                      onTap: () => _addWater(200),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildQuickWaterButton(
                      label: '+350ml',
                      icon: Icons.water_drop_outlined,
                      onTap: () => _addWater(350),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildQuickWaterButton(
                      label: '+500ml',
                      icon: Icons.water_rounded,
                      onTap: () => _addWater(500),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickWaterButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF38BDF8).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFF38BDF8).withValues(alpha: 0.3),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: const Color(0xFF38BDF8)),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF38BDF8),
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // WIDGET: CARD DE NOTIFICAÇÃO INDIVIDUAL
  // ===========================================================================
  Widget _buildNotificationCard(
    BuildContext context,
    StudentNotificationItem item,
    bool isDark,
  ) {
    Color tintColor;
    IconData icon;

    switch (item.type) {
      case NotificationType.frequency:
        tintColor = item.severity == NotificationSeverity.urgent
            ? const Color(0xFFEF4444)
            : const Color(0xFFF59E0B);
        icon = Icons.local_fire_department_rounded;
        break;
      case NotificationType.hydration:
        tintColor = item.severity == NotificationSeverity.success
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
      case NotificationType.system:
        tintColor = const Color(0xFF64748B);
        icon = Icons.info_outline_rounded;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: item.isRead
            ? MetaColors.card(context).withValues(alpha: 0.6)
            : MetaColors.highlight(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: item.isRead
              ? MetaColors.cardBorder(context)
              : tintColor.withValues(alpha: 0.4),
          width: item.isRead ? 0.8 : 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: tintColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: tintColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              color: MetaColors.text(context),
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        if (!item.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(left: 6),
                            decoration: BoxDecoration(
                              color: tintColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.message,
                      style: TextStyle(
                        color: MetaColors.subtext(context),
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: MetaColors.subtext(context).withValues(alpha: 0.6),
                ),
                onPressed: () =>
                    StudentNotificationService.instance.dismiss(item.id),
                tooltip: 'Dispensar',
              ),
            ],
          ),

          // Botão de ação (se houver)
          if (item.actionLabel != null) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!item.isRead)
                  TextButton(
                    onPressed: () =>
                        StudentNotificationService.instance.markAsRead(item.id),
                    child: Text(
                      'Marcar como lida',
                      style: TextStyle(
                        color: MetaColors.subtext(context),
                        fontSize: 12,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    StudentNotificationService.instance.markAsRead(item.id);
                    if (item.type == NotificationType.hydration) {
                      _addWater(350);
                    } else if (item.type == NotificationType.frequency ||
                        item.type == NotificationType.workoutPlan) {
                      Navigator.pop(context);
                      widget.onOpenWorkout?.call();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tintColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    item.actionLabel!,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            color: MetaColors.primaryColor(context),
            size: 46,
          ),
          const SizedBox(height: 12),
          Text(
            'Tudo Limpo e em Dia!',
            style: TextStyle(
              color: MetaColors.text(context),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Você não tem pendências de treinos ou hidratação no momento. Continue assim!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: MetaColors.subtext(context),
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
