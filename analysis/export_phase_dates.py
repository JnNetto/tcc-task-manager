#!/usr/bin/env python3
"""Datas reais das fases e exposição à degradação, por participante.

Lê `participants/*` e `telemetry/*` do RTDB (REST, como `fetch_data.py`) e
gera, sem nomes (apenas o código `Pxxx`):

- `output/datas_fases_participantes.csv`: uma linha por participante com
  início do estudo, troca de arquitetura, submissão/importação de T1 e T2,
  primeiro/último evento, `dayOfStudy` máximo, duração das fases, dias
  ativos, bloqueios no modo online-first (leitura × escrita), taxa efetiva
  com e sem bloqueios de leitura e pushes adiados no modo offline-first;
- `output/datas_fases_resumo.md`: estatísticas descritivas dos que
  concluíram T1 e T2.

Datas exibidas em horário de Brasília (UTC−3, sem horário de verão desde
2019). Fonte de cada campo:

- `study_started_at`: gravado pelo app na 1ª conexão (relógio do aparelho, UTC);
- troca: 1ª entrada de `architecture_timeline` com arquitetura diferente da
  inicial (gravada pelo painel do pesquisador, relógio do aparelho admin);
- `submitted_at`: relógio do navegador no envio do questionário HTML;
- `imported_at`: momento da importação do JSON pelo pesquisador;
- eventos: `timestamp` da telemetria (relógio do aparelho do participante).
"""

from __future__ import annotations

import argparse
import csv
import os
import sys
from collections import defaultdict
from datetime import datetime, timedelta, timezone
from pathlib import Path
from statistics import mean, median
from typing import Optional

import pandas as pd
from scipy.stats import spearmanr

from analyze_full_study import build_subjective_rows, participantes_completos_t1_t2
from domain import OFFLINE_FIRST, ONLINE_FIRST, normalize_arch, parse_iso_utc
from fetch_data import DEFAULT_DATABASE_URL, fetch_participants, fetch_telemetry

BRT = timezone(timedelta(hours=-3))
OPERATION_EVENTS = {"operation_started", "operation_completed", "operation_blocked"}
READ_OPS = {"watch_tasks"}

COLUMNS = [
    "participant_id",
    "concluiu_t1_t2",
    "ordem",
    "study_started_at",
    "troca_at",
    "n_trocas",
    "t1_submitted_at",
    "t1_imported_at",
    "t2_submitted_at",
    "t2_imported_at",
    "primeiro_evento",
    "ultimo_evento",
    "ultimo_evento_operacao",
    "max_day_of_study",
    "max_day_of_study_operacao",
    "dias_fase1",
    "dias_fase2",
    "dias_total_ate_t2",
    "dias_t1_ate_troca",
    "dias_fase_online",
    "dias_fase_offline",
    "dias_ativos_online",
    "dias_ativos_offline",
    "eventos_apos_t2",
    "sucessos_online",
    "falhas_reais_online",
    "bloqueios_online_total",
    "bloqueios_online_leitura",
    "bloqueios_online_escrita",
    "taxa_efetiva_online",
    "taxa_efetiva_online_sem_leitura",
    "ciclos_push_bloqueados",
    "ciclos_push_bloqueados_com_pendencia",
    "push_itens_sucesso",
    "push_itens_falha_real",
    "app_enabled",
    "days_online_phase_rtdb",
    "days_offline_phase_rtdb",
]


def _fmt_dt(dt: Optional[datetime]) -> str:
    return dt.astimezone(BRT).strftime("%Y-%m-%d %H:%M") if dt else ""


def _days(a: Optional[datetime], b: Optional[datetime]) -> Optional[float]:
    if a is None or b is None:
        return None
    return round((b - a).total_seconds() / 86400.0, 1) + 0.0


def _timeline(participant: dict) -> list[tuple[datetime, str]]:
    raw = participant.get("architecture_timeline")
    entries: list[tuple[datetime, str]] = []
    if isinstance(raw, dict):
        for entry in raw.values():
            if not isinstance(entry, dict):
                continue
            at = parse_iso_utc(entry.get("changed_at"))
            if at is not None:
                entries.append((at, normalize_arch(entry.get("architecture"))))
    entries.sort(key=lambda e: e[0])
    return entries


def _period(participant: dict, period: str) -> dict:
    subj = participant.get("subjective_questionnaires")
    subj = subj if isinstance(subj, dict) else {}
    payload = subj.get(period)
    return payload if isinstance(payload, dict) else {}


