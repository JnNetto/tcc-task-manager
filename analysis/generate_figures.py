#!/usr/bin/env python3
"""Gera figuras do TCC a partir do RTDB e dos artefatos de análise.

Saídas em `--output-dir` (default: analysis/output/figures/):

  01_arquiteturas.png              — OnlineTaskRepository vs OfflineTaskRepository
  03_boxplot_taxa_efetiva.png      — H2 objetiva (resultado principal)
  04_barras_comparativo.png        — bloco bipolar T2 recodificado
  05_funil_participacao.png        — CONSORT-like 40→28→21
  06_linha_tempo_estudo.png        — 30 dias, T1/T2, ordens, janelas
  07_latencia_sync_log.png         — pending_duration_ms em escala log
  08_boxplot_sus.png               — escore SUS por arquitetura
  09_engajamento_semanal.png       — operações/dia + n ativos/semana

Convenção ABNT: títulos de figura ficam no documento (não embutidos no PNG).
Figura 02 (capturas lado a lado) exige screenshots reais — não gerada aqui.
"""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

import matplotlib

matplotlib.use("Agg")

import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.patches import FancyBboxPatch
import numpy as np
import pandas as pd
import seaborn as sns
from scipy import stats

from analyze_full_study import (
    build_objective_rows,
    build_subjective_rows,
    filtrar_por_completos,
    participantes_completos_t1_t2,
)
from domain import OFFLINE_FIRST, ONLINE_FIRST, normalize_arch, resolve_start_architecture
from fetch_data import DEFAULT_DATABASE_URL, fetch_participants, fetch_telemetry
from metrics import COMPARATIVE_IDS

# Paleta acadêmica sóbria (sem roxo/neon)
C_ONLINE = "#2C5F8A"
C_OFFLINE = "#2E7D4F"
C_ACCENT = "#B85C38"
C_MUTED = "#6B7280"
C_LIGHT = "#F3F4F6"
C_EDGE = "#1F2937"

sns.set_theme(style="whitegrid", font_scale=1.05)
plt.rcParams.update(
    {
        "figure.dpi": 150,
        "savefig.dpi": 300,
        "savefig.bbox": "tight",
        "font.family": "DejaVu Sans",
        "axes.titlesize": 12,
        "axes.labelsize": 11,
    }
)


def _arch_label(s: pd.Series) -> pd.Series:
    return s.map(
        {
            ONLINE_FIRST: "Online-first",
            OFFLINE_FIRST: "Offline-first",
        }
    ).fillna(s)


def _box(ax, x, y, bottom, width, height, facecolor, edgecolor=C_EDGE, lw=1.2, text="", fontsize=8):
    # Rectangle (não FancyBboxPatch): mutation_aspect distorce a altura e empurra
    # a caixa para cima, colidindo com o título do painel.
    rect = mpatches.Rectangle(
        (x, y),
        width,
        height,
        linewidth=lw,
        edgecolor=edgecolor,
        facecolor=facecolor,
        zorder=2,
    )
    ax.add_patch(rect)
    if text:
        ax.text(
            x + width / 2,
            y + height / 2,
            text,
            ha="center",
            va="center",
            fontsize=fontsize,
            color=C_EDGE,
            wrap=True,
            zorder=3,
        )
    return rect


