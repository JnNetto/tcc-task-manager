# Datas reais das fases e exposição (participantes que concluíram T1 e T2)

Gerado por `analysis/export_phase_dates.py`. n = 21. Datas em UTC−3.
Detalhe por participante: `output/datas_fases_participantes.csv` (sem nomes).

## Calendário

- Primeiro início de estudo: 2026-05-22 19:10; último início: 2026-05-29 16:48.
- Primeira submissão de T2: 2026-06-25 10:05; última: 2026-07-12 10:51.
- Participantes com mais de uma troca registrada: 1.

## Duração (dias corridos)

| Medida | Descrição |
| --- | --- |
| Fase 1 (início → troca) | n=21; média 17.5; mediana 17.0; mín 15.0; máx 27.4 |
| Fase 2 (troca → envio do T2) | n=21; média 20.7; mediana 19.9; mín 15.5; máx 32.1 |
| Total (início → envio do T2) | n=21; média 38.1; mediana 37.4; mín 31.1; máx 48.7 |
| Fase online-first | n=21; média 19.5; mediana 18.5; mín 15.5; máx 27.4 |
| Fase offline-first | n=21; média 18.7; mediana 17.5; mín 15.0; máx 32.1 |
| Envio do T1 → troca | n=21; média 0.1; mediana 0.0; mín 0.0; máx 0.9 |
| Dias com operações (online-first) | n=21; média 4.4; mediana 4.0; mín 1.0; máx 10.0 |
| Dias com operações (offline-first) | n=21; média 5.4; mediana 5.0; mín 1.0; máx 11.0 |
| `dayOfStudy` máximo em operações | n=21; média 35.6; mediana 34.0; mín 30.0; máx 46.0 |

- Participantes com duração total acima de 30 dias: 21 de 21.
- Participantes com operação registrada após o dia 42 (semana 7 da Tabela 10): 3 de 21.
- `dayOfStudy` é contado desde `study_started_at` (não reinicia na troca), por isso
  a Tabela 10 alcança a semana 7 quando a participação total passa de 42 dias.

## Exposição à degradação no modo online-first

- Sucessos: 270; bloqueios de escrita (create/update/delete/impressão): 73;
  bloqueios de leitura da lista (`watch_tasks`): 292.
- Taxa efetiva agregada atual (com leitura no denominador): 270/635 = 0.425.
- Taxa efetiva agregada só com escritas: 270/343 = 0.787.
- Taxa efetiva por participante (atual): n=21; média 0.559; mediana 0.562; mín 0.000; máx 1.000.
- Taxa efetiva por participante (sem leitura): n=20; média 0.844; mediana 0.893; mín 0.515; máx 1.000 (participante sem nenhuma escrita online fica sem valor).
- Falhas reais (`operation_completed` com `success=false`) no modo online-first: 0.
- Participantes sem nenhum bloqueio online: 4.
- Spearman (dias da fase online × bloqueios totais): rho = -0.263, p = 0.2492.
- Spearman (dias da fase online × bloqueios de escrita): rho = -0.145, p = 0.5314.

## Pushes adiados no modo offline-first

- Ciclos de sincronização com push vetado pelo simulador (`sync_blocked`): 2242; n=21; média 106.8; mediana 16.0; mín 0.0; máx 884.0 por participante.
  O evento é emitido em todo ciclo (15 s, mutação ou abertura) durante degradação,
  mesmo sem nada pendente.
- Desses, ciclos com pelo menos uma tarefa pendente (push efetivamente adiado): 572; n=21; média 27.2; mediana 4.0; mín 0.0; máx 266.0 por participante.
- Itens enviados com sucesso (`sync_item` push): 386; falhas reais de push: 0.
- Push adiado não gera `operation_blocked`: a operação local já foi concluída e a
  tarefa permanece `pending` até um ciclo fora da degradação.
