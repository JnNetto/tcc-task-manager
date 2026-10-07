# Relatório completo da análise do estudo — Online-First vs Offline-First

**Projeto:** TCC Task Manager (`tcc-task-manager`)  
**Data deste relatório:** 12/07/2026 (atualizado 27/07/2026 com análises de lacunas)  
**Fonte dos números:** `analysis/analyze_full_study.py` + `analysis/analyze_pending_gaps.py` contra o Firebase RTDB (`tcc-task-manager-82e52`), artefatos em `analysis/output/`  
**Escopo:** pipeline de coleta/análise, problemas encontrados, soluções, resultados estatísticos de H1/H2, interpretações, achados secundários, **lacunas da revisão** (alfa, demografia, atrito, comparativo T2), limitações e recomendações para pesquisa futura

---

## 1. Objetivo inicial

O estudo compara, em desenho **within-subjects**, duas arquiteturas de aplicativo móvel de gerenciamento de tarefas sob **conectividade limitada** (instabilidade de rede simulada):

| Hipótese | Enunciado (especificações técnicas, seção 1.2) |
|---|---|
| **H1** | Arquitetura **offline-first** apresenta melhor percepção de **usabilidade** do que online-first em conectividade limitada. |
| **H2** | Arquitetura **offline-first** apresenta melhor percepção de **confiabilidade** do que online-first em conectividade limitada. |

Cada participante usa as duas arquiteturas em períodos sucessivos (~15 dias cada), com ordem balanceada (metade começa em online-first, metade em offline-first). Ao final de cada período, responde aos questionários T1/T2 (SUS, confiabilidade percebida, contexto de uso). Em paralelo, o app grava telemetria de operações, bloqueios, atrasos e sincronização no Firebase Realtime Database.

O **objetivo deste trabalho de análise** foi:

1. Extrair **todos** os dados já gravados no RTDB (participantes, questionários subjetivos, telemetria).
2. Associar corretamente cada resposta/questionário e cada evento à arquitetura vigente no período (**não** à arquitetura “atual” do cadastro).
3. Calcular métricas subjetivas e objetivas alinhadas às seções 2.4–2.6 e 13.2 das especificações.
4. Executar testes estatísticos adequados (Wilcoxon pareado + efeito *r*).
5. Produzir relatório interpretável para o capítulo de resultados/discussão do TCC.

---

## 2. Como foi feito

### 2.1 Pipeline técnico

Foi criado um pipeline Python standalone em `analysis/`:

| Módulo | Função |
|---|---|
| `fetch_data.py` | GET REST em `participants.json` e `telemetry.json`; exclui participante de teste `P000` |
| `domain.py` | Prioriza `architecture_during_period` (semântica de **fase** T1/T2); recálculo por `submitted_at` só como fallback/auditoria |
| `metrics.py` | SUS (Brooke, 1996); confiabilidade técnica/confiança; contexto; agregação de telemetria; **taxa efetiva de conclusão** |
| `analyze_full_study.py` | Orquestra ETL → DataFrames → Wilcoxon pareado → relatório Markdown + CSV + gráfico PNG |
| `analyze_pending_gaps.py` | Lacunas da revisão: Cronbach, demografia, atrito diferencial, comparativo bipolar T2, n efetivo do Wilcoxon |

**Execução:**

```bash
cd analysis
pip install -r requirements.txt
python analyze_full_study.py
python analyze_pending_gaps.py
```

**Saídas:**

| Artefato | Conteúdo |
|---|---|
| `output/metrics_by_participant.csv` | Uma linha por participante × arquitetura |
| `output/hypothesis_tests.md` | Relatório automático com testes |
| `output/results.png` | Gráficos (SUS, confiabilidade, taxa efetiva, engajamento) |
| `output/pending_gaps_report.md` | Alfa, demografia, atrito, comparativo T2, Wilcoxon detalhado |
| `output/questionarios_flat.csv` | Itens brutos flat (auditoria / reexecução offline) |

### 2.2 Importação dos questionários (pré-requisito)

Antes da análise estatística, os formulários HTML externos (`questionario_T1.html`, `questionario_T2.html`) foram importados pelo painel admin do app, gravando em:

```
participants/{id}/subjective_questionnaires/{T1|T2}
```

campos como `responses`, `submitted_at`, `architecture_during_period`, `assigned_architecture`, etc.

**Decisão de análise:** o pareamento por arquitetura **não** usa `assigned_architecture`. Usa a arquitetura do período (recalculada / `architecture_during_period` semântico de fase).

### 2.3 Métricas principais

**Subjetivas**