def fig_arquiteturas(path: Path) -> None:
    fig, axes = plt.subplots(1, 2, figsize=(12.8, 7.6))

    layouts = [
        {
            "ax": axes[0],
            "title": "Online-first — OnlineTaskRepository",
            "color": C_ONLINE,
            "boxes": [
                (2.5, 7.8, 5, 1.2, "#DBEAFE", "UI Flutter\n(lista / formulário)", 9),
                (2.5, 6.0, 5, 1.2, "#DBEAFE", "OnlineTaskRepository", 9),
                (2.5, 4.2, 5, 1.2, "#FEE2E2", "NetworkSimulator\n(intercepta CRUD)", 8),
                (2.5, 2.4, 5, 1.2, "#E5E7EB", "Cloud Firestore\n(tarefas / CRUD)", 9),
                (2.5, 0.5, 5, 1.4, "#FEF3C7", "Sem conectividade\n→ operação bloqueada\nou atrasada", 8),
            ],
            "arrows": [
                ((5, 7.8), (5, 7.2), C_EDGE),
                ((5, 6.0), (5, 5.4), C_EDGE),
                ((5, 4.2), (5, 3.6), C_EDGE),
                ((5, 2.4), (5, 1.9), C_ACCENT),
            ],
            "footer": "Disponibilidade = rede + servidor",
        },
        {
            "ax": axes[1],
            "title": "Offline-first — OfflineTaskRepository + SyncService",
            "color": C_OFFLINE,
            "boxes": [
                (2.5, 7.8, 5, 1.2, "#D1FAE5", "UI Flutter\n(mesma interface)", 9),
                (2.5, 6.0, 5, 1.2, "#D1FAE5", "OfflineTaskRepository", 9),
                (0.8, 4.0, 4.0, 1.3, "#A7F3D0", "Hive (local)\nCRUD imediato", 8),
                (5.2, 4.0, 4.0, 1.3, "#FEE2E2", "NetworkSimulator\n(só no push)", 8),
                (2.5, 2.2, 5, 1.2, "#BBF7D0", "SyncService\n(fila pending → remoto)", 8),
                (2.5, 0.5, 5, 1.2, "#E5E7EB", "Cloud Firestore\n(quando permitido)", 9),
            ],
            "arrows": [
                ((5, 7.8), (5, 7.2), C_EDGE),
                ((4.2, 6.0), (2.8, 5.3), C_OFFLINE),
                ((5.8, 6.0), (7.2, 5.3), C_ACCENT),
                ((2.8, 4.0), (5, 3.4), C_OFFLINE),
                ((7.2, 4.0), (5, 3.4), C_ACCENT),
                ((5, 2.2), (5, 1.7), C_EDGE),
            ],
            "footer": "Disponibilidade local; sync eventual",
        },
    ]

    for layout in layouts:
        ax = layout["ax"]
        ax.set_xlim(0, 10)
        ax.set_ylim(0, 10.5)
        for spine in ax.spines.values():
            spine.set_visible(False)
        ax.set_xticks([])
        ax.set_yticks([])
        for x, y, w, h, fc, txt, fs in layout["boxes"]:
            _box(ax, x, y, 0, w, h, fc, text=txt, fontsize=fs)
        for (x0, y0), (x1, y1), col in layout["arrows"]:
            ax.annotate("", xy=(x1, y1), xytext=(x0, y0), arrowprops=dict(arrowstyle="->", color=col, lw=1.3))
        ax.text(5, 0.15, layout["footer"], ha="center", fontsize=8, color=C_MUTED, style="italic")

    fig.subplots_adjust(left=0.03, right=0.97, top=0.82, bottom=0.04, wspace=0.12)
    for ax, layout in zip(axes, layouts):
        pos = ax.get_position()
        fig.text(
            pos.x0 + pos.width / 2,
            pos.y1 + 0.055,
            layout["title"],
            ha="center",
            va="bottom",
            fontsize=11,
            fontweight="bold",
            color=layout["color"],
            transform=fig.transFigure,
        )

    fig.savefig(path, bbox_inches="tight", pad_inches=0.4)
    plt.close(fig)


def _boxplot_arch(ax, data: list, labels: list[str], colors: list[str], *, showfliers: bool = False) -> dict:
    """Boxplot nativo com cores explícitas (evita seaborn pintar as duas caixas iguais)."""
    flierprops = {
        "marker": "o",
        "markerfacecolor": "none",
        "markeredgecolor": C_MUTED,
        "markersize": 5,
    }
    bp = ax.boxplot(
        data,
        labels=labels,
        widths=0.45,
        patch_artist=True,
        showfliers=showfliers,
        flierprops=flierprops,
        medianprops={"linewidth": 2.2},
        whiskerprops={"color": C_EDGE},
        capprops={"color": C_EDGE},
        boxprops={"linewidth": 1.2},
    )
    for patch, med, color, vals in zip(bp["boxes"], bp["medians"], colors, data):
        patch.set_facecolor(color)
        patch.set_edgecolor(color)
        patch.set_alpha(0.85)
        med.set_color(color)
        # caixa degenerada (todos iguais): mediana mais grossa para a cor aparecer
        if len(vals) and (float(np.nanmax(vals)) - float(np.nanmin(vals))) < 1e-9:
            med.set_linewidth(4.0)
    rng = np.random.default_rng(42)
    for i, (vals, color) in enumerate(zip(data, colors), start=1):
        if len(vals) == 0:
            continue
        jitter = rng.uniform(-0.08, 0.08, size=len(vals))
        ax.scatter(
            np.full(len(vals), i) + jitter,
            vals,
            color=color,
            alpha=0.45,
            s=22,
            zorder=3,
            edgecolors="white",
            linewidths=0.3,
        )
    return bp


