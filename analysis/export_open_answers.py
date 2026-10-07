#!/usr/bin/env python3
"""Exporta respostas abertas (texto livre) do RTDB.

As três perguntas do bloco «Em suas palavras» existem em T1 e em T2
(`responses.open_answers.{liked,frustrated,gaveup}`). O CSV principal
tem **uma linha por participante**, com `arq_T1` / `arq_T2` (fase) e as
seis colunas de texto (3 × período), para não perder metade do material
qualitativo nem o contexto de ordem ao ler «o primeiro / o segundo».

Também gera um CSV longo (uma linha por participante × período) com as
colunas `pergunta1..3` no formato pedido pelo texto.
"""

from __future__ import annotations

import argparse
import csv
import os
import sys
from pathlib import Path

from domain import resolve_period_architecture, resolve_start_architecture
from fetch_data import ADMIN_PARTICIPANT_ID, DEFAULT_DATABASE_URL, fetch_participants

# Enunciados exatos — questionario_T1.html / questionario_T2.html (bloco 5)
ENUNCIADOS = {
    "pergunta1": "O que mais te agradou no aplicativo nas últimas duas semanas?",
    "pergunta2": "O que mais te frustrou ou atrapalhou?",
    "pergunta3": (
        "Houve algum momento em que você desistiu de usar o aplicativo? "
        "Se sim, o que aconteceu?"
    ),
}

OPEN_KEYS = (
    ("pergunta1", "liked"),
    ("pergunta2", "frustrated"),
    ("pergunta3", "gaveup"),
)


def _open_answers(payload: dict | None) -> dict[str, str]:
    if not isinstance(payload, dict):
        return {col: "" for col, _ in OPEN_KEYS}
    responses = payload.get("responses")
    responses = responses if isinstance(responses, dict) else {}
    raw = responses.get("open_answers")
    raw = raw if isinstance(raw, dict) else {}
    out: dict[str, str] = {}
    for col, key in OPEN_KEYS:
        val = raw.get(key)
        out[col] = "" if val is None else str(val).strip()
    return out


def _period_arch(participant: dict, subjective: dict, period: str) -> str:
    payload = subjective.get(period)
    if not isinstance(payload, dict):
        # Sem questionário: infere pela ordem (T1 = start; T2 = oposta)
        start, _ = resolve_start_architecture(participant)
        if period == "T1":
            return start
        return "offline-first" if start == "online-first" else "online-first"
    arch, _ = resolve_period_architecture(participant, payload)
    return arch


def build_rows(participants: dict) -> tuple[list[dict], list[dict]]:
    """Retorna (wide_rows, long_rows)."""
    wide: list[dict] = []
    long: list[dict] = []

    for pid in sorted(participants.keys()):
        if pid == ADMIN_PARTICIPANT_ID:
            continue
        participant = participants[pid]
        if not isinstance(participant, dict):
            continue

        subjective = participant.get("subjective_questionnaires")
        if not isinstance(subjective, dict):
            continue
        if not any(isinstance(subjective.get(p), dict) for p in ("T1", "T2")):
            continue

        arq_t1 = _period_arch(participant, subjective, "T1")
        arq_t2 = _period_arch(participant, subjective, "T2")
        opens_t1 = _open_answers(subjective.get("T1"))
        opens_t2 = _open_answers(subjective.get("T2"))

        wide.append(
            {
                "participant_id": pid,
                "arq_T1": arq_t1,
                "arq_T2": arq_t2,
                "pergunta1_T1": opens_t1["pergunta1"],
                "pergunta2_T1": opens_t1["pergunta2"],
                "pergunta3_T1": opens_t1["pergunta3"],
                "pergunta1_T2": opens_t2["pergunta1"],
                "pergunta2_T2": opens_t2["pergunta2"],
                "pergunta3_T2": opens_t2["pergunta3"],
            }
        )

        for period, opens, arq in (
            ("T1", opens_t1, arq_t1),
            ("T2", opens_t2, arq_t2),
        ):
            if not isinstance(subjective.get(period), dict):
                continue
            long.append(
                {
                    "participant_id": pid,
                    "periodo": period,
                    "arquitetura_periodo": arq,
                    "arq_T1": arq_t1,
                    "arq_T2": arq_t2,
                    "pergunta1": opens["pergunta1"],
                    "pergunta2": opens["pergunta2"],
                    "pergunta3": opens["pergunta3"],
                }
            )

    return wide, long


