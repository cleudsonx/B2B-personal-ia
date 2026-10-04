import os
import json
from typing import List, Union
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    PROJECT_NAME: str = "B2B Personal IA Backend"
    ENVIRONMENT: str = "production"
    PORT: int = 8000
    
    # Gemini API Models (gemini-2.5-flash é o modelo oficial ativo)
    GEMINI_API_KEY: str = ""
    DEFAULT_FAST_MODEL: str = "gemini-2.5-flash"
    DEFAULT_DEEP_MODEL: str = "gemini-2.5-flash"
    AIS_GATEWAY_URL: str = "https://ais-dev-3ey6ymjmlzt5sh4qusmboi-873261240850.us-east1.run.app"
    
    # Supabase & Auth
    SUPABASE_URL: str = "https://rgbyfiulomxpqkuufdtg.supabase.co"
    SUPABASE_PUBLISHABLE_KEY: str = "sb_publishable_GM85tixsI7l1WTU3jhEmoQ_s_pv_F6C"
    SUPABASE_SECRET_KEY: str = "" # Injetado via .env / Environment Variables
    SUPABASE_KEY: str = ""        # Alias retrocompatível
    SUPABASE_JWT_SECRET: str = ""
    SUPABASE_JWKS_URL: str = "https://rgbyfiulomxpqkuufdtg.supabase.co/auth/v1/.well-known/jwks.json"
    
    # E-mail & Resend
    RESEND_API_KEY: str = ""
    EMAIL_FROM: str = "Mr. Coach <contato@shaipados.com>"
    APP_FRONTEND_URL: str = "https://shaipados.com"
    APP_BACKEND_URL: str = "https://api.shaipados.com"

    # InfinitePay Gateway
    INFINITEPAY_HANDLE: str = "sheipados"
    INFINITEPAY_CHECKOUT_API_URL: str = "https://api.checkout.infinitepay.io"
    INFINITEPAY_WEBHOOK_SECRET: str = ""

    # Asaas Gateway & Webhooks
    ASAAS_API_KEY: str = ""
    ASAAS_API_URL: str = "https://sandbox.asaas.com/api/v3"
    ASAAS_WEBHOOK_TOKEN: str = ""
    MERCADOPAGO_WEBHOOK_SECRET: str = ""
    STRIPE_WEBHOOK_SECRET: str = ""

    # WhatsApp / Evolution API (sem valor padrão — configurar como secret no Render)
    EVOLUTION_API_KEY: str = ""
    EVOLUTION_API_URL: str = "http://193.123.123.34:8080"
    EVOLUTION_INSTANCE: str = "mr_coach_instance"
    
    # CORS (aceita string "*", JSON '["*"]' ou listas sem erro no EnvSettingsSource do Pydantic)
    CORS_ORIGINS: Union[str, List[str]] = "*"

    @property
    def cors_origins_list(self) -> List[str]:
        val = self.CORS_ORIGINS
        if isinstance(val, list):
            origins = [str(item) for item in val]
            if "*" in origins and self.ENVIRONMENT.lower() == "production":
                return ["https://shaipados.com"]
            return origins
        if isinstance(val, str):
            v_clean = val.strip()
            if not v_clean or v_clean == "*":
                if self.ENVIRONMENT.lower() == "production":
                    return ["https://shaipados.com"]
                return ["*"]
            if v_clean.startswith("[") and v_clean.endswith("]"):
                try:
                    parsed = json.loads(v_clean)
                    if isinstance(parsed, list):
                        origins = [str(item) for item in parsed]
                        if "*" in origins and self.ENVIRONMENT.lower() == "production":
                            return ["https://shaipados.com"]
                        return origins
                except Exception:
                    pass
            origins = [i.strip() for i in v_clean.split(",") if i.strip()]
            if "*" in origins and self.ENVIRONMENT.lower() == "production":
                return ["https://shaipados.com"]
            return origins
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
