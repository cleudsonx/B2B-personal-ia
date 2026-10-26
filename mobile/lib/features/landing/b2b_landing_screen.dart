import 'package:flutter/material.dart';

import '../../core/utils/currency_pt_br_formatter.dart';
import '../../core/widgets/meta_components.dart';
import 'widgets/biomechanical_test_drive_widget.dart';

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
            SliverToBoxAdapter(child: BiomechanicalTestDriveWidget(wide: wide)),
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
    final isDark = MetaColors.isDark(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0B100D) : const Color(0xFFF1F5F9),
        border: Border(
          top: BorderSide(color: isDark ? const Color(0xFF27332B) : const Color(0xFFCBD5E1)),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1160),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 12,
            children: [
              Text(
                '© 2026 Shaipados Labs • Todos os direitos reservados',
                style: TextStyle(
                  color: isDark ? _muted : const Color(0xFF64748B),
                  fontSize: 12,
                ),
              ),
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: () => _showTermsDialog(context),
                    style: TextButton.styleFrom(
                      foregroundColor: isDark ? Colors.white70 : const Color(0xFF334155),
                    ),
                    child: const Text('Termos de Uso', style: TextStyle(fontSize: 12)),
                  ),
                  TextButton(
                    onPressed: () => _showPrivacyDialog(context),
                    style: TextButton.styleFrom(
                      foregroundColor: isDark ? Colors.white70 : const Color(0xFF334155),
                    ),
                    child: const Text('Privacidade', style: TextStyle(fontSize: 12)),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, '/ai'),
                    style: TextButton.styleFrom(
                      foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    child: const Text('Mr. Coach IA', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void _showTermsDialog(BuildContext context) {
    final isDark = MetaColors.isDark(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF111827) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: isDark ? const Color(0xFF1F2937) : const Color(0xFFCBD5E1)),
        ),
        title: Text(
          'Termos de Uso • Mr. Coach',
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Text(
            'Ao utilizar o Mr. Coach e o ecossistema Shaipados Labs, você concorda com os termos de prestação de serviço de inteligência artificial aplicada ao treinamento físico. '
            'A plataforma atua como ferramenta de suporte a profissionais de Educação Física certificados e seus alunos. '
            'Todas as prescrições devem respeitar a individualidade biológica e a liberação médica do praticante.',
            style: TextStyle(
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido', style: TextStyle(color: _green, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  static void _showPrivacyDialog(BuildContext context) {
    final isDark = MetaColors.isDark(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF111827) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: isDark ? const Color(0xFF1F2937) : const Color(0xFFCBD5E1)),
        ),
        title: Text(
          'Política de Privacidade & LGPD',
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Text(
            'O Shaipados Labs respeita a sua privacidade e a Lei Geral de Proteção de Dados (LGPD - Lei 13.709/2018). '
            'Coletamos estritamente os dados necessários para o cálculo biomecânico de periodização e acompanhamento de treinos. '
            'Seus dados nunca são comercializados com terceiros e estão protegidos por criptografia e Row-Level Security (RLS) no Supabase.',
            style: TextStyle(
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido', style: TextStyle(color: _green, fontWeight: FontWeight.bold)),
          ),
        ],
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
        borderRadius: BorderRadius.circular(16),
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
                  borderRadius: BorderRadius.circular(6),
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
                  borderRadius: BorderRadius.circular(6),
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
              _buildPresetChip('Iniciante (15 alunos • ${CurrencyPtBrFormatter.format(180)})', 15, 180),
              _buildPresetChip('Pro Ativo (30 alunos • ${CurrencyPtBrFormatter.format(250)})', 30, 250),
              _buildPresetChip('Elite Coach (60 alunos • ${CurrencyPtBrFormatter.format(350)})', 60, 350),
              _buildPresetChip('Assessoria (100 alunos • ${CurrencyPtBrFormatter.format(400)})', 100, 400),
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
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? B2BLandingScreen._green : const Color(0xFF1F2B23),
          borderRadius: BorderRadius.circular(8),
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: B2BLandingScreen._green.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: B2BLandingScreen._green.withValues(alpha: 0.12),
            blurRadius: 32,
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
            title: 'Custo da plataforma (Plano Pro)',
            highlight: 'Apenas ${costRatio.toStringAsFixed(2)}% da sua receita bruta',
            sub: '${CurrencyPtBrFormatter.format(_proPlanCost)}/mês • 1 aluno já paga 100% da ferramenta',
          ),
          const SizedBox(height: 14),
          _buildRoiRow(
            icon: Icons.rocket_launch_rounded,
            title: 'Retorno sobre o investimento (ROI)',
            highlight: '${roiMultiplier.toStringAsFixed(0)}x o valor do software',
            sub: 'Cada R\$ 1,00 investido gera ${CurrencyPtBrFormatter.format(roiMultiplier)} em consultoria',
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/professor/cadastro'),
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: const Text(
                'Criar Minha Vitrine Grátis no Starter',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: B2BLandingScreen._green,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
// PILAR 2: WIDGET DE TEST-DRIVE BIOMECÂNICO DE IA (SEM CADASTRO / WEB PÚBLICA)
// Modularizado em `mobile/lib/features/landing/widgets/biomechanical_test_drive_widget.dart`
// =============================================================================

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
        title: 'Cobrança de Mensalidades & Split Automático',
        icon: Icons.payments_outlined,
        oldWay: 'Cobrança manual constrangedora no WhatsApp, comprovantes perdidos e prejuízo com calotes frequentes.',
        aiWay: 'Cobrança automatizada via Asaas (Pix e Cartão) com split 95%/5%, liberação instantânea e gestão de inadimplência.',
      ),
      _ComparisonCardData(
        title: 'Percepção de Valor & Retenção',
        icon: Icons.workspace_premium_rounded,
        oldWay: 'Sensação de ter pago por um PDF estático disponível na internet. Churn alto em menos de 60 dias.',
        aiWay: 'Sensação de personal VIP 24 horas no bolso. Retenção média superior a 8 meses com tickets de ${CurrencyPtBrFormatter.format(200)} a ${CurrencyPtBrFormatter.format(500)}+.',
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
                  borderRadius: BorderRadius.circular(999),
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
                        const SizedBox(width: 20),
                        Expanded(child: _buildBentoCard(items[2])),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildBentoCard(items[3])),
                        const SizedBox(width: 20),
                        Expanded(child: _buildBentoCard(items[4])),
                        const SizedBox(width: 20),
                        Expanded(child: _buildBentoCard(items[5])),
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
              const SizedBox(height: 28),
              // Callout de Retenção & Performance One UI 7
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF142018),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: B2BLandingScreen._green.withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: B2BLandingScreen._green.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.insights_rounded, color: B2BLandingScreen._green, size: 22),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Text(
                        'Estatística Comprovada: Alunos acompanhados pelo ecossistema Mr. Coach treinam 3.4x mais dias seguidos e renovam 85% mais planos do que em consultorias de planilha estática.',
                        style: TextStyle(
                          color: Color(0xFFE2F3E9),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2C3C31)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2D23),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(data.icon, color: B2BLandingScreen._green, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  data.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15.5,
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
              borderRadius: BorderRadius.circular(10),
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
              borderRadius: BorderRadius.circular(10),
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

