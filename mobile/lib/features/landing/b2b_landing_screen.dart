import 'package:flutter/material.dart';

import '../../core/utils/currency_pt_br_formatter.dart';
import '../../core/widgets/meta_components.dart';

class B2BLandingScreen extends StatelessWidget {
  const B2BLandingScreen({super.key});

  static const _ink = Color(0xFF111A17);
  static const _muted = Color(0xFF9AA9A1);
  static const _green = Color(0xFF25A875);
  static const _panel = Color(0xFF17211C);

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width > 760;
    return Scaffold(
      backgroundColor: const Color(0xFF0B100D),
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(context, wide)),
            SliverToBoxAdapter(child: _buildHero(context, wide)),
            SliverToBoxAdapter(child: _RoiCalculatorSection(wide: wide)),
            SliverToBoxAdapter(child: _BiomechanicalTestDriveSection(wide: wide)),
            SliverToBoxAdapter(child: _ConsultancyComparisonSection(wide: wide)),
            SliverToBoxAdapter(child: _buildAudience(context, wide)),
            SliverToBoxAdapter(child: _buildWorkflow(context, wide)),
            SliverToBoxAdapter(child: _buildFooter(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool wide) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 12),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1160),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/images/app_icon_black.png',
                  width: 42,
                  height: 42,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SHAIPADOS LABS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'MR. COACH  /  B2B',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              if (wide)
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/ai'),
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  child: const Text('Mr. Coach IA'),
                ),
              if (wide)
                TextButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/prof'),
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  icon: const Icon(Icons.search_rounded, size: 17),
                  label: const Text('Encontrar treinador'),
                ),
              const SizedBox(width: 8),
              _PlatformAccessButton(compact: !wide),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHero(BuildContext context, bool wide) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 42, 22, 60),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1160),
          child: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(flex: 6, child: _buildHeroCopy(context, wide)),
                    const SizedBox(width: 54),
                    const Expanded(flex: 5, child: _WorkflowPreview()),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeroCopy(context, wide),
                    const SizedBox(height: 36),
                    const _WorkflowPreview(),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildHeroCopy(BuildContext context, bool wide) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'PLATAFORMA PARA PERSONAL TRAINERS E ALUNOS',
          style: TextStyle(
            color: _green,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Mais clareza na rotina. Mais espaço para acompanhar pessoas.',
          style: TextStyle(
            color: Colors.white,
            fontSize: wide ? 54 : 39,
            fontWeight: FontWeight.w900,
            height: 1.04,
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'O Mr. Coach conecta organização de alunos, prescrição de treinos e acompanhamento em uma experiência compartilhada entre treinador e aluno.',
          style: TextStyle(color: _muted, fontSize: 16, height: 1.65),
        ),
        const SizedBox(height: 26),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/home'),
              icon: const Icon(Icons.login_rounded, size: 18),
              label: const Text('Acessar plataforma'),
              style: FilledButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/prof'),
              icon: const Icon(Icons.search_rounded, size: 18),
              label: const Text('Encontrar treinador'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 48),
                side: const BorderSide(color: Color(0xFF35443B)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAudience(BuildContext context, bool wide) {
    final trainer = _AudienceColumn(
      number: '01',
      title: 'Para quem orienta',
      description:
          'Organize sua lista de alunos, prepare prescrições e acompanhe a rotina profissional em um só lugar.',
      icon: Icons.sports_gymnastics_rounded,
    );
    final student = _AudienceColumn(
      number: '02',
      title: 'Para quem treina',
      description:
          'Conheça o treinador, confirme seu contato e preencha a avaliação. O treino aparece depois da conversa e da liberação profissional.',
      icon: Icons.fitness_center_rounded,
    );
    return Container(
      width: double.infinity,
      color: const Color(0xFFF1F4EF),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 54),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1160),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'UMA EXPERIÊNCIA, DOIS PONTOS DE VISTA',
                style: TextStyle(color: MetaColors.emerald, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.1),
              ),
              const SizedBox(height: 12),
              const Text(
                'Cada pessoa entra pelo caminho certo.',
                style: TextStyle(color: _ink, fontSize: 30, fontWeight: FontWeight.w900, height: 1.15),
              ),
              const SizedBox(height: 28),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [Expanded(child: trainer), const SizedBox(width: 42), Expanded(child: student)],
                )
              else
                Column(
                  children: [trainer, const SizedBox(height: 28), student],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWorkflow(BuildContext context, bool wide) {
    final steps = [
      ('01', 'Conheça o treinador', 'Abra o convite recebido ou encontre um profissional no diretório público.'),
      ('02', 'Confirme seus contatos e cadastre-se', 'No convite, use o e-mail ou telefone para o qual ele foi enviado.'),
      ('03', 'Preencha sua avaliação', 'As informações ficam vinculadas à sua conta para o treinador consultar.'),
      ('04', 'Converse e aguarde', 'O treinador alinha a consultoria e libera o treino quando estiver pronto.'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 56, 22, 58),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1160),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'COMECE PELA PLATAFORMA',
                style: TextStyle(color: _green, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.1),
              ),
              const SizedBox(height: 12),
              const Text(
                'Um acesso compartilhado. Jornadas preservadas.',
                style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900, height: 1.15),
              ),
              const SizedBox(height: 28),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var index = 0; index < steps.length; index++) ...[
                      if (index > 0) const SizedBox(width: 24),
                      Expanded(child: _StepItem(number: steps[index].$1, title: steps[index].$2, detail: steps[index].$3)),
                    ],
                  ],
                )
              else
                Column(
                  children: [
                    for (final step in steps)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 22),
                        child: _StepItem(number: step.$1, title: step.$2, detail: step.$3),
                      ),
                  ],
                ),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/prof'),
                icon: const Icon(Icons.search_rounded, size: 18),
                label: const Text('Encontrar treinador'),
                style: FilledButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFF27332B)))),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1160),
          child: Row(
            children: [
              const Expanded(
                child: Text('© 2026 Shaipados Labs', style: TextStyle(color: _muted, fontSize: 12)),
              ),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/ai'),
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                child: const Text('Mr. Coach IA'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkflowPreview extends StatelessWidget {
  const _WorkflowPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: B2BLandingScreen._panel,
        border: Border.all(color: const Color(0xFF35443B)),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.dashboard_customize_outlined, color: B2BLandingScreen._green, size: 19),
              SizedBox(width: 9),
              Text('ROTINA DO TREINADOR', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 20),
          _PreviewRow(icon: Icons.groups_2_outlined, title: 'Alunos', detail: 'Perfis e acompanhamento'),
          const Divider(color: Color(0xFF344038), height: 24),
          _PreviewRow(icon: Icons.edit_note_rounded, title: 'Prescrições', detail: 'Treinos organizados por aluno'),
          const Divider(color: Color(0xFF344038), height: 24),
          _PreviewRow(icon: Icons.link_rounded, title: 'Acesso do aluno', detail: 'Convite com vínculo ao treinador'),
        ],
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;

  const _PreviewRow({required this.icon, required this.title, required this.detail});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: B2BLandingScreen._green, size: 21),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(detail, style: const TextStyle(color: B2BLandingScreen._muted, fontSize: 12)),
            ],
          ),
        ),
        const Icon(Icons.arrow_forward_ios_rounded, color: B2BLandingScreen._muted, size: 13),
      ],
    );
  }
}

