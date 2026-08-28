import 'package:inject_annotation/inject_annotation.dart';

import 'umbrella_module_transitive_include.inject.dart' as g;

// I/O-matrix row: "Transitive include (A includes B includes C)" — the
// component lists only TopModule, which includes MiddleModule, which
// includes InnerModule. All three modules' providers must be present in
// the generated graph.

void main() {
  final comp = AppComponent.create();
  print(comp.value);
}

@Component([TopModule])
abstract class AppComponent {
  static const create = g.AppComponent$Component.create;

  @inject
  int get value;
}

@module
class InnerModule {
  @provides
  int provideValue() => 1;
}

@Module(includes: [InnerModule])
class MiddleModule {}

@Module(includes: [MiddleModule])
class TopModule {}
