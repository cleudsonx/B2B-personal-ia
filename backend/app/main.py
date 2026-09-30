from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.core.config import settings
from app.api.v1.router import api_router

app = FastAPI(
    title=settings.PROJECT_NAME,
    version="1.0.0",
    description="Motor de Inteligência Artificial para Prescrição e Adaptação Biomecânica de Treinos (B2B Personal IA)",
    openapi_url="/api/v1/openapi.json",
    docs_url="/docs",
    redoc_url="/redoc"
)

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

@app.post("/api/generate", response_model=AssistantChatResponse, tags=["Compatibility"])
async def legacy_generate(request: AssistantChatRequest):
    """Rota direta para compatibilidade com o gateway em nuvem"""
    return await chat_with_assistant(request)


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
