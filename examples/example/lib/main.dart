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
}

// ─── Module ──────────────────────────────────────────────────────────────────

/// Hosts external bindings that cannot use [@inject].
///
/// [Database] is a simulated third-party type — it has no [@inject]
/// annotation. A [@module] bridges it into the graph via a [@provides] method.
///
/// See `flutter_demo` → `DatabaseModule` for a version that uses two-line
/// [Qualifier]s to disambiguate two [String] bindings of the same Dart type.
@module
class AppModule {
  @provides
  @singleton
  Database provideDatabase() => Database();
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