| Métrica | Escala | Hipótese |
|---|---|---|
| SUS (10 itens) | 0–100 | H1 |
| Confiança no app (`cs*`) | 1–7 | H2 |
| Estabilidade/funcionamento (`tf*`) | 1–7 | H2 |
| Contexto de uso (`ctx*`) | 1–7 | Condição “conectividade limitada” (descritivo / exploratório) |

**Objetivas (telemetria)**

| Métrica | Definição | Papel |
|---|---|---|
| `operation_success_rate` | Sucessos / `operation_completed` | H1 (legado; pouco discriminante neste desenho) |
| `effective_completion_rate` | Sucessos / (`operation_completed` + `operation_blocked`) | **H2 objetivo** — disponibilidade operacional |
| `operations_blocked_total` | Contagem de `operation_blocked` | H1/H2 (especificações §2.6) |
| Sync push/pull, `avg_pending_to_sync_ms` | Só offline-first | H2 descritivo (sem par online) |

### 2.4 Método estatístico

- Desenho: **within-subjects** (mesmo participante nas duas arquiteturas).
- Teste: **Wilcoxon signed-rank** (não paramétrico; adequado a amostras pequenas / distribuição não normal).
- Tamanho de efeito: **r de Wilcoxon**.
- Mínimo de pares para teste: 5 (conforme script; alvo da proposta: n ≈ 20).
- Nível de significância implícito na interpretação: α = 0,05.
- Análise de efeito de ordem: **secundária** (não altera o teste principal de H1/H2).

---

## 3. Problemas encontrados e soluções

### 3.1 Campo `architecture_during_period` inconsistente na importação

**Problema.** Na importação admin, `architecture_during_period` era derivado da arquitetura **corrente** do participante (`cfg.architecture`) assumindo T1 = primeira fase e T2 = oposta. Se o questionário fosse importado **depois** que o participante já estava na segunda (ou terceira) fase, o valor gravado podia ficar invertido.

**Casos concretos**

| Participante | Situação | Solução |
|---|---|---|
| **P006** | T1 e T2 gravados **invertidos** (importação com arquitetura já em offline-first, embora a 1ª fase tivesse sido online-first) | Correção manual no RTDB: T1 → `online-first`, T2 → `offline-first` |
| **P016** | T1 enviado ~4 min após a troca offline→online; timeline no submit apontaria online, mas a **fase** T1 foi offline | Pipeline adota o gravado (`offline-first`); P016 **entra** nos 21 pares subjetivos. Aviso de auditoria permanece |

**Solução no pipeline.** `domain.py` prioriza `architecture_during_period` (fase). O instante de `submitted_at` só entra se o campo gravado faltar; divergência gera aviso, sem excluir o pareamento.

**Melhoria futura sugerida (código).** Na importação admin, continuar gravando pela fase; o recálculo por `submitted_at` fica só como auditoria.

### 3.2 Taxa de sucesso operacional = 100% nos dois modos

**Problema.** `operation_success_rate` (só sobre `operation_completed`) ficou em **1,0** em ambas as arquiteturas → Wilcoxon sem variabilidade → métrica **não informativa** para H1.

**Causa.** No modo online-first, tentativas impedidas pelo simulador de rede geram `operation_blocked` e **não entram** no denominador da taxa de sucesso “restrita”. Assim, operações que de fato “falharam por rede” não aparecem como fracasso nessa métrica.

**Solução.** Introduzir **`effective_completion_rate`**:

\[
\text{taxa efetiva} = \frac{\text{operações concluídas com sucesso}}{\text{concluídas} + \text{bloqueadas}}
\]

Isso incorpora o bloqueio por rede como **perda de disponibilidade operacional**, alinhada ao constructo de confiabilidade (H2) e às especificações (`operations_blocked` ↔ H1/H2).

### 3.3 Taxa de abandono após falha sem pares

**Problema.** Nenhum participante com dados pareados suficientes para `abandon_after_failure` → status `sem_dados_pareados`.

**Interpretação.** Ou o evento é raro, ou a instrumentação/critério de “abandono” pouco captura o comportamento. Limitação objetiva para H1/H2 nessa métrica específica.

### 3.4 Acesso REST e ambiente

**Problema.** Em sandbox do agente, DNS/`requests` às vezes demorava minutos; na máquina do pesquisador a coleta completa em ~45s.

**Solução operacional.** Rodar a análise localmente; manter regras de leitura abertas apenas enquanto necessário para o script (risco de segurança se o app for publicado com regras abertas).

### 3.5 Evolução da amostra subjetiva (efeito aparente que “sumiu”)

