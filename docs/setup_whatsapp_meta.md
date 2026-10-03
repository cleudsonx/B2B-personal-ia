# Guia Definitivo: Configuração da API Oficial do WhatsApp (Meta)

Este documento é o guia passo-a-passo para conectar o servidor do **Mr. Coach** (FastAPI) à rede oficial do WhatsApp, permitindo o disparo do "Robô Notificador Passivo" (Fase 1).

---

## 1. Criar a Conta e o Aplicativo na Meta
1. Acesse o [Meta for Developers](https://developers.facebook.com/) e faça login com seu Facebook.
2. Clique em **"Meus Aplicativos"** (My Apps) no canto superior direito.
3. Clique no botão verde **"Criar Aplicativo"** (Create App).
4. Escolha o caso de uso: **"Outro"** (Other) -> **"Avançar"**.
5. Escolha o tipo de aplicativo: **"Empresa"** (Business) -> **"Avançar"**.
6. Preencha os dados:
   * **Nome do aplicativo:** `Mr Coach B2B`
   * **E-mail de contato:** (Seu e-mail profissional)
   * **Conta Empresarial (Business Portfolio):** Vincule ao Gerenciador de Negócios da sua empresa (Obrigatório para ter limites maiores de disparo depois).
7. Clique em **"Criar aplicativo"**.

---

## 2. Adicionar o Produto WhatsApp
1. Na tela principal do seu novo aplicativo, desça até encontrar **"WhatsApp"** e clique em **"Configurar"** (Set up).
2. No menu lateral esquerdo, expanda "WhatsApp" e clique em **"Configuração da API"** (API Setup).
3. A Meta vai te dar um "Número de Telefone de Teste" e um "Token de Acesso Temporário" (dura 24h). 
   * *(Usaremos isso primeiro, depois ensino a colocar o token permanente e seu número real).*
4. Copie o **Identificador do número de telefone** (Phone Number ID) e salve-o no arquivo `.env` do nosso backend (FastAPI).

---

## 3. Configurar o Webhook (O "Porteiro" do nosso Backend)
Para que a Meta consiga avisar o Mr. Coach que "A mensagem foi entregue" ou "O aluno respondeu", precisamos plugar o Webhook.

1. No menu lateral esquerdo da Meta, em "WhatsApp", clique em **"Configuração"** (Configuration).
2. Na seção Webhooks, clique em **"Editar"**.
3. Uma janela vai pedir dois campos:
   * **URL de Retorno (Callback URL):** Coloque a URL do seu servidor em produção seguido da rota que o Alan e o Victor programaram. 
     * *Exemplo: `https://api.shaipados.com/api/v1/whatsapp/webhook`*
   * **Token de Verificação (Verify Token):** Lembra do token que colocamos no código de Python? Copie exatamente ele: `mrcoach_seguranca_token_2026`.
4. Clique em **"Verificar e Salvar"**. (A Meta fará um disparo real `GET` para o nosso servidor. Como o Thiago já validou o código `200 OK`, a Meta aprovará na hora).

---

## 4. Inscrever-se nos Eventos (Subscribing)
Ainda na tela de Webhooks (depois de salvar), você verá uma lista de "Campos do Webhook" (Webhook Fields).
1. Encontre a linha escrita **`messages`**.
2. Clique no botão **"Assinar"** (Subscribe) à direita dela.
*Isso diz para a Meta: "Avise o servidor do Mr. Coach toda vez que uma mensagem transitar".*

---

## 5. Gerando o Token Permanente (Produção)
O token da tela de "Configuração da API" dura só 24 horas. Para o aplicativo rodar sozinho sem você ter que logar todo dia:
1. Vá nas **Configurações do Gerenciador de Negócios** (Business Settings).
2. Vá em **Usuários > Usuários do sistema** (System Users).
3. Adicione um novo usuário (Ex: `MrCoachBot`) com a função **"Administrador"**.
4. Clique em **"Adicionar ativos"** (Add Assets), vá em Aplicativos, selecione o `Mr Coach B2B` e dê permissão total.
5. Clique em **"Gerar novo token"**.
6. Selecione as permissões cruciais:
   * `whatsapp_business_messaging`
   * `whatsapp_business_management`
7. Copie o token gigantesco gerado. Ele nunca vai expirar! 
8. Cole este token no arquivo `.env` do nosso backend como `WHATSAPP_TOKEN`.

---

## 🎉 Pronto!
Com esse Token Permanente e o Webhook rodando, o nosso servidor já tem permissão e "asfalto" para mandar mensagens ilimitadas (Template Passivo) via WhatsApp!
