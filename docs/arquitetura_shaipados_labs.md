# 🏭 Shaipados Labs - Venture Builder Blueprint & Arquitetura

Este documento serve como o **Playbook Oficial** e o registro de inteligência do ecossistema *Shaipados Labs*. Ele garante que qualquer agente de IA ou desenvolvedor humano no futuro compreenda a infraestrutura, o padrão de design e a mentalidade de engenharia por trás da nossa Fábrica de Software.

---

## 1. Visão Geral do Ecossistema (A Virada de Chave)
Saímos de um modelo "Single-App" (apenas o Mr. Coach) para um modelo **Venture Builder / Software Studio**. 
A Shaipados Labs é a matriz que constrói, lança e escala múltiplos produtos SaaS (Software as a Service) B2B e B2C, operando de forma ultra-enxuta através de esquadrões de Inteligência Artificial.

---

## 2. Padrão Arquitetural: Monorepo + Domain-Aware Routing
Para manter o custo de DevOps e manutenção próximo a zero, utilizamos um modelo de **Monorepo no Flutter Web**. Todos os produtos coexistem no mesmo código-fonte, mas são servidos dinamicamente baseados na URL que o usuário digita.

### 2.1. Regras de Domínio (O Roteador)
O ponto de entrada (main.dart) atua como um Proxy Reverso / Roteador de Aplicação usando Uri.base.host:
*   **shaipados.com (A Matriz):** Renderiza a Vitrine da Fábrica de Software (shaipados_studio_screen.dart). 
*   **[nome-do-produto].shaipados.com (As Landing Pages):** Renderiza a página de vendas específica de um produto. Exemplo atual: mrcoach.shaipados.com.
*   **pp.shaipados.com (O Ecossistema Interno):** Centraliza a Autenticação (Single Sign-On - SSO). É o portal de entrada para o sistema, onde a UI se adapta dependendo de qual produto o usuário comprou.

### 2.2. Como Lançar Novos Produtos no Futuro?
1. Desenhe a nova tela em eatures/landing/[novo_produto]_landing_screen.dart.
2. Adicione **2 linhas** no main.dart:
   `dart
   else if (host.contains('novoproduto')) {
     return const NovoProdutoLandingScreen();
   }
   `
3. Aponte o subdomínio no DNS para o mesmo servidor de hospedagem. Pronto, o produto está no ar.

---

## 3. Padrões de Design (UI/UX)
Dividimos nossa linguagem visual em duas frentes para maximizar a conversão e a usabilidade:

### 3.1. Front-end Corporativo (A Matriz - shaipados.com)
*   **Estilo:** Bento Grid (Caixas modulares interativas) + Dark Glassmorphism.
*   **Cores:** Ultra-dark (Fundos #09090B, Cards #18181B) com brilhos em Neon (ex: Verde Esmeralda #10B981).
*   **Objetivo:** Transmitir alta tecnologia, segurança B2B e atrair parceiros/investidores. Foco na prova social ao vivo ("Build in Public" com métricas em tempo real).

### 3.2. Front-end de Produtos (Ex: Mr. Coach / Apps)
*   **Estilo:** Google Material You (Bordas ultra arredondadas, flat design, elevação zero).
*   **Regra de Ouro:** *Edge-to-Edge* (Aplicação sangrando atrás das barras de navegação nativas do celular).
*   **Cores:** Tons pastéis suaves no Light Mode (Menta, Pêssego, Lavanda).
*   **Objetivo:** UX amigável, baixa fricção cognitiva e foco em "Product Led Growth" (PLG) — o design deve ser tão fácil que se vende sozinho.

---

## 4. O "Squad de Elite" (Agentes de Inteligência Artificial)
A Shaipados Labs não incha a folha de pagamento. Escalamos a produção utilizando Subagentes de IA especializados que atuam sob o comando do Tech Lead (Antigravity).

Sempre que iniciar uma nova fase, os agentes são instanciados (via invoke_subagent) com as seguintes personas:
1.  **Tech Lead / Arquiteto (Antigravity):** Orquestra a infraestrutura, aprova PRs, garante integração e gerencia o banco de dados.
2.  **Product Manager (Sarah):** Pensa na estratégia PLG, conversão de vendas e estruturar funis.
3.  **UI/UX (Mateus / Leo):** Focado obcecamente em Material You, Bento Grids e responsividade cross-platform.
4.  **Backend & DBA (Alan / Marta):** Responsáveis pela arquitetura do FastAPI e regras de segurança brutais no Supabase (RLS Policies e Joins otimizados).
5.  **QA (Thiago):** Garante a resiliência, validação de inputs, edge-cases de sessão e tratamento silencioso de erros.
6.  **Copywriter (Sofia):** Gera textos persuasivos e gatilhos virais (ex: Micro-copy de botões que aumentam cliques).

---

## 5. Mantras de Desenvolvimento
1.  **UTF-8 Sempre:** Todos os códigos são manipulados com proteção de encoding utf-8 para evitar quebra de caracteres (mojibake) em português (experiência prévia documentada em Outubro/2026).
2.  **Zero Warnings:** A pipeline CI/CD rejeita códigos com warnings (ex: imports não usados). O código deve rodar liso no lutter analyze.
3.  **No-Code Local:** Segredos e chaves de API nunca são commitados. Sempre dependemos do .env e de variáveis de ambiente injetadas no deploy (Supabase, Resend, Meta).

*(Documento gerado pela Inteligência Artificial da Google Deepmind durante a transformação arquitetural para Venture Builder - 2026).*
