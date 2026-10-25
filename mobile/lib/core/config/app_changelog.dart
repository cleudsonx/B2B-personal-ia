import 'package:flutter/material.dart';

/// Item individual de alteração em uma versão
class ChangelogItem {
  final IconData icon;
  final String title;
  final String description;
  final String? badge; // ex: 'NOVO', 'MELHORIA', 'CORREÇÃO', 'SEGURANÇA'
  final List<String> targetRoles; // ['student'], ['trainer'], ['admin'] ou padrão todos

  const ChangelogItem({
    required this.icon,
    required this.title,
    required this.description,
    this.badge,
    this.targetRoles = const ['student', 'trainer', 'admin'],
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

/// Registro centralizado e limpo de histórico de versões do Mr. Coach / Shaipados.
class AppChangelog {
  static const List<VersionRelease> history = [
    // ==========================================
    // v1.11.0 - SEGURANÇA 2FA & CONEXÃO WHATSAPP
    // ==========================================
    VersionRelease(
      version: '1.11.0',
      buildNumber: 2026103068,
      date: '24 de Outubro, 2026',
      summary:
          'Versão 1.11.0: Modernização Inteligente do 2FA Multi-Canal (WhatsApp, E-mail e Backup Codes de 10 dígitos), Dispositivo Confiável de 30 dias e Integração Estável com Evolution API v2.',
      highlights: [
        // --- ADMIN / INFRAESTRUTURA ---
        ChangelogItem(
          icon: Icons.admin_panel_settings_rounded,
          title: 'Blindagem de Segurança do 2FA & Multi-Canal (WhatsApp, Email e Backup)',
          description:
              'Armazenamento de segredos com hash HMAC-SHA256, expiração atômica de OTPs, rate limiting de 45s e bloqueio preventivo após 5 tentativas.',
          badge: 'SEGURANÇA & ACESSO',
          targetRoles: ['admin'],
        ),
        ChangelogItem(
          icon: Icons.hub_rounded,
          title: 'Conexão Otimizada da Evolution API & Persistência de Sessões',
          description:
              'Mapeamento de volumes persistentes na VPS, integração nativa com cache Redis e eliminação de timeouts em disparos assíncronos.',
          badge: 'INFRAESTRUTURA',
          targetRoles: ['admin'],
        ),

        // --- PROFESSOR / TREINADOR ---
        ChangelogItem(
          icon: Icons.chat_rounded,
          title: 'Pareamento Direto do WhatsApp do Treinador por Código de 8 Dígitos',
          description:
              'Conecte seu WhatsApp instantaneamente digitando o código de pareamento no celular, sem necessidade de escanear QR Code com a câmera.',
          badge: 'WHATSAPP PRO',
          targetRoles: ['trainer'],
        ),
        ChangelogItem(
          icon: Icons.devices_rounded,
          title: 'Acesso 2FA Sem Bloqueio com Dispositivo Confiável de 30 Dias',
          description:
              'Mantenha seu cockpit autenticado por 30 dias no seu dispositivo pessoal, com canais alternativos flexíveis para evitar qualquer perda de acesso.',
          badge: 'PRATICIDADE',
          targetRoles: ['trainer'],
        ),

        // --- ALUNO & COMUM ---
        ChangelogItem(
          icon: Icons.shield_rounded,
          title: 'Autenticação Multifatorial (2FA) Inteligente',
          description:
              'Acesse sua conta com segurança reforçada. Caso não tenha aplicativo autenticador, receba o código via WhatsApp ou E-mail com 1 toque.',
          badge: 'PROTEÇÃO',
          targetRoles: ['student', 'trainer', 'admin'],
        ),
        ChangelogItem(
          icon: Icons.mark_chat_read_rounded,
          title: 'Alertas e Mensagens de Treino em Tempo Real no WhatsApp',
          description:
              'Receba notificações de novas fichas, avisos de streak em risco e mensagens de apoio do seu treinador diretamente no seu WhatsApp.',
          badge: 'COMUNICAÇÃO',
          targetRoles: ['student', 'trainer'],
        ),
      ],
    ),

    // ==========================================
    // v1.10.0 - REDESIGN VISUAL DO ALUNO
    // ==========================================
    VersionRelease(
      version: '1.10.0',
      buildNumber: 2026103064,
      date: '22 de Outubro, 2026',
      summary:
          'Versão 1.10.0: Redesign Completo da Experiência do Aluno (Treino, Mr. Coach AI, Bio-Hub e Perfil) no padrão Apple Fitness+ / Samsung One UI 7, Anéis de Atividade e Imersão Edge-to-Edge.',
      highlights: [
        ChangelogItem(
          icon: Icons.fitness_center_rounded,
          title: 'Nova Experiência Visual do Aluno (4 Abas + Shell Edge-to-Edge)',
          description:
              'Interface remodelada no padrão Apple Fitness+ e One UI 7, anéis de atividade no Bio-Hub, biometria em tempo real e cálculo de IMC instantâneo.',
          badge: 'UX/UI 2.0',
          targetRoles: ['student', 'trainer', 'admin'],
        ),
        ChangelogItem(
          icon: Icons.fullscreen_rounded,
          title: 'Cockpit Edge-to-Edge com Doca Flutuante Translúcida',
          description:
              'Imersão contínua por trás da Status Bar e barra de gestos em 100% das telas, sem tarjas pretas no Android, iOS e Web.',
          badge: 'COCKPIT B2B',
          targetRoles: ['trainer', 'admin'],
        ),
        ChangelogItem(
          icon: Icons.content_copy_rounded,
          title: 'Motor de Prescrição em Lote & Clonagem de Mesociclos',
          description:
              'Duplicação ágil de fichas com regras dinâmicas de progressão linear e notificação transversal de sincronização para os alunos.',
          badge: 'AUTOMAÇÃO',
          targetRoles: ['trainer', 'admin'],
        ),
      ],
    ),

    // ==========================================
    // v1.9.0 - TELEMETRIA & SAÚDE INTEGRADA
    // ==========================================
    VersionRelease(
      version: '1.9.0',
      buildNumber: 2026102600,
      date: '17 de Outubro, 2026',
      summary:
          'Versão 1.9.0: Conector de Saúde Apple Health & Google Health Connect, Central de 1RM Teórico e Módulo de Conquistas.',
      highlights: [
        ChangelogItem(
          icon: Icons.monitor_heart_rounded,
          title: 'Módulo de Telemetria Vital & Saúde Integrada',
          description:
              'Sincronização de passos, calorias ativas, sono e hidratação direto do Apple Health, Google Health Connect e smartwatches.',
          badge: 'SAÚDE & IOT',
          targetRoles: ['student', 'trainer', 'admin'],
        ),
        ChangelogItem(
          icon: Icons.stacked_bar_chart_rounded,
          title: 'Central de Sobrecarga & 1RM Teórico (Suíte Meta Science)',
          description:
              'Cálculo de força máxima pelas fórmulas Epley e Brzycki, zonas de hipertrofia e gráfico de tonelagem semanal.',
          badge: 'CIÊNCIA',
          targetRoles: ['student', 'trainer', 'admin'],
        ),
        ChangelogItem(
          icon: Icons.military_tech_rounded,
          title: 'Módulo de Conquistas & Gamificação (Suíte Meta Growth)',
          description:
              'Sistema de badges e tiers comemorativos por marcos de carga e consistência, com compartilhamento social.',
          badge: 'GROWTH',
          targetRoles: ['student', 'trainer'],
        ),
      ],
    ),
  ];

  /// Retorna a versão corrente (a mais recente do histórico)
  static VersionRelease get current => history.first;

  /// Retorna todas as versões anteriores
  static List<VersionRelease> get previousReleases => history.skip(1).toList();
}
