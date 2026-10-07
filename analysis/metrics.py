"""Cálculo de métricas subjetivas (questionários) e objetivas (telemetria).

Os identificadores dos itens e as fórmulas seguem `questionario_T1.html` /
`questionario_T2.html` e a seção 9.4 de `especificacoes_tecnicas_v4 (1).md`.
"""

from __future__ import annotations

from collections import defaultdict
from typing import Optional

# SUS (System Usability Scale) — itens ímpares são afirmações positivas,
# pares são negativas (Brooke, 1996). Escala do instrumento: 1-5.
SUS_POSITIVE_IDS = {1, 3, 5, 7, 9}
SUS_NEGATIVE_IDS = {2, 4, 6, 8, 10}

RELIABILITY_TECHNICAL_IDS = [f"tf{i}" for i in range(1, 10)]  # tf1..tf9, escala 1-7
RELIABILITY_TRUST_IDS = [f"cs{i}" for i in range(1, 11)]  # cs1..cs10, escala 1-7
CONTEXT_IDS = [f"ctx{i}" for i in range(1, 6)]  # ctx1..ctx5, escala 1-7
COMPARATIVE_IDS = [f"comp{i}" for i in range(1, 7)]  # comp1..comp6, escala -3..+3 (somente T2)


def sus_score(sus: dict) -> Optional[float]:
    """Escore SUS (0-100) pela fórmula de Brooke. Exige os 10 itens respondidos."""
    if not isinstance(sus, dict):
        return None
    total = 0.0
    answered = 0
    for i in range(1, 11):
        value = sus.get(f"sus{i}")
        if value is None:
            continue
        value = float(value)
        if i in SUS_POSITIVE_IDS:
            total += value - 1
        else:
            total += 5 - value
        answered += 1
    if answered < 10:
        return None
    return total * 2.5


def likert_score(
    items: dict,
    item_ids: list[str],
    reverse_items: list[str],
    scale_min: int,
    scale_max: int,
) -> Optional[float]:
    """Média Likert (escala `scale_min`..`scale_max`) com itens invertidos.

    `reverse_items` vem do próprio payload exportado pelo questionário
    (campo `reverse_items`), não é fixado aqui — acompanha automaticamente
    mudanças futuras no instrumento.
    """
    if not isinstance(items, dict):
        return None
    reverse_set = set(reverse_items or [])
    values: list[float] = []
    for key in item_ids:
        raw = items.get(key)
        if raw is None:
            continue
        value = float(raw)
        if key in reverse_set:
            value = (scale_min + scale_max) - value
        values.append(value)
    if not values:
        return None
    return sum(values) / len(values)


def comparative_mean(comparative: dict) -> Optional[float]:
    """Média dos itens comparativos comp1..comp6 (-3..+3); só existe no T2."""
    if not isinstance(comparative, dict):
        return None
    values = [
        float(comparative[key])
        for key in COMPARATIVE_IDS
        if comparative.get(key) is not None
    ]
    if not values:
        return None
    return sum(values) / len(values)


def _event_data(event: dict) -> dict:
    data = event.get("data")
    return data if isinstance(data, dict) else {}


def aggregate_objective_metrics(events: list[dict]) -> dict:
    """Agrega eventos de telemetria de um participante numa arquitetura.

    Espelha as métricas de `TelemetryService._buildSummary` (Dart), mas
    operando sobre todos os eventos já filtrados por `architecture`.
    """
    completed = [e for e in events if e.get("eventType") == "operation_completed"]
    successful = [e for e in completed if _event_data(e).get("success") is True]
    blocked = [e for e in events if e.get("eventType") == "operation_blocked"]
    delayed = [e for e in events if e.get("eventType") == "operation_delayed"]
    abandoned = [e for e in events if e.get("eventType") == "abandon_after_failure"]
    sessions = [e for e in events if e.get("eventType") == "session_started"]

    total_attempts = len(completed) + len(blocked)
    effective_completion_rate = (
        len(successful) / total_attempts if total_attempts > 0 else None
    )

    sync_items = [e for e in events if e.get("eventType") == "sync_item"]
    sync_push = [e for e in sync_items if _event_data(e).get("direction") == "push"]
    sync_pull = [e for e in sync_items if _event_data(e).get("direction") == "pull"]
    sync_push_ok = [e for e in sync_push if _event_data(e).get("success") is True]
    sync_pull_ok = [e for e in sync_pull if _event_data(e).get("success") is True]
    sync_ok = [e for e in sync_items if _event_data(e).get("success") is True]

    pending_durations = [
        _event_data(e)["pending_duration_ms"]
        for e in sync_ok
        if _event_data(e).get("pending_duration_ms") is not None
    ]

    return {
        "events_total": len(events),
        "sessions_total": len(sessions),
        "total_operations": len(completed),
        "total_attempts": total_attempts,
        "operation_success_rate": (len(successful) / len(completed)) if completed else None,
        "effective_completion_rate": effective_completion_rate,
        "operations_blocked_total": len(blocked),
        "operations_delayed_total": len(delayed),
        "abandon_after_failure_total": len(abandoned),
        "abandon_rate": (len(abandoned) / len(blocked)) if blocked else None,
        "sync_items_total": len(sync_items),
        "sync_push_success_rate": (len(sync_push_ok) / len(sync_push)) if sync_push else None,
        "sync_pull_success_rate": (len(sync_pull_ok) / len(sync_pull)) if sync_pull else None,
        "sync_success_rate": (len(sync_ok) / len(sync_items)) if sync_items else None,
        "avg_pending_to_sync_ms": (
            sum(pending_durations) / len(pending_durations) if pending_durations else None
        ),
    }


def daily_breakdown(events: list[dict]) -> dict[int, dict]:
    """Agrupa eventos por `dayOfStudy` (engajamento longitudinal)."""
    by_day: dict[int, list[dict]] = defaultdict(list)
    for event in events:
        day = event.get("dayOfStudy")
        if day is None:
            continue
        try:
            day_int = int(day)
        except (TypeError, ValueError):
            continue
        by_day[day_int].append(event)

    result: dict[int, dict] = {}
    for day, day_events in by_day.items():
        completed = [e for e in day_events if e.get("eventType") == "operation_completed"]
        blocked = [e for e in day_events if e.get("eventType") == "operation_blocked"]
        sessions = [e for e in day_events if e.get("eventType") == "session_started"]
        result[day] = {
            "total_operations": len(completed),
            "operations_blocked": len(blocked),
            "sessions": len(sessions),
        }
    return result
