import os
import json
from typing import Optional
from google import genai
from google.genai import types
from app.core.config import settings
from app.schemas.workout import WorkoutPlanResponse
from app.schemas.adaptation import AdaptationResponse
from app.prompts.plan_generator import SYSTEM_INSTRUCTION_PLAN_GENERATOR, build_plan_prompt
from app.prompts.exercise_adapter import SYSTEM_INSTRUCTION_EXERCISE_ADAPTER, build_adaptation_prompt


class GeminiService:
    def __init__(self):
        api_key = settings.GEMINI_API_KEY or os.environ.get("GEMINI_API_KEY")
        if api_key:
            self.client = genai.Client(api_key=api_key)
        else:
            self.client = None

    def _ensure_client(self):
        if not self.client:
            # Check if environment variable was loaded dynamically
            api_key = os.environ.get("GEMINI_API_KEY") or settings.GEMINI_API_KEY
            if api_key:
                self.client = genai.Client(api_key=api_key)
            else:
                raise ValueError(
                    "GEMINI_API_KEY não configurada. Configure a variável no arquivo .env ou no ambiente."
                )

    async def generate_workout_plan(
        self,
        objective: str,
        training_level: str,
        days_per_week: int,
        workout_location: str,
        injuries_or_restrictions: str,
        additional_notes: Optional[str] = None,
        model_name: Optional[str] = None
    ) -> WorkoutPlanResponse:
        self._ensure_client()
        model = model_name or settings.DEFAULT_DEEP_MODEL

        prompt_text = build_plan_prompt(
            objective=objective,
            training_level=training_level,
            days_per_week=days_per_week,
            workout_location=workout_location,
            injuries_or_restrictions=injuries_or_restrictions,
            additional_notes=additional_notes or ""
        )

        config = types.GenerateContentConfig(
            system_instruction=SYSTEM_INSTRUCTION_PLAN_GENERATOR,
            response_mime_type="application/json",
            response_schema=WorkoutPlanResponse,
            temperature=0.2, # Low temperature for biomechanical stability and consistency
        )

        response = self.client.models.generate_content(
            model=model,
            contents=prompt_text,
            config=config,
        )

        if not response.text:
            raise RuntimeError("A API do Gemini retornou uma resposta vazia.")

        return WorkoutPlanResponse.model_validate_json(response.text)

    async def adapt_exercise(
        self,
        current_exercise: str,
        reason: str,
        workout_location: str,
        injuries_or_restrictions: str,
        model_name: Optional[str] = None
    ) -> AdaptationResponse:
        self._ensure_client()
        # Uses ultra-fast flash model for 1-second gym floor execution
        model = model_name or settings.DEFAULT_FAST_MODEL

        prompt_text = build_adaptation_prompt(
            current_exercise=current_exercise,
            reason=reason,
            workout_location=workout_location,
            injuries_or_restrictions=injuries_or_restrictions
        )

        config = types.GenerateContentConfig(
            system_instruction=SYSTEM_INSTRUCTION_EXERCISE_ADAPTER,
            response_mime_type="application/json",
            response_schema=AdaptationResponse,
            temperature=0.1, # Minimized creativity for strict biomechanical equivalence
        )

        response = self.client.models.generate_content(
            model=model,
            contents=prompt_text,
            config=config,
        )

        if not response.text:
            raise RuntimeError("A API do Gemini retornou uma resposta vazia.")

        return AdaptationResponse.model_validate_json(response.text)


gemini_service = GeminiService()
