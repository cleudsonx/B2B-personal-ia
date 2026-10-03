# 📐 Especificação de UI/UX & Wireframe: Landing Page Conversão WhatsApp
**Design System**: Material You (Material 3 Expressivo) • Cores Pastéis Menta & Pêssego • Zero Sombras (Flat 1px Border) • Cantos Super Arredondados
**Lead UI/UX Designer**: Leo
**Projeto**: Mr. Coach (B2B Personal IA)

---

## 1. Visão Geral & Estratégia de Conversão

A Landing Page foi projetada com um único objetivo principal de alta conversão: **levar o Personal Trainer ou Dono de Consultoria Fitness diretamente para o WhatsApp comercial com zero fricção**.

### Pilares de Design (Material You Pastel)
1. **Paleta Pastel Orgânica**:
   - **Menta Primário** (`#98FF98` / `#A7F3D0` / `rgba(152, 255, 152, 0.15)`): Representa crescimento, tecnologia limpa, saúde e eficiência.
   - **Pêssego Acento** (`#FFDAB9` / `#FED7AA` / `rgba(255, 218, 185, 0.20)`): Traz calor humano, energia, acolhimento e urgência suave sem agressividade visual.
   - **Superfícies**: Fundo Off-White Slate (`#F8FAFC`) no modo claro e Obsidian Slate (`#090D16`) no modo escuro.
2. **Zero Sombras (No Drop Shadows)**:
   - Eliminação de sombras pesadas (`elevation: 0`).
   - Profundidade obtida exclusivamente por **contornos sutis de 1px** (`#E2E8F0` no claro / `0x1FFFFFFF` no escuro) e sobreposição tonal suave (tintes de 4% a 12%).
3. **Cantos Arredondados Expressivos (Material 3)**:
   - Cards e containers estruturais: `BorderRadius.circular(24)` a `32`.
   - Botões de Ação e Badges: `BorderRadius.circular(100)` (Pill Shape completo).
4. **O "Mega Botão" do WhatsApp no Hero**:
   - Elemento focal dominante acima da dobra (*above the fold*).
   - Altura mínima de **72px** em desktop (64px em mobile), largura expandida, ícone estilizado do WhatsApp, micro-badge "Online agora • Resposta em 2 min" e texto de alta intenção de clique.

---

## 2. Wireframe Estrutural (Layout Breakdown)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ 🟢 NAVBAR (Fixa / Glassmorphism Flat)                                      │
│  [Logo MR. COACH]   [Badges: IA Gemini 3.8]     [Modo Claro/Escuro] [CTA WA]│
├─────────────────────────────────────────────────────────────────────────────┤
│ 🚀 HERO SECTION (Ultra Foco em Conversão)                                  │
│                                                                             │
│      [Pill Tag: ⚡ Potencialize sua Consultoria Fitness com IA]             │
│                                                                             │
│          PRESCREVA TREINOS PERFEITOS EM 30 SEGUNDOS.                        │
│          SEUS ALUNOS NUNCA MAIS FICAM PERDIDOS NO SALÃO.                    │
│                                                                             │
│   A plataforma B2B que cria periodizações completas com Gemini 3.8 e adapta │
│   exercícios em tempo real quando o aparelho está ocupado ou há dor.        │
│                                                                             │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │  🟢  MEGA BOTÃO WHATSAPP (Hero CTA Gigante)                         │   │
│   │  [ Ícone WhatsApp ]  QUERO TESTAR GRÁTIS NO WHATSAPP  →             │   │
│   │  • Atendimento Humano Imediato  • Sem Cartão de Crédito             │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│   [ Micro-garantias:  🛡️ 100% Seguro  |  ⭐ 4.9/5 por 320+ Personals ]       │
├─────────────────────────────────────────────────────────────────────────────┤
│ 📊 SOCIAL PROOF METRICS STRIP                                              │
│   [+2.400 Treinos Criados] │ [30s Tempo Médio] │ [99.4% Satisfação] │ [3x Escala] │
├─────────────────────────────────────────────────────────────────────────────┤
│ 🍱 BENTO GRID: RECURSOS EXCLUSIVOS (Menta & Pêssego Pastel)                 │
│ ┌───────────────────────────────────┬─────────────────────────────────────┐ │
│ │ 🌿 Menta Pastel Card              │ 🍑 Pêssego Pastel Card              │ │
│ │ Prescrição Periodizada com IA     │ Botão "Aparelho Ocupado"            │ │
│ │ Divisões A/B/C automáticas e      │ Sugestão imediata com mesmo vetor   │ │
│ │ blindagem de lesões articulares.  │ biomecânico sem travar o treino.    │ │
│ ├───────────────────────────────────┼─────────────────────────────────────┤ │
│ │ 🍑 Pêssego Pastel Card            │ 🌿 Menta Pastel Card                │ │
│ │ Anamnese Clínica Inteligente      │ Painel B2B do Treinador             │ │
│ │ Histórico completo de restrições  │ Visão panorâmica de alunos, fichas  │ │
│ │ e objetivos em 1 clique.          │ ativas e métricas de evolução.      │ │
│ └───────────────────────────────────┴─────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────────────────────────┤
│ 🪜 COMO FUNCIONA (3 Passos Simples)                                         │
│   [1. Converse no WhatsApp]  →  [2. Configure seu Perfil]  →  [3. Escale Alunos]│
├─────────────────────────────────────────────────────────────────────────────┤
│ 💬 DEPOIMENTOS DE PERSONAL TRAINERS (Pills & Cards Arredondados)           │
│   "Dobrei minha carteira de alunos e gasto 80% menos tempo montando fichas."│
├─────────────────────────────────────────────────────────────────────────────┤
│ 🏷️ PLANOS & INVESTIMENTO (Com CTA direto no WhatsApp)                       │
│   [Starter Grátis]      [Personal Pro (Destaque)]      [Consultoria Elite]  │
│   [Chamar no WA]        [Garantir Desconto no WA]      [Falar com Consultor]│
├─────────────────────────────────────────────────────────────────────────────┤
│ ❓ FAQ ACORDEÃO (Perguntas Frequentes)                                      │
├─────────────────────────────────────────────────────────────────────────────┤
│ 🏁 FOOTER & DIREITOS                                                        │
└─────────────────────────────────────────────────────────────────────────────┘
  [ 🟢 FLOATING ACTION BUTTON WHATSAPP ] (Fixo no canto inferior direito)
