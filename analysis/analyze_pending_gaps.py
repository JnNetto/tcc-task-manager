#!/usr/bin/env python3
"""
Análises pendentes do TCC — Offline-First
==========================================

Cobre quatro lacunas identificadas na revisão do artigo:

  1. Alfa de Cronbach das escalas próprias  -> validade de construto
  2. Caracterização demográfica da amostra  -> comentário 22 do orientador
  3. Análise de atrito (iniciaram -> T1/T2) -> ameaça à validade
  4. Bloco comparativo bipolar do T2        -> dado coletado e nunca reportado

Extras: contagem de pares não-empatados e r de Wilcoxon nas duas convenções
para as métricas já reportadas nos Quadros 4–6.

Fonte primária: Firebase RTDB (mesmo pipeline de `analyze_full_study.py`).
Opcionalmente aceita CSVs flat via --questionarios / --telemetria.

Dependências: pandas, numpy, scipy, requests (já no requirements.txt).
"""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path
from typing import Optional

import numpy as np
import pandas as pd
from scipy import stats

from domain import (
    OFFLINE_FIRST,
    ONLINE_FIRST,
    normalize_arch,
    resolve_period_architecture,
    resolve_start_architecture,
    warn_submit_vs_phase,
)
from fetch_data import (
    ADMIN_PARTICIPANT_ID,
    DEFAULT_DATABASE_URL,
    fetch_participants,
    fetch_telemetry,
)
from metrics import (
    COMPARATIVE_IDS,
    CONTEXT_IDS,
    RELIABILITY_TECHNICAL_IDS,
    RELIABILITY_TRUST_IDS,
    aggregate_objective_metrics,
    likert_score,
    sus_score,
)

# =============================================================================
# CONFIG — alinhado a questionario_T1/T2.html e ao schema RTDB
# =============================================================================

COL_PARTICIPANTE = "participant_id"
COL_FASE = "period"
COL_ARQUITETURA = "architecture_during_period"
COL_ORDEM = "start_architecture"  # arquitetura da 1ª fase (T1), via timeline

ITENS_SUS = [f"sus{i}" for i in range(1, 11)]
ITENS_ESTABILIDADE = list(RELIABILITY_TECHNICAL_IDS)  # tf1..tf9
ITENS_CONFIANCA = list(RELIABILITY_TRUST_IDS)  # cs1..cs10
ITENS_CONTEXTO = list(CONTEXT_IDS)  # ctx1..ctx5
ITENS_COMPARATIVO = list(COMPARATIVE_IDS)  # comp1..comp6

# Índices 1-based dos itens invertidos (fonte: REVERSE em questionario_*.html).
# SUS: pares por definição Brooke. Escalas próprias: tf2/4/6/8, cs4, ctx4.
REVERSOS_SUS = [2, 4, 6, 8, 10]
REVERSOS_ESTABILIDADE = [2, 4, 6, 8]  # tf2, tf4, tf6, tf8
REVERSOS_CONFIANCA = [4]  # cs4
REVERSOS_CONTEXTO = [4]  # ctx4

ROTULOS_COMPARATIVO = [
    "Facilidade de uso",
    "Velocidade percebida",
    "Confiança nos dados",
    "Estabilidade",
    "Comportamento em internet ruim",
    "Uso geral",
]

# Demografia disponível no app: profile_questionnaire.{age,gender,education}.
# Não coletados: área de formação / familiaridade técnica (lacuna residual).
COLS_DEMOGRAFICAS = ["idade", "genero", "escolaridade"]
COLS_DEMO_AUSENTES = ["area_formacao", "familiaridade_tec"]

EDUCATION_LABELS = {
    "fund_inc": "Fundamental incompleto",
    "fund_comp": "Fundamental completo",
    "med_inc": "Médio incompleto",
    "med_comp": "Médio completo",
    "sup_inc": "Superior incompleto",
    "sup_comp": "Superior completo",
    "pos": "Pós-graduação",
    "edu_skip": "Prefiro não informar",
}
GENDER_LABELS = {
    "female": "Feminino",
    "male": "Masculino",
    "non_binary": "Não-binário",
    "prefer_not": "Prefiro não informar",
    "other": "Outro",
}

ALFA = 0.05


# =============================================================================
# ETL — RTDB -> DataFrame flat (1 linha = 1 resposta T1/T2)
# =============================================================================


def _pick_items(block: object, ids: list[str]) -> dict:
    if not isinstance(block, dict):
        return {k: None for k in ids}
    return {k: block.get(k) for k in ids}


