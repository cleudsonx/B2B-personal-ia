import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import '../../core/widgets/meta_components.dart';

/// Meta Science Hub & Calculadoras SEO (One UI 7 Glassmorphism)
/// Roteamento: `/science`, `/science/1rm`, `/science/volume`, `/ai`
class AiNewsScreen extends StatefulWidget {
  final String? initialTab;

  const AiNewsScreen({
    super.key,
    this.initialTab,
  });

  @override
  State<AiNewsScreen> createState() => _AiNewsScreenState();
}

class _AiNewsScreenState extends State<AiNewsScreen> with SingleTickerProviderStateMixin {
  // Cores de autoridade da Shaipados Labs & One UI 7
  static const _emerald = MetaColors.emerald;
  static const _cyan = Color(0xFF06B6D4);
  static const _amber = Color(0xFFF59E0B);
  static const _rose = Color(0xFFF43F5E);

  late TabController _tabController;

  // Estado da Calculadora de 1RM
  double _oneRmWeight = 80.0;
  int _oneRmReps = 8;
  String _selectedExercise = 'Supino Reto Barra';

  // Estado do Auditório de Volume Semanal
  int _selectedMuscleIndex = 0;
  double _weeklySets = 14.0;

  // Estado do Feed de IA (Shaipados Labs)
  bool _isLoadingNews = true;
  String? _newsError;
  bool _isStale = false;
  DateTime? _updatedAt;
  List<Map<String, dynamic>> _newsItems = [];
  List<Map<String, dynamic>> _newsSources = [];

  static const List<String> _exercisePresets = [
    'Supino Reto Barra',
    'Agachamento Livre',
    'Levantamento Terra',
    'Desenvolvimento Halteres',
    'Leg Press 45°',
    'Puxada Alta Costas',
  ];

  static const List<_MuscleVolumeGuide> _volumeGuides = [
    _MuscleVolumeGuide(
      name: 'Peitoral',
      icon: Icons.fitness_center_rounded,
      mev: 8,
      mavMin: 12,
      mavMax: 20,
      mrv: 22,
      focusTip: 'Priorize adução horizontal no plano escapular. 12 a 16 séries semanais são o ponto ideal para a grande maioria dos praticantes intermediários.',
      bestExercise: 'Supino Inclinado c/ Halteres + Crucifixo no Crossover',
    ),
    _MuscleVolumeGuide(
      name: 'Costas / Dorsais',
      icon: Icons.shield_rounded,
      mev: 10,
      mavMin: 14,
      mavMax: 22,
      mrv: 25,
      focusTip: 'Grupamento complexo de alta capacidade de trabalho. Combine puxadas verticais para largura com remadas horizontais para densidade escapular.',
      bestExercise: 'Puxada Aberta Pronada + Remada Curvada com Barra',
    ),
    _MuscleVolumeGuide(
      name: 'Quadríceps',
      icon: Icons.directions_run_rounded,
      mev: 8,
      mavMin: 12,
      mavMax: 18,
      mrv: 20,
      focusTip: 'Músculo denso com alto dano excêntrico. Séries de agachamento profundo e leg press exigem maior intervalo de recuperação entre sessões.',
      bestExercise: 'Agachamento Barra Alta + Cadeira Extensora Unilateral',
    ),
    _MuscleVolumeGuide(
      name: 'Posterior & Glúteos',
      icon: Icons.accessibility_new_rounded,
      mev: 6,
      mavMin: 10,
      mavMax: 16,
      mrv: 18,
      focusTip: 'Trabalhe tanto a extensão de quadril (Stiff/RDL) quanto a flexão de joelho (Mesa Flexora) para recrutar todas as cabeças dos isquiotibiais.',
      bestExercise: 'Stiff c/ Halteres + Elevação Pélvica com Barra',
    ),
    _MuscleVolumeGuide(
      name: 'Deltoides (Lateral / Post.)',
      icon: Icons.sports_gymnastics_rounded,
      mev: 8,
      mavMin: 16,
      mavMax: 24,
      mrv: 26,
      focusTip: 'O feixe lateral e posterior recupera rápido e responde excepcionalmente bem a volumes mais altos (16-22 séries) em faixas de 10-18 reps.',
      bestExercise: 'Elevação Lateral na Polia + Crucifixo Inverso',
    ),
    _MuscleVolumeGuide(
      name: 'Braços (Bíceps / Tríceps)',
      icon: Icons.bolt_rounded,
      mev: 6,
      mavMin: 10,
      mavMax: 16,
      mrv: 18,
      focusTip: 'Lembre-se de contabilizar o volume indireto de puxadas e supinos. 10 a 14 séries diretas semanais bastam para hipertrofia máxima.',
      bestExercise: 'Tríceps Testa na Polia + Rosca Scott Barra W',
    ),
    _MuscleVolumeGuide(
      name: 'Panturrilhas & Abdômen',
      icon: Icons.view_agenda_rounded,
      mev: 6,
      mavMin: 12,
      mavMax: 20,
      mrv: 24,
      focusTip: 'Grupamentos posturais resistentes à fadiga. Utilize pausas de 2s no pico da contração e no estiramento para anular o reflexo elástico.',
      bestExercise: 'Gêmeos Sentado + Elevação de Pernas na Barra Fixa',
    ),
  ];

