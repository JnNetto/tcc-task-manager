# Log de Rastreabilidade Tecnica

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
