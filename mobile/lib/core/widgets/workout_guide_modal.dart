import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'meta_components.dart';

/// Modal interativo com passo a passo e guia completo (Antes, Durante e Pós-Treino)
/// para orientar o aluno a iniciar o treino e ter o melhor resultado.
class WorkoutGuideModal extends StatefulWidget {
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
  State<WorkoutGuideModal> createState() => _WorkoutGuideModalState();
}

class _WorkoutGuideModalState extends State<WorkoutGuideModal> {
  int _selectedTab = 0; // 0: Geral, 1: Antes, 2: Durante, 3: Pós-Treino

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
        maxHeight: MediaQuery.of(context).size.height * 0.90,
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
                        'Guia interativo para antes, durante e pós-treino',
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

            const SizedBox(height: 16),

            // Seletor de Fases (Abas em Pílula)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _buildTabPill(index: 0, label: '⚡ Passo a Passo', isDark: isDark),
                  const SizedBox(width: 8),
                  _buildTabPill(index: 1, label: '🥗 Antes do Treino', isDark: isDark),
                  const SizedBox(width: 8),
                  _buildTabPill(index: 2, label: '🏋️ Durante o Treino', isDark: isDark),
                  const SizedBox(width: 8),
                  _buildTabPill(index: 3, label: '🔥 Pós-Treino', isDark: isDark),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Conteúdo condicional por aba
            if (_selectedTab == 0) ...[
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
            ] else if (_selectedTab == 1) ...[
              // ANTES DO TREINO
              _buildDetailCard(
                icon: Icons.restaurant_rounded,
                iconColor: Colors.orangeAccent,
                title: 'Alimentação Pré-Treino',
                description:
                    'Faça uma refeição leve de 60 a 90 minutos antes do treino com carboidratos de média absorção (ex: banana com aveia) para garantir energia muscular sem peso estomacal.',
                cardBg: cardBg,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
              const SizedBox(height: 10),
              _buildDetailCard(
                icon: Icons.water_drop_rounded,
                iconColor: Colors.blueAccent,
                title: 'Hidratação Prévia',
                description:
                    'Beba de 350ml a 500ml de água cerca de 1 hora antes de começar. Músculos bem hidratados têm até 15% mais força e menor risco de lesão.',
                cardBg: cardBg,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
              const SizedBox(height: 10),
              _buildDetailCard(
                icon: Icons.sports_gymnastics_rounded,
                iconColor: Colors.amberAccent,
                title: 'Aquecimento Articular & Mobilidade',
                description:
                    'Antes de colocar a carga principal, faça 2 a 3 séries leves de ativação articular e neuromuscular na própria máquina. Isso prepara os ligamentos e o manguito/joelho.',
                cardBg: cardBg,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
            ] else if (_selectedTab == 2) ...[
              // DURANTE O TREINO
              _buildDetailCard(
                icon: Icons.timer_outlined,
                iconColor: MetaColors.emerald,
                title: 'Controle de Descanso entre Séries',
                description:
                    'Respeite o cronômetro do app (60s a 90s para hipertrofia, 2min a 3min para força). O descanso correto garante a recuperação do ATP fosfocreatina.',
                cardBg: cardBg,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
              const SizedBox(height: 10),
              _buildDetailCard(
                icon: Icons.accessibility_new_rounded,
                iconColor: Colors.cyanAccent,
                title: 'Amplitude & Cadência sem Compensação',
                description:
                    'Controle a fase excêntrica (descida do peso em 2-3 segundos). Evite roubar com impulsos na coluna ou articulações.',
                cardBg: cardBg,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
              const SizedBox(height: 10),
              _buildDetailCard(
                icon: Icons.auto_awesome,
                iconColor: Colors.purpleAccent,
                title: 'Aparelho Ocupado ou Dor Articular?',
                description:
                    'Toque no botão de adaptação no card do exercício. O Mr. Coach IA sugere imediatamente um substituto biomecanicamente equivalente e avisa seu treinador.',
                cardBg: cardBg,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
            ] else ...[
              // PÓS-TREINO
              _buildDetailCard(
                icon: Icons.check_circle_rounded,
                iconColor: MetaColors.emerald,
                title: 'Toque em "Finalizar Treino" na Base',
                description:
                    'Crucial: registrar a conclusão do treino atualiza sua ofensiva de treinos seguidos (Streak 🔥) e envia o resumo da sessão para o WhatsApp e painel do seu professor.',
                cardBg: cardBg,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
              const SizedBox(height: 10),
              _buildDetailCard(
                icon: Icons.egg_alt_outlined,
                iconColor: Colors.tealAccent,
                title: 'Nutrição Pós-Treino & Síntese Proteica',
                description:
                    'Consuma uma fonte proteica de boa qualidade e carboidratos nas primeiras 1 a 2 horas após a sessão para reparar as microlesões musculares.',
                cardBg: cardBg,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
              const SizedBox(height: 10),
              _buildDetailCard(
                icon: Icons.nightlight_round,
                iconColor: Colors.indigoAccent,
                title: 'Descanso e Sono Reparador',
                description:
                    'O músculo cresce durante o sono profundo, momento em que há maior secreção de hormônio do crescimento (GH). Priorize 7 a 8 horas de sono.',
                cardBg: cardBg,
                textPrimary: textPrimary,
                textSecondary: textSecondary,
              ),
            ],

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

  Widget _buildTabPill({
    required int index,
    required String label,
    required bool isDark,
  }) {
    final isSelected = _selectedTab == index;
    return InkWell(
      onTap: () => setState(() => _selectedTab = index),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.studentCyan
              : (isDark ? const Color(0xFF22272E) : const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.studentCyan
                : (isDark ? const Color(0xFF38404A) : const Color(0xFFD1D5DB)),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
            color: isSelected
                ? Colors.black
                : (isDark ? Colors.white : const Color(0xFF1F2937)),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required Color cardBg,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: iconColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Icon(icon, color: iconColor, size: 20),
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
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
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
