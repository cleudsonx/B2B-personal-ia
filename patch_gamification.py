import re

# 1. Update supabase_service.py
file_path = "backend/app/services/supabase_service.py"
with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

gamification_method = """
    async def get_gamification_data(self, client_id: str) -> dict:
        client = await self.get_client()
        if not client:
            return {"current_streak": 0, "daily_goal_progress": 0.0}
            
        try:
            from datetime import datetime, timezone, timedelta
            # Pega as sessões ordenadas por data descendente para calcular a ofensiva
            res = await client.table("workout_sessions")\\
                .select("completed_at, total_exercises, completed_exercises")\\
                .eq("client_id", self.to_valid_uuid_str(client_id))\\
                .order("completed_at", desc=True)\\
                .limit(50)\\
                .execute()
                
            sessions = res.data if res and res.data else []
            
            if not sessions:
                return {"current_streak": 0, "daily_goal_progress": 0.0}
                
            now = datetime.now(timezone.utc)
            today_date = now.date()
            
            daily_progress = 0.0
            distinct_dates = set()
            today_progress_set = False
            
            for s in sessions:
                try:
                    dt = datetime.fromisoformat(s['completed_at'].replace("Z", "+00:00"))
                    d = dt.date()
                    distinct_dates.add(d)
                    
                    if d == today_date and not today_progress_set:
                        t_ex = s.get("total_exercises", 0)
                        c_ex = s.get("completed_exercises", 0)
                        if t_ex > 0:
                            daily_progress = min(1.0, c_ex / t_ex)
                        today_progress_set = True
                except Exception:
                    pass
            
            sorted_dates = sorted(list(distinct_dates), reverse=True)
            streak = 0
            current_date = today_date
            
            if sorted_dates and sorted_dates[0] == current_date:
                streak = 1
                current_date = current_date - timedelta(days=1)
                idx = 1
            elif sorted_dates and sorted_dates[0] == current_date - timedelta(days=1):
                streak = 0 
                current_date = current_date - timedelta(days=1)
                idx = 0
            else:
                return {"current_streak": 0, "daily_goal_progress": daily_progress}
            
            while idx < len(sorted_dates):
                if sorted_dates[idx] == current_date:
                    streak += 1
                    current_date -= timedelta(days=1)
                    idx += 1
                else:
                    break
                    
            return {"current_streak": streak, "daily_goal_progress": daily_progress}
            
        except Exception as e:
            print(f"Erro ao calcular gamificacao: {e}")
            return {"current_streak": 0, "daily_goal_progress": 0.0}
"""

if "def get_gamification_data" not in content:
    # Insert before the last class or just at the end of the SupabaseService class
    # We can find `class SupabaseService:` and append to it. But it's safer to find the last method.
    # Actually just add it before the instantiation `supabase_service = SupabaseService()`
    parts = content.rsplit("supabase_service = SupabaseService()", 1)
    new_content = parts[0] + gamification_method + "\nsupabase_service = SupabaseService()\n" + parts[1]
    with open(file_path, "w", encoding="utf-8") as f:
        f.write(new_content)
    print("Added get_gamification_data to supabase_service.py")


# 2. Update workouts.py
file_path_w = "backend/app/api/v1/endpoints/workouts.py"
with open(file_path_w, "r", encoding="utf-8") as f:
    w_content = f.read()

# find get_gamification_data in workouts.py and replace its body
import ast
# We'll use regex to replace the function body
pattern = re.compile(r"(@router\.get\(\s*\"/gamification\".*?def get_gamification_data\([^)]*\)\s*->\s*GamificationResponse:\n)(.*?)(?=\n\n|\Z)", re.DOTALL)

def replacer(match):
    header = match.group(1)
    new_body = """    client_id = current_user.get("sub")
    if not client_id:
        return GamificationResponse(current_streak=0, daily_goal_progress=0.0)
        
    data = await supabase_service.get_gamification_data(client_id)
    return GamificationResponse(
        current_streak=data.get("current_streak", 0),
        daily_goal_progress=data.get("daily_goal_progress", 0.0)
    )"""
    return header + new_body

if "supabase_service.get_gamification_data" not in w_content:
    new_w_content = pattern.sub(replacer, w_content)
    with open(file_path_w, "w", encoding="utf-8") as f:
        f.write(new_w_content)
    print("Updated get_gamification_data in workouts.py")

