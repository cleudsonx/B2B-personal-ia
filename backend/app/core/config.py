import os
from typing import List, Union
from pydantic import AnyHttpUrl, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    PROJECT_NAME: str = "B2B Personal IA Backend"
    ENVIRONMENT: str = "development"
    PORT: int = 8000
    
    # Gemini API Models (Flash para trocas instantâneas no salão; Pro para periodização completa)
    DEFAULT_FAST_MODEL: str = "gemini-2.5-flash"
    DEFAULT_DEEP_MODEL: str = "gemini-2.5-pro"
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
