# Relatório de análise — H1/H2 (gerado automaticamente)

Participantes com dados encontrados: 21
Amostra analítica (T1 **e** T2): **21** — incompletos excluídos de H1/H2.
Limite mínimo de pares para teste de Wilcoxon: 5
Pareamento subjetivo usa `architecture_during_period` da **fase** (prioridade sobre o instante de `submitted_at`) — ver `analysis/domain.py`.

## Avisos de consistência (architecture_during_period)

- P016 [T1]: adotada arquitetura de fase 'offline-first' (architecture_during_period); no instante do submit a timeline apontaria 'online-first'. Questionario da fase enviado apos a troca — pareamento usa a fase, nao o relogio do envio.

## H1 — Usabilidade percebida e eficácia objetiva

> H1: arquitetura offline-first apresenta melhor percepção de usabilidade do que online-first em conectividade limitada.

### Escore SUS (subjetivo, 0-100)

- Pares válidos (participante com as duas arquiteturas): 21
- Online-first:  M=86.429  SD=11.952
- Offline-first: M=87.619  SD=12.386
- Wilcoxon: W=49.000, p=0.3243, r=0.215
- Conclusão: diferença não significativa (H0 não rejeitada para esta métrica).

### Taxa de sucesso de operações (objetivo, 0-1)

- Pares válidos (participante com as duas arquiteturas): 20
- Status: sem_variabilidade (todas as diferencas sao zero)

> Nota: esta métrica considera apenas eventos `operation_completed` e ignora tentativas bloqueadas (`operation_blocked`). Nos dados deste estudo ela tende a 100% em ambas as arquiteturas e não discrimina os modos — ver métricas objetivas de H2 abaixo.

### Taxa de abandono após falha (objetivo, 0-1)

- Pares válidos (participante com as duas arquiteturas): 0
- Status: sem_dados_pareados

## H2 — Confiabilidade percebida

> H2: arquitetura offline-first apresenta melhor percepção de confiabilidade do que online-first em conectividade limitada.

### Confiança no aplicativo (subjetivo, escala 1-7)

- Pares válidos (participante com as duas arquiteturas): 21
- Online-first:  M=6.067  SD=1.131
- Offline-first: M=6.167  SD=1.114
- Wilcoxon: W=63.500, p=0.8159, r=0.051
- Conclusão: diferença não significativa (H0 não rejeitada para esta métrica).

### Estabilidade/funcionamento percebido (subjetivo, escala 1-7)

- Pares válidos (participante com as duas arquiteturas): 21
- Online-first:  M=5.862  SD=1.099
- Offline-first: M=6.270  SD=0.807
- Wilcoxon: W=45.000, p=0.2335, r=0.260
- Conclusão: diferença não significativa (H0 não rejeitada para esta métrica).

### Evidência objetiva de confiabilidade operacional (H2)

> Bloqueios por instabilidade simulada refletem indisponibilidade do sistema no momento do uso — constructo alinhado à confiabilidade percebida (H2), conforme seção 2.6 das especificações (`operations_blocked` vinculado a H1 e H2).

### Taxa efetiva de conclusão (objetivo, 0-1)

- Pares válidos (participante com as duas arquiteturas): 21
- Online-first:  M=0.559  SD=0.329
- Offline-first: M=1.000  SD=0.000
- Wilcoxon: W=0.000, p=0.0003, r=0.790
- Conclusão: diferença significativa **favorecendo offline-first**.

> Fórmula: `operation_completed` com sucesso / (`operation_completed` + `operation_blocked`). Incorpora tentativas impedidas pela rede no modo online-first.

### Operações bloqueadas (objetivo, contagem)

- Pares válidos (participante com as duas arquiteturas): 21
- Online-first:  M=17.381  SD=25.874
- Offline-first: M=0.000  SD=0.000
- Wilcoxon: W=0.000, p=0.0003, r=0.790
- Conclusão: diferença significativa **favorecendo offline-first**.

## Contexto de uso (situações do dia a dia, escala 1-7)

> Bloco relacionado à condição "conectividade limitada" mencionada em H1/H2; reportado descritivamente.

### Escore de contexto

- Pares válidos (participante com as duas arquiteturas): 21
- Online-first:  M=5.714  SD=1.305
- Offline-first: M=6.276  SD=0.889
- Wilcoxon: W=21.000, p=0.0477, r=0.432
- Conclusão: diferença significativa **favorecendo offline-first**.

## Métricas exclusivas do modo offline-first (sincronização)

Eventos `sync_item` só são registrados em offline-first; sem par em online-first, reportado apenas de forma descritiva (sem Wilcoxon).

| architecture   |   ('sync_push_success_rate', 'mean') |   ('sync_push_success_rate', 'std') |   ('sync_push_success_rate', 'count') |   ('sync_pull_success_rate', 'mean') |   ('sync_pull_success_rate', 'std') |   ('sync_pull_success_rate', 'count') |   ('avg_pending_to_sync_ms', 'mean') |   ('avg_pending_to_sync_ms', 'std') |   ('avg_pending_to_sync_ms', 'count') |
|:---------------|-------------------------------------:|------------------------------------:|--------------------------------------:|-------------------------------------:|------------------------------------:|--------------------------------------:|-------------------------------------:|------------------------------------:|--------------------------------------:|
| offline-first  |                                    1 |                                   0 |                                    21 |                                    1 |                                   0 |                                    21 |                          7.41901e+06 |                         1.64702e+07 |                                    21 |
| online-first   |                                  nan |                                 nan |                                     0 |                                    1 |                                 nan |                                     1 |                        nan           |                       nan           |                                     0 |

## Efeito de ordem (secundário — não altera H1/H2)

Compara o escore SUS médio agrupando por qual arquitetura veio primeiro (T1) para cada participante; usa a atribuição inicial **apenas aqui**.

| first_architecture   | architecture   |    mean |      std |   count |
|:---------------------|:---------------|--------:|---------:|--------:|
| offline-first        | offline-first  | 90.2273 | 10.5151  |      11 |
| offline-first        | online-first   | 90.4545 |  9.86269 |      11 |
| online-first         | offline-first  | 84.75   | 14.1642  |      10 |
| online-first         | online-first   | 82      | 12.9529  |      10 |

## Engajamento semanal médio (operações/dia)

| architecture   |   week |   total_operations |
|:---------------|-------:|-------------------:|
| offline-first  |      1 |            4.38462 |
| offline-first  |      2 |            1.83333 |
| offline-first  |      3 |            2.18182 |
| offline-first  |      4 |            3.55556 |
| offline-first  |      5 |            1.33333 |
| offline-first  |      6 |            3.81818 |
| offline-first  |      7 |            2.5     |
| online-first   |      1 |            2.88462 |
| online-first   |      2 |            3       |
| online-first   |      3 |            3.41667 |
| online-first   |      4 |            1.46667 |
| online-first   |      5 |            2.35714 |
| online-first   |      6 |            1       |
| online-first   |      7 |            0       |
