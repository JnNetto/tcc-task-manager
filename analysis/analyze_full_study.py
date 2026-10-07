#!/usr/bin/env python3
"""Análise completa do estudo (H1/H2) a partir dos dados gravados no RTDB.

Busca todos os participantes e toda a telemetria do Firebase Realtime
Database, calcula os escores subjetivos (SUS, confiabilidade percebida,
contexto) e as métricas objetivas de telemetria, pareia por participante
nas duas arquiteturas (`online-first` / `offline-first`) e executa o teste
de Wilcoxon pareado para as hipóteses H1 e H2 definidas em
`especificacoes_tecnicas_v4 (1).md` (seções 1.2 e 2.4-2.6).

Uso:
    python analyze_full_study.py [--database-url URL] [--min-pairs N] [--output-dir DIR]

Saídas (em `--output-dir`, default `analysis/output/`):
    - metrics_by_participant.csv  — uma linha por participante x arquitetura
    - hypothesis_tests.md         — relatório com os testes de H1/H2 e avisos
    - results.png                 — gráficos (SUS, confiabilidade, sucesso, engajamento)

IMPORTANTE: a chave de pareamento por arquitetura é sempre
`architecture_during_period` (recalculada de forma independente em
`domain.py`), nunca `assigned_architecture` — ver decisão registrada em
`docs/rastreabilidade.md`.

Elegibilidade: apenas participantes que responderam **T1 e T2**. Quem não
completou os dois questionários é excluído das análises H1/H2 (subjetivas e
objetivas).
"""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path
from typing import Optional

import matplotlib

matplotlib.use("Agg")  # nao depende de display grafico (execucao via CLI)

import matplotlib.pyplot as plt
import pandas as pd
import seaborn as sns
from scipy import stats

from domain import (
    OFFLINE_FIRST,
    ONLINE_FIRST,
    normalize_arch,
    resolve_period_architecture,
    warn_submit_vs_phase,
)
from fetch_data import (
    ADMIN_PARTICIPANT_ID,
    DEFAULT_DATABASE_URL,
    fetch_participants,
    fetch_telemetry,
)
from metrics import (
    CONTEXT_IDS,
    RELIABILITY_TECHNICAL_IDS,
    RELIABILITY_TRUST_IDS,
    aggregate_objective_metrics,
    comparative_mean,
    daily_breakdown,
    likert_score,
    sus_score,
)

SUBJECTIVE_SCORE_COLUMNS = [
    "sus_score",
    "reliability_technical_score",
    "reliability_trust_score",
    "context_score",
]


def participantes_completos_t1_t2(subjective_df: pd.DataFrame) -> set[str]:
    """IDs com resposta em T1 e em T2 — amostra analitica do estudo."""
    if subjective_df.empty or "participant_id" not in subjective_df.columns:
        return set()
    q = subjective_df.groupby("participant_id")["period"].nunique()
    return set(q[q >= 2].index)


def filtrar_por_completos(
    df: pd.DataFrame, ids_completos: set[str], id_col: str = "participant_id"
) -> pd.DataFrame:
    if df.empty or id_col not in df.columns:
        return df
    return df[df[id_col].isin(ids_completos)].copy()


# ───────────────────────────── coleta -> linhas ──────────────────────────────


