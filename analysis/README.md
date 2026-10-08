# Análise completa do estudo (H1/H2)

Script Python que busca **todos** os dados gravados no Firebase Realtime
Database (cadastro de participantes, questionários subjetivos T1/T2 e
telemetria) e produz a análise estatística descrita nas especificações do
projeto (`especificacoes_tecnicas_v4 (1).md`, seções 1.2, 2.4-2.6 e 13.2).

## O que o script faz

1. Lê `participants/*` e `telemetry/*` de um snapshot local do RTDB ou,
   se as regras permitirem, via REST (veja a observação de segurança
   abaixo).
2. Para cada participante, recalcula de forma independente qual
   arquitetura (`online-first` / `offline-first`) estava vigente em cada
   questionário (T1/T2), usando `architecture_timeline` + `study_started_at`
   + `submitted_at` — **nunca** usa `assigned_architecture` como chave de
   comparação (ver `domain.py` e a entrada correspondente em
   `docs/rastreabilidade.md`).
3. Calcula os escores subjetivos:
   - **SUS** (0-100, fórmula de Brooke, 1996) → H1 (usabilidade)
   - **Confiabilidade percebida** (`reliability_trust`, `reliability_technical`,
     escala 1-7, com itens invertidos conforme `reverse_items`) → H2
   - **Contexto de uso** (escala 1-7) → relacionado a "conectividade limitada"
4. Calcula métricas objetivas de telemetria por arquitetura: taxa de
   sucesso de operações, operações bloqueadas/atrasadas, taxa de abandono
   após falha, taxas de sucesso de sincronização (push/pull, exclusivas do
   offline-first) e engajamento diário/semanal.
5. Pareia por participante (mesmo sujeito nas duas arquiteturas) e executa
   o **teste de Wilcoxon pareado** (não paramétrico, adequado a
   within-subjects com amostra pequena) + tamanho de efeito *r* de Wilcoxon,
   para H1 e H2.
6. Gera um relatório de efeito de ordem (qual arquitetura veio primeiro)
   como análise **secundária**, sem influenciar os testes de H1/H2.

## Como instalar

```bash
cd analysis
pip install -r requirements.txt
```

## Como rodar

```bash
python analyze_full_study.py
```

Opções:

```bash
python analyze_full_study.py \
  --database-url https://SEU-PROJETO-default-rtdb.firebaseio.com \
  --min-pairs 5 \
  --output-dir output
```

- `--database-url`: por padrão usa a variável de ambiente
  `FIREBASE_DATABASE_URL` ou o projeto configurado em
  `lib/firebase_options.dart` (`tcc-task-manager-82e52`).
- `--min-pairs`: número mínimo de participantes com dados nas duas
  arquiteturas para considerar o teste de Wilcoxon válido (default 5;
  abaixo disso o script reporta apenas estatística descritiva).
- `--output-dir`: pasta onde gravar os artefatos (default `analysis/output/`).

## Saídas geradas

| Arquivo | Conteúdo |
|---|---|
| `output/metrics_by_participant.csv` | Uma linha por participante × arquitetura (inclui `effective_completion_rate`, `total_attempts`) |
| `output/hypothesis_tests.md` | Relatório com Wilcoxon para H1/H2, incluindo evidência objetiva de H2 |
| `output/results.png` | Gráficos: SUS, confiabilidade percebida, taxa efetiva de conclusão (H2), engajamento semanal |
| `relatorio_completo_estudo.md` | Documento interpretativo (objetivo, método, problemas, resultados, limitações, pesquisa futura) |

## Observação de segurança

Desde 07/10/2026 as regras do RTDB e do Firestore negam leitura e escrita a
qualquer cliente (`database.rules.json`, `firestore.rules`). A leitura REST
sem credencial passa a receber 401, e `fetch_data.py` usa o snapshot mais
recente em `analysis/data/` (`rtdb_snapshot_*.json`). Também é possível
indicar o arquivo explicitamente:

```bash
TCC_RTDB_SNAPSHOT=analysis/data/rtdb_snapshot_2026-10-07_sem_nomes.json python analyze_full_study.py
```

O snapshot foi gerado com `firebase database:get / -o arquivo.json` (conta
com acesso ao projeto). Desde 08/10/2026 os campos de nome do RTDB e do
snapshot guardam o próprio código do participante; a correspondência
código → nome fica numa tabela-chave fora do repositório e do OneDrive. Os
dados continuam pseudonimizados (idade, gênero, escolaridade, respostas
abertas): a pasta `analysis/data/` é ignorada pelo Git e não faz parte do
repositório público.
Quem não tem o snapshot pode reproduzir o pipeline apenas com dados próprios;
os resultados agregados publicados estão em `analysis/resultados_agregados/`.

## Métricas objetivas de confiabilidade (H2)

Além dos questionários subjetivos, o relatório inclui:

