import 'package:flutter/material.dart';

/// Item individual de alteração em uma versão
class ChangelogItem {
  final IconData icon;
  final String title;
  final String description;
  final String? badge; // ex: 'NOVO', 'MELHORIA', 'CORREÇÃO', 'SEGURANÇA'

  const ChangelogItem({
    required this.icon,
    required this.title,
    required this.description,
    this.badge,
  });
}

/// Representação oficial de uma versão lançada
class VersionRelease {
  final String version;
  final int buildNumber;
  final String date;
  final String summary;
  final List<ChangelogItem> highlights;

  const VersionRelease({
    required this.version,
    required this.buildNumber,
    required this.date,
    required this.summary,
    required this.highlights,
  });

  String get fullTitle => 'v$version (Build $buildNumber)';
}

/// Registro centralizado e dinâmico de histórico de versões do Mr. Coach / Shaipados.
class AppChangelog {
  static const List<VersionRelease> history = [
    VersionRelease(
      version: '1.3.10',
      buildNumber: 2026102818,
      date: '16 de Outubro, 2026',
      summary:
          'Robô WhatsApp sem custo de IA, Substituição de Aparelhos liberada para alunos e Conexão WhatsApp sob demanda.',
      highlights: [
        ChangelogItem(
          icon: Icons.mark_chat_read_rounded,
          title: 'Robô WhatsApp & Triagem Custo Zero',
          description:
              'Alunos consultam fichas e ofensivas (Streak 🔥) via WhatsApp sem gastar tokens de IA. Notificações proativas avisam novas fichas liberadas.',
          badge: 'NOVO',
        ),
        ChangelogItem(
          icon: Icons.fitness_center_rounded,
          title: 'Substituição de Aparelho no Salão',
          description:
              'Alunos agora podem acionar a troca biomecânica de aparelhos ocupados direto pelo app, com contingência instantânea offline.',
          badge: 'MELHORIA',
        ),
        ChangelogItem(
          icon: Icons.phonelink_setup_rounded,
          title: 'Conexão WhatsApp sob Demanda',
          description:
              'O professor pode conferir, editar ou limpar seu número com 1 clique antes de gerar o código de pareamento, e alterá-lo a qualquer momento.',
          badge: 'CORREÇÃO',
        ),
        ChangelogItem(
          icon: Icons.sync_rounded,
          title: 'Heartbeat PWA & Detecção iOS/Android',
          description:
              'Sincronização em tempo real de novas versões no Firebase Hosting para alerta instantâneo no Safari (iPhone) e Chrome (Android).',
          badge: 'ESTABILIDADE',
        ),
      ],
    ),
    VersionRelease(
      version: '1.3.8',
      buildNumber: 2026102815,
      date: '15 de Outubro, 2026',
      summary:
          'Trava comercial para IA no WhatsApp (Fase 2 Pro/Studio) e endpoints proativos de engajamento.',
      highlights: [
        ChangelogItem(
          icon: Icons.shield_rounded,
          title: 'Trava Comercial de Planos',
          description:
              'Planos Pro e Studio liberam o Consultor Ativo IA 24h, garantindo proteção de custos operacionais no plano Starter.',
          badge: 'B2B',
        ),
        ChangelogItem(
          icon: Icons.notifications_active_rounded,
          title: 'Notificações Proativas de Treino',
          description:
              'Disparo automático de mensagem no WhatsApp avisando o aluno sobre nova periodização montada pelo professor.',
          badge: 'NOVO',
        ),
      ],
    ),
    VersionRelease(
      version: '1.3.6',
      buildNumber: 2026102813,
      date: '15 de Outubro, 2026',
      summary:
          'Guia interativo do treino para o aluno, simplificação da interface e atalho direto de WhatsApp com o treinador.',
      highlights: [
        ChangelogItem(
          icon: Icons.help_outline_rounded,
          title: 'Guia do Treino Interativo (?)',
          description:
              'Passo a passo visual e amigável ensinando o aluno a marcar séries, ajustar cargas e usar o timer de descanso.',
          badge: 'UX',
        ),
        ChangelogItem(
          icon: Icons.chat_outlined,
          title: 'Falar com Professor pelo WhatsApp',
          description:
              'Card do treinador agora conta com botão de WhatsApp direto para tirar dúvidas em 1 clique.',
          badge: 'MELHORIA',
        ),
      ],
    ),
    VersionRelease(
      version: '1.3.3',
      buildNumber: 2026102810,
      date: '15 de Outubro, 2026',
      summary:
          'Bio-Recovery, Galeria Sigilosa Antes x Depois e Sobrecarga Progressiva Sincronizada.',
      highlights: [
        ChangelogItem(
          icon: Icons.shield_moon_rounded,
          title: 'Bio-Recovery & Prontidão Real',
          description:
              'Score diário de prontidão biomecânica e telemetria de RPE integrado em tempo real no Supabase.',
          badge: 'IA',
        ),
        ChangelogItem(
          icon: Icons.lock_outline_rounded,
          title: 'Galeria Sigilosa Antes x Depois',
          description:
              'Fotos criptografadas com RLS para acompanhamento seguro da evolução física.',
          badge: 'PRIVACIDADE',
        ),
        ChangelogItem(
          icon: Icons.trending_up_rounded,
          title: 'Sobrecarga Progressiva Sincronizada',
          description:
              'Histórico real de cargas registradas pelo aluno exibido no dashboard de detalhes do professor.',
          badge: 'PERFORMANCE',
        ),
      ],
    ),
  ];

  /// Versão mais recente em produção
  static VersionRelease get current => history.first;

  /// Retorna as versões anteriores
  static List<VersionRelease> get previousReleases => history.sublist(1);
}
