import asyncio

import httpx
import pytest


def _patch_httpx_asyncclient_compat():
    """Compatibiliza clientes HTTPX antigos usados pelos testes com a API atual."""
    original_init = httpx.AsyncClient.__init__
    if getattr(original_init, "_b2b_compat", False):
        return

    def compat_init(self, *args, app=None, **kwargs):
        if app is not None and "transport" not in kwargs:
            kwargs["transport"] = httpx.ASGITransport(app=app)
        return original_init(self, *args, **kwargs)

    compat_init._b2b_compat = True
    httpx.AsyncClient.__init__ = compat_init


try:
    asyncio.get_running_loop()
except RuntimeError:
    asyncio.set_event_loop(asyncio.new_event_loop())

_patch_httpx_asyncclient_compat()


@pytest.fixture(autouse=True)
def isolate_supabase_from_tests(monkeypatch):
    from app.core.config import settings
    from app.services.supabase_service import supabase_service

    monkeypatch.setattr(settings, "ENVIRONMENT", "development")
    monkeypatch.setattr(settings, "WHATSAPP_PROVIDER", "mock")

    from app.services.whatsapp_service import whatsapp_service
    monkeypatch.setattr(whatsapp_service, "provider", "mock")

    async def no_supabase_client():
        return None

    monkeypatch.setattr(supabase_service, "get_client", no_supabase_client)