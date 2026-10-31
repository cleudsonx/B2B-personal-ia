import 'package:flutter/material.dart';

class BiomechanicalScenario {
  final String complaint;
  final String jointTarget;
  final String forceVectorDiagnosis;
  final String instantCorrection;
  final String alternativeExercise;
  final String safetyGain;
  final bool isBusyMachine;

  const BiomechanicalScenario({
    required this.complaint,
    required this.jointTarget,
    required this.forceVectorDiagnosis,
    required this.instantCorrection,
    required this.alternativeExercise,
    required this.safetyGain,
    this.isBusyMachine = false,
  });
}

class TestDriveCase {
  final String exerciseName;
  final String category;
  final IconData icon;
  final List<BiomechanicalScenario> scenarios;

  const TestDriveCase({
    required this.exerciseName,
    required this.category,
    required this.icon,
    required this.scenarios,
  });
}

class BiomechanicalTestDriveWidget extends StatefulWidget {
  final bool wide;

  const BiomechanicalTestDriveWidget({super.key, required this.wide});

  @override
  State<BiomechanicalTestDriveWidget> createState() => _BiomechanicalTestDriveWidgetState();
}

class _BiomechanicalTestDriveWidgetState extends State<BiomechanicalTestDriveWidget> {
  int _selectedExerciseIndex = 0;
  int _selectedScenarioIndex = 0;

  static const _green = Color(0xFF10B981);
  static const _muted = Color(0xFF94A3B8);

