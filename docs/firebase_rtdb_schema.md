# Firebase Realtime Database — esquema do estudo (v4.1)

Este documento descreve a árvore JSON usada pelo aplicativo participante e pelo investigador. Ative o Realtime Database no projeto Firebase e importe ou copie as regras de exemplo em `firebase/database.rules.json` (**abertas para desenvolvimento** — substituir antes de dados reais).

## Raízes

### `study_config` (opcional)

Parâmetros globais legíveis pelo app (somente leitura para participante).

| Campo | Tipo | Descrição |
|-------|------|-----------|
| `total_study_days` | int | Referência (ex.: 30) |
| `days_per_architecture_default` | int | Ex.: 15 |

### `participants/{participantId}`

`participantId` usa o mesmo formato que o app já gera: `P001`, `P023`, etc.

Em **build debug**, o app de investigador usa `P000` (reservado); não use `P000` para participantes reais.

| Campo | Tipo | Descrição |
|-------|------|-----------|
| `architecture` | string | `online-first` ou `offline-first` |
| `app_enabled` | bool | Se `false`, o app mostra ecrã de estudo encerrado. O painel investigador pode definir este campo em massa para todos os participantes (exceto `P000`). |
| `telemetry_enabled` | bool | Se `false`, não grava telemetria |
| `display_name` | string | Nome ou pseudónimo (preenchido pelo questionário ou investigador) |
| `study_started_at` | string (ISO8601) | Opcional; pode ser definido no primeiro perfil |
| `days_online_phase` | number | Contador opcional (investigador ou app admin) |
| `days_offline_phase` | number | Idem |
| `profile_questionnaire` | map | Ver abaixo |

#### `profile_questionnaire`

| Campo | Tipo |
|-------|------|
| `name` | string |
| `age` | int |
| `gender` | string |
| `education` | string |

O participante **só** pode escrever `profile_questionnaire` (e campos de perfil acordados). Campos `architecture`, `app_enabled`, `telemetry_enabled` devem ser escritos apenas pelo investigador (regras ou Cloud Function).

#### `subjective_questionnaires/{T1|T2}`

Respostas dos formulários HTML externos (`questionario_T1.html`, `questionario_T2.html`), importadas pelo painel investigador.

| Campo | Tipo | Descrição |
|-------|------|-----------|
| `period` | string | `T1` (primeiros 15 dias) ou `T2` (últimos 15 dias) |
| `participant_id` | string | Ex.: `P007` |
| `participant_display_name` | string | Nome do cadastro RTDB |
| `assigned_architecture` | string | Arquitetura atribuída no cadastro (primeira fase) |
| `architecture_during_period` | string | Arquitetura vigente nos 15 dias do questionário |
| `submitted_at` | string (ISO8601) | Data informada pelo participante no JSON |
| `imported_at` | string (ISO8601) | Momento da importação pelo investigador |
| `schema_version` | string | Versão do esquema do questionário (ex.: `1.0`) |
| `responses` | map | Payload completo exportado pelo HTML (SUS, confiabilidade, comparativo T2, etc.) |

### `telemetry/{participantId}/{pushId}`

Eventos append-only. Cada `pushId` é gerado pelo cliente. O payload segue o contrato em `especificacoes_tecnicas_v4.md` (campos `eventType`, `timestamp`, `architecture`, etc.).

## Desenvolvimento local

- Emulador Firebase: configurar URL no `firebase_database` (opcional, fase posterior).
- Sem nó em RTDB: compile com `--dart-define=ALLOW_MISSING_RTDB_PARTICIPANT=true` para usar valores por defeito apenas em **debug** (ver `ParticipantRemoteConfigService`).
