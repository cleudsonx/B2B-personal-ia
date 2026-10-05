from fastapi import APIRouter
from app.api.v1.endpoints import workouts, adaptations, assistant, subscriptions, validators, auth, webhooks, public, whatsapp, whatsapp_ai

api_router = APIRouter()

api_router.include_router(public.router, prefix="/public", tags=["Public"])
api_router.include_router(auth.router, prefix="/auth", tags=["Auth"])
api_router.include_router(workouts.router, prefix="/workouts", tags=["Workouts"])
api_router.include_router(adaptations.router, prefix="/adaptations", tags=["Adaptations"])
api_router.include_router(assistant.router, prefix="/assistant", tags=["Assistant"])
api_router.include_router(subscriptions.router, prefix="/subscriptions", tags=["Subscriptions"])
api_router.include_router(validators.router, prefix="/validators", tags=["Validators"])
api_router.include_router(webhooks.router, prefix="/webhooks", tags=["Webhooks"])
api_router.include_router(whatsapp_ai.router, prefix="/whatsapp", tags=["WhatsApp AI"])
api_router.include_router(whatsapp.router, prefix="/whatsapp", tags=["WhatsApp"])