def build_subjective_rows(participants: dict) -> tuple[list[dict], list[str]]:
    rows: list[dict] = []
    warnings: list[str] = []

    for participant_id, participant in participants.items():
        if participant_id == ADMIN_PARTICIPANT_ID or not isinstance(participant, dict):
            continue
        subjective = participant.get("subjective_questionnaires")
        if not isinstance(subjective, dict):
            continue

        for period in ("T1", "T2"):
            payload = subjective.get(period)
            if not isinstance(payload, dict):
                continue

            architecture, source = resolve_period_architecture(participant, payload)
            warning = warn_submit_vs_phase(
                participant_id,
                period,
                participant,
                payload,
                architecture,
            )
            if warning:
                warnings.append(warning)

            responses = payload.get("responses")
            responses = responses if isinstance(responses, dict) else {}
            reverse_items = responses.get("reverse_items") or []

            row = {
                "participant_id": participant_id,
                "period": period,
                "architecture": architecture,
                "architecture_source": source,
                "sus_score": sus_score(responses.get("sus") or {}),
                "reliability_technical_score": likert_score(
                    responses.get("reliability_technical") or {},
                    RELIABILITY_TECHNICAL_IDS,
                    reverse_items,
                    1,
                    7,
                ),
                "reliability_trust_score": likert_score(
                    responses.get("reliability_trust") or {},
                    RELIABILITY_TRUST_IDS,
                    reverse_items,
                    1,
                    7,
                ),
                "context_score": likert_score(
                    responses.get("context") or {},
                    CONTEXT_IDS,
                    reverse_items,
                    1,
                    7,
                ),
                "comparative_mean": None,
                "preferred_version": None,
            }

            if period == "T2":
                comparative = responses.get("comparative") or {}
                row["comparative_mean"] = comparative_mean(comparative)
                row["preferred_version"] = comparative.get("preferred_version")

            rows.append(row)

    return rows, warnings


def build_objective_rows(telemetry: dict) -> tuple[list[dict], list[dict]]:
    rows: list[dict] = []
    daily_rows: list[dict] = []

    for participant_id, events_map in telemetry.items():
        if participant_id == ADMIN_PARTICIPANT_ID or not isinstance(events_map, dict):
            continue

        events = [e for e in events_map.values() if isinstance(e, dict)]
        events_by_architecture: dict[str, list[dict]] = {}
        for event in events:
            architecture = normalize_arch(event.get("architecture"))
            events_by_architecture.setdefault(architecture, []).append(event)

        for architecture, architecture_events in events_by_architecture.items():
            metrics = aggregate_objective_metrics(architecture_events)
            metrics["participant_id"] = participant_id
            metrics["architecture"] = architecture
            rows.append(metrics)

            for day, day_metrics in daily_breakdown(architecture_events).items():
                daily_rows.append(
                    {
                        "participant_id": participant_id,
                        "architecture": architecture,
                        "day_of_study": day,
                        **day_metrics,
                    }
                )

    return rows, daily_rows


# ───────────────────────────── combinação / pivots ───────────────────────────


def merge_combined(subjective_df: pd.DataFrame, objective_df: pd.DataFrame) -> pd.DataFrame:
    if subjective_df.empty and objective_df.empty:
        return pd.DataFrame()

    if subjective_df.empty:
        return objective_df

    subjective_agg = subjective_df.groupby(
        ["participant_id", "architecture"], as_index=False
    )[SUBJECTIVE_SCORE_COLUMNS].mean()

    if objective_df.empty:
        return subjective_agg

    return pd.merge(
        subjective_agg, objective_df, on=["participant_id", "architecture"], how="outer"
    )


def pivot_metric(df: pd.DataFrame, metric: str) -> pd.DataFrame:
    if df.empty or metric not in df.columns:
        return pd.DataFrame()
    subset = df[["participant_id", "architecture", metric]].dropna(subset=[metric])
    if subset.empty:
        return pd.DataFrame()
    return subset.pivot_table(
        index="participant_id", columns="architecture", values=metric, aggfunc="mean"
    )


# ───────────────────────────── testes estatísticos ───────────────────────────