Em uma execução intermediária com **apenas 8 pares** SUS, H1 subjetiva saiu significativa (p ≈ 0,031). Com **21 pares** (amostra T1+T2 + P016 por fase), a diferença não é significativa (p ≈ 0,32).

**Interpretação.** Provável **baixo poder / amostra incompleta** na primeira janela, não “perda” de um efeito robusto. Relatar com transparência a evolução n=8 → n=21.

---

## 4. Amostra final (execução mais recente)

| Indicador | Valor |
|---|---|
| Participantes cadastrados no RTDB (excl. P000) | **40** |
| Com telemetria (iniciaram o uso) | **28** |
| Com telemetria nas **duas** arquiteturas (antes do filtro T1+T2) | **23** |
| Com ao menos um questionário (T1 e/ou T2) | **23** |
| Completaram T1 **e** T2 (= **amostra analítica H1/H2**) | **21** |
| Pares Wilcoxon subjetivos (ambas arquiteturas com escore) | **21** (P016 incluída via semântica de fase) |
| Pares Wilcoxon objetivos (telemetria, restritos a T1+T2) | **21** |
| Sem questionário algum (entre os 28) | **5** |
| Apenas um período de questionário (excluídos de H1/H2) | **2** (P031, P036) |
| Taxa de atrito (28 → 21 completos) | **25,0%** |
| Avisos de consistência remanescentes | **1** (P016 T1 — envio atrasado vs troca de fase; semântica de fase correta no RTDB) |

> **Elegibilidade:** `analyze_full_study.py` e `analyze_pending_gaps.py` restringem H1/H2 a quem respondeu **T1 e T2**. Incompletos entram só no funil de atrito.

---

## 5. Resultados estatísticos

Convenção: **M** = média, **SD** = desvio-padrão, **W** = estatística de Wilcoxon, **p** = valor-p bilateral, **r** = tamanho de efeito. Diferença favorável a offline-first quando indicado.

**Convenção de *r* (Seção 3.6.3 sugerida):** \( r = |Z| / \sqrt{N_{\text{não-empatados}}} \), com empates descartados pelo `zero_method="wilcox"`. Não usar \( \sqrt{2N} \) no denominador sem declarar. Os Quadros 4–6 devem reportar **n efetivo** (pares não-empatados) além do n de pares totais.

### 5.1 H1 — Usabilidade

#### 5.1.1 SUS (subjetivo)

| Arquitetura | M | SD | n pares |
|---|---|---|---|
| Online-first | 86,429 | 11,952 | 21 |
| Offline-first | 87,619 | 12,386 | 21 |

- Wilcoxon: **W = 49,000**, **p = 0,3243**, **r = 0,246** (n efetivo = 16 não-empatados; convenção §3.6.3)
- **Conclusão formal:** diferença **não significativa** (H0 não rejeitada).

**Interpretação.** Ambas as arquiteturas obtiveram SUS **alto** (faixa tipicamente associada a boa usabilidade). A diferença média (~1,2 ponto) é pequena frente à dispersão. Com a amostra completa, **não há evidência estatística** de superioridade percebida de usabilidade do offline-first.

**Possíveis motivos**

1. A interface (listas, formulários, fluxos) é **a mesma** nos dois modos; muda sobretudo o comportamento sob falha de rede — o SUS clássico pode ser pouco sensível a isso.
2. Efeito de teto: médias ~87–88 deixam pouco espaço para diferença.
3. Participantes podem julgar “facilidade de uso” pelas telas cotidianas, não pela experiência de bloqueio.
4. Amostragem intermediária (n=8) exagerou o efeito; n=21 estabilizou a estimativa.

#### 5.1.2 Taxa de sucesso de operações (objetivo, legado)

- 22 pares; **sem variabilidade** (diferenças todas zero; tipicamente 100% nos dois modos).
- **Não discrimina** arquiteturas neste desenho (ver §3.2).

#### 5.1.3 Taxa de abandono após falha

- 0 pares válidos → **sem evidência** nesta métrica.

**Veredicto H1 (amostra atual):** **não sustentada** no teste subjetivo principal (SUS). As métricas objetivas clássicas de “sucesso” também não discriminam; a narrativa de eficácia sob rede instável migra naturalmente para as métricas de **bloqueio / taxa efetiva** (tratadas em H2 objetiva, mas também listadas nas especificações como ligadas a H1).

---

### 5.2 H2 — Confiabilidade

#### 5.2.1 Confiança no aplicativo (subjetivo)

| Arquitetura | M | SD | n |
|---|---|---|---|
| Online-first | 6,067 | 1,131 | 21 |
| Offline-first | 6,167 | 1,114 | 21 |

