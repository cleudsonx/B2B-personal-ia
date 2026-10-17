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
      version: '1.4.2',
      buildNumber: 2026102875,
      date: '17 de Outubro, 2026',
      summary:
          'Checkout Asaas Transparente: Pix & Cartão centralizados na conta oficial, detecção automática de bandeiras, máscaras e validação obrigatória de CPF/CNPJ.',
      highlights: [
        ChangelogItem(
          icon: Icons.credit_card_rounded,
          title: 'Detecção Automática de Bandeira & Máscaras Mobile',
          description:
              'Formatação inteligente em tempo real para Visa, Mastercard, Elo, Amex e Hipercard, com validade MM/AA, CVV protegido e formatação de telefone.',
          badge: 'NOVO',
        ),
        ChangelogItem(
          icon: Icons.badge_outlined,
          title: 'Campo Obrigatório de CPF ou CNPJ (BACEN & Asaas)',
          description:
              'Validador nativo com máscara dinâmica de CPF/CNPJ integrado ao Asaas para emissão de nota fiscal e conciliação instantânea.',
          badge: 'SEGURANÇA',
        ),
        ChangelogItem(
          icon: Icons.pix_rounded,
          title: 'Centralização Financeira em Conta Única Asaas',
          description:
              'Cobranças Pix Copia e Cola e assinaturas de cartão liquidadas diretamente na conta oficial do titular, sem redirecionamentos externos.',
          badge: 'MELHORIA',
        ),
      ],
    ),
    VersionRelease(
      version: '1.4.0',
      buildNumber: 2026102873,
      date: '17 de Outubro, 2026',
      summary:
          'Fase 1 (One UI 7 / Samsung Health): Dock Flutuante em Cápsula com Blur, Controles Translúcidos de Topo, Barra Flutuante de Confirmação e Menu Popover com Ponto Laranja.',
      highlights: [
        ChangelogItem(
          icon: Icons.view_carousel_rounded,
          title: 'Dock Inferior Flutuante em Cápsula com Blur (Edge-to-Edge)',
          description:
              'Nova barra de navegação flutuante com efeito vidro fosco (BackdropFilter), pílula interna de seleção ativa e listas rolando suavemente por trás do menu.',
          badge: 'NOVO',
        ),
        ChangelogItem(
          icon: Icons.more_vert_rounded,
          title: 'Menu Popover Super-Arredondado com Ponto Laranja (•)',
          description:
              'Novo botão de opções rápidas no topo das abas Alunos, Social e Vitrine com indicador laranja para abrir as novidades da versão, alternar tema e configurar vitrine.',
          badge: 'UX',
        ),
        ChangelogItem(
          icon: Icons.tune_rounded,
          title: 'Controles Translúcidos de Topo & Barra [ Cancelar | Salvar ]',
          description:
              'Botões flutuantes translúcidos no cabeçalho e nova barra de confirmação em cápsula dividida com divisor central na configuração da Vitrine.',
          badge: 'MELHORIA',
        ),
      ],
    ),
    VersionRelease(
      version: '1.3.14',
      buildNumber: 2026102869,
      date: '17 de Outubro, 2026',
      summary:
          'Cockpit de Prescrição na Aba Treinos, Guia Interativo 360º do Aluno, Link 1-Toque na Vitrine, Nova Aba Conta e Sincronização Global de WhatsApp.',
      highlights: [
        ChangelogItem(
          icon: Icons.dashboard_customize_rounded,
          title: 'Cockpit de Prescrição & Vigência (Aba Treinos)',
          description:
              'Painel executivo com KPIs em tempo real (Fichas em Dia, Renovação e Fila), filtros inteligentes de vigência de 30 dias e renovação rápida com 1 toque.',
          badge: 'NOVO',
        ),
        ChangelogItem(
          icon: Icons.storefront_rounded,
          title: 'Link de Vendas 1-Toque na Vitrine & Nova Aba Conta',
          description:
              'Botão instantâneo para copiar o link público de vendas na Vitrine B2B e reorganização executiva dos 5 cartões principais na aba Conta.',
          badge: 'MELHORIA',
        ),
        ChangelogItem(
          icon: Icons.menu_book_rounded,
          title: 'Guia Interativo 360º (Pré, Durante e Pós-Treino)',
          description:
              'Novo manual interativo em 4 abas para orientar o aluno antes, durante e após o treino, além de sincronização global de telefone em todo o sistema.',
          badge: 'UX',
        ),
      ],
    ),
    VersionRelease(
      version: '1.3.13',
      buildNumber: 2026102821,
      date: '16 de Outubro, 2026',
      summary:
          'Estabilização de Lançamento: Correção de Layout no WhatsApp, Resiliência na Criação de Alunos e Testes CI/CD 100% Verdes.',
      highlights: [
        ChangelogItem(
          icon: Icons.person_add_rounded,
          title: 'Resiliência no Convite de Alunos',
          description:
              'Correção da trava de cota e blindagem no fluxo de criação de alunos, permitindo cadastros fluidos e geração instantânea de links de convite.',
          badge: 'CORREÇÃO',
        ),
        ChangelogItem(
          icon: Icons.smartphone_rounded,
          title: 'Layout Ergonômico de Conexão WhatsApp',
          description:
              'Textos de indicadores sem quebra de linha, botões de ação sem reticências e cartões de telemetria perfeitamente responsivos em qualquer tela.',
          badge: 'DESIGN',
        ),
        ChangelogItem(
          icon: Icons.check_circle_rounded,
          title: 'Pipeline CI/CD Aprovado',
          description:
              'Ajuste definitivo de layout responsivo (Wrap) no rodapé de notas de versão, eliminando overflows nos testes automatizados do GitHub Actions.',
          badge: 'ESTABILIDADE',
        ),
      ],
    ),
    VersionRelease(
      version: '1.3.12',
      buildNumber: 2026102820,
      date: '16 de Outubro, 2026',
      summary:
          'Fase A: Radar de Atendimento do Robô em tempo real, Botão de Teste 1-Clique no WhatsApp e Pílulas Omnichannel no Chat do Aluno.',
      highlights: [
        ChangelogItem(
          icon: Icons.send_rounded,
          title: 'Disparo de Teste no WhatsApp',
          description:
              'O treinador agora pode enviar uma mensagem de teste real diretamente para o seu próprio WhatsApp com 1 toque para confirmar que a automação está viva.',
          badge: 'NOVO',
        ),
        ChangelogItem(
          icon: Icons.insights_rounded,
          title: 'Radar & Telemetria do Robô',
          description:
              'Extrato transparente com total de atendimentos realizados, alunos únicos e horas economizadas no mês, além do histórico das últimas conversas.',
          badge: 'NOVO',
        ),
        ChangelogItem(
          icon: Icons.touch_app_rounded,
          title: 'Pílulas Rápidas no Chat do Aluno',
          description:
              'Atalhos ergonômicos na barra de digitação para o aluno consultar ficha, ofensiva ou pedir adaptação de máquina ocupada sem atrito.',
          badge: 'MELHORIA',
        ),
      ],
    ),
    VersionRelease(
      version: '1.3.11',
      buildNumber: 2026102819,
      date: '16 de Outubro, 2026',
      summary:
          'Blindagem de Webhook da Evolution API, busca resiliente de alunos por telefone e comandos inteligentes no Chat do Aluno.',
      highlights: [
        ChangelogItem(
          icon: Icons.shield_rounded,
          title: 'Blindagem do Robô WhatsApp',
          description:
              'Identificação ultra-resiliente de alunos mesmo com números salvos com traço ou espaço, suporte a convites pendentes e autoteste para o treinador.',
          badge: 'CORREÇÃO',
        ),
        ChangelogItem(
          icon: Icons.hub_rounded,
          title: 'Registro Forçado de Webhook',
          description:
              'Garantia automática de registro do webhook na Evolution API ao conectar a instância, assegurando recebimento instantâneo de mensagens.',
          badge: 'MELHORIA',
        ),
        ChangelogItem(
          icon: Icons.smart_toy_rounded,
          title: 'Guia Interativo no Chat do App',
          description:
              'O assistente do app agora orienta comandos de menu (1, 2, 3) instantaneamente e indica o canal correto do WhatsApp do seu treinador.',
          badge: 'NOVO',
        ),
      ],
    ),
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
