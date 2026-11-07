import pytest
from unittest.mock import AsyncMock, patch

from app.services.supabase_service import supabase_service
from app.api.v1.endpoints.whatsapp_ai import (
    find_exercise_swap_candidates,
    _extract_media_info,
    handle_deterministic_button,
    process_whatsapp_question,
)

TRAINER_ID = "00000000-0000-0000-0000-000000000001"
STUDENT_ID = "00000000-0000-0000-0000-000000000002"


@pytest.fixture(autouse=True)
def setup_student():
    supabase_service._mem_students[STUDENT_ID] = {
        "id": STUDENT_ID,
        "full_name": "Juliana Santos",
        "name": "Juliana Santos",
        "email": "juliana@shaipados.com",
        "phone": "5511999993333",
        "trainer_id": TRAINER_ID,
        "role": "client",
        "subscription_status": "active",
        "goal": "Definição",
    }
    supabase_service._mem_students[TRAINER_ID] = {
        "id": TRAINER_ID,
        "full_name": "Coach Treinador",
        "role": "trainer",
        "subscription_status": "active",
    }
    supabase_service._mem_subscriptions[TRAINER_ID] = {
        "plan_id": "pro",
        "plan_name": "Personal Pro",
        "active": True,
    }
    supabase_service._mem_prescriptions[STUDENT_ID] = {
        "is_active": True,
        "plan_json": {
            "workout_plan_title": "Treino Hipertrofia A/B",
            "notes_for_trainer": "Foco em quadríceps",
            "splits": [
                {
                    "split_identifier": "A",
                    "split_name": "Pernas e Ombros",
                    "estimated_duration_min": 50,
                    "exercises": [
                        {
                            "order": 1,
                            "name": "Leg Press 45",
                            "target_muscle_group": "Quadríceps",
                            "sets": 4,
                            "reps": "10-12",
                            "rest_seconds": 90,
                            "notes": "Amplitude segura",
                            "substitution_vector": "Agachamento ou Hack",
                        },
                        {
                            "order": 2,
                            "name": "Crossover",
                            "target_muscle_group": "Peitoral",
                            "sets": 3,
                            "reps": "12",
                            "rest_seconds": 60,
                            "notes": "Foco no pico de contração",
                            "substitution_vector": "Crucifixo",
                        },
                    ],
                }
            ],
        },
    }
    yield
    supabase_service._mem_students.pop(STUDENT_ID, None)
    supabase_service._mem_students.pop(TRAINER_ID, None)
    supabase_service._mem_subscriptions.pop(TRAINER_ID, None)
    supabase_service._mem_prescriptions.pop(STUDENT_ID, None)


def test_find_exercise_swap_candidates():
    # Leg press
    c1 = find_exercise_swap_candidates("leg press ta ocupado o que faco")
    assert "Agachamento Búlgaro" in c1[0] or "Hack Squat" in c1

    # Crossover
    c2 = find_exercise_swap_candidates("crossover muito lotado")
    assert "Crucifixo Halteres" in c2 or "Peck Deck" in c2

    # Inclinado
    c3 = find_exercise_swap_candidates("supino inclinado cheio")
    assert any("Inc" in x or "Inclinado" in x for x in c3)

    # Fallback contextual da ficha
    c4 = find_exercise_swap_candidates("aparelho ocupado", plan_text="Ficha: Treino A: Extensora 3x12")
    assert "Agachamento Búlgaro" in c4 or "Afundo c/ Halteres" in c4


def test_extract_media_info():
    # Baileys / Evolution audioMessage
    d1 = {"message": {"audioMessage": {"mimetype": "audio/ogg; codecs=opus", "seconds": 12}}}
    info1 = _extract_media_info(d1)
    assert info1 is not None
    assert info1["type"] == "audio"
    assert info1["seconds"] == 12

    # Baileys voiceMessage
    d2 = {"message": {"voiceMessage": {"mimetype": "audio/mp4", "seconds": 8}}}
    info2 = _extract_media_info(d2)
    assert info2 is not None
    assert info2["type"] == "audio"
    assert info2["seconds"] == 8

    # Meta Cloud audio
    d3 = {"type": "audio", "audio": {"mime_type": "audio/ogg", "id": "audio_123"}}
    info3 = _extract_media_info(d3)
    assert info3 is not None
    assert info3["type"] == "audio"
    assert info3["id"] == "audio_123"

    # Texto puro (sem mídia)
    d4 = {"message": {"conversation": "olá"}}
    assert _extract_media_info(d4) is None


@pytest.mark.asyncio
async def test_process_whatsapp_question_machine_busy_generates_tailored_buttons():
    student = supabase_service._mem_students[STUDENT_ID]

    # Mock do Gemini para retorno determinístico
    mock_gemini_resp = AsyncMock()
    mock_gemini_resp.text = "O Leg Press pode ser substituído com segurança pelo Agachamento Búlgaro com halteres ou Hack Squat."

    with patch("app.services.gemini_service.gemini_service._generate_with_fallback_async", return_value=mock_gemini_resp):
        res = await process_whatsapp_question(
            trainer_id=TRAINER_ID,
            student=student,
            question="Leg press tá muito ocupado na academia, posso trocar por qual?",
        )

        assert res["interaction_type"] == "reply_buttons"
        buttons = res.get("buttons") or []
        assert len(buttons) == 3

        # Verifica se os botões possuem títulos conformes com a Meta (<= 20 chars)
        for b in buttons:
            assert len(b["title"]) <= 20

        # Verifica botões sugeridos
        assert any("Búlgaro" in b["id"] or "Hack" in b["id"] for b in buttons)
        assert any(b["id"] == "keep_original|active" for b in buttons)


@pytest.mark.asyncio
async def test_confirm_swap_button_leaves_prescription_intact():
    res = await handle_deterministic_button(
        digits="5511999993333",
        button_id="confirm_swap|active|Agachamento Búlgaro",
        trainer_id=TRAINER_ID,
    )

    assert "Adaptação Registrada" in res["reply"]
    assert "Agachamento Búlgaro" in res["reply"]
    assert "ficha oficial do mesociclo segue intacta" in res["reply"]
    assert res["cost_type"] == "free"
