import 'package:inject_annotation/inject_annotation.dart';

import 'umbrella_module_diamond_include.inject.dart' as g;

// I/O-matrix row: "Diamond (A includes B and C; both B and C include D)" —
// TopModule includes LeftModule and RightModule, and both of those include
// SharedModule. SharedModule's provider must appear exactly once in the
// generated graph (deduplicated by type) — not twice, and not flagged as a
// duplicate-binding conflict.

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
class SharedModule {
  @provides
  int provideValue() => 1;
}

@Module(includes: [SharedModule])
class LeftModule {}

@Module(includes: [SharedModule])
class RightModule {}

@Module(includes: [LeftModule, RightModule])
class TopModule {}