def _rate(num: int, den: int) -> Optional[float]:
    return round(num / den, 3) if den else None


def build_rows(participants: dict, telemetry: dict, completers: set[str]) -> list[dict]:
    rows = []
    for pid in sorted(set(participants) | set(telemetry)):
        part = participants.get(pid, {})
        tl = _timeline(part)
        start_arch = tl[0][1] if tl else normalize_arch(part.get("architecture"))
        other = OFFLINE_FIRST if start_arch == ONLINE_FIRST else ONLINE_FIRST

        study_started = parse_iso_utc(part.get("study_started_at"))
        troca = next((at for at, arch in tl if arch != start_arch), None)
        n_trocas = sum(1 for i in range(1, len(tl)) if tl[i][1] != tl[i - 1][1])

        t1, t2 = _period(part, "T1"), _period(part, "T2")
        t1_sub, t2_sub = parse_iso_utc(t1.get("submitted_at")), parse_iso_utc(t2.get("submitted_at"))

        events = telemetry.get(pid) if isinstance(telemetry.get(pid), dict) else {}
        ts_all: list[datetime] = []
        ts_ops: list[datetime] = []
        max_day = max_day_ops = None
        active_days: dict[str, set] = defaultdict(set)
        succ_on = blk_read = blk_write = comp_on = 0
        push_blocked = push_blocked_pending = push_ok = push_fail = 0
        after_t2 = 0
        for ev in events.values():
            if not isinstance(ev, dict):
                continue
            ts = parse_iso_utc(ev.get("timestamp"))
            etype = ev.get("eventType")
            arch = normalize_arch(ev.get("architecture"))
            data = ev.get("data") if isinstance(ev.get("data"), dict) else {}
            day = ev.get("dayOfStudy")
            if ts is not None:
                ts_all.append(ts)
                if t2_sub is not None and ts > t2_sub:
                    after_t2 += 1
            if isinstance(day, (int, float)):
                max_day = day if max_day is None else max(max_day, day)
            if etype in OPERATION_EVENTS:
                if ts is not None:
                    ts_ops.append(ts)
                    active_days[arch].add(ts.astimezone(BRT).date())
                if isinstance(day, (int, float)):
                    max_day_ops = day if max_day_ops is None else max(max_day_ops, day)
            if etype == "operation_completed" and arch == ONLINE_FIRST:
                comp_on += 1
                if data.get("success") is True:
                    succ_on += 1
            elif etype == "operation_blocked" and arch == ONLINE_FIRST:
                if data.get("op") in READ_OPS:
                    blk_read += 1
                else:
                    blk_write += 1
            elif etype == "sync_blocked" and arch == OFFLINE_FIRST:
                push_blocked += 1
            elif etype == "sync_started" and arch == OFFLINE_FIRST:
                if ev.get("networkDegraded") is True and (data.get("pending_count") or 0) > 0:
                    push_blocked_pending += 1
            elif etype == "sync_item" and data.get("direction") == "push":
                if data.get("success") is True:
                    push_ok += 1
                else:
                    push_fail += 1

        last_op = max(ts_ops) if ts_ops else None
        fase2_end = t2_sub or (last_op if troca and last_op and last_op > troca else None)
        dias_f1 = _days(study_started, troca)
        dias_f2 = _days(troca, fase2_end)
        dias_by_arch = {start_arch: dias_f1, other: dias_f2}

        rows.append({
            "participant_id": pid,
            "concluiu_t1_t2": pid in completers,
            "ordem": f"{start_arch}→{other}",
            "study_started_at": _fmt_dt(study_started),
            "troca_at": _fmt_dt(troca),
            "n_trocas": n_trocas,
            "t1_submitted_at": _fmt_dt(t1_sub),
            "t1_imported_at": _fmt_dt(parse_iso_utc(t1.get("imported_at"))),
            "t2_submitted_at": _fmt_dt(t2_sub),
            "t2_imported_at": _fmt_dt(parse_iso_utc(t2.get("imported_at"))),
            "primeiro_evento": _fmt_dt(min(ts_all) if ts_all else None),
            "ultimo_evento": _fmt_dt(max(ts_all) if ts_all else None),
            "ultimo_evento_operacao": _fmt_dt(max(ts_ops) if ts_ops else None),
            "max_day_of_study": max_day,
            "max_day_of_study_operacao": max_day_ops,
            "dias_fase1": dias_f1,
            "dias_fase2": dias_f2,
            "dias_total_ate_t2": _days(study_started, t2_sub),
            "dias_t1_ate_troca": _days(t1_sub, troca),
            "dias_fase_online": dias_by_arch[ONLINE_FIRST],
            "dias_fase_offline": dias_by_arch[OFFLINE_FIRST],
            "dias_ativos_online": len(active_days[ONLINE_FIRST]),
            "dias_ativos_offline": len(active_days[OFFLINE_FIRST]),
            "eventos_apos_t2": after_t2,
            "sucessos_online": succ_on,
            "falhas_reais_online": comp_on - succ_on,
            "bloqueios_online_total": blk_read + blk_write,
            "bloqueios_online_leitura": blk_read,
            "bloqueios_online_escrita": blk_write,
            "taxa_efetiva_online": _rate(succ_on, comp_on + blk_read + blk_write),
            "taxa_efetiva_online_sem_leitura": _rate(succ_on, comp_on + blk_write),
            "ciclos_push_bloqueados": push_blocked,
            "ciclos_push_bloqueados_com_pendencia": push_blocked_pending,
            "push_itens_sucesso": push_ok,
            "push_itens_falha_real": push_fail,
            "app_enabled": part.get("app_enabled"),
            "days_online_phase_rtdb": part.get("days_online_phase"),
            "days_offline_phase_rtdb": part.get("days_offline_phase"),
        })
    return rows


