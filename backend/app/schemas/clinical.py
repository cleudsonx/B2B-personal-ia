from enum import Enum
from typing import List, Optional, Dict, Any
from pydantic import BaseModel, Field


class JointRegion(str, Enum):
    SHOULDER = "shoulder"
    LUMBAR_SPINE = "lumbar_spine"
    KNEE = "knee"
    CERVICAL_SPINE = "cervical_spine"
    HIP = "hip"
    WRIST_ELBOW = "wrist_elbow"
    ANKLE = "ankle"


class JointSeverity(str, Enum):
    MILD = "mild"          # Desconforto leve / incômodo ocasional
    MODERATE = "moderate"  # Limitação moderada / quadro crônico / reabilitação
    SEVERE = "severe"      # Lesão grave / pós-cirúrgico / contraindicação estrita


class JointRestriction(BaseModel):
    joint: JointRegion = Field(..., description="Articulação ou região anatômica afetada")
    severity: JointSeverity = Field(default=JointSeverity.MODERATE, description="Gravidade da restrição")
    conditions: List[str] = Field(default_factory=list, description="Condições ou patologias relatadas (ex: 'Condromalácia', 'Manguito', 'Hérnia de disco')")
    avoid_vectors: List[str] = Field(default_factory=list, description="Vetores ou padrões de movimento a evitar")
    notes: Optional[str] = Field(None, description="Observações clínicas adicionais do treinador ou médico")


class StudentClinicalProfile(BaseModel):
    student_id: str = Field(..., description="ID do aluno no sistema")
    restrictions: List[JointRestriction] = Field(default_factory=list, description="Lista de restrições articulares ativas")
    general_clinical_notes: Optional[str] = Field(None, description="Notas clínicas gerais (medicamentos, cirurgias, liberação médica)")
    risk_level: str = Field(default="low", description="'low', 'medium', 'high'")
    last_assessment_date: Optional[str] = Field(None, description="Data ISO da última avaliação clínica")
    updated_at: Optional[str] = Field(None, description="Data ISO da última atualização")


class ContraindicatedExercise(BaseModel):
    exercise_name: str = Field(..., description="Nome do exercício identificado na ficha")
    joint: JointRegion = Field(..., description="Articulação vulnerável")
    severity: JointSeverity = Field(..., description="Gravidade do risco associado")
    reason: str = Field(..., description="Justificativa biomecânica e cinesiológica da contraindicação")
    avoid_vector: str = Field(..., description="Vetor mecânico inadequado (ex: compressão axial, cisalhamento patelar)")
    safe_substitute: str = Field(..., description="Exercício alternativo seguro que preserva a articulação")


class BiomechanicalSafetyReport(BaseModel):
    is_safe: bool = Field(..., description="True se o treino não apresentar contraindicações graves")
    overall_risk: str = Field(default="safe", description="'safe', 'warning', 'critical_danger'")
    total_exercises_checked: int = Field(0, description="Total de exercícios avaliados na ficha")
    contraindications_count: int = Field(0, description="Quantidade de exercícios contraindicados")
    dangerous_exercises: List[ContraindicatedExercise] = Field(default_factory=list, description="Lista de exercícios com contraindicação")
    protective_recommendation: str = Field(..., description="Recomendação executiva de proteção articular")
    adapted_plan: Optional[Dict[str, Any]] = Field(None, description="Ficha de treino adaptada com as substituições aplicadas se solicitado")


class BiomechanicalSafetyCheckRequest(BaseModel):
    student_id: Optional[str] = Field(None, description="ID do aluno para busca do histórico clínico existente")
    restrictions: Optional[List[JointRestriction]] = Field(None, description="Lista explícita de restrições articulares")
    raw_restrictions_text: Optional[str] = Field(None, description="Texto livre digitado na anamnese caso não use a matriz")
    workout_plan: Dict[str, Any] = Field(..., description="Objeto estruturado do treino (WorkoutPlanResponse ou splits)")
    auto_apply_substitutes: bool = Field(default=False, description="Se True, retorna no adapted_plan o treino com as substituições aplicadas")
