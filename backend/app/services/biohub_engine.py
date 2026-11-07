import math
from typing import Dict, List, Optional, Tuple, Any
from app.schemas.biohub import (
    ReadinessLevel,
    MuscleGroup,
    RecoveryStatus,
    DailyBiometricLog,
    ReadinessScore,
    MuscleRecoveryItem,
    MuscleRecoveryReport,
    StrengthPrItem,
    DeloadRecommendation,
)


class BioHubEngine:
    """
    Motor Fisiológico Determinístico O(1) do Bio-Hub 3.0.
    Implementa modelos cinéticos de prontidão neuromuscular, fórmulas consagradas
    de 1RM (Brzycki & Epley) e janelas de recomposição miofibrilar sem custo de LLM.
    """

    # Janelas fisiológicas base de recomposição por grupamento (em horas)
    MUSCLE_RECOVERY_HOURS: Dict[MuscleGroup, int] = {
        MuscleGroup.CHEST: 48,
        MuscleGroup.BACK: 60,
        MuscleGroup.QUADRICEPS: 72,
        MuscleGroup.HAMSTRINGS_GLUTES: 72,
        MuscleGroup.SHOULDERS: 48,
        MuscleGroup.ARMS_CORE: 36,
    }

    MUSCLE_LABELS: Dict[MuscleGroup, str] = {
        MuscleGroup.CHEST: "Peitoral",
        MuscleGroup.BACK: "Dorsais / Costas",
        MuscleGroup.QUADRICEPS: "Quadríceps",
        MuscleGroup.HAMSTRINGS_GLUTES: "Posterior & Glúteos",
        MuscleGroup.SHOULDERS: "Ombros / Deltoides",
        MuscleGroup.ARMS_CORE: "Braços & Core",
    }

    # =========================================================================
    # 1. CÁLCULO DE 1RM & VOLUME LOAD
    # =========================================================================
    @staticmethod
    def calculate_1rm(
        weight_kg: float,
        reps: int,
        preferred_formula: str = "brzycki",
    ) -> Tuple[float, str]:
        """
        Calcula a Carga Máxima Teórica (1RM estimado).
        - Para 1 repetição, retorna a própria carga.
        - Para 2 a 10 reps, utiliza preferencialmente Brzycki: 1RM = peso / (1.0278 - 0.0278 * reps).
        - Para > 10 reps, utiliza Epley para maior precisão em altas repetições: 1RM = peso * (1 + reps / 30).
        """
        if weight_kg <= 0 or reps <= 0:
            return (0.0, preferred_formula)

        if reps == 1:
            return (round(weight_kg, 1), "direct")

        if reps <= 10 and preferred_formula.lower() == "brzycki":
            denom = 1.0278 - (0.0278 * reps)
            if denom > 0:
                est = weight_kg / denom
                return (round(est, 1), "brzycki")

        # Epley como padrão acima de 10 reps ou fallback
        est = weight_kg * (1.0 + (reps / 30.0))
        return (round(est, 1), "epley")

    @staticmethod
    def calculate_volume_load(weight_kg: float, reps: int, sets: int = 1) -> float:
        """Calcula o Volume Load da série ou exercício (Peso * Repetições * Séries)."""
        if weight_kg < 0 or reps < 0 or sets < 0:
            return 0.0
        return round(weight_kg * reps * sets, 1)

    # =========================================================================
    # 2. SCORE DIÁRIO DE PRONTIDÃO (READINESS SCORE 0 A 100)
    # =========================================================================
    def calculate_readiness_score(
        self,
        biometrics: Optional[DailyBiometricLog] = None,
        avg_recent_rpe: Optional[float] = None,
        consecutive_training_days: int = 0,
        has_joint_pain: bool = False,
    ) -> ReadinessScore:
        """
        Calcula o Score Diário de Prontidão (0 a 100) cruzando:
        - Baseline fisiológico: 85 pontos
        - Sono (quantidade e qualidade): -22 a +5 pontos
        - Fadiga de RPE recente (48-72h): -20 a +5 pontos
        - Dores ou inflamações articulares: -15 pontos
        - Sobrecarga de dias consecutivos sem descanso: -20 a 0 pontos
        """
        log = biometrics or DailyBiometricLog()
        sleep_hours = log.sleep_hours if log.sleep_hours is not None else 7.5
        sleep_quality = log.sleep_quality if log.sleep_quality is not None else 4
        stress = log.perceived_stress if log.perceived_stress is not None else 2
        soreness = log.soreness_level if log.soreness_level is not None else 2
        has_joint_pain = has_joint_pain or log.has_joint_pain

        # 1. Fator Sono
        sleep_factor = 0.0
        if sleep_hours >= 8.0:
            sleep_factor = 5.0
        elif sleep_hours >= 7.0:
            sleep_factor = 2.0
        elif sleep_hours >= 6.0:
            sleep_factor = -5.0
        elif sleep_hours >= 5.0:
            sleep_factor = -12.0
        else:
            sleep_factor = -20.0

        if sleep_quality <= 2:
            sleep_factor -= 4.0

        # 2. Fator Fadiga Acumulada RPE
        fatigue_factor = 0.0
        if avg_recent_rpe is not None:
            if avg_recent_rpe <= 6.0:
                fatigue_factor = 5.0
            elif avg_recent_rpe <= 7.5:
                fatigue_factor = 0.0
            elif avg_recent_rpe <= 8.5:
                fatigue_factor = -10.0
            else:
                fatigue_factor = -20.0

        # 3. Fator Dor Articular
        joint_factor = -15.0 if has_joint_pain else 0.0

        # 4. Fator Streak sem Descanso
        streak_factor = 0.0
        if consecutive_training_days >= 4:
            streak_factor = -20.0
        elif consecutive_training_days == 3:
            streak_factor = -10.0

        # Modificadores de estresse e dor muscular
        extra_modifier = 0.0
        if stress >= 4:
            extra_modifier -= 4.0
        if soreness >= 4:
            extra_modifier -= 4.0

        raw_score = 85.0 + sleep_factor + fatigue_factor + joint_factor + streak_factor + extra_modifier
        score = int(max(10, min(100, round(raw_score))))

        # Classificação e Mensagens
        if score >= 80:
            level = ReadinessLevel.HIGH
            headline = "🚀 Prontidão Neuromuscular Máxima!"
            recommendation = (
                "Sistema neuromuscular plenamente recuperado. Momento propício para "
                "buscar quebra de recorde (PR) ou séries de alta intensidade (RPE 8.5 - 9.5)."
            )
        elif score >= 60:
            level = ReadinessLevel.MODERATE
            headline = "⚡ Prontidão Estável e Equilibrada"
            recommendation = (
                "Corpo em boa resposta adaptativa. Execute a planilha programada "
                "mantendo foco na execução técnica e cargas de treino sólidas (RPE 7.0 - 8.0)."
            )
        elif score >= 40:
            level = ReadinessLevel.LOW
            headline = "⚠️ Atenção: Fadiga Residual Detectada"
            recommendation = (
                "Sinais de cansaço acumulado ou sono abaixo do ideal. Recomendamos limitar o RPE em 7.5, "
                "evitar falhas concêntricas forçadas e priorizar exercícios guiados."
            )
        else:
            level = ReadinessLevel.CRITICAL
            headline = "🛑 Alerta de Fadiga Central / Risco de Lesão"
            recommendation = (
                "Fadiga acentuada do SNC ou dor articular ativa. Indicado descanso ativo leve, "
                "mobilidade articular ou semana regenerativa (Deload)."
            )

        return ReadinessScore(
            score=score,
            level=level,
            headline=headline,
            recommendation=recommendation,
            sleep_factor=sleep_factor,
            fatigue_factor=fatigue_factor,
            joint_factor=joint_factor,
            streak_factor=streak_factor,
        )

    # =========================================================================
    # 3. MAPA DE RECUPERAÇÃO MUSCULAR POR GRUPAMENTO
    # =========================================================================
    def calculate_muscle_recovery(
        self,
        last_trained_hours_map: Dict[MuscleGroup, float],
        intensity_boost_map: Optional[Dict[MuscleGroup, float]] = None,
    ) -> MuscleRecoveryReport:
        """
        Calcula o percentual de recuperação fisiológica de cada grupo muscular
        com base no tempo decorrido desde a última sessão e o teto necessário de reparo.
        """
        items: List[MuscleRecoveryItem] = []
        ready_count = 0
        fatigued_count = 0
        total_pct = 0

        for group in MuscleGroup:
            required_hours = float(self.MUSCLE_RECOVERY_HOURS.get(group, 48))
            
            # Se a última sessão foi de altíssima intensidade (RPE 9+), adiciona 12h de reparo
            if intensity_boost_map and intensity_boost_map.get(group, 0) >= 9.0:
                required_hours += 12.0

            hours_ago = last_trained_hours_map.get(group)

            if hours_ago is None or hours_ago >= required_hours:
                # Totalmente recuperado
                pct = 100
                status = RecoveryStatus.RECOVERED
                hours_left = 0
            else:
                raw_pct = (hours_ago / required_hours) * 100.0
                pct = int(max(15, min(99, round(raw_pct))))
                hours_left = int(max(1, round(required_hours - hours_ago)))
                
                if pct < 50:
                    status = RecoveryStatus.FATIGUED
                else:
                    status = RecoveryStatus.RECOVERING

            if status == RecoveryStatus.RECOVERED:
                ready_count += 1
            elif status == RecoveryStatus.FATIGUED:
                fatigued_count += 1

            total_pct += pct

            items.append(
                MuscleRecoveryItem(
                    muscle_group=group,
                    label=self.MUSCLE_LABELS[group],
                    recovery_percentage=pct,
                    status=status,
                    last_trained_hours_ago=hours_ago,
                    hours_until_recovered=hours_left,
                )
            )

        overall_pct = int(round(total_pct / len(MuscleGroup))) if MuscleGroup else 100

        if overall_pct >= 85:
            summary = "Corpo amplamente regenerado e pronto para demandas de alta carga."
        elif overall_pct >= 60:
            summary = "Recuperação intermediária. Treine os grupos verdes e poupe os fatigados."
        else:
            summary = "Múltiplos grupos musculares em regeneração. Priorize descanso e nutrição."

        return MuscleRecoveryReport(
            overall_recovery_percentage=overall_pct,
            muscles=items,
            ready_muscles_count=ready_count,
            fatigued_muscles_count=fatigued_count,
            summary=summary,
        )

    # =========================================================================
    # 4. AVALIAÇÃO DE DELOAD INTELIGENTE
    # =========================================================================
    @staticmethod
    def evaluate_deload_need(
        recent_rpe_list: List[float],
        consecutive_low_readiness_days: int = 0,
        volume_spike_pct: float = 0.0,
    ) -> DeloadRecommendation:
        """
        Determina a necessidade de uma semana regenerativa (Deload) a partir de:
        - 3 ou mais sessões consecutivas com RPE >= 9.0
        - 3 ou mais dias consecutivos com Readiness < 50
        - Picos abruptos de volume semanal >= 35% acima da média base
        """
        reasons: List[str] = []
        should_deload = False
        urgency = "none"

        # 1. Fadiga severa por RPE consecutivo
        high_rpe_count = sum(1 for rpe in recent_rpe_list[-4:] if rpe >= 9.0)
        if high_rpe_count >= 3:
            should_deload = True
            reasons.append(f"{high_rpe_count} sessões recentes executadas em esforço extremo (RPE >= 9.0)")

        # 2. Prontidão cronicamente deprimida
        if consecutive_low_readiness_days >= 3:
            should_deload = True
            reasons.append(f"{consecutive_low_readiness_days} dias seguidos com prontidão neuromuscular crítica (<50)")

        # 3. Salto volumétrico abrupto
        if volume_spike_pct >= 35.0:
            should_deload = True
            reasons.append(f"Pico de volume semanal excessivo (+{volume_spike_pct:.0f}% sobre a média adaptada)")

        if should_deload:
            urgency = "high" if len(reasons) >= 2 else "moderate"

        return DeloadRecommendation(
            should_deload=should_deload,
            urgency=urgency,
            reasons=reasons,
            recommended_volume_reduction_pct=35,
            recommended_rpe_cap=7,
        )


biohub_engine = BioHubEngine()