def fig_boxplot_taxa(objective_df: pd.DataFrame, path: Path) -> None:
    df = objective_df.copy()
    order = ["Online-first", "Offline-first"]
    colors = [C_ONLINE, C_OFFLINE]
    data = [
        df.loc[df["architecture"] == ONLINE_FIRST, "effective_completion_rate"].dropna().to_numpy(),
        df.loc[df["architecture"] == OFFLINE_FIRST, "effective_completion_rate"].dropna().to_numpy(),
    ]
    fig, ax = plt.subplots(figsize=(7.2, 5.0))
    _boxplot_arch(ax, data, order, colors)
    ax.set_ylim(-0.05, 1.08)
    ax.set_ylabel("Taxa efetiva de conclusão")
    ax.set_xlabel("")
    for i, arch in enumerate([ONLINE_FIRST, OFFLINE_FIRST]):
        m = df.loc[df["architecture"] == arch, "effective_completion_rate"].mean()
        ax.text(i + 1, 1.02, f"M = {m:.3f}", ha="center", fontsize=9, color=colors[i])
    fig.tight_layout()
    fig.savefig(path)
    plt.close(fig)


def fig_boxplot_sus(subjective_df: pd.DataFrame, path: Path) -> None:
    df = (
        subjective_df.groupby(["participant_id", "architecture"], as_index=False)["sus_score"]
        .mean()
        .dropna()
    )
    order = ["Online-first", "Offline-first"]
    colors = [C_ONLINE, C_OFFLINE]
    data = [
        df.loc[df["architecture"] == ONLINE_FIRST, "sus_score"].dropna().to_numpy(),
        df.loc[df["architecture"] == OFFLINE_FIRST, "sus_score"].dropna().to_numpy(),
    ]
    fig, ax = plt.subplots(figsize=(7.2, 5.0))
    _boxplot_arch(ax, data, order, colors, showfliers=True)
    ax.axhline(80, color=C_MUTED, ls="--", lw=1, alpha=0.7, label="Referência ~80 (boa usabilidade)")
    ax.set_ylim(40, 105)
    ax.set_ylabel("Escore SUS (0–100)")
    ax.set_xlabel("")
    ax.legend(loc="lower right", fontsize=8, frameon=False)
    for i, arch in enumerate([ONLINE_FIRST, OFFLINE_FIRST]):
        m = df.loc[df["architecture"] == arch, "sus_score"].mean()
        ax.text(i + 1, 102, f"M = {m:.1f}", ha="center", fontsize=9, color=colors[i])
    fig.tight_layout()
    fig.savefig(path)
    plt.close(fig)


