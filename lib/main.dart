import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:tcc_task_manager/firebase_options.dart';
import 'app.dart';
import 'config/app_locale.dart';
import 'config/app_theme.dart';
import 'config/debug_admin.dart';
import 'data/experiment/admin_rtdb_bootstrap.dart';
import 'data/experiment/cross_architecture_task_bridge.dart';
import 'data/experiment/participant_remote_config_service.dart';
import 'data/hive/telemetry_event_model.dart';
import 'data/offline/sync_service.dart';
import 'data/offline/task_hive_model.dart';
import 'data/study_repository_factory.dart';
import 'domain/models/participant_study_config.dart';
import 'domain/models/profile_questionnaire.dart';
import 'domain/repositories/task_repository.dart';
import 'providers/study_session_controller.dart';
import 'providers/task_provider.dart';
import 'screens/participant_onboarding_screen.dart';
import 'screens/participant_profile_screen.dart';
import 'services/network_simulator.dart';
import 'services/notification_service.dart';
import 'services/telemetry_service.dart';
import 'utils/participant_loader.dart';
import 'utils/participant_name_match.dart';

/// Evita chamar [FirebaseFirestore.settings] repetidamente a cada rebuild.
bool? _firestorePersistenceOnlineFirst;

/// Ponto de entrada único do estudo (app único, arquitetura remota).
///
/// Em **debug**, o app inicia como investigador: identidade `P000` (`kDebugAdminParticipantId`),
/// sem onboarding, e semeia o RTDB se ainda não existir estrutura mínima.
///
/// O Firebase **não** é inicializado em [main] antes do primeiro [runApp]: nalguns dispositivos
/// Android o MethodChannel falha (`channel-error`) se [Firebase.initializeApp] correr cedo
/// demais. A inicialização corre em [_StudyAppEntryState._afterFirstFrame], após o primeiro frame.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _StudyAppEntry());
}

Future<void> _ensureFirebaseInitialized() async {
  await Future<void>.delayed(Duration.zero);

  const maxAttempts = 6;
  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      return;
    } on FirebaseException catch (e) {
      if (e.code == 'duplicate-app') return;
      rethrow;
    } on PlatformException catch (e) {
      final isChannel = e.code == 'channel-error';
      if (!isChannel || attempt == maxAttempts) rethrow;
      await Future<void>.delayed(Duration(milliseconds: 40 * attempt));
    }
  }
}

/// Primeiro frame: mostra splash; em seguida inicializa Firebase e delega ao fluxo real.
class _StudyAppEntry extends StatefulWidget {
  const _StudyAppEntry();

  @override
  State<_StudyAppEntry> createState() => _StudyAppEntryState();
}

