from datetime import datetime, timedelta, timezone

import pytest
from fastapi import HTTPException, status

from app.api.v1.endpoints import workouts as workouts_endpoint_module
from app.services import supabase_service as supabase_service_module
from app.services.supabase_service import SupabaseService

FIXED_NOW = datetime(2026, 10, 7, 12, 0, tzinfo=timezone.utc)


class FakeResponse:
    def __init__(self, rows):
        self.data = rows


class FakeQuery:
    def __init__(self, rows):
        self.rows = rows

    def select(self, *args, **kwargs):
        return self

    def eq(self, *args, **kwargs):
        return self

    def order(self, *args, **kwargs):
        return self

    def limit(self, *args, **kwargs):
        return self

    async def execute(self):
        return FakeResponse(self.rows)


class FakeClient:
    def __init__(self, rows, profile_rows=None):
        self.rows = rows
        self.profile_rows = profile_rows or []

    def table(self, name):
        if name == "workout_sessions":
            return FakeQuery(self.rows)
        if name == "profiles":
            return FakeQuery(self.profile_rows)
        raise AssertionError(f"Tabela fake não suportada: {name}")


async def _set_workout_sessions(monkeypatch, service: SupabaseService, rows, profile_rows=None):
    async def fake_get_client():
        return FakeClient(rows, profile_rows)

    monkeypatch.setattr(service, "get_client", fake_get_client)


def _freeze_service_now(monkeypatch, fixed_now: datetime):
    class FrozenDateTime(datetime):
        @classmethod
        def now(cls, tz=None):
            if tz is None:
                return fixed_now
            return fixed_now.astimezone(tz)

    monkeypatch.setattr(supabase_service_module, "datetime", FrozenDateTime)


def _utc_now():
    return FIXED_NOW


def _iso_utc(dt: datetime) -> str:
    return dt.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _iso_with_offset(dt: datetime, offset_hours: int) -> str:
    offset = timezone(timedelta(hours=offset_hours))
    return dt.astimezone(offset).isoformat()


@pytest.mark.asyncio
async def test_db_unavailable_raises_clear_error_not_zero(monkeypatch):
    service = SupabaseService()

    async def fake_get_client():
        return None

    monkeypatch.setattr(service, "get_client", fake_get_client)

    with pytest.raises(RuntimeError, match="Cliente Supabase indisponível"):
        await service.get_gamification_data("client-123")


@pytest.mark.asyncio
async def test_gamification_endpoint_returns_503_when_persistence_is_unavailable(monkeypatch):
    async def fake_get_gamification_data(_client_id: str):
        raise RuntimeError("Cliente Supabase indisponível para consultar gamificação do aluno.")

    monkeypatch.setattr(workouts_endpoint_module.supabase_service, "get_gamification_data", fake_get_gamification_data)

    with pytest.raises(HTTPException) as exc_info:
        await workouts_endpoint_module.get_gamification_data({"sub": "client-123"})

    assert exc_info.value.status_code == status.HTTP_503_SERVICE_UNAVAILABLE
    assert exc_info.value.detail == "Serviço de persistência indisponível no momento. Tente novamente mais tarde."


@pytest.mark.asyncio
async def test_empty_session_list_does_not_count_towards_streak_or_progress(monkeypatch):
    _freeze_service_now(monkeypatch, FIXED_NOW)
    service = SupabaseService()
    await _set_workout_sessions(monkeypatch, service, [])

    result = await service.get_gamification_data("client-123")

    assert result == {"current_streak": 0, "daily_goal_progress": 0.0}


@pytest.mark.asyncio
async def test_multiple_valid_sessions_same_day_accumulate_and_cap_progress(monkeypatch):
    _freeze_service_now(monkeypatch, FIXED_NOW)
    service = SupabaseService()
    today = _utc_now()
    iso_today = today.date()

    await _set_workout_sessions(
        monkeypatch,
        service,
        [
            {"completed_at": _iso_with_offset(datetime(iso_today.year, iso_today.month, iso_today.day, 8, 0, tzinfo=timezone.utc), -3), "total_exercises": 5, "completed_exercises": 1},
            {"completed_at": _iso_with_offset(datetime(iso_today.year, iso_today.month, iso_today.day, 8, 45, tzinfo=timezone.utc), -3), "total_exercises": 0, "completed_exercises": 0},
            {"completed_at": _iso_with_offset(datetime(iso_today.year, iso_today.month, iso_today.day, 9, 30, tzinfo=timezone.utc), -3), "total_exercises": 4, "completed_exercises": 4},
            {"completed_at": _iso_with_offset(datetime(iso_today.year, iso_today.month, iso_today.day, 12, 0, tzinfo=timezone.utc), -3), "total_exercises": 2, "completed_exercises": 2},
        ],
    )

    result = await service.get_gamification_data("client-123")

    assert result["current_streak"] == 1
    assert result["daily_goal_progress"] == 1.0


