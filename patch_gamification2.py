import re

file_path_w = "backend/app/api/v1/endpoints/workouts.py"
with open(file_path_w, "r", encoding="utf-8") as f:
    w_content = f.read()

# Let's replace the whole gamification function
start_marker = '@router.get(\n    "/gamification"'
if start_marker in w_content:
    parts = w_content.split(start_marker)
    # The first part is everything before the router get
    # The second part is the router get and the rest of the file
    new_func = """@router.get(
    "/gamification",
    response_model=GamificationResponse,
    status_code=status.HTTP_200_OK,
    summary="Buscar Dados de Gamificação do Aluno",
    description="Retorna dados de gamificação baseados na tabela workout_sessions do Supabase."
)
async def get_gamification_data(
    current_user: Dict[str, Any] = Depends(get_current_user)
) -> GamificationResponse:
    client_id = current_user.get("sub")
    if not client_id:
        return GamificationResponse(current_streak=0, daily_goal_progress=0.0)
        
    data = await supabase_service.get_gamification_data(client_id)
    return GamificationResponse(
        current_streak=data.get("current_streak", 0),
        daily_goal_progress=data.get("daily_goal_progress", 0.0)
    )
"""
    new_w_content = parts[0] + new_func
    with open(file_path_w, "w", encoding="utf-8") as f:
        f.write(new_w_content)
    print("Replaced get_gamification_data")
else:
    print("start_marker not found")
