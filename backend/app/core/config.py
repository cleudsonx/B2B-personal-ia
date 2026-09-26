import os
from typing import List, Union
from pydantic import AnyHttpUrl, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    PROJECT_NAME: str = "B2B Personal IA Backend"
    ENVIRONMENT: str = "development"
    PORT: int = 8000
    
    # Gemini API Models (3.8 Flash é o modelo oficial ativo com cota no Google AI Studio)
    GEMINI_API_KEY: str = ""
    DEFAULT_FAST_MODEL: str = "gemini-3.8-flash"
    DEFAULT_DEEP_MODEL: str = "gemini-3.8-flash"
    AIS_GATEWAY_URL: str = "https://ais-dev-3ey6ymjmlzt5sh4qusmboi-873261240850.us-east1.run.app"
    
    # Supabase & Auth
    SUPABASE_URL: str = ""
    SUPABASE_KEY: str = ""
    SUPABASE_JWT_SECRET: str = ""
    
    # CORS
    CORS_ORIGINS: List[str] = ["*"]

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore"
    )


settings = Settings()