def wilcoxon_test(pivot: pd.DataFrame, min_pairs: int) -> dict:
    if pivot.empty or ONLINE_FIRST not in pivot.columns or OFFLINE_FIRST not in pivot.columns:
        return {"n_pairs": 0, "status": "sem_dados_pareados"}

    paired = pivot[[ONLINE_FIRST, OFFLINE_FIRST]].dropna()
    n_pairs = len(paired)

    result = {
        "n_pairs": n_pairs,
        "mean_online": paired[ONLINE_FIRST].mean() if n_pairs else None,
        "sd_online": paired[ONLINE_FIRST].std() if n_pairs else None,
        "mean_offline": paired[OFFLINE_FIRST].mean() if n_pairs else None,
        "sd_offline": paired[OFFLINE_FIRST].std() if n_pairs else None,
    }

    if n_pairs < min_pairs:
        result["status"] = f"pares_insuficientes (n={n_pairs} < min_pairs={min_pairs})"
        return result

    diffs = paired[OFFLINE_FIRST] - paired[ONLINE_FIRST]
    if (diffs == 0).all():
        result["status"] = "sem_variabilidade (todas as diferencas sao zero)"
        return result

    try:
        w_stat, p_value = stats.wilcoxon(paired[ONLINE_FIRST], paired[OFFLINE_FIRST])
    except ValueError as exc:
        result["status"] = f"erro_wilcoxon: {exc}"
        return result

    z = stats.norm.ppf(p_value / 2) if p_value > 0 else float("-inf")
    effect_size_r = abs(z) / (diffs != 0).sum()**0.5 if n_pairs and z != float("-inf") else None

    result.update(
        {
            "status": "ok",
            "w_stat": w_stat,
            "p_value": p_value,
            "effect_size_r": effect_size_r,
        }
    )
    return result


def order_effect_table(subjective_df: pd.DataFrame) -> pd.DataFrame:
    if subjective_df.empty:
        return pd.DataFrame()
    first_phase = subjective_df[subjective_df["period"] == "T1"][
        ["participant_id", "architecture"]
    ].rename(columns={"architecture": "first_architecture"})
    if first_phase.empty:
        return pd.DataFrame()
    merged = subjective_df.merge(first_phase, on="participant_id", how="left")
    return (
        merged.groupby(["first_architecture", "architecture"])["sus_score"]
        .agg(["mean", "std", "count"])
        .reset_index()
    )


