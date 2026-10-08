# gemini_b2b_service.py
# Integração oficial para Personal Trainers & Alunos com o modelo gemini-3.6-flash
# pip install requests python-dotenv

import os
import sys
import json
import requests
from typing import Optional, Dict, Any, List
from dotenv import load_dotenv

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

load_dotenv()

BASE_URL = os.environ.get(
    "AIS_GATEWAY_URL",
    "https://ais-dev-3ey6ymjmlzt5sh4qusmboi-873261240850.us-east1.run.app"
).rstrip("/")


def generate_content(
    prompt: str,
    system_instruction: Optional[str] = None,
    model: str = "gemini-3.6-flash",
    temperature: float = 0.7,
    timeout: int = 30
) -> Dict[str, Any]:
    """
    Executa chamada ao endpoint seguro Cloud Run /api/generate utilizando o modelo gemini-3.6-flash.

    Suporta:
    - Chamada simples: apenas prompt, model e temperature.
    - Persona / Instrução de Sistema: através de systemInstruction.
    """
    endpoint = f"{BASE_URL}/api/generate"
    headers = {"Content-Type": "application/json"}

    payload = {
        "prompt": prompt,
        "model": model,
        "temperature": temperature
    }
    if system_instruction:
        payload["systemInstruction"] = system_instruction

    try:
        # Timeout curto de 3s para o gateway em nuvem para garantir resposta fluida
        res = requests.post(endpoint, json=payload, headers=headers, timeout=min(timeout, 3), allow_redirects=False)
        if res.status_code == 200 and "application/json" in res.headers.get("content-type", ""):
            return res.json()
    except Exception:
        pass

    # Fallback automático para o backend oficial local com alta disponibilidade
    local_endpoint = "http://localhost:8000/api/v1/assistant/generate"
    res = requests.post(local_endpoint, json=payload, headers=headers, timeout=timeout)
    res.raise_for_status()
    return res.json()


def prescribe_workout_for_student(
    student_name: str,
    goal: str,
    level: str,
    days: int,
    restrictions: List[str],
    model: str = "gemini-3.6-flash"
) -> Dict[str, Any]:
    """Gera periodização completa (Splits A, B, C) respeitando restrições articulares."""
    system_instruction = (
        "Você é um especialista em fisiologia do exercício e periodização para Personal Trainers B2B. "
        "Responda estritamente em formato JSON com chaves: studentName, splits, summary."
    )
    prompt = (
        f"Gere um programa de treinamento personalizado para o aluno {student_name}.\n"
        f"Objetivo: {goal}\n"
        f"Nível: {level}\n"
        f"Frequência semanal: {days} dias\n"
        f"Restrições e Lesões: {', '.join(restrictions) if restrictions else 'Nenhuma'}\n"
    )

    response_data = generate_content(
        prompt=prompt,
        system_instruction=system_instruction,
        model=model,
        temperature=0.4
    )
    return response_data


def adapt_exercise_in_gym(
    current_exercise: str,
    reason: str,
    pain_location: Optional[str] = None,
    model: str = "gemini-3.6-flash"
) -> Dict[str, Any]:
    """Botão de Emergência do Aluno no Salão: Aparelho ocupado ou Dor articular."""
    system_instruction = (
        "Você é o assistente biomecânico de salão de musculação. "
        "Sugira uma substituição imediata que preserve o mesmo vetor motor. "
        "Responda em formato JSON com chaves: original_exercise, substitute, rationale, execution_cues."
    )
    prompt = (
        f"O aluno precisa substituir o exercício: {current_exercise}.\n"
        f"Motivo: {reason}.\n"
        f"Local da dor/desconforto: {pain_location or 'Nenhum'}.\n"
        f"Indique o melhor substituto biomecânico seguro."
    )

    response_data = generate_content(
        prompt=prompt,
        system_instruction=system_instruction,
        model=model,
        temperature=0.2
    )
    return response_data


if __name__ == "__main__":
    print("=" * 60)
    print("[TEST] Endpoint Seguro Gemini: gemini-3.6-flash")
    print(f"Gateway: {BASE_URL}/api/generate")
    print("=" * 60)

    # 1. Chamada simples ao endpoint seguro
    print("\n--- 1. Chamada Simples (Prompt Básico) ---")
    try:
        res1 = generate_content(
            prompt="Olá Gemini! Como você pode me ajudar hoje?",
            model="gemini-3.6-flash",
            temperature=0.7
        )
        print("Resposta:", res1.get("text", res1))
    except Exception as e:
        print(f"Nota (Conexão Gateway): {e}")

    # 2. Exemplo com Instrução de Sistema (Persona)
    print("\n--- 2. Exemplo com Instrução de Sistema (Persona) ---")
    try:
        res2 = generate_content(
            prompt="Explique microsserviços em 3 tópicos.",
            system_instruction="Você é um professor universitário conciso.",
            model="gemini-3.6-flash",
            temperature=0.5
        )
        print("Resposta:", res2.get("text", res2))
    except Exception as e:
        print(f"Nota (Conexão Gateway): {e}")

    # 3. Exemplo B2B de Adaptação Biomecânica
    print("\n--- 3. Exemplo B2B: Adaptação Biomecânica no Salão ---")
    try:
        res3 = adapt_exercise_in_gym(
            current_exercise="Leg Press 45",
            reason="aparelho_ocupado",
            model="gemini-3.6-flash"
        )
        print("Substituição:", res3.get("text", res3))
    except Exception as e:
        print(f"Nota (Conexão Gateway): {e}")
