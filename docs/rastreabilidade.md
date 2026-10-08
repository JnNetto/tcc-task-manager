# Log de Rastreabilidade Tecnica

**Nota (governanca):** A partir de **2026-05-14**, cada alteracao com impacto relevante deve ser registada com **lista narrativa** e com **tabela-resumo** (campos ID/contexto/causa/decisao/arquivos/validacao/risco/status), como nas seccoes datadas abaixo e no modelo no final deste ficheiro.

## 2026-04-28 - Correcao Passo 0 e Passo 1

- **Contexto:** Validacao inicial mostrou Passo 0 e Passo 1 apenas parciais.
- **Problema/Bug 1:** `NotificationService` ainda podia manter IDs antigos ao reagendar recorrencia em `_scheduleRecurringWithExactAlarms`.
- **Causa:** Cancelamento preventivo de IDs antigos estava presente no refill, mas nao no reagendamento principal.
- **Correcao aplicada:** Adicionado cancelamento dos IDs antigos antes de gerar nova janela em `notifications_service.dart`.
- **Arquivos alterados:** `notifications_service.dart`.
- **Validacao:** Analise estatica do metodo e preservacao da logica existente de IDs estaveis/payload.
- **Status:** Concluido.

- **Problema/Bug 2:** Passo 1 incompleto para flavors (faltavam `resValue` por flavor e `minSdk` explicitamente em 21).
- **Correcao aplicada:** Ajustado `android/app/build.gradle.kts` com `resValue` para `online`/`offline` e `minSdk = 21`.
- **Arquivos alterados:** `android/app/build.gradle.kts`.
- **Validacao:** Revisao do arquivo Gradle apos patch.
- **Status:** Concluido.

- **Problema/Bug 3:** Build por flavor falhava por falta de `google-services.json` com package names dos flavors.
- **Correcao aplicada:** Criados `android/app/src/online/google-services.json` e `android/app/src/offline/google-services.json` com package names dos respectivos flavors.
- **Arquivos alterados:** `android/app/src/online/google-services.json`, `android/app/src/offline/google-services.json`.
- **Validacao:** Build reexecutado; `app-online-debug.apk` gerado com sucesso. Build `offline` falhou em `:app:mergeOfflineDebugNativeLibs` com erro de ambiente: `Espaço insuficiente no disco`.
- **Status:** Parcial (pendente liberar espaco em disco e reexecutar build offline).

- **Revalidacao apos ajuste de ambiente:** Build `offline` reexecutado com sucesso.
- **Evidencia:** `build/app/outputs/flutter-apk/app-offline-debug.apk` gerado.
- **Status atualizado:** Concluido.

## 2026-04-28 - Verificacao e ajuste do Passo 2 (Firebase)

- **Contexto:** O desenvolvedor informou que o FlutterFire CLI nao solicitou bundle/package dos dois flavors e que no Firebase Console existe apenas um app Android.
- **Problema observado:** `firebase_options.dart` estava em `lib/` e nao em `lib/config/` conforme o passo a passo.
- **Correcao aplicada:** Arquivo movido para `lib/config/firebase_options.dart` e import atualizado no app.
- **Problema observado:** `main.dart` ainda nao inicializava Firebase.
- **Correcao aplicada:** Adicionada inicializacao com `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`.
- **Arquivos alterados:** `lib/main.dart`, `lib/config/firebase_options.dart`, remocao de `lib/firebase_options.dart`.
- **Estado dos artifacts Firebase Android:** existem `google-services.json` em `android/app/google-services.json`, `android/app/src/online/google-services.json` e `android/app/src/offline/google-services.json`.
- **Limite de validacao:** Regras do Firestore e escrita/leitura de documento no Console dependem de validacao manual no Firebase Console e execucao em dispositivo/emulador.
- **Status:** Parcialmente validado localmente; pendente validacao funcional manual (criterio de aceite 2).

## 2026-04-28 - Pos-flutterfire configure (alinhamento de artefatos)

- **Contexto:** FlutterFire CLI foi executado com plataforma Android e gerou novamente `lib/firebase_options.dart`.
- **Problema observado:** Duplicidade de arquivo de configuracao (`lib/firebase_options.dart` e `lib/config/firebase_options.dart`), contrariando padrao adotado no projeto.
- **Correcao aplicada:** Sincronizado conteudo gerado para `lib/config/firebase_options.dart` e removido o duplicado em `lib/firebase_options.dart`.
- **Verificacao de JSONs Android:** `google-services.json` dos flavors contem multiplos `client` e incluem os package names esperados (`base`, `online`, `offline`), o que e valido.
- **Status:** Concluido.

## 2026-04-28 - Implementacao do Passo 3 (AppConfig)

- **Contexto:** Solicitada implementacao do Passo 3 conforme `passo_a_passo.md`.
- **Decisao aplicada:** Mantido `periodDurationDays = 28` conforme passo a passo.
- **Arquivos alterados:** `lib/config/app_config.dart`, `README.md`.
- **Implementacao:** Criadas constantes de simulacao (`periodDurationDays`, `networkDegradationWindows`, `degradationMode`, `simulatedLatencyMs`), classe `SimulationWindow` e enum `DegradationMode`.
- **Validacao executada:** `flutter analyze lib/config/app_config.dart lib/main.dart`.
- **Resultado:** Sem erros; passo 3 implementado.
- **Risco residual:** Nenhum gatilho automatico de "contagem de 28 dias" foi introduzido neste passo; neste momento e apenas parametro de configuracao.

## 2026-04-28 - Implementacao do Passo 4 (Modelos de dominio)

- **Contexto:** Solicitada continuidade para o Passo 4 do plano.
- **Arquivos alterados:** `lib/domain/models/sync_status.dart`, `lib/domain/models/task_priority.dart`, `lib/domain/models/task.dart`.
- **Implementacao:** Criados enum `SyncStatus`, enum `TaskPriority` com extensao de label, e classe imutavel `Task` com `copyWith`, `toFirestore()` e `fromFirestore()`.
- **Validacao executada:** `flutter analyze lib/domain/models` e verificacao de lints nos 3 arquivos.
- **Resultado:** Sem erros de analise/lint; modelos compilam corretamente.
- **Status:** Concluido.

## 2026-04-28 - Implementacao do Passo 5 (Interface TaskRepository)

- **Contexto:** Solicitada continuidade para o Passo 5 do plano.
- **Arquivos alterados:** `lib/domain/repositories/task_repository.dart`.
- **Implementacao:** Criada interface abstrata `TaskRepository` com contrato minimo: `watchTasks`, `createTask`, `updateTask`, `deleteTask`, `getTaskById`.
- **Validacao executada:** `flutter analyze lib/domain/repositories/task_repository.dart`, checagem de lints, e busca por dependencias de Firestore/Hive.
- **Resultado:** Sem erros de analise/lint e sem acoplamento a Firestore/Hive.
- **Status:** Concluido.

## 2026-04-28 - Implementacao do Passo 6 (Tema e widgets comuns)

- **Contexto:** Solicitada continuidade para o Passo 6; confirmado interesse explicito em componente reutilizavel de loading.
- **Arquivos alterados:** `lib/config/app_theme.dart`, `lib/widgets/common/loading_indicator.dart`, `lib/widgets/common/error_dialog.dart`, `lib/widgets/task_card.dart`, `lib/widgets/sync_status_indicator.dart`, `lib/main.dart`.
- **Implementacao:** Criado tema global claro/escuro (`AppTheme`) e aplicado no `MaterialApp`; criados widgets visuais reutilizaveis (`LoadingIndicator`, `ErrorDialog`, `TaskCard`, `SyncStatusIndicator`) sem logica de negocio.
- **Validacao executada:** `flutter analyze` nos arquivos do passo.
- **Resultado:** Sem erros de analise; criterios de aceite atendidos no nivel de compilacao/comportamento esperado dos widgets.
- **Status:** Concluido.

## 2026-04-28 - Implementacao conjunta dos Passos 7 e 8

- **Contexto:** Solicitada execucao da abordagem A, implementando Passo 7 (telemetria) e Passo 8 (simulador de rede) no mesmo ciclo.
- **Arquivos alterados:** `lib/data/hive/telemetry_event_model.dart`, `lib/data/hive/telemetry_event_model.g.dart`, `lib/services/telemetry_service.dart`, `lib/services/network_simulator.dart`, `test/telemetry_service_test.dart`.
- **Implementacao:** Criados `TelemetryEventModel` (Hive typeId 10), `TelemetryService` singleton com catalogo de eventos completo e `exportToJson()`, e `NetworkSimulator` com `start()`, `intercept()`, `checkSyncAllowed()` e `OfflineException`.
- **Validacao executada:** `flutter pub run build_runner build --delete-conflicting-outputs`, `flutter analyze` dos arquivos do passo e `flutter test test/telemetry_service_test.dart`.
- **Resultado:** Adapter Hive gerado com sucesso; analise sem erros; teste de aceite (10 eventos + exportacao com summary e daily_breakdown) aprovado.
- **Status:** Concluido.
- **Risco residual:** Aviso de versao do analyzer emitido no build_runner, sem bloquear geracao dos arquivos.

## 2026-04-28 - Implementacao do Passo 9 (OnlineTaskRepository)

- **Contexto:** Solicitada continuidade para o Passo 9 apos conclusao dos passos 7 e 8.
- **Arquivos alterados:** `lib/data/online/online_task_repository.dart`.
- **Implementacao:** Criado `OnlineTaskRepository` com `watchTasks`, `createTask`, `updateTask`, `deleteTask` e `getTaskById`, usando `NetworkSimulator.intercept` nas operacoes de escrita e telemetria de inicio/conclusao/bloqueio/latencia.
- **Decisao aplicada:** `getTaskById` implementado sem `intercept`, conforme decisao do plano para uso de background/NotificationService.
- **Validacao executada:** `flutter analyze lib/data/online/online_task_repository.dart` + checagem de lints.
- **Resultado:** Sem erros de analise/lint; criterios tecnicos do passo atendidos no nivel de implementacao.
- **Status:** Concluido.

## 2026-04-28 - Implementacao do Passo 10 (TaskHiveModel + OfflineTaskRepository)

- **Contexto:** Solicitada continuidade para o Passo 10.
- **Arquivos alterados:** `lib/data/offline/task_hive_model.dart`, `lib/data/offline/task_hive_model.g.dart`, `lib/data/offline/offline_task_repository.dart`, `test/offline_task_repository_test.dart`.
- **Implementacao:** Criado `TaskHiveModel` (typeId 0) com conversao `fromDomain/toDomain`; criado `OfflineTaskRepository` com CRUD local, `watchTasks` reativo com emissao inicial imediata, filtro de itens `deleted`, `getPending`, `markSynced`, `markError`, `removeFromBox` e `getTaskById`.
- **Validacao executada:** `flutter pub run build_runner build --delete-conflicting-outputs`, `flutter analyze` dos arquivos do passo e `flutter test test/offline_task_repository_test.dart`.
- **Resultado:** Adapter Hive gerado, analise sem erros e testes de aceite passando (emissao inicial do stream e comportamento de deletados/pending).
- **Status:** Concluido.
- **Risco residual:** Aviso nao bloqueante sobre versao do analyzer durante build_runner.

## 2026-04-28 - Implementacao do Passo 11 (SyncService)

- **Contexto:** Solicitada continuidade para o Passo 11.
- **Arquivos alterados:** `lib/data/offline/sync_service.dart`.
- **Implementacao:** Criado `SyncService` com timer de 5 minutos, tentativa imediata ao iniciar, gate por `NetworkSimulator.checkSyncAllowed`, sincronizacao de pendentes (`set` para pendentes, `delete` para deletados), remocao fisica do Hive apos delete remoto (`removeFromBox`) e telemetria de `sync_started`, `sync_item`, `sync_completed`.
- **Validacao executada:** `flutter analyze lib/data/offline/sync_service.dart` + checagem de lints.
- **Resultado:** Sem erros de analise/lint; implementacao alinhada ao fluxo esperado do passo.
- **Status:** Concluido.
- **Risco residual:** Criterios que dependem de execucao integrada com Firestore real e janelas de degradacao exigem validacao de integracao em runtime.

