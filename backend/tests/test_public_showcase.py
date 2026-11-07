from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock, patch
import pytest
from fastapi import HTTPException

from app.schemas.public_showcase import LeadScreeningRequest
from app.services.lead_screening_service import LeadScreeningService
from app.api.v1.endpoints.public import submit_public_lead_screening, get_public_trainer_profile


def test_lead_screening_service_generates_lumbar_insight():
    req = LeadScreeningRequest(
        lead_name="Carlos Silva",
        lead_phone="11988887777",
        goal="Hipertrofia",
        joint_pains=["Lombar"],
        training_frequency_weekly=4,
        current_activity_level="intermediario",
    )
    insight = LeadScreeningService.generate_biomechanical_insight(req)
    assert "Estabilização lombopélvica" in insight
    assert "core" in insight.lower()


def test_lead_screening_service_generates_shoulder_and_knee_insight():
    req = LeadScreeningRequest(
        lead_name="Juliana Costa",
        lead_phone="21977776666",
        goal="Emagrecimento",
        joint_pains=["Ombro", "Joelho"],
        training_frequency_weekly=3,
        current_activity_level="iniciante",
    )
    insight = LeadScreeningService.generate_biomechanical_insight(req)
    assert "manguito rotador" in insight.lower()
    assert "valgo dinâmico" in insight.lower()


def test_lead_screening_whatsapp_url_encoding():
    req = LeadScreeningRequest(
        lead_name="Mariana Dias",
        lead_phone="31999998888",
        goal="Condicionamento Geral",
        joint_pains=[],
        training_frequency_weekly=3,
        current_activity_level="iniciante",
    )
    insight = LeadScreeningService.generate_biomechanical_insight(req)
    url = LeadScreeningService.build_whatsapp_direct_url(
        trainer_phone="5511987654321",
        trainer_name="Roberto Personal",
        req=req,
        insight=insight,
    )
    assert url.startswith("https://wa.me/5511987654321?text=")
    assert "Mariana" in url or "Mariana%20Dias" in url or "Mariana+Dias" in url


@pytest.mark.asyncio
async def test_submit_public_lead_screening_success():
    req = LeadScreeningRequest(
        lead_name="Lucas Pereira",
        lead_phone="11999991234",
        goal="Alívio de Dores",
        joint_pains=["Lombar", "Cervical"],
        training_frequency_weekly=3,
        current_activity_level="iniciante",
        notes="Gostaria de começar esta semana",
    )

    query = MagicMock()
    query.select.return_value = query
    query.ilike.return_value = query
    query.eq.return_value = query
    query.maybe_single.return_value = query
    query.execute = AsyncMock(
        return_value=SimpleNamespace(
            data={
                "id": "trainer-lead-1",
                "role": "trainer",
                "full_name": "Prof. Lucas",
                "username": "prof-lucas",
                "public_whatsapp": "5511988887777",
                "professional_document": "CREF 12345-G/SP",
                "public_directory_enabled": True,
            }
        )
    )
    client = MagicMock()
    client.table.return_value = query

    with patch(
        "app.api.v1.endpoints.public.supabase_service.get_client",
        new=AsyncMock(return_value=client),
    ):
        res = await submit_public_lead_screening("prof-lucas", req)

    assert res.lead_id is not None
    assert res.trainer_id == "trainer-lead-1"
    assert res.trainer_name == "Prof. Lucas"
    assert "https://wa.me/5511988887777" in res.whatsapp_direct_url
    assert "Estabilização lombopélvica" in res.biomechanical_insight
    assert res.status == "registered"


@pytest.mark.asyncio
async def test_submit_public_lead_screening_trainer_not_found():
    req = LeadScreeningRequest(
        lead_name="Visitante Anônimo",
        lead_phone="11999990000",
        goal="Condicionamento",
    )

    query = MagicMock()
    query.select.return_value = query
    query.ilike.return_value = query
    query.eq.return_value = query
    query.maybe_single.return_value = query
    query.execute = AsyncMock(return_value=SimpleNamespace(data=None))
    client = MagicMock()
    client.table.return_value = query

    with patch(
        "app.api.v1.endpoints.public.supabase_service.get_client",
        new=AsyncMock(return_value=client),
    ):
        with pytest.raises(HTTPException) as exc_info:
            await submit_public_lead_screening("inexistente_12345", req)
        assert exc_info.value.status_code == 404


@pytest.mark.asyncio
async def test_public_trainer_profile_has_enriched_social_proof_metrics():
    query = MagicMock()
    query.select.return_value = query
    query.ilike.return_value = query
    query.eq.return_value = query
    query.maybe_single.return_value = query
    query.execute = AsyncMock(
        return_value=SimpleNamespace(
            data={
                "id": "trainer-social-1",
                "role": "trainer",
                "full_name": "Professora Sofia",
                "username": "prof-sofia",
                "bio": "Especialista em biomecânica e reabilitação de coluna.",
                "specialties": ["Coluna", "Hipertrofia"],
                "public_whatsapp": "5511977778888",
                "photo_url": "https://example.com/sofia.jpg",
                "professional_document": "CREF 54321-G/SP",
                "public_directory_enabled": True,
            }
        )
    )
    client = MagicMock()
    client.table.return_value = query

    with patch(
        "app.api.v1.endpoints.public.supabase_service.get_client",
        new=AsyncMock(return_value=client),
    ):
        profile = await get_public_trainer_profile("prof-sofia")

    assert profile.username == "prof-sofia"
    assert profile.cref == "CREF 54321-G/SP"
    assert profile.cref_verified is True
    assert profile.rating_avg >= 4.5
    assert profile.rating_count > 0
    assert len(profile.showcase_badges) >= 3
    assert "CREF Verificado" in profile.showcase_badges


@pytest.mark.asyncio
async def test_trainer_og_preview_returns_rich_social_metatags():
    from app.api.v1.endpoints.public import get_trainer_og_preview

    query = MagicMock()
    query.select.return_value = query
    query.ilike.return_value = query
    query.eq.return_value = query
    query.maybe_single.return_value = query
    query.execute = AsyncMock(
        return_value=SimpleNamespace(
            data={
                "id": "trainer-og-1",
                "role": "trainer",
                "full_name": "Prof. Lucas Ribeiro",
                "username": "lucas-ribeiro",
                "bio": "Biomecânica e hipertrofia de alto rendimento.",
                "photo_url": "https://example.com/lucas.jpg",
                "professional_document": "CREF 99887-G/SP",
            }
        )
    )
    client = MagicMock()
    client.table.return_value = query

    with patch(
        "app.api.v1.endpoints.public.supabase_service.get_client",
        new=AsyncMock(return_value=client),
    ):
        response = await get_trainer_og_preview("lucas-ribeiro")

    assert response.status_code == 200
    html = response.body.decode("utf-8")
    assert '<meta property="og:title" content="Prof. Lucas Ribeiro — Personal Trainer (CREF 99887-G/SP)">' in html
    assert '<meta property="og:image" content="https://example.com/lucas.jpg">' in html
    assert 'https://shaipados.com/p/lucas-ribeiro' in html
    assert 'twitter:card' in html

