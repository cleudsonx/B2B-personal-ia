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
      version: '1.7.0',
      buildNumber: 2026102921,
      date: '19 de Outubro, 2026',
      summary:
          'Experiência do Aluno no Treino Reformulada (Padrão Ouro Hevy/Strong): Hero Card ergonômico, pílulas de splits horizontais e miniaturas interativas com Focus Mode de alta precisão.',
      highlights: [
        ChangelogItem(
          icon: Icons.fitness_center_rounded,
          title: 'Design Ouro de Treino (Hevy / Strong)',
          description:
              'Novo Hero Card "Treino de Hoje" com CTA único de início imediato, sem cards empilhados bloqueando a visão da academia.',
          badge: 'UX ALUNO',
        ),
        ChangelogItem(
          icon: Icons.view_carousel_rounded,
          title: 'Seletor de Splits em Pílulas',
          description:
              'Abas horizontais compactas e fluidas com indicador do split do dia, facilitando a troca ágil entre divisões.',
          badge: 'ERGONOMIA',
        ),
        ChangelogItem(
          icon: Icons.play_circle_fill_rounded,
          title: 'Miniaturas Interativas 52x52',
          description:
              'Visualização direta da execução com animações fluidas na lista, toque para abrir vídeo instrutivo ou entrar direto no Focus Mode.',
          badge: 'FOCUS MODE',
        ),
      ],
    ),
    VersionRelease(
      version: '1.7.0',
      buildNumber: 2026102910,
      date: '19 de Outubro, 2026',
      summary:
          'Correção Crítica de Cota do Personal Pro (30 Alunos): Ativação e sincronização do status de assinatura, tolerância de ciclo no Supabase e revalidação resiliente antes de bloquear convites.',
      highlights: [
        ChangelogItem(
          icon: Icons.workspace_premium_rounded,
          title: 'Cota Personal Pro Integral (30 Alunos)',
          description:
              'Ajuste definitivo do plano Personal Pro para até 30 alunos com sincronização ativa de cotas e tolerância a períodos de transição.',
          badge: 'COTA',
        ),
        ChangelogItem(
          icon: Icons.play_circle_filled_rounded,
          title: 'Vídeos e GIFs 100% In-App',
          description:
              'Visualização nativa in-app do movimento sem redirecionamento externo para navegador, com modo tela cheia e zoom interativo.',
          badge: 'MÍDIA',
        ),
        ChangelogItem(
          icon: Icons.unfold_more_rounded,
          title: 'Instruções Biomecânicas Colapsáveis',
          description:
              'A descrição detalhada da postura agora fica recolhida por padrão e expande com um toque, poupando espaço e mantendo o foco no treino.',
          badge: 'UX',
        ),
        ChangelogItem(
          icon: Icons.gif_box_rounded,
          title: '432 Exercícios com GIFs Animados Inline',
          description:
              'Demonstrações em loop automático sem delay diretamente no card do exercício, cobrindo Peito, Costas, Bíceps, Tríceps, Ombros, Pernas, Panturrilhas, Abdômen e Calistenia.',
          badge: 'ACERVO',
        ),
        ChangelogItem(
          icon: Icons.play_circle_fill_rounded,
          title: 'Vídeos de Execução & Player Externo',
          description:
              'Suporte híbrido a vídeos em alta definição e GIFs animados com link direto e player de alta resolução.',
          badge: 'MÍDIA',
        ),
        ChangelogItem(
          icon: Icons.accessibility_new_rounded,
          title: 'Integração Raio-X 3D & Cinesiologia',
          description:
              'Guia biomecânico completo com músculos primários, secundários, dicas de postura e atalho direto para a visão anatômica 3D.',
          badge: 'BIOMECÂNICA',
        ),
        ChangelogItem(
          icon: Icons.cloud_sync_rounded,
          title: 'Arquitetura Desacoplada de Mídias',
          description:
              'Suporte a múltiplas fontes de mídia (Google Drive, Cloud Storage, CDNs) sem alterar as fichas cadastradas.',
          badge: 'ARQUITETURA',
        ),
      ],
    ),
    VersionRelease(
      version: '1.6.0',
      buildNumber: 2026102905,
      date: '18 de Outubro, 2026',
      summary:
          'FASE 7 — Consultor Ativo IA 2.0 (Coach Proativo no WhatsApp): Radar de Retenção Proativa (>4 dias), Resumo Executivo Semanal e Comandos Custo Zero 4 e 5.',
      highlights: [
        ChangelogItem(
          icon: Icons.radar_rounded,
          title: 'Radar de Retenção Proativa (>4 Dias Ausente)',
          description:
              'Identifica alunos sem treinar há mais de 4 dias e dispara check-in acolhedor via Robô WhatsApp (em lote ou 1 toque) com trava anti-spam de 48h.',
          badge: 'FASE 7',
        ),
        ChangelogItem(
          icon: Icons.assessment_rounded,
          title: 'Resumo Executivo Semanal no Seu WhatsApp',
          description:
              'Painel executivo da semana (Treinos concluídos, Taxa de Presença, Top Streaks e Alertas de Dor) com envio em 1 toque para o WhatsApp do Personal.',
          badge: 'COACH 2.0',
        ),
        ChangelogItem(
          icon: Icons.flash_on_rounded,
          title: 'Menu Custo Zero Expandido (Opções 4 e 5)',
          description:
              'Alunos agora podem consultar o Bio-Hub (Peso, IMC e Meta) digitando 5 e enviar recados prioritários ao painel do professor digitando 4 — 0 tokens gastos.',
          badge: '0 TOKENS',
        ),
      ],
    ),
    VersionRelease(
      version: '1.5.0',
      buildNumber: 2026102902,
      date: '18 de Outubro, 2026',
      summary:
          'Pacotes A & B: Sobrecarga progressiva real, sincronização automática Anamnese ➔ Bio-Hub, edição rápida de ficha e oficialização de troca biomecânica em 1 toque.',
      highlights: [
        ChangelogItem(
          icon: Icons.swap_horiz_rounded,
          title: 'Oficializar Troca Biomecânica em 1 Toque',
          description:
              'Professores agora podem substituir permanentemente o exercício adaptado na ficha ativa do aluno e resolver o alerta simultaneamente.',
          badge: 'SUPERPODER',
        ),
        ChangelogItem(
          icon: Icons.edit_note_rounded,
          title: 'Edição Rápida In-Place na Ficha Ativa',
          description:
              'Edite nome, séries, repetições, descanso e observações de qualquer exercício, ou adicione/remova exercícios diretamente nos detalhes da ficha.',
          badge: 'GESTÃO',
        ),
        ChangelogItem(
          icon: Icons.trending_up_rounded,
          title: 'Sobrecarga Progressiva Real & Sincronia Bio-Hub',
          description:
              'Cargas salvas no Modo Foco alimentam automaticamente a curva de progressão na nuvem e a Anamnese hidrata o histórico antropométrico.',
          badge: 'BIO-HUB',
        ),
      ],
    ),
    VersionRelease(
      version: '1.5.0',
      buildNumber: 2026102901,
      date: '18 de Outubro, 2026',
      summary:
          'Fase 5: Bio-Hub 2.0 com Split Photo Slider tátil, galeria sigilosa antes/depois e métricas antropométricas corporais.',
      highlights: [
        ChangelogItem(
          icon: Icons.compare_arrows_rounded,
          title: 'Split Photo Slider Tátil Antes & Depois (One UI 7)',
          description:
              'Visualizador interativo de fotos de evolução com slider tátil em tempo real, haptic feedback e exibição simultânea das datas e pesos.',
          badge: 'VISUAL',
        ),
        ChangelogItem(
          icon: Icons.straighten_rounded,
          title: 'Medidas Corporais & Antropometria Integrada',
          description:
              'Acompanhamento de peso, IMC automático com classificação de saúde, % de gordura e circunferências (cintura, braço, tórax, quadril, coxa) com deltas evolutivos.',
          badge: 'ANTROPOMETRIA',
        ),
        ChangelogItem(
          icon: Icons.lock_outline_rounded,
          title: 'Galeria Sigilosa no Prontuário do Treinador',
          description:
              'O professor tem acesso direto no prontuário do aluno à comparação com Split-Slider e ao histórico antropométrico com segurança e confidencialidade.',
          badge: 'COCKPIT B2B',
        ),
      ],
    ),
    VersionRelease(
      version: '1.5.0',
      buildNumber: 2026102900,
      date: '18 de Outubro, 2026',
      summary:
          'Fase 4: WhatsApp Ativo 24h com IA Biomecânica, injeção de Anamnese, Guardrail de Dor e Simulador Interativo.',
      highlights: [
        ChangelogItem(
          icon: Icons.chat_rounded,
          title: 'WhatsApp Ativo 24h & Assistente IA (Fase 4)',
          description:
              'Motor biomecânico Gemini conectado à Evolution API respondendo dúvidas de postura, cadência e substituição de aparelhos 24 horas por dia.',
          badge: 'IA 24H',
        ),
        ChangelogItem(
          icon: Icons.badge_rounded,
          title: 'Injeção da Anamnese Expandida no Contexto da IA',
          description:
              'A IA no WhatsApp agora consulta em tempo real as lesões, restrições e objetivos da anamnese do aluno, garantindo respostas personalizadas e clinicamente seguras.',
          badge: 'BIOMECÂNICA',
        ),
        ChangelogItem(
          icon: Icons.warning_amber_rounded,
          title: 'Safety Guardrail de Dor Aguda',
          description:
              'Detecção automática de relatos de dor forte no WhatsApp: o aluno é orientado a parar imediatamente e um alerta de alta prioridade é disparado no painel do treinador.',
          badge: 'SEGURANÇA',
        ),
        ChangelogItem(
          icon: Icons.science_rounded,
          title: 'Simulador do Robô no Cockpit do Treinador',
          description:
              'Painel interativo para o personal trainer simular mensagens de alunos (ficha, streak, dores, substituição) e testar a IA em tempo real com auditoria de tokens.',
          badge: 'ONE UI 7',
        ),
      ],
    ),
    VersionRelease(
      version: '1.5.0',
      buildNumber: 2026102899,
      date: '18 de Outubro, 2026',
      summary:
          'Fase 3: Modo Treino Focus Mode no Salão (Segmented Story Bar, Recordes PR, Seletor Anatômico de Dores e Gym UX One-Hand).',
      highlights: [
        ChangelogItem(
          icon: Icons.fitness_center_rounded,
          title: 'Modo Treino Focus Mode no Salão (Fase 3)',
          description:
              'Segmented Story Bar estilo status, auto-rest timer com haptic feedback, ajuste tátil de carga sem teclado (+/- 2.5kg), recordes pessoais (PR), seletor de dores articulares e celebração com tonelagem total.',
          badge: 'GYM UX',
        ),
        ChangelogItem(
          icon: Icons.timeline_rounded,
          title: 'Linha do Tempo & Evolução do Aluno',
          description:
              'Visualização comparativa "Antes vs. Agora" no Bio-Hub com delta de peso, evolução do IMC, frequência semanal, dores superadas e botão de 1 toque para novos check-ins.',
          badge: 'EVOLUÇÃO',
        ),
        ChangelogItem(
          icon: Icons.health_and_safety_rounded,
          title: 'Raio-X da Anamnese na Nova Periodização',
          description:
              'Card One UI 7 / Meta no topo da prescrição do professor que auto-hidrata todos os campos, exibe badges clínicas táteis e modal com dados biomédicos completos.',
          badge: 'ONE UI 7',
        ),
        ChangelogItem(
          icon: Icons.alt_route_rounded,
          title: 'Seletor de Split Tátil One UI 7',
          description:
              'Substituição do dropdown clássico por lista tátil de pílulas horizontais com ícones e subtítulos explicativos de cada metodologia de divisão.',
          badge: 'DESIGN',
        ),
        ChangelogItem(
          icon: Icons.shield_rounded,
          title: 'Trava Clínica na Renovação de Ficha',
          description:
              'Proteção preventiva na renovação rápida: alerta o professor caso o aluno tenha relatado novas dores articulares ou restrições após a emissão da ficha vigente.',
          badge: 'SEGURANÇA',
        ),
      ],
    ),
    VersionRelease(
      version: '1.4.9',
      buildNumber: 2026102895,
      date: '18 de Outubro, 2026',
      summary:
          'Persistência Total da Vitrine Pública, Links Oficiais com Domínio shaipados.com e Restauração Automática de Navegação no PWA.',
      highlights: [
        ChangelogItem(
          icon: Icons.storefront_rounded,
          title: 'Correção e Persistência da Vitrine',
          description:
              'Ajuste definitivo no salvamento da Vitrine Pública no Supabase, garantindo compatibilidade estrita com o banco e validações sem erros de schema.',
          badge: 'VITRINE B2B',
        ),
        ChangelogItem(
          icon: Icons.link_rounded,
          title: 'Link Oficial shaipados.com',
          description:
              'Todos os links gerados, exibidos e copiados para divulgação nas redes sociais utilizam exclusivamente o domínio canônico shaipados.com/#/prof/@seu_username.',
          badge: 'DOMÍNIO',
        ),
        ChangelogItem(
          icon: Icons.restore_page_rounded,
          title: 'Restauração de Contexto no PWA',
          description:
              'Ao aceitar uma atualização do app, o PWA restaura automaticamente a aba, recurso ou subtela em que o usuário estava navegando (ex: Montar Vitrine, WhatsApp, Treinos).',
          badge: 'PWA UX',
        ),
        ChangelogItem(
          icon: Icons.fitness_center_rounded,
          title: 'Ergonomia do Aluno (Filosofia Hevy)',
          description:
              'Lista compacta de exercícios com resumo de alta densidade (séries × reps, músculo e EMG), atalho de 1 toque direto para o Focus Mode horizontal e espaçamento seguro.',
          badge: 'ALUNO UX',
        ),
      ],
    ),
    VersionRelease(
      version: '1.4.9',
      buildNumber: 2026102885,
      date: '18 de Outubro, 2026',
      summary:
          'Cockpit One UI 7 Dedicado do Consultor Ativo IA — Disponibilidade Completa nas Abas Vitrine e Conta, com Suporte Total e Explícito ao Plano Elite Coach na Trava Comercial da Fase 2.',
      highlights: [
        ChangelogItem(
          icon: Icons.dashboard_rounded,
          title: 'Tela Dedicada do Cockpit One UI 7',
          description:
              'Interface completa e imersiva para o Consultor Ativo IA acessível tanto na aba Vitrine ("Expanda sua empresa") quanto na aba Conta ("Consultor Ativo IA & WhatsApp"), eliminando dependência de bottom sheets em navegadores PWA.',
          badge: 'ONE UI 7',
        ),
        ChangelogItem(
          icon: Icons.workspace_premium_rounded,
          title: 'Elite Coach na Trava Comercial',
          description:
              'Validação robusta que inclui expressamente o plano Elite Coach (além de Personal Pro e Studio) para uso irrestrito do motor biomecânico Gemini 2.5 Flash 24h no WhatsApp.',
          badge: 'B2B',
        ),
        ChangelogItem(
          icon: Icons.bolt_rounded,
          title: 'Triagem Custo Zero & Telemetria em Tempo Real',
          description:
              'Simulador dos comandos rápidos 1, 2 e 3 na tela, indicador de status online/desconectado do WhatsApp e métricas de horas economizadas.',
          badge: 'TELEMETRIA',
        ),
      ],
    ),
    VersionRelease(
      version: '1.4.8',
      buildNumber: 2026102884,
      date: '17 de Outubro, 2026',
      summary:
          'Correção e Renovação Automática do Código de Pareamento do WhatsApp — Eliminação de Códigos Estagnados em Cache (Reset Limpo de Sessões Pendentes).',
      highlights: [
        ChangelogItem(
          icon: Icons.sync_problem_rounded,
          title: 'Resolução de Código de Pareamento Congelado',
          description:
              'Corrigida inconsistência onde sessões pendentes na Evolution API retinham o código anterior em cache. Agora, a cada novo número ou tentativa, a sessão é reiniciada de forma limpa gerando um código 100% fresco do WhatsApp.',
          badge: 'CORREÇÃO',
        ),
        ChangelogItem(
          icon: Icons.refresh_rounded,
          title: 'Botão de Renovação Rápida',
          description:
              'Adicionado botão direto para gerar novo código caso os 120 segundos de validade do WhatsApp expirem antes de digitar.',
          badge: 'ONE UI 7',
        ),
      ],
    ),
    VersionRelease(
      version: '1.4.7',
      buildNumber: 2026102883,
      date: '17 de Outubro, 2026',
      summary:
          'Frente 3: "Consultor Ativo" no WhatsApp (IA de Suporte 24h) — Triagem de Custo Zero (Comandos Rápidos 1, 2 e 3), IA Biomecânica Gemini 2.5 Flash, Trava Comercial Pro/Studio e Cockpit One UI 7.',
      highlights: [
        ChangelogItem(
          icon: Icons.money_off_rounded,
          title: 'Triagem Custo Zero de IA no WhatsApp',
          description:
              'Comandos automáticos no WhatsApp (*1* Treino Ativo, *2* Ofensiva/Streak 🔥, *3* Link do App) respondem instantaneamente sem consumir tokens de LLM.',
          badge: 'CUSTO ZERO',
        ),
        ChangelogItem(
          icon: Icons.smart_toy_rounded,
          title: 'Consultor Biomecânico IA 24h',
          description:
              'Dúvidas sobre cadência, execução e postura respondidas em segundos pelo Gemini 2.5 Flash com base estrita na ficha de treino prescrita pelo professor.',
          badge: 'IA 24H',
        ),
        ChangelogItem(
          icon: Icons.workspace_premium_rounded,
          title: 'Monetização de Planos & Trava Comercial',
          description:
              'Assistente de IA 24h exclusivo para os planos Pro e Studio; treinadores no Starter contam com a triagem gratuita e encaminhamento direto das dúvidas.',
          badge: 'B2B',
        ),
        ChangelogItem(
          icon: Icons.dashboard_customize_rounded,
          title: 'Cockpit One UI 7 do Assistente',
          description:
              'Nova interface tátil na aba de Ferramentas com guia rápido dos comandos para alunos, status e atalho direto para a central de telemetria.',
          badge: 'ONE UI 7',
        ),
      ],
    ),
    VersionRelease(
      version: '1.4.6',
      buildNumber: 2026102882,
      date: '17 de Outubro, 2026',
      summary:
          'Frente 2: One UI 7 Fase 2 (Cockpit & Gestão do Treinador) — Cards 24px Super-Arredondados, Agrupamento e Triagem por Risco, Micro-ações Táteis com Haptics e Renovação Rápida de Ciclo.',
      highlights: [
        ChangelogItem(
          icon: Icons.rounded_corner_rounded,
          title: 'Design One UI 7 Super-Arredondado (24px)',
          description:
              'Cards redesenhados com cantos ultra-fluidos de 24px, acabamento obsidian e bordas translúcidas de alto contraste.',
          badge: 'VISUAL',
        ),
        ChangelogItem(
          icon: Icons.filter_alt_outlined,
          title: 'Triagem por Risco e Vigência em Pílula',
          description:
              'Filtros táteis rápidos no topo: Em Dia 🟢, Atenção 🟡 e Risco 🔴, identificando imediatamente alunos inativos ou fichas pendentes.',
          badge: 'ONE UI 7',
        ),
        ChangelogItem(
          icon: Icons.touch_app_outlined,
          title: 'Micro-Ações Táteis com Feedback Háptico',
          description:
              'Ações diretas no próprio card: contato por WhatsApp em 1-toque, prescrição de ficha imediata e renovação de ciclo (+30d) sem sair da lista.',
          badge: 'PRODUTIVIDADE',
        ),
        ChangelogItem(
          icon: Icons.linear_scale_rounded,
          title: 'Barra de Progresso do Ciclo de 30 Dias',
          description:
              'Visualização gráfica sutil do ciclo de periodização em cada ficha prescrita para antecipar renovações.',
          badge: 'COCKPIT',
        ),
      ],
    ),
    VersionRelease(
      version: '1.4.5',
      buildNumber: 2026102880,
      date: '17 de Outubro, 2026',
      summary:
          'Frente 1: Experiência do Aluno no Salão (One-Hand Gym UX), Ajuste Tátil de Carga e Repetições sem Teclado, Auto-Rest Timer com Vibração e Correção da Foto do Treinador.',
      highlights: [
        ChangelogItem(
          icon: Icons.fitness_center_rounded,
          title: 'Ergonomia no Salão & Ajuste Tátil sem Teclado',
          description:
              'Ajuste rápido de carga (+/- 2.5kg) e repetições (+/- 1) diretamente na tela, sem invasão do teclado virtual durante as séries.',
          badge: 'NOVO',
        ),
        ChangelogItem(
          icon: Icons.timer_outlined,
          title: 'Auto-Rest Timer com Feedback Háptico',
          description:
              'Ao marcar uma série concluída, o cronômetro de descanso inicia automaticamente, com vibração e botões de +30s e pular.',
          badge: 'UX',
        ),
        ChangelogItem(
          icon: Icons.bolt_rounded,
          title: 'Botão de Pânico "Aparelho Ocupado / Dor"',
          description:
              'Adaptação biomecânica em 1 toque com IA e notificação instantânea para o personal trainer.',
          badge: 'IA',
        ),
        ChangelogItem(
          icon: Icons.account_circle_rounded,
          title: 'Foto do Treinador 100% Preenchida (Meu Status)',
          description:
              'Eliminação de preenchimento ou bordas verdes nas quinas do avatar, garantindo enquadramento circular limpo e perfeito.',
          badge: 'CORREÇÃO',
        ),
      ],
    ),
    VersionRelease(
      version: '1.4.4',
      buildNumber: 2026102878,
      date: '17 de Outubro, 2026',
      summary:
          'Mensagens Amigáveis de Checkout (Padrão Nubank/Stripe), Modal de Recusa Bancária com Fallback para Pix e Correção de Legibilidade do CEP.',
      highlights: [
        ChangelogItem(
          icon: Icons.rocket_launch_rounded,
          title: 'Alerta de Atualização PWA Unificado',
          description:
              'Eliminação da sobreposição de avisos duplicados. Agora o PWA exibe exclusivamente a cápsula nativa inteligente com design escuro esmeralda.',
          badge: 'MELHORIA',
        ),
        ChangelogItem(
          icon: Icons.location_on_rounded,
          title: 'Campos de CEP e Número no Cartão',
          description:
              'Adição de CEP e Número residencial no formulário de checkout para conformidade anti-fraude do gateway Asaas.',
          badge: 'CORREÇÃO',
        ),
        ChangelogItem(
          icon: Icons.credit_card_rounded,
          title: 'Detecção Automática de Bandeira & Máscaras Mobile',
          description:
              'Formatação inteligente em tempo real para Visa, Mastercard, Elo, Amex e Hipercard, com validade MM/AA, CVV protegido e CPF/CNPJ dinâmico.',
          badge: 'NOVO',
        ),
        ChangelogItem(
          icon: Icons.pix_rounded,
          title: 'Pix Transparente na Conta Oficial',
          description:
              'Geração instantânea de QR Code e chave Copia e Cola sem redirecionamentos externos.',
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
