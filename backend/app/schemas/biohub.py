from enum import Enum
from typing import List, Optional, Dict, Any
from pydantic import BaseModel, Field


class ReadinessLevel(str, Enum):
    HIGH = "high"          # 80-100: Verde / Alta prontidão neuromuscular
    MODERATE = "moderate"  # 60-79: Amarelo / Estável / Prontidão equilibrada
    LOW = "low"            # 40-59: Laranja / Atenção / Cansaço acumulado
    CRITICAL = "critical"  # <40: Vermelho / Risco de overtraining / Repouso recomendado


class MuscleGroup(str, Enum):
    CHEST = "chest"                      # Peitoral Maior e Menor
    BACK = "back"                        # Dorsais, Trapézio e Romboides
    QUADRICEPS = "quadriceps"            # Quadríceps Femoral
    HAMSTRINGS_GLUTES = "hamstrings_glutes" # Posterior de Coxa e Glúteos
    SHOULDERS = "shoulders"              # Deltoides
    ARMS_CORE = "arms_core"              # Bíceps, Tríceps, Antebraços e Abdômen


class RecoveryStatus(str, Enum):
    RECOVERED = "recovered"    # 100% pronto para nova sessão pesada
    RECOVERING = "recovering"  # 50-99% em processo de síntese proteica/reparo
    FATIGUED = "fatigued"      # <50% alta fadiga miofibrilar/inflamação local


class DailyBiometricLog(BaseModel):
    sleep_hours: Optional[float] = Field(default=7.5, ge=0, le=24, description="Horas de sono na noite anterior")
    sleep_quality: Optional[int] = Field(default=4, ge=1, le=5, description="Qualidade subjetiva do sono (1 a 5)")
    perceived_stress: Optional[int] = Field(default=2, ge=1, le=5, description="Nível de estresse diário percebido (1 a 5)")
    soreness_level: Optional[int] = Field(default=2, ge=1, le=5, description="Nível de dor muscular tardia (DOMS) (1 a 5)")
    has_joint_pain: bool = Field(default=False, description="Reportou dor ou desconforto articular nas últimas 24h")
    notes: Optional[str] = Field(None, description="Observações do aluno sobre a prontidão")


class ReadinessScore(BaseModel):
    score: int = Field(..., ge=0, le=100, description="Pontuação final de prontidão de 0 a 100")
    level: ReadinessLevel = Field(..., description="Classificação do nível de prontidão")
    headline: str = Field(..., description="Manchete motivacional ou preventiva")
    recommendation: str = Field(..., description="Diretriz técnica cinesiológica para o treino de hoje")
    sleep_factor: float = Field(..., description="Impacto do sono no score (-20 a +5)")
    fatigue_factor: float = Field(..., description="Impacto da fadiga de RPE no score (-20 a +5)")
    joint_factor: float = Field(..., description="Impacto de dores articulares (-15 a 0)")
    streak_factor: float = Field(..., description="Impacto de treinos consecutivos sem descanso (-20 a 0)")


class MuscleRecoveryItem(BaseModel):
    muscle_group: MuscleGroup = Field(..., description="Grupamento muscular")
    label: str = Field(..., description="Nome amigável em português")
    recovery_percentage: int = Field(..., ge=0, le=100, description="Percentual estimado de recuperação (0 a 100)")
    status: RecoveryStatus = Field(..., description="Classificação do estado de recuperação")
    last_trained_hours_ago: Optional[float] = Field(None, description="Horas decorridas desde a última sessão desse grupo")
    hours_until_recovered: int = Field(..., ge=0, description="Horas estimadas restantes para recuperação completa (100%)")


class MuscleRecoveryReport(BaseModel):
    overall_recovery_percentage: int = Field(..., ge=0, le=100, description="Média geral de recuperação corporal")
    muscles: List[MuscleRecoveryItem] = Field(default_factory=list, description="Status individual de cada grupo muscular")
    ready_muscles_count: int = Field(..., description="Quantidade de grupos 100% recuperados")
    fatigued_muscles_count: int = Field(..., description="Quantidade de grupos em fadiga")
    summary: str = Field(..., description="Resumo executivo da prontidão corporal")


class StrengthPrItem(BaseModel):
    exercise_name: str = Field(..., description="Nome do exercício")
    weight_kg: float = Field(..., ge=0, description="Carga utilizada em kg")
    reps: int = Field(..., ge=1, description="Repetições executadas")
    estimated_1rm: float = Field(..., ge=0, description="1RM estimado em kg")
    formula_used: str = Field(default="brzycki", description="Fórmula utilizada ('brzycki' ou 'epley')")
    volume_load_kg: float = Field(..., ge=0, description="Volume load da série (peso * reps)")
    achieved_at: str = Field(..., description="Data/hora ISO da realização")
    previous_1rm: Optional[float] = Field(None, description="1RM anterior para comparação")
    gain_percent: Optional[float] = Field(None, description="Evolução percentual em relação ao recorde anterior")


class StrengthEvolutionReport(BaseModel):
    student_id: str = Field(..., description="ID do aluno")
    total_volume_7d_kg: float = Field(..., description="Volume total de carga movimentado nos últimos 7 dias")
    prs_count: int = Field(..., description="Quantidade de recordes pessoais registrados")
    recent_prs: List[StrengthPrItem] = Field(default_factory=list, description="Lista dos recordes mais recentes")
    key_lifts: Dict[str, StrengthPrItem] = Field(default_factory=dict, description="Melhor 1RM nos exercícios principais")


class DeloadRecommendation(BaseModel):
    should_deload: bool = Field(..., description="True se houver recomendação ativa de semana regenerativa")
    urgency: str = Field(default="none", description="'none', 'moderate', 'high'")
    reasons: List[str] = Field(default_factory=list, description="Critérios fisiológicos que dispararam o alerta")
    recommended_volume_reduction_pct: int = Field(default=35, description="Percentual recomendado de corte de séries (30-40%)")
    recommended_rpe_cap: int = Field(default=7, description="Teto de RPE recomendado para a semana regenerativa")
