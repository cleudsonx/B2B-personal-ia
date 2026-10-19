import sys
sys.stdout.reconfigure(encoding='utf-8')
import asyncio
from app.services.supabase_service import SupabaseService

async def check():
    svc = SupabaseService()
    client = await svc.get_client()
    res = await client.table('exercise_library').select('id, name, muscle_group', count='exact').execute()
    print(f"Total de exercícios na tabela exercise_library do Supabase: {res.count}")
    print("Amostra de 10 exercícios:")
    for r in res.data[:10]:
        print(f"  • {r['name']} ({r['muscle_group']})")

asyncio.run(check())