class _AudienceColumn extends StatelessWidget {
  final String number;
  final String title;
  final String description;
  final IconData icon;

  const _AudienceColumn({required this.number, required this.title, required this.description, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: MetaColors.emerald, size: 26),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(number, style: const TextStyle(color: MetaColors.emerald, fontSize: 11, fontWeight: FontWeight.w800)),
              const SizedBox(height: 7),
              Text(title, style: const TextStyle(color: B2BLandingScreen._ink, fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(description, style: const TextStyle(color: Color(0xFF657168), fontSize: 14, height: 1.55)),
            ],
          ),
        ),
      ],
    );
  }
}

class _StepItem extends StatelessWidget {
  final String number;
  final String title;
  final String detail;

  const _StepItem({required this.number, required this.title, required this.detail});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(number, style: const TextStyle(color: B2BLandingScreen._green, fontSize: 12, fontWeight: FontWeight.w900)),
        const SizedBox(height: 9),
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(detail, style: const TextStyle(color: B2BLandingScreen._muted, fontSize: 13, height: 1.5)),
      ],
    );
  }
}

class _PlatformAccessButton extends StatelessWidget {
  final bool compact;

  const _PlatformAccessButton({required this.compact});

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return IconButton(
        tooltip: 'Acessar plataforma',
        onPressed: () => Navigator.pushNamed(context, '/home'),
        icon: const Icon(Icons.login_rounded),
        color: B2BLandingScreen._green,
      );
    }
    return FilledButton.icon(
      onPressed: () => Navigator.pushNamed(context, '/home'),
      icon: const Icon(Icons.login_rounded, size: 17),
      label: const Text('Acessar plataforma'),
      style: FilledButton.styleFrom(
        backgroundColor: B2BLandingScreen._green,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 42),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
    );
  }
}

