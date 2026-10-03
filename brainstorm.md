# 🧠 Brainstorm & Roadmap (Mr. Coach / Shaipados)

Este arquivo serve como o repositório central de ideias, dúvidas de arquitetura, melhorias de UX/UI e estratégias de negócios. Sempre que uma nova ideia surgir, ela deve ser documentada aqui antes de virar código.

---

## 🎨 1. Arquivo de Design (Propostas Futuras)
*Decidimos seguir com a Proposta 2 (Google Material You - Limpo e Acessível) para o app principal. As propostas abaixo ficam guardadas como inspiração para projetos futuros ou módulos premium:*
*   **Proposta 4 (Material You Gamified):** Foco em anéis de retenção em tons pastel e contadores de ofensiva (streaks).
*   **Proposta 5 (Apple Spatial Fitness):** Fundo OLED, glassmorphism, tipografia SF Pro cinematográfica, foco em altíssima performance.

---

## 🔐 2. Fluxo de Autenticação do Aluno
*   **Origem do E-mail:** O e-mail do aluno idealmente é **real e funcional**. O personal cadastra o e-mail do aluno para enviar o convite, e o aluno usa esse e-mail para recuperar senhas e receber notificações.
*   **Sessão e Logout:** O aluno **pode** sair do app (Logout). Porém, após o primeiro login, o aplicativo usa um token seguro (persistência do Supabase) para manter a sessão ativa. **Ele não precisa fazer login toda vez que abre o app**, entra com apenas um clique.

---

## 🚀 3. Aquisição e Retenção de Personais (B2B)
*   **Onboarding do Professor:** Ao se cadastrar, o professor deve passar por um fluxo onde preenche foto, especialidades (ex: Hipertrofia, Emagrecimento), links das redes sociais e uma bio.
*   **Landing Page Pública:** Usar os dados do onboarding para gerar automaticamente uma página de vendas/captura (estilo Linktree) para o personal colocar na bio do Instagram.
*   **Arquitetura de Subdomínios:** Implementar roteamento dinâmico no frontend para que a landing page fique em um subdomínio amigável: `https://[nome-do-professor].shaipados.com`.

---

## 📢 4. Comunicação, Retenção e Alertas (E-mail e WhatsApp)
*   **Falha no Convite do Aluno:** Atualmente os alunos não estão recebendo o convite por e-mail. **Ação:** Revisar e melhorar o fluxo de disparo de e-mails, garantindo alta entregabilidade e um layout (HTML) profissional, atrativo e com as cores da marca.
*   **Branding do Personal (Falta o nome do Professor):** O nome do professor não está sendo apresentado ao aluno nem no e-mail de convite, nem dentro do aplicativo. **Ação:** Injetar o nome/foto do professor logado diretamente nas variáveis do e-mail e nos cabeçalhos/dashboard do app do aluno ("Seu treino com o Prof. João").
*   **Notificações Omnichannel:** Todas as comunicações, cobranças e alertas importantes para o aluno (ex: treino novo, vencimento de mensalidade, aluno sumido) não devem depender apenas do app. Devem ser engatilhadas e enviadas simultaneamente via **E-mail e WhatsApp** usando a API de disparo.

## ?? 5. Gamifica��o (Motor Backend)
*   **A��o:** Criar a l�gica matem�tica no Supabase para substituir os dados est�ticos (Mock) da interface Material You. Precisamos calcular e rastrear Ofensivas (Streaks em dias) e % de Conclus�o de Metas Di�rias.

## ?? 6. Automa��es Bidirecionais de WhatsApp
*   **A��o:** Construir gatilhos para que o sistema notifique ativamente o professor. Exemplo: Se o aluno trocar um exerc�cio pelo aplicativo, o Rob� envia um WhatsApp autom�tico para o Personal avisando da mudan�a.

