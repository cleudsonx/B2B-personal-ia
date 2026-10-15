import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'meta_components.dart';

/// Modal amigável com passo a passo ilustrado para o aluno aprender
/// a utilizar o app durante seus treinos de forma rápida e intuitiva.
class WorkoutGuideModal extends StatelessWidget {
  const WorkoutGuideModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const WorkoutGuideModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isDark ? const Color(0xFF14171A) : Colors.white;
    final cardBg = isDark ? const Color(0xFF1F2428) : const Color(0xFFF3F4F6);
    final textPrimary = isDark ? Colors.white : const Color(0xFF111827);
    final textSecondary = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: isDark ? const Color(0xFF2D333B) : const Color(0xFFE5E7EB),
          width: 1,
        ),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + bottomInset),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF38404A) : const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.studentCyan.withValues(alpha: 0.25),
                      AppColors.studentCyan.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.studentCyan.withValues(alpha: 0.4),
                  ),
                ),
                child: const Icon(
                  Icons.fitness_center_rounded,
                  color: AppColors.studentCyan,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Como treinar com o App ⚡',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Guia rápido de 4 passos para o salão',
                      style: TextStyle(
                        fontSize: 12,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.close_rounded, color: textSecondary, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Step 1: Escolha sua divisão
          _buildStepItem(
            stepNumber: '1',
            title: 'Escolha a divisão do dia (Treino A, B, C...)',
            description:
                'Toque na aba com o foco muscular prescrito pelo seu treinador (ex: Peito/Tríceps ou Pernas).',
            icon: Icons.splitscreen_rounded,
            iconColor: AppColors.studentCyan,
            cardBg: cardBg,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          const SizedBox(height: 10),

          // Step 2: Ative o Modo Salão
          _buildStepItem(
            stepNumber: '2',
            title: 'Ative o Modo Salão (Focus Mode)',
            description:
                'Ao tocar em "Iniciar Treino", você ganha controles fáceis para registrar cargas e repetições sem digitar, com cronômetro de descanso automático.',
            icon: Icons.bolt_rounded,
            iconColor: Colors.amber,
            cardBg: cardBg,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          const SizedBox(height: 10),

          // Step 3: Dúvidas ou Aparelho Ocupado?
          _buildStepItem(
            stepNumber: '3',
            title: 'Aparelho ocupado ou dor no movimento?',
            description:
                'Toque no botão de IA em qualquer exercício ou vá até a aba "Mr. Coach AI" para encontrar na hora uma adaptação aprovada para o mesmo músculo.',
            icon: Icons.smart_toy_rounded,
            iconColor: MetaColors.emerald,
            cardBg: cardBg,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          const SizedBox(height: 10),

          // Step 4: Finalize e mantenha o Streak
          _buildStepItem(
            stepNumber: '4',
            title: 'Finalize para salvar sua evolução 🔥',
            description:
                'Ao terminar as séries, toque em "Finalizar Treino". Seu professor recebe seus registros e você mantém sua sequência de treinos (Streak) ativa!',
            icon: Icons.local_fire_department_rounded,
            iconColor: Colors.deepOrangeAccent,
            cardBg: cardBg,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),

          const SizedBox(height: 22),

          // Action Button
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.studentCyan,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Entendi, vamos treinar!',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildStepItem({
    required String stepNumber,
    required String title,
    required String description,
    required IconData icon,
    required Color iconColor,
    required Color cardBg,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Icon(icon, color: iconColor, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.35,
                    color: textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