def weekly_engagement(daily_df: pd.DataFrame) -> pd.DataFrame:
    if daily_df.empty:
        return daily_df
    df = daily_df.copy()
    df["week"] = ((df["day_of_study"] - 1) // 7) + 1
    return df.groupby(["architecture", "week"])["total_operations"].mean().reset_index()


def describe_offline_only_metrics(objective_df: pd.DataFrame) -> pd.DataFrame:
    columns = ["sync_push_success_rate", "sync_pull_success_rate", "avg_pending_to_sync_ms"]
    existing = [c for c in columns if c in objective_df.columns]
    if objective_df.empty or not existing:
        return pd.DataFrame()
    return objective_df.groupby("architecture")[existing].agg(["mean", "std", "count"])


# ───────────────────────────── relatório / gráficos ──────────────────────────


def _fmt(value: Optional[float], decimals: int = 3) -> str:
    return "n/d" if value is None or pd.isna(value) else f"{value:.{decimals}f}"


def format_test_block(title: str, result: dict, higher_is_better: bool) -> list[str]:
    lines = [f"### {title}", "", f"- Pares válidos (participante com as duas arquiteturas): {result.get('n_pairs', 0)}"]

    if result.get("status") != "ok":
        lines.append(f"- Status: {result.get('status')}")
        lines.append("")
        return lines

    lines.append(f"- Online-first:  M={_fmt(result['mean_online'])}  SD={_fmt(result['sd_online'])}")
    lines.append(f"- Offline-first: M={_fmt(result['mean_offline'])}  SD={_fmt(result['sd_offline'])}")
    lines.append(
        f"- Wilcoxon: W={_fmt(result['w_stat'])}, p={_fmt(result['p_value'], 4)}, "
        f"r={_fmt(result['effect_size_r'])}"
    )

    p_value = result["p_value"]
    if p_value is None or p_value >= 0.05:
        lines.append("- Conclusão: diferença não significativa (H0 não rejeitada para esta métrica).")
    else:
        offline_better = (
            result["mean_offline"] > result["mean_online"]
            if higher_is_better
            else result["mean_offline"] < result["mean_online"]
        )
        if offline_better:
            lines.append("- Conclusão: diferença significativa **favorecendo offline-first**.")
        else:
            lines.append(
                "- Conclusão: diferença significativa **favorecendo online-first** "
                "(sentido contrário ao previsto pela hipótese direcional)."
            )
    lines.append("")
    return lines


def render_report(
    *,
    n_participants: int,
    n_completos_t1_t2: int,
    warnings: list[str],
    h1_results: dict,
    h2_results: dict,
    context_result: dict,
    order_df: pd.DataFrame,
    weekly_df: pd.DataFrame,
    offline_only_df: pd.DataFrame,
    min_pairs: int,
) -> str:
    lines: list[str] = []
    lines.append("# Relatório de análise — H1/H2 (gerado automaticamente)")
    lines.append("")
    lines.append(f"Participantes com dados encontrados: {n_participants}")
    lines.append(
        f"Amostra analítica (T1 **e** T2): **{n_completos_t1_t2}** — "
        "incompletos excluídos de H1/H2."
    )
    lines.append(f"Limite mínimo de pares para teste de Wilcoxon: {min_pairs}")
    lines.append(
        "Pareamento subjetivo usa `architecture_during_period` da **fase** "
        "(prioridade sobre o instante de `submitted_at`) — ver `analysis/domain.py`."
    )
    lines.append("")

    if warnings:
        lines.append("## Avisos de consistência (architecture_during_period)")
        lines.append("")
        for warning in warnings:
            lines.append(f"- {warning}")
        lines.append("")

    lines.append("## H1 — Usabilidade percebida e eficácia objetiva")
    lines.append("")
    lines.append(
        "> H1: arquitetura offline-first apresenta melhor percepção de usabilidade "
        "do que online-first em conectividade limitada."
    )
    lines.append("")
    lines.extend(format_test_block("Escore SUS (subjetivo, 0-100)", h1_results["sus_score"], higher_is_better=True))
    lines.extend(
        format_test_block(
            "Taxa de sucesso de operações (objetivo, 0-1)",
            h1_results["operation_success_rate"],
            higher_is_better=True,
        )
    )
    lines.append(
        "> Nota: esta métrica considera apenas eventos `operation_completed` e "
        "ignora tentativas bloqueadas (`operation_blocked`). Nos dados deste "
        "estudo ela tende a 100% em ambas as arquiteturas e não discrimina "
        "os modos — ver métricas objetivas de H2 abaixo."
    )
    lines.append("")
    lines.extend(
        format_test_block(
            "Taxa de abandono após falha (objetivo, 0-1)",
            h1_results["abandon_rate"],
            higher_is_better=False,
        )
    )

    lines.append("## H2 — Confiabilidade percebida")
    lines.append("")
    lines.append(
        "> H2: arquitetura offline-first apresenta melhor percepção de confiabilidade "
        "do que online-first em conectividade limitada."
    )
    lines.append("")
    lines.extend(
        format_test_block(
            "Confiança no aplicativo (subjetivo, escala 1-7)",
            h2_results["reliability_trust_score"],
            higher_is_better=True,
        )
    )
    lines.extend(
        format_test_block(
            "Estabilidade/funcionamento percebido (subjetivo, escala 1-7)",
            h2_results["reliability_technical_score"],
            higher_is_better=True,
        )
    )

    lines.append("### Evidência objetiva de confiabilidade operacional (H2)")
    lines.append("")
    lines.append(
        "> Bloqueios por instabilidade simulada refletem indisponibilidade do "
        "sistema no momento do uso — constructo alinhado à confiabilidade "
        "percebida (H2), conforme seção 2.6 das especificações (`operations_blocked` "
        "vinculado a H1 e H2)."
    )
    lines.append("")
    lines.extend(
        format_test_block(
            "Taxa efetiva de conclusão (objetivo, 0-1)",
            h2_results["effective_completion_rate"],
            higher_is_better=True,
        )
    )
    lines.append(
        "> Fórmula: `operation_completed` com sucesso / "
        "(`operation_completed` + `operation_blocked`). Incorpora tentativas "
        "impedidas pela rede no modo online-first."
    )
    lines.append("")
    lines.extend(
        format_test_block(
            "Operações bloqueadas (objetivo, contagem)",
            h2_results["operations_blocked_total"],
            higher_is_better=False,
        )
    )

    lines.append("## Contexto de uso (situações do dia a dia, escala 1-7)")
    lines.append("")
    lines.append(
        "> Bloco relacionado à condição \"conectividade limitada\" mencionada em H1/H2; "
        "reportado descritivamente."
    )
    lines.append("")
    lines.extend(format_test_block("Escore de contexto", context_result, higher_is_better=True))

    if not offline_only_df.empty:
        lines.append("## Métricas exclusivas do modo offline-first (sincronização)")
        lines.append("")
        lines.append(
            "Eventos `sync_item` só são registrados em offline-first; sem par em "
            "online-first, reportado apenas de forma descritiva (sem Wilcoxon)."
        )
        lines.append("")
        lines.append(offline_only_df.to_markdown())
        lines.append("")

    if not order_df.empty:
        lines.append("## Efeito de ordem (secundário — não altera H1/H2)")
        lines.append("")
        lines.append(
            "Compara o escore SUS médio agrupando por qual arquitetura veio primeiro "
            "(T1) para cada participante; usa a atribuição inicial **apenas aqui**."
        )
        lines.append("")
        lines.append(order_df.to_markdown(index=False))
        lines.append("")

    if not weekly_df.empty:
        lines.append("## Engajamento semanal médio (operações/dia)")
        lines.append("")
        lines.append(weekly_df.to_markdown(index=False))
        lines.append("")

    return "\n".join(lines)


def plot_results(
    subjective_df: pd.DataFrame,
    objective_df: pd.DataFrame,
    weekly_df: pd.DataFrame,
    output_path: Path,
) -> None:
    sns.set_theme(style="whitegrid")
    fig, axes = plt.subplots(2, 2, figsize=(14, 10))

    if not subjective_df.empty and subjective_df["sus_score"].notna().any():
        sns.boxplot(data=subjective_df, x="architecture", y="sus_score", ax=axes[0, 0])
    axes[0, 0].set_title("SUS por arquitetura (H1)")
    axes[0, 0].set_ylabel("Escore SUS (0-100)")

    if not subjective_df.empty and subjective_df["reliability_trust_score"].notna().any():
        sns.boxplot(data=subjective_df, x="architecture", y="reliability_trust_score", ax=axes[0, 1])
    axes[0, 1].set_title("Confiabilidade percebida por arquitetura (H2)")
    axes[0, 1].set_ylabel("Escore (1-7)")

    if not objective_df.empty and objective_df["effective_completion_rate"].notna().any():
        sns.boxplot(
            data=objective_df, x="architecture", y="effective_completion_rate", ax=axes[1, 0]
        )
    axes[1, 0].set_title("Taxa efetiva de conclusão (H2 objetivo)")
    axes[1, 0].set_ylabel("Taxa (0-1)")

    if not weekly_df.empty:
        sns.lineplot(
            data=weekly_df, x="week", y="total_operations", hue="architecture", marker="o", ax=axes[1, 1]
        )
    axes[1, 1].set_title("Engajamento semanal médio")
    axes[1, 1].set_ylabel("Operações/dia (média)")
    axes[1, 1].set_xlabel("Semana do estudo")

    plt.tight_layout()
    fig.savefig(output_path, dpi=300)
    plt.close(fig)


# ───────────────────────────── CLI / main ────────────────────────────────────


def parse_args(argv: Optional[list[str]] = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Análise completa do estudo (H1/H2) a partir dos dados do RTDB."
    )
    parser.add_argument(
        "--database-url",
        default=None,
        help="URL do Firebase Realtime Database (default: $FIREBASE_DATABASE_URL ou projeto do app).",
    )
    parser.add_argument(
        "--min-pairs",
        type=int,
        default=5,
        help="Número mínimo de pares (participantes com as duas arquiteturas) para rodar o Wilcoxon. Default: 5.",
    )
    parser.add_argument(
        "--output-dir",
        default=str(Path(__file__).parent / "output"),
        help="Diretório de saída dos artefatos gerados. Default: analysis/output/.",
    )
    return parser.parse_args(argv)


def main(argv: Optional[list[str]] = None) -> int:
    args = parse_args(argv)
    database_url = (
        args.database_url or os.environ.get("FIREBASE_DATABASE_URL") or DEFAULT_DATABASE_URL
    )
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    print(f"Buscando dados em {database_url} ...")
    participants = fetch_participants(database_url)
    telemetry = fetch_telemetry(database_url)
    print(
        f"{len(participants)} participante(s) no RTDB; "
        f"{len(telemetry)} com algum evento de telemetria."
    )

    subjective_rows, warnings = build_subjective_rows(participants)
    objective_rows, daily_rows = build_objective_rows(telemetry)

    subjective_df = pd.DataFrame(subjective_rows)
    objective_df = pd.DataFrame(objective_rows)
    daily_df = pd.DataFrame(daily_rows)

    # Elegibilidade: so quem completou T1 e T2 entra em H1/H2.
    ids_completos = participantes_completos_t1_t2(subjective_df)
    excluidos = sorted(
        (
            set(subjective_df.get("participant_id", pd.Series(dtype=str)).unique())
            | set(objective_df.get("participant_id", pd.Series(dtype=str)).unique())
        )
        - ids_completos
    )
    print(
        f"Amostra analitica (T1+T2): {len(ids_completos)} participante(s). "
        f"Excluidos de H1/H2: {len(excluidos)}"
    )
    if excluidos:
        print(f"  IDs excluidos: {', '.join(excluidos)}")

    subjective_df = filtrar_por_completos(subjective_df, ids_completos)
    objective_df = filtrar_por_completos(objective_df, ids_completos)
    daily_df = filtrar_por_completos(daily_df, ids_completos)

    combined_df = merge_combined(subjective_df, objective_df)
    combined_path = output_dir / "metrics_by_participant.csv"
    combined_df.to_csv(combined_path, index=False)

    h1_results = {
        "sus_score": wilcoxon_test(pivot_metric(subjective_df, "sus_score"), args.min_pairs),
        "operation_success_rate": wilcoxon_test(
            pivot_metric(objective_df, "operation_success_rate"), args.min_pairs
        ),
        "abandon_rate": wilcoxon_test(pivot_metric(objective_df, "abandon_rate"), args.min_pairs),
    }
    h2_results = {
        "reliability_trust_score": wilcoxon_test(
            pivot_metric(subjective_df, "reliability_trust_score"), args.min_pairs
        ),
        "reliability_technical_score": wilcoxon_test(
            pivot_metric(subjective_df, "reliability_technical_score"), args.min_pairs
        ),
        "effective_completion_rate": wilcoxon_test(
            pivot_metric(objective_df, "effective_completion_rate"), args.min_pairs
        ),
        "operations_blocked_total": wilcoxon_test(
            pivot_metric(objective_df, "operations_blocked_total"), args.min_pairs
        ),
    }
    context_result = wilcoxon_test(pivot_metric(subjective_df, "context_score"), args.min_pairs)

    order_df = order_effect_table(subjective_df)
    weekly_df = weekly_engagement(daily_df)
    offline_only_df = describe_offline_only_metrics(objective_df)

    n_participants = len(
        set(subjective_df.get("participant_id", pd.Series(dtype=str)))
        | set(objective_df.get("participant_id", pd.Series(dtype=str)))
    )

    report = render_report(
        n_participants=n_participants,
        n_completos_t1_t2=len(ids_completos),
        warnings=warnings,
        h1_results=h1_results,
        h2_results=h2_results,
        context_result=context_result,
        order_df=order_df,
        weekly_df=weekly_df,
        offline_only_df=offline_only_df,
        min_pairs=args.min_pairs,
    )
    report_path = output_dir / "hypothesis_tests.md"
    report_path.write_text(report, encoding="utf-8")

    plot_path = output_dir / "results.png"
    plot_results(subjective_df, objective_df, weekly_df, plot_path)

    print(report)
    print(f"\nArquivos gravados em: {output_dir.resolve()}")
    print(f"  - {combined_path.name}")
    print(f"  - {report_path.name}")
    print(f"  - {plot_path.name}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