- Wilcoxon: **W = 63,500**, **p = 0,8159**, **r = 0,058** (n efetivo = 16)
- **Não significativo.**

#### 5.2.2 Estabilidade / funcionamento percebido (subjetivo)

| Arquitetura | M | SD | n |
|---|---|---|---|
| Online-first | 5,862 | 1,099 | 21 |
| Offline-first | 6,270 | 0,807 | 21 |

- Wilcoxon: **W = 45,000**, **p = 0,2335**, **r = 0,298** (n efetivo = 16)
- **Não significativo**, mas direção e tamanho de efeito **favoráveis ao offline-first** (efeito pequeno–moderado).

**Interpretação subjetiva de H2.** Há tendência na estabilidade percebida, porém insuficiente para rejeitar H0 com α = 0,05. Possíveis motivos: escala Likert alta (efeito de teto), dificuldade de lembrar falhas pontuais ao longo de 15 dias, ou compensação cognitiva (“o app ‘funciona’ quando a rede volta”).

#### 5.2.3 Taxa efetiva de conclusão (objetivo) — resultado principal

| Arquitetura | M | SD | n |
|---|---|---|---|
| Online-first | **0,559** | 0,329 | 21 |
| Offline-first | **1,000** | 0,000 | 21 |

- Wilcoxon: **W = 0,000**, **p = 0,0003**, **r = 0,790** (pipeline; n efetivo = 17 → r ≈ 0,878 na convenção de pares não-empatados)
- **Significativo, favorecendo offline-first** (efeito **grande**).

Em média, no online-first cerca de **44,1%** das tentativas (concluídas + bloqueadas) **não chegam a conclusão** por bloqueio de rede; no offline-first, **100%** das tentativas contabilizadas nessa fórmula concluem (zero bloqueios na amostra pareada). Amostra restrita a quem completou T1+T2 (antes: n=23 incluindo P001/P036).

#### 5.2.4 Operações bloqueadas (objetivo)

| Arquitetura | M | SD | n |
|---|---|---|---|
| Online-first | **17,381** | 25,874 | 21 |
| Offline-first | **0,000** | 0,000 | 21 |

- Wilcoxon: **W = 0,000**, **p = 0,0003**, **r = 0,790** (pipeline; n efetivo = 17 → r ≈ 0,879)
- **Significativo, favorecendo offline-first** (efeito **grande**).

> **Nota sobre W=0 e r quase idênticos nas duas métricas objetivas:** não é erro de copiar-colar. Offline-first tem **zero bloqueios** e taxa efetiva **1,0** para todos os pares; online-first tem bloqueios > 0 (e taxa < 1) nos pares não-empatados. A ordenação dos postos sinalizados é a mesma estrutura de separação quase perfeita → W, p e r coincidem. Reportar o n efetivo e esta frase no texto dos Quadros 5.

**Veredicto H2:** **sustentada pela evidência objetiva** (disponibilidade operacional / ausência de bloqueios). A evidência subjetiva **aponta na mesma direção** na estabilidade, mas **não atinge significância**.

---

## 6. Achados secundários e ramificados (interessantes)

### 6.1 Contexto de uso (conectividade limitada no dia a dia)

| Arquitetura | M | SD | n |
|---|---|---|---|
| Online-first | 5,714 | 1,305 | 21 |
| Offline-first | 6,276 | 0,889 | 21 |

- Wilcoxon: **W = 21,000**, **p = 0,0477**, **r = 0,529** (n efetivo = 14)
- **Significativo, favorecendo offline-first.**

**Leitura.** Embora fora do enunciado formal de H1/H2, isso sugere que os participantes **perceberam o modo offline como mais adequado** às situações de rede limitada — constructo próximo da condição experimental. É um achado exploratório útil na discussão: a diferença “aparece” mais no julgamento de adequação ao contexto do que no SUS genérico.

### 6.2 Efeito de ordem (SUS médio)

| Quem começou em… | SUS médio na fase offline | SUS médio na fase online | n (aprox.) |
|---|---|---|---|
| Offline-first primeiro | 88,96 (n=12) | 92,25 (n=10) | — |
| Online-first primeiro | 84,75 (n=10) | 80,42 (n=12) | — |

**Observação.** Quem **começa em online-first** tende a notas SUS mais baixas nessa fase (~80) do que quem avalia online-first depois de ter usado offline (~92). Hipótese: a primeira exposição a bloqueios “ancora” a avaliação; ou fadiga / contraste. Tratar como **exploratório**, sem inferência causal forte (células desbalanceadas e sem teste formal de interação neste relatório).

### 6.3 Sincronização (somente offline-first)

