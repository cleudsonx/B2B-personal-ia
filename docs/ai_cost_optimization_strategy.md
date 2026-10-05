# Estratégia de Otimização de Custos de IA (Produção)

Este documento foi criado durante a fase de desenvolvimento agressivo (V2.0) para registrar as estratégias arquiteturais que serão aplicadas antes do lançamento em larga escala (Produção), visando reduzir os custos de consumo da API do Google Gemini.

## 1. Model Tiering (Roteamento Inteligente de Modelos)
Nem toda requisição precisa do modelo mais pesado e caro. Em produção, implementaremos um roteador de LLMs:
* **Gemini 1.5 Flash (Ultrarrápido e Barato):** Será usado para o *Consultor Ativo no WhatsApp*, onde o aluno faz perguntas simples do dia a dia (ex: "Qual o peso que peguei no supino ontem?"). O Flash custa uma fração de centavo por milhão de tokens.
* **Gemini 1.5 Pro (Raciocínio Profundo):** Será restrito **apenas** ao momento de Geração da Periodização Inicial e Análise Biomecânica, onde precisamos de altíssima precisão clínica para evitar lesões.

## 2. Context Caching (Cache de Contexto)
Em vez de enviar as "Regras do Mr. Coach" e "Diretrizes de Segurança Articular" em toda requisição, utilizaremos a API de Context Caching do Gemini.
* **Como funciona:** O "cérebro" das regras clínicas fica congelado (em cache) no servidor do Google.
* **Impacto:** Reduz o custo dos tokens de entrada (input) em até **75%**, além de deixar a resposta da IA quase instantânea.

## 3. Compressão de Prompts e JSON
Atualmente, nossos prompts de desenvolvimento são "verborrágicos" (explicamos muito as coisas para a IA). Em produção:
* Minificaremos os prompts.
* As chaves do JSON de saída serão encurtadas (ex: de "exercicio_nome" para "ex_n"), o que economiza milhares de tokens de saída (output) na geração de uma ficha com 20 exercícios.

## 4. Agrupamento em Lote (Batching)
Se um treinador solicitar a recriação da ficha de 10 alunos ao mesmo tempo (Renovação Mensal), o backend empacotará os 10 pedidos em um único prompt *Batch*, em vez de abrir 10 conexões individuais pesadas.

---
**Status atual:** *Aguardando fase de Escalabilidade (Pós-lançamento V2.0).* 
Durante a fase atual (Dev/Testing), o foco absoluto deve permanecer na Qualidade e Velocidade de Entrega. A otimização será ligada no momento exato em que a tração de usuários exigir.
