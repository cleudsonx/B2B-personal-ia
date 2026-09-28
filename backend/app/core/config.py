import os
import json
from typing import List, Union
from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    PROJECT_NAME: str = "B2B Personal IA Backend"
    ENVIRONMENT: str = "production"
    PORT: int = 8000
    
    # Gemini API Models (gemini-3.6-flash é o modelo oficial ativo)
    GEMINI_API_KEY: str = ""
    DEFAULT_FAST_MODEL: str = "gemini-3.6-flash"
    DEFAULT_DEEP_MODEL: str = "gemini-3.6-flash"
    AIS_GATEWAY_URL: str = "https://ais-dev-3ey6ymjmlzt5sh4qusmboi-873261240850.us-east1.run.app"
    
    # Supabase & Auth
    SUPABASE_URL: str = ""
    SUPABASE_KEY: str = ""
    SUPABASE_JWT_SECRET: str = ""
    
    # CORS (compatível com strings simples "*", JSON '["*"]' ou listas separadas por vírgula)
    CORS_ORIGINS: List[str] = ["*"]

    @field_validator("CORS_ORIGINS", mode="before")
    @classmethod
    def assemble_cors_origins(cls, v: Union[str, List[str]]) -> List[str]:
        if isinstance(v, str):
            v_clean = v.strip()
            if not v_clean or v_clean == "*":
                return ["*"]
            if v_clean.startswith("[") and v_clean.endswith("]"):
                try:
                    parsed = json.loads(v_clean)
                    if isinstance(parsed, list):
                        return [str(item) for item in parsed]
                except Exception:
                    pass
            return [i.strip() for i in v_clean.split(",") if i.strip()]
        elif isinstance(v, list):
            return [str(item) for item in v]
        return ["*"]

    model_config = SettingsConfigDict(
        env_file=[
            os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), ".env"),
            ".env"
        ],
        env_file_encoding="utf-8",
        extra="ignore"
    )


settings = Settings()