**Unidade de análise (convenção adotada):** latência por **evento** `sync_item` com sucesso (`pending_duration_ms`), não a média por participante (`avg_pending_to_sync_ms`). A figura `07_latencia_sync_log.png` usa a mesma unidade. A média de médias por participante aproxima a média geral, mas **não** a descreve — daí divergências numéricas se misturadas.

| Estatística (eventos, amostra T1+T2, offline-first) | Valor |
|---|---|
| n (eventos sync bem-sucedidos) | **386** |
| Mediana | **0,23 s** |
| Média | **~1,95 h** (~7,0×10⁶ ms) |
| P25 – P75 | 0,14 s – 0,35 s |
| Máximo | ~101 h |
| % ≤ 1 s | **86,5%** |
| % ≤ 10 s | **89,1%** |
| % ≤ 60 s | 90,7% |
| % ≤ 5 min | 91,5% |
| % ≤ 1 h | 94,0% |
| Push / pull success rate (agregado por participante) | **1,0** (n=21) |

**Leitura.** A distribuição é **fortemente assimétrica**: ~**89%** dos syncs concluem em até **10 s** (e ~87% em até 1 s) — próximo da percepção de instantaneidade — enquanto a **média** (~2 h) é puxada por uma cauda longa de pendências que esperaram janelas de degradação / reconexão. Sem escala log (e sem a mediana / percentis), “média ≈ 2 h” transmite a impressão errada. A fila offline **funciona** (taxa de sucesso 100%); “confiável” ≠ “instantaneamente consistente” no pior caso, mas o caso típico é rápido.

> Nota: `avg_pending_to_sync_ms` no CSV por participante permanece disponível para auditoria, mas **não** é a métrica reportada no texto nem na figura.

### 6.4 Engajamento semanal (operações/dia)

Uso irregular ao longo das semanas em ambos os modos (picos na semana 1 e oscilações depois). Offline-first mantém alguma atividade até a semana 7; online-first cai a 0 na semana 7 na média agregada — possível sinal de **desengajamento** ou fim de estudo desigual, não necessariamente causalidade arquitetural. Útil como contexto de aderência, não como teste de hipótese.

### 6.5 Dissociação subjetivo × objetivo

O achado mais rico para discussão acadêmica:

> Os participantes **quase não diferenciam** usabilidade/confiança nas escalas subjetivas, mas o sistema **objetivamente** falha em concluir operações no online-first sob rede simulada.

Isso sugere:

- vieses de memória / efeito de teto nas escalas;
- ou que “usabilidade percebida” e “disponibilidade operacional” são constructos **parcialmente ortogonais** neste desenho;
- ou que o instrumento SUS não captura bem **resiliência a falha de rede**.

### 6.6 Bloco comparativo bipolar (T2) — dado até então não reportado

Escalas `comp1`–`comp6` contrastam **1º aplicativo vs 2º aplicativo** (−3…+3), não online vs offline. Como a ordem foi contrabalanceada, metade dos participantes tem o sinal invertido em relação à arquitetura. Sem recodificar, os grupos se cancelam artificialmente.

**Recodificação adotada** (`analyze_pending_gaps.py`): valor positivo = favorável ao **offline-first**. Quem começou em offline-first (1ª fase = T1, via primeira entrada de `architecture_timeline`) teve o sinal invertido.

> **Correção metodológica (27/07/2026):** a primeira versão usava `architecture` corrente como proxy de “ordem inicial”. Esse campo, ao fim do estudo, coincide com **T2** (0/21 = T1). A fonte correta é a **timeline**. Os sinais abaixo estão com a recodificação corrigida.

| Item | n | M | Mdn | n≠0 | W | p | r |
|---|---|---|---|---|---|---|---|
| Facilidade de uso | 21 | +0,52 | 0 | 11 | 17,0 | 0,1485 | 0,44 |
| Velocidade percebida | 21 | +0,52 | 0 | 14 | 33,0 | 0,2141 | 0,33 |
| Confiança nos dados | 21 | +0,52 | 0 | 9 | 13,0 | 0,2449 | 0,39 |
| Estabilidade | 21 | +0,76 | +1 | 16 | 36,5 | 0,0984 | 0,41 |
| Comportamento em internet ruim | 21 | +0,33 | 0 | 9 | 15,5 | 0,3977 | 0,28 |
| Uso geral | 21 | +0,57 | 0 | 12 | 23,5 | 0,2157 | 0,36 |

**Preferência permanente** (recodificada para arquitetura): indiferente 12; offline 6; online 3.

