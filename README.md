# tcc-task-manager

Aplicativo, instrumentos e análise do Trabalho de Conclusão de Curso **"Avaliação Empírica do Impacto de Arquiteturas Offline-First na Experiência do Usuário em Aplicativos Móveis"** (Engenharia de Software, iCEV, 2026).

Um único aplicativo Flutter de tarefas opera em dois modos, escolhidos remotamente pelo pesquisador:

- **online-first:** cada operação vai direto ao Cloud Firestore (SDK com cache em disco desligado);
- **offline-first:** operações gravadas no Hive e sincronizadas com o Firestore em segundo plano (`SyncService`).

Um simulador embarcado (`lib/services/network_simulator.dart`) degrada a conectividade em janelas horárias fixas e por volume de operações. A telemetria e a configuração ficam no Firebase Realtime Database. O experimento foi de campo, within-subjects, com ordem contrabalanceada; 21 participantes concluíram as duas fases.

## Estrutura

| Caminho | Conteúdo |
| --- | --- |
| `lib/` | Aplicativo Flutter: repositórios online e offline, sincronização, simulador, telemetria, troca remota de arquitetura, painel do pesquisador |
| `lib/config/app_config.dart` | Parâmetros do experimento (janelas de degradação, regra de volume, latência simulada) |
| `questionario_T1.html`, `questionario_T2.html` | Questionários aplicados ao fim de cada fase |
| `docs/apendice_questionarios.md` | Transcrição literal de todos os instrumentos |
| `especificacoes_tecnicas_v4 (1).md` | Especificação técnica e plano de análise |
| `docs/rastreabilidade.md` | Registro cronológico de mudanças, problemas e decisões |
| `analysis/` | Pipeline de análise em Python (ver `analysis/README.md`) |
| `analysis/resultados_agregados/` | Resultados agregados publicados |
| `database.rules.json`, `firestore.rules` | Regras do Firebase (coleta encerrada: acesso negado a clientes) |

## Aplicativo

Desenvolvido com Flutter 3.41.9 (Dart 3.11.5), alvo Android. Versão do estudo: `1.0.1+2` (`pubspec.yaml`).

```bash
flutter pub get
flutter build apk --release
```

O projeto Firebase original está com as regras fechadas desde 07/10/2026, então um build deste repositório não lê nem grava dados. Para reproduzir o estudo, crie um projeto Firebase próprio, gere `lib/firebase_options.dart` e `android/app/google-services.json` com `flutterfire configure` e defina regras adequadas.

## Análise

```bash
cd analysis
pip install -r requirements.txt
python analyze_full_study.py
```

Os scripts leem um snapshot do Realtime Database. O snapshot do estudo contém dados pessoais e **não** é publicado; os resultados agregados estão em `analysis/resultados_agregados/`.

## Dados e privacidade

O repositório contém apenas código, instrumentos, documentação e estatísticas agregadas. Não contém nomes, dados por participante, respostas abertas nem dados demográficos individuais. Os participantes são identificados nos documentos apenas por código (P001, P002, …).

## Licença

- Código: MIT (`LICENSE`).
- Documentos, questionários e resultados agregados: CC BY 4.0 (`LICENSE-CC-BY-4.0.md`).

## Como citar

Use os metadados de `CITATION.cff` (botão "Cite this repository" no GitHub), indicando a versão `v1.0.1`.