class _StudyAppEntryState extends State<_StudyAppEntry> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_afterFirstFrame());
    });
  }

  Future<void> _afterFirstFrame() async {
    try {
      await _ensureFirebaseInitialized();
      await _continueStudyStartup();
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('Study startup failed: $e\n$st');
      }
      if (!mounted) return;
      runApp(
        MaterialApp(
          locale: AppLocale.defaultLocale,
          supportedLocales: AppLocale.supportedLocales,
          localizationsDelegates: AppLocale.delegates,
          theme: AppTheme.light(),
          home: Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Nao foi possivel iniciar o Firebase.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    Text('$e', textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: AppLocale.defaultLocale,
      supportedLocales: AppLocale.supportedLocales,
      localizationsDelegates: AppLocale.delegates,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('A iniciar…'),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _continueStudyStartup() async {
  if (kDebugMode) {
    await AdminRtdbBootstrap.ensureSeed(FirebaseDatabase.instance);
    await saveParticipantId(kDebugAdminParticipantId);
    await _bootstrapWithParticipantId(kDebugAdminParticipantId);
    return;
  }

  final existingId = await loadParticipantId();
  if (existingId == null) {
    runApp(const _PreStudyFlowApp());
    return;
  }
  await _bootstrapWithParticipantId(existingId);
}

// --- Primeira instalação: código + perfil ---------------------------------

class _PreStudyFlowApp extends StatefulWidget {
  const _PreStudyFlowApp();

  @override
  State<_PreStudyFlowApp> createState() => _PreStudyFlowAppState();
}

class _PreStudyFlowAppState extends State<_PreStudyFlowApp> {
  String? _participantId;
  String? _registeredNameForProfile;
  Object? _loadError;

  Future<void> _onCodeSubmitted(String digits) async {
    setState(() => _loadError = null);
    final id = buildParticipantIdFromNumber(digits);
    try {
      final remote = ParticipantRemoteConfigService();
      final cfg = await remote.fetchParticipant(id);
      if (cfg == null) {
        setState(() {
          _loadError =
              'Participante nao encontrado. Verifique o codigo ou o RTDB.';
        });
        return;
      }
      if (cfg.profileComplete) {
        await saveParticipantId(id);
        await _bootstrapWithParticipantId(id);
        return;
      }
      setState(() {
        _participantId = id;
        _registeredNameForProfile = cfg.registeredParticipantName;
      });
    } catch (e) {
      setState(() => _loadError = e.toString());
    }
  }

  void _returnToCodeEntry(String message) {
    setState(() {
      _participantId = null;
      _registeredNameForProfile = null;
      _loadError = message;
    });
  }

  Future<void> _onProfileSubmitted(ProfileQuestionnaire answers) async {
    final id = _participantId;
    if (id == null) return;
    setState(() => _loadError = null);
    try {
      final remote = ParticipantRemoteConfigService();
      final cfg = await remote.fetchParticipant(id);
      if (cfg == null) {
        _returnToCodeEntry(
          'Participante nao encontrado. Verifique o codigo ou o RTDB.',
        );
        return;
      }
      final expected = cfg.registeredParticipantName;
      if (expected != null &&
          expected.isNotEmpty &&
          !participantNamesMatch(answers.name, expected)) {
        _returnToCodeEntry(
          'O nome informado nao corresponde ao cadastrado para este codigo. '
          'Verifique o codigo e tente novamente.',
        );
        return;
      }
      await remote.saveProfileQuestionnaire(id, answers);
      await saveParticipantId(id);
      await _bootstrapWithParticipantId(id);
    } catch (e) {
      setState(() => _loadError = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Identificacao do participante',
      locale: AppLocale.defaultLocale,
      supportedLocales: AppLocale.supportedLocales,
      localizationsDelegates: AppLocale.delegates,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      debugShowCheckedModeBanner: false,
      home: Builder(
        builder: (context) {
          if (_loadError != null) {
            return Scaffold(
              body: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_loadError.toString(), textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => setState(() {
                          _loadError = null;
                          _participantId = null;
                          _registeredNameForProfile = null;
                        }),
                        child: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
          if (_participantId != null) {
            return ParticipantProfileScreen(
              registeredName: _registeredNameForProfile,
              onSubmit: _onProfileSubmitted,
            );
          }
          return ParticipantOnboardingScreen(onSubmit: _onCodeSubmitted);
        },
      ),
    );
  }
}

Future<void> _bootstrapWithParticipantId(String participantId) async {
  await Hive.initFlutter();
  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(TaskHiveModelAdapter());
  }
  if (!Hive.isAdapterRegistered(10)) {
    Hive.registerAdapter(TelemetryEventModelAdapter());
  }
  final tasksBox = await Hive.openBox<TaskHiveModel>('tasks');
  await Hive.openBox<TelemetryEventModel>('telemetry');

  final remote = ParticipantRemoteConfigService();
  final initialFetch = await remote.fetchParticipant(participantId);
  if (initialFetch == null) {
    runApp(
      MaterialApp(
        locale: AppLocale.defaultLocale,
        supportedLocales: AppLocale.supportedLocales,
        localizationsDelegates: AppLocale.delegates,
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Nao foi possivel carregar a configuracao remota.\n'
                'Verifique RTDB e o nó participants/$participantId.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
    return;
  }
  final initialCfg =
      await remote.ensureEnrollmentMetaAndPhaseTally(participantId);
  final studyStart = initialCfg.studyStartedAt ?? DateTime.now().toUtc();
  await saveStudyStartDateUtc(studyStart);

  final session = StudySessionController(
    participantId: participantId,
    studyStartDate: studyStart,
    remote: remote,
    onArchitectureTransition: (oldArch, newArch) async {
      if (oldArch == ParticipantStudyConfig.kOfflineFirst &&
          newArch == ParticipantStudyConfig.kOnlineFirst) {
        await CrossArchitectureTaskBridge.flushPendingToFirestore(
          tasksBox: tasksBox,
          participantId: participantId,
        );
      }
    },
  );
  await session.refreshRemoteConfig();
  final initial = session.remoteConfig;
  if (initial == null) {
    runApp(
      MaterialApp(
        locale: AppLocale.defaultLocale,
        supportedLocales: AppLocale.supportedLocales,
        localizationsDelegates: AppLocale.delegates,
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Nao foi possivel carregar a configuracao remota.\n'
                'Verifique RTDB e o nó participants/$participantId.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
    return;
  }

  await TelemetryService.instance.init(
    participantId: participantId,
    prototype: initial.architecture,
    studyStartDate: studyStart,
    realtimeDatabase: FirebaseDatabase.instance,
    architectureResolver: () => session.prototype,
    telemetryEnabledResolver: () => session.telemetryEnabled,
  );

  NetworkSimulator.instance.start();
  await NotificationService.initialize();
  if (!kDebugMode) {
    unawaited(NotificationService.scheduleEngagementRemindersIfNeeded());
  }

  runApp(_StudyRoot(session: session, tasksBox: tasksBox));
  // Android 13+: o pedido de POST_NOTIFICATIONS precisa de manifest + Activity;
  // após o primeiro frame do ecrã principal o diálogo do sistema costuma aparecer.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(NotificationService.requestAndroidPostNotificationsPermission());
    unawaited(NotificationService.requestBatteryOptimizationExemption());
  });
}

class _StudyRoot extends StatelessWidget {
  const _StudyRoot({required this.session, required this.tasksBox});

  final StudySessionController session;
  final Box<TaskHiveModel> tasksBox;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<StudySessionController>.value(
      value: session,
      child: Consumer<StudySessionController>(
        builder: (context, s, _) {
          final cfg = s.remoteConfig;
          if (cfg == null) {
            return MaterialApp(
              locale: AppLocale.defaultLocale,
              supportedLocales: AppLocale.supportedLocales,
              localizationsDelegates: AppLocale.delegates,
              theme: AppTheme.light(),
              home: const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              ),
            );
          }
          if (!cfg.appEnabled) {
            return MaterialApp(
              locale: AppLocale.defaultLocale,
              supportedLocales: AppLocale.supportedLocales,
              localizationsDelegates: AppLocale.delegates,
              theme: AppTheme.light(),
              home: const Scaffold(
                body: Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Este estudo terminou ou a sua participacao foi encerrada.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ),
              ),
            );
          }

          _applyFirestorePersistence(cfg.isOnlineFirst);

          final bundle = StudyRepositoryFactory.build(
            cfg: cfg,
            tasksBox: tasksBox,
            participantId: s.participantId,
          );
          final active = bundle.activeRepository;
          final offlineForSync = bundle.offlineRepositoryForSync;

          return MultiProvider(
            key: ValueKey<String>('${s.participantId}_${cfg.architecture}'),
            providers: [
              ChangeNotifierProvider<TaskProvider>(
                create: (_) => TaskProvider(active),
              ),
              Provider<TaskRepository>.value(value: active),
              if (offlineForSync != null)
                Provider<SyncService>(
                  lazy: false,
                  create: (_) {
                    final sync = SyncService(
                      localRepo: offlineForSync,
                      participantId: s.participantId,
                    )..start();
                    return sync;
                  },
                  dispose: (_, sync) => sync.dispose(),
                ),
            ],
            child: const App(),
          );
        },
      ),
    );
  }
}

void _applyFirestorePersistence(bool onlineFirst) {
  if (_firestorePersistenceOnlineFirst == onlineFirst) return;
  _firestorePersistenceOnlineFirst = onlineFirst;
  FirebaseFirestore.instance.settings = Settings(
    persistenceEnabled: !onlineFirst,
  );
}