def fig_barras_comparativo(df_quest: pd.DataFrame, path: Path) -> None:
    """Barras com IC 95% (t de Student); escala completa −3…+3."""
    t2 = df_quest[df_quest["period"].astype(str).str.upper().eq("T2")].copy()
    comecou_offline = t2["start_architecture"].astype(str).str.lower().str.contains("offline")
    rec = t2[COMPARATIVE_IDS].apply(pd.to_numeric, errors="coerce").copy()
    rec.loc[comecou_offline.values, :] *= -1

    rotulos = [
        "Facilidade\nde uso",
        "Velocidade\npercebida",
        "Confiança\nnos dados",
        "Estabilidade",
        "Internet\nruim",
        "Uso\ngeral",
    ]
    means, half_cis = [], []
    for col in COMPARATIVE_IDS:
        s = rec[col].dropna()
        n = len(s)
        m = float(s.mean())
        se = float(s.std(ddof=1) / np.sqrt(n)) if n > 1 else 0.0
        tcrit = float(stats.t.ppf(0.975, n - 1)) if n > 1 else 0.0
        means.append(m)
        half_cis.append(tcrit * se)

    fig, ax = plt.subplots(figsize=(9.5, 5.2))
    x = np.arange(len(rotulos))
    colors = [C_OFFLINE if m >= 0 else C_ONLINE for m in means]
    ax.bar(
        x,
        means,
        yerr=half_cis,
        color=colors,
        edgecolor=C_EDGE,
        linewidth=0.8,
        width=0.65,
        capsize=4,
        error_kw={"lw": 1},
    )
    ax.axhline(0, color=C_EDGE, lw=1)
    ax.set_xticks(x)
    ax.set_xticklabels(rotulos, fontsize=9)
    ax.set_ylabel("Média recodificada (−3 … +3)")
    ax.set_ylim(-3.05, 3.05)
    ax.set_yticks([-3, -2, -1, 0, 1, 2, 3])
    ax.text(0.01, 0.98, "favorece offline-first →", transform=ax.transAxes, va="top", fontsize=8, color=C_OFFLINE)
    ax.text(0.01, 0.02, "← favorece online-first", transform=ax.transAxes, va="bottom", fontsize=8, color=C_ONLINE)
    ax.text(
        0.99,
        0.02,
        "Barras de erro: IC 95% (t)",
        transform=ax.transAxes,
        ha="right",
        va="bottom",
        fontsize=7.5,
        color=C_MUTED,
    )
    for i, (m, half) in enumerate(zip(means, half_cis)):
        y = m + half + 0.12 if m >= 0 else m - half - 0.12
        ax.text(i, y, f"{m:+.2f}", ha="center", va="bottom" if m >= 0 else "top", fontsize=8, color=C_MUTED)
    fig.tight_layout()
    fig.savefig(path)
    plt.close(fig)


def fig_funil(path: Path) -> None:
    """Funil CONSORT-like: 40 cadastrados → 28 telemetria → 21 T1+T2."""
    stages = [
        ("Participantes cadastrados", 40, None),
        ("Iniciaram uso\n(com telemetria)", 28, "12 sem telemetria"),
        ("Completaram T1 e T2\n(amostra analítica)", 21, "5 sem questionário\n+ 2 só um período"),
    ]
    fig, ax = plt.subplots(figsize=(8.5, 5.8))
    ax.set_xlim(0, 10)
    ax.set_ylim(0, 11.5)
    ax.axis("off")

    widths = [8.0, 6.2, 4.6]
    y_positions = [8.5, 5.2, 1.9]
    colors = ["#DBEAFE", "#FEF3C7", "#D1FAE5"]

    for (label, n, lost), w, y, c in zip(stages, widths, y_positions, colors):
        x = (10 - w) / 2
        _box(ax, x, y, 0, w, 1.8, c, text=f"{label}\nn = {n}", fontsize=10)
        if lost:
            ax.annotate(
                f"perda: {lost}",
                xy=(x + w + 0.15, y + 0.9),
                fontsize=7.5,
                color=C_ACCENT,
                va="center",
                ha="left",
            )

    for y_from, y_to in [(8.5, 7.0), (5.2, 3.7)]:
        ax.annotate(
            "",
            xy=(5, y_to),
            xytext=(5, y_from),
            arrowprops=dict(arrowstyle="->", color=C_EDGE, lw=1.6),
        )

    ax.text(
        5,
        0.45,
        "Atrito global 28→21 = 25,0%. Atrito diferencial por ordem: Fisher p = 0,40 (n.s.).",
        ha="center",
        fontsize=8,
        color=C_MUTED,
    )
    fig.tight_layout()
    fig.savefig(path)
    plt.close(fig)


