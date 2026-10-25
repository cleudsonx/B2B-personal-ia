# Proposta Executiva: **Mr. Coach AI 3.0 (Ecossistema Inteligente de Consultoria, Notificações & Omnichannel)**

> **Status:** Especificação de Produto e Engenharia  
> **Público:** Engenharia, Produto e Gestão B2B do Mr. Coach  
> **Objetivo:** Modernizar a aba **Mr. Coach AI** (Aluno e Treinador), integrar o sistema de notificações/atualizações com robô de atendimento contextual e estruturar o roteamento inteligente multicanal (Meta Cloud API + Push Local).

---

## 1. Visão Geral e Benchmarks de Mercado

Grandes plataformas de escala global (**WHOOP Coach, Peloton IQ, Intercom Fin AI, Nike Training Club e Nubank**) utilizam uma tríade essencial de arquitetura:
1. **RAG Contextual Pessoal**: A IA nunca pergunta o que ela já deveria saber (o robô sabe quem é o aluno, qual o split de hoje, histórico de cargas, anamnese e nome do professor).
2. **Generative UI / Action Cards**: Respostas não são blocos de texto puro; entregam cartões interativos acionáveis em 1 toque (iniciar treino, registrar água, substituir aparelho).
3. **Roteamento Inteligente Multicanal (Smart Channel Routing)**: Notificações de alta frequência e hábitos rodam a **custo zero** dentro do app; disparos de alto impacto comercial (ficha nova, cobrança, radar de inatividade) usam a **API Oficial do WhatsApp**.

---

## 2. A Aba Mr. Coach AI do Aluno (Interface & Usabilidade)

A tela do aluno passa a operar em 3 zonas perfeitamente integradas no padrão **One UI / Glassmorphism**:

### Zona 1 — Topo: Identidade da Consultoria & Pulse de Avisos
- **Card do Personal**: Foto, nome, CREF e status da planilha ativa (*"Hipertrofia A/B/C/D • Atualizada há 3 dias"*).
- **Central Unificada de Notificações & Versão**:
  - Pílula retrátil que combina:
    - Avisos da consultoria (*"Seu professor ajustou as cargas do Supino"*, *"Faltam 500ml de água para sua meta"*).
    - Novidades da versão (*"Novidades v1.4"* com os 3 pontos-chave sem poluir a interface).

### Zona 2 — Centro: Robô da Consultoria (IA com RAG em 2 Camadas)
- **Camada 1 (Zero-Token Triage - Custo R$ 0,00)**:
  - *"Qual meu treino de hoje?"* → Responde na hora com a divisão do dia e botão `[Ir para o Treino]`.
  - *"Quantos dias de ofensiva eu tenho?"* → Consulta o Streak e exibe card comemorativo.
  - *"Quero registrar água"* → Registra +250ml ou +500ml direto no balão com 1 toque.
- **Camada 2 (Gemini 2.5 Flash-Lite com RAG da Ficha e Anamnese)**:
  - *"O banco de supino inclinado está ocupado, o que faço?"* → A IA analisa a ficha, localiza o grupo muscular e sugere substituto biomecânico equivalente (ex.: Supino com Halteres ou Peck Deck ajustado), oferecendo o botão `[Substituir no Treino de Hoje]`.
  - *"Sinto desconforto no ombro direito durante o treino"* → Responde orientando não forçar, recomenda correção postural e gera automaticamente um **Alerta Prioritário de Dor** no radar do professor.

### Zona 3 — Rodapé: Chips Inteligentes Dinâmicos
Chips contextuais que mudam conforme a rotina do aluno:
- **Antes do treino**: `📋 Ver divisão de hoje`, `🔄 Aparelho ocupado`, `💧 +250ml Água`.
- **Durante o treino (séries parciais salvas)**: `▶️ Retomar Treino A de onde parei`, `📐 Postura no exercício atual`.
- **Após o treino concluído**: `🏆 Ver volume de carga hoje`, `📩 Deixar feedback ao treinador`.

---

## 3. A Central do Treinador (Copiloto Executivo da Carteira)

Para o Personal Trainer, o Mr. Coach AI deixa de ser um chat genérico e se transforma em um **painel vivo de monitoramento contínuo da carteira**:

