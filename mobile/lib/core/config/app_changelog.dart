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
    // v1.11.3 - ABA SOCIAL & COMUNIDADE 2.0 (ROBÔ WA IN-APP)
    // ==========================================
    VersionRelease(
      version: '1.12.14',
      buildNumber: 2026103129,
      date: '28 de Outubro, 2026',
      summary:
          'Versão 1.11.3: Modernização da Aba Social & Comunidade do Treinador com disparo In-App via Robô do WhatsApp em 1 clique e em lote, Mural com Broadcast, Pódio Editorial One UI 7, Filtros de Retenção e Loader Executive Shimmer.',
      highlights: [
        // --- PROFESSOR / TREINADOR ---
        ChangelogItem(
          icon: Icons.smart_toy_rounded,
          title: 'Aba Social & Comunidade 2.0 com Robô In-App',
          description:
              'Incentivos e parabéns por treino ou ofensiva enviados 100% dentro do app pelo Robô WhatsApp em 1 clique e em lote, sem abrir links externos.',
          badge: 'RETENÇÃO',
          targetRoles: ['trainer'],
        ),
        ChangelogItem(
          icon: Icons.emoji_events_rounded,
          title: 'Pódio Editorial Top 3 & Filtros de Retenção',
          description:
              'Reconhecimento visual dos alunos mais dedicados com pódio One UI 7 e filtros estratégicos: Geral, Em Chamas (+7d) e Resgate Anti-Churn (+4d).',
          badge: 'ENGAGEMENT',
          targetRoles: ['trainer'],
        ),
        ChangelogItem(
          icon: Icons.campaign_rounded,
          title: 'Mural do Treinador com Broadcast via Robô',
          description:
              'Publique avisos e desafios com templates rápidos e opção de envio direto para a turma no WhatsApp com 1 toque.',
          badge: 'COMUNICAÇÃO',
          targetRoles: ['trainer'],
        ),

        // --- ALUNO & TREINO ---
        ChangelogItem(
          icon: Icons.speed_rounded,
          title: 'Carrossel de Treinos com Anéis de Desempenho',
          description:
              'Feed visual mais elegante exibindo os splits finalizados no dia com badges de conclusão e carregamento com o novo Executive Shimmer.',
          badge: 'DESIGN',
          targetRoles: ['student'],
        ),
        ChangelogItem(
          icon: Icons.local_fire_department_rounded,
          title: 'Feedback de Conclusão e Ofensivas em Tempo Real',
          description:
              'Reconhecimento de consistência e incentivos personalizados do treinador sincronizados com rapidez no feed da comunidade.',
          badge: 'COMUNIDADE',
          targetRoles: ['student'],
        ),

        // --- ADMIN / INFRAESTRUTURA ---
        ChangelogItem(
          icon: Icons.hub_rounded,
          title: 'Integração Unificada WhatsAppDirectService',
          description:
              'Rastreabilidade ponta a ponta dos disparos sociais integrando os registros de telemetria ao Live Student Pulse 3.0.',
          badge: 'ESTABILIDADE',
          targetRoles: ['admin'],
        ),
      ],
    ),
    // ==========================================
    // v1.11.2 - RECARREGAMENTO PWA 1-CLIQUE & FONTES OFICIAIS
    // ==========================================
    VersionRelease(
      version: '1.11.2',
      buildNumber: 2026103109,
      date: '28 de Outubro, 2026',
      summary:
          'Versão 1.11.2: Acionamento instantâneo do botão Atualizar no banner PWA, sincronização determinística de caches, fontes Inter oficiais integradas offline e Suíte de Loaders Shaipados Labs.',
      highlights: [
        // --- ALUNO & TREINO ---
        ChangelogItem(
          icon: Icons.text_fields_rounded,
          title: 'Fontes Inter Oficiais Empacotadas Offline',
          description:
              'Pacote de tipografia Inter oficial integrado diretamente ao bundle da aplicação, eliminando falhas de carregamento em redes oscilantes.',
          badge: 'CORREÇÃO',
          targetRoles: ['student'],
        ),
        ChangelogItem(
          icon: Icons.speed_rounded,
          title: 'Suíte de Loaders Shaipados Labs (60 FPS Nativo)',
          description:
              'Novas animações fluidas para geração de periodização IA, sincronização offline de treinos e substituição inteligente de exercícios no Botão Anti-Fila.',
          badge: 'PERFORMANCE',
          targetRoles: ['student'],
        ),
        ChangelogItem(
          icon: Icons.qr_code_rounded,
          title: 'Vitrines Públicas Canônicas (/p/:username)',
          description:
              'Link curto oficial e padronizado em Stories 9:16, QR Codes e Bio do Instagram com carregamento instantâneo e checkout Pix Asaas.',
          badge: 'CRESCIMENTO',
          targetRoles: ['student'],
        ),

        // --- PROFESSOR / TREINADOR ---
        ChangelogItem(
          icon: Icons.sensors_rounded,
          title: 'Live Student Pulse 3.0 com Robô WhatsApp & IA',
          description:
              'Monitoramento em tempo real unificando dúvidas respondidas pelo robô, trocas de exercício biomecânicas e consultas clínicas da IA.',
          badge: 'TELEMETRIA PRO',
          targetRoles: ['trainer'],
        ),
        ChangelogItem(
          icon: Icons.bolt_rounded,
          title: 'Ações Humanas no WhatsApp em 1 Clique In-App',
          description:
              'Parabenize ofensivas de alunos em lote e envie incentivos personalizados diretamente de dentro do aplicativo via API, sem precisar abrir o WhatsApp.',
          badge: 'AUTOMAÇÃO',
          targetRoles: ['trainer'],
        ),

        // --- ADMIN / INFRAESTRUTURA ---
        ChangelogItem(
          icon: Icons.sync_rounded,
          title: 'Atualização Instantânea PWA 1-Clique',
          description:
              'Ajuste no ciclo de vida e overlay do banner de novidades com recarregamento e limpeza determinística de cache HTTP e Service Worker.',
          badge: 'ESTABILIDADE',
          targetRoles: ['admin'],
        ),
        ChangelogItem(
          icon: Icons.alt_route_rounded,
          title: 'Roteamento Canônico e Fallbacks Seguros de Vitrine',
          description:
              'Unificação de rotas /p/:user em produção com preservação transparente de links legados /prof/ e redirecionamento limpo para o diretório de coaches.',
          badge: 'ESTABILIDADE',
          targetRoles: ['admin'],
        ),
      ],
    ),

    // ==========================================
    // v1.11.0 - CARDS EDITORIAIS ONE UI 7 & 2FA
    // ==========================================
    VersionRelease(
      version: '1.11.0',
      buildNumber: 2026103097,
      date: '26 de Outubro, 2026',
      summary:
          'Versão 1.11.0: Nova Experiência Editorial One UI 7 com Cards Temáticos Vivos, Marcas d\'Água 3D Vetoriais, Seletor de Estilo de Cards, Harmonização Visual Light/Dark e Segurança 2FA Multi-Canal.',
      highlights: [
        // --- ALUNO & TREINO ---
        ChangelogItem(
          icon: Icons.style_rounded,
          title: 'Design Editorial One UI 7 com Cards Temáticos Vivos',
          description:
              'Treino do Dia, BioHub, Cronômetro ATP-CP e Assistente IA com gradientes ricos, tipografia editorial moderna e marcas d\'água vetoriais 3D.',
          badge: 'NOVO VISUAL',
          targetRoles: ['student'],
        ),
        ChangelogItem(
          icon: Icons.palette_rounded,
          title: 'Seletor de Estilo de Cards (Editorial, Neumórfico e Minimalista)',
          description:
              'Personalize a aparência dos cards do seu app. Escolha o visual que melhor combina com você direto nas configurações de Perfil.',
          badge: 'CUSTOMIZAÇÃO',
          targetRoles: ['student'],
        ),
        ChangelogItem(
          icon: Icons.shield_rounded,
          title: 'Autenticação Multifatorial (2FA) Inteligente',
          description:
              'Acesse sua conta com segurança reforçada. Caso não tenha aplicativo autenticador, receba o código via WhatsApp ou E-mail com 1 toque.',
          badge: 'PROTEÇÃO',
          targetRoles: ['student'],
        ),
        ChangelogItem(
          icon: Icons.mark_chat_read_rounded,
          title: 'Alertas e Mensagens de Treino em Tempo Real no WhatsApp',
          description:
              'Receba notificações de novas fichas, avisos de streak em risco e mensagens de apoio do seu treinador diretamente no seu WhatsApp.',
          badge: 'COMUNICAÇÃO',
          targetRoles: ['student'],
        ),

        // --- PROFESSOR / TREINADOR ---
        ChangelogItem(
          icon: Icons.auto_awesome_rounded,
          title: 'Cockpit do Treinador com Dicas de Negócio & Saque Pix One UI 7',
          description:
              'Visual moderno e inspirador na Central de Negócios e no saldo da Carteira, com métricas de faturamento e dicas táticas de alta conversão.',
          badge: 'NEGÓCIO & VENDAS',
          targetRoles: ['trainer'],
        ),
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