  static const List<_ScienceArticle> _scienceArticles = [
    _ScienceArticle(
      title: 'Substituição Biomecânica de Exercícios com Mesmo Vetor Muscular',
      category: 'Biomecânica Clínica',
      readTime: '4 min de leitura',
      author: 'Equipe de Ciências Shaipados Labs',
      summary:
          'Como manter a tensão mecânica sobre o grupamento alvo sem sobrecarregar cápsulas articulares inflamadas ou quando o aparelho da academia estiver ocupado.',
      keyTakeaways: [
        'Ajuste o ângulo cotovelo-tronco de 75° para 50° para poupar o manguito rotador no supino.',
        'Substitua o agachamento com barra pelas costas por variações unilaterais (Búlgaro) para zerar o cisalhamento lombar mantendo 100% da carga sobre o quadríceps.',
        'No horário de pico, polias oferecem vetores de resistência contínua idênticos a máquinas de placas.',
      ],
    ),
    _ScienceArticle(
      title: 'Periodização Ondulatória Diária (DUP) vs. Linear para Hipertrofia',
      category: 'Fisiologia do Treinamento',
      readTime: '6 min de leitura',
      author: 'Prof. Cleudson Cavalcante (CREF 012345-G/DF)',
      summary:
          'Alternar estímulos de força (85% 1RM), hipertrofia de ouro (75% 1RM) e densidade metabólica (65% 1RM) na mesma semana acelera o ganho de massa magra em até 37%.',
      keyTakeaways: [
        'A DUP evita a acomodação neuromuscular e reduz a monotonia psicológica do treino.',
        'Permite trabalhar hipertrofia miofibrilar (densidade) e sarcoplasmática (volume celular) em microciclos sincronizados.',
        'O recálculo diário de carga baseado no RPE impede o overtraining mesmo em semanas de alto estresse profissional.',
      ],
    ),
    _ScienceArticle(
      title: 'RPE e Repetições na Reserva (RIR): A Ciência da Proximidade da Falha',
      category: 'Metodologia Avançada',
      readTime: '5 min de leitura',
      author: 'Comitê Científico Mr. Coach',
      summary:
          'Evidências mostram que treinar com 1 a 2 repetições na reserva (RIR 1-2 / RPE 8-9) gera hipertrofia idêntica à falha concêntrica total com metade da fadiga residual.',
      keyTakeaways: [
        'A falha total em todas as séries de exercícios multiarticulares degrada a recuperação das sessões seguintes.',
        'RIR 1-2 maximiza o recrutamento de unidades motoras de alto limiar sem elevar excessivamente o cortisol.',
        'A telemetria do Mr. Coach registra o RPE declarado pelo aluno e recalcula o descanso ideal no relógio.',
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    final initialIndex = _resolveInitialTabIndex(widget.initialTab);
    _tabController = TabController(length: 3, vsync: this, initialIndex: initialIndex);
    _loadNews();
  }

  int _resolveInitialTabIndex(String? tab) {
    if (tab == null) return 0;
    final lower = tab.toLowerCase();
    if (lower.contains('volume')) return 1;
    if (lower.contains('artigo') || lower.contains('noticia') || lower.contains('news') || lower.contains('articles')) {
      return 2;
    }
    return 0; // '1rm' por padrão
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // --- CÁLCULOS CIENTÍFICOS DE 1RM ---
  // Epley (1985): 1RM = Carga * (1 + Reps / 30)
  double get _epley1RM => _oneRmReps <= 1 ? _oneRmWeight : _oneRmWeight * (1.0 + (_oneRmReps / 30.0));

  // Brzycki (1993): 1RM = Carga / (1.0278 - (0.0278 * Reps))
  double get _brzycki1RM {
    if (_oneRmReps <= 1) return _oneRmWeight;
    final divisor = 1.0278 - (0.0278 * _oneRmReps);
    return divisor > 0.05 ? _oneRmWeight / divisor : _epley1RM;
  }

  // Lombardi (1989): 1RM = Carga * (Reps ^ 0.10)
  double get _lombardi1RM => _oneRmReps <= 1 ? _oneRmWeight : _oneRmWeight * math.pow(_oneRmReps, 0.10);

  // Média Ponderada Científica
  double get _average1RM => (_epley1RM + _brzycki1RM + _lombardi1RM) / 3.0;

  Future<void> _loadNews() async {
    setState(() {
      _isLoadingNews = true;
      _newsError = null;
    });
    try {
      final response = await http
          .get(Uri.parse('${AppConfig.apiBaseUrl}/public/ai-news'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        throw const FormatException('O feed oficial de IA está temporariamente offline.');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Resposta inválida do feed.');
      }
      final rawItems = decoded['items'];
      final rawSources = decoded['sources'];
      final items = rawItems is List
          ? rawItems.whereType<Map>().map(Map<String, dynamic>.from).toList()
          : <Map<String, dynamic>>[];
      final sources = rawSources is List
          ? rawSources.whereType<Map>().map(Map<String, dynamic>.from).toList()
          : <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() {
        _newsItems = items;
        _newsSources = sources;
        _isStale = decoded['stale'] == true;
        _updatedAt = DateTime.tryParse(decoded['updated_at']?.toString() ?? '')?.toLocal();
        _isLoadingNews = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _newsError = 'Feed online indisponível. Apresentando artigos técnicos indexados da Shaipados Labs.';
        _isLoadingNews = false;
      });
    }
  }

  Future<void> _openExternalUrl(String? url) async {
    if (url == null) return;
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = MetaColors.isDark(context);
    final bgColor = isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildGlassNavbar(isDark),
            _buildTabBar(isDark),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _build1RmTab(isDark),
                  _buildVolumeTab(isDark),
                  _buildArticlesAndNewsTab(isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassNavbar(bool isDark) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width > 1140;
    final isCompact = width < 480;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0E1524) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Row(
            children: [
              InkWell(
                onTap: () => Navigator.pushNamed(context, '/b2b'),
                borderRadius: BorderRadius.circular(10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_emerald, _cyan],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: _emerald.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.science_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'META SCIENCE HUB',
                              style: TextStyle(
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                            if (!isCompact) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _emerald.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'SEO OPEN',
                                  style: TextStyle(
                                    color: _emerald,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (!isCompact)
                          Text(
                            'Shaipados Labs • Fisiologia & Biomecânica Aplicada',
                            style: TextStyle(
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              fontSize: 10.5,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (isDesktop) ...[
                TextButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/coaches'),
                  icon: const Icon(Icons.search_rounded, size: 16),
                  label: const Text('Encontrar Personal'),
                  style: TextButton.styleFrom(
                    foregroundColor: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/b2b'),
                  icon: const Icon(Icons.fitness_center_rounded, size: 16),
                  label: const Text('Mr. Coach B2B'),
                  style: TextButton.styleFrom(
                    foregroundColor: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              ElevatedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/professor/cadastro'),
                icon: const Icon(Icons.flash_on_rounded, size: 16),
                label: const Text('Criar Conta Grátis'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _emerald,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar(bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF0B101D) : const Color(0xFFF1F5F9),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            indicatorColor: _emerald,
            indicatorWeight: 3,
            labelColor: _emerald,
            unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            tabs: const [
              Tab(
                icon: Icon(Icons.calculate_rounded, size: 18),
                text: 'Calculadora de 1RM & Zonas',
              ),
              Tab(
                icon: Icon(Icons.bar_chart_rounded, size: 18),
                text: 'Volume Semanal (MEV/MAV/MRV)',
              ),
              Tab(
                icon: Icon(Icons.auto_stories_rounded, size: 18),
                text: 'Artigos & Notícias de IA',
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // ABA 1: CALCULADORA DE 1RM & ZONAS DE HIPERTROFIA
  // ===========================================================================
  Widget _build1RmTab(bool isDark) {
    final avg = _average1RM;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header do Módulo
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _emerald.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _emerald.withValues(alpha: 0.3)),
                    ),
                    child: const Text(
                      'FERRAMENTA PÚBLICA • CIENTIFICAMENTE VALIDADA',
                      style: TextStyle(
                        color: _emerald,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    'Epley • Brzycki • Lombardi',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Calculadora Aberta de 1RM & Zonas de Hipertrofia',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Descubra sua força máxima teórica (1RM) sem o risco de lesões decorrentes de testes exaustivos. O algoritmo interpola três equações cinéticas para estimar a carga ótima de trabalho.',
                style: TextStyle(
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  fontSize: 13.5,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 24),

              // Bloco Interativo: Sliders e Big Number
              LayoutBuilder(
                builder: (context, constraints) {
                  final isDesktop = constraints.maxWidth > 768;

                  final inputsWidget = _build1RmInputsCard(isDark);
                  final resultsWidget = _build1RmDisplayCard(isDark, avg);

                  if (isDesktop) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 5, child: inputsWidget),
                        const SizedBox(width: 20),
                        Expanded(flex: 6, child: resultsWidget),
                      ],
                    );
                  } else {
                    return Column(
                      children: [
                        inputsWidget,
                        const SizedBox(height: 16),
                        resultsWidget,
                      ],
                    );
                  }
                },
              ),

              const SizedBox(height: 24),

              // Tabela Completa de Percentuais e Zonas de Intensidade
              _buildIntensityZonesTable(isDark, avg),

              const SizedBox(height: 24),

              // Callout de Conversão B2B / B2C
              _buildConversionBridges(
                isDark: isDark,
                title: 'Prescreva e Recalcule Cargas com Telemetria em Tempo Real',
                subtitle:
                    'No Mr. Coach AI, o 1RM dos seus alunos é recalculado automaticamente a cada série concluída no aplicativo móvel. Elimine suposições na periodização ondulatória.',
                primaryCtaText: 'Encontrar Treinador no Diretório',
                primaryCtaRoute: '/coaches',
                secondaryCtaText: 'Sou Personal e Quero Essa IA',
                secondaryCtaRoute: '/professor/cadastro',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _build1RmInputsCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '1. ESCOLHA O EXERCÍCIO DE REFERÊNCIA',
            style: TextStyle(
              color: _emerald,
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _exercisePresets.map((ex) {
              final isSelected = _selectedExercise == ex;
              return ChoiceChip(
                label: Text(ex),
                selected: isSelected,
                onSelected: (_) => setState(() => _selectedExercise = ex),
                selectedColor: _emerald.withValues(alpha: 0.2),
                backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                labelStyle: TextStyle(
                  color: isSelected ? _emerald : (isDark ? Colors.white70 : const Color(0xFF475569)),
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                ),
                side: BorderSide(
                  color: isSelected ? _emerald : Colors.transparent,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Slider Carga Levantada
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '2. CARGA LEVANTADA (KG)',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_oneRmWeight.toStringAsFixed(1)} kg',
                style: const TextStyle(
                  color: _emerald,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          Slider(
            value: _oneRmWeight,
            min: 5.0,
            max: 260.0,
            divisions: 255,
            activeColor: _emerald,
            inactiveColor: isDark ? Colors.white12 : const Color(0xFFCBD5E1),
            onChanged: (val) => setState(() => _oneRmWeight = val),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildStepButton('-5kg', () => setState(() => _oneRmWeight = math.max(5.0, _oneRmWeight - 5.0))),
              const SizedBox(width: 6),
              _buildStepButton('+5kg', () => setState(() => _oneRmWeight = math.min(260.0, _oneRmWeight + 5.0))),
              const SizedBox(width: 6),
              _buildStepButton('+10kg', () => setState(() => _oneRmWeight = math.min(260.0, _oneRmWeight + 10.0))),
            ],
          ),

          const SizedBox(height: 20),

          // Slider Repetições Realizadas
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '3. REPETIÇÕES EXECUTADAS',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$_oneRmReps reps',
                style: const TextStyle(
                  color: _cyan,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          Slider(
            value: _oneRmReps.toDouble(),
            min: 1.0,
            max: 15.0,
            divisions: 14,
            activeColor: _cyan,
            inactiveColor: isDark ? Colors.white12 : const Color(0xFFCBD5E1),
            onChanged: (val) => setState(() => _oneRmReps = val.round()),
          ),
          Wrap(
            spacing: 6,
            children: [1, 3, 5, 8, 10, 12, 15].map((r) {
              final isSel = _oneRmReps == r;
              return InkWell(
                onTap: () => setState(() => _oneRmReps = r),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSel ? _cyan : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$r reps',
                    style: TextStyle(
                      color: isSel ? Colors.black : (isDark ? Colors.white70 : const Color(0xFF475569)),
                      fontSize: 10.5,
                      fontWeight: isSel ? FontWeight.w900 : FontWeight.w600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStepButton(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _build1RmDisplayCard(bool isDark, double avg) {
    final epley = _epley1RM;
    final brzycki = _brzycki1RM;
    final lombardi = _lombardi1RM;

    // Carga recomendada para a Faixa de Ouro da Hipertrofia (75-80%)
    final hypertrophyCarga = avg * 0.775;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _emerald.withValues(alpha: 0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _emerald.withValues(alpha: isDark ? 0.12 : 0.06),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _emerald.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.bolt_rounded, color: _emerald, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '1RM TEÓRICO ESTIMADO (MÉDIA)',
                      style: TextStyle(
                        color: _emerald,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      _selectedExercise,
                      style: TextStyle(
                        color: isDark ? Colors.white70 : const Color(0xFF475569),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Big Number
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            runSpacing: 10,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    avg.toStringAsFixed(1),
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.5,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'kg',
                    style: TextStyle(
                      color: _emerald,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _emerald.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _emerald.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'ZONA DE OURO (8-10 REPS)',
                      style: TextStyle(
                        color: _emerald,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '${hypertrophyCarga.toStringAsFixed(1)} kg',
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),

          // Decomposição pelas 3 Fórmulas
          const Text(
            'COMPARAÇÃO POR EQUAÇÕES CINÉTICAS:',
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildFormulaBadge('Epley (1985)', '${epley.toStringAsFixed(1)} kg'),
              _buildFormulaBadge('Brzycki (1993)', '${brzycki.toStringAsFixed(1)} kg'),
              _buildFormulaBadge('Lombardi (1989)', '${lombardi.toStringAsFixed(1)} kg'),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 16, color: _cyan),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Para repetições abaixo de 10 reps, as equações apresentam desvio inferior a 3%, oferecendo alta precisão científica.',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8), height: 1.35),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormulaBadge(String name, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
      ],
    );
  }

  Widget _buildIntensityZonesTable(bool isDark, double avg) {
    final zones = [
      _IntensityZone(percentage: 100, label: '1RM (Força Pura)', reps: '1 rep', color: _rose, purpose: 'Capacidade Neuromuscular Absoluta'),
      _IntensityZone(percentage: 95, label: 'Força Máxima', reps: '2 reps', color: _rose, purpose: 'Tensão Intensa / Alta Sobrecarga Neural'),
      _IntensityZone(percentage: 90, label: 'Força Neural', reps: '3-4 reps', color: _amber, purpose: 'Adaptação de Força c/ Moderada Fadiga'),
      _IntensityZone(percentage: 85, label: 'Hipertrofia Miofibrilar', reps: '5-6 reps', color: _amber, purpose: 'Densidade & Crescimento de Fibras Rápidas'),
      _IntensityZone(percentage: 80, label: 'Faixa de Ouro Hipertrofia ⭐', reps: '7-8 reps', color: _emerald, purpose: 'Pico de Hipertrofia Muscular Segundo a Literatura'),
      _IntensityZone(percentage: 75, label: 'Hipertrofia Metabólica', reps: '9-10 reps', color: _emerald, purpose: 'Acúmulo Metabólico & Estresse Mecânico Ótimo'),
      _IntensityZone(percentage: 70, label: 'Volume Sarcoplasmático', reps: '11-12 reps', color: _cyan, purpose: 'Pump Intenso & Capilarização Muscular'),
      _IntensityZone(percentage: 65, label: 'Resistência de Força (RML)', reps: '13-15 reps', color: _cyan, purpose: 'Resistência Muscular Localizada & Tensão Contínua'),
      _IntensityZone(percentage: 50, label: 'Aquecimento & Potência', reps: '15+ reps', color: const Color(0xFF94A3B8), purpose: 'Ativação Miofascial / Aquecimento Específico'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.table_chart_rounded, color: _emerald, size: 20),
              const SizedBox(width: 8),
              Text(
                'Tabela de Zonas de Intensidade & Repetições Alvo',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...zones.map((zone) {
            final targetWeight = avg * (zone.percentage / 100.0);
            final isHighlight = zone.percentage == 80;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isHighlight
                    ? _emerald.withValues(alpha: 0.12)
                    : (isDark ? const Color(0xFF1E293B).withValues(alpha: 0.5) : const Color(0xFFF8FAFC)),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isHighlight ? _emerald : Colors.transparent,
                  width: isHighlight ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: zone.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${zone.percentage}%',
                      style: TextStyle(
                        color: zone.color,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          zone.label,
                          style: TextStyle(
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                            fontWeight: isHighlight ? FontWeight.w900 : FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          '${zone.reps} • ${zone.purpose}',
                          style: TextStyle(
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${targetWeight.toStringAsFixed(1)} kg',
                    style: TextStyle(
                      color: isHighlight ? _emerald : (isDark ? Colors.white : const Color(0xFF0F172A)),
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ===========================================================================
  // ABA 2: AUDITÓRIO DE VOLUME SEMANAL MEV / MAV / MRV
  // ===========================================================================
  Widget _buildVolumeTab(bool isDark) {
    final guide = _volumeGuides[_selectedMuscleIndex];
    final currentSets = _weeklySets.round();

    // Diagnóstico de Volume
    final String statusLabel;
    final Color statusColor;
    final String statusDescription;

    if (currentSets < guide.mev) {
      statusLabel = 'Volume Sub-Efetivo (< MEV)';
      statusColor = _amber;
      statusDescription = 'Abaixo do Volume Mínimo Efetivo. O estímulo não é suficiente para maximizar o ganho de massa magra neste grupamento.';
    } else if (currentSets >= guide.mev && currentSets < guide.mavMin) {
      statusLabel = 'Volume de Manutenção / Inicial (MEV)';
      statusColor = const Color(0xFF38BDF8);
      statusDescription = 'Gera progresso gradual com baixíssima fadiga acumulada. Excelente para fases de deload ativo ou consolidação.';
    } else if (currentSets >= guide.mavMin && currentSets <= guide.mavMax) {
      statusLabel = 'Faixa de Ouro Adaptativa (MAV) ⭐';
      statusColor = _emerald;
      statusDescription = 'Volume Adaptativo Máximo! Zona de máxima síntese proteica miofibrilar sem estresse articular excessivo.';
    } else {
      statusLabel = 'Zona de Alto Risco (> MRV)';
      statusColor = _rose;
      statusDescription = 'Atenção: Volume Máximo Recuperável ultrapassado! Risco de sobretreinamento, estagnação e tendinopatias por estresse mecânico crônico.';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _cyan.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _cyan.withValues(alpha: 0.3)),
                    ),
                    child: const Text(
                      'PERIODIZAÇÃO CIENTÍFICA • SCHOENFELD & ISRAETEL',
                      style: TextStyle(
                        color: _cyan,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Auditório de Volume Semanal (MEV / MAV / MRV)',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Avalie se a contagem de séries válidas semanais por grupamento muscular está na janela ótima de hipertrofia ou se você está em risco de sobretreinamento articular.',
                style: TextStyle(
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  fontSize: 13.5,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 24),

              // Seletor de Músculo
              Text(
                'SELECIONE O GRUPAMENTO MUSCULAR:',
                style: TextStyle(
                  color: isDark ? Colors.white70 : const Color(0xFF475569),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(_volumeGuides.length, (idx) {
                    final item = _volumeGuides[idx];
                    final isSel = _selectedMuscleIndex == idx;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        onTap: () => setState(() => _selectedMuscleIndex = idx),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSel
                                ? _emerald.withValues(alpha: 0.2)
                                : (isDark ? const Color(0xFF131B2E) : Colors.white),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSel ? _emerald : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                              width: isSel ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                item.icon,
                                color: isSel ? _emerald : (isDark ? Colors.white60 : const Color(0xFF64748B)),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                item.name,
                                style: TextStyle(
                                  color: isSel ? _emerald : (isDark ? Colors.white : const Color(0xFF0F172A)),
                                  fontWeight: isSel ? FontWeight.w900 : FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 24),

              // Card do Simulador com Slider de Séries
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF131B2E) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'SÉRIES SEMANAIS ATUAIS (${guide.name}):',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : const Color(0xFF475569),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                        Text(
                          '$currentSets séries / semana',
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Slider(
                      value: _weeklySets,
                      min: 0.0,
                      max: 32.0,
                      divisions: 32,
                      activeColor: statusColor,
                      inactiveColor: isDark ? Colors.white12 : const Color(0xFFCBD5E1),
                      onChanged: (val) => setState(() => _weeklySets = val),
                    ),

                    // Barra Visual Comparativa (MEV -> MAV -> MRV)
                    const SizedBox(height: 14),
                    _buildVolumeRangeGauge(guide, currentSets, isDark),

                    const SizedBox(height: 18),
                    // Card de Diagnóstico Dinâmico
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: statusColor.withValues(alpha: 0.35)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.analytics_rounded, color: statusColor, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                statusLabel,
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            statusDescription,
                            style: TextStyle(
                              color: isDark ? Colors.white70 : const Color(0xFF334155),
                              fontSize: 12.5,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Icon(Icons.recommend_rounded, size: 14, color: _emerald),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Exercício de Máxima Eficiência: ${guide.bestExercise}',
                                  style: const TextStyle(
                                    color: _emerald,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
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
              ),

              const SizedBox(height: 24),

              // Guia Teórico dos 3 Pilares
              _buildVolumeTheoryCards(isDark),

              const SizedBox(height: 24),

              // Callout
              _buildConversionBridges(
                isDark: isDark,
                title: 'Controle o Volume Semanal dos seus Alunos sem Planilhas',
                subtitle:
                    'O painel do treinador no Mr. Coach audita o volume de séries diretas e indiretas automaticamente, alertando antes que seu aluno atinja o MRV e sinta dores articulares.',
                primaryCtaText: 'Ver Treinadores no Diretório',
                primaryCtaRoute: '/coaches',
                secondaryCtaText: 'Cadastrar Minha Consultoria',
                secondaryCtaRoute: '/professor/cadastro',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVolumeRangeGauge(_MuscleVolumeGuide guide, int current, bool isDark) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('0 séries', style: TextStyle(color: isDark ? Colors.white38 : const Color(0xFF94A3B8), fontSize: 10)),
            Text('MEV: ${guide.mev}s', style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 10, fontWeight: FontWeight.w700)),
            Text('MAV: ${guide.mavMin}-${guide.mavMax}s', style: const TextStyle(color: _emerald, fontSize: 10, fontWeight: FontWeight.w800)),
            Text('MRV: ${guide.mrv}s', style: const TextStyle(color: _rose, fontSize: 10, fontWeight: FontWeight.w700)),
            Text('32+ séries', style: TextStyle(color: isDark ? Colors.white38 : const Color(0xFF94A3B8), fontSize: 10)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Container(
            height: 10,
            width: double.infinity,
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
            child: Row(
              children: [
                Expanded(flex: guide.mev, child: Container(color: _amber.withValues(alpha: 0.6))),
                Expanded(flex: guide.mavMin - guide.mev, child: Container(color: const Color(0xFF38BDF8).withValues(alpha: 0.7))),
                Expanded(flex: guide.mavMax - guide.mavMin, child: Container(color: _emerald)),
                Expanded(flex: guide.mrv - guide.mavMax, child: Container(color: _rose.withValues(alpha: 0.5))),
                Expanded(flex: math.max(1, 32 - guide.mrv), child: Container(color: _rose)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVolumeTheoryCards(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 640;
        final mev = _buildTheoryPillar(
          isDark: isDark,
          tag: 'MEV',
          title: 'Mínimo Efetivo',
          desc: 'Menor dose de treino capaz de disparar síntese proteica e evitar perda muscular.',
          color: const Color(0xFF38BDF8),
        );
        final mav = _buildTheoryPillar(
          isDark: isDark,
          tag: 'MAV',
          title: 'Adaptativo Máximo',
          desc: 'Faixa de ouro onde o estímulo mecânico gera o pico de hipertrofia com recuperação completa.',
          color: _emerald,
        );
        final mrv = _buildTheoryPillar(
          isDark: isDark,
          tag: 'MRV',
          title: 'Máximo Recuperável',
          desc: 'Teto biológico. Acima deste ponto, a fadiga sistêmica supera a capacidade de síntese.',
          color: _rose,
        );

        if (isDesktop) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: mev),
              const SizedBox(width: 12),
              Expanded(child: mav),
              const SizedBox(width: 12),
              Expanded(child: mrv),
            ],
          );
        } else {
          return Column(
            children: [
              mev,
              const SizedBox(height: 10),
              mav,
              const SizedBox(height: 10),
              mrv,
            ],
          );
        }
      },
    );
  }

  Widget _buildTheoryPillar({
    required bool isDark,
    required String tag,
    required String title,
    required String desc,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              tag,
              style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            desc,
            style: TextStyle(
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              fontSize: 11,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // ABA 3: ARTIGOS TÉCNICOS & FEED DE NOTÍCIAS DE IA
  // ===========================================================================
  Widget _buildArticlesAndNewsTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _emerald.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _emerald.withValues(alpha: 0.3)),
                    ),
                    child: const Text(
                      'CONHECIMENTO INDEXADO • SHAIPADOS LABS',
                      style: TextStyle(
                        color: _emerald,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Guias Técnicos de Biomecânica & Notícias de IA',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Literatura médica e fisiológica descomplicada para personal trainers e praticantes sérios de musculação.',
                style: TextStyle(
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  fontSize: 13.5,
                ),
              ),
              const SizedBox(height: 24),

              // Artigos Principais
              ..._scienceArticles.map((art) => _buildArticleCard(art, isDark)),

              const SizedBox(height: 28),

              // Seção do Feed de Notícias de IA da API
              Row(
                children: [
                  const Icon(Icons.rss_feed_rounded, color: _emerald, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Feed Oficial de Inteligência Artificial',
                          style: TextStyle(
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (_updatedAt != null)
                          Text(
                            _isStale
                                ? 'Última sincronização: ${_updatedAt!.day}/${_updatedAt!.month} às ${_updatedAt!.hour.toString().padLeft(2, '0')}:${_updatedAt!.minute.toString().padLeft(2, '0')}'
                                : 'Atualizado em ${_updatedAt!.day}/${_updatedAt!.month} às ${_updatedAt!.hour.toString().padLeft(2, '0')}:${_updatedAt!.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Atualizar Feed',
                    onPressed: _isLoadingNews ? null : _loadNews,
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    color: _emerald,
                  ),
                ],
              ),
              if (_newsSources.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _newsSources.map((s) {
                    final name = s['name']?.toString() ?? '';
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        name,
                        style: TextStyle(
                          color: isDark ? Colors.white70 : const Color(0xFF475569),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 12),

              if (_isLoadingNews)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(color: _emerald),
                  ),
                )
              else if (_newsError != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF131B2E) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: _cyan, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _newsError!,
                          style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF475569), fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ..._newsItems.map((item) => _buildNewsFeedItem(item, isDark)),

              const SizedBox(height: 28),

              _buildConversionBridges(
                isDark: isDark,
                title: 'Transforme Ciência em Faturamento na sua Consultoria',
                subtitle:
                    'Alunos que entendem a ciência do treino retêm por mais de 12 meses. O Mr. Coach AI une rigor técnico à maior comodidade operacional do mercado.',
                primaryCtaText: 'Ver Vitrines de Treinadores',
                primaryCtaRoute: '/coaches',
                secondaryCtaText: 'Testar Plataforma Grátis',
                secondaryCtaRoute: '/professor/cadastro',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArticleCard(_ScienceArticle article, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _emerald.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  article.category,
                  style: const TextStyle(color: _emerald, fontSize: 10, fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '• ${article.readTime}',
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
              ),
              const Spacer(),
              Text(
                article.author,
                style: TextStyle(
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            article.title,
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              fontSize: 17,
              fontWeight: FontWeight.w900,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            article.summary,
            style: TextStyle(
              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'PONTOS-CHAVE DE APLICAÇÃO PRÁTICA:',
            style: TextStyle(
              color: _cyan,
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          ...article.keyTakeaways.map(
            (point) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(color: _emerald, fontWeight: FontWeight.w900)),
                  Expanded(
                    child: Text(
                      point,
                      style: TextStyle(
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewsFeedItem(Map<String, dynamic> item, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _cyan.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.language_rounded, color: _cyan, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      item['source']?.toString() ?? 'Fonte Oficial',
                      style: const TextStyle(color: _emerald, fontSize: 10.5, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '• ${item['published_at'] != null ? item['published_at'].toString().split('T').first : 'Recente'}',
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10.5),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item['title']?.toString() ?? 'Atualização de IA',
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (item['url'] != null)
            IconButton(
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              color: _emerald,
              onPressed: () => _openExternalUrl(item['url']?.toString()),
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // CALLOUT E PONTES DE CONVERSÃO (B2B E B2C)
  // ===========================================================================
  Widget _buildConversionBridges({
    required bool isDark,
    required String title,
    required String subtitle,
    required String primaryCtaText,
    required String primaryCtaRoute,
    required String secondaryCtaText,
    required String secondaryCtaRoute,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF13221B), const Color(0xFF0D1B2A)]
              : [const Color(0xFFECFDF5), const Color(0xFFEFF6FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _emerald.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _emerald.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.stars_rounded, color: _emerald, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CONEXÃO DIRETA COM O ECOSSISTEMA MR. COACH',
                      style: TextStyle(
                        color: _emerald,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      title,
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: TextStyle(
              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
              fontSize: 12.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              ElevatedButton.icon(
                onPressed: () => Navigator.pushNamed(context, primaryCtaRoute),
                icon: const Icon(Icons.search_rounded, size: 16),
                label: Text(primaryCtaText),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _emerald,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => Navigator.pushNamed(context, secondaryCtaRoute),
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: Text(secondaryCtaText),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _emerald,
                  side: const BorderSide(color: _emerald),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Helpers de dados
class _MuscleVolumeGuide {
  final String name;
  final IconData icon;
  final int mev;
  final int mavMin;
  final int mavMax;
  final int mrv;
  final String focusTip;
  final String bestExercise;

  const _MuscleVolumeGuide({
    required this.name,
    required this.icon,
    required this.mev,
    required this.mavMin,
    required this.mavMax,
    required this.mrv,
    required this.focusTip,
    required this.bestExercise,
  });
}

class _IntensityZone {
  final int percentage;
  final String label;
  final String reps;
  final Color color;
  final String purpose;

  const _IntensityZone({
    required this.percentage,
    required this.label,
    required this.reps,
    required this.color,
    required this.purpose,
  });
}

class _ScienceArticle {
  final String title;
  final String category;
  final String readTime;
  final String author;
  final String summary;
  final List<String> keyTakeaways;

  const _ScienceArticle({
    required this.title,
    required this.category,
    required this.readTime,
    required this.author,
    required this.summary,
    required this.keyTakeaways,
  });
}
