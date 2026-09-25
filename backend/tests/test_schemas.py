import pytest
from app.schemas.anamnesis import AnamnesisInput
from app.schemas.workout import WorkoutPlanResponse, Split, Exercise
from app.schemas.adaptation import AdaptationInput, AdaptationResponse


def test_anamnesis_validation():
    data = AnamnesisInput(
        objective="Hipertrofia Muscular",
        training_level="Intermediário",
        days_per_week=4,
        workout_location="Academia completa",
        injuries_or_restrictions="Leve dor no ombro direito",
        additional_notes="Priorizar peitoral superior"
    )
    assert data.days_per_week == 4
    assert "ombro" in data.injuries_or_restrictions


def test_workout_plan_validation():
    exercise = Exercise(
        order=1,
        name="Supino Reto com Halteres",
        target_muscle_group="Peitoral Maior",
        sets=4,
        reps="8-10",
        rest_seconds=90,
        notes="Adução escapular e cotovelos a 45 graus",
        substitution_vector="Empurrar horizontal livre"
    )
    split_a = Split(
        split_identifier="A",
        split_name="Peito e Tríceps",
        estimated_duration_min=50,
        exercises=[exercise]
    )
    plan = WorkoutPlanResponse(
        workout_plan_title="Periodização Hipertrofia ABC",
        notes_for_trainer="Foco em estímulo tensional com volume moderado",
        splits=[split_a]
    )
    assert plan.workout_plan_title == "Periodização Hipertrofia ABC"
    assert len(plan.splits) == 1
    assert plan.splits[0].exercises[0].name == "Supino Reto com Halteres"


def test_adaptation_validation():
    adaptation_in = AdaptationInput(
        current_exercise="Leg Press 45",
        reason="Aparelho Ocupado / Fila",
        workout_location="Academia completa"
    )
    assert adaptation_in.reason == "Aparelho Ocupado / Fila"

    adaptation_out = AdaptationResponse(
        original_exercise="Leg Press 45",
        adapted_exercise="Agachamento Búlgaro com Halteres",
        reason="Aparelho Ocupado / Fila",
        sets=4,
        reps="10-12",
        rest_seconds=60,
        notes="Manter tronco levemente inclinado à frente",
        biomechanical_rationale="Mesmo padrão de dominância de joelho e extensão de quadril sem uso do aparelho ocupado"
    )
    assert adaptation_out.adapted_exercise == "Agachamento Búlgaro com Halteres"
