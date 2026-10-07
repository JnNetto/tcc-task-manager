"""Resolução da arquitetura vigente em cada período do estudo.

O questionário T1/T2 refere-se à **fase** do estudo (primeiro ou segundo
período), não ao segundo exato do envio. Por isso, quando existe
`architecture_during_period` gravado na importação, esse valor tem
prioridade (semântica de fase).

O recálculo via `architecture_timeline` + `submitted_at` (espelhando
`architectureAtInstant` do Flutter) continua disponível como checagem de
consistência e como fallback quando o campo gravado falta. Isso evita o
caso P016: questionário da 1ª fase enviado minutos após a troca de
arquitetura — o instante do submit apontaria a 2ª fase, mas o período
avaliado continua sendo a 1ª.
"""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Optional

ONLINE_FIRST = "online-first"
OFFLINE_FIRST = "offline-first"


def normalize_arch(value: object) -> str:
    return OFFLINE_FIRST if value == OFFLINE_FIRST else ONLINE_FIRST


def parse_iso_utc(value: object) -> Optional[datetime]:
    if value is None:
        return None
    text = str(value).strip()
    if not text:
        return None
    if text.endswith("Z"):
        text = text[:-1] + "+00:00"
    try:
        dt = datetime.fromisoformat(text)
    except ValueError:
        return None
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)


def architecture_at_instant(
    participant: dict,
    instant: datetime,
    study_started_full: datetime,
) -> str:
    """Espelha `architectureAtInstant` (Dart): arquitetura vigente em `instant`."""
    if instant < study_started_full:
        return normalize_arch(participant.get("architecture"))

    timeline = participant.get("architecture_timeline")
    entries: list[tuple[datetime, str]] = []
    if isinstance(timeline, dict):
        for entry in timeline.values():
            if not isinstance(entry, dict):
                continue
            at = parse_iso_utc(entry.get("changed_at"))
            if at is None:
                continue
            entries.append((at, normalize_arch(entry.get("architecture"))))
        entries.sort(key=lambda e: e[0])

    last: Optional[str] = None
    for at, arch in entries:
        if at > instant:
            break
        last = arch
    return last if last is not None else normalize_arch(participant.get("architecture"))


def resolve_start_architecture(participant: dict) -> tuple[str, str]:
    """Arquitetura da **1ª fase** (ordem de exposição / T1).

    Prioridade:
      1. primeira entrada de `architecture_timeline` (fonte confiável no RTDB)
      2. `assigned_architecture` (quando preenchido no cadastro)
      3. `architecture` corrente (último recurso — costuma ser a fase atual/T2)

    Retorna `(architecture, source)`.
    """
    timeline = participant.get("architecture_timeline")
    entries: list[tuple[datetime, str]] = []
    if isinstance(timeline, dict):
        for entry in timeline.values():
            if not isinstance(entry, dict):
                continue
            at = parse_iso_utc(entry.get("changed_at"))
            if at is None:
                continue
            entries.append((at, normalize_arch(entry.get("architecture"))))
        entries.sort(key=lambda e: e[0])
    if entries:
        return entries[0][1], "timeline_first"

    assigned = participant.get("assigned_architecture")
    if assigned:
        return normalize_arch(assigned), "assigned_architecture"

    return normalize_arch(participant.get("architecture")), "fallback_current"


def resolve_period_architecture(
    participant: dict,
    period_payload: dict,
) -> tuple[str, str]:
    """Resolve a arquitetura da fase (T1/T2) para pareamento subjetivo.

    Retorna `(architecture, source)`, onde `source` é:
      - "stored_period":    usou `architecture_during_period` (semântica de fase).
      - "recalculated":     sem valor gravado; usou timeline + `submitted_at`.
      - "fallback_current": sem gravado e sem dados para recalcular; usou
                            `architecture` corrente.
    """
    stored = period_payload.get("architecture_during_period")
    if stored:
        return normalize_arch(stored), "stored_period"

    study_started = parse_iso_utc(participant.get("study_started_at"))
    submitted_at = parse_iso_utc(period_payload.get("submitted_at"))

    if study_started is not None and submitted_at is not None:
        return architecture_at_instant(participant, submitted_at, study_started), "recalculated"

    return normalize_arch(participant.get("architecture")), "fallback_current"


def warn_submit_vs_phase(
    participant_id: str,
    period: str,
    participant: dict,
    period_payload: dict,
    phase_architecture: str,
) -> Optional[str]:
    """Avisa se `submitted_at` cairia em arquitetura diferente da fase adotada."""
    study_started = parse_iso_utc(participant.get("study_started_at"))
    submitted_at = parse_iso_utc(period_payload.get("submitted_at"))
    if study_started is None or submitted_at is None:
        return None
    at_submit = architecture_at_instant(participant, submitted_at, study_started)
    if at_submit == phase_architecture:
        return None
    return (
        f"{participant_id} [{period}]: adotada arquitetura de fase "
        f"'{phase_architecture}' (architecture_during_period); no instante do "
        f"submit a timeline apontaria '{at_submit}'. Questionario da fase "
        f"enviado apos a troca — pareamento usa a fase, nao o relogio do envio."
    )
