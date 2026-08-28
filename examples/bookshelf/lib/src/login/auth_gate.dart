import 'package:bookshelf_core/bookshelf_core.dart';
import 'package:flutter/material.dart';
import 'package:inject_annotation/inject_annotation.dart';
import 'package:inject_flutter/inject_flutter.dart';

import '../session/session_component.dart';
import 'login_page.dart';

part 'auth_gate.factory.dart';

/// Owns the session lifecycle: shows [LoginPage] while signed out, and
/// mounts a [SubcomponentBuilder] — keyed on the [Credentials] that produced
/// it — below this branch point once a login succeeds.
///
/// Logging out sets [_credentials] back to `null`, which unmounts the
/// [SubcomponentBuilder] subtree (swapping back to [LoginPage]) and lets it
/// call [SubcomponentBuilder.dispose] naturally — no manual session-field
/// bookkeeping needed. Once nothing references the [SessionComponent]
/// instance, [Credentials] and the session's `BookRepository` singleton
/// become unreachable — they were never stored in the root graph, so there
/// is nothing left to clean up there either.
class AuthGate extends StatefulWidget {
  @assistedInject
  const AuthGate({@assisted super.key, required this.loginPageFactory, required this.sessionFactory});

  final LoginPageFactory loginPageFactory;
  final SessionComponentFactory sessionFactory;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  Credentials? _credentials;

  void _onLoggedIn(Credentials credentials) {
    // [LoginPage] awaits the login call before invoking this callback — the
    // widget may have been removed from the tree in the meantime.
    if (!mounted) return;
    setState(() => _credentials = credentials);
  }

  void _logout() => setState(() => _credentials = null); // unmounts the SubcomponentBuilder subtree

  @override
  Widget build(BuildContext context) {
    final Credentials? credentials = _credentials;
    if (credentials == null) {
      return widget.loginPageFactory.create(onLoggedIn: _onLoggedIn);
    }
    return SubcomponentBuilder<SessionComponent>(
      // A fresh login — even with the same username/password — gets its own
      // `Credentials` instance, so keying on it is enough to force a new
      // `SessionComponent` (and therefore a new `BookRepository` singleton)
      // every time, without ever needing to compare credentials by value.
      key: ValueKey(credentials),
      create: () => widget.sessionFactory.create(credentials),
      builder: (context, session, _) => session.homePageFactory.create(onLogout: _logout),
    );
  }
}
