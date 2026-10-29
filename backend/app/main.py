import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request, HTTPException
from starlette.exceptions import HTTPException as StarletteHTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from app.core.config import settings
from app.api.v1.router import api_router

logger = logging.getLogger(__name__)


async def _scrub_polluted_synthetic_admins() -> None:
    """
    Em produção, revoga automaticamente qualquer privilégio administrativo acidental
    em contas sintéticas (wa_* / aluno_* / *.internal) não pertencentes aos UUIDs canônicos.
    """
    if settings.ENVIRONMENT.lower() != "production":
        return
    try:
        from app.services.supabase_service import supabase_service
        from app.api.v1.endpoints.subscriptions import (
            CANONICAL_SUPERADMIN_IDS,
            _is_synthetic_provisioned_email,
        )

        client = await supabase_service.get_client()
        if not client:
            return
        res = await client.table("profiles").select("id, email, role, roles, is_admin").eq("is_admin", True).execute()
        for row in (res.data or []):
            rid = str(row.get("id") or "").strip().lower()
            remail = str(row.get("email") or "").strip().lower()
            if rid in CANONICAL_SUPERADMIN_IDS or not _is_synthetic_provisioned_email(remail):
                continue
            r_roles = [str(x).strip().lower() for x in (row.get("roles") or [row.get("role") or "client"]) if x]
            cleaned_roles = [x for x in r_roles if x != "admin"]
            clean_primary = "trainer" if "trainer" in cleaned_roles else "client"
            if not cleaned_roles:
                cleaned_roles = [clean_primary]
            await client.table("profiles").update({
                "role": clean_primary,
                "roles": cleaned_roles,
                "is_admin": False,
                "is_vip": False,
            }).eq("id", row["id"]).execute()
            logger.warning("[Security] Privilégio admin revogado automaticamente da conta sintética %s (%s)", rid, remail)
    except Exception as exc:
        logger.warning("[Security] Auditoria de contas sintéticas no startup ignorada: %s", exc)


@asynccontextmanager
async def _lifespan(_app: FastAPI):
    await _scrub_polluted_synthetic_admins()
    yield


app = FastAPI(
    title=settings.PROJECT_NAME,
    version="1.0.0",
    description="Motor de Inteligência Artificial para Prescrição e Adaptação Biomecânica de Treinos (B2B Personal IA)",
    openapi_url="/api/v1/openapi.json",
    docs_url="/docs",
    redoc_url="/redoc",
    lifespan=_lifespan,
)


# Registrado antes do CORS para ficar dentro dele; senão o 500 sai sem CORS e o navegador mostra só "Failed to fetch".
@app.middleware("http")
async def unhandled_errors_as_json(request: Request, call_next):
    try:
        return await call_next(request)
    except (HTTPException, StarletteHTTPException) as http_exc:
        return JSONResponse(
            status_code=http_exc.status_code,
            content={"detail": http_exc.detail},
            headers=getattr(http_exc, "headers", None),
        )
    except RuntimeError as exc:
        logger.exception("Erro 503 em %s %s: %s", request.method, request.url.path, exc)
        return JSONResponse(status_code=503, content={"detail": str(exc)})
    except Exception as exc:
        logger.exception("Erro não tratado em %s %s: %s", request.method, request.url.path, exc)
        is_prod = settings.ENVIRONMENT.lower() == "production"
        detail = "Erro interno do servidor." if is_prod else f"Erro interno do servidor: {str(exc)}"
        return JSONResponse(status_code=500, content={"detail": detail})

# CORS configuration (conforme padrão W3C/OWASP: se allow_origins contém "*", allow_credentials deve ser False)
cors_origins = settings.cors_origins_list
allow_creds = False if "*" in cors_origins else True

app.add_middleware(
    CORSMiddleware,
    allow_origins=cors_origins,
    allow_credentials=allow_creds,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include API v1 router
app.include_router(api_router, prefix="/api/v1")

from app.api.v1.endpoints.assistant import chat_with_assistant
from app.schemas.assistant import AssistantChatRequest, AssistantChatResponse
from app.api.deps import get_current_user
from typing import Dict, Any
from fastapi import Depends

@app.post("/api/generate", response_model=AssistantChatResponse, tags=["Compatibility"])
async def legacy_generate(
    request: AssistantChatRequest,
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    """Rota direta para compatibilidade com o gateway em nuvem"""
    return await chat_with_assistant(request, current_user)


@app.get("/health", tags=["Health"])
async def health_check():
    return {
        "status": "healthy",
        "service": settings.PROJECT_NAME,
        "environment": settings.ENVIRONMENT
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app.main:app", host="0.0.0.0", port=settings.PORT, reload=True)
