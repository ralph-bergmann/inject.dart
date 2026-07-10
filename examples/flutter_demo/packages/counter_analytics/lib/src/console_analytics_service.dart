import 'package:flutter/foundation.dart';

import 'analytics_service.dart';

/// Default [AnalyticsService] implementation: prints to the debug console.
///
/// A plain class — no inject.dart annotations. [AnalyticsModule] constructs
/// it, which is the usual shape for infrastructure packages: the module is
/// the wiring surface, the implementation stays an ordinary class (often one
/// wrapping a third-party SDK that cannot carry `@inject` anyway).
class ConsoleAnalyticsService implements AnalyticsService {
  const ConsoleAnalyticsService({required this.appName});

  /// Used to prefix every event — supplied by the app via
  /// [AnalyticsModule]'s constructor.
  final String appName;

  @override
  void track(String event) => debugPrint('[$appName analytics] $event');
}
