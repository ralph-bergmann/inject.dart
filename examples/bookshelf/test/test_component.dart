import 'package:bookshelf/src/app/app_module.dart';
import 'package:bookshelf/src/login/auth_gate.dart';
import 'package:bookshelf/src/session/session_component.dart';
import 'package:bookshelf_auth/bookshelf_auth.dart';
import 'package:bookshelf_core/bookshelf_core.dart';
import 'package:inject_annotation/inject_annotation.dart';

import 'fake_books_api.dart';
import 'test_component.inject.dart' as g;

/// Test-parent seam: swaps [ApiModule] (real) for [FakeApiModule] while
/// reusing the exact same [AuthModule] and [AppModule] — and therefore the
/// same session-install point — as `MainComponent`. Anything created under
/// this component, including a session, observes the fake backend through
/// the child graph without either module knowing a test is running.
@Component([CoreModule, FakeApiModule, AuthModule, AppModule])
abstract class TestComponent {
  static const create = g.TestComponent$Component.create;

  @inject
  AuthGateFactory get authGateFactory;

  @inject
  SessionComponentFactory get sessionFactory;
}