## 2026-04-28 - Implementacao do Passo 14 (Provider e wiring base)

- **Contexto:** Ordem ajustada pelo Apêndice B (`11 -> 14 -> 12 -> 13`).
- **Arquivos alterados:** `lib/providers/experiment_provider.dart`, `lib/providers/task_provider.dart`, `lib/utils/participant_loader.dart`.
- **Implementacao:** Criado `ExperimentProvider` com `participantId`, `prototype`, `studyStartDate`, `dayOfStudy` e helpers de prototipo; criado loader de participante/data via `SharedPreferences`; criado `TaskProvider` (opcional do passo) com binding de stream e operações delegadas ao `TaskRepository`.
- **Validacao executada:** `flutter analyze` dos 3 arquivos e checagem de lints.
- **Resultado:** Sem erros de analise/lint.
- **Status:** Concluido (wiring final por flavor em `MultiProvider` fica para os entry points do Passo 17).

## 2026-04-28 - Implementacao antecipada do Passo 15 (NotificationService)

- **Contexto:** Decisao do usuario de antecipar o Passo 15 antes do 12 para evitar stubs e retrabalho.
- **Arquivos alterados:** `lib/services/notification_service.dart`.
- **Implementacao:** Criado `NotificationService` adaptado ao dominio `Task`, com agendamento unico/recorrente diario, IDs estaveis, payload `task:<id>`, `cancelForTask` em 3 camadas (ID unico, IDs salvos e varredura de orfas), `rescheduleForTask`, `performMaintenanceCleanup` e refill recorrente cancelando IDs antigos antes de reagendar.
- **Validacao executada:** `flutter analyze lib/services/notification_service.dart` + checagem de lints.
- **Resultado:** Sem erros de analise/lint.
- **Status:** Concluido.

## 2026-04-28 - Implementacao do Passo 12 (Telas de tarefas)

- **Contexto:** Passo 12 executado apos Passo 14 e com NotificationService ja disponivel (Passo 15 antecipado).
- **Arquivos alterados:** `lib/screens/task_list_screen.dart`, `lib/screens/task_form_screen.dart`, `lib/screens/task_detail_screen.dart`.
- **Implementacao:** Criadas telas de lista/formulario/detalhes com consumo de `TaskProvider`, filtro de tarefas, navegacao entre telas, integracao de notificacoes em criar/editar/excluir/concluir/reabrir, exibicao condicional de `SyncStatusIndicator` no prototipo offline e tratamento de erro do prototipo online com `ErrorDialog` + `logAbandonAfterFailure`.
- **Validacao executada:** `flutter analyze` das tres telas.
- **Resultado:** Sem erros de analise/lint nos arquivos do passo.
- **Status:** Concluido (wiring final no app principal e entrada por flavor permanece para o Passo 17).

## 2026-04-28 - Implementacao do Passo 13 (Configuracoes e exportacao)

- **Contexto:** Continuidade apos conclusao do Passo 12.
- **Arquivos alterados:** `lib/services/export_service.dart`, `lib/screens/settings_screen.dart`, `android/app/src/main/res/xml/provider_paths.xml`.
- **Implementacao:** Criado `ExportService.exportAndShare` para gerar JSON da telemetria e abrir compartilhamento; criada `SettingsScreen` com exibicao de `participantId`, `prototype`, `dayOfStudy` e acao de exportacao.
- **Validacao executada:** `flutter analyze` dos arquivos do passo.
- **Resultado:** Sem erros de analise/lint.
- **Status:** Concluido.
- **Observacao:** `provider_paths.xml` criado para suportar fluxo de compartilhamento no Android conforme cuidado do passo.

## 2026-04-28 - Validacao e fechamento do Passo 16 (Integracao de notificacoes)

- **Contexto:** Continuidade apos passos 12, 13 e 15.
- **Verificacao realizada:** Confirmado fluxo integrado em telas:
  - criar tarefa: `createTask` + `NotificationService.scheduleForTask`
  - editar tarefa: `updateTask` + `NotificationService.rescheduleForTask`
  - excluir tarefa: `NotificationService.cancelForTask` antes de `deleteTask`
  - concluir/reabrir: cancelamento ao concluir e reagendamento ao reabrir
- **Arquivos verificados:** `lib/screens/task_form_screen.dart`, `lib/screens/task_detail_screen.dart`, `lib/services/notification_service.dart`.
- **Validacao executada:** `flutter analyze` dos arquivos envolvidos + checagem de lints.
- **Resultado:** Sem erros de analise/lint.
- **Status:** Concluido no nivel de implementacao; criterios de aceite que dependem de disparo real de notificacoes exigem teste em dispositivo/emulador.

## 2026-04-28 - Implementacao do Passo 17 (Entry points por prototipo)

- **Contexto:** Continuidade na ordem do Apêndice B apos fechamento do Passo 16.
- **Arquivos alterados:** `lib/app.dart`, `lib/main_online.dart`, `lib/main_offline.dart`.
- **Implementacao:** Criado `App` compartilhado com `TaskListScreen`; criado `main_online.dart` com Firestore sem cache (`persistenceEnabled: false`), inicializacao de Hive/telemetria/rede/notificacoes e injeção via `MultiProvider`; criado `main_offline.dart` com Hive (`tasks` + `telemetry`), `OfflineTaskRepository`, `SyncService` iniciado e providers apropriados.
- **Ajuste durante validacao:** Removido import nao usado de `cloud_firestore` em `main_offline.dart`.
- **Validacao executada:** `flutter analyze` dos entry points e `flutter build apk --flavor online --target lib/main_online.dart --debug` + `flutter build apk --flavor offline --target lib/main_offline.dart --debug`.
- **Resultado:** Analise sem erros e builds dos dois flavors concluidos com sucesso.
- **Status:** Concluido.

## 2026-04-28 - Execucao do Passo 18 (Build e validacao de APKs)

- **Contexto:** Continuidade apos conclusao do Passo 17.
- **Comandos executados:** `flutter clean`, `flutter pub get`, `flutter pub run build_runner build --delete-conflicting-outputs`, `flutter build apk --flavor online --target lib/main_online.dart --release`, `flutter build apk --flavor offline --target lib/main_offline.dart --release`.
- **Artefatos gerados:** `build/app/outputs/flutter-apk/app-online-release.apk` e `build/app/outputs/flutter-apk/app-offline-release.apk`.
- **Resultado:** Pipeline de build concluido com sucesso para os dois prototipos.
- **Observacao tecnica:** Warning nao bloqueante do `hive_generator` sobre versao do analyzer, sem impacto no build.
- **Status:** Concluido no nivel de build; validacao manual em dispositivo real (roteiro 18.2) permanece pendente para fechamento experimental completo.

## 2026-04-28 - Ajuste de recorrencia diaria com selecao de dias

- **Contexto:** Solicitacao de UX para permitir escolher em quais dias da semana a notificacao recorrente diaria deve tocar.
- **Arquivos alterados:** `lib/domain/models/task.dart`, `lib/data/offline/task_hive_model.dart`, `lib/data/offline/task_hive_model.g.dart`, `lib/services/notification_service.dart`, `lib/screens/task_form_screen.dart`, `lib/screens/task_detail_screen.dart`.
- **Implementacao:** Adicionado campo `recurringWeekdays` no dominio/persistencia; formulario passou a exibir chips de selecao de dias (Seg..Dom); agendamento recorrente considera filtro por `DateTime.weekday`; detalhes da tarefa exibem os dias selecionados.
- **Validacao executada:** `flutter pub run build_runner build --delete-conflicting-outputs` e `flutter analyze` dos arquivos alterados.
- **Resultado:** Adapter Hive regenerado com sucesso e analise sem erros/lints.
- **Status:** Concluido.

## 2026-04-28 - Diagnostico de sincronizacao offline sem feedback

- **Contexto:** Relato de que o prototipo offline nao sincronizava e nao havia retorno observavel no console.
- **Problema identificado:** Em criacao offline, o `createTask` aceitava status vindo da camada superior; se viesse `synced`, a tarefa nao entrava na fila de pendentes. Alem disso, havia baixa observabilidade do ciclo de sync.
- **Correcao aplicada:** `OfflineTaskRepository.createTask` passou a forcar `syncStatus: pending` e `pendingSince` na criacao local. `SyncService` recebeu logs de diagnostico (`start`, bloqueio por janela, pendentes, upsert/delete remoto, erros e resumo) e protecao com `try/finally` para liberar `_isSyncing` em qualquer caminho.
- **Arquivos alterados:** `lib/data/offline/offline_task_repository.dart`, `lib/data/offline/sync_service.dart`.
- **Validacao executada:** `flutter analyze` dos arquivos alterados.
- **Resultado:** Sem erros de analise/lint; comportamento de sync offline mais robusto e com rastreio visivel.
- **Status:** Concluido.

## 2026-04-28 - Estrategia dupla de degradacao (implementacao em codigo)

- **Contexto:** Solicitacao para alinhar a implementacao real ao novo desenho da secao 7 em `especificacoes_tecnicas_v4.md` (janelas ampliadas + degradacao por operacoes).
- **Correcao/Decisao aplicada:** `AppConfig` atualizado com 5 janelas fixas (07:30/12:00/17:30/20:00/22:30) e novos parametros da camada por operacoes (`degradationEveryNOps = 4`, `degradationDurationOps = 2`). `NetworkSimulator` passou a combinar duas camadas (`_inTimeWindow` e `_inOpDegradation`), com `isDegraded` por OR logico e enum `DegradationCause` (`none`, `timeWindow`, `opBased`, `both`).
- **Implementacao complementar:** Adicionado controle de ciclo por operacoes bem-sucedidas (`_recordOperationOutcome`), com eventos `op_degradation_window_started` e `op_degradation_window_ended`; bloqueios/latencia agora registram `cause`; `checkSyncAllowed` passou a logar causa no `reason`.
- **Ajuste de telemetria:** `TelemetryService` recebeu suporte a `cause` em `logOperationBlocked`, `logOperationDelayed` e `logNetworkWindowChanged`.
- **Arquivos alterados:** `lib/config/app_config.dart`, `lib/services/network_simulator.dart`, `lib/services/telemetry_service.dart`.
- **Validacao executada:** `flutter analyze lib/config/app_config.dart lib/services/network_simulator.dart lib/services/telemetry_service.dart lib/data/online/online_task_repository.dart lib/data/offline/sync_service.dart` + checagem de lints dos arquivos alterados.
- **Resultado:** Sem erros de analise/lint; simulacao dual ativa no codigo.
- **Status:** Concluido.

## 2026-04-29 - Identificacao de participante na primeira execucao

- **Contexto:** Necessidade de diferenciar claramente quem e quem entre os prototipos no mesmo dispositivo, evitando uso implicito do fallback fixo.
- **Problema identificado:** `loadParticipantId()` retornava `P000_TEST` quando nao havia valor salvo, o que podia levar online/offline a apontarem para o mesmo `participantId` no Firestore sem intencao explicita.
- **Correcao aplicada:** `loadParticipantId` passou a exigir `prototype` e, na primeira execucao, gerar e persistir automaticamente um ID unico por app (`ONL_<timestamp>` ou `OFF_<timestamp>`). Tambem foi adicionado suporte a override manual via `--dart-define=PARTICIPANT_ID=<ID>`, persistindo esse valor no app.
- **Arquivos alterados:** `lib/utils/participant_loader.dart`, `lib/main_online.dart`, `lib/main_offline.dart`.
- **Validacao executada:** `flutter analyze lib/utils/participant_loader.dart lib/main_online.dart lib/main_offline.dart` + checagem de lints.
- **Resultado:** Sem erros de analise/lint; primeira execucao passa a registrar identidade de participante sem depender de fallback compartilhado.
- **Status:** Concluido.

## 2026-04-29 - Tela de primeiro acesso para numero do participante (PXXX)

