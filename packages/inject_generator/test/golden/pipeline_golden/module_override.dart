import 'package:inject_annotation/inject_annotation.dart';

import 'module_override.inject.dart' as g;

// Mirror-Pair A: @Component([AppModule, TestModule]) — TestModule wins.
// _message$Provider must reference _testModule.message(), not _appModule.message().
// See module_override_reversed.dart for the pair that proves order is the discriminator.

void main() {
  final comp = AppComponent.create();
  print(comp.message);
}

@Component([AppModule, TestModule])
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
