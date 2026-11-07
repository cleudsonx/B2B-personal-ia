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
    // v1.15.0 - HUB DE ANAMNESE CLÍNICA & INTELIGÊNCIA DE LESÕES
    // ==========================================
    VersionRelease(
      version: '1.15.0',
      buildNumber: 2026110702,
      date: '7 de Novembro, 2026',
      summary:
          'Versão 1.15.0: Hub de Anamnese Clínica & Inteligência de Lesões (Matriz articular interativa de 7 regiões, motor cinesiológico O(1) com detecção determinística de contraindicações e substituições protetoras de 1 toque no app).',
      highlights: [
        ChangelogItem(
          icon: Icons.accessibility_new_rounded,
          title: 'Matriz Articular & Blindagem Cinesiológica',
          description:
              'Mapeamento visual e intuitivo de 7 regiões articulares com severidade clínica graduada e patologias comuns na prescrição.',
          badge: 'NOVO',
          targetRoles: ['trainer'],
        ),
        ChangelogItem(
          icon: Icons.shield_rounded,
          title: 'Detecção de Contraindicações & 1-Toque Protetor',
          description:
              'Cruzamento automático de exercícios prescritos com a integridade biomecânica do aluno e substituição de risco com um único toque.',
          badge: 'SEGURANÇA',
          targetRoles: ['trainer'],
        ),
        ChangelogItem(
          icon: Icons.verified_user_rounded,
          title: 'Fichas 100% Protegidas Contra Lesões',
          description:
              'Periodizações biomecanicamente blindadas com respeito absoluto às dores articulares e orientações cinesiológicas claras.',
          badge: 'BIOMECÂNICA',
          targetRoles: ['student'],
        ),
        ChangelogItem(
          icon: Icons.fitness_center_rounded,
          title: 'Orientações Cinesiológicas & Alavancas Seguras',
          description:
              'Detalhamento de vetores de proteção articular nos exercícios para executar séries com máxima segurança e sem impacto.',
          badge: 'BEM-ESTAR',
          targetRoles: ['student'],
        ),
        ChangelogItem(
          icon: Icons.biotech_rounded,
          title: 'Motor Cinesiológico Determinístico O(1)',
          description:
              'Base de conhecimento cinesiológico de alta performance com custo zero de tokens e auditoria permanente de segurança biomecânica.',
          badge: 'MOTOR 4.0',
          targetRoles: ['admin'],
        ),
      ],
    ),

    // ==========================================
    // v1.14.0 - MOTOR WHATSAPP AI 3.0 & COPILOTO CONVERSACIONAL ATIVO
    // ==========================================
    VersionRelease(
      version: '1.14.0',
      buildNumber: 2026110604,
      date: '7 de Novembro, 2026',
      summary:
          'Versão 1.14.0: Motor WhatsApp AI 3.0 & Copiloto Conversacional Ativo (Check-in pós-treino com RPE 1-10 e triagem articular em tempo real, Resumo Semanal Executivo com Recordes de Carga (PRs) e Triagem Multimodal de Aparelho Ocupado).',
      highlights: [
        ChangelogItem(
          icon: Icons.chat_rounded,
          title: 'Motor WhatsApp AI 3.0 & Check-in Ativo',
          description:
              'Automação de check-in pós-treino no WhatsApp com cálculo imediato de PSE/RPE e alertas instantâneos de dor para o treinador.',
          badge: 'IA 3.0',
          targetRoles: ['trainer'],
        ),
        ChangelogItem(
          icon: Icons.emoji_events_rounded,
          title: 'Resumo Executivo com Recordes (PRs)',
          description:
              'Cálculo e notificação de recordes pessoais de carga batidos na semana pelos alunos enviados diretamente para o WhatsApp do personal.',
          badge: 'DESTAQUE',
          targetRoles: ['trainer'],
        ),
        ChangelogItem(
          icon: Icons.swap_horiz_rounded,
          title: 'Triagem Multimodal & Troca de Aparelho',
          description:
              'Suporte a mensagens de texto ou áudios na academia com recomendação biomecânica inteligente de aparelhos equivalentes e confirmação em 1 toque.',
          badge: 'BIOMECÂNICA',
          targetRoles: ['student'],
        ),
        ChangelogItem(
          icon: Icons.mark_chat_read_rounded,
          title: 'Interação Pós-Treino Direto no WhatsApp',
          description:
              'Questionário interativo e ágil enviado ao encerrar o treino para registrar percepção de esforço e recuperar feedback sem atrito.',
          badge: 'NOVO',
          targetRoles: ['student'],
        ),
        ChangelogItem(
          icon: Icons.hub_rounded,
          title: 'Webhook WhatsApp Cloud API & Worker Resiliente',
          description:
              'Infraestrutura em nuvem resiliente com processamento assíncrono de mensagens, idempotência de eventos Meta e monitoramento de entrega.',
          badge: 'INFRA',
          targetRoles: ['admin'],
        ),
      ],
    ),

    // ==========================================
    // v1.13.9 - COCKPIT OPERACIONAL DO TREINADOR ZEN & RADAR ANTI-EVASÃO (UX B2B)
    // ==========================================
    VersionRelease(
      version: '1.13.9',
      buildNumber: 2026110603,
      date: '6 de Novembro, 2026',
      summary:
          'Versão 1.13.9: Cockpit Operacional do Treinador Zen (Resumo 24h, séries concluídas pelos alunos e alertas articulares em tempo real) & Radar Anti-Evasão com reengajamento 1-toque WhatsApp e trava anti-spam de 48h.',
      highlights: [
        ChangelogItem(
          icon: Icons.bolt_rounded,
          title: 'Cockpit Operacional · Últimas 24h',
          description:
              'Card executivo no topo da lista de alunos com telemetria em tempo real de séries concluídas e taxa de presença semanal da consultoria.',
          badge: 'NOVO',
          targetRoles: ['trainer'],
        ),
        ChangelogItem(
          icon: Icons.health_and_safety_rounded,
          title: 'Alertas Articulares em Tempo Real',
          description:
              'Desconfortos e adaptações biomecânicas reportados na academia em destaque com acesso em 1-toque aos detalhes da substituição de exercício.',
          badge: 'SAÚDE',
          targetRoles: ['trainer'],
        ),
        ChangelogItem(
          icon: Icons.radar_rounded,
          title: 'Radar Anti-Evasão 1-Toque WhatsApp',
          description:
              'Detecção proativa de alunos ausentes (>4 dias sem treinar) com envio de mensagem de incentivo contextualizada por IA e trava anti-spam de 48h.',
          badge: 'RETENÇÃO',
          targetRoles: ['trainer'],
        ),
      ],
    ),

    // ==========================================
    // v1.13.8 - COCKPIT FINANCEIRO DO TREINADOR & EXTRATO DE SPLITS EM TEMPO REAL
    // ==========================================
    VersionRelease(
      version: '1.13.8',
      buildNumber: 2026110602,
      date: '6 de Novembro, 2026',
      summary:
          'Versão 1.13.8: Cockpit Financeiro do Treinador com Extrato de Splits Asaas em Tempo Real, filtros analíticos (Liquidados 95%, Compensação, Estornos), comprovação fiscal de não bitributação e auditoria digital de assinaturas JWS (Resolução BCB nº 4.893).',
      highlights: [
        ChangelogItem(
          icon: Icons.dashboard_customize_rounded,
          title: 'Cockpit Financeiro de Splits em Tempo Real',
          description:
              'Visualização consolidada de saldos liberados vs. em compensação, faturamento mensal 95% líquido e extrato transparente de cada transação de aluno.',
          badge: 'NOVO',
          targetRoles: ['trainer'],
        ),
        ChangelogItem(
          icon: Icons.receipt_long_rounded,
          title: 'Comprovante Fiscal de Split & Auditoria JWS',
          description:
              'Modal institucional detalhando o repasse de 95%, retenção operacional de 5%, ID da conciliação bancária Asaas e assinatura digital RFC 7515.',
          badge: 'SEGURANÇA',
          targetRoles: ['trainer', 'admin'],
        ),
        ChangelogItem(
          icon: Icons.filter_alt_rounded,
          title: 'Filtros Rápidos de Extrato Bancário',
          description:
              'Abas dinâmicas para consultar rapidamente transações liquidadas, repasses pendentes e estornos.',
          badge: 'MELHORIA',
          targetRoles: ['trainer'],
        ),
      ],
    ),

    // ==========================================
    // v1.13.7 - MOTOR FINTECH: SPLIT ASAAS (95/5) & CONFORMIDADE BCB 4.893
    // ==========================================
    VersionRelease(
      version: '1.13.7',
      buildNumber: 2026110601,
      date: '6 de Novembro, 2026',
      summary:
          'Versão 1.13.7: Implementação do Motor Fintech de Split Payment Asaas (95% para o Personal Trainer / 5% da Plataforma) e Conformidade Estrita com a Resolução BCB nº 4.893 com assinaturas digitais JWS (RFC 7515), mTLS readiness e Trilha de Auditoria Criptográfica Imutável.',
      highlights: [
        ChangelogItem(
          icon: Icons.payments_rounded,
          title: 'Split de Pagamento Asaas Automatizado (95% Líquido)',
          description:
              'Contratações na vitrine pública são liquidadas com divisão automática: 95% creditados na subconta do personal e 5% na plataforma.',
          badge: 'NOVO',
          targetRoles: ['trainer'],
        ),
        ChangelogItem(
          icon: Icons.shield_rounded,
          title: 'Blindagem Fiscal & Segregação Bancária',
          description:
              'Eliminação da bitributação: os valores dos alunos não transitam pela conta da holding, protegendo o personal e o SaaS.',
          badge: 'SEGURANÇA',
          targetRoles: ['trainer'],
        ),
        ChangelogItem(
          icon: Icons.qr_code_2_rounded,
          title: 'Checkout Pix Transparente com QR Code Regulado',
          description:
              'Geração instantânea de Pix Copia e Cola no padrão EMV do Banco Central com confirmação e liberação em tempo real.',
          badge: 'MELHORIA',
          targetRoles: ['student'],
        ),
        ChangelogItem(
          icon: Icons.verified_user_rounded,
          title: 'Assinatura JWS (RFC 7515) & Trilha BCB nº 4.893',
          description:
              'Comandos de split protegidos com autenticidade matemática inquebrável, encadeamento de hashes SHA-256 e suporte mTLS.',
          badge: 'INFRA',
          targetRoles: ['admin'],
        ),
      ],
    ),

    // ==========================================
    // v1.13.6 - BIOMETRIA 1 TOQUE NO PWA & DEFINIÇÃO DE SENHA DIRETA
    // ==========================================
    VersionRelease(
      version: '1.13.6',
      buildNumber: 2026110504,
      date: '5 de Novembro, 2026',
      summary:
          'Versão 1.13.6: Restauração da credencial de biometria (1 toque) em PWAs no iOS/Android após login via WhatsApp e nova funcionalidade de Definir / Trocar Senha no Perfil do Aluno.',
      highlights: [
        ChangelogItem(
          icon: Icons.fingerprint_rounded,
          title: 'Retorno com Biometria Ativo no PWA',
          description:
              'Acesso instantâneo em 1 toque (Face ID / Touch ID) agora preservado mesmo após login por WhatsApp no navegador ou PWA.',
          badge: 'NOVO',
          targetRoles: ['student'],
        ),
        ChangelogItem(
          icon: Icons.lock_reset_rounded,
          title: 'Definição Direta de Senha no Perfil',
          description:
              'Alunos agora podem criar uma senha fixa diretamente nas configurações de perfil para entrar sem depender de códigos no WhatsApp.',
          badge: 'NOVO',
          targetRoles: ['student'],
        ),
        ChangelogItem(
          icon: Icons.badge_rounded,
          title: 'Autenticação Rápida de Treinador sem Código',
          description:
              'Sessões de treinadores utilizam credenciais seguras locais para entrada instantânea na consultoria.',
          badge: 'ESTABILIDADE',
          targetRoles: ['trainer'],
        ),
        ChangelogItem(
          icon: Icons.security_rounded,
          title: 'Blindagem de Senhas Fixas de Treinadores',
          description:
              'Proteção da senha permanente do personal contra sobrescritas temporárias em sessões simultâneas.',
          badge: 'SEGURANÇA',
          targetRoles: ['trainer'],
        ),
        ChangelogItem(
          icon: Icons.admin_panel_settings_rounded,
          title: 'Persistência WebCrypto de Credenciais PWA',
          description:
              'Armazenamento seguro de sessão via WebCrypto isolado por sandbox contra perdas de contexto de reentrada.',
          badge: 'INFRA',
          targetRoles: ['admin'],
        ),
      ],
    ),

    // ==========================================
    // v1.13.5 - RESILIÊNCIA DE RECUPERAÇÃO DE ACESSO & OTP WHATSAPP
    // ==========================================
    VersionRelease(
      version: '1.13.5',
      buildNumber: 2026110503,
      date: '5 de Novembro, 2026',
      summary:
          'Versão 1.13.5: Melhoria no fluxo de recuperação de acesso com atalho "Já recebi o código de 6 dígitos" e aumento do tempo de resposta para 40s contra falsos timeouts no envio de WhatsApp.',
      highlights: [
        ChangelogItem(
          icon: Icons.key_rounded,
          title: 'Atalho Direto para Digitar o Código OTP',
          description:
              'Caso o código do WhatsApp chegue com leve atraso ou você já possua os 6 dígitos, toque no atalho "Já recebi o código" para digitar e redefinir sua senha sem precisar reenviar.',
          badge: 'NOVO',
          targetRoles: ['student'],
        ),
        ChangelogItem(
          icon: Icons.timer_outlined,
          title: 'Tolerância Estendida de Envio WhatsApp no Aluno',
          description:
              'Eliminação de erros de timeout causados pelo tempo de processamento assíncrono da API de mensagens no acesso de alunos.',
          badge: 'ESTABILIDADE',
          targetRoles: ['student'],
        ),
        ChangelogItem(
          icon: Icons.mark_chat_read_rounded,
          title: 'Resiliência de Recuperação para Treinadores',
          description:
              'Fluxo de recuperação por WhatsApp otimizado com tempo de resposta estendido para conexões com instabilidade.',
          badge: 'ESTABILIDADE',
          targetRoles: ['trainer'],
        ),
        ChangelogItem(
          icon: Icons.security_rounded,
          title: 'Segurança e Confirmação de OTP do Personal',
          description:
              'Redefinição protegida por chave temporária com validação automática de credencial ativa.',
          badge: 'SEGURANÇA',
          targetRoles: ['trainer'],
        ),
        ChangelogItem(
          icon: Icons.admin_panel_settings_rounded,
          title: 'Blindagem de Timeouts em Rotas MFA e Recovery',
          description:
              'Timeouts unificados para 40 segundos em todas as rotas de verificação em duas etapas e recuperação de senha.',
          badge: 'INFRA',
          targetRoles: ['admin'],
        ),
      ],
    ),

    // ==========================================
    // v1.13.4 - ISOLAMENTO MODO ESPELHO & FIM DE REDUNDÂNCIAS EM DEGUSTAÇÃO
    // ==========================================
    VersionRelease(
      version: '1.13.4',
      buildNumber: 2026110502,
      date: '5 de Novembro, 2026',
      summary:
          'Versão 1.13.4: Correção do vazamento de banner no retorno do Modo Espelho/Admin para o painel do professor, eliminação de toasts redundantes em trocas de aba no modo degustação e refinamento dos estados vazios.',
      highlights: [
        ChangelogItem(
          icon: Icons.cleaning_services_rounded,
          title: 'Fim das Notificações Redundantes em Degustação',
          description:
              'Eliminação de avisos flutuantes invasivos a cada troca de aba. A vinculação ao personal agora é exibida de forma elegante e contextual na ficha e no perfil.',
          badge: 'MELHORIA',
          targetRoles: ['student'],
        ),
        ChangelogItem(
          icon: Icons.fitness_center_rounded,
          title: 'Experiência Fluida de Ficha Vazia',
          description:
              'Eliminada a duplicação de banners e botões de conexão na tela inicial de treino sem ficha atribuída.',
          badge: 'MELHORIA',
          targetRoles: ['student'],
        ),
        ChangelogItem(
          icon: Icons.admin_panel_settings_rounded,
          title: 'Isolamento Estrito do Modo Espelho / Admin',
          description:
              'Ao retornar do Modo Espelho ou do Painel Admin para o painel do personal, a tela carrega limpa sem retenção de avisos ou badges de degustação de aluno.',
          badge: 'CORREÇÃO',
          targetRoles: ['trainer'],
        ),
        ChangelogItem(
          icon: Icons.verified_user_rounded,
          title: 'Reconhecimento Nativo de Perfil do Professor',
          description:
              'Identificação imediata de contas de treinadores e diretores para blindar o ambiente contra falsos alertas de ausência de personal.',
          badge: 'SEGURANÇA',
          targetRoles: ['trainer'],
        ),
        ChangelogItem(
          icon: Icons.layers_clear_rounded,
          title: 'Limpeza de Overlays Órfãos em Trocas de Contexto',
          description:
              'Descarte automático de notificações temporárias globais ao transitar entre visões executivas e operacionais.',
          badge: 'INFRA',
          targetRoles: ['admin'],
        ),
      ],
    ),

    // ==========================================
    // v1.13.3 - PONTE DIRETA WHATSAPP ALUNO ↔ PERSONAL & CORREÇÃO iOS PWA
    // ==========================================
    VersionRelease(
      version: '1.13.3',
      buildNumber: 2026110501,
      date: '5 de Novembro, 2026',
      summary:
          'Versão 1.13.3: Nova Central de Contato Rápido Aluno ↔ Personal com envio direto em 1 toque de dentro do app (sem sair do treino), atalhos inteligentes de assunto e abertura nativa do WhatsApp no iOS/Android PWA sem tela branca.',
      highlights: [
        ChangelogItem(
          icon: Icons.send_rounded,
          title: 'Ponte Direta WhatsApp — Envie sem sair do App',
          description:
              'Toque em "Falar no WhatsApp (24h)" em qualquer aba (Treino, Mr. Coach AI, Bio-Hub ou Perfil) para disparar sua mensagem direto para o WhatsApp do seu professor em 1 toque, sem precisar sair do treino.',
          badge: 'NOVO',
          targetRoles: ['student'],
        ),
        ChangelogItem(
          icon: Icons.phone_iphone_rounded,
          title: 'Abertura Nativa Instantânea no iPhone (iOS PWA)',
          description:
              'Eliminada a tela branca ("OK") ao abrir o app do WhatsApp no iPhone: agora o protocolo nativo aciona o aplicativo instalado diretamente ou oferece cópia em 1 toque.',
          badge: 'CORREÇÃO',
          targetRoles: ['student'],
        ),
        ChangelogItem(
          icon: Icons.bolt_rounded,
          title: 'Recebimento Integrado no WhatsApp & Live Student Pulse',
          description:
              'Mensagens enviadas pelos alunos pela Ponte Direta chegam instantaneamente no seu WhatsApp formatadas com o contexto do treino e ficam registradas no pulso ao vivo do aluno.',
          badge: 'CONSULTORIA',
          targetRoles: ['trainer'],
        ),
        ChangelogItem(
          icon: Icons.mark_chat_read_rounded,
          title: 'Notificação Direta e Contextualizada da Célula de Treino',
          description:
              'Identifique instantaneamente qual exercício ou dor motivou o contato do aluno, agilizando orientações e respostas em menos de 1 minuto.',
          badge: 'RETENÇÃO',
          targetRoles: ['trainer'],
        ),
        ChangelogItem(
          icon: Icons.security_rounded,
          title: 'Blindagem Multi-Domínio (shaipados.com & shapelab.ia.br)',
          description:
              'Autenticação biométrica WebAuthn e rota bidirecional WhatsApp Direct habilitadas para alunos e treinadores com CORS dinâmico.',
          badge: 'INFRA',
          targetRoles: ['admin'],
        ),
      ],
    ),

    // ==========================================
    // v1.13.2 - ABA TREINO & FOCUS COCKPIT 3.2 (ALUNO)
    // ==========================================
    VersionRelease(
      version: '1.13.2',
      buildNumber: 2026110409,
      date: '4 de Novembro, 2026',
      summary:
          'Versão 1.13.2: Modernização da Aba Treino e tela Iniciar Treino de Hoje (Zen 3.2). Eliminação da duplicação entre Bento e Hero (ganho de 115px), ofensiva no Smart Header, Dynamic Island no scroll da lista, Smart Action Thumb-Bar (conclusão de séries com 1 toque no polegar) e Smart Overload no topo.',
      highlights: [
        // --- ALUNO & TREINO ---
        ChangelogItem(
          icon: Icons.fitness_center_rounded,
          title: 'Aba Treino Zen 3.2 — Hero Cockpit sem Redundâncias',
          description:
              'Ofensiva unificada no Smart Header, eliminação do Bento duplicado com ganho de 115px verticais acima da dobra e aquecimento guiado integrado no topo do Hero card.',
          badge: 'NOVO',
          targetRoles: ['student'],
        ),
        ChangelogItem(
          icon: Icons.layers_outlined,
          title: 'Dynamic Island & Auto-Hide na Lista de Exercícios',
          description:
              'Ao rolar os exercícios, a barra inferior recolhe suavemente e o topo vira a Dynamic Island com progresso e botão de continuar rápido.',
          badge: 'NOVO',
          targetRoles: ['student'],
        ),
        ChangelogItem(
          icon: Icons.touch_app_rounded,
          title: 'Iniciar Treino de Hoje — Smart Action Thumb-Bar',
          description:
              'Botão inferior ergonômico no polegar para concluir séries sucessivas com 1 toque, alternando automaticamente para "Próximo Exercício" ao finalizar todas as séries.',
          badge: 'NOVO',
          targetRoles: ['student'],
        ),
        ChangelogItem(
          icon: Icons.auto_awesome_rounded,
          title: 'Smart Overload IA no Topo das Séries',
          description:
              'Sugestão inteligente de progressão de carga reposicionada logo acima da tabela de séries, com aplicação em 1 toque, spotlight na série ativa e notas colapsáveis.',
          badge: 'NOVO',
          targetRoles: ['student'],
        ),

        // --- PROFESSOR / TREINADOR ---
        ChangelogItem(
          icon: Icons.insights_rounded,
          title: 'Telemetria de Cargas & Recordes Pessoais do Aluno em Tempo Real',
          description:
              'Visualização imediata das cargas executadas e PRs alcançados durante os treinos dos alunos sem necessidade de sincronização manual.',
          badge: 'CONSULTORIA',
          targetRoles: ['trainer'],
        ),
        ChangelogItem(
          icon: Icons.shield_rounded,
          title: 'Preservação de Integridade da Ficha Prescrita',
          description:
              'O aluno executa substituições biomecânicas pontuais no salão sem alterar o mesociclo original desenhado pelo personal.',
          badge: 'RETENÇÃO',
          targetRoles: ['trainer'],
        ),

        // --- ADMIN / INFRAESTRUTURA ---
        ChangelogItem(
          icon: Icons.verified_rounded,
          title: 'Build Stamp 2026110409 & Suíte de Testes Zen 3.2',
          description:
              'Incremento contínuo de build PWA com cache-busting rigoroso e suíte automatizada de testes do Focus Mode e Smart Action Thumb-Bar.',
          badge: 'ESTABILIDADE',
          targetRoles: ['admin'],
        ),
      ],
    ),
    // ==========================================
    // v1.13.0 - MR. COACH AI 3.0 (COPILOTO DO ALUNO) & BIO-HUB 3.0
    // ==========================================
    VersionRelease(
      version: '1.13.1',
      buildNumber: 2026110408,
      date: '4 de Novembro, 2026',
      summary:
          'Versão 1.13.1: Mr. Coach AI Aluno Zen 3.1 com rolagem ultra fluida, auto-hide da barra de navegação e Dynamic Island no topo, aposentadoria de redundâncias da versão anterior, 2 cápsulas slim (Senti Dor e Carga & RIR) e acordeão inteligente no Cockpit.',
      highlights: [
        // --- ALUNO & TREINO ---
        ChangelogItem(
          icon: Icons.auto_awesome_rounded,
          title: 'Mr. Coach AI Zen 3.1 — Rolagem Fluida & Auto-Hide Imersivo',
          description:
              'Ao rolar a tela do treino, o menu inferior e barras secundárias se recolhem suavemente em um Mini-Composer e Dynamic Island, reaparecendo instantaneamente ao rolar para cima ou tocar para digitar.',
          badge: 'NOVO',
          targetRoles: ['student'],
        ),
        ChangelogItem(
          icon: Icons.cleaning_services_rounded,
          title: 'Fim das Redundâncias & Cápsulas Slim 2-em-1',
          description:
              'Aposentamos a grade 2x2 e botões duplicados da versão anterior. Agora você tem acesso direto a "Senti Dor" e "Carga & RIR" em cápsulas compactas de alta precisão.',
          badge: 'MELHORIA',
          targetRoles: ['student'],
        ),
        ChangelogItem(
          icon: Icons.swap_horiz_rounded,
          title: 'Cockpit de Salão com Acordeão Inteligente & Swap em 1 Toque',
          description:
              'Veja os exercícios da sua série logo ao abrir a aba, consulte execução 3D em 5 segundos ou troque aparelhos ocupados em 1 toque sem alterar sua ficha oficial.',
          badge: 'NOVO',
          targetRoles: ['student'],
        ),
        ChangelogItem(
          icon: Icons.biotech_rounded,
          title: 'Bio-Hub 3.0 — Bio-Battery & Sobrecarga Compacta com Top PRs',
          description:
              'Prontidão diária em 1 toque e histórico de sobrecarga reorganizado com filtros rápidos, Top 2 recordes em destaque e linhas compactas sem rolagem excessiva.',
          badge: 'DESIGN',
          targetRoles: ['student'],
        ),
        ChangelogItem(
          icon: Icons.health_and_safety_rounded,
          title: 'Guardrail Clínico Instantâneo & Espelho Omnichannel WhatsApp',
          description:
              'Proteção articular imediata ao relatar dor ou fisgada e sincronização em tempo real das adaptações do dia entre o App e o Robô do WhatsApp.',
          badge: 'SEGURANÇA',
          targetRoles: ['student'],
        ),

        // --- PROFESSOR / TREINADOR ---
        ChangelogItem(
          icon: Icons.workspace_premium_rounded,
          title: 'Governança Inteligente por Plano B2B no Copiloto do Aluno',
          description:
              'Modo Copiloto IA 24/7 para planos Pro/Elite/Studio e Modo Essencial Determinístico (\$0 tokens) para o plano Starter com gatilho de upgrade integrado.',
          badge: 'FINOPS',
          targetRoles: ['trainer'],
        ),
        ChangelogItem(
          icon: Icons.radar_rounded,
          title: 'Rastreamento de Adaptações de Salão no Radar',
          description:
              'Toda substituição de aparelho ocupado feita pelo aluno no App ou no WhatsApp é gravada em adaptation_logs mantendo o mesociclo original intacto.',
          badge: 'RETENÇÃO',
          targetRoles: ['trainer'],
        ),

        // --- ADMIN / INFRAESTRUTURA ---
        ChangelogItem(
          icon: Icons.verified_rounded,
          title: 'Build Stamp Monotônico PWA & Suíte Interativa de Testes',
          description:
              'Correção definitiva do incremento sequencial de builds diários no deploy web para invalidação imediata de Service Worker em iOS, Android e Desktop.',
          badge: 'ESTABILIDADE',
          targetRoles: ['admin'],
        ),
      ],
    ),
    // ==========================================
    // v1.11.3 - ABA SOCIAL & COMUNIDADE 2.0 (ROBÔ WA IN-APP)
    // ==========================================
    VersionRelease(
      version: '1.12.15',
      buildNumber: 2026103130,
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