**Leitura para o Capítulo 5.** Nenhum item rejeita a neutralidade (α = 0,05), mas **todas as médias apontam para o offline-first** (M > 0), alinhadas à telemetria objetiva e opostas ao SUS “empatado”. Isso fortalece o argumento da Seção 5.1: o problema é de **sensibilidade do SUS**, não ausência de preferência relativa — o comparativo direto captura uma direção que o SUS não captura, ainda sem atingir significância (amostra pequena; estabilidade p ≈ 0,10).

### 6.7 Simetria da degradação — janelas vs. volume (qualificação)

O `NetworkSimulator` tem **duas camadas** (`lib/services/network_simulator.dart` + `AppConfig`):

| Camada | Regra | Onde atua |
|---|---|---|
| 1. Janelas horárias | 07:30, 12:00, 17:30, 20:00, 22:30 (duração fixa) | `isDegraded` compartilhado |
| 2. Volume de ops | A cada **4** ops OK via `intercept()`, próximas **2** degradadas | Contador só em `intercept()` |

**Online-first:** CRUD passa por `intercept()` → sofre janela **e** volume; o contador de volume **avança** a cada operação bem-sucedida.

**Offline-first:**
- CRUD local (Hive) **não** passa pelo simulador → UI nunca é bloqueada por volume/janela.
- **Push** (Hive→Firestore) usa `checkPushToRemoteAllowed()`, que consulta o mesmo `isDegraded` (janela **ou** volume ativo), mas **não** chama `_recordOperationOutcome` — portanto **não alimenta** o contador de volume.
- **Pull** (Firestore→Hive) **não** é interceptado pelo simulador (por desenho: convergência com o canónico).

**Consequência para a alegação de “aplicação simétrica”:**
- As **janelas horárias** são simétricas no *flag* de degradação (ambos os modos as veem quando o caminho de rede é consultado).
- A camada por **volume não é simétrica**: só o caminho online (e outros usos de `intercept`, ex. impressões) gera e consome o contador; no offline-first o push *pode* ser bloqueado se o flag já estiver ativo (ex.: residual da fase online, ou impressão), mas o uso típico de tarefas **não dispara** a regra “4 OK → 2 degradadas”.
- A figura `06_linha_tempo_estudo.png` mostra as duas camadas; o texto do capítulo de método deve **qualificar** a simetria — não afirmar que volume e janelas se aplicam igualmente aos dois modos.

---

## 7. Conclusões gerais

1. **H1 (usabilidade percebida via SUS):** **não confirmada** na amostra completa (n=21 pares). Ambos os modos são avaliados como altamente usáveis, com diferença trivial.
2. **H2 (confiabilidade):**
   - **Subjetiva:** não confirmada formalmente; tendência na estabilidade (p ≈ 0,23).
   - **Objetiva (taxa efetiva / bloqueios):** **fortemente confirmada** (p ≈ 0,0003, r ≈ 0,79 no pipeline; r ≈ 0,88 com n efetivo). Offline-first elimina bloqueios por rede; online-first perde, em média, ~44% das tentativas contabilizadas (n=21, só T1+T2).
3. **Mensagem central para o TCC:** em conectividade limitada, a vantagem do offline-first neste protótipo aparece sobretudo como **garantia de conclusão operacional**; o SUS não diferencia, mas o **comparativo bipolar** (direção, ainda n.s.) e o contexto de uso apontam no mesmo sentido do objetivo.
4. **Contexto de uso** significativo reforça a narrativa de adequação do offline-first ao cenário de rede instável (com ressalva de alfa baixo no T2 — ver §11.1).
5. **Atrito diferencial:** sem evidência (Fisher p ≈ 0,40) após corrigir a ordem de exposição pela timeline — reporte na 5.5.1 como **resultado positivo** para validade interna.
6. Correção do P006 no RTDB e a adoção da **semântica de fase** para P016 (T1=offline) **incluem** a participante nos pares subjetivos; o aviso de submit atrasado permanece só como auditoria.

---

## 8. Limitações

