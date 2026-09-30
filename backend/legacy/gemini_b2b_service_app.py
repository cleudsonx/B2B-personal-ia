# app/services/gemini_b2b_service.py
# Serviço B2B com suporte ao endpoint seguro Cloud Run e modelo gemini-3.6-flash

import os
import requests
from typing import List, Optional, Dict, Any
from dotenv import load_dotenv

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

    res = requests.post(endpoint, json=payload, headers=headers, timeout=timeout)
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
    """Gera periodização completa respeitando restrições articulares."""
    system_instruction = (
        "Você é um especialista em fisiologia do exercício e periodização para Personal Trainers B2B. "
        "Responda estritamente em formato JSON com chaves: studentName, splits, summary."
    )
    prompt = (
        f"Gere um programa de treinamento para o aluno {student_name}.\n"
        f"Objetivo: {goal}\n"
        f"Nível: {level}\n"
        f"Frequência semanal: {days} dias\n"
        f"Restrições: {', '.join(restrictions) if restrictions else 'Nenhuma'}"
    )
    return generate_content(
        prompt=prompt,
        system_instruction=system_instruction,
        model=model,
        temperature=0.4
    )


def adapt_exercise_in_gym(
    current_exercise: str,
    reason: str,
    pain_location: Optional[str] = None,
    model: str = "gemini-3.6-flash"
) -> Dict[str, Any]:
    """Botão de Emergência do Aluno no Salão: Aparelho ocupado ou Dor articular."""
    system_instruction = (
        "Você é o assistente biomecânico de salão de musculação. "
        "Sugira uma substituição imediata que preserve o mesmo vetor motor."
    )
    prompt = (
        f"Substituir exercício: {current_exercise}.\n"
        f"Motivo: {reason}.\n"
        f"Local de dor: {pain_location or 'Nenhum'}."
    )
    return generate_content(
        prompt=prompt,
        system_instruction=system_instruction,
        model=model,
        temperature=0.2
    )