def _desc(values: list, decimals: int = 1) -> str:
    vals = [v for v in values if isinstance(v, (int, float)) and not isinstance(v, bool)]
    if not vals:
        return "—"
    d = decimals
    return (
        f"n={len(vals)}; média {mean(vals):.{d}f}; mediana {median(vals):.{d}f}; "
        f"mín {min(vals):.{d}f}; máx {max(vals):.{d}f}"
    )


def render_summary(rows: list[dict]) -> str:
    comp = [r for r in rows if r["concluiu_t1_t2"]]
    col = lambda name: [r[name] for r in comp]  # noqa: E731
    starts = sorted(r["study_started_at"] for r in comp if r["study_started_at"])
    ends = sorted(r["t2_submitted_at"] for r in comp if r["t2_submitted_at"])

    rho_tot = rho_wr = None
    pairs = [
        (r["dias_fase_online"], r["bloqueios_online_total"], r["bloqueios_online_escrita"])
        for r in comp if isinstance(r["dias_fase_online"], (int, float))
    ]
    if len(pairs) >= 3:
        d, bt, bw = zip(*pairs)
        rho_tot = spearmanr(d, bt)
        rho_wr = spearmanr(d, bw)

    succ = sum(col("sucessos_online"))
    blk_r = sum(col("bloqueios_online_leitura"))
    blk_w = sum(col("bloqueios_online_escrita"))
    over_30 = sum(1 for v in col("dias_total_ate_t2") if isinstance(v, (int, float)) and v > 30)
    over_42 = sum(1 for v in col("max_day_of_study_operacao") if isinstance(v, (int, float)) and v > 42)

    lines = [
        "# Datas reais das fases e exposição (participantes que concluíram T1 e T2)",
        "",
        f"Gerado por `analysis/export_phase_dates.py`. n = {len(comp)}. Datas em UTC−3.",
        "Detalhe por participante: `output/datas_fases_participantes.csv` (sem nomes).",
        "",
        "## Calendário",
        "",
        f"- Primeiro início de estudo: {starts[0] if starts else '—'}; último início: {starts[-1] if starts else '—'}.",
        f"- Primeira submissão de T2: {ends[0] if ends else '—'}; última: {ends[-1] if ends else '—'}.",
        f"- Participantes com mais de uma troca registrada: {sum(1 for r in comp if r['n_trocas'] > 1)}.",
        "",
        "## Duração (dias corridos)",
        "",
        "| Medida | Descrição |",
        "| --- | --- |",
        f"| Fase 1 (início → troca) | {_desc(col('dias_fase1'))} |",
        f"| Fase 2 (troca → envio do T2) | {_desc(col('dias_fase2'))} |",
        f"| Total (início → envio do T2) | {_desc(col('dias_total_ate_t2'))} |",
        f"| Fase online-first | {_desc(col('dias_fase_online'))} |",
        f"| Fase offline-first | {_desc(col('dias_fase_offline'))} |",
        f"| Envio do T1 → troca | {_desc(col('dias_t1_ate_troca'))} |",
        f"| Dias com operações (online-first) | {_desc(col('dias_ativos_online'))} |",
        f"| Dias com operações (offline-first) | {_desc(col('dias_ativos_offline'))} |",
        f"| `dayOfStudy` máximo em operações | {_desc(col('max_day_of_study_operacao'))} |",
        "",
        f"- Participantes com duração total acima de 30 dias: {over_30} de {len(comp)}.",
        f"- Participantes com operação registrada após o dia 42 (semana 7 da Tabela 10): {over_42} de {len(comp)}.",
        "- `dayOfStudy` é contado desde `study_started_at` (não reinicia na troca), por isso",
        "  a Tabela 10 alcança a semana 7 quando a participação total passa de 42 dias.",
        "",
        "## Exposição à degradação no modo online-first",
        "",
        f"- Sucessos: {succ}; bloqueios de escrita (create/update/delete/impressão): {blk_w};",
        f"  bloqueios de leitura da lista (`watch_tasks`): {blk_r}.",
        f"- Taxa efetiva agregada atual (com leitura no denominador): {succ}/{succ + blk_r + blk_w} = "
        f"{succ / (succ + blk_r + blk_w):.3f}." if succ + blk_r + blk_w else "- Sem eventos online.",
        f"- Taxa efetiva agregada só com escritas: {succ}/{succ + blk_w} = {succ / (succ + blk_w):.3f}."
        if succ + blk_w else "",
        f"- Taxa efetiva por participante (atual): {_desc(col('taxa_efetiva_online'), 3)}.",
        f"- Taxa efetiva por participante (sem leitura): {_desc(col('taxa_efetiva_online_sem_leitura'), 3)}"
        " (participante sem nenhuma escrita online fica sem valor).",
        f"- Falhas reais (`operation_completed` com `success=false`) no modo online-first: "
        f"{sum(col('falhas_reais_online'))}.",
        f"- Participantes sem nenhum bloqueio online: {sum(1 for v in col('bloqueios_online_total') if v == 0)}.",
    ]
    if rho_tot is not None:
        lines += [
            f"- Spearman (dias da fase online × bloqueios totais): rho = {rho_tot.statistic:.3f}, p = {rho_tot.pvalue:.4f}.",
            f"- Spearman (dias da fase online × bloqueios de escrita): rho = {rho_wr.statistic:.3f}, p = {rho_wr.pvalue:.4f}.",
        ]
    lines += [
        "",
        "## Pushes adiados no modo offline-first",
        "",
        f"- Ciclos de sincronização com push vetado pelo simulador (`sync_blocked`): "
        f"{sum(col('ciclos_push_bloqueados'))}; {_desc(col('ciclos_push_bloqueados'))} por participante.",
        "  O evento é emitido em todo ciclo (15 s, mutação ou abertura) durante degradação,",
        "  mesmo sem nada pendente.",
        f"- Desses, ciclos com pelo menos uma tarefa pendente (push efetivamente adiado): "
        f"{sum(col('ciclos_push_bloqueados_com_pendencia'))}; "
        f"{_desc(col('ciclos_push_bloqueados_com_pendencia'))} por participante.",
        f"- Itens enviados com sucesso (`sync_item` push): {sum(col('push_itens_sucesso'))}; "
        f"falhas reais de push: {sum(col('push_itens_falha_real'))}.",
        "- Push adiado não gera `operation_blocked`: a operação local já foi concluída e a",
        "  tarefa permanece `pending` até um ciclo fora da degradação.",
        "",
    ]
    return "\n".join(lines)


def parse_args(argv: Optional[list[str]] = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument(
        "--database-url",
        default=os.environ.get("FIREBASE_DATABASE_URL", DEFAULT_DATABASE_URL),
    )
    parser.add_argument("--output-dir", default=str(Path(__file__).parent / "output"))
    return parser.parse_args(argv)


def main(argv: Optional[list[str]] = None) -> int:
    args = parse_args(argv)
    participants = fetch_participants(args.database_url)
    telemetry = fetch_telemetry(args.database_url)
    subj, _ = build_subjective_rows(participants)
    completers = participantes_completos_t1_t2(pd.DataFrame(subj))

    rows = build_rows(participants, telemetry, completers)
    out = Path(args.output_dir)
    out.mkdir(parents=True, exist_ok=True)
    with open(out / "datas_fases_participantes.csv", "w", newline="", encoding="utf-8-sig") as f:
        writer = csv.DictWriter(f, fieldnames=COLUMNS)
        writer.writeheader()
        writer.writerows(rows)
    (out / "datas_fases_resumo.md").write_text(render_summary(rows), encoding="utf-8")
    print(f"{len(rows)} participantes ({len(completers)} concluíram T1 e T2) -> {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
