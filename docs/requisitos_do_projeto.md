# Documento de Requisitos e Fluxos do Projeto (PRD)

## 1. Visão Geral
O **Mr. Coach** opera no modelo B2B2C. O sistema precisa ser "Product-Led Growth" (PLG), ou seja, o produto deve se vender sozinho sem gargalos de atendimento humano inicial. 

## 2. Fluxo do Professor (B2B) - "Self-Service"
O objetivo da Landing Page principal (shaipados.com) é converter visitantes em usuários pagantes ou em período de testes, sem atrito.
1. **Descoberta:** Professor acessa a Landing Page.
2. **Conversão (Novo Botão):** Clica em "Criar Conta Grátis" (substituindo o antigo "Chame no Zap").
3. **Onboarding:** Preenche e-mail, senha, CREF e monta sua "Vitrine" (Foto, Bio, Especialidades).
4. **Primeira Ação (Aha Moment):** Cadastra o primeiro aluno, preenche a anamnese e gera o treino via IA em 30 segundos.
5. **Convite:** O sistema dispara automaticamente um link de convite para o WhatsApp/E-mail do aluno.

## 3. Fluxo do Aluno (B2C) - "Experiência Premium"
O aluno não entra pela porta da frente genérica. Ele tem uma experiência guiada e personalizada pelo seu professor.
1. **Recepção:** Aluno recebe o link no WhatsApp (ex: shaipados.com/convite/joao-silva/token123).
2. **Landing Page do Convite:** A página exibe a foto do Professor, sua Bio e a mensagem: *"O Prof. João Silva preparou seu treino com IA. Acesse agora"*.
3. **Ativação:** Aluno clica em "Acessar meu Treino", define uma senha (ou usa biometria/FaceID).
4. **Retenção:** Cai direto no Dashboard do Aluno (ctive_workout_screen.dart), pronto para treinar.

## 4. O Papel do WhatsApp (Suporte e Vendas Avançadas)
O botão de WhatsApp não deve ser a **única** porta de entrada. Ele deve ser um canal de **Suporte** (dúvidas complexas) ou **Vendas Enterprise** (acima de 10 alunos). A porta principal de entrada é o cadastro "Self-Service".

## 5. Edição Colaborativa (O Novo Fluxo do Aluno)
Conforme aprovado, o fluxo de Anamnese será bidirecional:
1. O Professor faz o cadastro inicial (Anamnese Padrão) e gera o primeiro treino.
2. O Aluno, ao aceitar o convite e acessar o app, tem total autonomia para **visualizar, revisar e editar** seus dados cadastrais e sua Anamnese (ex: relatar uma lesão no joelho que o professor não sabia).
3. **Regra de Negócio (IA):** Se o aluno alterar a anamnese inserindo uma nova restrição, o sistema (via Backend) deve acionar o motor do Gemini para revisar automaticamente o treino ativo, garantindo a **consistência e segurança biomecânica**.

## 6. Arquitetura de Segurança e Consistência (Supabase)
Para garantir persistência, autenticidade e segurança:
* **Identificador Único (UUID v4):** Todo usuário (Professor ou Aluno) é registrado no Supabase Auth e recebe um ID criptográfico único e universal. E-mails são estritamente únicos.
* **Autenticidade (RLS):** O banco de dados utiliza Row Level Security (RLS) do PostgreSQL. Um token JWT de aluno garante que ele só pode fazer UPDATE na própria linha da tabela profiles, sendo matematicamente impossível que ele altere os dados do professor ou de outros alunos.
* **Consistência de Dados:** O Backend em FastAPI fará a validação de todos os payloads usando Pydantic, garantindo clareza e que nenhum dado corrompido chegue ao banco.
