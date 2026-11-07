import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/widgets/meta_components.dart';
import '../../../../models/operational_cockpit_model.dart';

/// Radar de Retenção Proativa & Anti-Evasão do Treinador.
///
/// Destaca alunos ausentes (>4 dias sem treinar) com ação direta de
/// reengajamento WhatsApp 1-Toque e respeito à trava anti-spam de 48h.
class TrainerRetentionRadar extends StatelessWidget {
  final List<InactiveStudentCard> inactiveStudents;
  final ValueChanged<InactiveStudentCard> onContactStudent;
  final ValueChanged<InactiveStudentCard>? onStudentDetails;

  const TrainerRetentionRadar({
    super.key,
    required this.inactiveStudents,
    required this.onContactStudent,
    this.onStudentDetails,
  });

  @override
  Widget build(BuildContext context) {
    if (inactiveStudents.isEmpty) {
      return const SizedBox.shrink();
    }

    final isDark = MetaColors.isDark(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Título da Seção do Radar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.radar_rounded,
                      color: Colors.redAccent,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Radar Anti-Evasão',
                      style: TextStyle(
                        color: MetaColors.text(context),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.redAccent.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        '${inactiveStudents.length} em risco',
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  '>4 dias sem treino',
                  style: TextStyle(
                    color: MetaColors.subtext(context),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // 2. Carrossel Horizontal de Alunos em Risco
          SizedBox(
            height: 140,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: inactiveStudents.length,
              separatorBuilder: (context, index) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final student = inactiveStudents[index];
                final isContacted = student.recentlyContacted48h;

                return Container(
                  width: 260,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: MetaColors.card(context),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isContacted
                          ? MetaColors.cardBorder(context)
                          : Colors.redAccent.withValues(alpha: 0.3),
                      width: isContacted ? 0.8 : 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color:
                            Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Linha de Identificação do Aluno
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor:
                                Colors.redAccent.withValues(alpha: 0.15),
                            child: Text(
                              _initials(student.fullName),
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  student.fullName,
                                  style: TextStyle(
                                    color: MetaColors.text(context),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.access_time_rounded,
                                      size: 11,
                                      color: Colors.redAccent,
                                    ),
                                    const SizedBox(width: 3),
                                    Expanded(
                                      child: Text(
                                        'Ausente há ${student.daysInactive} dias',
                                        style: const TextStyle(
                                          color: Colors.redAccent,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Botão de Ação: WhatsApp 1-Toque ou Status 48h
                      InkWell(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          onContactStudent(student);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: isContacted
                                ? MetaColors.highlight(context)
                                : MetaColors.emerald.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isContacted
                                  ? MetaColors.cardBorder(context)
                                  : MetaColors.emerald.withValues(alpha: 0.4),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isContacted
                                    ? Icons.done_all_rounded
                                    : Icons.chat_bubble_rounded,
                                size: 14,
                                color: isContacted
                                    ? MetaColors.subtext(context)
                                    : MetaColors.emerald,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  isContacted
                                      ? 'Contatado (trava 48h)'
                                      : 'Reengajar WhatsApp (1-Toque)',
                                  style: TextStyle(
                                    color: isContacted
                                        ? MetaColors.subtext(context)
                                        : MetaColors.emerald,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return 'A';
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}
