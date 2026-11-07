import pytest
from app.schemas.biohub import (
    ReadinessLevel,
    MuscleGroup,
    RecoveryStatus,
    DailyBiometricLog,
)
from app.services.biohub_engine import biohub_engine


def test_calculate_1rm_and_volume_load():
    # 1 repetição direta
    one_rm, formula = biohub_engine.calculate_1rm(100.0, 1)
    assert one_rm == 100.0
    assert formula == "direct"

    # 5 repetições (Brzycki)
    one_rm_5, formula_5 = biohub_engine.calculate_1rm(100.0, 5)
    # 100 / (1.0278 - 0.0278 * 5) = 100 / 0.8888 ~= 112.5
    assert 112.0 <= one_rm_5 <= 113.0
    assert formula_5 == "brzycki"

    # 12 repetições (Epley para > 10 reps)
    one_rm_12, formula_12 = biohub_engine.calculate_1rm(100.0, 12)
    # 100 * (1 + 12 / 30) = 140.0
    assert one_rm_12 == 140.0
    assert formula_12 == "epley"

    # Volume load (Peso * Reps * Sets)
    vol = biohub_engine.calculate_volume_load(100.0, 10, 4)
    assert vol == 4000.0


def test_calculate_readiness_score_high_and_critical():
    # 1. Caso Alta Prontidão (Sono ideal, RPE leve, sem dor articular, sem streak abusivo)
    bio_good = DailyBiometricLog(
        sleep_hours=8.5,
        sleep_quality=5,
        perceived_stress=1,
        soreness_level=1,
        has_joint_pain=False,
    )
    score_good = biohub_engine.calculate_readiness_score(
        biometrics=bio_good,
        avg_recent_rpe=6.0,
        consecutive_training_days=1,
        has_joint_pain=False,
    )
    assert score_good.score >= 80
    assert score_good.level == ReadinessLevel.HIGH
    assert "Prontidão Neuromuscular Máxima" in score_good.headline

    # 2. Caso Fadiga Extrema (Pouco sono, RPE pesadíssimo, dor articular ativa, 4 dias direto)
    bio_bad = DailyBiometricLog(
        sleep_hours=4.0,
        sleep_quality=1,
        perceived_stress=5,
        soreness_level=5,
        has_joint_pain=True,
    )
    score_bad = biohub_engine.calculate_readiness_score(
        biometrics=bio_bad,
        avg_recent_rpe=9.5,
        consecutive_training_days=4,
        has_joint_pain=True,
    )
    assert score_bad.score <= 40
    assert score_bad.level in [ReadinessLevel.LOW, ReadinessLevel.CRITICAL]
    assert score_bad.joint_factor == -15.0
    assert score_bad.streak_factor == -20.0


def test_calculate_muscle_recovery_kinetics():
    # Peitoral treinado há 6 horas (ainda em forte fadiga)
    # Costas treinadas há 65 horas (totalmente recuperadas para teto de 60h)
    last_trained = {
        MuscleGroup.CHEST: 6.0,
        MuscleGroup.BACK: 65.0,
        MuscleGroup.QUADRICEPS: 12.0,
    }

    report = biohub_engine.calculate_muscle_recovery(last_trained)

    # Localiza o peitoral
    chest_item = next(m for m in report.muscles if m.muscle_group == MuscleGroup.CHEST)
    assert chest_item.status == RecoveryStatus.FATIGUED
    assert chest_item.recovery_percentage < 50
    assert chest_item.hours_until_recovered > 0

    # Localiza as costas
    back_item = next(m for m in report.muscles if m.muscle_group == MuscleGroup.BACK)
    assert back_item.status == RecoveryStatus.RECOVERED
    assert back_item.recovery_percentage == 100
    assert back_item.hours_until_recovered == 0

    assert report.ready_muscles_count >= 1
    assert report.fatigued_muscles_count >= 1


def test_evaluate_deload_need():
    # 1. Aluno com 3 treinos extremos seguidos de RPE 9.5
    recent_rpes = [9.5, 9.0, 9.5, 9.0]
    rec = biohub_engine.evaluate_deload_need(recent_rpe_list=recent_rpes)
    assert rec.should_deload is True
    assert rec.urgency in ["moderate", "high"]
    assert any("esforço extremo" in r for r in rec.reasons)

    # 2. Aluno com rotina equilibrada (RPE 7.0 a 8.0)
    normal_rpes = [7.0, 7.5, 8.0, 7.0]
    rec_normal = biohub_engine.evaluate_deload_need(recent_rpe_list=normal_rpes)
    assert rec_normal.should_deload is False
    assert rec_normal.urgency == "none"
