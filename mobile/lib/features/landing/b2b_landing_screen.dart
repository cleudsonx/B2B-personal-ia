import 'package:flutter/material.dart';

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
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(context, wide)),
            SliverToBoxAdapter(child: _buildHero(context, wide)),
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
              onPressed: () => Navigator.pushNamed(context, '/ai'),
              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
              label: const Text('Mr. Coach IA'),
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
          'Acesse os treinos compartilhados pelo treinador e use as ferramentas disponíveis durante sua jornada.',
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
      ('01', 'Acesse sua conta', 'Treinadores e alunos usam o mesmo ponto de entrada.'),
      ('02', 'Entre no seu espaço', 'A plataforma direciona cada conta conforme o perfil salvo.'),
      ('03', 'Siga o vínculo', 'Alunos convidados continuam pelo link recebido do treinador.'),
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
                onPressed: () => Navigator.pushNamed(context, '/home'),
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: const Text('Acessar plataforma'),
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