def build_questionnaire_df(participants: dict) -> tuple[pd.DataFrame, list[str]]:
    """Monta tabela flat com itens brutos + metadados de ordem/arquitetura."""
    rows: list[dict] = []
    warnings: list[str] = []

    for pid, participant in participants.items():
        if pid == ADMIN_PARTICIPANT_ID or not isinstance(participant, dict):
            continue

        profile = participant.get("profile_questionnaire")
        profile = profile if isinstance(profile, dict) else {}
        start_arch, start_source = resolve_start_architecture(participant)

        subjective = participant.get("subjective_questionnaires")
        if not isinstance(subjective, dict):
            continue

        for period in ("T1", "T2"):
            payload = subjective.get(period)
            if not isinstance(payload, dict):
                continue

            architecture, source = resolve_period_architecture(participant, payload)
            warning = warn_submit_vs_phase(
                pid,
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

            row: dict = {
                COL_PARTICIPANTE: pid,
                COL_FASE: period,
                COL_ARQUITETURA: architecture,
                "architecture_source": source,
                COL_ORDEM: start_arch,
                "start_architecture_source": start_source,
                "idade": profile.get("age"),
                "genero": profile.get("gender"),
                "escolaridade": profile.get("education"),
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
                "preferred_version": None,
                "noticed_difference": None,
            }
            row.update(_pick_items(responses.get("sus"), ITENS_SUS))
            row.update(
                _pick_items(responses.get("reliability_technical"), ITENS_ESTABILIDADE)
            )
            row.update(_pick_items(responses.get("reliability_trust"), ITENS_CONFIANCA))
            row.update(_pick_items(responses.get("context"), ITENS_CONTEXTO))

            if period == "T2":
                comparative = responses.get("comparative") or {}
                row.update(_pick_items(comparative, ITENS_COMPARATIVO))
                row["preferred_version"] = comparative.get("preferred_version")
                row["noticed_difference"] = comparative.get("noticed_difference")

            rows.append(row)

    return pd.DataFrame(rows), warnings


def build_telemetry_participant_ids(telemetry: dict) -> set[str]:
    return {
        pid
        for pid, events in telemetry.items()
        if pid != ADMIN_PARTICIPANT_ID and isinstance(events, dict) and events
    }


def build_objective_pivot(telemetry: dict) -> pd.DataFrame:
    """Uma linha por participante × arquitetura com métricas objetivas."""
    rows: list[dict] = []
    for pid, events_map in telemetry.items():
        if pid == ADMIN_PARTICIPANT_ID or not isinstance(events_map, dict):
            continue
        events = [e for e in events_map.values() if isinstance(e, dict)]
        by_arch: dict[str, list[dict]] = {}
        for event in events:
            arch = normalize_arch(event.get("architecture"))
            by_arch.setdefault(arch, []).append(event)
        for arch, arch_events in by_arch.items():
            metrics = aggregate_objective_metrics(arch_events)
            metrics[COL_PARTICIPANTE] = pid
            metrics["architecture"] = arch
            rows.append(metrics)
    return pd.DataFrame(rows)


# =============================================================================
# Amostra analitica: so quem terminou o estudo (T1 e T2)
# =============================================================================


def participantes_completos(df: pd.DataFrame) -> set[str]:
    """IDs com resposta em T1 e em T2. Incompletos nao entram nas analises."""
    q = df.groupby(COL_PARTICIPANTE)[COL_FASE].nunique()
    return set(q[q >= 2].index)


def filtrar_completos(df: pd.DataFrame) -> pd.DataFrame:
    ids = participantes_completos(df)
    return df[df[COL_PARTICIPANTE].isin(ids)].copy()


# =============================================================================
# 1. ALFA DE CRONBACH
# =============================================================================


def cronbach_alpha(df_itens: pd.DataFrame) -> tuple[float, int, int]:
    d = df_itens.dropna()
    n_itens = d.shape[1]
    if n_itens < 2 or len(d) < 3:
        return float("nan"), len(d), n_itens
    var_itens = d.var(axis=0, ddof=1).sum()
    var_total = d.sum(axis=1).var(ddof=1)
    if var_total == 0:
        return float("nan"), len(d), n_itens
    alpha = (n_itens / (n_itens - 1)) * (1 - var_itens / var_total)
    return float(alpha), len(d), n_itens


def alpha_se_item_removido(df_itens: pd.DataFrame) -> pd.Series:
    out = {}
    for col in df_itens.columns:
        a, _, _ = cronbach_alpha(df_itens.drop(columns=[col]))
        out[col] = a
    return pd.Series(out)


def reverter(serie: pd.Series, minimo: int, maximo: int) -> pd.Series:
    return (minimo + maximo) - serie


def preparar_escala(
    df: pd.DataFrame, itens: list[str], reversos_idx: list[int], minimo: int, maximo: int
) -> pd.DataFrame:
    bloco = df[itens].apply(pd.to_numeric, errors="coerce").copy()
    for i in reversos_idx:
        col = itens[i - 1]
        bloco[col] = reverter(bloco[col], minimo, maximo)
    return bloco


def interpretar_alpha(a: float) -> str:
    if pd.isna(a):
        return "não calculável"
    if a >= 0.90:
        return "excelente"
    if a >= 0.80:
        return "boa"
    if a >= 0.70:
        return "aceitável"
    if a >= 0.60:
        return "questionável"
    return "inaceitável — não usar como escala somada"


def rodar_alfas(df: pd.DataFrame) -> pd.DataFrame:
    print("\n" + "=" * 78)
    print("1. CONSISTENCIA INTERNA (ALFA DE CRONBACH)")
    print("=" * 78)
    print(
        """
  Amostra: apenas participantes com T1 e T2.
  Nota: T1 e T2 do mesmo participante nao sao independentes.
  Reportamos alfa em tres recortes: todas as respostas (descritivo),
  so T1 e so T2 (recomendados para o texto)."""
    )

    escalas = [
        ("SUS (validacao do pipeline)", ITENS_SUS, REVERSOS_SUS, 1, 5),
        ("Estabilidade/funcionamento", ITENS_ESTABILIDADE, REVERSOS_ESTABILIDADE, 1, 7),
        ("Confianca no aplicativo", ITENS_CONFIANCA, REVERSOS_CONFIANCA, 1, 7),
        ("Contexto de uso", ITENS_CONTEXTO, REVERSOS_CONTEXTO, 1, 7),
    ]

    recortes = [
        ("todas", df),
        ("T1", df[df[COL_FASE].astype(str).str.upper().eq("T1")]),
        ("T2", df[df[COL_FASE].astype(str).str.upper().eq("T2")]),
    ]

    linhas = []
    for nome, itens, reversos, mn, mx in escalas:
        faltando = [c for c in itens if c not in df.columns]
        if faltando:
            print(f"\n  [!] {nome}: colunas ausentes {faltando} — pulando.")
            continue

        print(f"\n  {nome}")
        for rotulo_recorte, subset in recortes:
            if subset.empty:
                continue
            bloco = preparar_escala(subset, itens, reversos, mn, mx)
            a, n, k = cronbach_alpha(bloco)
            linhas.append(
                {
                    "Escala": nome,
                    "Recorte": rotulo_recorte,
                    "Itens": k,
                    "n": n,
                    "Alfa": round(a, 3) if not pd.isna(a) else None,
                    "Interpretação": interpretar_alpha(a),
                }
            )
            print(
                f"    [{rotulo_recorte}] itens={k} | n={n} | "
                f"alfa={a:.3f} ({interpretar_alpha(a)})"
            )

            # Diagnostico item-removido so no recorte T1 (texto principal)
            if (
                rotulo_recorte == "T1"
                and not pd.isna(a)
                and a < 0.80
            ):
                print("      Alfa se item removido (T1):")
                for item, av in alpha_se_item_removido(bloco).sort_values(
                    ascending=False
                ).items():
                    marca = (
                        "  <-- considerar remover"
                        if (not pd.isna(av) and av > a)
                        else ""
                    )
                    if not pd.isna(av):
                        print(f"        {item:20s} {av:.3f}{marca}")

    tabela = pd.DataFrame(linhas)
    print("\n  --- Tabela para o texto ---")
    print(tabela.to_string(index=False) if not tabela.empty else "  (vazia)")
    print(
        """
  Leitura: use preferencialmente o alfa de T1 (ou T2) no texto — nao o pool
  'todas'. O SUS tipicamente fica perto de 0,90 na literatura; se ficar bem
  abaixo com a reversao correta, discuta efeito-teto / baixa variancia em 5.5.3.
  Alfa baixo nas escalas proprias NAO invalida o trabalho; omitir e pior."""
    )
    return tabela


# =============================================================================
# 2. CARACTERIZAÇÃO DA AMOSTRA
# =============================================================================


def rodar_demografia(df: pd.DataFrame) -> dict:
    print("\n" + "=" * 78)
    print("2. CARACTERIZACAO DOS PARTICIPANTES")
    print("=" * 78)
    print("  (apenas quem completou T1 e T2)")

    base = df.drop_duplicates(subset=[COL_PARTICIPANTE]).copy()
    print(f"\n  Participantes unicos (T1+T2): {len(base)}")

    presentes = [c for c in COLS_DEMOGRAFICAS if c in base.columns and base[c].notna().any()]
    resultado: dict = {"n": len(base), "presentes": presentes, "ausentes": COLS_DEMO_AUSENTES}

    if not presentes:
        print(
            """
  [!] Nenhuma coluna demográfica encontrada.
  Considere formulário curto e retroativo (idade, escolaridade, área, familiaridade)."""
        )
        return resultado

    if "idade" in presentes:
        s = pd.to_numeric(base["idade"], errors="coerce").dropna()
        print(f"\n  idade")
        print(
            f"    n={len(s)} | média={s.mean():.1f} | DP={s.std():.1f} | "
            f"mediana={s.median():.1f} | min={s.min():.0f} | máx={s.max():.0f}"
        )
        resultado["idade"] = {
            "n": len(s),
            "mean": float(s.mean()),
            "sd": float(s.std()),
            "median": float(s.median()),
            "min": float(s.min()),
            "max": float(s.max()),
        }

    if "genero" in presentes:
        print("\n  genero")
        cont = base["genero"].map(lambda x: GENDER_LABELS.get(str(x), str(x))).value_counts(
            dropna=False
        )
        resultado["genero"] = {}
        for val, n in cont.items():
            pct = 100 * n / len(base)
            print(f"    {str(val):35s} {n:3d}  ({pct:.1f}%)")
            resultado["genero"][str(val)] = {"n": int(n), "pct": pct}

    if "escolaridade" in presentes:
        print("\n  escolaridade")
        cont = base["escolaridade"].map(
            lambda x: EDUCATION_LABELS.get(str(x), str(x))
        ).value_counts(dropna=False)
        resultado["escolaridade"] = {}
        for val, n in cont.items():
            pct = 100 * n / len(base)
            print(f"    {str(val):35s} {n:3d}  ({pct:.1f}%)")
            resultado["escolaridade"][str(val)] = {"n": int(n), "pct": pct}

    print(
        f"""
  [i] Colunas NÃO coletadas no app (lacuna residual para o comentário 22):
      {COLS_DEMO_AUSENTES}
  Há idade/gênero/escolaridade; falta área de formação e familiaridade técnica.
  Formulário retroativo curto ainda resolve o ponto mais frágil (área de TI)."""
    )
    return resultado


# =============================================================================
# 3. ATRITO
# =============================================================================


def rodar_atrito(
    df: pd.DataFrame,
    iniciaram: set[str],
    ordem_por_participante: Optional[dict[str, str]] = None,
) -> dict:
    print("\n" + "=" * 78)
    print("3. ANALISE DE ATRITO")
    print("=" * 78)

    q = df.groupby(COL_PARTICIPANTE)[COL_FASE].nunique()
    completos = set(q[q >= 2].index)
    so_um = set(q[q == 1].index)
    com_quest = set(df[COL_PARTICIPANTE].unique())

    if not iniciaram:
        iniciaram = com_quest

    resultado = {
        "iniciaram": len(iniciaram),
        "completos": len(completos),
        "so_um_periodo": len(so_um),
        "sem_questionario": len(iniciaram - com_quest),
    }

    print(f"\n  Iniciaram (telemetria):        {resultado['iniciaram']}")
    print(f"  Responderam T1 e T2:           {resultado['completos']}")
    print(f"  Responderam apenas um periodo: {resultado['so_um_periodo']}")
    print(f"  Sem questionario algum:        {resultado['sem_questionario']}")
    if iniciaram:
        perda = 1 - len(completos) / len(iniciaram)
        resultado["taxa_atrito"] = perda
        print(f"\n  Taxa de atrito: {100 * perda:.1f}%")

    # Ordem: preferir mapa completo (todos os participantes do RTDB);
    # fallback = so quem tem questionario.
    if ordem_por_participante:
        ordem = pd.Series(ordem_por_participante, name=COL_ORDEM)
    elif COL_ORDEM in df.columns:
        ordem = df.drop_duplicates(subset=[COL_PARTICIPANTE]).set_index(COL_PARTICIPANTE)[
            COL_ORDEM
        ]
    else:
        print(f"\n  [!] Coluna '{COL_ORDEM}' ausente — nao da para testar atrito diferencial.")
        return resultado

    print("\n  Atrito por ordem de exposicao (atrito DIFERENCIAL):")
    tab_rows = []
    for grupo in sorted(ordem.dropna().unique()):
        ids = set(ordem[ordem == grupo].index)
        ids_ini = ids & iniciaram if iniciaram else ids
        n_ini = len(ids_ini)
        n_comp = len(ids_ini & completos)
        tab_rows.append(
            {
                "Ordem inicial": grupo,
                "Iniciaram": n_ini,
                "Completaram": n_comp,
                "Atrito %": round(100 * (1 - n_comp / n_ini), 1) if n_ini else None,
            }
        )
    tab = pd.DataFrame(tab_rows)
    print(tab.to_string(index=False))
    resultado["por_ordem"] = tab.to_dict(orient="records")

    if len(tab) == 2 and tab["Iniciaram"].min() > 0:
        tabela = [
            [int(r["Completaram"]), int(r["Iniciaram"] - r["Completaram"])]
            for _, r in tab.iterrows()
        ]
        try:
            _, p = stats.fisher_exact(tabela)
            resultado["fisher_p"] = float(p)
            print(f"\n  Teste exato de Fisher: p = {p:.4f}")
            if p < ALFA:
                print("  >>> ATRITO DIFERENCIAL SIGNIFICATIVO. Ameaca seria a validade")
                print("      interna — precisa estar na Secao 5.5.1.")
            else:
                print("  >>> Sem evidencia de atrito diferencial. Reporte: fortalece")
                print("      a validade interna.")
        except Exception as e:
            print(f"  [!] Fisher nao aplicavel: {e}")

    return resultado


# =============================================================================
# 4. BLOCO COMPARATIVO BIPOLAR (T2)
# =============================================================================


def rodar_comparativo(df: pd.DataFrame) -> pd.DataFrame:
    print("\n" + "=" * 78)
    print("4. BLOCO COMPARATIVO BIPOLAR (T2)")
    print("=" * 78)

    faltando = [c for c in ITENS_COMPARATIVO if c not in df.columns]
    if faltando:
        print(f"\n  [!] Colunas ausentes: {faltando}")
        return pd.DataFrame()

    t2 = df[df[COL_FASE].astype(str).str.upper().eq("T2")].copy()
    if t2.empty:
        print("\n  [!] Nenhuma resposta de T2 localizada.")
        return pd.DataFrame()

    print(f"\n  Respondentes T2: {len(t2)}")
    print(
        """
  ATENCAO — RECODIFICACAO OBRIGATORIA
  Escala: -3 = 1o app melhor ... +3 = 2o app melhor (nao online vs offline).
  Convencao: valor POSITIVO = favoravel ao OFFLINE-FIRST.
  - Comecou online  -> 2o = offline -> sinal mantido
  - Comecou offline -> 2o = online  -> sinal invertido"""
    )

    if COL_ORDEM not in t2.columns:
        print(f"\n  [!] Coluna '{COL_ORDEM}' ausente. Impossível recodificar.")
        return pd.DataFrame()

    comecou_offline = t2[COL_ORDEM].astype(str).str.lower().str.contains("offline")
    t1_arch = (
        df[df[COL_FASE].astype(str).str.upper().eq("T1")]
        .drop_duplicates(subset=[COL_PARTICIPANTE])
        .set_index(COL_PARTICIPANTE)[COL_ARQUITETURA]
    )
    aligned = sum(
        1
        for _, r in t2.iterrows()
        if r[COL_PARTICIPANTE] in t1_arch.index
        and str(r[COL_ORDEM]) == str(t1_arch.loc[r[COL_PARTICIPANTE]])
    )
    print(f"\n  Sanity start_architecture == arquitetura T1: {aligned}/{len(t2)}")
    if aligned != len(t2):
        print("  >>> ALERTA: ordem de exposição desalinhada do T1 — revise a fonte.")
    print(f"  Começaram por offline-first: {int(comecou_offline.sum())} (sinal invertido)")
    print(f"  Começaram por online-first:  {int((~comecou_offline).sum())} (sinal mantido)")

    rec = t2[ITENS_COMPARATIVO].apply(pd.to_numeric, errors="coerce").copy()
    rec.loc[comecou_offline.values, :] *= -1

    print("\n  Teste de Wilcoxon dos postos sinalizados contra a neutralidade (0):\n")
    linhas = []
    for col, rot in zip(ITENS_COMPARATIVO, ROTULOS_COMPARATIVO):
        s = rec[col].dropna()
        nao_nulos = int((s != 0).sum())
        if nao_nulos < 3:
            linhas.append(
                {
                    "Item": rot,
                    "n": len(s),
                    "M": round(float(s.mean()), 2) if len(s) else None,
                    "Mdn": float(s.median()) if len(s) else None,
                    "n≠0": nao_nulos,
                    "W": None,
                    "p": None,
                    "r": None,
                }
            )
            continue
        W, p = stats.wilcoxon(s, zero_method="wilcox", alternative="two-sided")
        z = stats.norm.isf(p / 2) * np.sign(s.mean() if s.mean() != 0 else 1)
        linhas.append(
            {
                "Item": rot,
                "n": len(s),
                "M": round(float(s.mean()), 2),
                "Mdn": float(s.median()),
                "n≠0": nao_nulos,
                "W": round(float(W), 1),
                "p": round(float(p), 4),
                "r": round(abs(float(z)) / np.sqrt(nao_nulos), 2),
            }
        )

    res = pd.DataFrame(linhas)
    print(res.to_string(index=False))

    # Preferência recodificada para arquitetura
    if "preferred_version" in t2.columns:
        pref = t2[["preferred_version"]].copy()
        pref["start"] = t2[COL_ORDEM].values
        mapeados = []
        for _, r in t2.iterrows():
            pv = str(r.get("preferred_version") or "").lower()
            start = str(r.get(COL_ORDEM) or "").lower()
            if pv in ("indiferente", "none", ""):
                mapeados.append("indiferente")
            elif pv == "primeiro":
                mapeados.append("offline" if "offline" in start else "online")
            elif pv == "segundo":
                mapeados.append("online" if "offline" in start else "offline")
            else:
                mapeados.append(pv)
        cont = pd.Series(mapeados).value_counts()
        print("\n  Preferência permanente (recodificada para arquitetura):")
        for k, n in cont.items():
            print(f"    {k:20s} {n:3d}")

    print(
        """
  Leitura: M > 0 favorece o offline-first; M < 0 favorece o online-first.
  Se houver diferença aqui onde o SUS não achou, reforça a Seção 5.1
  (sensibilidade do instrumento)."""
    )
    return res


# =============================================================================
# 5. PARES NÃO-EMPATADOS E r — Quadros já reportados
# =============================================================================


def wilcoxon_detalhado(a, b, rotulo: str = "") -> Optional[dict]:
    d = pd.DataFrame({"a": a, "b": b}).dropna()
    dif = d["a"] - d["b"]
    n_pares = len(dif)
    n_nao_empatados = int((dif != 0).sum())

    print(f"\n  {rotulo}")
    print(
        f"    pares totais = {n_pares} | não-empatados = {n_nao_empatados} "
        f"| empates descartados = {n_pares - n_nao_empatados}"
    )

    if n_nao_empatados < 3:
        print("    [!] Pares insuficientes após descartar empates.")
        return None

    W, p = stats.wilcoxon(d["a"], d["b"], zero_method="wilcox", alternative="two-sided")
    z = abs(stats.norm.isf(p / 2))
    r_pairs = z / np.sqrt(n_nao_empatados)
    r_obs = z / np.sqrt(2 * n_nao_empatados)
    print(f"    W = {W:.2f} | p = {p:.4f}")
    print(f"    r = {r_pairs:.3f}  (N = pares não-empatados)  ← convenção recomendada")
    print(f"    r = {r_obs:.3f}  (N = observações, 2 por par)")
    return {
        "label": rotulo,
        "W": float(W),
        "p": float(p),
        "n_pares": n_pares,
        "n_efetivo": n_nao_empatados,
        "r_pares": float(r_pairs),
        "r_obs": float(r_obs),
    }


def rodar_wilcoxon_quadros(
    subjective_df: pd.DataFrame,
    objective_df: pd.DataFrame,
    ids_completos: Optional[set[str]] = None,
) -> list[dict]:
    print("\n" + "=" * 78)
    print("5. PARES NAO-EMPATADOS NOS TESTES JA REPORTADOS")
    print("=" * 78)
    print(
        """
  Amostra: apenas quem completou T1 e T2.
  Convencao: r = |Z| / sqrt(N_nao_empatados).
  Declare a mesma convencao na Secao 3.6.3 e use em todo o texto."""
    )

    resultados: list[dict] = []
    subj = subjective_df.rename(columns={COL_ARQUITETURA: "architecture"})
    obj = objective_df
    if ids_completos is not None:
        subj = subj[subj["participant_id"].isin(ids_completos)]
        if not obj.empty and "participant_id" in obj.columns:
            obj = obj[obj["participant_id"].isin(ids_completos)]
        print(f"  Participantes elegiveis (T1+T2): {len(ids_completos)}")

    def _pair(df: pd.DataFrame, metric: str, label: str) -> None:
        if df.empty or metric not in df.columns:
            print(f"\n  {label}: sem dados")
            return
        pivot = (
            df[["participant_id", "architecture", metric]]
            .dropna(subset=[metric])
            .pivot_table(
                index="participant_id",
                columns="architecture",
                values=metric,
                aggfunc="mean",
            )
        )
        if ONLINE_FIRST not in pivot.columns or OFFLINE_FIRST not in pivot.columns:
            print(f"\n  {label}: colunas de arquitetura ausentes")
            return
        paired = pivot[[ONLINE_FIRST, OFFLINE_FIRST]].dropna()
        out = wilcoxon_detalhado(paired[ONLINE_FIRST], paired[OFFLINE_FIRST], label)
        if out:
            out["mean_online"] = float(paired[ONLINE_FIRST].mean())
            out["mean_offline"] = float(paired[OFFLINE_FIRST].mean())
            resultados.append(out)

    _pair(subj, "sus_score", "SUS")
    _pair(subj, "reliability_technical_score", "Estabilidade percebida")
    _pair(subj, "reliability_trust_score", "Confianca percebida")
    _pair(subj, "context_score", "Contexto de uso")
    _pair(obj, "effective_completion_rate", "Taxa efetiva de conclusao")
    _pair(obj, "operations_blocked_total", "Operacoes bloqueadas")

    return resultados


# =============================================================================
# Relatorio Markdown
# =============================================================================


def _render_markdown(
    *,
    alfas: pd.DataFrame,
    demo: dict,
    atrito: dict,
    comparativo: pd.DataFrame,
    wilcoxon_extra: list[dict],
    warnings: list[str],
) -> str:
    lines = [
        "# Análises pendentes — lacunas da revisão",
        "",
        "Gerado por `analysis/analyze_pending_gaps.py`.",
        "",
        "**Critério de elegibilidade:** apenas participantes com **T1 e T2**. "
        "Quem respondeu só um período é excluído das análises (entra apenas no "
        "funil de atrito).",
        "",
    ]
    if warnings:
        lines.append("## Avisos de consistência")
        lines.append("")
        for w in warnings:
            lines.append(f"- {w}")
        lines.append("")

    lines.append("## 1. Alfa de Cronbach")
    lines.append("")
    if alfas is not None and not alfas.empty:
        lines.append(alfas.to_markdown(index=False))
    else:
        lines.append("_Sem resultados._")
    lines.append("")
    lines.append(
        "Reversão das escalas próprias (fonte `questionario_*.html`): "
        "`tf2,tf4,tf6,tf8`, `cs4`, `ctx4`. SUS: itens pares."
    )
    lines.append("")

    lines.append("## 2. Demografia")
    lines.append("")
    lines.append(f"- Participantes com T1+T2 (amostra analitica): **{demo.get('n', 0)}**")
    if "idade" in demo:
        i = demo["idade"]
        lines.append(
            f"- Idade: n={i['n']}, M={i['mean']:.1f}, DP={i['sd']:.1f}, "
            f"Mdn={i['median']:.1f}, min={i['min']:.0f}, máx={i['max']:.0f}"
        )
    if "genero" in demo:
        lines.append("- Gênero:")
        for k, v in demo["genero"].items():
            lines.append(f"  - {k}: {v['n']} ({v['pct']:.1f}%)")
    if "escolaridade" in demo:
        lines.append("- Escolaridade:")
        for k, v in demo["escolaridade"].items():
            lines.append(f"  - {k}: {v['n']} ({v['pct']:.1f}%)")
    lines.append(
        f"- **Não coletados:** {', '.join(demo.get('ausentes', COLS_DEMO_AUSENTES))} "
        "(área de formação / familiaridade técnica — lacuna residual do comentário 22)."
    )
    lines.append("")

    lines.append("## 3. Atrito")
    lines.append("")
    lines.append(f"- Iniciaram (telemetria): {atrito.get('iniciaram')}")
    lines.append(f"- Completaram T1+T2: {atrito.get('completos')}")
    lines.append(f"- Apenas um período: {atrito.get('so_um_periodo')}")
    lines.append(f"- Sem questionário: {atrito.get('sem_questionario')}")
    if atrito.get("taxa_atrito") is not None:
        lines.append(f"- Taxa de atrito: **{100 * atrito['taxa_atrito']:.1f}%**")
    if atrito.get("por_ordem"):
        lines.append("")
        lines.append(pd.DataFrame(atrito["por_ordem"]).to_markdown(index=False))
    if atrito.get("fisher_p") is not None:
        p = atrito["fisher_p"]
        lines.append(f"\n- Fisher (atrito diferencial): **p = {p:.4f}**")
        if p < ALFA:
            lines.append("- Interpretação: atrito diferencial **significativo** → Seção 5.5.1.")
        else:
            lines.append(
                "- Interpretação: sem evidência de atrito diferencial "
                "(fortalece validade interna) → reporte na 5.5.1."
            )
    lines.append("")

    lines.append("## 4. Bloco comparativo bipolar (T2, recodificado)")
    lines.append("")
    lines.append(
        "Convenção: M > 0 favorece **offline-first**; recodificação por "
        f"`{COL_ORDEM}` (1ª fase via `architecture_timeline`)."
    )
    lines.append("")
    if comparativo is not None and not comparativo.empty:
        lines.append(comparativo.to_markdown(index=False))
    else:
        lines.append("_Sem resultados._")
    lines.append("")

    lines.append("## 5. Wilcoxon detalhado (pares não-empatados)")
    lines.append("")
    if wilcoxon_extra:
        tab = pd.DataFrame(wilcoxon_extra)
        cols = [
            "label",
            "n_pares",
            "n_efetivo",
            "mean_online",
            "mean_offline",
            "W",
            "p",
            "r_pares",
            "r_obs",
        ]
        cols = [c for c in cols if c in tab.columns]
        lines.append(tab[cols].to_markdown(index=False, floatfmt=".4f"))
        lines.append("")
        lines.append(
            "Se duas métricas objetivas mostram W/p/r idênticos, isso é "
            "plausível sob separação quase perfeita (offline sem bloqueios vs "
            "online com bloqueios); reporte o n efetivo e explique a coincidência."
        )
    else:
        lines.append("_Sem resultados._")
    lines.append("")
    return "\n".join(lines)


# =============================================================================
# MAIN
# =============================================================================


def parse_args(argv: Optional[list[str]] = None) -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Análises pendentes (lacunas da revisão).")
    p.add_argument("--database-url", default=None)
    p.add_argument(
        "--questionarios",
        default=None,
        help="CSV flat opcional (1 linha = 1 resposta). Se omitido, busca no RTDB.",
    )
    p.add_argument(
        "--telemetria-csv",
        default=None,
        help="CSV opcional só com participant_id (para atrito). Se omitido, usa RTDB.",
    )
    p.add_argument(
        "--output-dir",
        default=str(Path(__file__).parent / "output"),
    )
    return p.parse_args(argv)


def main(argv: Optional[list[str]] = None) -> int:
    args = parse_args(argv)
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    warnings: list[str] = []
    objective_df = pd.DataFrame()
    ordem_por_participante: Optional[dict[str, str]] = None

    if args.questionarios:
        df = pd.read_csv(args.questionarios)
        print(f"Carregado CSV: {args.questionarios} ({len(df)} linhas)")
        iniciaram: set[str] = set()
        if args.telemetria_csv:
            tele_csv = pd.read_csv(args.telemetria_csv)
            iniciaram = set(tele_csv[COL_PARTICIPANTE].unique())
    else:
        database_url = (
            args.database_url
            or os.environ.get("FIREBASE_DATABASE_URL")
            or DEFAULT_DATABASE_URL
        )
        print(f"Buscando dados em {database_url} ...")
        participants = fetch_participants(database_url)
        telemetry = fetch_telemetry(database_url)
        print(
            f"{len(participants)} participante(s); "
            f"{len(telemetry)} com telemetria."
        )
        df, warnings = build_questionnaire_df(participants)
        iniciaram = build_telemetry_participant_ids(telemetry)
        objective_df = build_objective_pivot(telemetry)
        ordem_por_participante = {
            pid: resolve_start_architecture(p)[0]
            for pid, p in participants.items()
            if isinstance(p, dict)
        }
        # Export flat para auditoria / reexecução offline
        flat_path = output_dir / "questionarios_flat.csv"
        df.to_csv(flat_path, index=False)
        print(f"Flat exportado: {flat_path.name}")

    if df.empty:
        print("[!] Nenhuma resposta de questionario encontrada.")
        return 1

    print(
        f"\nCarregado: {len(df)} respostas | "
        f"{df[COL_PARTICIPANTE].nunique()} participantes unicos"
    )
    for w in warnings:
        print(f"  AVISO: {w}")

    # Evita UnicodeEncodeError no console Windows (cp1252).
    if hasattr(sys.stdout, "reconfigure"):
        try:
            sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        except Exception:
            pass

    # Criterio de elegibilidade: so quem terminou o estudo (T1 e T2).
    # Incompletos entram APENAS na analise de atrito (funil).
    ids_completos = participantes_completos(df)
    df_analise = filtrar_completos(df)
    incompletos = sorted(set(df[COL_PARTICIPANTE].unique()) - ids_completos)
    print(
        f"\nAmostra analitica (T1+T2): {len(ids_completos)} participantes | "
        f"{len(df_analise)} respostas"
    )
    if incompletos:
        print(
            f"Excluidos das analises (so um periodo): {', '.join(incompletos)} "
            f"— entram so no atrito."
        )

    alfas = rodar_alfas(df_analise)
    demo = rodar_demografia(df_analise)
    atrito = rodar_atrito(df, iniciaram, ordem_por_participante)
    comparativo = rodar_comparativo(df_analise)
    wilcoxon_extra = rodar_wilcoxon_quadros(df_analise, objective_df, ids_completos)

    report = _render_markdown(
        alfas=alfas,
        demo=demo,
        atrito=atrito,
        comparativo=comparativo,
        wilcoxon_extra=wilcoxon_extra,
        warnings=warnings,
    )
    report_path = output_dir / "pending_gaps_report.md"
    report_path.write_text(report, encoding="utf-8")

    if not alfas.empty:
        alfas.to_csv(output_dir / "cronbach_alphas.csv", index=False)
    if not comparativo.empty:
        comparativo.to_csv(output_dir / "comparative_bipolar.csv", index=False)

    print("\n" + "=" * 78)
    print(f"Relatório gravado: {report_path.resolve()}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
