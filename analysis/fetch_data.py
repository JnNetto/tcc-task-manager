"""Coleta de dados do estudo a partir do Firebase Realtime Database.

Fontes, em ordem de prioridade:

1. variável de ambiente `TCC_RTDB_SNAPSHOT` apontando para um JSON exportado
   (`firebase database:get / -o arquivo.json`);
2. `database_url` igual ao caminho de um arquivo `.json` local;
3. REST do RTDB (`{database_url}/{path}.json`), sem credenciais. Se o banco
   recusar a leitura (401/403, regras fechadas), usa o snapshot mais recente
   em `analysis/data/`.

O snapshot é pseudonimizado (sem nomes, mas com dados por participante): fica
em `analysis/data/`, que é ignorado pelo Git, e não deve ser publicado.
"""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path
from typing import Optional

import requests

# Mesmo projeto referenciado em lib/firebase_options.dart.
DEFAULT_DATABASE_URL = "https://tcc-task-manager-82e52-default-rtdb.firebaseio.com"

# Reservado ao painel investigador (lib/config/debug_admin.dart); não é
# participante do estudo e deve ser excluído de qualquer análise.
ADMIN_PARTICIPANT_ID = "P000"

SNAPSHOT_ENV = "TCC_RTDB_SNAPSHOT"
SNAPSHOT_DIR = Path(__file__).parent / "data"

_REQUEST_TIMEOUT_SECONDS = 30
_snapshot_cache: dict[str, dict] = {}


def _latest_snapshot() -> Optional[Path]:
    files = sorted(SNAPSHOT_DIR.glob("rtdb_snapshot_*.json"))
    return files[-1] if files else None


def _load_snapshot(path: Path) -> dict:
    key = str(path.resolve())
    if key not in _snapshot_cache:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        if not isinstance(data, dict):
            raise ValueError(f"Snapshot inesperado em {path}: esperado objeto JSON.")
        _snapshot_cache[key] = data
    return _snapshot_cache[key]


def _from_snapshot(path: Path, node: str) -> dict:
    data = _load_snapshot(path).get(node)
    return data if isinstance(data, dict) else {}


def _snapshot_source(database_url: str) -> Optional[Path]:
    env = os.environ.get(SNAPSHOT_ENV)
    if env:
        return Path(env)
    if database_url.lower().endswith(".json") and Path(database_url).is_file():
        return Path(database_url)
    return None


def _get_json(database_url: str, path: str) -> dict:
    snapshot = _snapshot_source(database_url)
    if snapshot is not None:
        return _from_snapshot(snapshot, path)

    url = f"{database_url.rstrip('/')}/{path}.json"
    response = requests.get(url, timeout=_REQUEST_TIMEOUT_SECONDS)
    if response.status_code in (401, 403):
        fallback = _latest_snapshot()
        if fallback is None:
            response.raise_for_status()
        print(
            f"[fetch_data] RTDB recusou leitura ({response.status_code}); "
            f"usando snapshot local {fallback.name}.",
            file=sys.stderr,
        )
        return _from_snapshot(fallback, path)
    response.raise_for_status()
    data = response.json()
    if data is None:
        return {}
    if not isinstance(data, dict):
        raise ValueError(
            f"Resposta inesperada em {url}: esperado objeto JSON, recebido {type(data)}."
        )
    return data


def fetch_participants(database_url: str) -> dict:
    """Busca `participants/*`, excluindo o slot do administrador (P000)."""
    raw = _get_json(database_url, "participants")
    return {
        pid: payload
        for pid, payload in raw.items()
        if pid != ADMIN_PARTICIPANT_ID and isinstance(payload, dict)
    }


def fetch_telemetry(database_url: str) -> dict:
    """Busca `telemetry/*`, excluindo o slot do administrador (P000)."""
    raw = _get_json(database_url, "telemetry")
    return {
        pid: payload
        for pid, payload in raw.items()
        if pid != ADMIN_PARTICIPANT_ID and isinstance(payload, dict)
    }
