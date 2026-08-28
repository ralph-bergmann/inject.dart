import 'package:inject_annotation/inject_annotation.dart';

import 'analytics_service.dart';
import 'console_analytics_service.dart';

/// The package's module — its public wiring surface.
///
/// The app installs this package by listing the module in its component,
/// exactly like a local module:
///
/// ```dart
/// @Component([AppModule, DatabaseModule, AnalyticsModule])
/// abstract class MainComponent { ... }
/// ```
///
/// Because this module has **no default constructor** (it needs [_appName]),
/// the generated `create` factory makes the parameter *required* — the app
/// must pass a configured instance:
///
/// ```dart
/// MainComponent.create(
///   analyticsModule: const AnalyticsModule('Counter App'),
/// );
/// ```
///
/// This is the intended channel for runtime configuration: the compiler
/// forces the wiring, and the configuration value never needs to live inside
/// the graph as a binding of its own.
@module
class AnalyticsModule {
  const AnalyticsModule(this._appName);

  final String _appName;

  /// Binds the [AnalyticsService] interface to the package's default
  /// implementation. Consumers inject [AnalyticsService] and never learn
  /// which implementation they got — a later module in the component list
  /// (or a test module) can override this binding without touching this
  /// package.
  @provides
  @singleton
  AnalyticsService provideAnalyticsService() => ConsoleAnalyticsService(appName: _appName);
}
