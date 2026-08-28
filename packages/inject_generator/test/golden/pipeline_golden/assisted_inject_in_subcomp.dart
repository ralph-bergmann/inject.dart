import 'package:inject_annotation/inject_annotation.dart';

import 'assisted_inject_in_subcomp.inject.dart' as g;

part 'assisted_inject_in_subcomp.factory.dart';

// Assisted injection inside a subcomponent: Session mixes an @assisted
// runtime parameter with a parent binding (Logger). The synthesized
// SessionFactory is generated into the child graph and consumes the parent
// binding transparently.

void main() {}

// ── Parent component ─────────────────────────────────────────────────

@inject
@singleton
class Logger {
  const Logger();
}

@Module(subcomponents: [AuthSubcomponent])
class AppModule {}

@Component([AppModule])
abstract class AppComponent {
  static const create = g.AppComponent$Component.create;

  Logger get logger;

  AuthSubcomponentFactory get authFactory;
}

// ── Subcomponent ─────────────────────────────────────────────────────

class Session {
  @assistedInject
  const Session(this.logger, @assisted this.userId);

  final Logger logger;
  final String userId;
}

@subcomponent
abstract class AuthSubcomponent {
  SessionFactory get sessionFactory;
}
