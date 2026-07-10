import 'package:counter_analytics/counter_analytics.dart';
import 'package:flutter/material.dart';
import 'package:inject_annotation/inject_annotation.dart';

import 'main.inject.dart' as g;
import 'src/app_module.dart';
import 'src/data/repositories/counter_repository.dart';
import 'src/data/services/database.dart';
import 'src/features/app/my_app.dart';

void main() async {
  // [AnalyticsModule] has no default constructor (it needs the app name),
  // so the generated `create` factory REQUIRES an instance — passing a
  // pre-configured module is how runtime configuration enters the graph.
  final component = MainComponent.create(
    analyticsModule: const AnalyticsModule('Counter App'),
  );

  // [welcomeMessage] is [Future<String>] — await is required at this
  // entry-point boundary even though both [provideAppInfo] and
  // [provideWelcomeMessage] are marked [@asynchronous].
  //
  // [@asynchronous] means: "the **binding type** is T (not Future<T>) —
  // intermediate providers receive the already-resolved value directly".
  // [provideWelcomeMessage] injects [AppInfo], not [Future<AppInfo>].
  //
  // But async-ness still **propagates upward to the entry point**: the
  // component getter is typed [Future<String>] because the resolution chain
  // is async. You cross back into async-world at the boundary and must await.
  //
  // Contrast with [component.myAppFactory]: it is synchronous because the
  // [CounterViewModel] chain depends on [Future<int>] from
  // [provideInitialCount] — which has no transitive @asynchronous deps.
  debugPrint(await component.welcomeMessage);

  runApp(component.myAppFactory.create());
}

/// Root of the dependency graph.
///
/// Three modules cover distinct concerns:
/// - [AppModule]: app metadata ([@asynchronous] [AppInfo]), welcome message
///   (also [@asynchronous], injects [AppInfo] directly), initial count (raw
///   [Future<int>] **without** [@asynchronous]), and the [@provisionListener].
/// - [DatabaseModule]: qualified [String] config values and the [Database]
///   singleton.
/// - [AnalyticsModule]: from the **local `counter_analytics` package** —
///   modules from other packages are listed exactly like local ones. This is
///   how a monorepo marries its infrastructure packages (api, database,
///   auth, analytics, ...) into one graph. Because [AnalyticsModule] has no
///   default constructor, `create` requires a configured instance (see
///   `main()`).
///
/// **Module order matters.** A binding in a later module overrides an earlier
/// module's binding for the same (type, qualifier) pair. The test components
/// in [test/] exploit this: they append a module that provides a fake
/// [Database], and that binding wins over [DatabaseModule]'s real one.
@Component([AppModule, DatabaseModule, AnalyticsModule])
abstract class MainComponent {
  static const create = g.MainComponent$Component.create;

  /// Root widget factory.
  ///
  /// Synchronous: the [CounterViewModel] chain depends on [Future<int>]
  /// from [AppModule.provideInitialCount], which has **no** transitive
  /// [@asynchronous] deps, so async-ness does not propagate here.
  ///
  /// If [CounterViewModel] depended on something in the [AppInfo] chain
  /// it would break [ViewModelFactory], which requires synchronous provider
  /// resolution. The design intentionally keeps [@asynchronous] bindings
  /// out of the ViewModel chain.
  @inject
  MyAppFactory get myAppFactory;

  /// Welcome message composed from [AppInfo].
  ///
  /// [Future<String>] because the resolution chain includes [@asynchronous]
  /// providers ([AppInfo] → [String]); async-ness propagates to this entry
  /// point. [AppModule.provideWelcomeMessage] receives [AppInfo] directly
  /// — the generator handles the `await` transparently in the generated
  /// provider.
  @welcome
  @inject
  Future<String> get welcomeMessage;

  /// Lazy accessor for the shared [CounterRepository].
  ///
  /// [Provider<T>] as a component entry point defers creation to call time.
  /// Useful when you want to pass the provider reference to non-DI code,
  /// need lazy initialisation, or want to produce multiple independent
  /// instances. Since [CounterRepository] is a [@singleton], every [.get()]
  /// call returns the same instance.
  @inject
  Provider<CounterRepository> get counterRepositoryProvider;

  /// Singleton provision listener.
  @inject
  CreationLogListener get creationLogListener;
}