| Limitação | Impacto |
|---|---|
| Amostra exploratória (alvo ~20; **21** pares subjetivos e objetivos com T1+T2) | Poder limitado para efeitos pequenos (ex.: SUS, confiança) |
| **Atrito global 25%** (28→21); diferencial por ordem **não significativo** (Fisher p ≈ 0,40) | Reportar atrito descritivo; ausência de diferencial fortalece validade interna |
| Instabilidade de rede **simulada** (duas camadas) | Janelas horárias são simétricas; camada por **volume** de ops **não** é (ver §6.7) |
| Interface idêntica nos dois modos | SUS / comparativo podem subestimar diferenças de arquitetura |
| `operation_success_rate` legado | Não discrimina; interpretação exige a taxa efetiva |
| Abandono após falha | Sem dados pareados |
| Sync só no offline | Sem contraste estatístico online vs offline |
| Submit atrasado vs troca de fase (ex.: P016) | Mitigado: pareamento usa fase gravada; aviso de auditoria se o relógio do envio divergir |
| Efeito de ordem | Reportado descritivamente; sem modelo de interação formal |
| Regras RTDB abertas para o script | Risco de segurança; script sem Admin SDK |
| Estudo de campo com engajamento variável | Confundidores (adesão, tempo de uso, semana do calendário) |
| Múltiplos testes sem correção (Bonferroni etc.) | Risco de falso positivo em achados exploratórios (ex.: contexto p=0,048) — reportar com cautela |
| SUS com α ≈ 0,70 (abaixo do típico ~0,90) | Consistência interna questionável/aceitável; possível efeito-teto |
| Contexto α = 0,57 no T2 | Não usar como escala somada no T2 sem ressalva |
| Área de formação / familiaridade técnica não coletadas | Comentário 22 do orientador só parcialmente respondido |

---

## 9. Como melhorar em pesquisa mais avançada

### 9.1 Desenho e amostra

- Aumentar n (ex.: 40–60) para detectar efeitos subjetivos pequenos (r ≈ 0,2–0,3).
- Pré-registro de hipóteses e de métricas primárias vs secundárias.
- Análise de poder *a priori* para Wilcoxon / efeitos esperados.
- Controles mais rígidos de adesão (mínimo de operações por fase para inclusão).

### 9.2 Instrumentos

- Incluir escalas específicas de **resiliência / confiança sob falha** (além do SUS genérico).
- Questionário **logo após** episódios de degradação (EMA — ecological momentary assessment), reduzindo viés de memória.
- Itens que meçam **frustração com bloqueio** e **percepção de perda de dados**.

### 9.3 Telemetria e métricas

- Tornar `effective_completion_rate` (ou equivalente) a **métrica objetiva primária** de disponibilidade desde o protocolo.
- Instrumentar melhor abandono após falha (timeouts, retries, saída de tela).
- Medir tempo até sucesso **incluindo** retries após bloqueio.
- Comparar consistência eventual (conflitos, edições concorrentes) em cenários multi-dispositivo.

### 9.4 Rede e validade ecológica

- Combinar simulação com logs de conectividade **real** (quando ética/privacidade permitirem).
- Variar severidade de degradação (percentual de bloqueio, latência) como fator experimental.

### 9.5 Análise estatística

- Modelos mistos (efeito aleatório de participante) + teste de interação **ordem × arquitetura**.
- Correção para múltiplas comparações nas métricas exploratórias.
- Análise de sensibilidade excluindo outliers de bloqueio / engajamento extremo.
- Alinhar código de importação e `domain.py` à **semântica de fase** (T1/T2), não só ao instante de submit.

### 9.6 Engenharia / reprodutibilidade

- Firebase Admin SDK (leitura autenticada) quando as regras forem fechadas.
- Versionar snapshots anonimizados dos dados usados no capítulo de resultados.
- Automatizar checagens de consistência (timeline × questionário × telemetria) no painel admin **antes** da análise final.

---

## 10. Artefatos e rastreabilidade

| Item | Local |
|---|---|
| Código da análise | `analysis/*.py`, `analysis/README.md` |
| Relatório automático (números brutos) | `analysis/output/hypothesis_tests.md` |
| Lacunas da revisão (alfa, demografia, atrito, comparativo) | `analysis/output/pending_gaps_report.md` |
| Tabela por participante | `analysis/output/metrics_by_participant.csv` |
| Gráficos | `analysis/output/results.png` |
| Hipóteses e protocolo | `especificacoes_tecnicas_v4 (1).md` (§1.2, §2.4–2.6, §13.2) |
| Esquema RTDB | `docs/firebase_rtdb_schema.md` |
| Log técnico de mudanças | `docs/rastreabilidade.md` |

---

## 11. Lacunas da revisão — resultados aplicados (27/07/2026)

Script: `analysis/analyze_pending_gaps.py`. Fonte: RTDB em tempo real. Reversão das escalas próprias: `tf2,tf4,tf6,tf8`, `cs4`, `ctx4` (idêntica a `REVERSE` em `questionario_*.html`).

**Critério de elegibilidade:** apenas quem **completou T1 e T2** (n=21). P031 e P036 (só T1) são excluídos de alfa, demografia, comparativo e Wilcoxon — entram só no funil de atrito.

### 11.1 Alfa de Cronbach (validade de construto → Seção 5.5.3)

Alfas reportados por período (amostra T1+T2; n=21 em cada onda).

