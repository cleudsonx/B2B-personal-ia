from typing import Dict, Any
from fastapi import Depends
from app.core.security import get_current_user_payload
from app.services.gemini_service import gemini_service, GeminiService


def get_current_user(payload: Dict[str, Any] = Depends(get_current_user_payload)) -> Dict[str, Any]:
    return payload


def get_gemini_service() -> GeminiService:
    return gemini_service
