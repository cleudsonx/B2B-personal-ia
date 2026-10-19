import 'package:flutter/material.dart';
import 'meta_components.dart';

/// Modal interativo com padrão ouro de usabilidade (inspirado em Hevy, Strong e Apple Fitness)
/// Guia ergonômico e direto ao ponto para orientar o aluno antes, durante e pós-treino no salão de musculação.
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
  int _selectedTab = 0; // 0: No Salão (Passo a Passo), 1: Cargas & Execução, 2: Dores & Trocas, 3: Pré & Pós-Treino

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isDark = MetaColors.isDark(context);

    final bgColor = MetaColors.bg(context);
    final textPrimary = MetaColors.text(context);
    final textSecondary = MetaColors.subtext(context);
    final highlightColor = MetaColors.highlight(context);
    final borderColor = MetaColors.cardBorder(context);
    final primaryAccent = MetaColors.emerald;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 680,
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: borderColor,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.15),
                blurRadius: 32,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Drag Handle ergonômico no topo
              Center(
                child: Container(
                  width: 48,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 2. Cabeçalho Premium com Ícone em Destaque e Fechar
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          primaryAccent.withValues(alpha: 0.25),
                          primaryAccent.withValues(alpha: 0.08),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: primaryAccent.withValues(alpha: 0.35),
                        width: 1.2,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.fitness_center_rounded,
                        color: MetaColors.emerald,
                        size: 22,
                      ),
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
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Guia interativo para antes, durante e pós-treino',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: highlightColor,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          color: textSecondary,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // 3. Seletor de Fases (Segmented Pills com rolagem horizontal fluida)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildTabPill(
                      index: 0,
                      label: '⚡ No Salão',
                      sublabel: 'Passo a passo',
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _buildTabPill(
                      index: 1,
                      label: '🏋️ Execução & Cargas',
                      sublabel: 'Sobrecarga',
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _buildTabPill(
                      index: 2,
                      label: '🤖 Aparelho Ocupado',
                      sublabel: 'IA de troca',
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    _buildTabPill(
                      index: 3,
                      label: '🥗 Pré & Pós-Treino',
                      sublabel: 'Recuperação',
                      isDark: isDark,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 4. Área de Conteúdo Rolável
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_selectedTab == 0) ...[
                        // Passo 1: Divisão do Dia
                        _buildStepCard(
                          stepNumber: '1',
                          badgeColor: MetaColors.emerald,
                          title: 'Escolha a divisão do dia (Treino A, B, C...)',
                          description:
                              'Toque na aba do split prescrito pelo seu treinador (ex: Peito/Tríceps, Pernas ou Costas). Você visualiza todos os exercícios em ordem otimizada.',
                          icon: Icons.splitscreen_rounded,
                          iconColor: MetaColors.emerald,
                          tip: '💡 Dica: Siga a ordem montada pelo seu treinador para melhor rendimento energético.',
                          isDark: isDark,
                        ),
                        const SizedBox(height: 12),

                        // Passo 2: Modo Salão (Focus Mode)
                        _buildStepCard(
                          stepNumber: '2',
                          badgeColor: Colors.amber,
                          title: 'Ative o Modo Salão (Focus Mode)',
                          description:
                              'Toque em "Iniciar Treino". Os botões de carga e repetições ficam gigantes para você ajustar no toque. Marque a série como concluída e o cronômetro de descanso dispara na hora.',
                          icon: Icons.bolt_rounded,
                          iconColor: Colors.amber,
                          tip: '⚡ Zero distração: você treina sem teclado atrapalhando sua visão.',
                          isDark: isDark,
                        ),
                        const SizedBox(height: 12),

                        // Passo 3: Aparelho ocupado ou dor
                        _buildStepCard(
                          stepNumber: '3',
                          badgeColor: const Color(0xFFA855F7), // Purple
                          title: 'Aparelho ocupado ou dor no movimento?',
                          description:
                              'Não perca o ritmo! Toque no botão de IA no card do exercício para encontrar na hora uma adaptação aprovada pelo seu professor para o mesmo grupo muscular.',
                          icon: Icons.auto_awesome_rounded,
                          iconColor: const Color(0xFFA855F7),
                          tip: '🛡️ Segurança: O professor recebe a notificação da adaptação automaticamente.',
                          isDark: isDark,
                        ),
                        const SizedBox(height: 12),

                        // Passo 4: Finalize e mantenha o Streak
                        _buildStepCard(
                          stepNumber: '4',
                          badgeColor: const Color(0xFFF97316), // Orange
                          title: 'Finalize para salvar sua evolução 🔥',
                          description:
                              'Terminou as séries? Toque no botão gigante "Finalizar Treino" na base. Suas cargas ficam salvas para a próxima semana e sua ofensiva diária (Streak) é computada!',
                          icon: Icons.local_fire_department_rounded,
                          iconColor: const Color(0xFFF97316),
                          tip: '🔥 Consistência: Manter a sequência de treinos desbloqueia conquistas no app.',
                          isDark: isDark,
                        ),
                      ] else if (_selectedTab == 1) ...[
                        // Cargas e Execução
                        _buildDetailCard(
                          icon: Icons.trending_up_rounded,
                          iconColor: MetaColors.emerald,
                          title: 'Princípio da Sobrecarga Progressiva',
                          description:
                              'A hipertrofia acontece quando desafiamos o músculo. Sempre que conseguir completar o número máximo de repetições com boa postura, tente aumentar 1kg a 2kg na sessão seguinte.',
                          highlight: 'Progresso constante > Peso exagerado sem forma',
                          isDark: isDark,
                        ),
                        const SizedBox(height: 12),
                        _buildDetailCard(
                          icon: Icons.speed_rounded,
                          iconColor: Colors.cyanAccent,
                          title: 'Cadência Excêntrica (2 a 3 segundos)',
                          description:
                              'Não deixe o peso despencar! A fase de descida (excêntrica) gera a maior tensão mecânica e recrutamento de fibras musculares. Desça com controle absoluto.',
                          highlight: 'Subida explosiva (1s) e descida controlada (2-3s)',
                          isDark: isDark,
                        ),
                        const SizedBox(height: 12),
                        _buildDetailCard(
                          icon: Icons.timer_outlined,
                          iconColor: Colors.amberAccent,
                          title: 'Intervalos de Descanso Científicos',
                          description:
                              'Respeite o cronômetro do app. Exercícios compostos pesados (Agachamento, Supino, Levantamento Terra) exigem de 2 a 3 minutos para restaurar a fosfocreatina. Isoladores pedem de 60 a 90 segundos.',
                          highlight: 'Descansar bem permite erguer mais carga na série seguinte',
                          isDark: isDark,
                        ),
                      ] else if (_selectedTab == 2) ...[
                        // Aparelho Ocupado / Dor
                        _buildDetailCard(
                          icon: Icons.swap_horiz_rounded,
                          iconColor: const Color(0xFFA855F7),
                          title: 'Substituição Instantânea de Máquina',
                          description:
                              'Se o banco ou a polia estiverem lotados, toque no botão "Substituir com IA". O sistema oferece alternativas equivalentes com halteres ou elásticos que trabalham o mesmo vetor de força.',
                          highlight: 'Mantenha o foco sem ficar esperando aparelho desocupar',
                          isDark: isDark,
                        ),
                        const SizedBox(height: 12),
                        _buildDetailCard(
                          icon: Icons.healing_rounded,
                          iconColor: Colors.redAccent,
                          title: 'Aviso de Dor Articular ou Desconforto',
                          description:
                              'Sente dor aguda no ombro, joelho ou lombar? Pare imediatamente a série. Acione a adaptação clínica biomecânica. O app registra o alerta e avisa seu treinador para ajuste na próxima ficha.',
                          highlight: 'Dor no músculo = OK | Dor na articulação/tendão = PARE',
                          isDark: isDark,
                        ),
                        const SizedBox(height: 12),
                        _buildDetailCard(
                          icon: Icons.history_rounded,
                          iconColor: Colors.lightBlueAccent,
                          title: 'Histórico Inteligente de Séries Anteriores',
                          description:
                              'Acima dos campos de digitação, o app sempre exibe o que você fez no treino passado (ex: 3x10 com 24kg). Você nunca mais precisará tentar adivinhar a carga de memória.',
                          highlight: 'Seu diário de treino no bolso com precisão de elite',
                          isDark: isDark,
                        ),
                      ] else ...[
                        // Pré & Pós-Treino
                        _buildDetailCard(
                          icon: Icons.restaurant_rounded,
                          iconColor: Colors.orangeAccent,
                          title: 'Alimentação Pré-Treino Inteligente',
                          description:
                              'Faça uma refeição equilibrada entre 60 e 90 minutos antes do treino. Priorize carboidratos de média absorção (banana com aveia, torrada com ovos) para fornecer glicogênio sem pesar o estômago.',
                          highlight: 'Energia disponível nos músculos sem refluxo',
                          isDark: isDark,
                        ),
                        const SizedBox(height: 12),
                        _buildDetailCard(
                          icon: Icons.water_drop_rounded,
                          iconColor: Colors.blueAccent,
                          title: 'Hidratação Intra-Treino',
                          description:
                              'Ingira cerca de 400ml a 500ml de água 1 hora antes e tome pequenos goles a cada descanso. Um músculo desidratado em apenas 2% perde até 15% de força explosiva.',
                          highlight: 'Músculos hidratados têm menor risco de cãibra e lesão',
                          isDark: isDark,
                        ),
                        const SizedBox(height: 12),
                        _buildDetailCard(
                          icon: Icons.nightlight_round,
                          iconColor: Colors.indigoAccent,
                          title: 'Sono Anabólico & Recuperação',
                          description:
                              'O treino é o estímulo, mas o crescimento muscular ocorre no descanso. Garanta de 7 a 8 horas de sono de qualidade para liberação ideal de GH e reparo das microlesões.',
                          highlight: 'Quem não dorme bem perde até 30% dos ganhos de massa magra',
                          isDark: isDark,
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 5. Botão de Ação Inferior (Padrão Ouro Squircle de Largura Total)
              SquircleButton(
                label: 'Entendi, vamos treinar!',
                icon: Icons.fitness_center_rounded,
                isPrimary: true,
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Pílula de seleção de aba estilo Hevy / iOS
  Widget _buildTabPill({
    required int index,
    required String label,
    required String sublabel,
    required bool isDark,
  }) {
    final isSelected = _selectedTab == index;
    return InkWell(
      onTap: () => setState(() => _selectedTab = index),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? Colors.white : MetaColors.emerald)
              : MetaColors.highlight(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? (isDark ? Colors.white : MetaColors.emerald)
                : MetaColors.cardBorder(context),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected
                ? (isDark ? Colors.black : Colors.white)
                : MetaColors.subtext(context),
          ),
        ),
      ),
    );
  }

  /// Card de passo com micro-badge numérico no padrão Hevy/Strong
  Widget _buildStepCard({
    required String stepNumber,
    required Color badgeColor,
    required String title,
    required String description,
    required IconData icon,
    required Color iconColor,
    required String tip,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MetaColors.card(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: MetaColors.cardBorder(context),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Badge de número do passo
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: badgeColor.withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    stepNumber,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: badgeColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Ícone da ação
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 8),

              // Título do passo
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: MetaColors.text(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: MetaColors.subtext(context),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: MetaColors.highlight(context),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              tip,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Card de detalhes científicos e de boas práticas
  Widget _buildDetailCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required String highlight,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MetaColors.card(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: MetaColors.cardBorder(context),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: iconColor.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Center(
              child: Icon(icon, color: iconColor, size: 22),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: MetaColors.text(context),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: MetaColors.subtext(context),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline_rounded,
                      size: 13,
                      color: iconColor,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        highlight,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: iconColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
