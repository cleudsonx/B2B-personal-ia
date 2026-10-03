from typing import Dict, Any
from fastapi import APIRouter, Request, BackgroundTasks, status
import logging
from app.services.supabase_service import supabase_service
from app.services.gemini_service import GeminiService
from app.schemas.workout import BiomechanicalAlertCreate
import json

logger = logging.getLogger(__name__)

router = APIRouter()
gemini_service = GeminiService()

async def process_anamnesis_update(student_id: str, new_restrictions: str, trainer_id: str):
    logger.info(f"Iniciando verificação de segurança biomecânica para o aluno {student_id}")
    
    # 1. Fetch active workout
    active_plan = await supabase_service.get_active_prescription(student_id)
    if not active_plan:
        logger.info(f"Aluno {student_id} não possui plano ativo. Análise pulada.")
        return
        
    # 2. Serialize workout safely
    workout_json = json.dumps(active_plan.model_dump(), default=str, ensure_ascii=False)
    
    # 3. Request Gemini Analysis
    try:
        safety_report = await gemini_service.analyze_biomechanical_safety(new_restrictions, workout_json)
        
        if not safety_report.get("is_safe", True):
            dangerous = safety_report.get("dangerous_exercises", [])
            names = [ex.get("exercise_name", "") for ex in dangerous]
            alert_message = f"ALERTA DE SEGURANÇA: {len(dangerous)} exercícios perigosos detectados devido à restrição '{new_restrictions}'. Exercícios: {', '.join(names)}. Recomendação: {safety_report.get('recommendation', '')}"
            
            # 4. Create Alert in database
            student = await supabase_service.get_student_by_id(student_id)
            student_name = student.full_name if student else "Aluno"
            
            alert = BiomechanicalAlertCreate(
                student_id=student_id,
                student_name=student_name,
                trainer_id=trainer_id,
                original_exercise=", ".join(names) if names else "Vários",
                adapted_exercise="Revisão Necessária via IA",
                reason=alert_message,
                pain_location="Geral/Perfil",
                severity="Alta",
                workout_id=active_plan.id
            )
            await supabase_service.create_biomechanical_alert(alert)
            logger.warning(f"Alerta biomecânico gerado para o aluno {student_id}: {alert_message}")
            
    except Exception as e:
        logger.error(f"Erro ao processar análise biomecânica com a IA: {e}")

@router.post("/supabase/anamnesis", status_code=status.HTTP_200_OK, summary="Supabase Webhook para Anamnese")
async def anamnesis_webhook(request: Request, background_tasks: BackgroundTasks):
    """
    Webhook chamado pelo Supabase quando o perfil de um aluno é atualizado (especificamente clinical_restrictions).
    """
    try:
        payload = await request.json()
    except Exception:
        return {"status": "ignored", "reason": "invalid payload"}
        
    record = payload.get("record", {})
    old_record = payload.get("old_record", {})
    
    # Check if this is an update and clinical_restrictions actually changed
    new_restrictions = record.get("clinical_restrictions")
    old_restrictions = old_record.get("clinical_restrictions")
    
    if new_restrictions and new_restrictions != old_restrictions:
        student_id = record.get("id")
        trainer_id = record.get("trainer_id")
        
        if student_id and trainer_id:
            background_tasks.add_task(process_anamnesis_update, student_id, new_restrictions, trainer_id)
            return {"status": "processing", "message": "Triggered AI biomechanical safety check in background."}
            
    return {"status": "ignored", "reason": "No meaningful restriction changes."}
