# Design System: Mr. Coach (Inspirado no Meta/WhatsApp Business)

**Documento de Arquitetura Visual e Componentização**
Baseado no estudo profundo da interface (UI/UX) do ecossistema Meta, adaptado para a realidade B2B2C da plataforma Mr. Coach.

---

## 1. Mapeamento de Funcionalidades (Visão do Personal Trainer)

Para que o aplicativo seja tão intuitivo quanto o WhatsApp, replicaremos a arquitetura de abas e listas.

| Padrão Meta (WhatsApp) | Adaptação Mr. Coach (App do Treinador) | Descrição da Interface |
| :--- | :--- | :--- |
| **Aba "Conversas"** | **Aba "Alunos" (Dashboard)** | Lista de alunos ativos. Barra de pesquisa no topo (pílula). Cada aluno exibe Avatar, Nome, e "Última Atividade". |
| **Aba "Ligações"** | **Aba "Treinos"** | Ações rápidas no topo em círculos (Ex: "Criar Ficha"). Abaixo, a lista de "Fichas Recentes" modificadas. |
| **Aba "Atualizações"** | **Aba "Social / Ranking"** | Espaço estilo "Canais" para o professor ver os Streaks (ofensivas) dos alunos em destaque. |
| **Aba "Ferramentas"**| **Aba "Minha Vitrine"** | Cards horizontais no topo com dicas de negócio. Abaixo, links para editar a Landing Page pública e configurar IA. |

---

## 2. A Visão do Aluno (A Experiência no Salão de Musculação)

O Design System da Meta (Dark Mode de alto contraste e grandes alvos de toque) será **100% aplicado à visão do Aluno**. O benefício aqui não é apenas estético, mas ergonômico: fundos pretos não ofuscam a visão na academia, e botões "Squircle" gigantes evitam cliques errados com mãos suadas ou trêmulas durante o treino.

| Lógica Meta | Adaptação Mr. Coach (App do Aluno) |
| :--- | :--- |
| **Interface Flat/Sem Sombras** | A `active_workout_screen.dart` abandona cards complexos. Os exercícios são listados de forma reta e limpa, usando apenas o fundo Cinza Chumbo (`MetaColors.surfaceHighlight`) para separar do fundo preto absoluto. |
| **FAB Squircle Branco** | O botão de **"Finalizar Treino"** será o nosso icônico Squircle Branco no canto inferior. Impossível de ignorar, chamando a ação de gamificação. |
| **FAB Empilhado Menor** | O icônico **"Botão de Pânico (Aparelho Ocupado)"** ficará logo acima do finalizar, com formato circular e uma cor de alerta (Amarelo ou Azul), para acionar a IA de substituição biomecânica instantânea. |
| **Status/Gamificação** | O progresso do treino e as *Streaks* (Chamas de ofensiva) usam a linguagem de "Status" (barras de progresso segmentadas e arredondadas no topo da tela). |

---

## 3. Padrões de Componentes (O Segredo do Flutter)

### A. O FAB (Floating Action Button) de Alto Contraste
*   **FAB Principal:** Fomato **Squircle** (Rounded Rectangle, raio ~16px). Cor de fundo: `Branco Puro (#FFFFFF)`. Ícone: `Preto (#000000)`.
*   **FAB Secundário (Empilhado):** Formato **Circular** pequeno. Cor de fundo: `Cinza Chumbo (#1F2C34)`. Ícone colorido.

### B. Barra de Navegação Inferior (Material 3 NavigationBar)
*   Ausência total de sombras (`elevation: 0`).
*   Ícone ativo: Preenchido, circundado por um `Indicator` em formato de pílula.

### C. List Tiles (Itens de Lista)
*   **Zero Dividers:** Separação feita exclusivamente por `SizedBox(height: 16)`.
*   **Barra de Pesquisa:** Formato de pílula, sem elevação.

---

## 4. Paleta de Cores e Tipografia (Design Tokens)

*   **Background (Fundo Absoluto):** `#0B141A` (Preto AMOLED profundo)
*   **Surface (Barras, Cards, Search):** `#1F2C34` (Cinza Chumbo)
*   **Primary Action (FAB Principal):** `#FFFFFF` (Branco Puro)
*   **Primary Text:** `#E9EDEF` (Branco Suave)
*   **Secondary Text & Icons:** `#8696A0` (Cinza Azulado)

---

## 5. Extensão para Web e Marketing (Páginas de Captura & Site)
* **Bordas Arredondadas (Cards):** Substituir layouts engessados por "Floating Cards" minimalistas com `BorderRadius.circular(24)` e fundos cinza chumbo.
* **Limpeza Tipográfica e Correção UTF-8:** Foco absoluto em velocidade de leitura e conversão.

