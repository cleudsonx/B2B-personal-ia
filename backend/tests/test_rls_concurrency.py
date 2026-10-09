from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock, patch
import pytest
from fastapi import HTTPException

from app.api.v1.endpoints.public import get_public_trainer_profile
from app.api.v1.endpoints.workouts import generate_workout_plan
from app.schemas.anamnesis import AnamnesisInput


@pytest.mark.asyncio
async def test_rls_public_trainer_profile_blocks_missing_cref():
    """Garante que a política RLS/vitrine pública rejeita instrutores com CREF nulo/vazio."""
    profile_data = {
        "id": "trainer-sem-cref-uuid",
        "username": "semcref",
        "full_name": "Instrutor Sem CREF",
        "role": "trainer",
        "professional_document": None,
        "bio": "Instrutor em formação",
        "public_directory_enabled": True,
        "specialties": ["Iniciantes"],
    }
    
    query = MagicMock()
    query.select.return_value = query
    query.ilike.return_value = query
    query.eq.return_value = query
    query.maybe_single.return_value = query
    query.execute = AsyncMock(return_value=SimpleNamespace(data=profile_data))
    
    client = MagicMock()
    client.table.return_value = query

    with patch(
        "app.api.v1.endpoints.public.supabase_service.get_client",
        new=AsyncMock(return_value=client),
    ):
        with pytest.raises(HTTPException) as exc_info:
            await get_public_trainer_profile(username="semcref")
        assert exc_info.value.status_code == 403
        assert "CREF pendente" in exc_info.value.detail or "não validado" in exc_info.value.detail


@pytest.mark.asyncio
async def test_rls_public_trainer_profile_allows_valid_cref():
    """Garante que a vitrine pública exibe corretamente treinadores com CREF validado."""
    profile_data = {
        "id": "trainer-cref-valido-uuid",
        "username": "carlossilva",
        "full_name": "Professor Carlos Silva",
        "role": "trainer",
        "professional_document": "CREF 012345-G/SP",
        "bio": "Especialista em hipertrofia",
        "specialties": ["Hipertrofia", "Biomecânica"],
        "public_whatsapp": "5511999998888",
        "photo_url": "https://example.com/carlos.jpg",
        "public_directory_enabled": True,
    }

    query = MagicMock()
    query.select.return_value = query
    query.ilike.return_value = query
    query.eq.return_value = query
    query.maybe_single.return_value = query
    query.execute = AsyncMock(return_value=SimpleNamespace(data=profile_data))
    
    client = MagicMock()
    client.table.return_value = query

    with patch(
        "app.api.v1.endpoints.public.supabase_service.get_client",
        new=AsyncMock(return_value=client),
    ):
        result = await get_public_trainer_profile(username="carlossilva")
        assert result.username == "carlossilva"
        assert result.cref == "CREF 012345-G/SP"


@pytest.mark.asyncio
async def test_concurrency_atomic_quota_reservation_blocks_when_limit_reached():
    """Garante que a reserva atômica de quota de IA bloqueia a requisição quando o limite for atingido."""
    trainer_user = {
        "sub": "trainer-uuid-001",
        "aal": "aal2",
        "profile": {"role": "trainer", "roles": ["trainer"]},
    }
    anamnesis = AnamnesisInput(
        objective="Hipertrofia Muscular",
        training_level="Intermediário",
        days_per_week=4,
        workout_location="Academia",
    )

    mock_sub = MagicMock(max_ai_generations=5, plan_name="Starter")

    with patch("app.services.supabase_service.supabase_service.get_trainer_subscription", new=AsyncMock(return_value=mock_sub)):
        with patch("app.services.supabase_service.supabase_service.reserve_monthly_ai_quota", new=AsyncMock(return_value=False)):
            with pytest.raises(HTTPException) as exc_info:
                await generate_workout_plan(
                    data=anamnesis,
                    gemini_svc=MagicMock(),
                    current_user=trainer_user,
                )
            assert exc_info.value.status_code == 403
            assert "atingido" in exc_info.value.detail.lower()


@pytest.mark.asyncio
async def test_concurrency_releases_quota_on_gemini_failure():
    """Garante que, se o motor Gemini falhar, a quota atômica é liberada para não lesar os créditos do professor."""
    trainer_user = {
        "sub": "trainer-uuid-001",
        "aal": "aal2",
        "profile": {"role": "trainer", "roles": ["trainer"]},
    }
    anamnesis = AnamnesisInput(
        objective="Hipertrofia Muscular",
        training_level="Intermediário",
        days_per_week=4,
        workout_location="Academia",
    )

    mock_sub = MagicMock(max_ai_generations=10, plan_name="Pro")
    mock_gemini = MagicMock()
    mock_gemini.generate_workout_plan = AsyncMock(side_effect=Exception("Timeout no provedor de IA"))

    with patch("app.services.supabase_service.supabase_service.get_trainer_subscription", new=AsyncMock(return_value=mock_sub)):
        with patch("app.services.supabase_service.supabase_service.reserve_monthly_ai_quota", new=AsyncMock(return_value=True)):
            with patch("app.services.supabase_service.supabase_service.release_monthly_ai_quota", new=AsyncMock()) as mock_release:
                with pytest.raises(HTTPException) as exc_info:
                    await generate_workout_plan(
                        data=anamnesis,
                        gemini_svc=mock_gemini,
                        current_user=trainer_user,
                    )
                assert exc_info.value.status_code == 500
                mock_release.assert_awaited_once_with("trainer-uuid-001")