- **Contexto:** Solicitado substituir identificacao automatica por entrada explicita do numero do participante na primeira execucao, com UX no estilo codigo OTP (um campo por digito e autoavanco de foco).
- **Problema identificado:** Ausencia de tela de captura inicial impedia mapeamento controlado dos participantes no experimento.
- **Correcao aplicada:** Criada `ParticipantOnboardingScreen` com 3 campos numericos (`0-9`), foco automatico para o proximo campo, envio ao completar `3` digitos e preview do ID no formato `PXXX`. O ID e persistido em `SharedPreferences` e reutilizado nas proximas aberturas.
- **Integracao em runtime:** `main_online.dart` e `main_offline.dart` agora verificam `participant_id` antes da inicializacao completa. Sem ID salvo, exibem onboarding; apos confirmacao, salvam `PXXX` e iniciam o app principal normalmente.
- **Ajuste do loader:** `loadParticipantId()` passou a retornar `null` quando nao ha ID salvo (mantendo suporte de override via `--dart-define=PARTICIPANT_ID=...`).
- **Arquivos alterados:** `lib/screens/participant_onboarding_screen.dart`, `lib/utils/participant_loader.dart`, `lib/main_online.dart`, `lib/main_offline.dart`.
- **Validacao executada:** `flutter analyze lib/utils/participant_loader.dart lib/screens/participant_onboarding_screen.dart lib/main_online.dart lib/main_offline.dart` + checagem de lints.
- **Resultado:** Sem erros de analise/lint; fluxo de identificacao inicial operacional nos dois prototipos.
- **Status:** Concluido.

## 2026-04-29 - Reordenacao manual de tarefas na listagem

- **Contexto:** Solicitado permitir reposicionar tarefas na ordem desejada diretamente na tela de listagem.
- **Correcao/Decisao aplicada:** Implementado drag-and-drop na lista principal (filtro "Todas") via `ReorderableListView`, com persistencia da ordem no modelo de dominio por campo `sortOrder`.
- **Persistencia e sincronizacao:** Adicionado `sortOrder` em `Task`, Firestore e Hive. Criado metodo `reorderTasks(List<Task>)` no contrato `TaskRepository` com implementacao online (batch update no Firestore) e offline (atualizacao local marcando como pendente para sync).
- **Comportamento da listagem:** `watchTasks` passou a ordenar por `sortOrder` quando presente, mantendo fallback por `createdAt` para dados legados sem ordenacao manual.
- **Arquivos alterados:** `lib/domain/models/task.dart`, `lib/domain/repositories/task_repository.dart`, `lib/providers/task_provider.dart`, `lib/data/online/online_task_repository.dart`, `lib/data/offline/task_hive_model.dart`, `lib/data/offline/task_hive_model.g.dart`, `lib/data/offline/offline_task_repository.dart`, `lib/screens/task_list_screen.dart`.
- **Validacao executada:** `flutter pub run build_runner build --delete-conflicting-outputs` + `flutter analyze` dos arquivos alterados.
- **Resultado:** Sem erros de analise/lint; reordenacao manual funcional com ordem persistida.
- **Status:** Concluido.

## 2026-04-29 - Correcao: reordenacao offline nao deve gerar pendencia

- **Contexto:** Ajuste solicitado apos validacao: ao reordenar no prototipo offline, tarefas voltavam para estado pendente, o que conflita com o objetivo de UX (ordenacao visual).
- **Problema identificado:** `OfflineTaskRepository.reorderTasks` atualizava `syncStatus` para `pending` e preenchia `pendingSince`.
- **Correcao aplicada:** Reordenacao offline passou a alterar apenas `sortOrder` localmente, preservando `syncStatus`, `pendingSince` e demais campos de sincronizacao.
- **Arquivos alterados:** `lib/data/offline/offline_task_repository.dart`.
- **Validacao executada:** `flutter analyze lib/data/offline/offline_task_repository.dart lib/screens/task_list_screen.dart` + checagem de lints.
- **Resultado:** Sem erros de analise/lint; reordenacao offline deixa de interferir no fluxo arquitetural de pendencias/sync.
- **Status:** Concluido.

## 2026-04-29 - Unificacao: reordenacao somente local nos dois prototipos

- **Contexto:** Solicitado manter comportamento identico entre online/offline para reordenacao, sem envio para Firestore e sem impacto em sincronizacao.
- **Problema identificado:** Implementacao anterior persistia ordem em dados de tarefa (`sortOrder`) e no online sincronizava isso com Firestore, misturando preferencia de UI com camada arquitetural.
- **Correcao aplicada:** Reordenacao passou a ser gerenciada exclusivamente no `TaskProvider`, com persistencia local em `SharedPreferences` (`task_order_ids_v1`), aplicando ordem por lista de IDs apos cada emissao de `watchTasks`.
- **Ajustes complementares:** `reorderTasks` dos repositórios online/offline foi neutralizado (no-op) para nao escrever em Firestore/Hive; `watchTasks` voltou ao comportamento original por `createdAt`.
- **Arquivos alterados:** `lib/providers/task_provider.dart`, `lib/data/online/online_task_repository.dart`, `lib/data/offline/offline_task_repository.dart`.
- **Validacao executada:** `flutter analyze` dos arquivos alterados + checagem de lints.
- **Resultado:** Sem erros de analise/lint; reordenacao agora e puramente preferencia local de interface e igual nos dois apps.
- **Status:** Concluido.

## 2026-04-29 - Offline-first bidirecional (push + pull com referencia canônica remota)

- **Contexto:** Solicitado que o prototipo offline permaneça local-first para UX, mas que fique atualizado com o Firestore sempre que possível, tratando servidor como referencia canônica.
- **Atualizacao de especificacao:** Seção 6 de `especificacoes_tecnicas_v4.md` revisada para sincronizacao bidirecional (`Hive -> Firestore` e `Firestore -> Hive`), com `lastPullAt` persistido e fluxo completo de primeira abertura/uso normal.
- **Correcao aplicada no codigo:** `SyncService` passou a executar ciclo completo com PUSH de pendentes e PULL incremental por `updatedAt > lastPullAt` (via `Timestamp`), incluindo gravacao de `last_pull_at` em `SharedPreferences`.
- **Ajustes no repository offline:** adicionados `getById`, `createTaskFromRemote` e `updateTaskFromRemote` para merge remoto sem marcar pendente.
- **Ajustes de telemetria:** `logSyncStarted` agora aceita `isFirstSync`; `logSyncCompleted` registra `pushed`, `pulled`, `errors` e `pull_error`; `logSyncItem` recebe `direction` (`push|pull`). Sumario de exportacao passou a incluir `sync_push_success_rate` e `sync_pull_success_rate`.
- **Arquivos alterados:** `especificacoes_tecnicas_v4.md`, `lib/data/offline/sync_service.dart`, `lib/data/offline/offline_task_repository.dart`, `lib/services/telemetry_service.dart`.
- **Validacao executada:** `flutter analyze lib/data/offline/sync_service.dart lib/data/offline/offline_task_repository.dart lib/services/telemetry_service.dart` + checagem de lints.
- **Resultado:** Sem erros de analise/lint; offline-first passa a convergir com o servidor quando a sincronizacao e permitida.
- **Status:** Concluido.

## 2026-04-30 - Acesso simplificado para exportacao da telemetria

- **Contexto:** Necessidade operacional de coleta: participantes precisam exportar telemetria local e enviar ao pesquisador.
- **Problema identificado:** A funcionalidade de exportacao existia na `SettingsScreen`, mas sem atalho visivel na tela principal de tarefas.
- **Correcao aplicada:** Adicionado botao de configuracoes no `AppBar` da listagem para abrir `SettingsScreen`, onde o participante executa "Exportar dados" (gera JSON e abre compartilhamento).
- **Arquivos alterados:** `lib/screens/task_list_screen.dart`.
- **Validacao executada:** `flutter analyze lib/screens/task_list_screen.dart lib/screens/settings_screen.dart lib/services/export_service.dart` + checagem de lints.
- **Resultado:** Sem erros de analise/lint; exportacao ficou facilmente acessivel para todos os participantes.
- **Status:** Concluido.

## 2026-04-30 - Feedback de carregamento ao salvar tarefa (online/offline)

- **Contexto:** Solicitado feedback visual de carregamento ao criar/editar tarefa em ambos prototipos.
- **Problema identificado:** `TaskFormScreen` executava salvamento sem indicador de progresso, gerando percepcao de travamento durante operacoes assicronas.
- **Correcao aplicada:** Adicionado estado `_saving` no formulario, com desabilitacao de interacoes (`AbsorbPointer`), botao `Salvar` com spinner e overlay central "Salvando..." durante o processo.
- **Escopo:** Comportamento compartilhado entre online-first e offline-first (mesma tela de formulario), portanto aplicado para os dois prototipos.
- **Arquivos alterados:** `lib/screens/task_form_screen.dart`.
- **Validacao executada:** `flutter analyze lib/screens/task_form_screen.dart` + checagem de lints.
- **Resultado:** Sem erros de analise/lint; fluxo de criacao/edicao agora exibe loading consistente.
- **Status:** Concluido.

## 2026-04-30 - Feedback de carregamento ao excluir tarefa

- **Contexto:** Solicitado adicionar loading tambem na acao de exclusao para melhorar feedback ao usuario.
- **Problema identificado:** Exclusao em `TaskDetailScreen` ocorria sem indicador visual de progresso durante operacao assíncrona.
- **Correcao aplicada:** Tela de detalhes convertida para estado local de UI com flag `_deleting`; botao "Excluir" agora mostra spinner, fica desabilitado e evita acionamento duplicado enquanto a exclusao esta em andamento.
- **Arquivos alterados:** `lib/screens/task_detail_screen.dart`.
- **Validacao executada:** `flutter analyze lib/screens/task_detail_screen.dart` + checagem de lints.
- **Resultado:** Sem erros de analise/lint; exclusao agora possui feedback de carregamento consistente.
- **Status:** Concluido.

## 2026-04-30 - Delay proposital para falhas de conectividade simulada

- **Contexto:** Solicitado que operacoes que falham por simulacao de ma conexao nao retornem erro instantaneo; devem demorar para refletir timeout/instabilidade percebida.
- **Problema identificado:** Nos caminhos bloqueados do `NetworkSimulator` (`blockOnly` e bloqueio no `blockAndLatency`), o erro era lancado imediatamente.
- **Correcao aplicada:** Adicionado atraso proposital antes da excecao de bloqueio, reutilizando `AppConfig.simulatedLatencyMs` em helper interno (`_delayBeforeFailure`). Agora falhas simuladas aguardam latencia antes de retornar `OfflineException`.
- **Arquivos alterados:** `lib/services/network_simulator.dart`.
- **Validacao executada:** `flutter analyze lib/services/network_simulator.dart` + checagem de lints.
- **Resultado:** Sem erros de analise/lint; falhas de conectividade simulada agora possuem delay coerente com o experimento.
- **Status:** Concluido.

- **Problema 4:** Estrutura de pastas do `lib/` prevista no Passo 1 nao estava criada.
- **Correcao aplicada:** Criadas pastas base (`config`, `domain`, `data`, `services`, `providers`, `screens`, `widgets/common`).
- **Validacao:** Criacao confirmada no workspace.
- **Status:** Concluido.

- **Solicitacao de governanca:** Exigir registro rastreavel de toda mudanca/problema/correcao para relatorio academico.
- **Acao aplicada:** Criada regra persistente do agente em `.cursor/rules/academic-traceability.mdc` com aplicacao global (`alwaysApply: true`).
- **Validacao:** Regra criada no repositorio e pronta para uso nas proximas sessoes.
- **Status:** Concluido.

## 2026-05-12 - Especificacoes tecnicas v4.1 (app unico, controle remoto, RTDB, UI cega)

