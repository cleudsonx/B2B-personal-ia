from fastapi import APIRouter
from app.api.v1.endpoints import (
    workouts, adaptations, assistant, subscriptions, validators,
    auth, webhooks, public, whatsapp, whatsapp_ai, invites,
    exercises, wallet, consultancy_plans, student_pulse, notifications
)

api_router = APIRouter()

api_router.include_router(public.router, prefix="/public", tags=["Public"])
api_router.include_router(auth.router, prefix="/auth", tags=["Auth"])
api_router.include_router(invites.router, prefix="/invites", tags=["Invites"])
api_router.include_router(workouts.router, prefix="/workouts", tags=["Workouts"])
api_router.include_router(exercises.router, prefix="/exercises", tags=["Exercises"])
api_router.include_router(adaptations.router, prefix="/adaptations", tags=["Adaptations"])
api_router.include_router(assistant.router, prefix="/assistant", tags=["Assistant"])
api_router.include_router(student_pulse.router, prefix="/pulse", tags=["Student Pulse"])
api_router.include_router(notifications.router, prefix="/notifications", tags=["Notifications"])
api_router.include_router(subscriptions.router, prefix="/subscriptions", tags=["Subscriptions"])
api_router.include_router(validators.router, prefix="/validators", tags=["Validators"])
api_router.include_router(webhooks.router, prefix="/webhooks", tags=["Webhooks"])
api_router.include_router(whatsapp_ai.router, prefix="/whatsapp", tags=["WhatsApp AI"])
api_router.include_router(whatsapp.router, prefix="/whatsapp", tags=["WhatsApp"])
api_router.include_router(wallet.router, prefix="/wallet", tags=["Wallet"])
api_router.include_router(consultancy_plans.router, tags=["Consultancy Plans"])