def fig_linha_tempo(path: Path) -> None:
    """Linha do tempo 30 dias + duas ordens + janelas diárias de degradação."""
    fig = plt.figure(figsize=(12.5, 8.6))
    gs = fig.add_gridspec(3, 1, height_ratios=[1.0, 1.0, 1.4], hspace=0.75)

    def _ordem(ax, titulo: str, cor_titulo: str, cor1: str, lab1: str, cor2: str, lab2: str, troca: bool):
        ax.set_xlim(0, 30)
        ax.set_ylim(0, 2.4)
        ax.set_yticks([])
        ax.set_xlabel("Dia do estudo")
        ax.set_title(titulo, loc="left", fontsize=10, color=cor_titulo, fontweight="bold", pad=10)
        ax.barh(0.85, 15, left=0, height=0.9, color=cor1, edgecolor=C_EDGE)
        ax.barh(0.85, 15, left=15, height=0.9, color=cor2, edgecolor=C_EDGE)
        ax.axvline(15, color=C_ACCENT, ls="--", lw=1.5)
        ax.text(7.5, 0.85, lab1, ha="center", va="center", fontsize=9)
        ax.text(22.5, 0.85, lab2, ha="center", va="center", fontsize=9)
        ax.plot(14.5, 1.95, "v", color=C_EDGE, markersize=8)
        ax.plot(29.5, 1.95, "v", color=C_EDGE, markersize=8)
        ax.text(14.5, 2.15, "T1", ha="center", fontsize=9, fontweight="bold")
        ax.text(29.5, 2.15, "T2", ha="center", fontsize=9, fontweight="bold")
        if troca:
            ax.text(15.2, 0.15, "troca de arquitetura", fontsize=8, color=C_ACCENT)

    ax = fig.add_subplot(gs[0])
    _ordem(
        ax,
        "Ordem A — começa em offline-first",
        C_OFFLINE,
        "#A7F3D0",
        "Fase 1 · Offline-first",
        "#93C5FD",
        "Fase 2 · Online-first",
        True,
    )

    ax = fig.add_subplot(gs[1])
    _ordem(
        ax,
        "Ordem B — começa em online-first",
        C_ONLINE,
        "#93C5FD",
        "Fase 1 · Online-first",
        "#A7F3D0",
        "Fase 2 · Offline-first",
        False,
    )

    ax = fig.add_subplot(gs[2])
    windows = [
        (7.5, 0.5, "07:30–08:00"),
        (12.0, 20 / 60, "12:00–12:20"),
        (17.5, 0.5, "17:30–18:00"),
        (20.0, 1.0, "20:00–21:00"),
        (22.5, 20 / 60, "22:30–22:50"),
    ]
    ax.set_xlim(0, 24)
    ax.set_ylim(0, 2.0)
    ax.set_yticks([])
    ax.set_xlabel("Hora do dia (janelas idênticas nos dois modos)")
    ax.set_title(
        "Janelas diárias de degradação (NetworkSimulator)",
        loc="left",
        fontsize=10,
        color=C_EDGE,
        fontweight="bold",
        pad=12,
    )
    ax.barh(0.55, 24, left=0, height=0.55, color="#F3F4F6", edgecolor=C_EDGE)
    for start, dur, label in windows:
        ax.barh(0.55, dur, left=start, height=0.55, color="#FECACA", edgecolor=C_ACCENT, linewidth=0.8)
        # rótulos bem acima da barra, abaixo do título
        ax.text(start + dur / 2, 1.25, label, ha="center", va="bottom", fontsize=7.5, color=C_ACCENT)
    ax.set_xticks([0, 6, 12, 18, 24])
    ax.set_xticklabels(["00h", "06h", "12h", "18h", "24h"])
    ax.text(
        12,
        0.12,
        "Camada 2 (volume): a cada 4 ops OK via intercept(), próximas 2 degradadas — "
        "só o caminho online alimenta o contador; offline push consulta isDegraded, mas não incrementa",
        ha="center",
        fontsize=7.5,
        color=C_MUTED,
    )

    fig.subplots_adjust(left=0.06, right=0.98, top=0.94, bottom=0.07, hspace=0.70)
    fig.savefig(path, bbox_inches="tight", pad_inches=0.3)
    plt.close(fig)


def collect_sync_latencies(telemetry: dict) -> pd.Series:
    values: list[float] = []
    for pid, events_map in telemetry.items():
        if not isinstance(events_map, dict):
            continue
        for event in events_map.values():
            if not isinstance(event, dict):
                continue
            if event.get("eventType") != "sync_item":
                continue
            if normalize_arch(event.get("architecture")) != OFFLINE_FIRST:
                continue
            data = event.get("data") if isinstance(event.get("data"), dict) else {}
            if data.get("success") is not True:
                continue
            dur = data.get("pending_duration_ms")
            if dur is None:
                continue
            try:
                v = float(dur)
            except (TypeError, ValueError):
                continue
            if v >= 0:
                values.append(v)
    return pd.Series(values, name="pending_duration_ms")


