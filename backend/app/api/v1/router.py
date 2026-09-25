from fastapi import APIRouter
from app.api.v1.endpoints import workouts, adaptations

api_router = APIRouter()

api_router.include_router(workouts.router, prefix="/workouts", tags=["Workouts"])
api_router.include_router(adaptations.router, prefix="/adaptations", tags=["Adaptations"])
