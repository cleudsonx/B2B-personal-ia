# Proposta 01: Atualizações do aplicativo pelas lojas

**Status:** artefato de planejamento, ainda não implementado  
**Escopo:** distribuição e atualização do aplicativo Flutter em Android e iOS  
**Uso previsto:** referência para uma decisão e implementação futura; pode ser descartado após o uso.

## Objetivo

Permitir que usuários recebam novas versões do aplicativo com o mínimo de fricção, mantendo controle de qualidade, compatibilidade com o backend e conformidade com as regras de Google Play e App Store.

## Recomendação

Usar Google Play e App Store como canais oficiais de produção, com builds assinados e publicação automatizada em etapas. Complementar a distribuição com:

- Atualização automática gerenciada pelo sistema operacional, conforme as preferências do usuário.
- Verificação de versão no aplicativo, com aviso opcional e bloqueio apenas quando uma versão antiga não puder operar com segurança ou compatibilidade.
- Google Play In-App Updates no Android: fluxo flexível para atualizações comuns e fluxo imediato somente para incidentes críticos.
- TestFlight para validação de versões iOS antes da publicação.
- Lançamento gradual e monitoramento de falhas antes de concluir cada rollout.
- Compatibilidade do backend com as versões anteriores do app durante a janela de atualização.

Não se deve prometer instalação imediata e silenciosa em todos os dispositivos: o usuário, as configurações do aparelho, a disponibilidade das lojas e a revisão das plataformas influenciam quando a nova versão é instalada.

## Opções de atualização

### 1. Atualizações automáticas das lojas

**Android:** usuários que instalaram pela Google Play podem receber atualizações automáticas conforme as configurações da loja, rede, dispositivo e demais condições aplicadas pelo Google Play. O usuário pode desativar a atualização automática ou atualizar manualmente.

**iOS:** atualizações automáticas da App Store vêm ativadas por padrão, mas podem ser desativadas pelo usuário. A Apple também permite liberar uma versão gradualmente por sete dias, em percentuais crescentes. Durante essa liberação, usuários ainda podem buscar a atualização manualmente.

**Vantagens:** canal oficial, instalação familiar ao usuário, assinatura e distribuição gerenciadas pelas lojas.  
**Limites:** não há garantia de instalação imediata; usuários podem permanecer em versões antigas.

### 2. Atualização solicitada pelo próprio aplicativo

O app pode consultar um endpoint de configuração e comparar a versão instalada com a versão recomendada e a versão mínima suportada.

- **Atualização opcional:** informa que existe uma versão mais recente, apresenta notas e permite continuar usando o app ou abrir a loja.
- **Atualização obrigatória:** impede o uso de fluxos incompatíveis e direciona à loja. Deve ser reservada para falha crítica de segurança, incompatibilidade real ou versão sem suporte.
- **Android:** o app pode iniciar um fluxo da Google Play usando Play Core In-App Updates: `flexible` para baixar enquanto a pessoa continua usando o app; `immediate` para cenários críticos, com interrupção do uso até concluir ou sair do fluxo.
- **iOS:** o app pode informar e abrir a página da App Store, mas não instalar ou forçar silenciosamente uma atualização nativa.

A verificação deve ocorrer ao iniciar o app e em intervalos apropriados, com tratamento de falta de rede e uma política segura de cache. Para bloqueios importantes, o backend também deve aplicar a regra nas operações incompatíveis; uma tela de aviso isolada no cliente não constitui controle de segurança.

### 3. Distribuição gerenciada ou privada

- **Android:** Google Play privado/gerenciado, Android Enterprise ou MDM podem distribuir e administrar apps de organizações.
- **iOS:** Apple Business Manager e MDM podem atender organizações e dispositivos administrados. TestFlight é destinado a beta e validação, não ao canal público de produção. Distribuição empresarial/alternativa tem requisitos e escopo próprios.

É uma opção quando a organização controla os dispositivos. Não é a recomendação para distribuir o app a consumidores em geral.

### 4. Instalação direta

- **Android:** disponibilizar APK fora da Play Store é possível, mas exige que o usuário autorize a instalação por essa origem e que os APKs sejam assinados corretamente. Atualizações precisam manter a mesma identidade de assinatura e ser distribuídas novamente pelo canal externo.
- **iOS:** não há um canal geral de instalação direta comparável a baixar um APK. Distribuição Ad Hoc, empresarial e canais alternativos têm limites, elegibilidade e requisitos específicos.

Esses caminhos aumentam suporte, risco de erro e complexidade operacional. Não são recomendados para produção pública quando as lojas oficiais estão disponíveis.

### 5. Atualização OTA de código Flutter

Serviços como Shorebird podem distribuir alterações compatíveis de código Dart sem exigir uma nova instalação pela loja. Em geral, o patch é baixado em segundo plano e passa a valer na próxima abertura do app.