  static const List<TestDriveCase> _cases = [
    TestDriveCase(
      exerciseName: 'Agachamento Livre',
      category: 'Membros Inferiores',
      icon: Icons.accessibility_new_rounded,
      scenarios: [
        BiomechanicalScenario(
          complaint: 'Dor e pinçamento na lombar baixa (L5-S1) no fundo',
          jointTarget: 'Coluna Lombar / Pelve',
          forceVectorDiagnosis:
              'Retroversão pélvica precoce (butt wink) com aumento do braço de momento sobre os eretores e cisalhamento discal em flexão.',
          instantCorrection:
              'Elevação do calcanhar com calço de 1,5 cm, abertura da base para 1,2x a largura dos ombros e manutenção do gradil costal conectado à pelve.',
          alternativeExercise: 'Agachamento Búlgaro no Banco ou Agachamento Goblet com tronco a 70°',
          safetyGain: '-68% de força de cisalhamento na L5-S1 com 95% de estímulo em quadríceps e glúteos.',
        ),
        BiomechanicalScenario(
          complaint: 'Aparelho / Gaiola ocupada no horário de pico',
          jointTarget: 'Substituição por Sobrecarga de Espaço',
          forceVectorDiagnosis:
              'Horário de pico na academia. Necessidade de replicar o mesmo perfil de torque de flexão/extensão de joelho e quadril com peso livre.',
          instantCorrection:
              'Migrar para halteres com passada ou agachamento búlgaro mantendo o tempo sob tensão (TUT 3-1-1).',
          alternativeExercise: 'Passada com Halteres com pausa isométrica de 1s na base',
          safetyGain: 'Zero espera na academia, mantendo taxa de esforço percebido (RPE 8.5) idêntica à ficha.',
          isBusyMachine: true,
        ),
        BiomechanicalScenario(
          complaint: 'Valgo dinâmico e pontada patelar no joelho',
          jointTarget: 'Articulação Patelofemoral',
          forceVectorDiagnosis:
              'Colapso medial dos joelhos por déficit do glúteo médio e rotação interna descontrolada da tíbia na subida concêntrica.',
          instantCorrection:
              'Cue mental de "espalhar o chão" com os pés e rotação externa de fêmur pré-ativada.',
          alternativeExercise: 'Leg Press 45° unilateral com alinhamento mecânico controlado',
          safetyGain: 'Alívio imediato da compressão retro-patelar e ativação do tensor da fáscia lata.',
        ),
      ],
    ),
    TestDriveCase(
      exerciseName: 'Supino Reto com Barra',
      category: 'Peitoral & Membros Superiores',
      icon: Icons.fitness_center_rounded,
      scenarios: [
        BiomechanicalScenario(
          complaint: 'Ombro estalando e dor na cápsula anterior',
          jointTarget: 'Articulação Glenoumeral',
          forceVectorDiagnosis:
              'Abdução excessiva do úmero (>75° no plano coronal), comprimindo a cabeça longa do bíceps e manguito sob o acrômio.',
          instantCorrection:
              'Depressão e retração de escápulas, cotovelos fechados a 45°-55° do tronco e barra tocando a linha dos mamilos.',
          alternativeExercise: 'Supino Reto com Halteres em pegada semi-pronada / neutra',
          safetyGain: 'Descompressão total do espaço subacromial e maior pico de contração no peitoral maior.',
        ),
        BiomechanicalScenario(
          complaint: 'Banco de supino ocupado com fila de espera',
          jointTarget: 'Manutenção de Vetor Horizontal',
          forceVectorDiagnosis:
              'Banco reto indisponível. Necessidade de manter vetor horizontal de adução escapuloumeral para ativação esternocostal.',
          instantCorrection:
              'Ajustar as polias do cross na altura do peito ou deitar no colchonete com halteres (Floor Press).',
          alternativeExercise: 'Floor Press com Halteres ou Crossover Polia Média',
          safetyGain: 'Estímulo preservado em 100% com segurança extra contra hiperextensão de cotovelos.',
          isBusyMachine: true,
        ),
        BiomechanicalScenario(
          complaint: 'Tríceps falha muito antes de sentir o peito',
          jointTarget: 'Cotovelo / Peitoral',
          forceVectorDiagnosis:
              'Empunhadura excessivamente fechada e falta de arqueamento torácico estável gerando sobrecarga de extensores do cotovelo.',
          instantCorrection:
              'Ajustar pegada para 1,5x a largura biacromial e aplicar leg drive empurrando o chão com calcanhares.',
          alternativeExercise: 'Crucifixo Inclinado com Halteres ou Crossover polia média',
          safetyGain: '+42% de recrutamento nas fibras esternocostais do peitoral maior.',
        ),
      ],
    ),
    TestDriveCase(
      exerciseName: 'Puxada Alta',
      category: 'Dorsais & Escápulas',
      icon: Icons.vertical_align_bottom_rounded,
      scenarios: [
        BiomechanicalScenario(
          complaint: 'Sobrecarga nos antebraços sem sentir a grande dorsal',
          jointTarget: 'Complexo Escapulotorácico',
          forceVectorDiagnosis:
              'Falta de depressão escapular prévia ao movimento; puxada acionada por flexão de cotovelos em vez de tração escapular.',
          instantCorrection:
              'Puxar iniciando pelo rebaixamento das escápulas, usando pegada sem polegar (thumbless grip) e cue de "levar os cotovelos aos bolsos".',
          alternativeExercise: 'Remada Baixa Unilateral na polia com pegada neutra',
          safetyGain: 'Isolamento cirúrgico da grande dorsal sem esgotar os flexores do punho.',
        ),
        BiomechanicalScenario(
          complaint: 'Puxador articulado e polia alta ocupados',
          jointTarget: 'Vetor de Tração Vertical',
          forceVectorDiagnosis:
              'Equipamento principal de tração vertical bloqueado. É preciso simular a adução coronal do úmero sem aparelhos fixos.',
          instantCorrection:
              'Utilizar elástico superband ancorado no rack ou barra fixa com pegada supinada assistida.',
          alternativeExercise: 'Barra Fixa com elástico ou Remada Curvada com Barra',
          safetyGain: 'Adaptação sem atraso no treino com ativação superior do latíssimo do dorso.',
          isBusyMachine: true,
        ),
        BiomechanicalScenario(
          complaint: 'Desconforto cervical e impacto ao puxar atrás da nuca',
          jointTarget: 'Cintura Escapular & Cervical',
          forceVectorDiagnosis:
              'Rotação externa extrema associada à flexão cervical forçada, com alto estresse em cápsula articular e ligamentos.',
          instantCorrection:
              'Execução estritamente pela frente do corpo, barra descendo até o esterno alto com tronco inclinado a 15°.',
          alternativeExercise: 'Puxada Frente com Triângulo ou Pegada Neutra Fechada',
          safetyGain: 'Proteção articular completa da cintura escapular sem compressão nervosa.',
        ),
      ],
    ),
    TestDriveCase(
      exerciseName: 'Levantamento Terra',
      category: 'Cadeia Posterior',
      icon: Icons.sports_gymnastics_rounded,
      scenarios: [
        BiomechanicalScenario(
          complaint: 'Arredondamento lombar na saída do solo',
          jointTarget: 'Eretores da Espinha / Lombar',
          forceVectorDiagnosis:
              'Falta de tensão prévia nas dorsais antes da arrancada ("quebrar a barra") e distância excessiva da barra em relação às tíbias.',
          instantCorrection:
              'Travar as dorsais, colar a barra nas canelas e empurrar o piso com os calcanhares antes de puxar com o quadril.',
          alternativeExercise: 'Levantamento Terra com Trap Bar (barra hexagonal) ou RDL com Halteres',
          safetyGain: '-72% de momento flexor na coluna lombar com centro de gravidade alinhado.',
        ),
      ],
    ),
    TestDriveCase(
      exerciseName: 'Desenvolvimento c/ Halteres',
      category: 'Ombros & Deltoides',
      icon: Icons.pan_tool_alt_rounded,
      scenarios: [
        BiomechanicalScenario(
          complaint: 'Dor aguda ao descer abaixo de 90° no plano coronal',
          jointTarget: 'Manguito Rotador / Acrômio',
          forceVectorDiagnosis:
              'Movimento executado em abdução total (180° frontal), forçando o tendão do supraespinhal contra a abóbada óssea.',
          instantCorrection:
              'Posicionar os cotovelos 30° à frente no plano escapular com halteres angulados a 45°.',
          alternativeExercise: 'Desenvolvimento Arnold no banco 75° ou Elevação Lateral na polia',
          safetyGain: 'Trajetória fisiológica natural sem compressão subacromial.',
        ),
        BiomechanicalScenario(
          complaint: 'Banco regulável e pares de halteres ocupados',
          jointTarget: 'Vetor de Empurrar Vertical',
          forceVectorDiagnosis:
              'Área de halteres congestionada. Preservação da elevação escapular e flexão de deltoide anterior/médio.',
          instantCorrection:
              'Realizar o desenvolvimento em pé com barra leve ou usar a polia baixa com pegada pronada.',
          alternativeExercise: 'Desenvolvimento Militar em Pé com Barra ou na Polia',
          safetyGain: 'Treino concluído sem perder o aquecimento, com estímulo core ampliado.',
          isBusyMachine: true,
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final currentCase = _cases[_selectedExerciseIndex];
    final safeScenarioIndex = _selectedScenarioIndex.clamp(0, currentCase.scenarios.length - 1);
    final currentScenario = currentCase.scenarios[safeScenarioIndex];

    return Container(
      width: double.infinity,
      color: const Color(0xFF090D16),
      padding: EdgeInsets.symmetric(horizontal: 22, vertical: widget.wide ? 76 : 52),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1160),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _green.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome_rounded, color: _green, size: 14),
                    SizedBox(width: 6),
                    Text(
                      'TEST-DRIVE DE IA EM TEMPO REAL • 0 CADASTRO • RESPOSTA EM 3S',
                      style: TextStyle(
                        color: _green,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.9,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Experimente a inteligência biomecânica que protege seus alunos',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: widget.wide ? 34 : 25,
                  fontWeight: FontWeight.w900,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Selecione um exercício clássico e uma queixa comum (dor articular ou aparelho ocupado). Veja a adaptação instantânea calculada pela IA como se o aluno estivesse treinando agora.',
                style: TextStyle(
                  color: _muted,
                  fontSize: 15,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 32),
              // Step 1: Exercise Selection
              const Text(
                '1. Escolha o exercício:',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (var i = 0; i < _cases.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      _buildExerciseChip(i, _cases[i]),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 22),
              // Step 2: Complaint Selection
              const Text(
                '2. Situação na academia (Dor ou Aparelho Ocupado):',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var s = 0; s < currentCase.scenarios.length; s++)
                    _buildScenarioChip(s, currentCase.scenarios[s]),
                ],
              ),
              const SizedBox(height: 26),
              // AI Live Output Card
              _buildAiDiagnosticCard(currentCase, currentScenario),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExerciseChip(int index, TestDriveCase item) {
    final isSelected = _selectedExerciseIndex == index;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedExerciseIndex = index;
          _selectedScenarioIndex = 0;
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? _green : const Color(0xFF131B2E),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? _green : const Color(0xFF334155),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              item.icon,
              size: 16,
              color: isSelected ? Colors.white : _green,
            ),
            const SizedBox(width: 8),
            Text(
              item.exerciseName,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScenarioChip(int index, BiomechanicalScenario scenario) {
    final isSelected = _selectedScenarioIndex == index;
    final isBusy = scenario.isBusyMachine;
    final tagColor = isBusy ? const Color(0xFF38BDF8) : _green;

    return InkWell(
      onTap: () => setState(() => _selectedScenarioIndex = index),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isBusy ? const Color(0xFF0C2A38) : const Color(0x2610B981))
              : const Color(0xFF131B2E),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? tagColor : const Color(0xFF334155),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected
                  ? (isBusy ? Icons.hourglass_top_rounded : Icons.check_circle_rounded)
                  : Icons.radio_button_unchecked_rounded,
              color: isSelected ? tagColor : _muted,
              size: 15,
            ),
            const SizedBox(width: 8),
            Text(
              scenario.complaint,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiDiagnosticCard(TestDriveCase currentCase, BiomechanicalScenario scenario) {
    final isBusy = scenario.isBusyMachine;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF131B2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isBusy ? const Color(0xFF0369A1).withValues(alpha: 0.4) : const Color(0xFF334155),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 24, offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: isBusy ? const Color(0xFF0A2230) : const Color(0xFF1E293B),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: isBusy ? const Color(0xFF075985) : const Color(0xFF334155))),
            ),
            child: Row(
              children: [
                Icon(
                  isBusy ? Icons.swap_horizontal_circle_outlined : Icons.psychology_rounded,
                  color: isBusy ? const Color(0xFF38BDF8) : _green,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  isBusy ? 'TROCA RÁPIDA DE APARELHO OCUPADO (0 ESPERA)' : 'MOTOR BIOMECÂNICO CLÍNICO MR. COACH AI',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (isBusy ? const Color(0xFF38BDF8) : _green).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.circle, color: isBusy ? const Color(0xFF38BDF8) : _green, size: 8),
                      const SizedBox(width: 6),
                      Text(
                        'RESPOSTA EM <100MS',
                        style: TextStyle(
                          color: isBusy ? const Color(0xFF38BDF8) : _green,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Body Content
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isBusy ? 'DIAGNÓSTICO DE SUBSTITUIÇÃO' : 'DIAGNÓSTICO DO VETOR DE FORÇA',
                            style: const TextStyle(
                              color: _muted,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            scenario.forceVectorDiagnosis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              height: 1.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ALVO ANATÔMICO',
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 9.5, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            scenario.jointTarget,
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Divider(color: Color(0x1FFFFFFF)),
                ),
                // Instant correction
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.tune_rounded, color: _green, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'AJUSTE IMEDIATO RECOMENDADO AO ALUNO',
                            style: TextStyle(
                              color: _green,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            scenario.instantCorrection,
                            style: const TextStyle(color: Colors.white, fontSize: 13.5, height: 1.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Alternative Exercise
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.swap_horiz_rounded, color: Color(0xFF5DB8FF), size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'EXERCÍCIO SUBSTITUTO SELECIONADO',
                            style: TextStyle(
                              color: Color(0xFF5DB8FF),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            scenario.alternativeExercise,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Safety gain badge
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0x2610B981),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _green.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_user_rounded, color: _green, size: 17),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Benefício biomecânico: ${scenario.safetyGain}',
                          style: const TextStyle(
                            color: Color(0xFFD1FAE5),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // CTA Footer inside card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF090D16),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: const Text(
                          'Essa proteção acompanha seus alunos em cada série e avisa você no WhatsApp.',
                          style: TextStyle(color: Color(0xFF9AA9A1), fontSize: 12),
                        ),
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => Navigator.pushNamed(context, '/coaches'),
                            icon: const Icon(Icons.search_rounded, size: 14),
                            label: const Text('Encontrar Personal'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Color(0xFF334155)),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pushNamed(context, '/professor/cadastro'),
                            style: FilledButton.styleFrom(
                              backgroundColor: _green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Prescrever com essa IA', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    ],
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