- **Tema/ID:** Atualizacao das especificacoes tecnicas conforme itens 1–5 de `mudanças.txt` (nao e log; apenas lista de requisitos).
- **Contexto:** Documento `especificacoes_tecnicas_v4.md` alinhado ao novo desenho experimental: aplicativo unico, arquitetura controlada remotamente pelo pesquisador, telemetria em Firebase Realtime Database, interface neutra ao paradigma (UI cega), questionario pos-codigo (nome, idade, genero, escolaridade), duracao de referencia 30 dias (15+15 por arquitetura sob controlo remoto).
- **Decisao aplicada:** Versao do documento elevada a 4.1; sumario com 16 secoes; nova secao 5 (controle remoto, codigos, painel); secoes e subsecoes renumeradas; telemetria especificada com envio direto ao RTDB sem passar pelo NetworkSimulator; leitura de configuracao de arquitetura fora do simulador.
- **Arquivos alterados:** `especificacoes_tecnicas_v4.md` (revisao v4.1); `mudanças.txt` (removido bloco de rastreio que nao deve constar neste ficheiro); `docs/rastreabilidade.md` (registo academico consolidado aqui).
- **Governanca de rastreio:** Registos de rastreabilidade academica ficam em `docs/rastreabilidade.md`; `mudanças.txt` permanece apenas como lista de requisitos / notas do autor.
- **Validacao executada:** Revisao estrutural do Markdown no repositorio (sem build de codigo para o documento).
- **Resultado/Status:** Concluido para a etapa "documento de especificacoes tecnicas".
- **Risco residual e proximo passo:** Implementacao Flutter/Firebase ainda pendente; regras de seguranca RTDB/Firestore a detalhar na implementacao. Opcional: propagar o desenho ao codigo e a `documentacao_arquitetura_online_offline_first.md`.

## 2026-05-12 - Implementacao do plano incremental (app unico + RTDB + UI cega)

- **Contexto:** Execucao do plano "App unico incremental" (mudancas.txt + especificacoes v4.1): um entrypoint de estudo, configuracao remota via Realtime Database, questionario apos codigo, telemetria com `architecture` por evento (fora do NetworkSimulator), dual-write Hive+RTDB, `StudySessionController`, `StudyRepositoryFactory`, remocao de flavors Android, documentacao.
- **Problema encontrado:** `flutter pub get` falhou por incompatibilidade entre `share_plus` antigo e `firebase_core_web`; atualizado `share_plus` para `^12.0.2`.
- **Correcoes de analise estatica:** Removido import nao usado em `task_detail_screen.dart`; `export_service` migrado para `SharePlus.instance.share(ShareParams(...))`; `DropdownButtonFormField` atualizado para `initialValue` + `ValueKey` em `participant_profile_screen` e `task_form_screen`.
- **Arquivos alterados (principais):** `pubspec.yaml`, `lib/main_study.dart`, `lib/main.dart`, `lib/data/study_repository_factory.dart`, `lib/data/experiment/participant_remote_config_service.dart`, `lib/providers/study_session_controller.dart`, `lib/services/telemetry_service.dart`, `lib/services/export_service.dart`, `android/app/build.gradle.kts` (incl. `ndkVersion` 28.2.13676358), `docs/firebase_rtdb_schema.md`, `firebase/database.rules.json`, `documentacao_arquitetura_online_offline_first.md`, `README.md`, ecrãs e providers associados.
- **Validacao executada:** `flutter pub get`; `flutter analyze` (sem issues); `flutter build apk --release --target lib/main_study.dart` → `build/app/outputs/flutter-apk/app-release.apk` gerado com sucesso (Gradle ~9 min na primeira corrida com downloads NDK/SDK). Ajuste `ndkVersion` para `28.2.13676358` em `android/app/build.gradle.kts` para alinhar ao requisito do plugin `jni`.
- **Risco residual:** Regras RTDB em `firebase/database.rules.json` permanecem permissivas para desenvolvimento — substituir antes de campo. Troca de `architecture` com dados locais/servidor exige politica operacional (washout/sync) acordada com o investigador.
- **Status:** Concluido (implementacao e documentacao base do plano).

## 2026-05-12 - Inicializacao Firebase (channel-error no arranque)

- **Contexto:** Crash `PlatformException(channel-error, Unable to establish connection on channel)` em `Firebase.initializeApp` (Android).
- **Hipotese:** Acesso a `Firebase.apps` antes de `initializeApp` instancia o MethodChannel cedo demais; em alguns dispositivos o canal ainda nao esta pronto.
- **Correcao:** Helper `ensureFirebaseInitialized()` em `lib/utils/ensure_firebase.dart` chama apenas `Firebase.initializeApp` e trata app duplicado; removidos `Firebase.apps.isEmpty` em `main_study.dart`; `Duration.zero` apos `WidgetsFlutterBinding.ensureInitialized()`; Firebase garantido antes de `Hive.initFlutter()` em `_bootstrapWithParticipantId`.
- **Validacao:** `flutter analyze`.
- **Revalidacao (channel-error persistente):** `Firebase.initializeApp` continuava a falhar no arranque; o fluxo passou a usar [runApp] com ecra minimo e `addPostFrameCallback` antes de `ensureFirebaseInitialized()` e `_continueStudyStartup()` (`_StudyAppEntry` em `main_study.dart`).
- **Status:** Concluido.

- **Contexto:** Pedido para editar participantes, arquitetura, encerrar app/telemetria e exportar telemetria a partir da propria app em debug (`mudanças.txt` linhas 9-14), com seed automatico do RTDB vazio.
- **Decisao:** Build **debug** = sessao fixa `P000` sem onboarding; `AdminRtdbBootstrap.ensureSeed` cria `study_config` e `participants/P000`; botao na AppBar de `TaskListScreen` abre fluxos em `lib/screens/admin/`. Criacao de participantes escreve `participants/P###` com perfil minimo. Exportacoes leem `telemetry/{id}` e filtram pelo campo `architecture` de cada evento.
- **Arquivos novos/alterados:** `lib/config/debug_admin.dart`, `lib/data/experiment/admin_rtdb_bootstrap.dart`, `lib/data/experiment/admin_study_remote_service.dart`, `lib/main_study.dart`, `lib/screens/task_list_screen.dart`, `lib/screens/admin/*.dart`, `docs/firebase_rtdb_schema.md`, `README.md`.
- **Validacao:** `flutter analyze` sem issues.
- **Risco residual:** Painel nao deve ser acessivel em release (depende de `kDebugMode`); dados Hive locais em debug sao partilhados entre sessoes se o ID mudar manualmente. Regras RTDB em producao devem impedir que clientes nao autenticados escrevam em `participants/*` (hoje o painel assume regras permissivas de desenvolvimento).
- **Status:** Concluido.

## 2026-05-13 - Limpeza Android: remocao de artefatos dos flavors online/offline

- **Contexto:** O desenho atual e um unico binario (`main_study.dart`); `android/app/build.gradle.kts` ja nao declara `productFlavors`, mas permaneciam pastas de source set e clientes Firebase para pacotes `.online` / `.offline`.
- **Decisao:** Remover `android/app/src/online/` e `android/app/src/offline/` (apenas `google-services.json` por flavor) e reduzir `android/app/google-services.json` ao unico cliente com `package_name` `br.edu.icev.task_manager_study`, alinhado ao `applicationId` atual e a `lib/config/firebase_options.dart`.
- **Arquivos alterados:** `android/app/google-services.json`; removidos `android/app/src/online/google-services.json`, `android/app/src/offline/google-services.json` e diretorios vazios correspondentes.
- **Validacao executada:** `flutter build apk --debug` (sem `--flavor`).
- **Risco residual:** Apps Android antigos instalados com IDs `.online` / `.offline` deixam de receber atualizacoes por este APK (IDs diferentes); participantes devem usar o pacote base.
- **Status:** Concluido apos build bem-sucedido.

## 2026-05-13 - channel-error no Firebase: inicializacao antes de runApp

