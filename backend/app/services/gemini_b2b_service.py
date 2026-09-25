import os
import requests
from typing import List, Optional, Dict, Any
from dotenv import load_dotenv

load_dotenv()

BASE_URL = os.environ.get(
    "AIS_GATEWAY_URL",
    "https://ais-dev-3ey6ymjmlzt5sh4qusmboi-873261240850.us-east1.run.app"
)


def prescribe_workout_for_student(
    student_name: str,
    goal: str,
    level: str,
    days: int,
    restrictions: List[str]
) -> Dict[str, Any]:
    """
    Gera periodização completa (Splits A, B, C) respeitando lesões articulares
    através do gateway B2B hospedado.
    """
    endpoint = f"{BASE_URL}/api/b2b/prescribe-workout"
    payload = {
        "studentName": student_name,
        "goal": goal,
        "experienceLevel": level,
        "daysPerWeek": days,
        "restrictions": restrictions
    }
    res = requests.post(endpoint, json=payload, timeout=45)
    res.raise_for_status()
    data = res.json()
    return data.get("workoutPlan", data)


def adapt_exercise_in_gym(
    current_exercise: str,
    reason: str,
    pain_location: Optional[str] = None
) -> Dict[str, Any]:
    """
    Botão de Emergência do Aluno: Aparelho ocupado ou Dor articular.
    Substitui em tempo real o exercício no salão de musculação.
    """
    endpoint = f"{BASE_URL}/api/b2b/adapt-exercise"
    payload = {
        "currentExercise": current_exercise,
        "reason": reason,  # "aparelho_ocupado" ou "dor_articular"
        "painLocation": pain_location
    }
    res = requests.post(endpoint, json=payload, timeout=20)
    res.raise_for_status()
    data = res.json()
    return data.get("adaptation", data)


if __name__ == "__main__":
    # Teste 1: Aluno com tendinite no ombro
    print("--- 1. Gerando Treino Personalizado ---")
    try:
        treino = prescribe_workout_for_student(
            student_name="Carlos Silva",
            goal="Hipertrofia",
            level="Intermediário",
            days=4,
            restrictions=[
                "Tendinite no manguito rotador direito",
                "Desconforto na lombar em agachamento livre"
            ]
        )
        print("Treino gerado:", treino.get("summary", treino))
    except Exception as e:
        print(f"Nota de teste (Gateway em inicialização): {e}")

    # Teste 2: Aluno no salão com Leg Press ocupado
    print("\n--- 2. Botão de Emergência (Salão de Musculação) ---")
    try:
        substituicao = adapt_exercise_in_gym(
            current_exercise="Leg Press 45",
            reason="aparelho_ocupado"
        )
        print("Substituto sugerido:", substituicao.get("substitute", {}).get("name", substituicao))
    except Exception as e:
        print(f"Nota de teste (Gateway em inicialização): {e}")
