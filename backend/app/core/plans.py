from typing import List, Dict, Any, Optional
from app.schemas.subscription import PlanResponse, PlanFeature

# ==============================================================================
# Catálogo Central de Planos SaaS — B2B Personal IA ("Mr. Coach")
# Fonte única da verdade consumida por subscriptions.py, payment_service.py e DB
# ==============================================================================

SAAS_PLANS: List[PlanResponse] = [
    PlanResponse(
        id="starter",
        name="Starter Trial",
        tagline="Degustação completa para começar sua consultoria com IA",
        price_monthly_cents=0,
        price_yearly_cents=0,
        price_yearly_monthly_equivalent_cents=0,
        max_students=3,
        max_ai_generations_per_month=10,
        is_popular=False,
        badge="GRATUITO",
        features=[
            PlanFeature(title="Até 3 alunos ativos simultâneos", included=True, highlight=False),
            PlanFeature(title="10 fichas geradas por IA com Gemini 3.5", included=True, highlight=False),
            PlanFeature(title="Adaptação de exercícios por dor ou aparelho ocupado", included=True, highlight=False),
            PlanFeature(title="Raio-X Anatômico e Split-View para o aluno", included=True, highlight=False),
            PlanFeature(title="Suporte comunitário", included=True, highlight=False),
            PlanFeature(title="Alunos ilimitados", included=False, highlight=False),
            PlanFeature(title="Alertas automáticos via WhatsApp", included=False, highlight=False),
        ],
    ),
    PlanResponse(
        id="pro",
        name="Personal Pro",
        tagline="O plano definitivo para o Personal Trainer autônomo de alta renda",
        price_monthly_cents=8900,  # R$ 89,00
        price_yearly_cents=85200,  # R$ 852,00 (R$ 71,00/mês - 20% OFF)
        price_yearly_monthly_equivalent_cents=7100,
        max_students=30,
        max_ai_generations_per_month=-1,  # Ilimitado
        is_popular=True,
        badge="MAIS POPULAR",
        features=[
            PlanFeature(title="Até 30 alunos ativos na consultoria", included=True, highlight=True),
            PlanFeature(title="Prescrições IA Ilimitadas (Gemini Flash)", included=True, highlight=True),
            PlanFeature(title="Anamnese clínica profunda com histórico de lesões", included=True, highlight=False),
            PlanFeature(title="Raio-X Muscular com EMG e Análise de Fases", included=True, highlight=True),
            PlanFeature(title="Timer de descanso interativo sincronizado", included=True, highlight=False),
            PlanFeature(title="Painel de alertas de adaptação em tempo real", included=True, highlight=True),
            PlanFeature(title="Suporte prioritário via WhatsApp", included=True, highlight=False),
            PlanFeature(title="Múltiplos personals colaboradores", included=False, highlight=False),
        ],
    ),
    PlanResponse(
        id="elite",
        name="Elite Coach",
        tagline="Consultoria esportiva de alta escala com canal WhatsApp automatizado",
        price_monthly_cents=14900,  # R$ 149,00
        price_yearly_cents=142800,  # R$ 1.428,00 (R$ 119,00/mês - 20% OFF)
        price_yearly_monthly_equivalent_cents=11900,
        max_students=60,
        max_ai_generations_per_month=-1,
        is_popular=False,
        badge="ALTA ESCALA",
        features=[
            PlanFeature(title="Até 60 alunos ativos na consultoria", included=True, highlight=True),
            PlanFeature(title="Prescrições IA Ilimitadas (Gemini Flash)", included=True, highlight=True),
            PlanFeature(title="Automação WhatsApp (Evolution/Z-API): Envio de treinos", included=True, highlight=True),
            PlanFeature(title="Alertas de dor e faltas recorrentes direto no WhatsApp", included=True, highlight=True),
            PlanFeature(title="Raio-X Muscular com EMG e Análise de Fases", included=True, highlight=False),
            PlanFeature(title="Relatórios de assiduidade e retenção de alunos", included=True, highlight=True),
            PlanFeature(title="Suporte prioritário via WhatsApp", included=True, highlight=False),
        ],
    ),
    PlanResponse(
        id="studio",
        name="Studio Scale",
        tagline="Para assessorias esportivas e estúdios que buscam escala máxima",
        price_monthly_cents=19900,  # R$ 199,00
        price_yearly_cents=190800,  # R$ 1.908,00 (R$ 159,00/mês - 20% OFF)
        price_yearly_monthly_equivalent_cents=15900,
        max_students=100,
        max_ai_generations_per_month=-1,
        is_popular=False,
        badge="ESCALA MÁXIMA",
        features=[
            PlanFeature(title="Até 100 alunos ativos na assessoria", included=True, highlight=True),
            PlanFeature(title="Prescrições e adaptações IA Ilimitadas", included=True, highlight=True),
            PlanFeature(title="Múltiplos personals e estagiários sob a mesma conta", included=True, highlight=True),
            PlanFeature(title="Alertas de dor e evasão em tempo real via WhatsApp", included=True, highlight=True),
            PlanFeature(title="Relatórios de assiduidade e retenção de alunos", included=True, highlight=True),
            PlanFeature(title="Personalização com a marca (White-Label parcial)", included=True, highlight=False),
            PlanFeature(title="Gerente de contas dedicado e suporte VIP", included=True, highlight=False),
        ],
    ),
]

# Dicionário indexado para cálculos rápidos e consultas de transição/faturamento
PLANS_CATALOG: Dict[str, Dict[str, Any]] = {
    p.id: {
        "id": p.id,
        "name": p.name,
        "tagline": p.tagline,
        "monthly_cents": p.price_monthly_cents,
        "yearly_cents": p.price_yearly_cents,
        "max_students": p.max_students,
        "max_ai": p.max_ai_generations_per_month,
        "tier": idx + 1,
    }
    for idx, p in enumerate(SAAS_PLANS)
}

# Alias compatível com payment_service PLANS_INFO
PLANS_INFO = PLANS_CATALOG


def get_plan(plan_id: str) -> Optional[PlanResponse]:
    return next((p for p in SAAS_PLANS if p.id == plan_id), None)


def get_plan_info(plan_id: str) -> Optional[Dict[str, Any]]:
    return PLANS_CATALOG.get(plan_id)


def get_plan_student_limit(plan_id: str, default: int = 3) -> int:
    info = PLANS_CATALOG.get(plan_id)
    return info["max_students"] if info else default


def get_plan_ai_limit(plan_id: str, default: int = 10) -> int:
    info = PLANS_CATALOG.get(plan_id)
    return info["max_ai"] if info else default