def write_csv(path: Path, rows: list[dict], fieldnames: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8-sig", newline="") as fh:
        writer = csv.DictWriter(
            fh,
            fieldnames=fieldnames,
            quoting=csv.QUOTE_MINIMAL,
            extrasaction="ignore",
        )
        writer.writeheader()
        for row in rows:
            writer.writerow(row)


def write_enunciados(path: Path) -> None:
    path.write_text(
        """# Enunciados das perguntas abertas

Fonte: `questionario_T1.html` e `questionario_T2.html`, seção **«Em suas palavras»**
(bloco 5). Os enunciados são **idênticos** em T1 e T2.

| Coluna | Campo RTDB (`open_answers`) | Enunciado exato |
|---|---|---|
| `pergunta1` | `liked` | O que mais te agradou no aplicativo nas últimas duas semanas? |
| `pergunta2` | `frustrated` | O que mais te frustrou ou atrapalhou? |
| `pergunta3` | `gaveup` | Houve algum momento em que você desistiu de usar o aplicativo? Se sim, o que aconteceu? |

## Texto para Seção 3.4.1 / Apêndice C

Ao final de cada período (T1 e T2), o instrumento inclui três perguntas abertas
de resposta livre:

1. O que mais te agradou no aplicativo nas últimas duas semanas?
2. O que mais te frustrou ou atrapalhou?
3. Houve algum momento em que você desistiu de usar o aplicativo? Se sim, o que aconteceu?

Cada resposta refere-se à arquitetura vigente naquele período. As colunas
`arq_T1` e `arq_T2` no CSV de exportação indicam a ordem de exposição
(contrabalanceamento), necessária para interpretar menções a «o primeiro» /
«o segundo» aplicativo.
""",
        encoding="utf-8",
    )


def parse_args(argv=None):
    p = argparse.ArgumentParser(description="Exporta respostas abertas do RTDB.")
    p.add_argument("--database-url", default=None)
    p.add_argument(
        "--output-dir",
        default=str(Path(__file__).parent / "output"),
    )
    return p.parse_args(argv)


def main(argv=None) -> int:
    args = parse_args(argv)
    out = Path(args.output_dir)
    database_url = (
        args.database_url or os.environ.get("FIREBASE_DATABASE_URL") or DEFAULT_DATABASE_URL
    )
    print(f"Buscando participantes em {database_url} ...")
    participants = fetch_participants(database_url)
    wide, long = build_rows(participants)

    wide_path = out / "respostas_abertas.csv"
    long_path = out / "respostas_abertas_por_periodo.csv"
    enunciados_path = out / "respostas_abertas_enunciados.md"

    write_csv(
        wide_path,
        wide,
        [
            "participant_id",
            "arq_T1",
            "arq_T2",
            "pergunta1_T1",
            "pergunta2_T1",
            "pergunta3_T1",
            "pergunta1_T2",
            "pergunta2_T2",
            "pergunta3_T2",
        ],
    )
    write_csv(
        long_path,
        long,
        [
            "participant_id",
            "periodo",
            "arquitetura_periodo",
            "arq_T1",
            "arq_T2",
            "pergunta1",
            "pergunta2",
            "pergunta3",
        ],
    )
    write_enunciados(enunciados_path)

    n_both = sum(
        1
        for r in wide
        if any(r[f"pergunta{i}_T1"] for i in (1, 2, 3))
        and any(r[f"pergunta{i}_T2"] for i in (1, 2, 3))
    )
    print(f"Participantes com questionário: {len(wide)}")
    print(f"  com texto em T1 e T2: {n_both}")
    print(f"Linhas por período: {len(long)}")
    print(f"→ {wide_path}")
    print(f"→ {long_path}")
    print(f"→ {enunciados_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