| Escala | T1 (n=21) | T2 (n=21) | Leitura |
|---|---|---|---|
| SUS | 0,690 (questionável) | 0,714 (aceitável) | Abaixo do ~0,90 típico da literatura |
| Estabilidade (`tf*`) | 0,830 (boa) | 0,769 (aceitável) | Adequada para escala somada no T1 |
| Confiança (`cs*`) | 0,927 (excelente) | 0,943 (excelente) | Valida o pipeline de reversão |
| Contexto (`ctx*`) | 0,858 (boa) | 0,574 (inaceitável) | No T2, **não** tratar como escala somada sem ressalva |

**Interpretação.** O α excelente da confiança (~0,93) indica que a reversão dos itens negativos **está correta** — o sanity check do pipeline passa pelas escalas próprias, não pelo SUS. O SUS abaixo de 0,90 nesta amostra é compatível com **efeito-teto / baixa variância** (médias ~87–88), não com erro de recodificação. Na 5.5.3: reportar os alfas; reconhecer que o SUS aqui tem consistência apenas aceitável/questionável; destacar que o contexto no T2 não deve ser somado cegamente (o Wilcoxon de contexto usa a média Likert já calculada no pipeline — manter como exploratório).

### 11.2 Demografia (comentário 22)

Dados de `profile_questionnaire` (**n=21** com T1+T2):

| Variável | Resultado |
|---|---|
| Idade | M=26,1; DP=12,0; Mdn=21; min=18; máx=67 |
| Gênero | Masculino 66,7% (14); Feminino 33,3% (7) |
| Escolaridade | Superior incompleto 52,4%; Médio completo 23,8%; Superior completo 9,5%; Pós 4,8%; demais 9,6% |

**Lacuna residual:** `area_formacao` e `familiaridade_tec` **não foram coletadas**. Idade/escolaridade respondem parcialmente ao comentário 22; a proporção de participantes de computação/TI permanece desconhecida. Saída defensável: formulário curto e retroativo pós-debriefing, reportando a taxa de resposta.

### 11.3 Atrito diferencial (validade interna → Seção 5.5.1)

| Ordem inicial (1ª fase / timeline) | Iniciaram (telemetria) | Completaram T1+T2 | Atrito |
|---|---|---|---|
| offline-first | 13 | 11 | **15,4%** |
| online-first | 15 | 10 | **33,3%** |

- Taxa de atrito global: **25,0%** (28 → 21).
- Teste exato de Fisher: **p = 0,3955** → **sem evidência de atrito diferencial**.

> **Correção:** a versão anterior usava `architecture` corrente (= T2) como “ordem inicial”, invertendo os grupos e gerando Fisher p = 0,030 falso. Com a 1ª fase via timeline, o diferencial deixa de ser significativo.

**Na 5.5.1:** reporte o atrito global e declare a **ausência** de atrito diferencial significativo — isso **fortalece** a validade interna (os grupos de ordem permanecem comparáveis quanto à retenção).

### 11.4 Impacto no Capítulo 5 — checklist editorial

| Lacuna | Achado | Onde escrever |
|---|---|---|
| Alfa | Confiança excelente; SUS ~0,70; contexto T2 frágil | 5.5.3 |
| Demografia | Idade/gênero/escolaridade ok; falta área/TI | 5.5.2 + comentário 22 |
| Atrito diferencial | **Não significativo (p=0,40)** após correção da ordem | 5.5.1 (fortalece validade interna) |
| Comparativo T2 | Não-sig.; **todas as M > 0** (favor offline) | 5.1 / 5.3 (sensibilidade do SUS) |
| n efetivo / r | Declarar convenção; explicar W=0 idêntico | 3.6.3 + Quadros 4–6 |
| Elegibilidade | Só T1+T2 (n=21); P031/P036 fora | Método / amostra |
| Ordem de exposição | Fonte = 1ª entrada de `architecture_timeline` (não `architecture` corrente) | Método |

---

## 12. Status deste documento

| Campo | Conteúdo |
|---|---|
| **Status** | **Concluído** — H1/H2 com T1+T2; P016 incluída no subjetivo via semântica de fase (27/07/2026) |
| **Dependência** | `hypothesis_tests.md` e `pending_gaps_report.md` reexecutados após mudança em `domain.py` |
| **Risco residual** | Aviso P016 (auditoria); área de formação ausente; múltiplos testes exploratórios sem correção |

---

*Documento gerado para apoio ao capítulo de resultados/discussão do TCC. Não substitui a redação formal da monografia, mas consolida evidências, decisões metodológicas e limitações de forma rastreável.*
