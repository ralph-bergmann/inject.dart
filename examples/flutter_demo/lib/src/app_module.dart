import 'package:flutter/material.dart';
import 'package:inject_annotation/inject_annotation.dart';

const welcome = Qualifier(#welcome);

/// App-level bindings: metadata, welcome text, and the provision listener.
@module
class AppModule {
  /// Provides [AppInfo] **WITH** [@asynchronous].
  ///
  /// [@asynchronous] tells the generator to *unwrap* the [Future]:
  /// the **binding type** becomes [AppInfo] — not [Future<AppInfo>].
  ///
  /// Consequence: any other provider that *depends on* [AppInfo] receives
  /// it as plain [AppInfo], not as [Future<AppInfo>]. The generator inserts
  /// the necessary `await` inside the dependent provider automatically.
  ///
  /// See [provideWelcomeMessage], which injects [AppInfo] and therefore
  /// gets the already-resolved value — no `await` in that method.
  @provides
  @singleton
  @asynchronous
  Future<AppInfo> provideAppInfo() async {
    // In a real app this might load from SharedPreferences, a remote config,
    // or a platform channel — any genuinely async initialisation step.
    await Future.delayed(Duration.zero);
    return const AppInfo(name: 'Counter App', version: '1.0.0');
  }

  /// Provides the welcome message, composed from [AppInfo].
  ///
  /// **Return type vs. binding type — they are not the same thing.**
  /// The method signature returns [Future<String>]; that is plain Dart.
  /// [@asynchronous] is a separate instruction to inject.dart: *unwrap that
  /// [Future] and register the binding as [String]*. So the value that flows
  /// through the dependency graph is a ready [String] — even though the
  /// method itself returns a [Future<String>]. (Returning a [Future] does
  /// **not** by itself imply [@asynchronous]; see [provideInitialCount].)
  ///
  /// **Why [@asynchronous] is needed here.** This provider depends on
  /// [AppInfo], whose own binding is [@asynchronous]. Resolving it therefore
  /// requires awaiting the [AppInfo] future first, so the welcome [String]
  /// can only be produced asynchronously. [@asynchronous] declares exactly
  /// that — the generator inserts the `await` in the generated provider and
  /// propagates async-ness outward: the `appInfo` parameter arrives as a
  /// plain (already-resolved) [AppInfo], every consumer receives a ready
  /// [String], and the [MainComponent.welcomeMessage] entry point surfaces as
  /// [Future<String>] at the component boundary.
  ///
  /// **Contrast — [provideInitialCount]** returns [Future<int>] *without*
  /// [@asynchronous]: there the binding type stays [Future<int>], and the
  /// consumer ([CounterViewModel]) awaits it explicitly.
  @welcome
  @provides
  @singleton
  @asynchronous
  Future<String> provideWelcomeMessage(AppInfo appInfo) => Future.value('${appInfo.name} — tap + to start counting!');

  /// Provides the initial counter value **WITHOUT** [@asynchronous].
  ///
  /// The binding type is [Future<int>], not [int].
  /// [CounterViewModel] injects [Future<int>] and awaits it in [init] —
  /// demonstrating that without [@asynchronous] the consumer resolves the
  /// [Future] explicitly.
  ///
  /// Note: this provider is independent of [AppInfo], so it does **not**
  /// taint the [CounterViewModel] chain with async-ness. That independence
  /// is what keeps [ViewModelFactory<CounterViewModel>] working — it requires
  /// every provider in the ViewModel chain to be synchronously resolvable.
  @provides
  @singleton
  Future<int> provideInitialCount() => Future.value(0);

  /// Wires [CreationLogListener] as a provision hook.
  ///
  /// [@provisionListener] causes the generator to call [onProvision] after
  /// each [ChangeNotifier] the component provisions — here, every
  /// [CounterViewModel] instance, because [CounterViewModel] extends
  /// [ChangeNotifier].
  ///
  /// [@singleton] ensures every provisioned [ChangeNotifier] goes to the
  /// same listener.
  @provides
  @singleton
  @provisionListener
  CreationLogListener provideCreationLogListener() => CreationLogListener();
}

/// Minimal app metadata, loaded asynchronously via [AppModule.provideAppInfo].
class AppInfo {
  const AppInfo({required this.name, required this.version});

  final String name;
  final String version;

  @override
  String toString() => '$name v$version';
}

/// Observes every [ChangeNotifier] the component provisions.
///
/// Real-world uses: centralised logging, lifecycle tracking, metrics,
/// or keeping a list of resources to close on teardown.
class CreationLogListener implements ProvisionListener<ChangeNotifier> {
  int _count = 0;

  int get provisionCount => _count;

  @override
  void onProvision(ChangeNotifier instance) {
    _count++;
    debugPrint('inject.dart provisioned ${instance.runtimeType} (#$_count)');
  }
}
