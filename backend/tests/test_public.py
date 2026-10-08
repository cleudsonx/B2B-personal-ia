from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from fastapi import HTTPException

from app.api.v1.endpoints.public import get_public_trainer_profile, list_public_trainers


@pytest.mark.asyncio
async def test_public_trainer_directory_only_returns_complete_public_profiles():
    profiles = [
        {
            "id": "trainer-1",
            "role": "trainer",
            "full_name": "Ana Silva",
            "username": "ana-silva",
            "bio": "Treinamento de força individualizado.",
            "specialties": ["Força"],
            "public_whatsapp": "5511999999999",
            "photo_url": "https://example.com/ana.jpg",
            "professional_document": "CREF 12345-G/SP",
            "public_directory_enabled": True,
            "phone": "5511888888888",
            "email": "ana@example.com",
        },
        {
            "id": "trainer-2",
            "role": "trainer",
            "full_name": "Sem vitrine",
            "username": None,
            "bio": "Perfil ainda não publicado.",
            "professional_document": "CREF 98765-G/SP",
            "public_directory_enabled": False,
        },
        {
            "id": "trainer-3",
            "role": "trainer",
            "full_name": "Sem credencial",
            "username": "sem-credencial",
            "bio": "Perfil não validado.",
            "public_directory_enabled": True,
        },
    ]
    query = MagicMock()
    query.select.return_value = query
    query.eq.return_value = query
    query.limit.return_value = query
    query.execute = AsyncMock(return_value=SimpleNamespace(data=profiles))
    client = MagicMock()
    client.table.return_value = query

    with patch(
        "app.api.v1.endpoints.public.supabase_service.get_client",
        new=AsyncMock(return_value=client),
    ):
        result = await list_public_trainers(limit=50)

    assert len(result) == 1
    assert result[0].username == "ana-silva"
    assert result[0].cref == "CREF 12345-G/SP"
    assert not hasattr(result[0], "phone")
    assert not hasattr(result[0], "email")


@pytest.mark.asyncio
async def test_public_trainer_directory_caps_requested_limit():
    with pytest.raises(HTTPException):
        await list_public_trainers(limit=51)


@pytest.mark.asyncio
async def test_unpublished_trainer_profile_is_not_public_by_direct_url():
    query = MagicMock()
    query.select.return_value = query
    query.ilike.return_value = query
    query.eq.return_value = query
    query.maybe_single.return_value = query
    query.execute = AsyncMock(
        return_value=SimpleNamespace(
            data={
                "id": "trainer-2",
                "role": "trainer",
                "full_name": "Sem vitrine",
                "username": "sem-vitrine",
                "bio": "Perfil ainda não publicado.",
                "professional_document": "CREF 98765-G/SP",
                "public_directory_enabled": False,
            }
        )
    )
    client = MagicMock()
    client.table.return_value = query

    with patch(
        "app.api.v1.endpoints.public.supabase_service.get_client",
        new=AsyncMock(return_value=client),
    ):
        with pytest.raises(HTTPException) as error:
            await get_public_trainer_profile("sem-vitrine")

    assert error.value.status_code == 404