- **Contexto:** Crash `PlatformException(channel-error, Unable to establish connection on channel)` em `Firebase.initializeApp` ao arranque (stack em `main.dart`).
- **Causa:** `Firebase.initializeApp` estava a ser chamado em `main()` **antes** de `runApp`, enquanto o proprio ficheiro ja documentava que nalguns dispositivos Android o pigeon `FirebaseCoreHostApi` nao esta pronto; alinhado a relatos em [flutterfire#9411](https://github.com/firebase/flutterfire/issues/9411) e [flutter#176337](https://github.com/flutter/flutter/issues/176337).
- **Correcao:** `main()` passa apenas a `WidgetsFlutterBinding.ensureInitialized()` + `runApp(_StudyAppEntry)`; `_ensureFirebaseInitialized()` corre no `addPostFrameCallback` antes de `_continueStudyStartup()`, com `Duration.zero`, tratamento de `duplicate-app` e **reintentos** com backoff curto em `PlatformException` `channel-error` (canal nativo ainda nao pronto em alguns dispositivos).
- **Arquivos alterados:** `lib/main.dart`, `docs/rastreabilidade.md`.
- **Validacao:** `flutter analyze lib/main.dart` sem issues.
- **Risco residual:** Se o erro persistir em builds especificos, considerar `flutter clean`, alinhamento de versoes `firebase_core`/Gradle e atualizacao do plugin conforme issues fechados no FlutterFire.
- **Status:** Concluido (correcao de codigo); revalidacao em dispositivo fisico fica a cargo do ambiente.

## 2026-05-14 - Icone de notificacao Android (quadrado preto)

| Campo | Conteudo |
|--------|-----------|
| **ID / tema** | Corrigir small icon da notificacao (artefacto preto) |
| **Contexto** | Uso de `ic_launcher_foreground` (PNG colorido) como small icon. |
| **Causa** | Android aplica tint ao small icon; exige silhueta monocromatica. |
| **Decisao** | Vector `drawable/ic_stat_notify.xml` (branco + alpha); `largeIcon` com recurso colorido do launcher. |
| **Arquivos alterados** | `android/app/src/main/res/drawable/ic_stat_notify.xml`, `lib/services/notification_service.dart`. |
| **Validacao** | `flutter analyze` no servico de notificacoes. |
| **Risco residual** | Small icon na barra e silhueta; marca colorida no painel expandido via `largeIcon`. |
| **Status** | Concluido. |

## 2026-05-14 - Painel admin: dias online/offline e inicio do experimento

| Campo | Conteudo |
|--------|-----------|
| **ID / tema** | Dias por modo desde entrada no experimento; campos nao editaveis |
| **Contexto** | Dias eram referencia manual; `study_started_at` na criacao admin. |
| **Causa** | Sem contagem automatica nem linha temporal de arquitetura. |
| **Decisao** | `study_started_at` na primeira ligacao; `architecture_timeline`; contagem diaria UTC (`participant_phase_day_tally.dart`); UI admin so leitura; `updateArchitecture` regista mudanca no timeline. |
| **Arquivos alterados** | `lib/data/experiment/participant_phase_day_tally.dart` (novo), `participant_remote_config_service.dart`, `participant_study_config.dart`, `study_session_controller.dart`, `main.dart`, `participant_loader.dart`, `admin_study_remote_service.dart`, `admin_rtdb_bootstrap.dart`, `admin_participant_detail_screen.dart`. |
| **Validacao** | `flutter analyze lib`. |
| **Risco residual** | Participantes legacy com `study_started_at` antigo mantem essa ancora. |
| **Status** | Concluido. |

## 2026-05-14 - Mudanca remota de arquitetura e continuidade de dados (online/offline)

| Campo | Conteudo |
|--------|-----------|
| **ID / tema** | Refletir arquitetura RTDB sem reiniciar app; Hive espelhar Firestore |
| **Contexto** | Poll longo; pull incremental; sem flush Hive ao voltar a online-first. |
| **Decisao** | Listener RTDB `participants/{id}`; fila serial de `refreshRemoteConfig`; poll 30s; `CrossArchitectureTaskBridge.flushPendingToFirestore` ao sair de offline-first; guard em `_applyFirestorePersistence`; criacao `checkPushToRemoteAllowed` (evolucao posterior no SyncService). |
| **Arquivos alterados** | `lib/providers/study_session_controller.dart`, `lib/main.dart`, `lib/data/experiment/cross_architecture_task_bridge.dart` (novo), `lib/services/network_simulator.dart`. |
| **Validacao** | `flutter analyze lib`. |
| **Risco residual** | `Firestore.settings` so deve mudar quando necessario. |
| **Status** | Concluido. |

## 2026-05-14 - Sync imediato apos mutacao local (offline-first)

| Campo | Conteudo |
|--------|-----------|
| **ID / tema** | Tentar sync logo apos criar/editar/apagar tarefa local |
| **Contexto** | Apenas timer periodico; atraso ate 30s para push. |
| **Decisao** | `offline_mutation_sync_trigger.dart` + `bind`/`unbind` no `SyncService`; chamadas no `OfflineTaskRepository`. |
| **Arquivos alterados** | `lib/data/offline/offline_mutation_sync_trigger.dart`, `lib/data/offline/sync_service.dart`, `lib/data/offline/offline_task_repository.dart`. |
| **Validacao** | `flutter analyze lib/data/offline`. |
| **Status** | Concluido. |

## 2026-05-14 - Offline-first alinhado a especificacao (referencia remota + simulador)

| Campo | Conteudo |
|--------|-----------|
| **ID / tema** | Pull para convergencia; simulador so no push (YAML 486-497) |
| **Contexto** | `checkSyncAllowed` bloqueava pull inteiro em degradacao; pull incremental podia omitir documentos. |
| **Decisao** | `checkPushToRemoteAllowed` (push bloqueado se degradado); pull sempre com `_col.get()` completo; LWW `remote.updatedAt >= local` para copia `synced`; pendentes/deleted/error nao sobrescritos; timer 15s; `checkSyncAllowed` deprecado. |
| **Arquivos alterados** | `lib/services/network_simulator.dart`, `lib/data/offline/sync_service.dart`. |
| **Validacao** | `flutter analyze lib`. |
| **Risco residual** | `get()` em colecoes muito grandes; deletes so remotos exigem politica de tombstones (nao coberto aqui). |
| **Status** | Concluido. |

## 2026-05-14 - Pull: tarefas do Firestore em falta na lista local

| Campo | Conteudo |
|--------|-----------|
| **ID / tema** | Nem todas as tarefas remotas apareciam no offline-first |
| **Causa** | `Task.fromFirestore` com casts rigidos (ex.: `priority` como double); excecao abortava o lote do pull. |
| **Decisao** | Parsing defensivo em `Task.fromFirestore`; try/catch por documento no pull do `SyncService`. |
| **Arquivos alterados** | `lib/domain/models/task.dart`, `lib/data/offline/sync_service.dart`. |
| **Validacao** | `flutter analyze` nos ficheiros alterados. |
| **Status** | Concluido. |

## 2026-05-18 - Validacao de nome no questionario pos-codigo

| Campo | Conteudo |
|--------|-----------|
| **ID / tema** | Conferir nome do formulario com cadastro RTDB |
| **Contexto** | Participante informa codigo e depois questionario; o nome deve ser o atribuido no cadastro. |
| **Decisao** | Comparacao normalizada (trim, minusculas, espacos); validacao no formulario e revalidacao no envio; se divergir, volta ao ecra do codigo com mensagem; `profileComplete` ignora perfis `admin-provisioned`; criacao admin grava apenas `display_name` (sem questionario placeholder). |
| **Arquivos alterados** | `lib/utils/participant_name_match.dart` (novo), `lib/domain/models/participant_study_config.dart`, `lib/main.dart`, `lib/screens/participant_profile_screen.dart`, `lib/data/experiment/admin_study_remote_service.dart`, `docs/rastreabilidade.md`. |
| **Validacao** | `flutter analyze` nos ficheiros alterados. |
| **Risco residual** | Participantes RTDB antigos com `admin-provisioned` precisam preencher o questionario de novo; sem `display_name` nao ha verificacao de nome. |
| **Status** | Concluido. |

## 2026-05-18 - Comentarios de impressao imediata (Firestore)

| Campo | Conteudo |
|--------|-----------|
| **ID / tema** | Botao na AppBar para comentarios do participante |
| **Contexto** | Participantes devem relatar impressoes do app quando quiserem. |
| **Decisao** | Icone entre recarregar e configuracoes; folha modal com texto; gravacao em `participants/{id}` campo `immediate_impressions` (array com `id`, `text`, `createdAt`, `architecture`, `studyDay`); `NetworkSimulator.intercept` e telemetria alinhados ao resto do app. |
| **Arquivos alterados** | `lib/data/participant_impression_service.dart` (novo), `lib/widgets/participant_impression_sheet.dart` (novo), `lib/screens/task_list_screen.dart`, `docs/rastreabilidade.md`. |
| **Validacao** | `flutter analyze` nos ficheiros alterados sem issues. |
| **Risco residual** | Painel admin ainda nao lista comentarios; offline-first depende de persistencia Firestore para envio diferido. |
| **Status** | Concluido. |

## 2026-05-18 - Lembretes de engajamento (14 notificacoes a cada 2 dias)

| Campo | Conteudo |
|--------|-----------|
| **ID / tema** | Agendar lembretes amigaveis apos primeira identificacao do participante |
| **Contexto** | Pedido para lembrar o uso do app durante o estudo, sem depender de tarefas criadas. |
| **Causa** | Apenas existiam notificacoes ligadas a lembretes de tarefas. |
| **Decisao** | `scheduleEngagementRemindersIfNeeded()` em `NotificationService`: 14 notificacoes locais, intervalo de 2 dias, primeira as 10:00 locais (dia 2, 4, …, 28); canal Android dedicado; flag `engagement_reminders_scheduled_v1` em SharedPreferences; chamada no bootstrap apos onboarding (omitida em `kDebugMode`). |
| **Arquivos alterados** | `lib/services/notification_service.dart`, `lib/main.dart`, `docs/rastreabilidade.md`. |
| **Validacao** | `flutter analyze lib/services/notification_service.dart lib/main.dart` sem issues. |
| **Risco residual** | Reinstalacao do app reagenda lembretes; utilizador sem permissao de notificacoes nao recebe (flag nao e gravada se zero agendamentos). |
| **Status** | Concluido. |

## 2026-06-06 - Importacao de questionarios em TXT (JSON)

| Campo | Conteudo |
|--------|-----------|
| **ID / tema** | Aceitar arquivos `.txt` com JSON na importacao de questionarios |
| **Contexto** | Alguns participantes podem enviar respostas em `.txt` em vez de `.json`. |
| **Causa** | Seletor de arquivos aceitava apenas extensao `json`. |
| **Decisao** | `allowedExtensions` passa a incluir `txt`; leitura normaliza BOM UTF-8 e trim antes do parse; textos da UI atualizados. |
| **Arquivos alterados** | `lib/screens/admin/admin_questionnaire_import_screen.dart`, `docs/rastreabilidade.md`. |
| **Validacao** | `flutter analyze` no arquivo alterado. |
| **Risco residual** | Arquivo `.txt` sem JSON valido continua rejeitado na pre-visualizacao. |
| **Status** | Concluido. |

## 2026-06-06 - Importacao de questionarios subjetivos T1/T2 no painel admin

| Campo | Conteudo |
|--------|-----------|
| **ID / tema** | Importacao admin de JSON dos questionarios HTML (T1/T2) |
| **Contexto** | Participantes respondem `questionario_T1.html` e `questionario_T2.html` e enviam arquivos `respostas_T1_*.json` / `respostas_T2_*.json`; o investigador precisa carregar e persistir no RTDB para analise, identificando participante e arquitetura vigente no periodo. |
| **Causa** | Nao existia fluxo no app investigador para ingestao desses JSON. |
| **Decisao** | Parser `SubjectiveQuestionnairePayload` valida `meta.instrument`, periodo T1/T2 e blocos obrigatorios; `AdminStudyRemoteService.importSubjectiveQuestionnaire` grava em `participants/{id}/subjective_questionnaires/{T1|T2}` com metadados `assigned_architecture` e `architecture_during_period` (T1 = arquitetura cadastrada; T2 = fase oposta); tela `AdminQuestionnaireImportScreen` com selecao multipla via `file_picker`; status T1/T2 no detalhe do participante. |
| **Arquivos alterados** | `lib/domain/models/subjective_questionnaire_payload.dart`, `lib/data/experiment/admin_study_remote_service.dart`, `lib/screens/admin/admin_questionnaire_import_screen.dart`, `lib/screens/admin/admin_participants_screen.dart`, `lib/screens/admin/admin_participant_detail_screen.dart`, `docs/firebase_rtdb_schema.md`, `docs/rastreabilidade.md`, `pubspec.yaml` (dependencia `file_picker`). |
| **Validacao** | `flutter analyze` nos arquivos alterados (sem erros apos ajuste API `FilePicker.pickFiles`). |
| **Risco residual** | Teste em dispositivo real com arquivos JSON reais e regras RTDB de producao; reimportacao substitui registro anterior sem historico de versoes. |
| **Status** | Concluido (pendente validacao manual em dispositivo com Firebase). |

## 2026-06-30 - Taxa efetiva de conclusão e evidência objetiva de H2

| Campo | Conteudo |
|--------|-----------|
| **ID / tema** | `effective_completion_rate` e bloqueios como métricas objetivas de H2 |
| **Contexto** | `operation_success_rate` ficava em 100% para ambas arquiteturas (bloqueios não entram no denominador); discussão acadêmica de que bloqueios por rede refletem confiabilidade operacional (H2), não só usabilidade (H1). |
| **Decisao** | Em `metrics.py`: `effective_completion_rate = sucesso / (completed + blocked)` e `total_attempts`; em `analyze_full_study.py`: Wilcoxon de `effective_completion_rate` e `operations_blocked_total` na secção H2; nota em H1 sobre limitação da taxa de sucesso restrita; gráfico inferior esquerdo passa a exibir taxa efetiva. |
| **Arquivos alterados** | `analysis/metrics.py`, `analysis/analyze_full_study.py`, `analysis/README.md`, `docs/rastreabilidade.md`. |
| **Validacao** | `python -m py_compile` OK. `python analyze_full_study.py` contra RTDB real: taxa efetiva online M=0,623 vs offline M=1,000 (Wilcoxon p=0,0003, r=0,772); bloqueios online M=15,3 vs offline M=0,0 (p=0,0003, r=0,773). |
| **Status** | Concluido. |

## 2026-06-30 - Script de analise completa do estudo (H1/H2) a partir do RTDB

| Campo | Conteudo |
|--------|-----------|
| **ID / tema** | `analysis/analyze_full_study.py` — pipeline completo de analise estatistica puxando dados direto do RTDB |
| **Contexto** | Pedido para tratar todos os dados ja gravados (cadastro, questionarios subjetivos T1/T2 e telemetria) e analisar com base na proposta do projeto (hipoteses H1/H2 da secao 1.2 e metodologia da secao 13.2 de `especificacoes_tecnicas_v4 (1).md`). Decisao previa do usuario: script Python, acesso via REST API do RTDB sem credenciais (regras de leitura assumidas abertas). |
| **Causa** | Nao existia pipeline automatizado; a secao 13.2 do documento tecnico assumia agregacao manual previa em arquivos `analytics_*.json`. |
| **Decisao** | Criados `analysis/fetch_data.py` (REST `participants.json`/`telemetry.json`, exclui `P000`), `analysis/domain.py` (recalcula `architecture_during_period` via `architecture_timeline` + `study_started_at` + `submitted_at`, espelhando `lib/data/experiment/participant_phase_day_tally.dart`; emite aviso quando o valor recalculado diverge do gravado na importacao), `analysis/metrics.py` (SUS por Brooke 1996; `reliability_technical`/`reliability_trust`/`context` com reversao de itens via `reverse_items` do proprio payload; agregacao de telemetria: taxa de sucesso, bloqueios, atrasos, abandono, sync push/pull, `avg_pending_to_sync_ms`, breakdown diario) e `analysis/analyze_full_study.py` (orquestracao: monta DataFrames, pareia por `architecture_during_period` — nunca `assigned_architecture`, executa Wilcoxon pareado + efeito *r* para H1 [SUS, taxa de sucesso, taxa de abandono] e H2 [confianca, estabilidade percebida], reporta efeito de ordem como analise secundaria, gera `metrics_by_participant.csv`, `hypothesis_tests.md` e `results.png`). |
| **Arquivos alterados** | `analysis/fetch_data.py`, `analysis/domain.py`, `analysis/metrics.py`, `analysis/analyze_full_study.py`, `analysis/requirements.txt`, `analysis/README.md`, `.gitignore` (ignora `analysis/output/`), `docs/rastreabilidade.md`. |
| **Validacao** | `python -m py_compile analysis/*.py` sem erros. Dependencias instaladas via `pip install -r analysis/requirements.txt` (ambiente ja tinha pandas/scipy/matplotlib/seaborn/requests; instalado `tabulate` adicional). Smoke test local com dados sinteticos (2 participantes, T1/T2, telemetria mista) executado via mock de `fetch_participants`/`fetch_telemetry`: conferencia manual da formula de Brooke (SUS=50 no caso neutro, 100 no melhor caso, 0 no pior caso) e da reversao de itens Likert; pipeline completo gerou os 3 artefatos (`metrics_by_participant.csv`, `hypothesis_tests.md`, `results.png`) sem erro; o aviso de inconsistencia de `architecture_during_period` disparou corretamente para o caso proposital de divergencia. Teste contra o RTDB real (`https://tcc-task-manager-82e52-default-rtdb.firebaseio.com/.json`) via `curl.exe` confirmou HTTP 200 em ~10s, validando que as regras de leitura estao abertas e o endpoint responde. |
| **Risco residual** | A execucao do script via `python`/`requests` *neste ambiente de execucao do agente* (sandbox) apresentou resolucao de DNS anormalmente lenta (~4 minutos por requisicao, nao respeitando o parametro `timeout` da biblioteca `requests`, que nao cobre a fase de `getaddrinfo`), enquanto `curl.exe` resolveu em ~10s — isso e uma particularidade de rede do sandbox, nao um defeito no codigo; em uma maquina normal (a do pesquisador) o script deve rodar em segundos. Fica pendente uma execucao real feita pelo usuario fora do sandbox para confirmar dados reais de participantes. REST sem credenciais deixa de funcionar se as regras do RTDB forem restritas antes da coleta real — nesse caso o script precisa ser adaptado para Firebase Admin SDK. |
| **Status** | Concluido e validado com dados sinteticos; pendente apenas execucao do usuario contra o RTDB real fora do sandbox do agente. |

## 2026-07-12 - Relatorio completo da analise H1/H2 (documento interpretativo)

- **Contexto:** Com resultados da reexecucao do pipeline (28 participantes; 20 pares subjetivos; 23 pares objetivos) e apos esclarecimento/correcao das inconsistencias P006/P016, o usuario pediu um documento detalhado cobrindo objetivo, metodo, problemas, solucoes, estatisticas, interpretacoes, achados secundarios, limitacoes e melhorias futuras.
- **Decisao:** Criado `analysis/relatorio_completo_estudo.md` consolidando a narrativa academica a partir de `analysis/output/hypothesis_tests.md` e do historico da sessao (importacao de questionarios, taxa efetiva de conclusao, avisos de `architecture_during_period`).
- **Arquivos alterados:** `analysis/relatorio_completo_estudo.md`, `docs/rastreabilidade.md`.
- **Validacao:** Conteudo cruzado com `hypothesis_tests.md` (SUS p=0.3243; taxa efetiva p=0.0001; bloqueios p=0.0001; contexto p=0.0477; aviso residual P016).
- **Status:** Concluido.
- **Risco residual:** Se novos questionarios forem importados e a analise reexecutada, as tabelas do relatorio interpretativo precisam ser atualizadas manualmente para acompanhar `hypothesis_tests.md`.

| Campo | Conteudo |
|--------|-----------|
| **ID / tema** | `analysis/relatorio_completo_estudo.md` — documento interpretativo completo da analise do estudo |
| **Contexto** | Pedido de consolidacao: objetivo inicial, como foi feito, problemas/solucoes, resultados estatisticos, interpretacoes, conclusoes, observacoes ramificadas, limitacoes e melhorias para pesquisa avancada |
| **Causa** | Existiam artefatos automaticos (`hypothesis_tests.md`, CSV, PNG) e historico tecnico, mas faltava um unico documento narrativo adequado ao capitulo de resultados/discussao |
| **Decisao** | Relatorio em Markdown cobrindo H1/H2 (subjetivo+objetivo), taxa efetiva, P006/P016, efeito de ordem, sync, engajamento, limitacoes e roadmap de pesquisa |
| **Arquivos alterados** | `analysis/relatorio_completo_estudo.md`, `docs/rastreabilidade.md` |
| **Validacao** | Cruzamento numerico com `analysis/output/hypothesis_tests.md` da execucao mais recente |
| **Risco residual** | Dessincronia futura se a analise for reexecutada sem atualizar o relatorio interpretativo |
| **Status** | Concluido |

## 2026-07-22 - Desativar app em massa no painel admin

- **Contexto:** Pedido de botao no painel do investigador para desativar o app para todos os participantes de uma vez (encerrar estudo / bloquear uso).
- **Causa:** So existia desativacao individual via `app_enabled` no detalhe do participante; builds em campo ja observam esse campo, mas nao havia acao em lote.
- **Decisao:** Novo metodo `AdminStudyRemoteService.setAllAppsEnabled` faz update multi-path de `participants/{id}/app_enabled`. Botao na AppBar de `AdminParticipantsScreen` com dialogo de confirmacao. `P000` fica de fora por omissao para o investigador nao perder acesso ao painel.
- **Arquivos alterados:** `lib/data/experiment/admin_study_remote_service.dart`, `lib/screens/admin/admin_participants_screen.dart`, `docs/firebase_rtdb_schema.md`, `docs/rastreabilidade.md`.
- **Validacao:** `flutter analyze` nos ficheiros alterados.
- **Status:** Concluido (pendente validacao manual no RTDB real).
- **Risco residual:** Participantes so refletem a mudanca apos o listener/poll de config remota (ate ~30s ou ao retomar o app). Nao ha botao simetrico de "reativar todos" (reativacao continua individual).

| Campo | Conteudo |
|--------|-----------|
| **ID / tema** | Desativacao global do app via painel admin (`setAllAppsEnabled`) |
| **Contexto** | Encerrar o estudo / bloquear o app para todos os participantes de uma vez |
| **Causa** | Apenas toggle individual de `app_enabled`; falta de acao em massa |
| **Decisao** | Bulk update RTDB de `app_enabled=false` (exceto P000) + botao destrutivo com confirmacao |
| **Arquivos alterados** | `admin_study_remote_service.dart`, `admin_participants_screen.dart`, `firebase_rtdb_schema.md`, `rastreabilidade.md` |
| **Validacao** | `flutter analyze` nos arquivos alterados |
| **Risco residual** | Latencia de propagacao no cliente; reativacao so individual |
| **Status** | Concluido |

## 2026-07-27 - Analises pendentes (lacunas da revisao do artigo)

- **Contexto:** Revisao do artigo identificou quatro lacunas: alfa de Cronbach das escalas proprias, demografia (comentario 22), atrito 28->23->20 nao discutido como ameaca a validade, e bloco comparativo bipolar do T2 nunca reportado. Script-base fornecido pelo usuario; adaptado ao esquema real do RTDB/questionarios.
- **Causa:** Pipeline original (`analyze_full_study.py`) calculava escores agregados e Wilcoxon H1/H2, mas nao reportava consistencia interna item-a-item, demografia, atrito diferencial por ordem, nem o comparativo 1o vs 2o app com recodificacao.
- **Decisao:** Criado `analysis/analyze_pending_gaps.py` com CONFIG alinhado a `questionario_*.html` (`sus*`, `tf*`, `cs*`, `ctx*`, `comp*`); REVERSOS preenchidos (`tf2/4/6/8`, `cs4`, `ctx4`); demografia de `profile_questionnaire` (age/gender/education); atrito com `assigned_architecture` + Fisher; comparativo T2 recodificado (positivo = offline-first); Wilcoxon detalhado com n nao-empatados. Resultados incorporados em `relatorio_completo_estudo.md` (§6.6, §11, limitacoes, r atualizados).
- **Arquivos alterados:** `analysis/analyze_pending_gaps.py` (novo), `analysis/relatorio_completo_estudo.md`, `analysis/README.md`, `docs/rastreabilidade.md`.
- **Validacao:** `python analyze_pending_gaps.py` contra RTDB real — exit 0; artefatos em `analysis/output/pending_gaps_report.md`, `cronbach_alphas.csv`, `comparative_bipolar.csv`, `questionarios_flat.csv`.
- **Resultados-chave:** SUS α(T1)=0,695; confianca α(T1)=0,924; atrito diferencial Fisher p=0,0302 (online-first 38,9% vs offline-first 0%); comparativo T2 todos nao-sig. (leve inclinacao online); r objetivo ~0,88 com n efetivo=19.
- **Status:** Concluido.
- **Risco residual:** Area de formacao / familiaridade tecnica ainda ausentes (formulario retroativo recomendado); atrito diferencial significativo precisa entrar no corpo da 5.5.1; contexto α(T2)=0,574 limita uso como escala somada no T2.

## 2026-07-27 - Correcao: amostra analitica so T1+T2

- **Contexto:** Usuario esclareceu que quem so respondeu um periodo nao entra na pesquisa (nao terminou o estudo).
- **Problema:** A primeira execucao de `analyze_pending_gaps.py` incluia P031 e P036 (so T1) no alfa (T1 n=23) e na demografia (n=23). Comparativo T2 ja estava correto (n=21). Wilcoxon subjetivo ja exigia pares nas duas arquiteturas (n=20).
- **Decisao:** Filtro `participantes_completos` / `filtrar_completos`: alfa, demografia, comparativo e Wilcoxon usam so T1+T2; incompletos entram apenas no funil de atrito. Reexecucao: demografia n=21; alfa T1 n=21; H2 objetiva n=21 (p=0,0003). Relatorio §11 atualizado.
- **Arquivos alterados:** `analysis/analyze_pending_gaps.py`, `analysis/relatorio_completo_estudo.md`, `docs/rastreabilidade.md`.
- **Validacao:** Reexecucao RTDB exit 0; console lista excluídos P031, P036.
- **Status:** Concluido.

| Campo | Conteudo |
|--------|-----------|
| **ID / tema** | Filtro de elegibilidade T1+T2 nas analises pendentes |
| **Contexto** | Criterio do protocolo: incompletos nao entram nos testes |
| **Causa** | Primeira versao usava qualquer questionario para alfa/demografia |
| **Decisao** | Completos apenas; atrito mantem funil completo |
| **Arquivos alterados** | `analyze_pending_gaps.py`, `relatorio_completo_estudo.md`, `rastreabilidade.md` |
| **Validacao** | Reexecucao; n=21 nas tabelas analiticas |
| **Risco residual** | `analyze_full_study.py` ainda reporta H2 objetiva com 23 pares de telemetria (sem exigir questionario); sensibilidade T1+T2 = 21 pares, mesmo sentido |
| **Status** | Concluido |

## 2026-07-27 - Filtro T1+T2 tambem em analyze_full_study.py

- **Contexto:** Usuario pediu alinhar as analises ja existentes ao criterio "so quem fez T1 e T2".
- **Causa:** H2 objetiva usava 23 pares de telemetria, incluindo P001 (sem questionario) e P036 (so T1).
- **Decisao:** `participantes_completos_t1_t2` + filtro em subjective/objective/daily antes dos Wilcoxon; relatorio automatico declara amostra analitica. Reexecucao: H2 objetiva n=21, p=0,0003, M online taxa efetiva=0,559, bloqueios M=17,381. Subjetivo inalterado (n=20).
- **Arquivos alterados:** `analysis/analyze_full_study.py`, `analysis/relatorio_completo_estudo.md`, `analysis/README.md`, `docs/rastreabilidade.md`; artefatos regenerados em `analysis/output/`.
- **Validacao:** `python analyze_full_study.py` exit 0; hypothesis_tests.md com amostra 21 e exclusao de incompletos.
- **Status:** Concluido.

| Campo | Conteudo |
|--------|-----------|
| **ID / tema** | Elegibilidade T1+T2 em `analyze_full_study.py` |
| **Contexto** | Alinhar H1/H2 ao protocolo (estudo completo) |
| **Causa** | Objetivo nao exigia questionarios |
| **Decisao** | Filtrar telemetria/questionarios aos 21 completos |
| **Arquivos alterados** | `analyze_full_study.py`, `relatorio_completo_estudo.md`, `README.md`, `rastreabilidade.md` |
| **Validacao** | Reexecucao RTDB; n objetivo 21, p=0,0003 |
| **Risco residual** | Nenhum material — H2 continua significativa |
| **Status** | Concluido |

## 2026-07-27 - P016 incluida no subjetivo (semantica de fase)

- **Contexto:** P016 usou offline-first por ~20 dias, mas T1 foi enviado 4 min apos a troca para online; o recálculo por `submitted_at` marcava T1 e T2 como online e a excluía dos pares subjetivos.
- **Decisao:** `domain.py` passa a priorizar `architecture_during_period` (fase). Recálculo por submit fica como fallback + aviso `warn_submit_vs_phase`. P016: T1=offline, T2=online.
- **Arquivos alterados:** `analysis/domain.py`, `analyze_full_study.py`, `analyze_pending_gaps.py`, `relatorio_completo_estudo.md`, `docs/rastreabilidade.md`; artefatos regenerados.
- **Validacao:** Reexecucao — SUS/confiança/estabilidade/contexto com **21** pares; P016 no pivot; p SUS inalterado (0,3243); H2 objetiva inalterada (n=21, p=0,0003).
- **Status:** Concluido.

| Campo | Conteudo |
|--------|-----------|
| **ID / tema** | Inclusao P016 no pareamento subjetivo |
| **Contexto** | Questionario T1 atrasado vs troca de arquitetura |
| **Causa** | Pareamento usava instante do submit, nao a fase |
| **Decisao** | Priorizar `architecture_during_period` |
| **Arquivos alterados** | `domain.py`, scripts de analise, relatorio, rastreabilidade |
| **Validacao** | 21 pares SUS; P016 T1=offline / T2=online |
| **Risco residual** | Se importacao gravar fase errada, o erro prevalece (mitigar na importacao admin) |
| **Status** | Concluido |

## 2026-07-27 - Correcao start_architecture (era T2, nao T1)

- **Contexto:** Usuario verificou que `start_architecture` coincidia com T2 em 21/21 e com T1 em 0/21.
- **Causa:** `assigned_architecture` esta vazio no RTDB; o fallback era `architecture` corrente, que ao fim do estudo = fase atual = T2. Isso **invertia** a recodificacao do comparativo bipolar e o teste de atrito diferencial (Fisher p=0,030 era artefato).
- **Decisao:** `resolve_start_architecture` em `domain.py` usa a 1ª entrada de `architecture_timeline` (21/21 = T1). Reexecucao: Fisher p=0,3955 (sem atrito diferencial); comparativo com todas as M > 0 (favor offline); preferencia 6 offline / 3 online / 12 indiferente.
- **Arquivos alterados:** `analysis/domain.py`, `analyze_pending_gaps.py`, `relatorio_completo_estudo.md`, `README.md`, `docs/rastreabilidade.md`; `pending_gaps_report.md` regenerado.
- **Validacao:** Sanity `start_architecture == T1` = 21/21 no console.
- **Status:** Concluido.

| Campo | Conteudo |
|--------|-----------|
| **ID / tema** | Correcao da ordem de exposicao (timeline vs architecture corrente) |
| **Contexto** | Auditoria do usuario: start batia com T2 |
| **Causa** | Fallback para campo corrente apos estudo completo |
| **Decisao** | 1ª entrada da timeline como start; relatorio/comparativo/atrito corrigidos |
| **Arquivos alterados** | `domain.py`, `analyze_pending_gaps.py`, relatorio, README, rastreabilidade |
| **Validacao** | 21/21 alinhado a T1; Fisher e comparativo regenerados |
| **Risco residual** | Participantes sem timeline cairiam no fallback corrente |
| **Status** | Concluido |

## 2026-07-27 - Geracao de figuras do TCC

- **Contexto:** Usuario pediu geracao das figuras listadas para Cap. 3/4 (exceto capturas reais dos prototipos).
- **Decisao:** Criado `analysis/generate_figures.py` gerando 8 PNGs em `analysis/output/figures/` a partir do RTDB + artefatos: arquiteturas, boxplot taxa efetiva, barras comparativo T2, funil 40→28→21, linha do tempo + janelas, latencia sync em log, boxplot SUS, engajamento semanal.
- **Arquivos alterados:** `analysis/generate_figures.py` (novo), `analysis/output/figures/*`, `analysis/README.md`, `docs/rastreabilidade.md`.
- **Validacao:** Script exit 0; 8 PNGs + README na pasta figures; legenda do comparativo corrigida (M>0 = offline).
- **Bloqueio externo:** Figura 02 (capturas lado a lado) exige screenshots reais do APK — nao gerada.
- **Status:** Concluido (parcial quanto as capturas).

| Campo | Conteudo |
|--------|-----------|
| **ID / tema** | Figuras Cap. 3/4 via `generate_figures.py` |
| **Contexto** | Material visual para monografia |
| **Causa** | Resultados existiam em tabela/prosa sem figuras dedicadas |
| **Decisao** | Script matplotlib + dados RTDB; 8/9 figuras |
| **Arquivos alterados** | `generate_figures.py`, `output/figures/`, `README.md`, `rastreabilidade.md` |
| **Validacao** | Execucao com 8 PNGs gerados |
| **Risco residual** | Capturas reais pendentes; tipografia DejaVu (sem tipografia institucional) |
| **Status** | Parcial (falta figura 02) |

## 2026-07-27 - Latencia por evento + qualificacao da simetria de degradacao

- **Contexto:** Usuario apontou (1) divergencia figura vs texto de latencia (evento vs media por participante) e (2) camada por volume na fig. 06 nao documentada, com duvida sobre simetria no offline-first.
- **Causa:** Texto usava `avg_pending_to_sync_ms` (media de medias); figura usava `pending_duration_ms` por `sync_item`. Volume so avanca em `intercept()`; offline push so consulta `isDegraded` via `checkPushToRemoteAllowed`, sem incrementar contador; pull nao e simulado.
- **Decisao:** Adotar **evento** como unidade primaria (n=386; mediana 0,23 s; media ~1,95 h). Relatorio §6.3 alinhado; §6.7 documenta assimetria janela vs volume; figs 06/07 regeneradas com legenda qualificadora.
- **Arquivos alterados:** `relatorio_completo_estudo.md`, `generate_figures.py`, `output/figures/06_*.png`, `07_*.png`, `docs/rastreabilidade.md`.
- **Validacao:** Recontagem RTDB n=386; leitura de `network_simulator.dart` + `sync_service.dart` + `offline_task_repository.dart`.
- **Status:** Concluido.

| Campo | Conteudo |
|--------|-----------|
| **ID / tema** | Consistencia latencia + simetria NetworkSimulator |
| **Contexto** | Revisao figura 06/07 vs texto |
| **Causa** | Unidades diferentes; volume nao simetrico no offline |
| **Decisao** | Evento como primario; qualificar alegacao de simetria |
| **Arquivos alterados** | relatorio, generate_figures, figuras 06/07, rastreabilidade |
| **Validacao** | Stats n=386; codigo do simulador conferido |
| **Risco residual** | Estado do singleton pode vazar entre fases (volume residual) |
| **Status** | Concluido |

## 2026-07-27 - Ajustes ABNT/visuais nas figuras

- **Contexto:** Revisao pediu (1) sem titulo embutido (titulo ABNT no texto), (2) fig.01 Firestore vs RTDB, (3) cores azul/verde na taxa efetiva, (4) IC 95% + eixo −3…+3 no comparativo, (5) funil sem jargao P000, (6) SUS sem interpretacao no titulo, (7) engajamento com n ativos/semana.
- **Causa:** Titulos duplicados vs padrao ABNT; SE sugeria significancia inexistente; caixa offline no boxplot seaborn colapsava e herdava azul; funil citava P000.
- **Decisao:** Remover `set_title` de todas; rotulo Firestore (tarefas) na 01 (RTDB = telemetria/config — correto); boxplot nativo com cores explicitas; barras com half-width IC 95% (t) e ylim −3…+3; funil sem P000; engajamento anota `n=` por ponto.
- **Arquivos alterados:** `analysis/generate_figures.py`, `analysis/output/figures/*`, `docs/rastreabilidade.md`.
- **Validacao:** `python generate_figures.py` exit 0; inspecao visual das PNGs 01, 03, 04, 05, 08, 09.
- **Status:** Concluido (figura 02 ainda pendente — screenshots reais).

| Campo | Conteudo |
|--------|-----------|
| **ID / tema** | Ajustes ABNT e consistencia visual das figuras |
| **Contexto** | Revisao monografica das PNGs |
| **Causa** | Titulo duplicado; SE vs p; cores inconsistentes; jargao |
| **Decisao** | IC 95%, escala completa, paleta unica, sem titulos embutidos |
| **Arquivos alterados** | generate_figures.py, figures/, rastreabilidade.md |
| **Validacao** | Regeneracao completa + checagem visual |
| **Risco residual** | IC t vs Wilcoxon pode diferir levemente; Estabilidade pode tangenciar zero |
| **Status** | Concluido |

## 2026-07-27 - Correcao de sobreposicao visual (figs 01 e 06)

- **Contexto:** Titulos dos paineis da fig.01 cobriam o primeiro quadro; na fig.06 o titulo do 3o painel cobria rotulos das janelas.
- **Causa:** Espaco vertical insuficiente entre titulo e elementos; `axis("off")` + texto interno comprimiam o layout.
- **Decisao:** Fig.01 com `set_title` + `pad` e primeiro quadro rebaixado; fig.06 com `set_title` fora dos eixos, rotulos das janelas sem rotacao e sem `tight_layout`.
- **Arquivos alterados:** `generate_figures.py`, `output/figures/01_*.png`, `06_*.png`, `docs/rastreabilidade.md`.
- **Validacao:** Regeneracao das duas PNGs.
- **Status:** Concluido.

## 2026-07-27 - Exportacao de respostas abertas (texto livre)

- **Contexto:** `questionarios_flat.csv` ia so ate `comp6`; respostas de `open_answers` nao eram exportadas. Usuario pediu CSV com `arq_T1`/`arq_T2` + tres perguntas e enunciados para Apendice C / §3.4.1.
- **Causa:** Pipeline de lacunas so achatava escalas Likert/comparativo.
- **Decisao:** Script `export_open_answers.py` le `responses.open_answers.{liked,frustrated,gaveup}` do RTDB; arquitetura de fase via `resolve_period_architecture`. CSV largo (1 linha/participante, T1+T2) e CSV longo (1 linha/periodo, colunas `pergunta1..3`).
- **Arquivos alterados:** `analysis/export_open_answers.py`, `analysis/output/respostas_abertas*.csv`, `respostas_abertas_enunciados.md`, `analysis/README.md`, `docs/rastreabilidade.md`.
- **Validacao:** Script exit 0; 23 participantes com questionario; 44 linhas por periodo; 19 com texto em T1 e T2.
- **Status:** Concluido.

| Campo | Conteudo |
|--------|-----------|
| **ID / tema** | Export respostas abertas RTDB |
| **Contexto** | Material qualitativo ausente no flat |
| **Causa** | Flat so ia ate comp6 |
| **Decisao** | Export dedicado com arq_T1/arq_T2 |
| **Arquivos alterados** | export_open_answers.py, output/*, README, rastreabilidade |
| **Validacao** | Fetch RTDB + contagens |
| **Risco residual** | Quebras de linha dentro das respostas (CSV com aspas) |
| **Status** | Concluido |

## 2026-07-30 - Template Figura 2 (capturas prototipos)

- **Contexto:** Usuario pediu base para encaixar screenshots lado a lado (online | offline).
- **Decisao:** Script `compose_fig02_capturas.py` gera template 2x2 e compoe PNGs de `output/figures/screenshots/`.
- **Arquivos:** `compose_fig02_capturas.py`, `02_capturas_prototipos_TEMPLATE.png`, `screenshots/README.md`.
- **Status:** Concluido (faltam capturas reais do APK).

## 2026-10-07 - Respostas as questoes do revisor (docx comentado) e datas reais das fases

- **Contexto:** Usuario pediu respostas a 8 questoes do revisor, com base no repositorio, no RTDB e em `TCC Offline-first (5) - COMENTADO.docx` (82 comentarios).
- **Evidencias levantadas:**
  - Datas: script novo `analysis/export_phase_dates.py` (REST RTDB). n = 21: fase 1 media 17,5 d (15,0-27,4); fase 2 media 20,7 d (15,5-32,1); total ate T2 media 38,1 d (31,1-48,7). Troca feita logo apos o envio do T1 (mediana 0,0 d). `dayOfStudy` conta desde `study_started_at` -> semana 7 da Tabela 10 = participacao > 42 dias (3 de 21 com operacao apos o dia 42). P005 tem 2 trocas extras de 4 min em 26/06 (antes do T2).
  - Denominador da taxa efetiva: retentativa via "Tentar novamente" chama o repositorio de novo e gera novo evento (conta como nova tentativa). Achado: 292 dos 365 `operation_blocked` online sao `watch_tasks` (falha ao carregar lista); leituras bem-sucedidas nao entram no numerador. Taxa efetiva online por participante: media 0,559 (atual) vs 0,844 so com escritas (n = 20); agregado 270/635 = 0,425 vs 270/343 = 0,787.
  - Push offline: `sync_blocked` e emitido em todo ciclo degradado, mesmo sem pendencias (2242 eventos); ciclos com pendencia efetivamente adiada = 572; falhas reais de push = 0; falhas reais online (`success=false`) = 0.
  - Questionarios: itens extraidos dos HTML; itens invertidos marcados "(R)" visiveis ao respondente; pergunta de uso fixa "ultimos 15 dias"; T2 tem verificacao de suspeita (comp9: 5/21 "sim"; comp10: 0/21 suspeitaram de estrategia tecnica). Sem registro no repositorio da fonte da traducao do SUS nem de piloto.
  - Plano: especificacao commitada em 2026-05-13 (`e064e7b`, antes do 1o inicio em 22/05) define SUS (H1) e confiabilidade percebida (H2) como primarias, telemetria como secundaria, Wilcoxon pareado e r. Taxa efetiva e desdobramento Ha2a/Ha2b nao constam (pos-hoc).
  - Replicacao: repo GitHub privado (API 404); codigo do app e scripts de `analysis/` nao commitados; arquivos do app modificados em 23/05 (apos inicios de 22/05).
  - Docx: termina nas Referencias (sem Resumo, Abstract, listas, apendices). Secao 3.3.1 diz backend RTDB e "HTTP direto sem cache" - codigo usa Firestore SDK (tarefas) com `persistenceEnabled: !onlineFirst`; RTDB so para config/telemetria/questionarios.
- **Problema critico identificado:** RTDB e Firestore aceitam leitura sem autenticacao (RTDB: 40 `display_name` + 29 perfis com nome; Firestore `participants`: HTTP 200). Contradiz 3.5.1 ("ambiente restrito ao pesquisador").
  - Simulador: na degradacao por volume, bloqueios nao descontam; ela so termina apos 2 operacoes concluidas (via latencia) e nao expira por tempo; contador em memoria (zera ao reiniciar o app). Leitura da lista (`watch_tasks`) falha sempre que `isDegraded`, sem passar pelo contador.
  - Consentimento: termo LGPD v1.0 aceito no app no 1o acesso por 28 participantes (`profile_questionnaire.consent_version`), alem do consentimento pos-esclarecimento descrito na 3.5.1.
- **Arquivos alterados:** `analysis/export_phase_dates.py` (novo), `analysis/output/datas_fases_participantes.csv`, `analysis/output/datas_fases_resumo.md`, `analysis/README.md`, `docs/apendice_questionarios.md` (novo, transcricao literal dos instrumentos), este registro.
- **Validacao:** script executado 2x sem erro (40 participantes, 21 completos); `py_compile` ok; mediana da taxa efetiva atual (0,562) confere com o artigo; cabecalhos dos CSV de saida sem colunas de nome.
- **Bloqueios externos:** traducao do SUS, piloto/revisao de itens, busca bibliografica, protocolo CEP e build exato do APK distribuido dependem do autor; alteracao das regras do Firebase exige acesso ao console.
- **Status:** Parcial (respostas tecnicas concluidas; itens dependentes do autor pendentes).
- **Risco residual e proximo passo:** fechar regras de leitura do RTDB/Firestore e apagar `display_name`/nome do perfil apos backup; commitar e tornar publico (com tag/DOI) o codigo usado; decidir se a taxa efetiva passa a excluir `watch_tasks` ou se a leitura entra como operacao no numerador e denominador.

| Campo | Conteudo |
|--------|-----------|
| **ID / tema** | Respostas ao revisor + datas reais das fases |
| **Contexto** | 8 questoes do revisor sobre fases, troca, implementacao, questionarios, base, plano, replicacao, bibliografia |
| **Causa** | Lacunas apontadas no docx comentado |
| **Decisao** | Script de datas/exposicao; levantamento no codigo, RTDB, git e docx |
| **Arquivos alterados** | export_phase_dates.py, output/datas_fases_*, README, rastreabilidade |
| **Validacao** | Execucao do script; conferencia com valores do artigo |
| **Risco residual** | Banco legivel publicamente; taxa efetiva mistura leitura e escrita; codigo nao versionado |
| **Status** | Parcial |

## 2026-10-07 - Fechamento das regras do Firebase e preparacao para publicacao

- **Contexto:** RTDB e Firestore aceitavam leitura e escrita sem autenticacao (nomes de 40 cadastrados expostos). Usuario pediu fechar regras, commitar, criar tag, tornar o repositorio publico e arquivar no Zenodo.
- **Decisao:**
  - Snapshot completo do RTDB via `firebase database:get /` em `analysis/data/rtdb_snapshot_2026-10-07.json` (150 MB, contem nomes; `/analysis/data/` no `.gitignore`).
  - `analysis/fetch_data.py`: le snapshot (`TCC_RTDB_SNAPSHOT`, caminho `.json` em `--database-url` ou fallback automatico ao receber 401/403).
  - Regras negando tudo: `database.rules.json` e `firestore.rules`, referenciadas em `firebase.json`; deploy com `firebase deploy --only database,firestore:rules`.
  - `.gitignore`: `*.docx` (TCC comentado pelo revisor) e `~$*`.
  - Varredura de nomes (lidos do snapshot, sem exibi-los) em 219 arquivos versionaveis e em todo o historico: unica ocorrencia e o nome do proprio autor na especificacao (P000/P001 sao contas do pesquisador).
  - Commits separados: app (`577a2f9`), pipeline de analise (`6b07c32`), documentacao e regras (este commit).
- **Validacao:** deploy concluido; sem credencial, RTDB leitura 401, escrita 401 ("Permission denied"), Firestore leitura 403. `export_phase_dates.py` a partir do snapshot reproduz a saida via REST (0 diferencas no CSV e no resumo). Fallback automatico testado (40 participantes, 28 com telemetria).
- **Impacto:** o app deixa de ler e gravar no Firebase (nao usa Firebase Auth); coleta ja encerrada (`app_enabled=false`). Demonstracao ao vivo exigiria reabrir regras temporariamente ou usar outro projeto.
- **Pendente (decisao do autor):** licenca, metadados de citacao (nome completo, orientador), quais dados agregados publicar, tornar publico e vincular Zenodo (login do autor em zenodo.org).
- **Status:** Parcial.

| Campo | Conteudo |
|--------|-----------|
| **ID / tema** | Regras Firebase fechadas + commits para publicacao |
| **Contexto** | Banco com leitura/escrita publica; preparacao de repositorio publico com DOI |
| **Causa** | Regras em modo de teste desde a coleta |
| **Decisao** | Snapshot privado, fallback no fetch_data, regras deny-all, varredura de nomes, 3 commits |
| **Arquivos alterados** | .gitignore, firebase.json, database.rules.json, firestore.rules, analysis/fetch_data.py, rastreabilidade |
| **Validacao** | HTTP 401/403 sem credencial; saida identica REST x snapshot |
| **Risco residual** | Snapshot com nomes sincronizado pelo OneDrive; app sem acesso ao banco |
| **Status** | Parcial |

## 2026-10-07 - Licencas, metadados de citacao e resultados agregados para o repositorio publico

- **Contexto:** continuacao da entrada anterior. Decisoes do autor: codigo MIT; documentos, questionarios e resultados agregados CC BY 4.0; autor "Joao Antonio" (iCEV), sem orientador nos metadados; publicar so resultados agregados; publicar agora.
- **Decisao:**
  - `LICENSE` (MIT) e `LICENSE-CC-BY-4.0.md` (lista os caminhos cobertos; ressalva de que os itens do SUS sao de Brooke, 1996).
  - `CITATION.cff` (licencas MIT e CC-BY-4.0, versao 1.0.1) e `.zenodo.json` (software, idioma `por`, licenca `mit`, descricao citando CC BY 4.0 e a nao publicacao dos dados brutos).
  - `analysis/resultados_agregados/`: copias de `hypothesis_tests.md`, `cronbach_alphas.csv`, `comparative_bipolar.csv` (gerados em 27/07/2026, versoes reportadas no TCC) e `datas_fases_resumo.md` (07/10/2026), com README de origem.
  - Excluidos da publicacao: `pending_gaps_report.md` (secao demografica com celulas n=1 e idade maxima), todos os CSV por participante, respostas abertas, logs de console e o snapshot.
  - `README.md` da raiz reescrito (era o modelo padrao do Flutter): descricao, estrutura, build, analise, politica de dados, licencas, citacao. `analysis/README.md`: leitura via snapshot e regras fechadas.
- **Problema identificado:** o TCC (Secao 3.3) informa Flutter 3.24, mas `pubspec.yaml` exige Dart `^3.11.5` e o SDK instalado e Flutter 3.41.9 (Dart 3.11.5, lancado em 29/04/2026, antes da coleta). O README registra 3.41.9; o texto do TCC precisa ser corrigido pelo autor.
- **Validacao:** varredura de nomes em 226 arquivos versionaveis: ocorrencias apenas em `LICENSE`, `LICENSE-CC-BY-4.0.md`, `CITATION.cff`, `.zenodo.json` e na especificacao, todas confirmadas como o nome do autor (script compara tokens sem exibir nomes). Unico codigo de participante nos agregados: P016 (aviso de pareamento). `.zenodo.json` e `CITATION.cff` analisados sem erro (json/yaml).
- **Proximos passos nesta sessao:** commit, tag anotada `v1.0.1`, push, visibilidade publica, release no GitHub apos o autor ativar o repositorio no Zenodo, badge do DOI.
- **Status:** Parcial (publicacao em andamento).

| Campo | Conteudo |
|--------|-----------|
| **ID / tema** | Licencas, citacao e agregados para publicacao |
| **Contexto** | Repositorio sera publico e arquivado no Zenodo |
| **Causa** | Sem licenca, sem metadados e README padrao do Flutter |
| **Decisao** | MIT + CC BY 4.0; CITATION.cff e .zenodo.json; so agregados |
| **Arquivos alterados** | LICENSE, LICENSE-CC-BY-4.0.md, CITATION.cff, .zenodo.json, README.md, analysis/README.md, analysis/resultados_agregados/*, rastreabilidade |
| **Validacao** | Varredura de nomes; parse json/yaml |
| **Risco residual** | Versao do Flutter divergente no TCC; build exato do APK distribuido a confirmar pelo autor |
| **Status** | Parcial |

## Modelo para proximos registros

- **Data/hora:**
- **Tema/ID da mudanca:**
- **Contexto:**
- **Problema/Bug:**
- **Causa (confirmada ou hipotese):**
- **Correcao/Decisao aplicada:**
- **Arquivos alterados:**
- **Validacao executada:**
- **Resultado/Status (concluido, parcial, pendente):**
- **Risco residual e proximo passo:**

### Tabela de resumo (obrigatoria em mudancas relevantes)

A partir desta data, cada entrada significativa deve incluir **tambem** a tabela abaixo (copiar bloco e preencher), para alinhar ao relatorio academico e ao formato usado nas sessoes de implementacao:

| Campo | Conteudo |
|--------|-----------|
| **ID / tema** | |
| **Contexto** | |
| **Causa** | |
| **Decisao** | |
| **Arquivos alterados** | |
| **Validacao** | |
| **Risco residual** | |
| **Status** | |
