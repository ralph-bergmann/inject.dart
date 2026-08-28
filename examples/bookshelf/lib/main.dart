import 'package:bookshelf_api/bookshelf_api.dart';
import 'package:bookshelf_auth/bookshelf_auth.dart';
import 'package:bookshelf_core/bookshelf_core.dart';
import 'package:flutter/material.dart';
import 'package:inject_annotation/inject_annotation.dart';

import 'main.inject.dart' as g;
import 'src/app/app_module.dart';
import 'src/login/auth_gate.dart';

void main() {
  // ApiModule has no default constructor, so MainComponent.create requires
  // a configured instance — the compiler enforces the base URL argument.
  final MainComponent component = MainComponent.create(
    apiModule: const ApiModule('https://bookshelf.example.com'),
  );
  runApp(MaterialApp(title: 'Bookshelf', home: component.authGateFactory.create()));
}

/// Root of the dependency graph.
///
/// [CoreModule] is listed exactly once here; [ApiModule] and [AuthModule]
/// both consume its [Logger] singleton without redeclaring it. [AppModule]
/// contributes no bindings of its own — its sole job is installing the
/// session subcomponent (see `src/app/app_module.dart`).
@Component([CoreModule, ApiModule, AuthModule, AppModule])
abstract class MainComponent {
  static const create = g.MainComponent$Component.create;

  @inject
  AuthGateFactory get authGateFactory;
}