def fig_latencia_sync(latencies_ms: pd.Series, path: Path) -> None:
    if latencies_ms.empty:
        fig, ax = plt.subplots(figsize=(7, 4))
        ax.text(0.5, 0.5, "Sem dados de pending_duration_ms", ha="center", va="center")
        ax.axis("off")
        fig.savefig(path)
        plt.close(fig)
        return

    seconds = latencies_ms / 1000.0
    seconds = seconds.clip(lower=0.001)

    fig, ax = plt.subplots(figsize=(8.5, 5.0))
    bins = np.logspace(np.log10(seconds.min()), np.log10(seconds.max()), 40)
    ax.hist(seconds, bins=bins, color=C_OFFLINE, edgecolor="white", alpha=0.85)
    ax.set_xscale("log")
    ax.set_xlabel("Latência pending → sync bem-sucedida (segundos, escala log)")
    ax.set_ylabel("Frequência (eventos sync_item)")
    med = float(seconds.median())
    mean = float(seconds.mean())
    ax.axvline(med, color=C_ACCENT, ls="-", lw=1.8, label=f"Mediana = {med:.2f} s")
    ax.axvline(mean, color=C_ONLINE, ls="--", lw=1.5, label=f"Média = {mean/3600:.2f} h")
    ax.legend(frameon=False, fontsize=9)
    for val, lab in [(1, "1 s"), (10, "10 s"), (60, "1 min"), (3600, "1 h")]:
        if seconds.min() <= val <= seconds.max():
            ax.axvline(val, color=C_MUTED, ls=":", lw=0.8, alpha=0.5)
            ax.text(val, ax.get_ylim()[1] * 0.92, lab, rotation=90, va="top", ha="right", fontsize=7, color=C_MUTED)
    fig.tight_layout()
    fig.savefig(path)
    plt.close(fig)


