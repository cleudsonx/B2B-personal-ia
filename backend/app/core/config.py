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

    # Segurança Cibernética & Split Payment (Resolução BCB nº 4.893)
    FINANCIAL_SIGNING_SECRET: str = ""
    FINANCIAL_JWS_ISSUER: str = "shapelab-financial-core"
    MTLS_CLIENT_CERT_PATH: str = ""
    MTLS_CLIENT_KEY_PATH: str = ""
    MTLS_CA_CERT_PATH: str = ""
    FINANCIAL_AUDIT_ENABLED: bool = True

    # WhatsApp / Evolution API (sem valor padrão — configurar como secret no Render)
    WHATSAPP_PROVIDER: str = "evolution"
    EVOLUTION_API_KEY: str = ""
    EVOLUTION_API_URL: str = "http://193.123.123.34:8080"
    EVOLUTION_INSTANCE: str = "mr_coach_instance"
    PLATFORM_WHATSAPP_NUMBER: str = "5561991497852"
    # Segredo que a Evolution envia no header "apikey" do webhook (obrigatorio p/ ativar o Consultor IA)
    EVOLUTION_WEBHOOK_TOKEN: str = "mrcoach_evolution_webhook_sec_2026_tok"
    # URL publica do backend, usada para registrar o webhook na Evolution
    PUBLIC_BACKEND_URL: str = "https://b2b-personal-ia-backend.onrender.com"

    # WhatsApp Oficial (Meta Cloud API / Graph API)
    META_WA_PHONE_NUMBER_ID: str = ""
    META_WA_ACCESS_TOKEN: str = ""
    META_WA_BUSINESS_ACCOUNT_ID: str = ""
    META_WA_API_VERSION: str = "v21.0"
    META_WA_WEBHOOK_VERIFY_TOKEN: str = "mrcoach_meta_webhook_verify_sec_tok"
    
    # CORS (aceita string "*", JSON '["*"]' ou listas sem erro no EnvSettingsSource do Pydantic)
    CORS_ORIGINS: Union[str, List[str]] = "*"

    @property
    def cors_origins_list(self) -> List[str]:
        production_origins = [
            "https://shaipados.com",
            "https://www.shaipados.com",
            "https://shaipados-labs.web.app",
            "https://shaipados-labs.firebaseapp.com",
            "https://mrcoach.shaipados.com",
            "https://mrcoach.app",
            "https://app.shaipados.com",
            "https://shapelab.ia.br",
            "https://www.shapelab.ia.br",
            "https://app.shapelab.ia.br",
            "https://mrcoach.shapelab.ia.br",
        ]
        shapelab_domains = [
            "https://shapelab.ia.br",
            "https://www.shapelab.ia.br",
            "https://app.shapelab.ia.br",
            "https://mrcoach.shapelab.ia.br",
            "https://shaipados-labs.firebaseapp.com",
        ]

        def _enrich_production_origins(origins: List[str]) -> List[str]:
            """Garante suporte Dual-Domain (shaipados.com + shapelab.ia.br) em produção."""
            if self.ENVIRONMENT.lower() == "production" and "https://shaipados.com" in origins:
                for domain in shapelab_domains:
                    if domain not in origins:
                        origins.append(domain)
            return origins

        val = self.CORS_ORIGINS
        if isinstance(val, list):
            origins = [str(item) for item in val]
            if "*" in origins and self.ENVIRONMENT.lower() == "production":
                return production_origins
            return _enrich_production_origins(origins)
        if isinstance(val, str):
            v_clean = val.strip()
            if not v_clean or v_clean == "*":
                if self.ENVIRONMENT.lower() == "production":
                    return production_origins
                return ["*"]
            if v_clean.startswith("[") and v_clean.endswith("]"):
                try:
                    parsed = json.loads(v_clean)
                    if isinstance(parsed, list):
                        origins = [str(item) for item in parsed]
                        if "*" in origins and self.ENVIRONMENT.lower() == "production":
                            return production_origins
                        return _enrich_production_origins(origins)
                except Exception:
                    pass
            origins = [i.strip() for i in v_clean.split(",") if i.strip()]
            if "*" in origins and self.ENVIRONMENT.lower() == "production":
                return production_origins
            return _enrich_production_origins(origins)
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
