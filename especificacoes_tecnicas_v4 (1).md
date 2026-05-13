# ESPECIFICAÇÕES TÉCNICAS — v4.1
## Sistema de Avaliação Empírica de Arquiteturas Offline-First

**Projeto:** Trabalho de Conclusão de Curso
**Título:** Avaliação Empírica do Impacto de Arquiteturas Offline-First na Experiência do Usuário em Aplicativos Móveis
**Autor:** João Antônio
**Instituição:** iCEV
**Curso:** Engenharia de Software
**Data:** Maio 2026
**Versão:** 4.1 *(revisão: aplicativo único, arquitetura controlada remotamente, telemetria em nuvem, UI cega ao paradigma)*

---

## SUMÁRIO

1. [Visão Geral do Sistema](#1-visão-geral-do-sistema)
2. [Decisões de Design Experimental](#2-decisões-de-design-experimental)
3. [Arquitetura Geral](#3-arquitetura-geral)
4. [Stack Tecnológica](#4-stack-tecnológica)
5. [Controle Remoto, Códigos e Painel do Pesquisador](#5-controle-remoto-códigos-e-painel-do-pesquisador)
6. [Modo Online-First](#6-modo-online-first)
7. [Modo Offline-First](#7-modo-offline-first)
8. [Sistema de Simulação de Conectividade](#8-sistema-de-simulação-de-conectividade)
9. [Sistema de Telemetria](#9-sistema-de-telemetria)
10. [Interface de Usuário](#10-interface-de-usuário)
11. [Modelo de Dados](#11-modelo-de-dados)
12. [Fluxo Experimental](#12-fluxo-experimental)
13. [Exportação e Análise de Dados](#13-exportação-e-análise-de-dados)
14. [Requisitos Não-Funcionais](#14-requisitos-não-funcionais)
15. [Cronograma de Desenvolvimento](#15-cronograma-de-desenvolvimento)
16. [Apêndices](#16-apêndices)

---

## 1. VISÃO GERAL DO SISTEMA

### 1.1 Objetivo

Desenvolver **um único** aplicativo móvel de gerenciamento de tarefas, funcionalmente equivalente nas telas e fluxos visíveis ao participante, capaz de operar em **dois modos de arquitetura de dados** (Online-First ou Offline-First) selecionados **remotamente** pelo pesquisador. O objetivo é avaliar empiricamente o impacto de cada abordagem na experiência do usuário em uso real e prolongado, com coleta automática de métricas objetivas de comportamento **enviadas à nuvem**, sem exigir exportação manual pelo participante.

### 1.2 Hipóteses

- **H1:** Aplicativos móveis desenvolvidos com arquitetura offline-first apresentam melhor percepção de usabilidade por parte dos usuários do que aplicativos desenvolvidos com arquitetura online-first em ambientes de conectividade limitada.
- **H2:** Aplicativos móveis desenvolvidos com arquitetura offline-first apresentam melhor percepção de confiabilidade por parte dos usuários do que aplicativos desenvolvidos com arquitetura online-first em ambientes de conectividade limitada.
- **H0:** Não há diferença significativa na experiência do usuário entre os dois paradigmas em ambientes de conectividade limitada.

### 1.3 Características Principais

```yaml
Tipo:                 Aplicativo móvel (Flutter/Android) — build único
Plataforma:           Android (SDK mínimo 21 / Android 5.0+)
Domínio:              Gerenciamento de tarefas pessoais
Backend:              Firebase (Firestore para tarefas; Realtime Database para telemetria e controle)
Arquitetura ativa:    Online-First ou Offline-First — atribuída por código ao participante; trocável remotamente pelo pesquisador
Design experimental:  Within-subjects longitudinal; ordem e duração de cada fase controladas pelo pesquisador (remoto)
Contexto de uso:      Campo — celular pessoal do participante, uso no dia a dia
Duração total alvo:   30 dias de estudo (ex.: 15 dias por arquitetura — parâmetros definidos e alterados pelo pesquisador)
Simulação de rede:    Simétrica em relação ao modo ativo — mesmo padrão; não se aplica a telemetria nem à leitura de configuração de arquitetura
UI ao participante:   Cega ao paradigma (sem indicação visual de online-first vs offline-first)
```

### 1.4 Princípio da Simetria do NetworkSimulator

> **Decisão de design central:** o mesmo padrão de instabilidade recorrente aplica-se ao participante **no modo em que ele estiver**, de forma que a comparação entre arquiteturas não seja confundida com padrões de rede diferentes.

Em cada instante, o app opera em **um** modo (Online-First ou Offline-First), definido remotamente. O `NetworkSimulator` atua assim:

- **Modo Online-First:** o simulador intercepta requisições ao Firestore (CRUD). Instabilidade = operações bloqueadas ou lentas; impacto direto na UI.
- **Modo Offline-First:** o simulador atua na sincronização em background. Instabilidade = sync falha ou atrasa; operações locais seguem disponíveis.

**Exclusões obrigatórias do simulador:** (1) qualquer **escrita ou leitura de telemetria** destinada ao armazenamento remoto; (2) a **consulta remota** que determina qual arquitetura o participante deve usar (e estados globais do experimento definidos pelo pesquisador). Esses fluxos devem usar caminho de rede real, para que mudanças administrativas e o registro de eventos não sejam descartados ou atrasados artificialmente.

Isso preserva a comparabilidade entre modos e a integridade da coleta e do controle experimental.

---

## 2. DECISÕES DE DESIGN EXPERIMENTAL

### 2.1 Estudo de Campo Longitudinal

O experimento é conduzido em **campo**: os participantes instalam o APK no próprio celular e usam o aplicativo no contexto real de suas vidas, sem sessões controladas em laboratório. Isso implica:

- Variabilidade natural de uso (alguns participantes usarão mais, outros menos)
- Contextos reais de uso — em casa, no trabalho, em trânsito
- A telemetria é a principal fonte de dados objetivos, pois o pesquisador não observa o uso diretamente
- Ao final de cada período, o participante responde ao SUS e ao questionário de confiabilidade percebida remotamente (formulário online)

### 2.2 Design Within-Subjects com atribuição remota

Cada participante experimenta **as duas arquiteturas** em períodos consecutivos (ou conforme calendário definido pelo pesquisador), **no mesmo aplicativo**. Não há mais dois APKs distintos: o pesquisador define, por participante ou em massa, qual modo está ativo em cada fase do estudo.

A **ordem** (por exemplo, Online-First primeiro ou Offline-First primeiro) e os **cortes de tempo** são controlados remotamente (códigos de participante + painel administrativo), preservando a lógica de contrabalanceamento quando desejado (ex.: metade dos participantes inicia em um modo e metade no outro).

Entre as duas fases arquiteturais pode haver um **intervalo de washout** (recomendado: 3–7 dias), configurável pelo pesquisador, durante o qual o app pode ser bloqueado para uso ou mantido sem registrar telemetria, conforme protocolo.

### 2.3 Duração dos períodos e do estudo

O desenho alvo do experimento passa a ser **30 dias totais** de participação no estudo, com **15 dias por arquitetura** quando se adota simetria entre as duas fases — valores **ajustáveis** pelo pesquisador no painel (não dependem de recompilação do app). O documento fixa esse alvo como referência de planejamento; alterações são permitidas desde que documentadas no protocolo.

```yaml
Duração total sugerida:     30 dias (ex.: 15 + 15 por arquitetura)
Controle:                  Pesquisador (remoto) — troca de modo e encerramento de fases
Parâmetros:                Armazenados no Firebase (ex.: study_config / participantes)
Washout:                   Opcional, entre fases, conforme seção 2.2
```

### 2.4 Variáveis do Experimento

```yaml
Variável independente:
  - Arquitetura: [online-first | offline-first]

Variáveis dependentes primárias (subjetivas — SUS e questionário):
  - Escore SUS total                          → H1 (usabilidade percebida)
  - Escore de confiabilidade percebida        → H2

Variáveis dependentes secundárias (objetivas — telemetria):
  - Taxa de sucesso de operações              → H1
  - Frequência de operações bloqueadas        → H1, H2
  - Tempo médio de resposta de operações      → H1
  - Taxa de abandono após falha               → H1, H2
  - Volume de uso ao longo do tempo           → engajamento longitudinal
  - Taxa de sincronização bem-sucedida        → H2 (modo Offline-First)
  - Tempo médio offline→sync                  → H2 (modo Offline-First)

Variáveis de controle:
  - Mesmo padrão de simulação de rede (NetworkSimulator simétrico ao modo ativo)
  - Mesmas telas e fluxos visíveis (UI cega ao paradigma)
  - Verificação remota da arquitetura ativa antes de operações de dados (fora do simulador)

Variáveis moderadoras (questionário no app, imediatamente após o código do participante):
  - Nome (ou identificação acordada no TCLE)
  - Idade
  - Gênero (opções pré-definidas, inclusive "Prefiro não informar" / "Outro" conforme protocolo ético)
  - Escolaridade (opções: Fundamental incompleto | Fundamental completo | Médio incompleto | Médio completo | Superior incompleto | Superior completo | Pós-graduação | Prefiro não informar)

```

### 2.5 Tamanho Amostral

Alvo: **n = 20 participantes** (10 por grupo de ordem). O estudo é caracterizado como exploratório. A análise estatística usará o **teste de Wilcoxon pareado** (não paramétrico, adequado para within-subjects com amostras pequenas). O tamanho do efeito será reportado com **r de Wilcoxon**.

### 2.6 Vínculo entre Telemetria e Hipóteses

| Métrica da telemetria | Hipótese | Interpretação |
|---|---|---|
| `operations_blocked` | H1, H2 | Impacto da instabilidade no modo Online-First |
| `task_success_rate` | H1 | Eficácia objetiva das operações |
| `avg_operation_duration_ms` | H1 | Eficiência objetiva (ISO 9241-11) |
| `abandon_after_failure_rate` | H1, H2 | Usuário desistiu após erro — frustração |
| `daily_operations_count` | engajamento | Queda de uso = possível frustração acumulada |
| `sync_success_rate` | H2 (modo Offline-First) | Confiabilidade da sincronização |
| `avg_pending_to_sync_ms` | H2 (modo Offline-First) | Latência percebida da consistência |

---

## 3. ARQUITETURA GERAL

### 3.1 Diagrama de Componentes

```
┌─────────────────────────────────────────────────────────────┐
│                  APLICATIVO MÓVEL FLUTTER (build único)      │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │               CAMADA DE APRESENTAÇÃO                │   │
│  │   Onboarding: código + questionário                  │   │
│  │   Screens / Widgets / Provider (UI cega ao modo)     │   │
│  └────────────────────────┬────────────────────────────┘   │
│                           │                                 │
│  ┌────────────────────────▼────────────────────────────┐   │
│  │   ExperimentConfigService (sem NetworkSimulator)     │   │
│  │   → lê participants/{code} no Firebase (RTDB/REST)   │   │
│  └────────────────────────┬────────────────────────────┘   │
│                           │                                 │
│  ┌────────────────────────▼────────────────────────────┐   │
│  │               CAMADA DE DOMÍNIO                       │   │
│  │   TaskRepository (interface) + factory por modo       │   │
│  └────────────────────────┬────────────────────────────┘   │
│                           │                                 │
│        ┌──────────────────┴──────────────────┐             │
│  ┌─────▼──────────┐             ┌────────────▼──────────┐  │
│  │ MODO ONLINE    │             │   MODO OFFLINE         │  │
│  │ OnlineRepo     │             │   OfflineRepo          │  │
│  │                │             │                        │  │
│  │ Firestore CRUD │             │   Hive + SyncService   │  │
│  │ NetworkSim ↑   │             │   NetworkSim na sync ↑ │  │
│  └────────┬───────┘             └──────────┬─────────────┘  │
│           │                               │                 │
│  ┌────────▼───────────────────────────────▼─────────────┐  │
│  │   NetworkSimulator │ TelemetryService (envio direto) │  │
│  └──────────────────────────────────────────────────────┘  │
│                           │                                 │
│  ┌────────────────────────▼────────────────────────────┐   │
│  │   PERSISTÊNCIA LOCAL                                  │   │
│  │   Hive: tasks (modo offline) | prefs: código, cache  │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                            │
              ┌─────────────┴─────────────┐
              ▼                           ▼
   ┌────────────────────┐      ┌─────────────────────────┐
   │ FIRESTORE          │      │ REALTIME DATABASE       │
   │ tasks / metadados  │      │ telemetria + controle   │
   └────────────────────┘      └─────────────────────────┘
```

### 3.2 Estrutura de Pastas

```
lib/
├── main.dart                    # Ponto de entrada único
├── config/
│   ├── app_config.dart          # janelas do NetworkSimulator, URLs
│   ├── firebase_options.dart
│   └── app_theme.dart
├── domain/
│   ├── models/
│   │   ├── task.dart
│   │   └── sync_status.dart
│   └── repositories/
│       └── task_repository.dart
├── data/
│   ├── online/
│   │   └── online_task_repository.dart
│   ├── offline/
│   │   ├── offline_task_repository.dart
│   │   ├── sync_service.dart
│   │   └── task_hive_model.dart
│   ├── experiment/
│   │   └── experiment_config_repository.dart  # lê modo remoto (sem simulador)
│   └── hive/
│       └── (opcional: fila local só se offline-first na telemetria — evitar; preferir envio direto)
├── services/
│   ├── network_simulator.dart
│   ├── telemetry_service.dart   # grava no Realtime Database, fora do simulador
│   └── export_service.dart      # opcional / legado
├── admin/                       # opcional: mesmo repo, flavor admin — ou projeto separado
│   └── ...
├── providers/
│   ├── task_provider.dart
│   ├── connectivity_provider.dart
│   └── experiment_provider.dart
├── screens/
│   ├── onboarding_code_screen.dart
│   ├── onboarding_profile_screen.dart
│   ├── task_list_screen.dart
│   ├── task_form_screen.dart
│   ├── task_detail_screen.dart
│   └── settings_screen.dart
└── widgets/
    ├── task_card.dart
    └── common/
```

---

## 4. STACK TECNOLÓGICA

### 4.1 Frontend

```yaml
Framework:   Flutter 3.24+
Linguagem:   Dart 3.5+
SDK mínimo:  Android 21 (Android 5.0)
SDK alvo:    Android 34 (Android 14)
```

### 4.2 Backend

```yaml
BaaS:   Firebase (Google)
Firestore:  Tarefas e metadados por participante (mesmo esquema de coleções já definido)
Realtime Database:  Telemetria (append JSON por evento), configuração remota do experimento e painel do pesquisador (participantes / study_config)
Regra:  Telemetria e leitura de arquitetura ativa não passam pelo NetworkSimulator
```

### 4.3 Dependências

```yaml
dependencies:
  flutter:
    sdk: flutter
  firebase_core: ^3.0.0
  cloud_firestore: ^5.0.0
  firebase_database: ^11.0.0
  hive: ^2.2.3
  hive_flutter: ^1.1.0
  path_provider: ^2.1.2
  provider: ^6.1.2
  connectivity_plus: ^6.0.0
  uuid: ^4.4.0
  intl: ^0.19.0
  device_info_plus: ^10.0.0
  share_plus: ^9.0.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  hive_generator: ^2.0.1
  build_runner: ^2.4.8
  flutter_lints: ^4.0.0
```

---

## 5. CONTROLE REMOTO, CÓDIGOS E PAINEL DO PESQUISADOR

### 5.1 Objetivo

Centralizar no **Firebase** (e em fluxo administrativo definido pelo pesquisador) a definição de **qual arquitetura cada participante usa em cada momento**, acompanhar o progresso do estudo e, ao final, **encerrar** coleta ou uso sem depender de novo APK por participante.

### 5.2 Fluxo do participante no aplicativo

1. Na primeira utilização (ou após reinstalação), o participante informa o **código** atribuído pelo pesquisador.
2. O app consulta o servidor (Realtime Database ou endpoint equivalente) para validar o código e obter o **modo ativo** (`online-first` | `offline-first`), flags de **app encerrado** e **telemetria desativada**.
3. Imediatamente após validação bem-sucedida, o participante responde ao **questionário básico no app**: nome, idade, gênero e escolaridade (opções fechadas; incluir alternativas de não identificação conforme ética).
4. Em seguida, o app funciona como gerenciador de tarefas; **toda** operação de dados (listar/criar/atualizar/remover — semanticamente GET/POST/PATCH/DELETE) **deve** consultar ou respeitar o modo ativo atual.

**Requisito de rede para a troca de arquitetura:** a leitura da configuração remota do participante **não** passa pelo `NetworkSimulator`. O simulador aplica-se apenas ao pipeline de **dados de tarefas** coerente com o modo ativo (interceptação de CRUD no modo online-first; bloqueio de sync no modo offline-first).

### 5.3 Painel / operações do pesquisador (contrato funcional)

O pesquisador dispõe de mecanismo de gestão (app administrativo separado, script ou console Firebase — implementação aberta) que permita:

- **Listar participantes** (por código ou lista completa autorizada): para cada item, exibir **nome** (ou pseudônimo), **código**, **dias acumulados** de uso sob cada arquitetura (ou dias no estudo conforme métricas armazenadas) e **arquitetura atualmente ativa**.
- **Alterar a arquitetura** associada a um participante (ou em massa) a qualquer momento; o app cliente passa a enxergar a mudança na **próxima sincronização de configuração** (polling curto ou push, ver implementação).
- **Encerrar o experimento** para um participante ou globalmente: estados como `app_disabled` (app exibe tela de estudo encerrado e não permite uso) e/ou `telemetry_disabled` (app continua ou não conforme protocolo, porém **nenhum** evento de telemetria é gravado).

### 5.4 Modelo de dados sugerido (Firebase)

Os caminhos abaixo são sugestivos; podem ser normalizados em uma única árvore do **Realtime Database** (JSON nativo) ou espelhados no Firestore.

```text
study_config/
  total_study_days: 30
  days_per_architecture_default: 15
  washout_days: 0..7
  global_app_enabled: bool
  global_telemetry_enabled: bool

participants/{participantCode}/
  display_name: string
  architecture: "online-first" | "offline-first"
  study_started_at: ISO8601
  days_online_phase: number   # derivado ou atualizado pelo cliente/servidor
  days_offline_phase: number
  app_enabled: bool
  telemetry_enabled: bool
  profile_questionnaire: { name, age, gender, education }  # preenchido uma vez no app
```

Regras de segurança do Firebase devem impedir que participantes alterem campos administrativos (`architecture`, flags de encerramento); apenas o cliente autenticado do pesquisador ou Cloud Functions podem escrever nesses nós.

### 5.5 Sincronização da arquitetura no cliente

- Após o login por código, o app armazena localmente uma **cópia em cache** do último modo autorizado e o timestamp da última leitura.
- Antes de cada operação de tarefas (ou em intervalo curto configurável, ex.: a cada abertura do app e a cada N minutos em foreground), o cliente **atualiza** essa cópia com o servidor **sem** simulador.
- Se o modo mudar entre duas operações, o runtime deve **trocar** a implementação ativa de `TaskRepository` (e iniciar/parar `SyncService` conforme necessário) de forma segura (ex.: após concluir operação em curso ou exibir mensagem neutra de “sincronizando…” sem revelar o paradigma).

---

## 6. MODO ONLINE-FIRST

### 6.1 Características

```yaml
Fonte de verdade:       Servidor remoto (Firestore)
Leitura:                Sempre do servidor
Escrita:                Sempre ao servidor
Persistência local:     Configurações e cache de experimento; telemetria enviada à nuvem (RTDB), não depende de exportação pelo participante
Sem conectividade:      Operações bloqueadas ou lentas (via NetworkSimulator)
Firebase cache:         persistenceEnabled: false — obrigatório
```

### 6.2 Implementação do Repository

```dart
// lib/data/online/online_task_repository.dart

class OnlineTaskRepository implements TaskRepository {
  final FirebaseFirestore _firestore;
  final String participantId;

  OnlineTaskRepository({required this.participantId,
      FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col => _firestore
      .collection('participants')
      .doc(participantId)
      .collection('tasks');

  @override
  Future<void> createTask(Task task) async {
    // NetworkSimulator pode bloquear ou adicionar latência aqui
    await NetworkSimulator.instance.intercept('create_task', () async {
      TelemetryService.instance.logOperationStarted('create', task.id);
      try {
        await _col.doc(task.id).set(task.toFirestore());
        TelemetryService.instance.logOperationCompleted(
            'create', task.id, success: true);
      } on FirebaseException catch (e) {
        TelemetryService.instance.logOperationCompleted(
            'create', task.id, success: false, error: e.code);
        rethrow;
      }
    });
  }

  @override
  Stream<List<Task>> watchTasks() {
    if (!NetworkSimulator.instance.isConnected) {
      TelemetryService.instance.logOperationBlocked('watch_tasks');
      return Stream.error(
          OfflineException('Sem conexão. Conecte-se para ver suas tarefas.'));
    }
    return _col
        .orderBy('createdAt', descending: true)
        .snapshots(includeMetadataChanges: false)
        .map((s) {
      TelemetryService.instance.logEvent('tasks_fetched_server',
          data: {'count': s.docs.length});
      return s.docs.map((d) => Task.fromFirestore(d)).toList();
    });
  }

  @override
  Future<void> updateTask(Task task) async {
    await NetworkSimulator.instance.intercept('update_task', () async {
      TelemetryService.instance.logOperationStarted('update', task.id);
      try {
        await _col.doc(task.id).update(task.toFirestore());
        TelemetryService.instance.logOperationCompleted(
            'update', task.id, success: true);
      } on FirebaseException catch (e) {
        TelemetryService.instance.logOperationCompleted(
            'update', task.id, success: false, error: e.code);
        rethrow;
      }
    });
  }

  @override
  Future<void> deleteTask(String taskId) async {
    await NetworkSimulator.instance.intercept('delete_task', () async {
      TelemetryService.instance.logOperationStarted('delete', taskId);
      try {
        await _col.doc(taskId).delete();
        TelemetryService.instance.logOperationCompleted(
            'delete', taskId, success: true);
      } on FirebaseException catch (e) {
        TelemetryService.instance.logOperationCompleted(
            'delete', taskId, success: false, error: e.code);
        rethrow;
      }
    });
  }
}

class OfflineException implements Exception {
  final String message;
  OfflineException(this.message);
  @override
  String toString() => message;
}
```

### 6.3 Configuração Firebase (modo Online-First)

```dart
Future<void> initializeFirebase() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: false, // sem cache — obrigatório no modo Online-First
  );
}
```

---

## 7. MODO OFFLINE-FIRST

### 7.1 Características

```yaml
Fonte de verdade:       Dispositivo local (Hive) — para leitura e escrita
Referência canônica:    Firestore remoto — Hive deve convergir para ele
Leitura:                Sempre do Hive — instantânea
Escrita:                Sempre no Hive — instantânea
Sincronização:          SyncService bidirecional em background
                        Push: Hive → Firestore (dados pendentes locais)
                        Pull: Firestore → Hive (dados mais recentes do servidor)
NetworkSimulator:       Atua no SyncService — não bloqueia operações locais
Sem conectividade sim.: Operações locais funcionam; sync fica pendente
Resolução de conflitos: Last-Write-Wins por updatedAt
```

### 7.2 Modelo Hive

```dart
// lib/data/offline/task_hive_model.dart

@HiveType(typeId: 0)
class TaskHiveModel extends HiveObject {
  @HiveField(0) final String id;
  @HiveField(1) String title;
  @HiveField(2) String? description;
  @HiveField(3) bool isCompleted;
  @HiveField(4) int priority;
  @HiveField(5) DateTime createdAt;
  @HiveField(6) DateTime updatedAt;
  @HiveField(7) int syncStatus; // SyncStatus.index
  @HiveField(8) DateTime? pendingSince; // quando ficou pending

  // ...fromDomain / toDomain omitidos por brevidade
}
```

### 7.3 Repository Offline

```dart
// lib/data/offline/offline_task_repository.dart

class OfflineTaskRepository implements TaskRepository {
  final Box<TaskHiveModel> _box;
  OfflineTaskRepository(this._box);

  @override
  Future<void> createTask(Task task) async {
    await _box.put(task.id, TaskHiveModel.fromDomain(task));
    TelemetryService.instance.logOperationCompleted(
        'create', task.id, success: true, local: true);
    // Sem verificação de rede — sempre funciona
  }

  @override
  Stream<List<Task>> watchTasks() {
    // Stream reativo do Hive — nunca falha por falta de rede
    return _box.watch().map((_) {
      final tasks = _box.values
          .map((m) => m.toDomain())
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      TelemetryService.instance.logEvent('tasks_loaded_local',
          data: {'count': tasks.length,
                 'pending': tasks.where((t) =>
                     t.syncStatus == SyncStatus.pending).length});
      return tasks;
    });
  }

  @override
  Future<void> updateTask(Task task) async {
    final updated = task.copyWith(
        updatedAt: DateTime.now(), syncStatus: SyncStatus.pending);
    await _box.put(task.id, TaskHiveModel.fromDomain(updated));
    TelemetryService.instance.logOperationCompleted(
        'update', task.id, success: true, local: true);
  }

  @override
  Future<void> deleteTask(String taskId) async {
    final model = _box.get(taskId);
    if (model != null) {
      model.syncStatus = SyncStatus.deleted.index;
      model.pendingSince = DateTime.now();
      await model.save();
    }
    TelemetryService.instance.logOperationCompleted(
        'delete', taskId, success: true, local: true);
  }

  List<Task> getPending() => _box.values
      .where((m) => m.syncStatus == SyncStatus.pending.index ||
                    m.syncStatus == SyncStatus.deleted.index)
      .map((m) => m.toDomain())
      .toList();

  Future<void> markSynced(String id) async {
    final m = _box.get(id);
    if (m != null) { m.syncStatus = SyncStatus.synced.index; await m.save(); }
  }

  Future<void> markError(String id) async {
    final m = _box.get(id);
    if (m != null) { m.syncStatus = SyncStatus.error.index; await m.save(); }
  }
}
```

### 7.4 SyncService

O `SyncService` é responsável pela sincronização **bidirecional** entre o Hive local e o Firestore remoto. O Firestore é a referência canônica — o Hive deve sempre convergir para o estado do servidor após cada ciclo de sincronização.

**Fluxo de sincronização completo:**

```text
_doSync()
  ├── PUSH: envia dados pendentes locais → Firestore
  │         (criações, edições, deleções feitas offline)
  └── PULL: busca dados novos do Firestore → Hive
            (apenas o que mudou desde lastPullAt)
```

O `lastPullAt` é um timestamp persistido em `SharedPreferences`. A cada pull, apenas documentos com `updatedAt > lastPullAt` são baixados, evitando downloads desnecessários. Na primeira abertura (Hive vazio), `lastPullAt` é nulo e todos os documentos são baixados.

```dart
// lib/data/offline/sync_service.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/network_simulator.dart';
import '../../services/telemetry_service.dart';
import '../../domain/models/task.dart';
import '../../domain/models/sync_status.dart';
import 'offline_task_repository.dart';

class SyncService {
  final OfflineTaskRepository _local;
  final FirebaseFirestore _firestore;
  final String participantId;
  bool _isSyncing = false;
  Timer? _periodicTimer;

  static const _lastPullKey = 'last_pull_at';

  SyncService({
    required OfflineTaskRepository localRepo,
    required this.participantId,
    FirebaseFirestore? firestore,
  })  : _local = localRepo,
        _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col => _firestore
      .collection('participants').doc(participantId).collection('tasks');

  void start() {
    // Sincroniza periodicamente a cada 5 minutos
    _periodicTimer = Timer.periodic(
        const Duration(minutes: 5), (_) => _syncIfAllowed());
    // Tenta imediatamente ao iniciar — pull inicial se Hive estiver vazio
    _syncIfAllowed();
  }

  Future<void> _syncIfAllowed() async {
    if (_isSyncing) return;

    final allowed = await NetworkSimulator.instance
        .checkSyncAllowed('sync_service');

    if (!allowed) {
      TelemetryService.instance.logSyncBlocked(reason: 'network_simulator');
      return;
    }

    await _doSync();
  }

  Future<void> _doSync() async {
    _isSyncing = true;
    final pending = _local.getPending();
    final prefs = await SharedPreferences.getInstance();
    final lastPullStr = prefs.getString(_lastPullKey);
    final lastPullAt = lastPullStr != null
        ? DateTime.parse(lastPullStr)
        : null; // null = primeira sincronização, baixa tudo

    TelemetryService.instance.logSyncStarted(
      pendingCount: pending.length,
      isFirstSync: lastPullAt == null,
    );

    int pushed = 0, pulled = 0, errors = 0;

    // ── PUSH: envia pendentes locais → Firestore ────────────────────────
    for (final task in pending) {
      try {
        if (task.syncStatus == SyncStatus.deleted) {
          await _col.doc(task.id).delete();
        } else {
          await _col.doc(task.id).set(task.toFirestore());
        }
        await _local.markSynced(task.id);
        pushed++;
        TelemetryService.instance.logSyncItem(task.id,
            direction: 'push',
            success: true,
            pendingDuration: task.pendingSince != null
                ? DateTime.now().difference(task.pendingSince!)
                : null);
      } catch (e) {
        await _local.markError(task.id);
        errors++;
        TelemetryService.instance.logSyncItem(task.id,
            direction: 'push', success: false, error: e.toString());
      }
    }

    // ── PULL: busca dados novos do Firestore → Hive ─────────────────────
    try {
      final pullStart = DateTime.now();
      Query<Map<String, dynamic>> query = _col;

      if (lastPullAt != null) {
        query = query.where(
          'updatedAt',
          isGreaterThan: Timestamp.fromDate(lastPullAt),
        );
      }

      final snapshot = await query.get();

      for (final doc in snapshot.docs) {
        final remote = Task.fromFirestore(doc);
        final local = _local.getById(remote.id);

        if (local == null) {
          await _local.createTaskFromRemote(remote);
          pulled++;
          TelemetryService.instance.logSyncItem(
            remote.id,
            direction: 'pull',
            success: true,
          );
        } else if (remote.updatedAt.isAfter(local.updatedAt) &&
            local.syncStatus != SyncStatus.pending) {
          await _local.updateTaskFromRemote(remote);
          pulled++;
          TelemetryService.instance.logSyncItem(
            remote.id,
            direction: 'pull',
            success: true,
          );
        }
      }

      await prefs.setString(_lastPullKey, pullStart.toIso8601String());
      TelemetryService.instance.logSyncCompleted(
          pushed: pushed, pulled: pulled, errors: errors);
    } catch (e) {
      TelemetryService.instance.logSyncCompleted(
        pushed: pushed,
        pulled: pulled,
        errors: errors + 1,
        pullError: e.toString(),
      );
    } finally {
      _isSyncing = false;
    }
  }

  void dispose() {
    _periodicTimer?.cancel();
  }
}
```

### 7.5 Métodos adicionais no OfflineTaskRepository

O pull bidirecional requer dois métodos extras no repository que não existiam antes:

```dart
// Adições em lib/data/offline/offline_task_repository.dart

/// Retorna uma tarefa por ID, ou null se não existir localmente
Task? getById(String id) {
  final model = _box.get(id);
  return model?.toDomain();
}

/// Cria tarefa vinda do servidor (sem marcar como pending)
Future<void> createTaskFromRemote(Task task) async {
  final model = TaskHiveModel.fromDomain(
      task.copyWith(syncStatus: SyncStatus.synced));
  await _box.put(task.id, model);
}

/// Atualiza tarefa com dados do servidor (sem marcar como pending)
Future<void> updateTaskFromRemote(Task task) async {
  final model = TaskHiveModel.fromDomain(
      task.copyWith(syncStatus: SyncStatus.synced));
  await _box.put(task.id, model);
}
```

### 7.6 Fluxo Completo de Operação

```text
APP ABRE (primeira vez / após reinstalação)
  ↓
Hive vazio → lastPullAt = null
  ↓
NetworkSimulator.checkSyncAllowed()
  ├── NÃO (degradação ativa) → UI mostra dados locais (vazio)
  │   → aguarda próximo ciclo de 5 min
  └── SIM → pull completo do Firestore
            → popula Hive com todos os dados do participante
            → UI exibe lista completa
            → salva lastPullAt

APP ABRE (uso normal, Hive populado)
  ↓
UI carrega do Hive imediatamente (stream reativo)
  ↓
SyncService em background:
  ├── PUSH: envia pendentes → Firestore
  └── PULL incremental: busca updatedAt > lastPullAt
      → mescla com Hive (Last-Write-Wins)
      → UI atualiza via stream reativo do Hive

USUÁRIO FAZ OPERAÇÃO (criar/editar/deletar)
  ↓
Hive atualizado imediatamente → syncStatus = pending
  ↓
UI responde instantaneamente
  ↓
[background] próximo ciclo de sync → PUSH para Firestore
```

---

## 8. SISTEMA DE SIMULAÇÃO DE CONECTIVIDADE

### 8.1 Visão Geral

O `NetworkSimulator` é **simétrico** entre participantes: **mesmo** padrão recorrente configurado. A diferença está em **como** cada **modo de arquitetura ativo** o utiliza:

- **Modo Online-First:** chama `intercept()` em cada operação CRUD — pode bloquear ou adicionar latência à operação.
- **Modo Offline-First (`SyncService`):** chama `checkSyncAllowed()` antes de cada ciclo de sync — pode impedir a sincronização, mas nunca bloqueia operações locais.

### 8.2 Estratégia de Degradação Dupla

O simulador combina duas camadas independentes de degradação, que atuam em conjunto. Uma operação é degradada se qualquer uma das duas camadas estiver ativa no momento da chamada.

**Camada 1 — Janelas fixas por horário (cobertura temporal):**
Garante que todos os participantes encontrem degradação em momentos distribuídos ao longo do dia, independentemente do volume de uso. São configuradas múltiplas janelas cobrindo diferentes períodos do dia — manhã, tarde e noite — para que usuários com diferentes rotinas sejam igualmente expostos.

**Camada 2 — Degradação por operações (cobertura proporcional):**
Garante que mesmo participantes que usam o app exclusivamente fora das janelas fixas ainda enfrentem instabilidade de forma proporcional ao uso. A cada N operações bem-sucedidas, as próximas M são degradadas. Isso assegura que participantes com alto volume de uso fora das janelas não tenham uma experiência artificialmente melhor.

As duas camadas são configuradas em `app_config.dart` e são **as mesmas** para todos os participantes; apenas o **ponto de aplicação** muda conforme o modo ativo (CRUD vs sync).

### 8.3 Configuração

```dart
// lib/config/app_config.dart

class AppConfig {
  // Duração de fases pode vir do RTDB (study_config); constante abaixo = fallback
  static const int periodDurationDays = 0; // 0 = usar apenas config remota

  // ── CAMADA 1: Janelas fixas por horário ────────────────────────────────
  // Múltiplas janelas ao longo do dia para cobrir diferentes rotinas
  static const List<SimulationWindow> networkDegradationWindows = [
    SimulationWindow(startHour: 7,  startMinute: 30, durationMinutes: 30), // manhã
    SimulationWindow(startHour: 12, startMinute: 0,  durationMinutes: 20), // almoço
    SimulationWindow(startHour: 17, startMinute: 30, durationMinutes: 30), // fim de tarde
    SimulationWindow(startHour: 20, startMinute: 0,  durationMinutes: 60), // noite
    SimulationWindow(startHour: 22, startMinute: 30, durationMinutes: 20), // noite tardia
  ];
  // Total de degradação por janelas fixas: ~2h40 por dia

  // ── CAMADA 2: Degradação por operações ────────────────────────────────
  // A cada degradationEveryNOps operações bem-sucedidas,
  // as próximas degradationDurationOps são degradadas
  static const int degradationEveryNOps = 4;   // a cada 4 ops normais...
  static const int degradationDurationOps = 2; // ...as próximas 2 são degradadas
  // Resultado: ~33% das operações fora das janelas fixas são degradadas

  // ── Modo de degradação (aplica-se às duas camadas) ─────────────────────
  static const DegradationMode degradationMode = DegradationMode.blockAndLatency;

  // Latência adicionada nas operações que passam (não bloqueadas)
  static const int simulatedLatencyMs = 3000;
}

class SimulationWindow {
  final int startHour;
  final int startMinute;
  final int durationMinutes;
  const SimulationWindow({
    required this.startHour,
    required this.startMinute,
    required this.durationMinutes,
  });
}

enum DegradationMode {
  blockOnly,       // bloqueia completamente
  latencyOnly,     // apenas adiciona latência
  blockAndLatency, // bloqueia parcialmente + latência nas que passam
}
```

### 8.4 Implementação do NetworkSimulator

```dart
// lib/services/network_simulator.dart

import 'dart:async';
import '../config/app_config.dart';
import 'telemetry_service.dart';

class NetworkSimulator {
  static final NetworkSimulator instance = NetworkSimulator._();
  NetworkSimulator._();

  Timer? _windowCheckTimer;

  // Camada 1: estado da janela horária
  bool _inTimeWindow = false;

  // Camada 2: contador de operações para degradação proporcional
  int _opsSucceededSinceLastDegradation = 0;
  int _opsDegradedRemaining = 0;
  bool _inOpDegradation = false;

  bool get isDegraded => _inTimeWindow || _inOpDegradation;
  bool get isConnected => !isDegraded;

  // Expõe a causa da degradação para telemetria
  DegradationCause get degradationCause {
    if (_inTimeWindow && _inOpDegradation) return DegradationCause.both;
    if (_inTimeWindow) return DegradationCause.timeWindow;
    if (_inOpDegradation) return DegradationCause.opBased;
    return DegradationCause.none;
  }

  void start() {
    _checkWindow();
    _windowCheckTimer = Timer.periodic(
        const Duration(minutes: 1), (_) => _checkWindow());
  }

  // ── Camada 1: verificação de janela horária ───────────────────────────
  void _checkWindow() {
    final now = DateTime.now();
    final inWindow = AppConfig.networkDegradationWindows.any((w) {
      final start = DateTime(now.year, now.month, now.day,
          w.startHour, w.startMinute);
      final end = start.add(Duration(minutes: w.durationMinutes));
      return now.isAfter(start) && now.isBefore(end);
    });

    if (inWindow != _inTimeWindow) {
      _inTimeWindow = inWindow;
      TelemetryService.instance.logNetworkWindowChanged(
          degraded: isDegraded,
          cause: degradationCause.name,
          timestamp: now);
    }
  }

  // ── Camada 2: atualização do contador por operações ───────────────────
  void _recordOperationOutcome(bool succeeded) {
    if (_inOpDegradation) {
      if (!succeeded) return; // ops bloqueadas não contam
      _opsDegradedRemaining--;
      if (_opsDegradedRemaining <= 0) {
        _inOpDegradation = false;
        _opsSucceededSinceLastDegradation = 0;
        TelemetryService.instance.logEvent('op_degradation_window_ended');
      }
    } else {
      if (succeeded) {
        _opsSucceededSinceLastDegradation++;
        if (_opsSucceededSinceLastDegradation >=
            AppConfig.degradationEveryNOps) {
          _inOpDegradation = true;
          _opsDegradedRemaining = AppConfig.degradationDurationOps;
          _opsSucceededSinceLastDegradation = 0;
          TelemetryService.instance.logEvent('op_degradation_window_started');
        }
      }
    }
  }

  // ── Método público: usado no modo Online-First ────────────────────────────
  Future<void> intercept(String operationName,
      Future<void> Function() operation) async {
    if (!isDegraded) {
      // Fora de qualquer degradação: executa normalmente
      try {
        await operation();
        _recordOperationOutcome(true);
      } catch (_) {
        _recordOperationOutcome(false);
        rethrow;
      }
      return;
    }

    // Dentro de alguma forma de degradação
    switch (AppConfig.degradationMode) {
      case DegradationMode.blockOnly:
        _recordOperationOutcome(false);
        TelemetryService.instance.logOperationBlocked(operationName,
            cause: degradationCause.name);
        throw OfflineException('Sem conexão. Tente novamente mais tarde.');

      case DegradationMode.latencyOnly:
        TelemetryService.instance.logOperationDelayed(
            operationName, AppConfig.simulatedLatencyMs,
            cause: degradationCause.name);
        await Future.delayed(
            Duration(milliseconds: AppConfig.simulatedLatencyMs));
        await operation();
        _recordOperationOutcome(true);

      case DegradationMode.blockAndLatency:
        // 60% de chance de bloquear, 40% passa com latência
        final blocked = DateTime.now().millisecond % 10 < 6;
        if (blocked) {
          _recordOperationOutcome(false);
          TelemetryService.instance.logOperationBlocked(operationName,
              cause: degradationCause.name);
          throw OfflineException('Sem conexão. Tente novamente mais tarde.');
        } else {
          TelemetryService.instance.logOperationDelayed(
              operationName, AppConfig.simulatedLatencyMs,
              cause: degradationCause.name);
          await Future.delayed(
              Duration(milliseconds: AppConfig.simulatedLatencyMs));
          await operation();
          _recordOperationOutcome(true);
        }
    }
  }

  // ── Método público: usado no modo Offline-First (SyncService) ─────────────
  Future<bool> checkSyncAllowed(String context) async {
    if (!isDegraded) return true;
    TelemetryService.instance.logSyncBlocked(
        reason: degradationCause.name);
    return false;
  }

  void dispose() {
    _windowCheckTimer?.cancel();
  }
}

enum DegradationCause { none, timeWindow, opBased, both }
```

### 8.5 Exemplo de Funcionamento Combinado

```
EXEMPLO — participante com rotina de uso variada

Cenário A: uso dentro de janela fixa
  12:05 — usuário abre o app (janela das 12h ativa)
          → _inTimeWindow = true → isDegraded = true
          → Modo online-first: operação bloqueada ou com latência
          → Modo offline-first: sync bloqueada, operação local funciona
          → telemetry: cause = 'timeWindow'

Cenário B: uso fora de janelas fixas, degradação por operações
  15:30 — usuário fez 4 operações normais seguidas
          → _opsSucceededSinceLastDegradation = 4
          → _inOpDegradation = true, _opsDegradedRemaining = 2
          → próximas 2 operações: modo online-first bloqueado/lento
          → telemetry: cause = 'opBased'

  15:31 — 5ª operação (ainda com 1 degradada restante)
          → degradada → _opsDegradedRemaining = 1
  15:32 — 6ª operação (última degradada)
          → degradada → _opsDegradedRemaining = 0
          → _inOpDegradation = false → ciclo reinicia

Cenário C: uso dentro de janela E no ciclo de ops
  20:15 — janela noturna ativa E ops atingiram limite
          → _inTimeWindow = true E _inOpDegradation = true
          → isDegraded = true
          → telemetry: cause = 'both'

DISTRIBUIÇÃO RESULTANTE DE DEGRADAÇÃO (estimativa):
  Via janelas fixas:     ~2h40min por dia (~11% do dia)
  Via ops fora janelas:  ~33% das operações no tempo restante
  Cobertura efetiva:     participante raramente passa mais de
                         4 operações consecutivas sem degradação
```

### 8.6 Resumo das Janelas Fixas Configuradas

```
Todos os dias:
  07:30 → 08:00  30 min  — instabilidade matinal (caminho ao trabalho/escola)
  12:00 → 12:20  20 min  — instabilidade no horário de almoço
  17:30 → 18:00  30 min  — instabilidade no fim de tarde (retorno)
  20:00 → 21:00  60 min  — instabilidade noturna (uso doméstico)
  22:30 → 22:50  20 min  — instabilidade noite tardia

Total por janelas:  ~2h40 por dia
Cobertura do dia:   ~11% do tempo total
```

---

## 9. SISTEMA DE TELEMETRIA

### 9.1 Princípio

Em um estudo de campo longitudinal, a telemetria é a **principal fonte de dados objetivos**. Os eventos devem ser persistidos **remotamente** (recomenda-se **Firebase Realtime Database** pela estrutura em JSON e baixa fricção para leitura pelo pesquisador), evitando depender de exportação manual pelo participante após cada sessão.

**Regras obrigatórias:**

- **Nenhum** registro de telemetria passa pelo `NetworkSimulator`. O envio usa a pilha de rede normal do dispositivo (com retry exponencial simples em falhas transitórias).
- Cada evento deve carregar o valor **`architecture`** (`online-first` | `offline-first`) **vigente no momento do log**, obtido do mesmo estado usado pelos repositórios de tarefas (após a resolução remota da seção 5), de modo que, com um único binário, as séries temporais das duas arquiteturas permanecem **separáveis** na análise.
- Se `telemetry_disabled` estiver ativo no participante (seção 5), o serviço de telemetria torna-se no-op.

### 9.2 Modelo de evento (contrato JSON no Realtime Database)

Cada gravação é um nó filho sob `telemetry/{participantCode}/{pushId}` (ou agrupamento equivalente), contendo:

```json
{
  "id": "uuid-v4",
  "participantId": "código ou id interno",
  "sessionId": "uuid-v4",
  "eventType": "operation_completed",
  "timestamp": "2026-05-12T18:00:00.000Z",
  "data": { "op": "create", "task_id": "...", "success": true },
  "architecture": "offline-first",
  "networkDegraded": false,
  "sequenceNumber": 42,
  "dayOfStudy": 8
}
```

> O campo `dayOfStudy` continua essencial para análises longitudinais (ex.: semana 1 vs. semana 2 dentro de cada fase de 15 dias). Pode ser calculado a partir de `study_started_at` armazenado no perfil do participante.

### 9.3 Serviço de Telemetria (persistência remota)

O `TelemetryService` **não** usa Hive como fonte primária. Opcionalmente mantém **fila local mínima** apenas para reenvio se o app for fechado durante uma escrita pendente — mas o caminho feliz é `push` imediato ao RTDB. Ilustração do núcleo de `logEvent`:

```dart
// lib/services/telemetry_service.dart (trecho conceitual)
// imports: firebase_database, uuid, ...

import 'package:firebase_database/firebase_database.dart';

class TelemetryService {
  static final TelemetryService instance = TelemetryService._();
  TelemetryService._();

  DatabaseReference? _telemetryRoot;
  late String _participantCode;
  late DateTime _studyStartDate;
  String _sessionId = '';
  int _seq = 0;

  /// architectureAtEventTime vem do ExperimentConfigService (valor já resolvido no servidor).
  Future<void> logEvent(
    String type, {
    Map<String, dynamic>? data,
    required String architectureAtEventTime,
    required bool telemetryEnabled,
  }) async {
    if (!telemetryEnabled) return;

    final payload = {
      'id': const Uuid().v4(),
      'participantId': _participantCode,
      'sessionId': _sessionId,
      'eventType': type,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'data': data,
      'architecture': architectureAtEventTime,
      'networkDegraded': NetworkSimulator.instance.isDegraded,
      'sequenceNumber': _seq++,
      'dayOfStudy': DateTime.now().difference(_studyStartDate).inDays + 1,
    };

    // IMPORTANTE: sem interceptação pelo NetworkSimulator
    await _telemetryRoot!
        .child(_participantCode)
        .push()
        .set(payload);
  }

  // Demais métodos (logOperationCompleted, logSyncItem, etc.) delegam a logEvent
  // passando sempre architectureAtEventTime atual.
}
```

Funções de **agregação** (`summary`, `daily_breakdown`) passam a ser responsabilidade do **pesquisador** (script Python lendo JSON exportado do RTDB, Cloud Functions ou consulta no console Firebase), não do app participante.

### 9.4 Catálogo de Eventos

```yaml
SESSÃO:
  session_started         — app aberto (nova sessão de uso)

OPERAÇÕES CRUD (predominantes no modo online-first):
  operation_started       — início de operação (medir duração quando aplicável)
  operation_completed     — conclusão (success, local, error)
  operation_blocked       — bloqueada pelo NetworkSimulator (somente pipeline de tarefas degradado)
  operation_delayed       — atrasada por latência simulada (modo online-first)
  abandon_after_failure   — usuário desistiu após erro (modo online-first)

SINCRONIZAÇÃO (modo offline-first):
  sync_started            — ciclo de sync iniciado (is_first_sync, pending_count)
  sync_completed          — ciclo concluído (pushed, pulled, errors)
  sync_blocked            — sync impedida pelo NetworkSimulator
  sync_item               — resultado por tarefa (direction: push|pull, pending_duration_ms)

REDE:
  network_window_changed  — entrada/saída de janela de degradação

CAMPOS TRANSVERSAIS EM TODOS OS EVENTOS:
  architecture            — 'online-first' | 'offline-first' (valor no instante do evento)
  networkDegraded         — simulador ativo para dados de tarefas quando o evento ocorreu?
  dayOfStudy              — dia desde o início da participação no estudo (1, 2, 3…)
```

---

## 10. INTERFACE DE USUÁRIO

### 10.1 Princípio

A interface é **única e neutra** em relação ao paradigma de dados: o participante **não** deve inferir se está em online-first ou offline-first por meio de textos, ícones exclusivos de “sincronização na nuvem” vs “local”, cores distintas ou badges na AppBar. Qualquer estado de espera ou erro deve usar mensagens **genéricas** (ex.: “Não foi possível concluir agora”, “Aguarde…”) que não revelem a estratégia de persistência.

> Motivação experimental: participantes com conhecimento técnico poderiam enviesar respostas se identificassem o modo offline-first.

### 10.2 Telas principais

#### Onboarding — código do participante

Tela inicial solicita apenas o **código** fornecido pelo pesquisador e valida contra o Firebase (sem `NetworkSimulator`).

#### Onboarding — questionário básico

Após código válido: formulário com **nome**, **idade**, **gênero** (lista fechada + opções de não identificação) e **escolaridade** (opções da seção 2.4). Os dados são enviados ao nó do participante no Firebase conforme seção 5.4.

#### Lista de Tarefas

```
┌─────────────────────────────────────────┐
│ ☰  Minhas Tarefas                       │  ← sem badge que revele modo offline/sync
├─────────────────────────────────────────┤
│ [Todas]  [Pendentes]  [Concluídas]      │
├─────────────────────────────────────────┤
│ ┌─────────────────────────────────────┐ │
│ │ ● Reunião com cliente        [  ]  │ │
│ │   Sala de conferências B           │ │
│ │   Hoje, 14:30                      │ │
│ └─────────────────────────────────────┘ │
│ ┌─────────────────────────────────────┐ │
│ │ ● Comprar mantimentos        [✓]  │ │
│ │   Supermercado                     │ │
│ │   Ontem, 09:15                     │ │
│ └─────────────────────────────────────┘ │
│                                   [+]   │
└─────────────────────────────────────────┘
```

#### Criar / Editar Tarefa

```
┌─────────────────────────────────────────┐
│ ←  Nova Tarefa                 [Salvar] │
├─────────────────────────────────────────┤
│  Título *                               │
│  ┌───────────────────────────────────┐  │
│  │                                   │  │
│  └───────────────────────────────────┘  │
│  Descrição (opcional)                   │
│  ┌───────────────────────────────────┐  │
│  │                                   │  │
│  └───────────────────────────────────┘  │
│  Prioridade                             │
│  ○ Baixa    ● Média    ○ Alta           │
└─────────────────────────────────────────┘
```

#### Feedback de erro (durante janela de degradação no modo online-first)

```
┌─────────────────────────────────────────┐
│              ⚠ Erro                     │
├─────────────────────────────────────────┤
│  Sem conexão. Não foi possível salvar   │
│  a tarefa. Verifique sua conexão e      │
│  tente novamente.                       │
│                                         │
│  [Tentar novamente]      [Cancelar]     │
└─────────────────────────────────────────┘
```

> O botão "Cancelar" dispara `logAbandonAfterFailure()` na telemetria.

---

## 11. MODELO DE DADOS

### 11.1 Task (domínio)

```dart
enum TaskPriority { low, medium, high }
enum SyncStatus { pending, synced, error, deleted }

class Task {
  final String id;
  final String title;
  final String? description;
  final bool isCompleted;
  final TaskPriority priority;
  final DateTime createdAt;
  final DateTime updatedAt;
  final SyncStatus syncStatus;
  final DateTime? pendingSince;

  // copyWith, toFirestore, fromFirestore omitidos por brevidade
}
```

### 11.2 Interface TaskRepository

```dart
abstract class TaskRepository {
  Stream<List<Task>> watchTasks();
  Future<void> createTask(Task task);
  Future<void> updateTask(Task task);
  Future<void> deleteTask(String taskId);
}
```

---

## 12. FLUXO EXPERIMENTAL

### 12.1 Visão Geral

```
LINHA DO TEMPO DO EXPERIMENTO

[Recrutamento + TCLE]
  ↓
[Onboarding no app]
  Participante instala o APK único
  Informa código → validação remota (sem simulador)
  Questionário básico (nome, idade, gênero, escolaridade)
  Instruções de uso neutras
  ↓
[FASE 1 — ex.: 15 dias no modo A]
  Pesquisador mantém architecture = online-first ou offline-first
  Participante usa o app no dia a dia
  NetworkSimulator ativo apenas no pipeline de tarefas
  Telemetria gravada no RTDB em tempo real
  ↓
[Transição de fase]
  Pesquisador altera architecture remotamente (opcional: washout com app desativado)
  Participante **não** reinstala outro APK
  ↓
[FASE 2 — ex.: 15 dias no modo B]
  Mesmo app, outro modo de repositório após refresh de configuração
  ↓
[Encerramento]
  Pesquisador pode desativar telemetria e/ou desativar o app (tela de estudo encerrado)
  Participante responde SUS + confiabilidade por formulário online (após cada fase)
  Questionário comparativo após a segunda fase
  ↓
[Análise]
  Dados objetivos obtidos diretamente do Firebase (export JSON / scripts)
```

### 12.2 Instrumentos de Coleta

**SUS (após cada período):**
10 itens padrão em português, escala Likert 1–5. Escore calculado pela fórmula de Brooke (1996).

**Questionário de confiabilidade percebida (após cada período):**
4 itens em escala Likert 1–5:

1. "Eu confiaria neste aplicativo para armazenar informações importantes."
2. "O aplicativo funcionou de forma consistente ao longo do tempo que usei."
3. "Eu me senti seguro(a) de que as ações realizadas foram registradas corretamente."
4. "O aplicativo se comportou como eu esperava, mesmo em momentos com problemas de conexão."

**Questionário de preferência comparativa (após a segunda fase arquitetural):**
3 itens comparando as **duas fases de uso** do mesmo app, sem nomear arquiteturas.

**Questionário básico no aplicativo (uma vez, após o código):**
Nome, idade, gênero e escolaridade — ver seção 2.4 e 10.2.

### 12.3 Protocolo de exportação e acesso aos dados

A fonte primária de telemetria é o **Firebase Realtime Database**. O pesquisador:

1. Exporta os nós `telemetry/...` via console, **Firebase Admin SDK**, script Python com credencial de serviço, ou **Cloud Functions** agendadas.
2. Não exige que o participante envie arquivos após cada sessão.

O app pode manter função **“Exportar dados”** opcional para resgate de emergência ou depuração; não é o fluxo principal da coleta.

---

## 13. EXPORTAÇÃO E ANÁLISE DE DADOS

### 13.1 Estrutura do JSON exportado (referência / legado)

O formato abaixo permanece útil como **esquema lógico** após agregação offline dos eventos do RTDB (campo `architecture` por evento substitui o antigo `prototype` fixo por build). Scripts de análise devem filtrar eventos por `architecture` ao comparar fases.

```json
{
  "metadata": {
    "export_timestamp": "2026-05-18T14:00:00.000Z",
    "participant_id": "P001",
    "architecture_phase": "offline-first",
    "study_start_date": "2026-04-18T00:00:00.000Z",
    "total_days": 30,
    "total_events": 847
  },
  "summary": {
    "operation_success_rate": 1.0,
    "operations_blocked_total": 0,
    "operations_delayed_total": 0,
    "abandon_after_failure_total": 0,
    "sync_push_success_rate": 0.97,
    "sync_pull_success_rate": 1.0,
    "avg_pending_to_sync_ms": 4320000,
    "total_operations": 312
  },
  "daily_breakdown": {
    "day_1": { "total_operations": 15, "operations_blocked": 0, "sessions": 3 },
    "day_2": { "total_operations": 12, "operations_blocked": 0, "sessions": 2 },
    "...": "..."
  },
  "events": [ "..." ]
}
```

### 13.2 Script de Análise (Python)

O script abaixo assume arquivos `analytics_*.json` já **agregados** por participante e fase (como no esquema da seção 13.1). Na prática, a etapa ETL deve ler o RTDB, filtrar eventos por `architecture` e opcionalmente pivotar para colunas `online-first` / `offline-first` antes de reutilizar funções como `stats.wilcoxon`. Ajuste os nomes de colunas (`prototype` → `architecture` ou fases) conforme o CSV de SUS.

```python
# analysis/analyze.py

import json
import pandas as pd
from pathlib import Path
from scipy import stats
import matplotlib.pyplot as plt
import seaborn as sns

def load_all(data_dir: Path):
    records = []
    for f in data_dir.glob('analytics_*.json'):
        d = json.loads(f.read_text())
        m = d['metadata']
        s = d['summary']
        records.append({
            'participant_id':        m['participant_id'],
            'prototype':             m['prototype'],
            'total_days':            m['total_days'],
            'total_operations':      s['total_operations'],
            'success_rate':          s['operation_success_rate'],
            'blocked_total':         s['operations_blocked_total'],
            'abandon_rate':          s['abandon_after_failure_total'] /
                                     max(s['operations_blocked_total'], 1),
            'sync_push_success_rate': s.get('sync_push_success_rate'),
            'sync_pull_success_rate': s.get('sync_pull_success_rate'),
            'avg_pending_ms':        s.get('avg_pending_to_sync_ms'),
        })
    return pd.DataFrame(records)

def daily_engagement(data_dir: Path):
    """Análise de engajamento diário — detecta queda de uso ao longo do tempo"""
    all_daily = []
    for f in data_dir.glob('analytics_*.json'):
        d = json.loads(f.read_text())
        proto = d['metadata']['prototype']
        pid   = d['metadata']['participant_id']
        for day_key, day_data in d['daily_breakdown'].items():
            day_num = int(day_key.replace('day_', ''))
            all_daily.append({
                'participant_id': pid,
                'prototype':      proto,
                'day':            day_num,
                'operations':     day_data['total_operations'],
                'blocked':        day_data['operations_blocked'],
                'sessions':       day_data['sessions'],
            })
    return pd.DataFrame(all_daily)

def analyze(data_dir: Path, sus_csv: Path):
    df       = load_all(data_dir)
    daily_df = daily_engagement(data_dir)
    sus_df   = pd.read_csv(sus_csv)  # SUS coletado em formulário externo

    # Merge SUS com dados de telemetria
    merged = df.merge(sus_df, on=['participant_id', 'prototype'])

    # ── Análise H1: usabilidade percebida (SUS) ───────────────────────────
    paired_sus = merged.pivot(
        index='participant_id', columns='prototype', values='sus_score').dropna()

    w_stat, p_sus = stats.wilcoxon(
        paired_sus['online-first'], paired_sus['offline-first'])
    z = stats.norm.ppf(p_sus / 2)
    r_sus = abs(z) / (len(paired_sus) ** 0.5)

    print("=== H1: Usabilidade (SUS) ===")
    print(f"Online-First:  M={paired_sus['online-first'].mean():.1f} "
          f"SD={paired_sus['online-first'].std():.1f}")
    print(f"Offline-First: M={paired_sus['offline-first'].mean():.1f} "
          f"SD={paired_sus['offline-first'].std():.1f}")
    print(f"Wilcoxon W={w_stat:.2f}, p={p_sus:.4f}, r={r_sus:.3f}\n")

    # ── Análise H2: confiabilidade percebida ─────────────────────────────
    paired_conf = merged.pivot(
        index='participant_id', columns='prototype',
        values='reliability_score').dropna()

    w_conf, p_conf = stats.wilcoxon(
        paired_conf['online-first'], paired_conf['offline-first'])
    print("=== H2: Confiabilidade percebida ===")
    print(f"Wilcoxon W={w_conf:.2f}, p={p_conf:.4f}\n")

    # ── Análise objetiva: taxa de sucesso de operações ────────────────────
    paired_ops = merged.pivot(
        index='participant_id', columns='prototype',
        values='success_rate').dropna()
    w_ops, p_ops = stats.wilcoxon(
        paired_ops['online-first'], paired_ops['offline-first'])
    print("=== Objetiva: Taxa de sucesso ===")
    print(f"Wilcoxon W={w_ops:.2f}, p={p_ops:.4f}\n")

    # ── Análise de engajamento longitudinal ───────────────────────────────
    print("=== Engajamento ao longo do tempo ===")
    weekly = daily_df.copy()
    weekly['week'] = ((weekly['day'] - 1) // 7) + 1
    weekly_ops = weekly.groupby(['prototype', 'week'])['operations'].mean()
    print(weekly_ops)

    # ── Controle do efeito de ordem ───────────────────────────────────────
    order_check = merged.groupby(
        ['prototype', 'study_order'])['sus_score'].mean()
    print("\n=== Efeito de ordem ===")
    print(order_check)

    _plot(merged, daily_df)
    return merged

def _plot(merged, daily_df):
    fig, axes = plt.subplots(2, 2, figsize=(14, 10))

    sns.boxplot(data=merged, x='prototype', y='sus_score', ax=axes[0, 0])
    axes[0, 0].set_title('SUS por Arquitetura')
    axes[0, 0].set_ylabel('Escore SUS (0–100)')

    sns.boxplot(data=merged, x='prototype', y='success_rate', ax=axes[0, 1])
    axes[0, 1].set_title('Taxa de Sucesso de Operações')
    axes[0, 1].set_ylabel('Taxa (0–1)')

    weekly = daily_df.copy()
    weekly['week'] = ((weekly['day'] - 1) // 7) + 1
    weekly_mean = weekly.groupby(['prototype', 'week'])['operations'].mean().reset_index()
    sns.lineplot(data=weekly_mean, x='week', y='operations',
                 hue='prototype', ax=axes[1, 0])
    axes[1, 0].set_title('Engajamento Semanal Médio')
    axes[1, 0].set_ylabel('Operações por dia')

    sns.boxplot(data=merged, x='prototype', y='blocked_total', ax=axes[1, 1])
    axes[1, 1].set_title('Operações Bloqueadas por Participante')
    axes[1, 1].set_ylabel('Total')

    plt.tight_layout()
    plt.savefig('results.png', dpi=300)
    print("Gráficos salvos em results.png")

if __name__ == '__main__':
    analyze(Path('data/'), Path('data/sus_scores.csv'))
```

---

## 14. REQUISITOS NÃO-FUNCIONAIS

### 14.1 Performance

```yaml
Operações locais (modo offline-first):     < 50ms
Requisições Firestore (modo online-first): < 2s fora de janela de degradação
Carregamento inicial:                      < 3s
Sync em background:                        não bloqueia UI
Consumo de bateria:                       mínimo — sem polling agressivo na telemetria (batch opcional)
```

### 14.2 Confiabilidade

```yaml
Telemetria:           envio remoto com retry; nunca atravessando o NetworkSimulator
Dados locais (modo offline-first): zero perda por falta de rede nas operações de UI
Resolução de modo:    leitura remota da arquitetura fora do simulador
```

### 14.3 Usabilidade

```yaml
Idioma:               Português (Brasil)
Touch targets:        mínimo 48×48dp
Fonte mínima:         14sp
Contraste:            WCAG AA
Mensagens de erro:    claras e com opção de retry quando o modo online-first falhar na persistência remota
```

### 14.4 Compatibilidade

```yaml
Android mínimo:   5.0 (API 21)
Android alvo:     14 (API 34)
Dispositivo ref.: Android mid-range contemporâneo
```

### 14.5 Privacidade

```yaml
Dados:            identificados por código de participante + perfil mínimo no app
Consentimento:    TCLE assinado antes da instalação
Armazenamento:    tarefas no Firestore conforme modo; telemetria e controle no RTDB (servidor Google)
Conformidade:     LGPD — política de retenção e acesso definida no projeto
```

---

## 15. CRONOGRAMA DE DESENVOLVIMENTO

```yaml
TOTAL ESTIMADO: 100–130 horas

Semana 1 (45h):
  Setup Flutter + Firebase (Firestore + RTDB) + regras de segurança:  8h
  Onboarding: código + questionário + ExperimentConfigRepository:     8h
  Modelos de domínio + TaskRepository + factory por modo:             6h
  UI neutra: tema, telas de tarefas, mensagens genéricas:             12h
  Modo online-first (OnlineTaskRepository):                           8h
  Testes modo online-first + simulador em CRUD:                       3h

Semana 2 (45h):
  Modo offline-first (Hive + OfflineTaskRepository):                  10h
  SyncService + integração Firestore:                                  10h
  NetworkSimulator (recorrente, simétrico ao modo ativo):             8h
  TelemetryService (RTDB, fora do simulador, campo architecture):     10h
  Painel admin mínimo ou scripts de gestão de participantes:          4h
  Testes modo offline-first + sync:                                   3h

Semana 3 (25h):
  Script Python de análise (export RTDB / JSON agregado):             6h
  Testes integrados (troca remota de modo, washout, flags fim):       10h
  Ajustes LGPD, documentação inline:                                  9h

BUFFER: +25h para imprevistos
```

---

## 16. APÊNDICES

### 16.1 Comandos Úteis

```bash
# Criar projeto
flutter create --org br.edu.ufla task_manager_study

# Dependências
flutter pub add firebase_core cloud_firestore firebase_database \
  hive hive_flutter path_provider provider connectivity_plus uuid intl \
  device_info_plus share_plus

# Configurar Firebase
dart pub global activate flutterfire_cli
flutterfire configure

# Gerar código Hive (modelos de tarefa local)
flutter pub run build_runner build --delete-conflicting-outputs

# Build APK único (release)
flutter build apk --release
```

### 16.2 Ponto de entrada único e seleção de repositório

```dart
// lib/main.dart (ilustrativo — imports omitidos)

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await Hive.initFlutter();
  Hive.registerAdapter(TaskHiveModelAdapter());
  final taskBox = await Hive.openBox<TaskHiveModel>('tasks');

  final experiment = ExperimentController(
    taskBox: taskBox,
    database: FirebaseDatabase.instance,
    firestore: FirebaseFirestore.instance,
  );
  await experiment.loadParticipantFromPrefsOrOnboarding();

  NetworkSimulator.instance.start();
  experiment.startSyncIfOfflineMode();

  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: experiment),
      ProxyProvider<ExperimentController, TaskRepository>(
        update: (_, exp, __) => exp.repository,
      ),
    ],
    child: const StudyApp(),
  ));
}

/// ExperimentController encapsula:
/// - leitura remota de participants/{code}.architecture (SEM NetworkSimulator)
/// - troca de OnlineTaskRepository vs OfflineTaskRepository + SyncService
/// - TelemetryService com push RTDB e architecture por evento
```

### 16.3 Glossário

```yaml
NetworkSimulator:    Simula degradação de rede no pipeline de **tarefas** do modo ativo
SimulationWindow:    Janela de tempo com degradação ativa (hora + duração)
DegradationMode:     Como a degradação se manifesta (block / latency / ambos)
intercept():         Usado no modo online-first em operações CRUD ao Firestore
checkSyncAllowed():  Usado no modo offline-first no SyncService
dayOfStudy:          Dia desde o início da participação no estudo (campo em cada evento)
architecture:        Modo de dados no instante do evento de telemetria
networkDegraded:     Flag: simulador ativo para tarefas quando o evento ocorreu
Washout:             Intervalo entre fases arquiteturais (opcional)
Within-subjects:     Cada participante experimenta as duas arquiteturas (sequência controlada remotamente)
UI cega:             Interface sem revelar online-first vs offline-first
```

### 16.4 Checklist de Entrega

```yaml
Aplicativo:
  - [ ] Modo online-first: opera fora da janela; bloqueia/atrasa dentro da janela
  - [ ] Modo offline-first: opera localmente na janela; sync retoma após janela
  - [ ] Troca remota de architecture refletida sem reinstalar APK
  - [ ] Telemetria gravada no RTDB com campo architecture; nunca passa pelo simulador
  - [ ] Leitura de configuração remota (código, modo, encerramento) fora do simulador
  - [ ] APK único gerado em release

Materiais do experimento:
  - [ ] TCLE
  - [ ] Questionário no app (nome, idade, gênero, escolaridade)
  - [ ] Questionário SUS em português (formulário online, após cada fase)
  - [ ] Questionário de confiabilidade percebida (formulário online)
  - [ ] Questionário de preferência comparativa (formulário online)
  - [ ] Protocolo do pesquisador + painel/lista de participantes (Firebase)

Análise:
  - [ ] Script Python ou pipeline de exportação do RTDB testado com dados simulados
  - [ ] Template de sus_scores.csv (merge por participant_id e fase / architecture)

Documentação:
  - [ ] Este documento técnico (v4.1)
  - [ ] README do repositório
```

---

**FIM DO DOCUMENTO**

*Versão 4.1 — Aplicativo único, controle remoto de arquitetura, telemetria em RTDB, UI cega (maio 2026)*