```

---

## 3. Especificação do "Mega Botão" do WhatsApp (Hero)

### Dimensões & Anatomia
- **Largura**: Responsiva, até `580px` no desktop (100% da largura útil em mobile com padding lateral de 20px).
- **Altura / Espaçamento Interno**: `Padding: EdgeInsets.symmetric(horizontal: 28, vertical: 22)`.
- **Raio de Borda**: `BorderRadius.circular(100)` (Pill Shape generoso e suave).
- **Sem Sombras**: Flat com borda de 1.5px em tom Menta Vibrante (`#34D399` ou `#10B981` com opacidade 0.5) e fundo gradiente suave de Menta Pastel (`#E8FDF0` -> `#C1F5D0` no claro / `#064E3B` -> `#047857` no escuro).
- **Componentes Internos**:
  1. **Ícone do WhatsApp**: Container circular de 48px com ícone destacado de chat/WhatsApp em verde escuro ou branco.
  2. **Coluna de Texto**:
     - *Badge superior*: "DISPONÍVEL AGORA • RESPOSTA EM 2 MIN" (Letras maiúsculas, 10px, bold, tracking 1.0).
     - *Título de Ação*: "TESTAR MR. COACH NO WHATSAPP" (18px a 20px, extra bold, cor de alto contraste).
     - *Subtexto explicativo*: "Inicie seu teste gratuito em 1 clique • Sem compromisso" (12px, tom secundário).
  3. **Ícone de Flecha**: `Icons.arrow_forward_rounded` indicando ação imediata.

---

## 4. Design Tokens Material You

| Token | Modo Claro (Light) | Modo Escuro (Dark) | Aplicação |
|---|---|---|---|
| `bg` | `#F8FAFC` | `#090D16` | Fundo geral da página |
| `surface` | `#FFFFFF` | `#131B2E` | Cards e seções contidas |
| `border` | `#E2E8F0` (1px) | `0x1FFFFFFF` (1px) | Contornos sem sombra |
| `mint_primary` | `#98FF98` | `#34D399` | Destaques principais, IA, CTAs |
| `mint_bg` | `#E8FDF0` | `rgba(52, 211, 153, 0.15)`| Fundo de cards Menta |
| `peach_primary` | `#FFDAB9` | `#FB923C` | Acentos secundários, calor |
| `peach_bg` | `#FFF7ED` | `rgba(251, 146, 60, 0.15)` | Fundo de cards Pêssego |
| `text_primary` | `#0F172A` | `#F8FAFC` | Headings e títulos |
| `text_secondary` | `#64748B` | `#94A3B8` | Textos de apoio e descrições |
| `radius_pill` | `100px` | `100px` | Botões, badges, tags |
| `radius_card` | `24px - 32px` | `24px - 32px` | Cards do Bento Grid |

---

## 5. Implementação Técnica em Flutter Web
A tela `LandingPageScreen` implementará:
- **Edge-to-Edge nativo** com `AnnotatedRegion<SystemUiOverlayStyle>` dinâmico.
- **Scaffold direto**, sem `SafeArea` em volta do Scaffold inteiro.
- **SafeArea cirúrgico** na barra de navegação superior e no floating button.
- **Scroll fluido** com `MediaQuery.paddingOf(context).bottom` dinâmico para garantir que o rodapé e botões flutuantes nunca colidam com home indicators ou gestos de navegação.
- Link direto de abertura via `url_launcher` para:
  `https://wa.me/5511999999999?text=Ol%C3%A1%2C%20gostaria%20de%20testar%20a%20plataforma%20Mr.%20Coach%20IA!`
