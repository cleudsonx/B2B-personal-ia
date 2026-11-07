import pytest
from app.schemas.clinical import (
    JointRegion,
    JointSeverity,
    JointRestriction,
)
from app.services.cinesiology_engine import cinesiology_engine


SAMPLE_WORKOUT_PLAN = {
    "workout_plan_title": "Treino ABC Hipertrofia",
    "notes_for_trainer": "Foco em peito, costas e pernas",
    "splits": [
        {
            "split_identifier": "A",
            "split_name": "Peito e Ombros",
            "estimated_duration_min": 50,
            "exercises": [
                {
                    "order": 1,
                    "name": "Supino Reto com Barra Livre",
                    "target_muscle_group": "Peitoral Maior",
                    "sets": 4,
                    "reps": "8-10",
                    "rest_seconds": 90,
                    "notes": "Descer até tocar o peito",
                    "substitution_vector": "Empurrar horizontal",
                },
                {
                    "order": 2,
                    "name": "Remada Alta com Barra",
                    "target_muscle_group": "Deltoides",
                    "sets": 3,
                    "reps": "10-12",
                    "rest_seconds": 60,
                    "notes": "Puxar até o queixo",
                    "substitution_vector": "Abdução de ombro",
                },
            ],
        },
        {
            "split_identifier": "B",
            "split_name": "Pernas e Costas",
            "estimated_duration_min": 60,
            "exercises": [
                {
                    "order": 1,
                    "name": "Agachamento Livre com Barra nas Costas",
                    "target_muscle_group": "Quadríceps / Glúteos",
                    "sets": 4,
                    "reps": "8-10",
                    "rest_seconds": 120,
                    "notes": "Agachar fundo",
                    "substitution_vector": "Dominante de joelho",
                },
                {
                    "order": 2,
                    "name": "Levantamento Terra",
                    "target_muscle_group": "Posterior / Dorsais",
                    "sets": 3,
                    "reps": "6-8",
                    "rest_seconds": 120,
                    "notes": "Puxada do chão",
                    "substitution_vector": "Dominante de quadril",
                },
            ],
        },
    ],
}


def test_parse_natural_language_restrictions():
    text = "Aluno com hérnia de disco lombar e condromalácia grave no joelho direito"
    restrictions = cinesiology_engine.parse_natural_language_restrictions(text)
    
    joints = {r.joint for r in restrictions}
    assert JointRegion.LUMBAR_SPINE in joints
    assert JointRegion.KNEE in joints
    
    # Valida severidade grave detectada por palavra-chave 'hérnia' / 'grave'
    assert all(r.severity == JointSeverity.SEVERE for r in restrictions)


def test_evaluate_workout_safety_clean_plan():
    # Sem restrições -> 100% seguro
    report = cinesiology_engine.evaluate_workout_safety(
        workout_plan=SAMPLE_WORKOUT_PLAN,
        restrictions=[],
    )
    assert report.is_safe is True
    assert report.overall_risk == "safe"
    assert report.contraindications_count == 0
    assert len(report.dangerous_exercises) == 0


def test_evaluate_workout_safety_shoulder_and_lumbar():
    # Com restrição no ombro e coluna lombar
    restrictions = [
        JointRestriction(
            joint=JointRegion.SHOULDER,
            severity=JointSeverity.MODERATE,
            conditions=["Impacto Subacromial"],
        ),
        JointRestriction(
            joint=JointRegion.LUMBAR_SPINE,
            severity=JointSeverity.SEVERE,
            conditions=["Hérnia Discal L5-S1"],
        ),
    ]

    report = cinesiology_engine.evaluate_workout_safety(
        workout_plan=SAMPLE_WORKOUT_PLAN,
        restrictions=restrictions,
        auto_apply_substitutes=True,
    )

    assert report.is_safe is False
    assert report.overall_risk == "critical_danger"  # Porque tem lombar severa
    assert report.contraindications_count >= 3  # Supino Reto Barra, Remada Alta, Agachamento Livre, Terra

    ex_names = [d.exercise_name for d in report.dangerous_exercises]
    assert any("Remada Alta" in name for name in ex_names)
    assert any("Agachamento Livre" in name for name in ex_names)
    assert any("Levantamento Terra" in name for name in ex_names)

    # Valida plano adaptado com substitutos automáticos
    assert report.adapted_plan is not None
    adapted_split_b = report.adapted_plan["splits"][1]
    adapted_ex1 = adapted_split_b["exercises"][0]
    
    # O agachamento livre deve ter sido substituído por exercício protetor
    assert "Agachamento Búlgaro" in adapted_ex1["name"] or "Leg Press" in adapted_ex1["name"]
    assert "[Blindagem Articular" in adapted_ex1["notes"]
