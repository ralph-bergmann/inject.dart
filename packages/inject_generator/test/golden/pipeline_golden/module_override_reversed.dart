import 'package:inject_annotation/inject_annotation.dart';

import 'module_override_reversed.inject.dart' as g;

// Mirror-Pair B: @Component([TestModule, AppModule]) — AppModule wins.
// _message$Provider must reference _appModule.message(), not _testModule.message().
//
// Mirror-pair to module_override.dart. Any sort or reordering in _buildBindings()
// makes both goldens identical → test fails. This is the killer assertion against
// alphabetical-sort regressions.

void main() {
  final comp = AppComponent.create();
  print(comp.message);
}

@Component([TestModule, AppModule])
abstract class AppComponent {
  static const create = g.AppComponent$Component.create;

  @inject
  String get message;
}

@module
class AppModule {
  @provides
  String message() => 'app';
}

@module
class TestModule {
  @provides
  String message() => 'test';
}
