import 'package:inject_annotation/inject_annotation.dart';

import 'analytics_service.dart';

/// Reports counter increments to the bound [AnalyticsService].
///
/// An ordinary `@inject` class in a library package: the app's generator
/// resolves it across the package boundary — its provider is emitted into
/// the app's `main.inject.dart`, no code generation runs in this package.
/// Consumers in the app (see `IncrementCounterUseCase`) inject it like any
/// local class.
@inject
@singleton
class IncrementTracker {
  const IncrementTracker(this._analytics);

  final AnalyticsService _analytics;

  void onIncrement(int newValue) =>
      _analytics.track('counter incremented to $newValue');
}
