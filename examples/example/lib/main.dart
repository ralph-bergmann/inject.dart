// A condensed single-file showcase of inject.dart + inject_flutter.
//
// pub.dev renders only one example file, so this file intentionally stays
// small: it covers the key concepts and uses comments to point readers to
// `flutter_demo` for everything else.
//
// Key concepts shown:
//   1. @Component + @module — the DI graph root and external-type bindings.
//   2. @provides @singleton — a module-provided singleton.
//   3. @inject — constructor injection wired by the generator.
//   4. @assistedInject — compile-time DI combined with runtime parameters.
//   5. ViewModelFactory<T> — the inject_flutter bridge between DI and
//      Flutter's widget lifecycle.
//   6. @subcomponent — an encapsulated child graph whose bindings stay
//      invisible to the parent; only a re-exported service crosses the
//      boundary.
//
// Concepts omitted for space (all shown in `flutter_demo`):
//   • Two-line Qualifier form for same-Dart-type disambiguation.
//   • @asynchronous vs. raw Future<T> binding — how inject.dart propagates
//     async-ness to component entry points.
//   • Provider<T> as a component entry point — lazy / on-demand access.
//   • @provisionListener — a singleton hook fired after every provisioned
//     ChangeNotifier.
//   • Use Case layer — the optional Logic layer between Repository and ViewModel.
//   • Test @Component with module override — later modules win.

import 'package:flutter/material.dart';
import 'package:inject_annotation/inject_annotation.dart';
import 'package:inject_flutter/inject_flutter.dart';

import 'main.inject.dart' as g;

part 'main.factory.dart';

void main() {
  final component = MainComponent.create();
  runApp(component.myAppFactory.create());
}

// ─── Component ───────────────────────────────────────────────────────────────

/// Root of the dependency graph.
///
/// [@Component([AppModule])] tells the generator to emit
/// `MainComponent$Component` in `main.inject.dart`, pre-wired against the
/// providers declared in [AppModule]. The static [create] alias hides the
/// generated class name.
///
/// See `flutter_demo` → `MainComponent` for a version with multiple modules,
/// qualified bindings, async entry points, and a [Provider<T>] entry point.
@Component([AppModule])
abstract class MainComponent {
  static const create = g.MainComponent$Component.create;

  @inject
  MyAppFactory get myAppFactory;

  /// Re-exported from the [BackupSubcomponent] — see the module provider in
  /// [AppModule]. The [BackupClient] behind it stays private to the subgraph.
  @inject
  BackupService get backupService;
}

// ─── Module ──────────────────────────────────────────────────────────────────

/// Hosts external bindings that cannot use [@inject].
///
/// [Database] is a simulated third-party type — it has no [@inject]
/// annotation. A [@module] bridges it into the graph via a [@provides] method.
///
/// See `flutter_demo` → `DatabaseModule` for a version that uses two-line
/// [Qualifier]s to disambiguate two [String] bindings of the same Dart type.
@Module(subcomponents: [BackupSubcomponent])
class AppModule {
  @provides
  @singleton
  Database provideDatabase() => Database();

  /// Re-exports the subcomponent's service into the parent graph: the
  /// injected [BackupSubcomponentFactory] (a parent binding, generated into
  /// `main.factory.dart`) creates the child graph, and only [BackupService]
  /// crosses the boundary. Note the child binds it with a [Qualifier] so this
  /// unqualified parent binding does not collide with the child's own key.
  @provides
  @singleton
  BackupService provideBackupService(BackupSubcomponentFactory factory) => factory.create().backupService;
}

// ─── Encapsulated subgraph — @subcomponent ───────────────────────────────────

