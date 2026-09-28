from fastapi import APIRouter
from app.api.v1.endpoints import workouts, adaptations, assistant, subscriptions

api_router = APIRouter()

api_router.include_router(workouts.router, prefix="/workouts", tags=["Workouts"])
api_router.include_router(adaptations.router, prefix="/adaptations", tags=["Adaptations"])
api_router.include_router(assistant.router, prefix="/assistant", tags=["Assistant"])
api_router.include_router(subscriptions.router, prefix="/subscriptions", tags=["Subscriptions"])