Não substitui uma versão de loja: mudanças em código nativo, plugins com mudanças nativas, assets e engine Flutter exigem um novo build. Além disso, a Apple restringe o download e a execução de código que altere funcionalidades do app; patches que mudem comportamento podem criar risco de revisão ou conformidade. Por isso, OTA não é recomendado como canal principal de atualização, especialmente no iOS. Se for avaliado no futuro, limitar a correções compatíveis e revisar as regras vigentes das lojas e do fornecedor.

### 6. Web, configuração remota e feature flags

Atualizações do Flutter Web podem ser publicadas pela hospedagem web e ficar disponíveis na próxima visita/recarga. Feature flags e configurações remotas podem ativar ou desativar funcionalidades já incluídas no binário nativo.

Essas opções ajudam a controlar lançamentos, conteúdo e compatibilidade, mas não atualizam telas/código nativo que não estejam no binário instalado. Push notification pode comunicar uma atualização disponível, mas não instala o app.

## Fluxo de publicação proposto

1. Executar testes, análise estática e builds de validação.
2. Incrementar a versão e o número de build; manter números crescentes em cada plataforma.
3. Produzir Android App Bundle (`.aab`) assinado com chave de produção protegida.
4. Publicar primeiro em teste interno da Google Play; validar e promover para produção em rollout gradual.
5. Produzir archive/IPA iOS assinado e publicar em TestFlight para QA.
6. Enviar a versão iOS à App Store para revisão e, após aprovação, liberar gradualmente quando apropriado.
7. Observar crashes, erros de API, métricas de adoção e suporte; pausar rollout ou preparar correção se houver regressão.
8. Aumentar gradualmente a disponibilidade e encerrar o rollout quando os indicadores estiverem saudáveis.

A pipeline deve exigir credenciais de publicação fora do repositório, armazenadas como secrets protegidos do CI, com permissões mínimas e rotação adequada. O build de produção nunca deve usar assinatura de debug.

## Compatibilidade com o backend

O backend pode ser publicado separadamente do binário. Mudanças de servidor compatíveis podem chegar sem atualização do app. Mudanças que alterem contratos de API precisam de uma janela de convivência:

- Primeiro publicar backend que aceite clientes antigos e novos.
- Depois distribuir o app atualizado e acompanhar adoção e erros.
- Só remover o contrato antigo quando a versão mínima definida e os dados de uso justificarem.
- Usar a versão mínima suportada para bloquear somente clientes realmente incompatíveis.

## Estado observado do projeto

Na referência consultada para esta proposta:

- O workflow Android compila um APK release e o armazena como artefato do GitHub Actions; não publica na Google Play.
- O workflow do Firebase publica Flutter Web, não os aplicativos móveis.
- O backend tem pipeline separado.
- A versão mobile estava em `1.0.0+1`.
- O build Android release usava assinatura de debug, portanto ainda não estava pronto para distribuição pública pela loja.
- O projeto iOS existe, com bundle identifier `com.b2bpersonalia.personalIa` e deployment target iOS 15, mas não foi encontrado workflow de publicação iOS.
- Não foi encontrado mecanismo de atualização dentro do app, Play Core, verificação de versão mínima, publicação Play, TestFlight ou Shorebird.

Esse inventário deve ser reconfirmado antes da implementação, pois o repositório pode mudar.

## Pré-requisitos para implementação

- Conta, cadastro do app e acesso de publicação na Google Play Console.
- Chave de assinatura Android de produção, com backup seguro e sem commit no repositório.
- Conta Apple Developer e App Store Connect; certificados/perfis de distribuição e acesso à equipe.
- Confirmar bundle ID iOS, metadados, política de privacidade, classificação etária e requisitos de revisão.
- Pipeline CI que gere e assine `.aab` e archive/IPA e publique primeiro em canais de teste.
- Gestão automatizada da versão e do build number para evitar versões repetidas ou regressivas.
- Endpoint de versão e comportamento de aviso/bloqueio definidos, incluindo mensagens e links corretos para cada loja.
- Telemetria de crashes, falhas de inicialização, erros de API e adoção por versão.

## Decisões pendentes para a etapa de implementação

- Nome e titularidade das contas de publicação.
- Se a primeira entrega inclui apenas pipeline de lojas ou também aviso de versão no app.
- Qual versão mínima suportada e quais condições justificam bloqueio obrigatório.
- Tamanho do grupo de teste e critérios para avançar o rollout.
- Política de compatibilidade e prazo de suporte para clientes antigos.
- Se existe necessidade de distribuição gerenciada para clientes empresariais.

## Referências oficiais

- [Google Play In-App Updates](https://developer.android.com/guide/playcore/in-app-updates)
- [Atualizações automáticas do Google Play](https://support.google.com/googleplay/answer/113412)
- [Atualizações automáticas e manuais da App Store](https://support.apple.com/en-us/102629)
- [Liberação gradual de versões na App Store](https://developer.apple.com/help/app-store-connect/update-your-app/release-a-version-update-in-phases/)
- [Diretrizes de revisão da App Store, seção 2.5](https://developer.apple.com/app-store/review/guidelines/#software-requirements)
- [TestFlight](https://developer.apple.com/testflight/)
- [Shorebird Code Push](https://docs.shorebird.dev/code-push/)
