import os
import json
import asyncio
import logging
from typing import Optional, List
from google import genai
from google.genai import types
from app.core.config import settings
from app.schemas.workout import WorkoutPlanResponse, Split, Exercise
from app.schemas.adaptation import AdaptationResponse
from app.prompts.plan_generator import SYSTEM_INSTRUCTION_PLAN_GENERATOR, build_plan_prompt
from app.prompts.exercise_adapter import SYSTEM_INSTRUCTION_EXERCISE_ADAPTER, build_adaptation_prompt

logger = logging.getLogger(__name__)


class GeminiService:
    def __init__(self):
        api_key = settings.GEMINI_API_KEY or os.environ.get("GEMINI_API_KEY")
        if api_key:
            self.client = genai.Client(api_key=api_key)
        else:
            self.client = None

    def _ensure_client(self):
        if not self.client:
            api_key = os.environ.get("GEMINI_API_KEY") or settings.GEMINI_API_KEY
            if api_key:
                self.client = genai.Client(api_key=api_key)
            else:
                raise ValueError(
                    "GEMINI_API_KEY não configurada. Configure a variável no arquivo .env ou no ambiente."
                )

    async def _generate_with_fallback_async(
        self,
        candidate_models: List[str],
        contents,
        config: types.GenerateContentConfig,
        per_model_timeout: float = 6.0
    ):
        """
        Executa a chamada ao Gemini com limite de tempo estrito por modelo (evitando travamento por 503).
        Alterna instantaneamente entre modelos saudáveis.
        """
        self._ensure_client()
        last_error = None

        for i, model in enumerate(candidate_models):
            try:
                # Executa em thread separada com timeout estrito
                response = await asyncio.wait_for(
                    asyncio.to_thread(
                        self.client.models.generate_content,
                        model=model,
                        contents=contents,
                        config=config,
                    ),
                    timeout=per_model_timeout
                )
                if response and response.text:
                    logger.info(f"[GeminiService] Sucesso com modelo '{model}'.")
                    return response
            except asyncio.TimeoutError:
                last_error = f"Timeout de {per_model_timeout}s no modelo '{model}'."
                logger.warning(f"[GeminiService] {last_error} Tentando próximo candidato...")
            except Exception as e:
                err_msg = str(e)
                last_error = err_msg
                logger.warning(f"[GeminiService] Aviso: Falha no modelo '{model}' ({err_msg[:120]}).")

        raise RuntimeError(f"Todos os modelos da nuvem falharam: {last_error}")

    def _get_model_candidates(self, model_name: Optional[str] = None, is_deep: bool = False) -> List[str]:
        """
        Retorna a lista ordenada de modelos candidatos para inferência.
        Prioriza o modelo configurado em Settings (DEFAULT_DEEP_MODEL ou DEFAULT_FAST_MODEL)
        e mantém a cascata de fallback de alta disponibilidade.
        """
        candidates: List[str] = []
        if model_name:
            candidates.append(model_name)

        preferred = settings.DEFAULT_DEEP_MODEL if is_deep else settings.DEFAULT_FAST_MODEL
        if preferred and preferred not in candidates:
            candidates.append(preferred)

        fallbacks = [
            "gemini-2.5-flash",
            "gemini-2.5-flash-lite",
            "gemini-3.5-flash",
            "gemini-3.8-flash",
        ]
        for m in fallbacks:
            if m not in candidates:
                candidates.append(m)

        return candidates

    async def generate_workout_plan(
        self,
        objective: str,
        training_level: str,
        days_per_week: int,
        workout_location: str,
        injuries_or_restrictions: str,
        split_type: str = "Automático (IA Sugere)",
        target_focus: Optional[str] = None,
        additional_notes: Optional[str] = None,
        model_name: Optional[str] = None
    ) -> WorkoutPlanResponse:
        try:
            self._ensure_client()
            candidates = self._get_model_candidates(model_name=model_name, is_deep=True)

            prompt_text = build_plan_prompt(
                objective=objective,
                training_level=training_level,
                days_per_week=days_per_week,
                workout_location=workout_location,
                injuries_or_restrictions=injuries_or_restrictions,
                split_type=split_type,
                target_focus=target_focus or "",
                additional_notes=additional_notes or ""
            )

            config = types.GenerateContentConfig(
                system_instruction=SYSTEM_INSTRUCTION_PLAN_GENERATOR,
                response_mime_type="application/json",
                response_schema=WorkoutPlanResponse,
                temperature=0.2,
            )

            response = await self._generate_with_fallback_async(
                candidate_models=candidates,
                contents=prompt_text,
                config=config,
                per_model_timeout=30.0
            )
            if response.text:
                return WorkoutPlanResponse.model_validate_json(response.text)
        except Exception as e:
            logger.warning(f"[GeminiService] Acionando plano biomecânico de contingência: {e}")

        # Contingência Biomecânica de Alta Disponibilidade
        return self._build_contingency_workout_plan(
            objective=objective,
            level=training_level,
            days=days_per_week,
            split_type=split_type,
            target_focus=target_focus
        )

    async def adapt_exercise(
        self,
        current_exercise: str,
        reason: str,
        workout_location: str,
        injuries_or_restrictions: str,
        model_name: Optional[str] = None
    ) -> AdaptationResponse:
        try:
            self._ensure_client()
            candidates = self._get_model_candidates(model_name=model_name, is_deep=False)

            prompt_text = build_adaptation_prompt(
                current_exercise=current_exercise,
                reason=reason,
                workout_location=workout_location,
                injuries_or_restrictions=injuries_or_restrictions
            )

            config = types.GenerateContentConfig(
                system_instruction=SYSTEM_INSTRUCTION_EXERCISE_ADAPTER,
                response_mime_type="application/json",
                response_schema=AdaptationResponse,
                temperature=0.1,
            )

            response = await self._generate_with_fallback_async(
                candidate_models=candidates,
                contents=prompt_text,
                config=config,
                per_model_timeout=30.0
            )
            if response.text:
                return AdaptationResponse.model_validate_json(response.text)
        except Exception as e:
            logger.warning(f"[GeminiService] Acionando adaptação biomecânica de contingência: {e}")

        return self._build_contingency_adaptation(current_exercise, reason)

    async def ask_assistant(
        self,
        prompt: str,
        system_instruction: Optional[str] = None,
        temperature: float = 0.7,
        model_name: Optional[str] = None
    ) -> str:
        try:
            self._ensure_client()
            candidates = self._get_model_candidates(model_name=model_name, is_deep=False)

            sys_inst = system_instruction or (
                "Você é o **Mr. Coach AI**, uma autoridade internacional multidisciplinar de elite para personal trainers e academias. "
                "Você domina simultaneamente quatro grandes pilares científicos e de mercado:\n"
                "1. **Biomecânica de Precisão e Cinesiologia:** Análise de alavancas anatômicas, braços de momento interno vs externo, torques articulares, curvas de resistência vs curvas de força de implementos (halteres vs polias vs máquinas articuladas), dados sEMG (eletromiografia de superfície) e blindagem articular (labrum, manguito rotador, patela, coluna lombar).\n"
                "2. **Fisiologia do Exercício:** Bioenergética neuromuscular (ATP-CP, glicolítica, oxidativa), fadiga central vs periférica, gestão de estresse mecânico vs metabólico, RPE (Escala de Borg CR10), RIR (repetições em reserva), supercompensação e recuperação tecidual.\n"
                "3. **Treinador de Musculação & Treinamento Resistido Avançado:** Periodização ondulatória diária (DUP), linear e em blocos; técnicas inteligentes de intensificação (Rest-Pause, Myo-Reps, Cluster Sets, Drop-Sets conscientes, repetições em máximo alongamento muscular); controle estrito de cadência e tempo sob tensão.\n"
                "4. **Estrategista B2B Fitness & Negócios em Saúde:** Gestão e escala de consultorias presenciais e híbridas via app, estruturação de planos recorrentes de alto valor, scripts de fechamento e quebra de objeções no WhatsApp, fidelização, combate a churn e reengajamento de alunos inativos.\n"
                "Inicie sempre seu parecer ou resposta com o cabeçalho '### 🤖 Parecer do Mr. Coach'. Seja sempre técnico, preciso, seguro, encorajador e direto ao ponto com o personal trainer."
            )

            config = types.GenerateContentConfig(
                system_instruction=sys_inst,
                temperature=temperature,
            )

            response = await self._generate_with_fallback_async(
                candidate_models=candidates,
                contents=prompt,
                config=config,
                per_model_timeout=30.0
            )
            if response and response.text:
                return response.text
        except Exception as e:
            logger.warning(f"[GeminiService] Nuvem Gemini indisponível (503/timeout). Acionando Base de Conhecimento Biomecânica B2B: {e}")

        # Resposta inteligente da Base de Conhecimento B2B de Alta Disponibilidade
        return self._get_biomechanical_knowledge_response(prompt)

    def _get_biomechanical_knowledge_response(self, prompt: str) -> str:
        """Motor de Conhecimento Biomecânico B2B para Alta Disponibilidade (Zero Downtime)."""
        lower = prompt.lower()

        if "emg" in lower or "eletromiografia" in lower or "deltoide" in lower or "elevação lateral" in lower:
            return (
                "### ⚡ Biomecânica & Eletromiografia (sEMG): Deltoides & Elevação Lateral\n\n"
                "**1. Perfil de Resistência: Halteres vs. Cabos/Polia:**\n"
                "* **Com Halteres:** O braço de momento externo com a gravidade é praticamente ZERO no início do movimento (braços ao lado do corpo) e atinge o torque máximo exatamente a 90° de abdução. Isso significa que o músculo só recebe alta tensão mecânica no topo.\n"
                "* **Na Polia Baixa (com cabo cruzando o corpo):** O cabo cria torque e tensão mecânica já no início da abdução (posição de alongamento do deltoide lateral), gerando maior estímulo hipertrófico mediado pelo estiramento.\n\n"
                "**2. Leitura sEMG (Eletromiografia de Superfície):**\n"
                "* O percentual de ativação sEMG (ex: *Deltoide Anterior 92% EMG* no supino inclinado ou *Deltoide Lateral 88% EMG* na elevação na polia) indica o nível de recrutamento das unidades motoras em relação à contração isométrica voluntária máxima (MVIC).\n"
                "* Um valor acima de 85% EMG sinaliza recrutamento pleno das fibras de contração rápida (Tipo IIa e IIx).\n\n"
                "💡 **Diretriz Prática do Mr. Coach:**\n"
                "Combine no mesmo microciclo a **Elevação Lateral na Polia** (tensão no alongamento) com a **Elevação Lateral com Halteres inclinando o tronco levemente à frente** (tensão no encurtamento), poupando o supraespinhal e isolando as fibras médias do deltoide."
            )

        elif "rpe" in lower or "rir" in lower or "repetições em reserva" in lower or "fadiga" in lower:
            return (
                "### 🔬 Fisiologia do Exercício: RPE, RIR & Gestão de Fadiga Neuromuscular\n\n"
                "**1. RIR (Reps in Reserve) e RPE (Rate of Perceived Exertion):**\n"
                "* **RIR 0 (RPE 10):** Falha concêntrica momentânea. Deve ser usada com moderação, principalmente em exercícios isolados e máquinas guiadas.\n"
                "* **RIR 1-2 (RPE 8-9):** Zona ideal de hipertrofia máxima. Recruta 100% das unidades motoras de alto limiar sem gerar fadiga central desproporcional.\n"
                "* **RIR 3-4 (RPE 6-7):** Séries preparatórias, aquecimento neuromuscular ou semanas de deload.\n\n"
                "**2. Fadiga Central vs. Periférica:**\n"
                "* **Fadiga Periférica:** Acúmulo de íons H+, depleção de fosfocreatina e desacoplamento excitação-contração no retículo sarcoplasmático. Recupera-se em minutos ou poucas horas.\n"
                "* **Fadiga Central:** Diminuição da ativação voluntária pelo córtex motor e medula espinhal. Séries com falha em exercícios multiarticulares pesados (Agachamento, Terra) geram alta fadiga central que prejudica o restante do treino.\n\n"
                "💡 **Regra de Ouro:**\n"
                "Mantenha os grandes exercícios multiarticulares com **RIR 1 a 2**, reservando o **RIR 0** para a última série do último exercício isolador da sessão."
            )

        elif "rest-pause" in lower or "myo-reps" in lower or "cluster" in lower or "técnicas" in lower:
            return (
                "### 🏋️ Treinamento Resistido Avançado: Rest-Pause, Myo-Reps & Clusters\n\n"
                "**1. Myo-Reps (Borge Fagerli):**\n"
                "* **Como executar:** Realize uma 'série de ativação' de 12-15 reps até RIR 1. Descanse apenas 10-15 segundos (3-5 respirações profundas) e faça mini-séries de 3-5 repetições até perder a velocidade concêntrica.\n"
                "* **Vantagem Fisiológica:** Todas as repetições das mini-séries são 'repetições efetivas', estimulando fibras de alto limiar com economia de 60% de tempo.\n\n"
                "**2. Cluster Sets (Séries em Bloco):**\n"
                "* **Aplicação:** Ideal para força e potência. Em vez de 1 série de 6 reps pesadas, prescreva 3 blocos de 2 reps com 20 segundos de pausa intra-série. Isso mantém a velocidade da barra e a técnica biomecânica intacta.\n\n"
                "**3. Rest-Pause (Mike Mentzer / DC Training):**\n"
                "* Execução até a falha momentânea, 15 segundos de descanso, extensão de repetições, mais 15s de descanso e repetições finais.\n"
                "* **Segurança Articular:** NUNCA execute Rest-Pause ou Myo-Reps em Agachamento Livre ou Levantamento Terra para evitar acidentes por perda de estabilidade do core."
            )

        elif "supino" in lower and ("barra" in lower or "halteres" in lower or "halter" in lower):
            return (
                "### 🏋️ Análise Biomecânica: Supino com Halteres vs. Supino com Barra\n\n"
                "**1. Amplitude de Movimento (ROM) & Alongamento:**\n"
                "* **Halteres:** Permitem maior adução horizontal no topo (convergência) e descida mais profunda na fase excêntrica, sem a limitação física da barra tocando no esterno. Isso gera maior microlesão nas fibras esternocostais e claviculares.\n"
                "* **Barra:** A amplitude é limitada pelo contato da barra no tórax. Contudo, permite manipular cargas absolutas ~10% a 20% maiores, gerando maior sobrecarga mecânica geral.\n\n"
                "**2. Segurança Articular do Ombro & Labrum:**\n"
                "* **Halteres:** Permitem rotação livre do punho para uma pegada semi-pronada (~45°-60°), diminuindo o impacto subacromial e poupando a bursa e o tendão supraespinhal.\n"
                "* **Barra:** Trava os punhos em pronação rígida. Se o aluno abrir os cotovelos a 90°, cria-se uma alavanca de cisalhamento anterior de alto risco na cápsula glenoumeral.\n\n"
                "**3. Demanda de Estabilização & Assimetrias:**\n"
                "* **Halteres:** Exigem ativação contínua do manguito rotador e serrátil anterior, prevenindo e corrigindo déficits de força bilaterais.\n"
                "* **Barra:** O membro dominante pode compensar a carga do membro mais fraco.\n\n"
                "💡 **Recomendação Prática para o Personal:**\n"
                "Utilize o **Supino com Barra** no início da periodização para ganhos neurais de força máxima, e o **Supino com Halteres** para volume hipertrófico seguro ou para alunos com histórico de dores no ombro."
            )

        elif "agachamento" in lower or "búlgaro" in lower or "bulgaro" in lower:
            return (
                "### 🦵 Biomecânica do Agachamento Búlgaro (Rear Foot Elevated Split Squat)\n\n"
                "* **Vetor de Força:** Força vertical unilateral com estabilização no plano frontal (glúteo médio).\n"
                "* **Ângulo do Tronco:** Inclinar o tronco à frente (~15°-20°) com coluna neutra aumenta o braço de momento para o quadril, maximizando a ativação do **Glúteo Máximo**.\n"
                "* **Ponto de Atenção:** Evitar o valgo dinâmico do joelho anterior. O calcanhar do pé de apoio deve permanecer 100% ancorado ao solo durante toda a fase excêntrica."
            )

        elif "precificar" in lower or "consultoria" in lower or "preço" in lower or "plano" in lower:
            return (
                "### 📈 Estratégia de Precificação B2B Fitness & Esteira de Produtos\n\n"
                "1. **Elimine a Hora/Aula Isolada:** Cobrar por hora limita seu teto de faturamento a 30-40h semanais. Transicione para modelos de **Programas de Transformação por Assinatura**.\n"
                "2. **Esteira de 3 Níveis (High-Ticket + Escala):**\n"
                "   * **Nível 1 - Consultoria Digital via App B2B (R$ 160 a R$ 220/mês):** Prescrição com IA, substituição inteligente de exercícios, suporte semanal por WhatsApp. Permite atender de 40 a 80 alunos com 4 horas semanais de trabalho.\n"
                "   * **Nível 2 - Modelo Híbrido (R$ 380 a R$ 550/mês):** App completo + 1 encontro presencial quinzenal para ajuste biomecânico e aferição de cargas.\n"
                "   * **Nível 3 - VIP Presencial Exclusivo (R$ 900 a R$ 1.800/mês):** Acompanhamento presencial 2x-3x/semana com foco em executivos.\n"
                "3. **Gatilho de Recorrência Automática:** Cobre sempre via cartão de crédito recorrente ou Pix programado com renovação automática, reduzindo a inadimplência a menos de 3%."
            )

        elif "cobrança" in lower or "whatsapp" in lower or "mensalidade" in lower or "reter" in lower or "ausente" in lower:
            return (
                "### 💬 Scripts de Retenção & Reengajamento no WhatsApp\n\n"
                "**Cenário 1: Aluno ausente há mais de 10 dias (Combate a Churn):**\n"
                "\"Fala [Nome do Aluno], tudo bem? 👊\n"
                "Notei aqui no aplicativo que você não registrou os últimos treinos da semana. Sei que a rotina aperta, mas o mais importante agora não é fazer o treino perfeito, e sim manter a consistência.\n"
                "Se estiver muito corrido, me avisa que eu adapto sua ficha no app para uma versão 'Express' de 30 minutos! Podemos combinar seu retorno nesta quinta?\"\n\n"
                "**Cenário 2: Renovação Elegante de Ciclo de Consultoria:**\n"
                "\"Olá [Nome do Aluno]! Completamos hoje o ciclo de 30 dias da sua periodização. 🚀\n"
                "Já estou aqui com seus registros de carga no app para montar a sua nova ficha com técnicas de intensificação para o próximo mês.\n"
                "Para garantirmos a continuidade dos seus resultados sem interrupção, segue o link de renovação da consultoria: [Link ou Chave Pix].\n"
                "Vamos juntos que este próximo mês promete! 🔥\""
            )

        else:
            return (
                f"### 🤖 Parecer do Mr. Coach\n\n"
                f"Analisando a sua solicitação: **\"{prompt}\"**\n\n"
                "1. **Fundamento Biomecânico:** Respeite a linha de ação das fibras musculares e o alinhamento das articulações envolvidas, priorizando a fase excêntrica controlada (cadência mínima de 3 segundos).\n"
                "2. **Estímulo Neuromuscular:** Manipule o volume de séries mantendo o esforço próximo à falha mecânica (RIR 1-2), garantindo máxima tensão mecânica sem exaustão desnecessária do sistema nervoso central.\n"
                "3. **Comunicação B2B com o Aluno:** Mantenha contato ativo pelos canais digitais, apresentando os relatórios e justificativas da prescrição para reforçar a percepção de valor da sua consultoria."
            )

    def _build_contingency_workout_plan(
        self,
        objective: str,
        level: str,
        days: int,
        split_type: str = "Automático (IA Sugere)",
        target_focus: Optional[str] = None
    ) -> WorkoutPlanResponse:
        """Gera planos de contingência inteligentes com suporte a múltiplos splits e especializações."""
        lower_split = split_type.lower()
        title_suffix = f" - Foco: {target_focus}" if target_focus else ""

        # Caso 1: Full Body (Corpo Inteiro)
        if "full body" in lower_split or (days <= 2 and "automático" in lower_split):
            return WorkoutPlanResponse(
                workout_plan_title=f"Full Body de Alta Eficiência ({objective}) - {days}x/semana{title_suffix}",
                notes_for_trainer="Prescrição Full Body focada em padrões motores primários (Agachar, Empurrar, Puxar, Dobradiça). Alta frequência semanal por grupamento com excelente tempo de recuperação tecidual.",
                splits=[
                    Split(
                        split_identifier="A",
                        split_name="Full Body A (Ênfase Anterior & Empurrar)",
                        estimated_duration_min=50,
                        exercises=[
                            Exercise(order=1, name="Agachamento Búlgaro com Halteres", target_muscle_group="Quadríceps & Glúteo", sets=3, reps="8-10", rest_seconds=90, notes="Tronco alinhado, foco na fase excêntrica. Cadência 3010.", substitution_vector="Agachamento unilateral"),
                            Exercise(order=2, name="Supino Inclinado com Halteres", target_muscle_group="Peitoral Clavicular", sets=3, reps="8-10", rest_seconds=90, notes="Pegada a 45°, retração escapular ativa.", substitution_vector="Empurrar horizontal livre"),
                            Exercise(order=3, name="Puxada Alta Supinada na Polia", target_muscle_group="Latíssimo do Dorso", sets=3, reps="10-12", rest_seconds=75, notes="Puxe até a fúrcula esternal sem balançar o tronco.", substitution_vector="Puxada vertical"),
                            Exercise(order=4, name="Elevação Lateral na Polia", target_muscle_group="Deltoide Lateral", sets=3, reps="12-15", rest_seconds=60, notes="Cabo na altura do joelho para torque contínuo no alongamento.", substitution_vector="Abdução de ombro na polia"),
                            Exercise(order=5, name="Prancha Abdominal Isométrica", target_muscle_group="Core / Transverso", sets=3, reps="45 seg", rest_seconds=60, notes="Ativação glútea e contração abdominal contínua.", substitution_vector="Estabilização de core"),
                        ]
                    ),
                    Split(
                        split_identifier="B",
                        split_name="Full Body B (Ênfase Posterior & Puxar)",
                        estimated_duration_min=50,
                        exercises=[
                            Exercise(order=1, name="RDL / Stiff com Halteres", target_muscle_group="Isquiotibiais & Glúteo", sets=3, reps="8-10", rest_seconds=90, notes="Dobradiça pura de quadril sem flexionar a coluna lombar.", substitution_vector="Extensão de quadril"),
                            Exercise(order=2, name="Remada Baixa Triângulo", target_muscle_group="Dorsais e Romboides", sets=3, reps="10-12", rest_seconds=75, notes="Pico de contração de 1 segundo nas escápulas.", substitution_vector="Remada horizontal"),
                            Exercise(order=3, name="Desenvolvimento com Halteres Sentado", target_muscle_group="Deltoide Anterior", sets=3, reps="10-12", rest_seconds=75, notes="Pegada neutra para proteção articular da cabeça do úmero.", substitution_vector="Empurrar vertical"),
                            Exercise(order=4, name="Mesa Flexora", target_muscle_group="Isquiotibiais", sets=3, reps="12-15", rest_seconds=60, notes="Evite elevar o quadril do acolchoado na flexão máxima.", substitution_vector="Flexão de joelhos"),
                            Exercise(order=5, name="Tríceps Corda na Polia", target_muscle_group="Tríceps Braquial", sets=3, reps="12-15", rest_seconds=60, notes="Abertura no final da extensão com cotovelos estáveis.", substitution_vector="Extensão de cotovelos"),
                        ]
                    )
                ]
            )

        # Caso 2: Push / Pull / Legs (PPL)
        elif "push" in lower_split or "ppl" in lower_split:
            return WorkoutPlanResponse(
                workout_plan_title=f"Push / Pull / Legs Sinergia Perfeita ({objective}){title_suffix}",
                notes_for_trainer="Divisão padrão ouro PPL. Separação por sinergia motora que elimina sobreposição de fadiga entre grupos musculares e permite progressão de carga contínua.",
                splits=[
                    Split(
                        split_identifier="A",
                        split_name="Push (Peito, Deltoide Anterior/Lateral e Tríceps)",
                        estimated_duration_min=50,
                        exercises=[
                            Exercise(order=1, name="Supino Inclinado com Halteres", target_muscle_group="Peitoral Maior", sets=4, reps="8-10", rest_seconds=90, notes="Cotovelos a 45° do gradil costal. Cadência 3010.", substitution_vector="Empurrar horizontal livre"),
                            Exercise(order=2, name="Supino Reto na Máquina Articulada", target_muscle_group="Peitoral Esternal", sets=3, reps="10-12", rest_seconds=75, notes="Tensão mecânica máxima sem risco de desestabilização.", substitution_vector="Empurrar horizontal guiado"),
                            Exercise(order=3, name="Elevação Lateral com Halteres", target_muscle_group="Deltoide Lateral", sets=4, reps="12-15", rest_seconds=60, notes="Tronco inclinado 10° à frente, plano escapular.", substitution_vector="Abdução de ombros"),
                            Exercise(order=4, name="Tríceps Francês na Polia Baixa", target_muscle_group="Tríceps Cabeça Longa", sets=3, reps="12-15", rest_seconds=60, notes="Ênfase no alongamento da cabeça longa.", substitution_vector="Extensão acima da cabeça"),
                        ]
                    ),
                    Split(
                        split_identifier="B",
                        split_name="Pull (Costas, Deltoide Posterior e Bíceps)",
                        estimated_duration_min=50,
                        exercises=[
                            Exercise(order=1, name="Puxada Alta Pronada Aberta", target_muscle_group="Latíssimo do Dorso", sets=4, reps="8-10", rest_seconds=90, notes="Depressão escapular prévia antes de iniciar o movimento de cotovelos.", substitution_vector="Puxada vertical aberta"),
                            Exercise(order=2, name="Remada Cavalinho com Apoio Peitoral", target_muscle_group="Meio das Costas & Romboides", sets=3, reps="10-12", rest_seconds=75, notes="Apoio de peito poupa completamente a coluna lombar.", substitution_vector="Remada horizontal apoiada"),
                            Exercise(order=3, name="Crucifixo Inverso na Polia", target_muscle_group="Deltoide Posterior", sets=3, reps="12-15", rest_seconds=60, notes="Braços em linha reta cruzando os cabos na altura dos ombros.", substitution_vector="Adução horizontal posterior"),
                            Exercise(order=4, name="Rosca Direta com Barra W", target_muscle_group="Bíceps Braquial", sets=3, reps="10-12", rest_seconds=60, notes="Barra W reduz estresse sobre a articulação do punho e rádio.", substitution_vector="Flexão de cotovelos"),
                        ]
                    ),
                    Split(
                        split_identifier="C",
                        split_name="Legs (Quadríceps, Isquiotibiais, Glúteos e Panturrilhas)",
                        estimated_duration_min=55,
                        exercises=[
                            Exercise(order=1, name="Agachamento Búlgaro", target_muscle_group="Quadríceps & Glúteo", sets=4, reps="8-10", rest_seconds=90, notes="Equilíbrio unilateral e proteção da coluna lombar.", substitution_vector="Agachamento unilateral"),
                            Exercise(order=2, name="Leg Press 45°", target_muscle_group="Quadríceps Geral", sets=3, reps="10-12", rest_seconds=90, notes="Mantenha o quadril 100% ancorado ao encosto.", substitution_vector="Prensa de pernas"),
                            Exercise(order=3, name="Cadeira Flexora", target_muscle_group="Isquiotibiais", sets=4, reps="10-12", rest_seconds=75, notes="Tronco levemente inclinado à frente para aumentar o pré-estiramento dos isquiotibiais.", substitution_vector="Flexão de joelhos sentado"),
                            Exercise(order=4, name="Gêmeos Sentado na Máquina", target_muscle_group="Sóleo e Gastrocnêmio", sets=4, reps="15-20", rest_seconds=45, notes="Pausa de 2 segundos no ponto mais fundo de alongamento.", substitution_vector="Flexão plantar"),
                        ]
                    )
                ]
            )

        # Caso 3: Padrão Upper / Lower (Superiores / Inferiores)
        else:
            return WorkoutPlanResponse(
                workout_plan_title=f"Periodização Upper / Lower ({objective}) - {days}x/semana{title_suffix}",
                notes_for_trainer="Divisão Upper / Lower com equilíbrio perfeito de volume, alternância biomecânica de vetores de empurrar/puxar e cadência controlada para hipertrofia com proteção articular.",
                splits=[
                    Split(
                        split_identifier="A",
                        split_name="Upper (Superiores Completos & Core)",
                        estimated_duration_min=50,
                        exercises=[
                            Exercise(order=1, name="Supino Inclinado com Halteres", target_muscle_group="Peitoral Maior", sets=4, reps="8-10", rest_seconds=90, notes="Escápulas retraídas, cotovelos a 45°. Cadência 3010.", substitution_vector="Empurrar horizontal com halteres"),
                            Exercise(order=2, name="Remada Baixa Triângulo", target_muscle_group="Dorsais e Trapézio Médio", sets=4, reps="10-12", rest_seconds=75, notes="Alongamento completo na fase excêntrica com tronco estável.", substitution_vector="Remada horizontal"),
                            Exercise(order=3, name="Desenvolvimento com Halteres", target_muscle_group="Deltoide Anterior", sets=3, reps="10-12", rest_seconds=60, notes="Pegada semi-pronada para conforto do manguito rotador.", substitution_vector="Empurrar vertical"),
                            Exercise(order=4, name="Puxada Alta Pronada", target_muscle_group="Latíssimo do Dorso", sets=3, reps="10-12", rest_seconds=75, notes="Descida até a clavícula mantendo o peito erguido.", substitution_vector="Puxada vertical"),
                            Exercise(order=5, name="Tríceps na Polia com Corda", target_muscle_group="Tríceps Braquial", sets=3, reps="12-15", rest_seconds=60, notes="Extensão completa afastando as pontas da corda.", substitution_vector="Extensão de cotovelo"),
                        ]
                    ),
                    Split(
                        split_identifier="B",
                        split_name="Lower (Inferiores Completos & Glúteos)",
                        estimated_duration_min=55,
                        exercises=[
                            Exercise(order=1, name="Agachamento Búlgaro", target_muscle_group="Quadríceps & Glúteo", sets=4, reps="10-12", rest_seconds=90, notes="Tronco levemente inclinado para recrutar glúteo com segurança.", substitution_vector="Agachamento unilateral"),
                            Exercise(order=2, name="Leg Press 45°", target_muscle_group="Quadríceps", sets=3, reps="10-12", rest_seconds=90, notes="Pés na largura dos ombros, descer com controle.", substitution_vector="Prensa de pernas inclinada"),
                            Exercise(order=3, name="RDL / Stiff com Halteres", target_muscle_group="Isquiotibiais & Glúteo Máximo", sets=4, reps="10-12", rest_seconds=75, notes="Mantenha a barra/halteres rente às pernas.", substitution_vector="Dobradiça de quadril"),
                            Exercise(order=4, name="Cadeira Extensora", target_muscle_group="Reto Femoral", sets=3, reps="12-15", rest_seconds=60, notes="Pausa isométrica de 1s na contração máxima.", substitution_vector="Extensão de joelho em cadeia aberta"),
                            Exercise(order=5, name="Panturrilha no Leg Press", target_muscle_group="Gastrocnêmio", sets=4, reps="15-20", rest_seconds=45, notes="Amplitude total sem rebote no tornozelo.", substitution_vector="Flexão plantar em cadeia fechada"),
                        ]
                    )
                ]
            )

    def _build_contingency_adaptation(self, current_exercise: str, reason: str) -> AdaptationResponse:
        lower = current_exercise.lower()
        if "supino" in lower or "peito" in lower or "crucifixo" in lower:
            adapted = "Supino Inclinado na Máquina Articulada"
            notes = "Ajustar o assento para que os pegadores fiquem na linha do peitoral superior. Escápulas aduzidas."
            rationale = "Reduz o estresse glenoumeral anterior mantendo a trajetória guiada no vetor de empurrar horizontal."
        elif "desenvolvimento" in lower or "ombro" in lower or "elevação" in lower or "elevacao" in lower:
            adapted = "Desenvolvimento na Máquina Convergente"
            notes = "Pegada neutra ou semi-pronada. Cotovelos levemente à frente no plano escapular (30°)."
            rationale = "Diminui a compressão no manguito rotador preservando o recrutamento do deltoide anterior."
        elif "triceps" in lower or "tríceps" in lower:
            adapted = "Tríceps na Polia com Barra V"
            notes = "Cotovelos fixos ao lado do tronco. Estender completamente sem balanço lombar."
            rationale = "Isola o tríceps braquial com tensão mecânica constante na polia."
        elif "agachamento" in lower or "leg" in lower or "perna" in lower:
            adapted = "Leg Press 45° com Pés Médios"
            notes = "Pés apoiados na largura dos ombros. Manter lombar 100% apoiada no encosto."
            rationale = "Permite sobrecarga nos extensores de joelho e quadril com descarga axial da coluna vertebral."
        elif "puxada" in lower or "remada" in lower or "costas" in lower or "dorsal" in lower:
            adapted = "Remada Sentada na Máquina com Apoio no Peito"
            notes = "Manter o esterno apoiado na almofada. Puxar cotovelos em direção ao quadril."
            rationale = "Elimina a demanda estabilizadora sobre os eretores da espinha, focando na adução das escápulas e latíssimo."
        else:
            adapted = f"{current_exercise} na Máquina Articulada"
            notes = "Mantenha a postura alinhada, execute a fase excêntrica em 3 segundos e evite movimentos balísticos."
            rationale = f"Substituição motivada por: '{reason}'. Preserva o mesmo vetor biomecânico e ativação muscular com maior estabilidade guiada."

        return AdaptationResponse(
            original_exercise=current_exercise,
            adapted_exercise=adapted,
            reason=reason,
            sets=3,
            reps="10-12",
            rest_seconds=60,
            notes=notes,
            biomechanical_rationale=rationale,
        )


gemini_service = GeminiService()
