# B2B Personal IA - Plataforma de Prescrição & Adaptação de Treinos

Plataforma mobile B2B para **Personal Trainers** e **Consultorias Fitness** potencializada por Inteligência Artificial (Google Gemini 3.8 / FastAPI) e persistência em tempo real (Supabase).

---

## 🎯 Proposta de Valor

1. **Para o Treinador (Geração & Escala)**:
   - Prescrição de periodizações completas e equilibradas (Splits A, B, C...) em segundos com base em anamnese clínica detalhada.
   - Respeito irrestrito a restrições articulares e lesões (ombro, lombar, joelho).
   - Edição rápida e aprovação em 1 clique antes de liberar o treino para o aluno.
2. **Para o Aluno (Agilidade no Salão de Musculação)**:
   - Visualização limpa dos exercícios do dia com séries, repetições e intervalos.
   - **Botão de Emergência ("Aparelho Ocupado" / "Dor")**: A IA sugere instantaneamente uma variação biomecanicamente equivalente com o mesmo vetor motor.
   - Notificação/auditoria para o treinador acompanhar tudo o que foi alterado.

---

## 🏗️ Arquitetura do Sistema

```plaintext
B2B-personal-ia/
├── backend/            # API Python (FastAPI + Pydantic v2 + Google GenAI SDK)
├── mobile/             # Aplicativo Flutter (Android / iOS)
├── supabase/           # Migrações SQL, RLS Policies e Triggers
├── docs/               # Especificações técnicas e manuais
└── README.md
```

### Stack Tecnológica
- **Mobile**: Flutter 3.47+ (Dart 3.13+)
- **Backend API**: Python 3.11+ / FastAPI
- **Motor de IA**: Google Gemini API (`gemini-3.8-flash`) com *Structured Outputs* estritos via Pydantic
- **Banco de Dados & Auth**: Supabase (PostgreSQL + Supabase Auth com Row Level Security - RLS)
- **Hospedagem API**: Render / Fly.io / GCP Cloud Run (Tier gratuito ou ultra-baixo custo)

---

## 🚀 Como Executar o Projeto

### 1. Banco de Dados (Supabase)
1. Crie um projeto gratuito no [Supabase](https://supabase.com).
2. Acesse o **SQL Editor** do Supabase e execute o script contido em:
   ```
   supabase/migrations/20260925_init_schema.sql
   ```
3. Obtenha a URL do projeto (`SUPABASE_URL`), a chave anônima (`SUPABASE_KEY`) e o JWT Secret (`SUPABASE_JWT_SECRET`).

---

### 2. Backend (FastAPI + Python)
1. Acesse o diretório do backend:
   ```bash
   cd backend
   ```
2. Crie e ative um ambiente virtual:
   ```bash
   python -m venv .venv
   # Windows:
   .venv\Scripts\activate
   # Linux/Mac:
   source .venv/bin/activate
   ```
3. Instale as dependências:
   ```bash
   pip install -r requirements.txt
   ```
4. Configure as variáveis de ambiente:
   - Duplique `.env.example` para `.env`:
     ```bash
     copy .env.example .env
     ```
   - Preencha sua chave `GEMINI_API_KEY` (gratuita no [Google AI Studio](https://aistudio.google.com/)).
5. Inicie a API:
   ```bash
   uvicorn app.main:app --reload --port 8000
   ```
6. Acesse a documentação interativa Swagger em: [http://localhost:8000/docs](http://localhost:8000/docs)

---

### 3. Mobile (Flutter)
1. Acesse o diretório do app:
   ```bash
   cd mobile
   ```
2. Instale os pacotes:
   ```bash
   flutter pub get
   ```
3. Execute o aplicativo em um emulador ou dispositivo conectado:
   ```bash
   flutter run
   ```

---

## 🔒 Segurança e RLS
- Todas as tabelas no Supabase (`profiles`, `anamnesis`, `workouts`, `adaptation_logs`) possuem **Row Level Security (RLS)** ativado.
- Treinadores só têm acesso aos dados e treinos dos alunos vinculados a eles.
- Alunos só têm permissão de leitura nos seus próprios treinos ativos e criação de logs de adaptação.