def weekly_engagement_with_n(daily_df: pd.DataFrame) -> pd.DataFrame:
    """Média de operações/dia e n de participantes ativos por semana × arquitetura."""
    if daily_df.empty:
        return daily_df
    df = daily_df.copy()
    df["week"] = ((df["day_of_study"] - 1) // 7) + 1
    ops = df.groupby(["architecture", "week"])["total_operations"].mean()
    n_active = df.groupby(["architecture", "week"])["participant_id"].nunique()
    out = ops.rename("total_operations").to_frame()
    out["n_active"] = n_active
    return out.reset_index()


def fig_engajamento(weekly_df: pd.DataFrame, path: Path) -> None:
    df = weekly_df.copy()
    df["Arquitetura"] = _arch_label(df["architecture"])
    fig, ax = plt.subplots(figsize=(9.0, 5.2))
    palette = {"Online-first": C_ONLINE, "Offline-first": C_OFFLINE}
    sns.lineplot(
        data=df,
        x="week",
        y="total_operations",
        hue="Arquitetura",
        hue_order=["Online-first", "Offline-first"],
        palette=palette,
        marker="o",
        linewidth=2,
        ax=ax,
    )
    ax.set_xlabel("Semana do estudo")
    ax.set_ylabel("Operações concluídas / dia (média)")
    # n ativos em cada ponto
    if "n_active" in df.columns:
        for _, row in df.iterrows():
            ax.annotate(
                f"n={int(row['n_active'])}",
                xy=(row["week"], row["total_operations"]),
                xytext=(0, 8),
                textcoords="offset points",
                ha="center",
                fontsize=7,
                color=palette.get(row["Arquitetura"], C_MUTED),
            )
    ax.legend(title="", frameon=False)
    fig.tight_layout()
    fig.savefig(path)
    plt.close(fig)


def parse_args(argv=None):
    p = argparse.ArgumentParser(description="Gera figuras do TCC.")
    p.add_argument("--database-url", default=None)
    p.add_argument(
        "--output-dir",
        default=str(Path(__file__).parent / "output" / "figures"),
    )
    return p.parse_args(argv)


def main(argv=None) -> int:
    args = parse_args(argv)
    out = Path(args.output_dir)
    out.mkdir(parents=True, exist_ok=True)

    database_url = (
        args.database_url or os.environ.get("FIREBASE_DATABASE_URL") or DEFAULT_DATABASE_URL
    )
    print(f"Buscando dados em {database_url} ...")
    participants = fetch_participants(database_url)
    telemetry = fetch_telemetry(database_url)

    # Flat questionários (precisa start_architecture da timeline)
    from analyze_pending_gaps import build_questionnaire_df, filtrar_completos

    df_quest, warnings = build_questionnaire_df(participants)
    for w in warnings:
        print(f"  AVISO: {w}")
    df_quest = filtrar_completos(df_quest)

    subjective_rows, _ = build_subjective_rows(participants)
    objective_rows, daily_rows = build_objective_rows(telemetry)
    subjective_df = pd.DataFrame(subjective_rows)
    objective_df = pd.DataFrame(objective_rows)
    daily_df = pd.DataFrame(daily_rows)

    ids = participantes_completos_t1_t2(subjective_df)
    subjective_df = filtrar_por_completos(subjective_df, ids)
    objective_df = filtrar_por_completos(objective_df, ids)
    daily_df = filtrar_por_completos(daily_df, ids)
    weekly_df = weekly_engagement_with_n(daily_df)

    # Sobrepor arquitetura de fase nos subjetivos a partir do flat (já com stored_period)
    # build_subjective_rows já usa domain atualizado.

    latencies = collect_sync_latencies(telemetry)
    # restringir latências a participantes completos, se possível
    # (eventos não têm filtro fácil por completo sem remapear — manter todos offline ok,
    #  mas filtra por pid se disponível)
    # eventos não carregam participant no collect — já iteramos por pid; refazer filtro:
    lat_complete: list[float] = []
    for pid, events_map in telemetry.items():
        if pid not in ids or not isinstance(events_map, dict):
            continue
        for event in events_map.values():
            if not isinstance(event, dict) or event.get("eventType") != "sync_item":
                continue
            if normalize_arch(event.get("architecture")) != OFFLINE_FIRST:
                continue
            data = event.get("data") if isinstance(event.get("data"), dict) else {}
            if data.get("success") is not True:
                continue
            dur = data.get("pending_duration_ms")
            if dur is None:
                continue
            try:
                v = float(dur)
            except (TypeError, ValueError):
                continue
            if v >= 0:
                lat_complete.append(v)
    latencies = pd.Series(lat_complete if lat_complete else latencies, name="pending_duration_ms")

    generators = [
        ("01_arquiteturas.png", lambda p: fig_arquiteturas(p)),
        ("03_boxplot_taxa_efetiva.png", lambda p: fig_boxplot_taxa(objective_df, p)),
        ("04_barras_comparativo.png", lambda p: fig_barras_comparativo(df_quest, p)),
        ("05_funil_participacao.png", lambda p: fig_funil(p)),
        ("06_linha_tempo_estudo.png", lambda p: fig_linha_tempo(p)),
        ("07_latencia_sync_log.png", lambda p: fig_latencia_sync(latencies, p)),
        ("08_boxplot_sus.png", lambda p: fig_boxplot_sus(subjective_df, p)),
        ("09_engajamento_semanal.png", lambda p: fig_engajamento(weekly_df, p)),
    ]

    print(f"\nGerando figuras em {out.resolve()}")
    for name, fn in generators:
        path = out / name
        print(f"  → {name}")
        fn(path)

    readme = out / "README.md"
    readme.write_text(
        """# Figuras geradas para o TCC

Geradas por `analysis/generate_figures.py`.

**Convenção ABNT:** as imagens **não** embutem o título da figura — o título e a fonte ficam no documento.

| Arquivo | Uso sugerido | Notas |
|---|---|---|
| `01_arquiteturas.png` | Cap. 3 | Tarefas no **Cloud Firestore**; telemetria/config no **RTDB** (scripts de análise) |
| `03_boxplot_taxa_efetiva.png` | 4.3.2 | Azul = online-first; verde = offline-first |
| `04_barras_comparativo.png` | 4.4 | Barras de erro = **IC 95%** (t); eixo −3…+3 |
| `05_funil_participacao.png` | 4.1.1 | Funil 40 → 28 → 21 |
| `06_linha_tempo_estudo.png` | Cap. 3 | Duas ordens + janelas; volume assimétrico (legenda) |
| `07_latencia_sync_log.png` | 4.3.3 | Eventos `sync_item` (não média por participante) |
| `08_boxplot_sus.png` | 4.2.1 | Sem interpretação no título |
| `09_engajamento_semanal.png` | 4.5.3 | Rótulo `n=` = participantes ativos na semana |

**Não gerada:** capturas lado a lado dos protótipos — exige screenshots reais.

```bash
cd analysis
python generate_figures.py
```
""",
        encoding="utf-8",
    )
    print(f"\nREADME: {readme}")
    print("Figura 02 (capturas) NÃO gerada — precisa de screenshots reais.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