1. **Feed ao Vivo dos Alunos (Live Student Pulse)**:
   - 🟢 **Treinos Concluídos**: *"Rafael AC concluiu o Treino A (32 min • 4.200 kg de volume)"*.
   - 🟡 **Dúvidas Resolvidas pelo Robô**: *"O robô atendeu Mariana e adaptou Supino Reto por Halteres (aparelho ocupado)"*.
   - 🔴 **Atenção Prioritária**: *"Pedro relatou dor no joelho no Leg Press"*, *"Lucas está há 5 dias sem treinar"*.
2. **Ações Executivas de 1 Toque**:
   - `[Cobrar Check-in via WhatsApp]`, `[Elogiar Ofensiva/PR]`, `[Gerar Nova Ficha com IA]`.
3. **Consultas em Linguagem Natural sobre a Carteira**:
   - O professor pode perguntar: *"Quem são os 3 alunos com menor frequência esta semana?"* ou *"Crie uma mensagem acolhedora para quem está ausente há mais de 4 dias"*.

---

## 4. Arquitetura Multicanal & Economia WhatsApp (Meta Cloud API vs Push)

### Matriz de Roteamento de Mensagens

| Tipo de Mensagem | Canal Principal | Regra de Custo Meta | Custo para o Mr. Coach |
| :--- | :--- | :--- | :--- |
| **Dúvidas do Aluno / Consulta de Treino** | WhatsApp ou Aba Mr. Coach AI | Mensagem iniciada pelo aluno (Janela de 24h aberta) | **R$ 0,00 (Grátis)** |
| **Nova Ficha Liberada pelo Treinador** | WhatsApp (Meta Cloud API) + Push App | Se aluno interagiu em 24h = Grátis; se fechada = Template Utilidade | **R$ 0,00 a R$ 0,04** por envio |
| **Cobrança de Mensalidade / Renovação** | WhatsApp (Meta Cloud API) | Template de Utilidade | **~R$ 0,04** (Altíssimo ROI) |
| **Radar de Retenção (Aluno ausente >4 dias)** | WhatsApp com trava anti-spam de 48h | Template de Utilidade | **~R$ 0,04** |
| **Lembretes de Hábito (Beba Água, Timer, Streak)** | **Aba Mr. Coach AI & Notificações Push** | Canal interno do App (Web/PWA/Mobile) | **R$ 0,00 (Ilimitado)** |

### Ganhos da Meta Cloud API Oficial:
- **Disponibilidade 99,99%**: Sem dependência de emulação Baileys/QR Code para a instância central.
- **Risco Zero de Banimento**: Tráfego oficial homologado pela Meta.
- **Botões Nativos**: O aluno recebe botões clicáveis no WhatsApp (`[Ver Treino]`, `[Ofensiva]`), dispensando digitação manual.

---

## 5. Roteiro de Implementação Técnica (Fases)

### Fase 1: Interface & Central Unificada da Aba Mr. Coach AI (Aluno)
- Reestruturação visual no padrão One UI com **Header da Consultoria**, **Pulse de Notificações/Versão** e **Action Cards**.
- Injeção das notificações locais (`StudentNotificationService`) dentro do feed da IA.

### Fase 2: Motor RAG da Consultoria no App
- Conexão do robô aos dados do aluno no Supabase (`active_workout`, `profiles`, `streak_days`, `anamnesis`, `bio_hub_metrics`).
- Triagem local determinística (0 tokens) para intenções frequentes + prompt enxuto Gemini 2.5 Flash-Lite para adaptações biomecânicas.

### Fase 3: Cockpit de Monitoramento Contínuo do Treinador
- Criação do feed em tempo real de eventos dos alunos (`workout_sessions`, `adaptation_logs`).
- Assistente executivo com consultas da carteira em linguagem natural e ações de 1 toque.

### Fase 4: Integração de Provedor Meta Cloud API no Backend
- Adição do provider `meta_cloud` em [`whatsapp_service.py`](file:///c:/Users/Cleudson/OneDrive/Documentos/PROJETOS%202026/B2B-personal-ia/backend/app/services/whatsapp_service.py) para disparos oficiais de alta confiabilidade.