// =============================================================================
// ONDA 1: CALCULADORA INTERATIVA DE FATURAMENTO & ROI DO TREINADOR
// =============================================================================

class _RoiCalculatorSection extends StatefulWidget {
  final bool wide;

  const _RoiCalculatorSection({required this.wide});

  @override
  State<_RoiCalculatorSection> createState() => _RoiCalculatorSectionState();
}

class _RoiCalculatorSectionState extends State<_RoiCalculatorSection> {
  double _students = 30;
  double _ticketPrice = 250;

  static const double _proPlanCost = 89.0;

  void _applyPreset(double students, double price) {
    setState(() {
      _students = students;
      _ticketPrice = price;
    });
  }

  @override
  Widget build(BuildContext context) {
    final monthlyRevenue = _students * _ticketPrice;
    final annualRevenue = monthlyRevenue * 12;
    final costRatio = (monthlyRevenue > 0) ? (_proPlanCost / monthlyRevenue) * 100 : 0.0;
    final traditionalHours = _students.round(); // ~1 hora/mês por aluno com fichas manuais
    const aiHours = 0.5; // ~30 minutos/mês usando o motor de IA do Mr. Coach
    final hoursSaved = (traditionalHours - aiHours).clamp(1.0, 999.0);
    final roiMultiplier = (monthlyRevenue / _proPlanCost);

    return Container(
      width: double.infinity,
      color: const Color(0xFF0F1612),
      padding: EdgeInsets.symmetric(horizontal: 22, vertical: widget.wide ? 72 : 48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1160),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBadge(
                icon: Icons.calculate_outlined,
                label: 'SIMULADOR DE FATURAMENTO & ESCALABILIDADE',
              ),
              const SizedBox(height: 14),
              Text(
                'Quanto você pode faturar e quanto tempo vai economizar?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: widget.wide ? 34 : 25,
                  fontWeight: FontWeight.w900,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Ajuste sua estimativa de alunos e o valor da sua mensalidade. O simulador calcula em tempo real sua receita bruta, o tempo livre recuperado e o custo irrisório do Mr. Coach.',
                style: TextStyle(
                  color: B2BLandingScreen._muted,
                  fontSize: 15,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 34),
              if (widget.wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 6, child: _buildSlidersCard()),
                    const SizedBox(width: 36),
                    Expanded(
                      flex: 5,
                      child: _buildResultsCard(
                        monthlyRevenue: monthlyRevenue,
                        annualRevenue: annualRevenue,
                        costRatio: costRatio,
                        hoursSaved: hoursSaved,
                        roiMultiplier: roiMultiplier,
                      ),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    _buildSlidersCard(),
                    const SizedBox(height: 24),
                    _buildResultsCard(
                      monthlyRevenue: monthlyRevenue,
                      annualRevenue: annualRevenue,
                      costRatio: costRatio,
                      hoursSaved: hoursSaved,
                      roiMultiplier: roiMultiplier,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: B2BLandingScreen._green.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: B2BLandingScreen._green.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: B2BLandingScreen._green, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: B2BLandingScreen._green,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.9,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlidersCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: B2BLandingScreen._panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2E3E33)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Alunos na consultoria',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B100D),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: B2BLandingScreen._green.withValues(alpha: 0.4)),
                ),
                child: Text(
                  '${_students.round()} alunos',
                  style: const TextStyle(
                    color: B2BLandingScreen._green,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: B2BLandingScreen._green,
              inactiveTrackColor: const Color(0xFF26362B),
              thumbColor: Colors.white,
              overlayColor: B2BLandingScreen._green.withValues(alpha: 0.2),
            ),
            child: Slider(
              value: _students,
              min: 5,
              max: 100,
              divisions: 19,
              onChanged: (v) => setState(() => _students = v),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Mensalidade média do aluno',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B100D),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: B2BLandingScreen._green.withValues(alpha: 0.4)),
                ),
                child: Text(
                  CurrencyPtBrFormatter.format(_ticketPrice),
                  style: const TextStyle(
                    color: B2BLandingScreen._green,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: B2BLandingScreen._green,
              inactiveTrackColor: const Color(0xFF26362B),
              thumbColor: Colors.white,
              overlayColor: B2BLandingScreen._green.withValues(alpha: 0.2),
            ),
            child: Slider(
              value: _ticketPrice,
              min: 100,
              max: 500,
              divisions: 40,
              onChanged: (v) => setState(() => _ticketPrice = v),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Cenários rápidos de mercado:',
            style: TextStyle(color: B2BLandingScreen._muted, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildPresetChip('Iniciante (15 alunos • R\$ 180)', 15, 180),
              _buildPresetChip('Pro Ativo (30 alunos • R\$ 250)', 30, 250),
              _buildPresetChip('Elite Coach (60 alunos • R\$ 350)', 60, 350),
              _buildPresetChip('Assessoria (100 alunos • R\$ 400)', 100, 400),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip(String label, double students, double price) {
    final isSelected = (_students == students && _ticketPrice == price);
    return InkWell(
      onTap: () => _applyPreset(students, price),
      borderRadius: BorderRadius.circular(5),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? B2BLandingScreen._green : const Color(0xFF1F2B23),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: isSelected ? B2BLandingScreen._green : const Color(0xFF334539),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFFB4C5BC),
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildResultsCard({
    required double monthlyRevenue,
    required double annualRevenue,
    required double costRatio,
    required double hoursSaved,
    required double roiMultiplier,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF141F18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: B2BLandingScreen._green.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: B2BLandingScreen._green.withValues(alpha: 0.08),
            blurRadius: 28,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'FATURAMENTO BRUTO ESTIMADO',
            style: TextStyle(
              color: B2BLandingScreen._muted,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                CurrencyPtBrFormatter.format(monthlyRevenue),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                '/ mês',
                style: TextStyle(color: B2BLandingScreen._muted, fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          Text(
            'Projeção anual de ${CurrencyPtBrFormatter.format(annualRevenue)}',
            style: const TextStyle(
              color: B2BLandingScreen._green,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Divider(color: Color(0xFF28392F)),
          ),
          _buildRoiRow(
            icon: Icons.access_time_filled_rounded,
            title: 'Tempo operacional economizado',
            highlight: '~${hoursSaved.toStringAsFixed(0)}h / mês livres',
            sub: 'De ${traditionalHoursText()} manuais para apenas 30 minutos com IA',
          ),
          const SizedBox(height: 14),
          _buildRoiRow(
            icon: Icons.pie_chart_outline_rounded,
            title: 'Custo do Mr. Coach Pro',
            highlight: 'Apenas ${costRatio.toStringAsFixed(2)}% da sua receita',
            sub: 'R\$ ${_proPlanCost.toStringAsFixed(2)}/mês • Sem taxa sobre seus alunos',
          ),
          const SizedBox(height: 14),
          _buildRoiRow(
            icon: Icons.rocket_launch_rounded,
            title: 'Retorno sobre o investimento',
            highlight: '${roiMultiplier.toStringAsFixed(0)}x o valor do software',
            sub: 'Cada R\$ 1 investido gera R\$ ${roiMultiplier.toStringAsFixed(0)} em consultoria',
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/register'),
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: const Text('Começar Gratuitamente no Starter'),
              style: FilledButton.styleFrom(
                backgroundColor: B2BLandingScreen._green,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Center(
            child: Text(
              '✓ Sem cartão de crédito • ✓ 3 alunos grátis • ✓ Ativação imediata',
              style: TextStyle(color: B2BLandingScreen._muted, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  String traditionalHoursText() {
    final h = _students.round();
    return '$h horas';
  }

  Widget _buildRoiRow({
    required IconData icon,
    required String title,
    required String highlight,
    required String sub,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: const Color(0xFF1E2E24),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: B2BLandingScreen._green, size: 17),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: B2BLandingScreen._muted, fontSize: 11.5, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                highlight,
                style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 1),
              Text(
                sub,
                style: const TextStyle(color: Color(0xFF7A8B81), fontSize: 11.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// ONDA 1: WIDGET DE TEST-DRIVE BIOMECÂNICO DE IA (SEM CADASTRO / WEB PÚBLICA)
// =============================================================================

class _BiomechanicalTestDriveSection extends StatefulWidget {
  final bool wide;

  const _BiomechanicalTestDriveSection({required this.wide});

  @override
  State<_BiomechanicalTestDriveSection> createState() => _BiomechanicalTestDriveSectionState();
}

class _BiomechanicalScenario {
  final String complaint;
  final String jointTarget;
  final String forceVectorDiagnosis;
  final String instantCorrection;
  final String alternativeExercise;
  final String safetyGain;

  const _BiomechanicalScenario({
    required this.complaint,
    required this.jointTarget,
    required this.forceVectorDiagnosis,
    required this.instantCorrection,
    required this.alternativeExercise,
    required this.safetyGain,
  });
}

class _TestDriveCase {
  final String exerciseName;
  final String category;
  final IconData icon;
  final List<_BiomechanicalScenario> scenarios;

  const _TestDriveCase({
    required this.exerciseName,
    required this.category,
    required this.icon,
    required this.scenarios,
  });
}

class _BiomechanicalTestDriveSectionState extends State<_BiomechanicalTestDriveSection> {
  int _selectedExerciseIndex = 0;
  int _selectedScenarioIndex = 0;

  static const List<_TestDriveCase> _cases = [
    _TestDriveCase(
      exerciseName: 'Agachamento Livre',
      category: 'Membros Inferiores',
      icon: Icons.accessibility_new_rounded,
      scenarios: [
        _BiomechanicalScenario(
          complaint: 'Dor e pinçamento na lombar baixa (L5-S1) no fundo',
          jointTarget: 'Coluna Lombar / Pelve',
          forceVectorDiagnosis:
              'Retroversão pélvica precoce (butt wink) com aumento do braço de momento sobre os eretores e cisalhamento discal em flexão.',
          instantCorrection:
              'Elevação do calcanhar com calço de 1,5 cm, abertura da base para 1,2x a largura dos ombros e manutenção do gradil costal conectado à pelve.',
          alternativeExercise: 'Agachamento Búlgaro no Banco ou Agachamento Goblet com tronco a 70°',
          safetyGain: '-68% de força de cisalhamento na L5-S1 com 95% de estímulo em quadríceps e glúteos.',
        ),
        _BiomechanicalScenario(
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
    _TestDriveCase(
      exerciseName: 'Supino Reto com Barra',
      category: 'Peitoral & Membros Superiores',
      icon: Icons.fitness_center_rounded,
      scenarios: [
        _BiomechanicalScenario(
          complaint: 'Ombro estalando e dor na cápsula anterior',
          jointTarget: 'Articulação Glenoumeral',
          forceVectorDiagnosis:
              'Abdução excessiva do úmero (>75° no plano coronal), comprimindo a cabeça longa do bíceps e manguito sob o acrômio.',
          instantCorrection:
              'Depressão e retração de escápulas, cotovelos fechados a 45°-55° do tronco e barra tocando a linha dos mamilos.',
          alternativeExercise: 'Supino Reto com Halteres em pegada semi-pronada / neutra',
          safetyGain: 'Descompressão total do espaço subacromial e maior pico de contração no peitoral maior.',
        ),
        _BiomechanicalScenario(
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
    _TestDriveCase(
      exerciseName: 'Puxada Alta',
      category: 'Dorsais & Escápulas',
      icon: Icons.vertical_align_bottom_rounded,
      scenarios: [
        _BiomechanicalScenario(
          complaint: 'Sobrecarga nos antebraços sem sentir a grande dorsal',
          jointTarget: 'Complexo Escapulotorácico',
          forceVectorDiagnosis:
              'Falta de depressão escapular prévia ao movimento; puxada acionada por flexão de cotovelos em vez de tração escapular.',
          instantCorrection:
              'Puxar iniciando pelo rebaixamento das escápulas, usando pegada sem polegar (thumbless grip) e cue de "levar os cotovelos aos bolsos".',
          alternativeExercise: 'Remada Baixa Unilateral na polia com pegada neutra',
          safetyGain: 'Isolamento cirúrgico da grande dorsal sem esgotar os flexores do punho.',
        ),
        _BiomechanicalScenario(
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
    _TestDriveCase(
      exerciseName: 'Levantamento Terra',
      category: 'Cadeia Posterior',
      icon: Icons.sports_gymnastics_rounded,
      scenarios: [
        _BiomechanicalScenario(
          complaint: 'Arredondamento lombar na saída do solo',
          jointTarget: 'Eretores da Espinha / Lombar',
          forceVectorDiagnosis:
              'Falta de tensão prévia nas dorsais antes da arrancada ("quebrar a barra") e distância excessiva da barra em relação às tíbias.',
          instantCorrection:
              'Travar as dorsais, colar a barra nas canelas e empurrar o piso com os calcanhares antes de puxar com o quadril.',
          alternativeExercise: 'Levantamento Terra com Trap Bar (barra hexagonal)',
          safetyGain: '-72% de momento flexor na coluna lombar com centro de gravidade alinhado.',
        ),
      ],
    ),
    _TestDriveCase(
      exerciseName: 'Desenvolvimento c/ Halteres',
      category: 'Ombros & Deltoides',
      icon: Icons.pan_tool_alt_rounded,
      scenarios: [
        _BiomechanicalScenario(
          complaint: 'Dor aguda ao descer abaixo de 90° no plano coronal',
          jointTarget: 'Manguito Rotador / Acrômio',
          forceVectorDiagnosis:
              'Movimento executado em abdução total (180° frontal), forçando o tendão do supraespinhal contra a abóbada óssea.',
          instantCorrection:
              'Posicionar os cotovelos 30° à frente no plano escapular com halteres angulados a 45°.',
          alternativeExercise: 'Desenvolvimento Arnold no banco 75° ou Elevação Lateral na polia',
          safetyGain: 'Trajetória fisiológica natural sem compressão subacromial.',
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
      color: const Color(0xFF0B100D),
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
                  color: B2BLandingScreen._green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: B2BLandingScreen._green.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome_rounded, color: B2BLandingScreen._green, size: 14),
                    SizedBox(width: 6),
                    Text(
                      'TEST-DRIVE DE IA EM TEMPO REAL • SEM CADASTRO',
                      style: TextStyle(
                        color: B2BLandingScreen._green,
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
                'Selecione um exercício clássico e uma queixa comum de academia. Veja a adaptação instantânea calculada pela IA como se o aluno estivesse treinando agora.',
                style: TextStyle(
                  color: B2BLandingScreen._muted,
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
                '2. Queixa reportada pelo aluno na academia:',
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

  Widget _buildExerciseChip(int index, _TestDriveCase item) {
    final isSelected = _selectedExerciseIndex == index;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedExerciseIndex = index;
          _selectedScenarioIndex = 0;
        });
      },
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? B2BLandingScreen._green : const Color(0xFF141F18),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? B2BLandingScreen._green : const Color(0xFF2C3E32),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              item.icon,
              size: 16,
              color: isSelected ? Colors.white : B2BLandingScreen._green,
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

  Widget _buildScenarioChip(int index, _BiomechanicalScenario scenario) {
    final isSelected = _selectedScenarioIndex == index;
    return InkWell(
      onTap: () => setState(() => _selectedScenarioIndex = index),
      borderRadius: BorderRadius.circular(5),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF233529) : const Color(0xFF131A16),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: isSelected ? B2BLandingScreen._green : const Color(0xFF2A382F),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              color: isSelected ? B2BLandingScreen._green : B2BLandingScreen._muted,
              size: 15,
            ),
            const SizedBox(width: 8),
            Text(
              scenario.complaint,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFFA5B4AB),
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiDiagnosticCard(_TestDriveCase currentCase, _BiomechanicalScenario scenario) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF111A15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2B3C30)),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 20, offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFF17241D),
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
              border: Border(bottom: BorderSide(color: Color(0xFF25362B))),
            ),
            child: Row(
              children: [
                const Icon(Icons.psychology_rounded, color: B2BLandingScreen._green, size: 20),
                const SizedBox(width: 10),
                const Text(
                  'MOTOR BIOMECÂNICO MR. COACH AI',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: B2BLandingScreen._green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.circle, color: B2BLandingScreen._green, size: 8),
                      SizedBox(width: 6),
                      Text(
                        'RESPOSTA INSTANTÂNEA',
                        style: TextStyle(
                          color: B2BLandingScreen._green,
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
                          const Text(
                            'DIAGNÓSTICO DO VETOR DE FORÇA',
                            style: TextStyle(
                              color: B2BLandingScreen._muted,
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
                        color: const Color(0xFF1E2D22),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: const Color(0xFF374D3D)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ALVO ANATÔMICO',
                            style: TextStyle(color: Color(0xFF8BA093), fontSize: 9.5, fontWeight: FontWeight.w800),
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
                  child: Divider(color: Color(0xFF243329)),
                ),
                // Instant correction
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.tune_rounded, color: B2BLandingScreen._green, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'AJUSTE IMEDIATO RECOMENDADO AO ALUNO',
                            style: TextStyle(
                              color: B2BLandingScreen._green,
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
                            'EXERCÍCIO SUBSTITUTO SE A DOR PERSISTIR',
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
                    color: const Color(0xFF18261E),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: B2BLandingScreen._green.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_user_rounded, color: B2BLandingScreen._green, size: 17),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Benefício biomecânico: ${scenario.safetyGain}',
                          style: const TextStyle(
                            color: Color(0xFFB4CDBF),
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
                    color: const Color(0xFF0F1713),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Text(
                          'Essa proteção acompanha seus alunos em cada série e avisa você no WhatsApp.',
                          style: TextStyle(color: B2BLandingScreen._muted, fontSize: 12),
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
                              side: const BorderSide(color: Color(0xFF35443B)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            ),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pushNamed(context, '/register'),
                            style: FilledButton.styleFrom(
                              backgroundColor: B2BLandingScreen._green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            ),
                            child: const Text('Prescrever com essa IA', style: TextStyle(fontSize: 12)),
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

// =============================================================================
// ONDA 1: BENTO GRID COMPARATIVO: CONSULTORIA ANTIGA vs MR. COACH AI
// =============================================================================

class _ConsultancyComparisonSection extends StatelessWidget {
  final bool wide;

  const _ConsultancyComparisonSection({required this.wide});

  @override
  Widget build(BuildContext context) {
    final items = [
      _ComparisonCardData(
        title: 'Aparelho Ocupado na Academia',
        icon: Icons.fitness_center_rounded,
        oldWay: 'O aluno fica perdido no horário de pico, improvisa qualquer máquina sem critério ou desiste do treino.',
        aiWay: 'A IA sugere substituição biomecânica equivalente em 5 segundos, mantendo ativação, volume e intensidade.',
      ),
      _ComparisonCardData(
        title: 'Dor Articular ou Queixa Inesperada',
        icon: Icons.health_and_safety_rounded,
        oldWay: 'O aluno força o movimento com desconforto, lesiona a articulação e abandona a consultoria no primeiro mês.',
        aiWay: 'Aluno reporta no app: a ficha recalcula o vetor de força, sugere adaptação e notifica você no painel.',
      ),
      _ComparisonCardData(
        title: 'Controle de Cargas e Cálculo de 1RM',
        icon: Icons.trending_up_rounded,
        oldWay: 'Anotações soltas no bloco de notas do celular ou WhatsApp que se perdem na semana seguinte.',
        aiWay: 'Registro série a série com cálculo de 1RM por Epley/Brzycki e gráficos automáticos de sobrecarga progressiva.',
      ),
      _ComparisonCardData(
        title: 'Descanso Entre Séries & Foco',
        icon: Icons.timer_outlined,
        oldWay: 'Aluno se distrai no feed do Instagram, descansa 5 minutos e perde a densidade de estímulo hipertrófico.',
        aiWay: 'Timer cadenciado na tela com alerta tátil e sonoro, mantendo o tempo sob tensão exato da prescrição.',
      ),
      _ComparisonCardData(
        title: 'Percepção de Valor & Retenção',
        icon: Icons.workspace_premium_rounded,
        oldWay: 'Sensação de ter pago por um PDF estático disponível na internet. Churn alto em menos de 60 dias.',
        aiWay: 'Sensação de personal VIP 24 horas no bolso. Retenção média superior a 8 meses com tickets de R\$ 200 a R\$ 500+.',
      ),
    ];

    return Container(
      width: double.infinity,
      color: const Color(0xFF0F1612),
      padding: EdgeInsets.symmetric(horizontal: 22, vertical: wide ? 74 : 50),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1160),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: B2BLandingScreen._green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: B2BLandingScreen._green.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.compare_arrows_rounded, color: B2BLandingScreen._green, size: 14),
                    SizedBox(width: 6),
                    Text(
                      'O FIM DA CONSULTORIA EM PDF',
                      style: TextStyle(
                        color: B2BLandingScreen._green,
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
                'Por que as consultorias antigas perdem alunos e o Mr. Coach retém',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: wide ? 34 : 25,
                  fontWeight: FontWeight.w900,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Compare a experiência de um arquivo estático de planilha com uma consultoria viva, inteligente e conectada.',
                style: TextStyle(
                  color: B2BLandingScreen._muted,
                  fontSize: 15,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 34),
              if (wide)
                Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildBentoCard(items[0])),
                        const SizedBox(width: 20),
                        Expanded(child: _buildBentoCard(items[1])),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildBentoCard(items[2])),
                        const SizedBox(width: 20),
                        Expanded(child: _buildBentoCard(items[3])),
                        const SizedBox(width: 20),
                        Expanded(child: _buildBentoCard(items[4])),
                      ],
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    for (final item in items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: _buildBentoCard(item),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBentoCard(_ComparisonCardData data) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: B2BLandingScreen._panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2C3C31)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2D23),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(data.icon, color: B2BLandingScreen._green, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  data.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Old way
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1314),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF422325)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.close_rounded, color: Color(0xFFFF6666), size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'CONSULTORIA ANTIGA (PDF / WHATSAPP)',
                        style: const TextStyle(
                          color: Color(0xFFFF8888),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  data.oldWay,
                  style: const TextStyle(color: Color(0xFFDFBDBF), fontSize: 12.5, height: 1.45),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // AI way
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF122218),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF2E533B)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.check_rounded, color: B2BLandingScreen._green, size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'CONSULTORIA MODERNA MR. COACH AI',
                        style: const TextStyle(
                          color: B2BLandingScreen._green,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  data.aiWay,
                  style: const TextStyle(color: Color(0xFFC7E4D3), fontSize: 12.5, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ComparisonCardData {
  final String title;
  final IconData icon;
  final String oldWay;
  final String aiWay;

  const _ComparisonCardData({
    required this.title,
    required this.icon,
    required this.oldWay,
    required this.aiWay,
  });
}

