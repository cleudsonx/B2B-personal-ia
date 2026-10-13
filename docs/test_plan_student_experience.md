# Plano e Matriz de Testes de Aceitação e Regressão: Nova Experiência do Aluno Mr. Coach (Gym Floor UX)

**Documento:** `docs/test_plan_student_experience.md`  
**Autor:** Thiago (QA Engineer Sênior)  
**Versão:** 1.0  
**Status:** Pronto para Execução / Homologação  
**Ambiente Alvo:** Android 11+ / iOS 15+ (Mobile Nativo Flutter)  

---

## 1. Escopo e Objetivos de QA

Validar a experiência do aluno em ambiente hostil de salão de musculação (baixa conectividade, mãos suadas, fadiga física, operação One-Hand na Thumb Zone).
A matriz cobre 5 pilares críticos:
1. **Navegação One-Hand por gestos de Swipe** (`PageView.builder` com `BouncingScrollPhysics`).
2. **Troca de Cargas sem Teclado** (incrementos e decrementos rápidos `+/- 2.5kg`, zero abertura de teclado virtual).
3. **Auto-Rest Timer com Feedback Tátil** (`HapticFeedback.lightImpact` no check e `HapticFeedback.mediumImpact` no timeout, persistência em background).
4. **Modo Aparelho Ocupado (IA Biomecânica)** (substituição isomórfica de EMG e notificação síncrona/WebSockets/Push no painel do Personal Trainer).
5. **Resiliência Offline e Sincronização Assíncrona** (persistência SQLite/Hive local, recuperação de conexão sem perda de tonelagem ou logs).

---

## 2. Matriz de Cenários de Testes

### Módulo 1: Navegação One-Hand & Gestos de Swipe (Gym Floor Navigation)

| ID | Cenário / Caso de Teste | Tipo | Pré-condição | Passos de Execução | Resultado Esperado | Severidade |
|---|---|---|---|---|---|---|
| **TC-NAV-001** | Transição horizontal suave entre exercícios via Swipe Left (Avançar) | Aceitação | Treino A iniciado, no Exercício 1 de 6 | 1. Deslizar o polegar da direita para a esquerda na área de Swipe.<br>2. Observar a física de mola e transição. | O card transiciona suavemente (`BouncingScrollPhysics`) para o Exercício 2/6. O contador do topo atualiza para "2/6" e a barra de progresso Emerald avança proporcionalmente. | Blocker |
| **TC-NAV-002** | Retorno de exercício via Swipe Right (Voltar) | Aceitação | No Exercício 2 de 6 | 1. Deslizar da esquerda para a direita. | Retorna ao Exercício 1/6 com estado das séries e cargas previamente digitadas intactas. | Critical |
| **TC-NAV-003** | Limites das extremidades do carrossel (Overscroll) | Regressão | No Exercício 1/6 (início) ou 6/6 (fim) | 1. No card 1, tentar deslizar para a direita.<br>2. No card 6, tentar deslizar para a esquerda. | Respeita a física de ricochete (`bouncing overscroll`) sem crash, sem tela branca e sem transição fantasma. | Major |
| **TC-NAV-004** | Acessibilidade One-Hand por Botões de Rodapé | Aceitação | Em qualquer exercício do treino | 1. Tocar no botão `[ Próximo Exercício > ]` no rodapé da Thumb Zone.<br>2. Tocar no botão `[ < Exercício Anterior ]`. | A navegação ocorre identicamente ao gesto de swipe, garantindo redundância ergonômica para uso unilateral. | Major |
| **TC-NAV-005** | Prevenção de conflito de gestos (Swipe Horizontal vs Scroll Vertical) | Regressão | Tela com histórico expandido ou muitas séries | 1. Rolar verticalmente as séries com movimento oblíquo/diagonal. | O `PageView` não engole o scroll vertical; o sistema discrimina com precisão a direção primária do gesto (touch slop/velocity). | Critical |

---

### Módulo 2: Troca de Cargas sem Teclado (+/- 2.5kg / Quick Weights)