@pytest.mark.asyncio
async def test_streak_converts_utc_to_local_days_when_profile_timezone_is_set(monkeypatch):
    _freeze_service_now(monkeypatch, FIXED_NOW)
    service = SupabaseService()
    today = _utc_now()
    local_day = today.astimezone(timezone(timedelta(hours=-3))).date()
    yesterday_local = local_day - timedelta(days=1)

    await _set_workout_sessions(
        monkeypatch,
        service,
        [
            {"completed_at": datetime(local_day.year, local_day.month, local_day.day, 0, 0, tzinfo=timezone(timedelta(hours=-3))).isoformat(), "total_exercises": 3, "completed_exercises": 3},
            {"completed_at": datetime(yesterday_local.year, yesterday_local.month, yesterday_local.day, 0, 0, tzinfo=timezone(timedelta(hours=-3))).isoformat(), "total_exercises": 3, "completed_exercises": 3},
        ],
        profile_rows=[{"timezone": "America/Sao_Paulo"}],
    )

    result = await service.get_gamification_data("client-123")

    assert result["current_streak"] == 2


@pytest.mark.asyncio
async def test_local_day_without_session_today_breaks_streak(monkeypatch):
    _freeze_service_now(monkeypatch, FIXED_NOW)
    service = SupabaseService()
    today = _utc_now()
    local_today = today.astimezone(timezone(timedelta(hours=-3))).date()
    prior_day = local_today - timedelta(days=2)
    previous_day = local_today - timedelta(days=1)

    await _set_workout_sessions(
        monkeypatch,
        service,
        [
            {"completed_at": datetime(prior_day.year, prior_day.month, prior_day.day, 0, 0, tzinfo=timezone(timedelta(hours=-3))).isoformat(), "total_exercises": 2, "completed_exercises": 2},
            {"completed_at": datetime(previous_day.year, previous_day.month, previous_day.day, 0, 0, tzinfo=timezone(timedelta(hours=-3))).isoformat(), "total_exercises": 2, "completed_exercises": 2},
        ],
        profile_rows=[{"timezone": "America/Sao_Paulo"}],
    )

    result = await service.get_gamification_data("client-123")

    assert result["current_streak"] == 0
    assert result["daily_goal_progress"] == 0.0


@pytest.mark.asyncio
async def test_missing_profile_timezone_falls_back_to_utc(monkeypatch):
    _freeze_service_now(monkeypatch, FIXED_NOW)
    service = SupabaseService()
    today = _utc_now()
    yesterday = today - timedelta(days=1)

    await _set_workout_sessions(
        monkeypatch,
        service,
        [
            {"completed_at": _iso_utc(yesterday), "total_exercises": 2, "completed_exercises": 2},
            {"completed_at": _iso_utc(today), "total_exercises": 2, "completed_exercises": 1},
        ],
    )

    result = await service.get_gamification_data("client-123")

    assert result["current_streak"] == 2
    assert result["daily_goal_progress"] == 0.5


@pytest.mark.asyncio
async def test_invalid_profile_timezone_falls_back_to_utc(monkeypatch):
    _freeze_service_now(monkeypatch, FIXED_NOW)
    service = SupabaseService()
    today = _utc_now()
    yesterday = today - timedelta(days=1)

    await _set_workout_sessions(
        monkeypatch,
        service,
        [
            {"completed_at": _iso_utc(yesterday), "total_exercises": 2, "completed_exercises": 2},
            {"completed_at": _iso_utc(today), "total_exercises": 2, "completed_exercises": 2},
        ],
        profile_rows=[{"timezone": "Not/A_Real_Zone"}],
    )

    result = await service.get_gamification_data("client-123")

    assert result["current_streak"] == 2
    assert result["daily_goal_progress"] == 1.0