- **`effective_completion_rate`** = operações concluídas com sucesso / (concluídas + bloqueadas). Incorpora tentativas impedidas pelo `NetworkSimulator` no modo online-first — constructo de **disponibilidade operacional** alinhado a H2.
- **`operations_blocked_total`** = contagem de bloqueios; teste de Wilcoxon com menor sendo melhor.

A métrica legada `operation_success_rate` (só sobre `operation_completed`) permanece em H1 com nota explicativa de que, neste desenho experimental, tende a 100% em ambos os modos.

## Solução de problemas

- **Script parece travado em "Buscando dados em ..." por muito tempo**: em
  redes corporativas/sandboxed com resolução de DNS lenta, a biblioteca
  `requests` pode demorar bem mais do que o esperado para resolver o
  hostname do Firebase (o parâmetro de timeout não cobre a fase de
  resolução de nome). Teste a conectividade básica primeiro com
  `curl https://SEU-PROJETO-default-rtdb.firebaseio.com/.json` — se isso
  responder rápido mas o script Python continuar lento, tente rodar fora
  de VPN/proxy corporativo ou aumente a paciência (a chamada eventualmente
  completa).

## Análises de lacunas (revisão do artigo)

Além de H1/H2, rode:

```bash
python analyze_pending_gaps.py
```

Gera `output/pending_gaps_report.md` com:

1. Alfa de Cronbach (SUS + escalas próprias; recortes T1/T2)
2. Demografia (`profile_questionnaire`: idade, gênero, escolaridade)
3. Atrito diferencial por ordem de exposição (1ª fase via `architecture_timeline`; Fisher)
4. Bloco comparativo bipolar T2 **recodificado** para offline-first
5. Wilcoxon com n efetivo (pares não-empatados) e *r* nas duas convenções

Reversão das escalas próprias (não deixar vazia): `tf2,tf4,tf6,tf8`, `cs4`, `ctx4`.

**Ordem de exposição:** não usar `architecture` corrente nem `assigned_architecture` vazio — usar a primeira entrada de `architecture_timeline` (`resolve_start_architecture` em `domain.py`). Sanity check: deve coincidir 21/21 com a arquitetura do T1.

## Figuras para o texto

```bash
python generate_figures.py
```

Gera PNGs em `output/figures/` **sem título embutido** (ABNT: título/fonte no documento). Convenções: azul = online-first, verde = offline-first; fig. 04 usa IC 95% (t) e eixo −3…+3; fig. 09 anota `n=` de ativos por semana. Capturas lado a lado dos protótipos **não** são geradas automaticamente — precisam de screenshots reais do APK.

## Respostas abertas (texto livre)

O `questionarios_flat.csv` **não** inclui `open_answers` (só escalas até `comp6`). Para exportar o bloco «Em suas palavras»:

```bash
python export_open_answers.py
```

Gera:
- `output/respostas_abertas.csv` — 1 linha/participante; `arq_T1`, `arq_T2` + `pergunta{1,2,3}_{T1,T2}`
- `output/respostas_abertas_por_periodo.csv` — 1 linha/participante×período; colunas `pergunta1..3`
- `output/respostas_abertas_enunciados.md` — enunciados exatos (Apêndice C / §3.4.1)

Arquitetura de fase via `resolve_period_architecture` (mesmo critério do comparativo bipolar).

## Datas reais das fases e exposição

```bash
python export_phase_dates.py
```

Gera:
- `output/datas_fases_participantes.csv` — 1 linha/participante (só código `Pxxx`): início (`study_started_at`), troca (1ª mudança em `architecture_timeline`), `submitted_at`/`imported_at` de T1 e T2, primeiro/último evento, `dayOfStudy` máximo, dias por fase, dias ativos, bloqueios online separados em leitura (`watch_tasks`) e escrita, taxa efetiva com e sem leitura, ciclos de push vetados no offline-first.
- `output/datas_fases_resumo.md` — descritivas dos que concluíram T1 e T2 (n = 21).

Datas em UTC−3. `dayOfStudy` conta desde o início do estudo (não reinicia na troca).

## Limitações conhecidas

- Eventos `sync_item` só existem em offline-first (estrutura do app), por
  isso as métricas de sincronização são reportadas apenas de forma
  descritiva, sem teste pareado.
- O teste de Wilcoxon exige diferenças não todas nulas; participantes sem
  dados em uma das arquiteturas são excluídos do par (reportado em
  `n_pairs`).
- **Elegibilidade:** só entram em H1/H2 participantes com questionários
  **T1 e T2**. Telemetria de incompletos é ignorada nos testes (não no
  funil de atrito de `analyze_pending_gaps.py`).
- O efeito de tamanho *r* é aproximado via `scipy.stats.norm.ppf(p/2)`,
  consistente com a metodologia já documentada na seção 13.2 das
  especificações técnicas. Em `analyze_pending_gaps.py` o denominador
  preferido é \(\sqrt{N_{\text{não-empatados}}}\).