| ID | Cenário / Caso de Teste | Tipo | Pré-condição | Passos de Execução | Resultado Esperado | Severidade |
|---|---|---|---|---|---|---|
| **TC-WGT-001** | Incremento padrão de carga (+2.5 kg) em 1 toque | Aceitação | Série #3 com carga herdada de 32.5 kg | 1. Pressionar o botão `[ + ]` da coluna Carga Atual. | A carga atualiza imediatamente para `35.0 kg`. Nenhum teclado de sistema (`SoftInput`) é exibido. Feedback háptico sutil disparado. | Blocker |
| **TC-WGT-002** | Decremento de carga (-2.5 kg) com limite de segurança | Aceitação | Carga atual em `2.5 kg` | 1. Pressionar `[ - ]`.<br>2. Pressionar `[ - ]` novamente. | No primeiro toque vai para `0.0 kg` (peso corporal/livre). No segundo toque permanece `0.0 kg`, desabilitando o botão `[ - ]` para evitar números negativos. | Critical |
| **TC-WGT-003** | Long Press / Toque Contínuo para aceleração de carga | Aceitação | Carga em 20 kg | 1. Manter pressionado o botão `[ + ]` por 1.5s. | O incremento acelera em passos de 5kg ou dispara contagem rápida, parando ao soltar o dedo. | Minor |
| **TC-WGT-004** | Manutenção de precisão de ponto flutuante (Sem bugs decimais) | Regressão | Carga em `12.5 kg` | 1. Pressionar `[ + ]` repetidas vezes (15.0, 17.5, 20.0). | As strings formatadas não apresentam anomalias do IEEE 754 (ex: `17.500000000002 kg`), mantendo formato limpo `17.5 kg` / `20 kg`. | Major |
| **TC-WGT-005** | Isolamento do foco e supressão de teclado virtual | Regressão | Série ativa em foco | 1. Tocar em qualquer ponto do seletor `[ - ] 35.0 kg [ + ]`. | Em nenhum momento o teclado alfanumérico ou numérico do Android/iOS é aberto. | Critical |

---

### Módulo 3: Auto-Rest Timer com Vibração Tátil (Haptic Feedback)

| ID | Cenário / Caso de Teste | Tipo | Pré-condição | Passos de Execução | Resultado Esperado | Severidade |
|---|---|---|---|---|---|---|
| **TC-TMR-001** | Disparo automático do timer ao marcar série `[ ✓ ]` | Aceitação | Série #1 em execução | 1. Tocar no botão de status `[ ✓ ]`. | 1. Status da série muda para verde (Concluída).<br>2. Dispara `HapticFeedback.lightImpact()`.<br>3. Banner flutuante do timer surge automaticamente iniciando contagem regressiva (ex: 60s/90s conforme prescrito). | Blocker |
| **TC-TMR-002** | Expiração do timer com Vibração Tátil no bolso | Aceitação | Timer com 00:03 restantes | 1. Aguardar o contador atingir 00:00. | Dispara `HapticFeedback.mediumImpact()` (vibração perceptível mesmo com o celular no bolso ou na esteira). Banner transiciona para "Descanso Concluído / Próxima Série". | Blocker |
| **TC-TMR-003** | Ajustes rápidos de tempo (+30s / Pular) | Aceitação | Timer ativo em 00:45 | 1. Tocar no botão `[ +30s ]`.<br>2. Tocar no botão `[ Pular ]`. | No passo 1, o timer incrementa para `01:15`. No passo 2, o timer é interrompido imediatamente e o banner recolhe sem travar a UI. | Major |
| **TC-TMR-004** | Persistência do Timer com App em Segundo Plano / Tela Bloqueada | Regressão | Timer rodando em 00:50 | 1. Bloquear a tela do aparelho por 55 segundos.<br>2. Desbloquear o celular. | A contagem regressiva calculou via delta timestamp (`DateTime.now()`), zera no momento correto e emite notificação local/vibração em background. | Critical |
| **TC-TMR-005** | Múltiplos checks sem sobreposição de instâncias de timer | Regressão | Série 1 concluída, timer rodando | 1. Marcar a Série 2 quase imediatamente. | O timer anterior é descartado/reiniciado de forma limpa, sem criar vazamentos de memória (Timer leak) ou múltiplas vibrações dessincronizadas. | Critical |

---

### Módulo 4: Aparelho Ocupado (IA Biomecânica) & Alerta ao Treinador

