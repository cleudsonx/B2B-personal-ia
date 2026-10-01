import pytest


@pytest.fixture(autouse=True)
def isolate_supabase_from_tests(monkeypatch):
    from app.core.config import settings
    from app.services.supabase_service import supabase_service

    monkeypatch.setattr(settings, "ENVIRONMENT", "development")

    async def no_supabase_client():
        return None

    monkeypatch.setattr(supabase_service, "get_client", no_supabase_client)