/// Marks the subcomponent-internal [BackupService] binding; the parent
/// re-export above is unqualified, so the two keys never collide.
const internalBackup = Qualifier(#internalBackup);

/// Private to the backup subgraph: the parent graph cannot inject
/// [BackupClient] — trying to do so fails at build time with a diagnostic
/// that names [BackupSubcomponent] as the nearby source.
class BackupClient {
  const BackupClient(this.database);

  final Database database; // parent binding, read through the parent graph

  Future<void> upload() async {
    // Simulated network call.
  }
}

/// The only type that leaves the subgraph (via the re-export in [AppModule]).
class BackupService {
  const BackupService(this._client);

  final BackupClient _client;

  Future<void> backup() => _client.upload();
}

/// Providers of the child graph. [BackupClient] consumes the parent's
/// [Database] transparently; `@singleton` here means once per subcomponent
/// instance, not app-wide.
@module
class BackupModule {
  @provides
  @singleton
  BackupClient provideClient(Database database) => BackupClient(database);

  @provides
  @internalBackup
  BackupService provideService(BackupClient client) => BackupService(client);
}

/// The encapsulated child graph. Installed on [AppModule] via
/// `@Module(subcomponents: [...])`, which makes the generated
/// [BackupSubcomponentFactory] available as a binding in the parent graph.
///
/// This example calls `factory.create()` exactly once, eagerly, via the
/// [AppModule.provideBackupService] re-export above — the "hide an
/// implementation detail behind a public service" flavor of subcomponents.
/// The *other* flavor uses the identical mechanism differently: call
/// `factory.create()` again whenever a new scope should start (e.g. after a
/// user logs in) and drop the reference when it ends (on logout) — every
/// call produces an independent instance with its own `@singleton`
/// bindings, released together when nothing references it anymore. See the
/// README's "Encapsulating subgraphs" section for that pattern in detail.
@Subcomponent([BackupModule])
abstract class BackupSubcomponent {
  @internalBackup
  BackupService get backupService;
}

// ─── Data layer ──────────────────────────────────────────────────────────────

/// Simulates a third-party database library.
///
/// Because it is a third-party type it cannot be annotated with [@inject].
/// [AppModule] provides it instead.
class Database {
  int _count = 0;

  Future<void> updateCount(int count) async => _count = count;

  Future<int> selectCount() => Future.value(_count);
}

/// Counter repository.
///
/// [@inject] tells the generator to wire [CounterRepository] via its
/// constructor. [@singleton] ensures one shared instance.
///
/// See `flutter_demo` → `CounterRepository` and `IncrementCounterUseCase` for
/// the full layered version with a separate domain model ([Counter]).
@inject
@singleton
class CounterRepository {
  CounterRepository({required this._database});

  final Database _database;

  Future<int> get count => _database.selectCount();

  Future<void> increment() async {
    final current = await _database.selectCount();
    await _database.updateCount(current + 1);
  }
}

// ─── ViewModel ───────────────────────────────────────────────────────────────

/// ViewModel for [HomePage].
///
/// [@inject] wires its [CounterRepository] dependency via constructor
/// injection. Extending [ChangeNotifier] lets [ViewModelFactory] subscribe
/// widgets to state changes.
///
/// See `flutter_demo` → `CounterViewModel` for the version that also injects
/// a raw [Future<String>] binding (without [@asynchronous]) and resolves it
/// lazily in [init].
@inject
class CounterViewModel extends ChangeNotifier {
  CounterViewModel({required this._repository});

  final CounterRepository _repository;

  int count = 0;

  Future<void> increment() async {
    await _repository.increment();
    count = await _repository.count;
    notifyListeners();
  }
}

// ─── Views ───────────────────────────────────────────────────────────────────

/// Root widget.
///
/// [@assistedInject] supplies [homePageFactory] from the graph at build time;
/// [key] is provided at runtime by the caller. The generated [MyAppFactory]
/// hides the DI-managed parameters.
class MyApp extends StatelessWidget {
  @assistedInject
  const MyApp({@assisted super.key, required this.homePageFactory});

  final HomePageFactory homePageFactory;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Counter App',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple), useMaterial3: true),
      home: homePageFactory.create(title: 'Counter Demo'),
    );
  }
}

/// Counter home screen.
///
/// [@assistedInject] supplies [viewModelFactory] from the graph; [key] and
/// [title] come from the caller at runtime.
///
/// [ViewModelFactory<CounterViewModel>] is the inject_flutter lifecycle
/// bridge: it creates the VM in [State.initState], wires [ListenableBuilder]
/// for rebuilds, and disposes the VM in [State.dispose] — all without the
/// View knowing about any of it.
///
/// See `flutter_demo` → `HomePage` for the full version, including an [init]
/// callback that awaits a [Future<String>] binding.
class HomePage extends StatelessWidget {
  @assistedInject
  const HomePage({@assisted super.key, @assisted required this.title, required this.viewModelFactory});

  final String title;
  final ViewModelFactory<CounterViewModel> viewModelFactory;

  @override
  Widget build(BuildContext context) {
    return viewModelFactory(
      builder: (context, vm, _) => Scaffold(
        appBar: AppBar(backgroundColor: Theme.of(context).colorScheme.inversePrimary, title: Text(title)),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('You have pushed the button this many times:'),
              Text('${vm.count}', style: Theme.of(context).textTheme.headlineMedium),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: vm.increment,
          tooltip: 'Increment',
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