| ID | Cenário / Caso de Teste | Tipo | Pré-condição | Passos de Execução | Resultado Esperado | Severidade |
|---|---|---|---|---|---|---|
| **TC-OCC-001** | Abertura do Modal Bottom Sheet "Aparelho Ocupado" | Aceitação | No card "Supino Reto com Barra" | 1. Tocar em `[ ⚡ Aparelho Ocupado? ]`. | Modal Bottom Sheet desliza suavemente (`Obsidian #0B0E14`), exibindo sugestões equivalentes (ex: Supino com Halteres - 93% EMG, Supino Articulado - 91% EMG). | Blocker |
| **TC-OCC-002** | Aplicação da Substituição no Treino em Execução | Aceitação | Modal de sugestões aberto | 1. Clicar em `[ Substituir por Esta ]` na Opção 1 (Halteres). | O exercício atual no Focus Mode é substituído instantaneamente por "Supino Reto com Halteres". O progresso das séries concluídas é tratado de acordo com a regra de negócio. | Blocker |
| **TC-OCC-003** | Propagação de Notificação Síncrona ao Painel do Personal | Aceitação | Treinador conectado ao painel web/app | 1. Aluno confirma a substituição no app.<br>2. Monitorar painel do Personal Trainer. | Painel do Treinador recebe via WebSocket/SSE/Push: "Aluno [Nome] substituiu Supino Barra por Supino Halteres no Treino A (Aparelho Ocupado)". Histórico é registrado no prontuário. | Critical |
| **TC-OCC-004** | Fallback de Sugestões Biomecânicas quando Offline | Regressão | Aparelho sem internet | 1. Tocar em `[ ⚡ Aparelho Ocupado? ]`. | As sugestões biomecânicas são lidas da matriz local pré-carregada (tabela de equivalência EMG em cache local), sem exibir erro de rede. | Critical |
| **TC-OCC-005** | Cancelamento / Fechamento do Modal sem Efeito Colateral | Regressão | Modal aberto | 1. Deslizar para baixo ou tocar fora do modal. | O modal fecha suavemente e o exercício original permanece 100% inalterado. | Minor |

---

### Módulo 5: Resiliência Offline & Sincronização Assíncrona

| ID | Cenário / Caso de Teste | Tipo | Pré-condição | Passos de Execução | Resultado Esperado | Severidade |
|---|---|---|---|---|---|---|
| **TC-OFF-001** | Execução completa de treino sem sinal de rede (Modo Avião) | Aceitação | Treino do dia sincronizado, Modo Avião ativado | 1. Iniciar o treino.<br>2. Ajustar cargas (+/- 2.5kg).<br>3. Dar check em todas as séries e navegar por Swipe.<br>4. Finalizar o treino. | O app funciona 100% fluido. Todos os eventos são gravados na fila SQLite/Hive local. Tela de parabéns/dopamina exibe o resumo calculado localmente com sucesso. | Blocker |
| **TC-OFF-002** | Sincronização automática em background após restauração de rede | Aceitação | Treino finalizado offline com status `pending_sync` | 1. Desativar o Modo Avião (reconectar 4G/Wi-Fi).<br>2. Observar tráfego e logs de rede. | O job de sincronização (`WorkManager` / `JobScheduler`) envia os lotes pendentes com idempotência (`idempotency_key`), atualizando o status para `synced`. | Blocker |
| **TC-OFF-003** | Persistência contra fechamento forçado do app (Kill Task / Bateria Baixa) | Regressão | 3 séries concluídas, no meio do Treino A | 1. Forçar o encerramento do app no gerenciador de tarefas do SO.<br>2. Reabrir o app Mr. Coach. | O app restaura a sessão ativa de treino exatamente de onde parou: séries marcadas permanecem concluídas, cargas mantidas e tempo total acumulado correto. | Critical |
| **TC-OFF-004** | Tratamento de conflito de concorrência (Offline Sync vs Alteração do Treinador) | Regressão | Aluno treina offline enquanto treinador edita ficha no painel | 1. Sincronizar logs do aluno offline após o treinador ter atualizado o plano. | Os logs de execução do aluno têm precedência de histórico (imutabilidade da execução realizada); o novo plano do treinador passa a valer para o próximo treino. | Major |

---

## 3. Critérios de Aceite e Definição de Pronto (DoD)

1. **Taxa de Passagem (Pass Rate):** 100% dos testes classificados como **Blocker** e **Critical** devem passar sem desvios.
2. **Latência de Interação:** Operações de Swipe e toque no seletor de carga devem responder em menos de **16ms** (60-120 FPS estáveis sem jank).
3. **Consumo de Bateria & Memória:** O Auto-Rest Timer e o listener de haptics não podem gerar vazamentos de memória (Zero memory leaks com o app aberto por 90 minutos contínuos).
4. **Idempotência de Dados:** Nenhuma série ou treino duplicado no banco central durante reconexões intermitentes de 3G/4G.

