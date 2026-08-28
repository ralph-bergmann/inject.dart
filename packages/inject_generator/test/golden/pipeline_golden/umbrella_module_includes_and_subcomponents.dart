import 'package:inject_annotation/inject_annotation.dart';

import 'umbrella_module_includes_and_subcomponents.inject.dart' as g;

part 'umbrella_module_includes_and_subcomponents.factory.dart';

// I/O-matrix row: "`includes:` + `subcomponents:` on the same module" —
// CombinedModule both includes ExtraModule (folding its provider into the
// parent graph) and installs LabelSubcomponent as a subcomponent factory
// binding. The two parameters compose independently: ExtraModule's provider
// reaches the parent directly, while LabelSubcomponent is only reachable
// through the synthesized factory. The subcomponent's internal label is
// qualified so its re-export at the parent (unqualified) does not collide
// with it — mirrors component_with_subcomp_encapsulation.dart's pattern.

void main() {}

const internal = Qualifier(#internal);

@module
class ExtraModule {
  @provides
  int provideExtra() => 42;
}

@module
class LabelModule {
  @provides
  @internal
  String provideLabel() => 'sub-label';
}

@Subcomponent([LabelModule])
abstract class LabelSubcomponent {
  @internal
  String get label;
}

@Module(includes: [ExtraModule], subcomponents: [LabelSubcomponent])
class CombinedModule {
  @provides
  String provideExportedLabel(LabelSubcomponentFactory factory) => factory.create().label;
}

@Component([CombinedModule])
abstract class AppComponent {
  static const create = g.AppComponent$Component.create;

  @inject
  int get extra;

  @inject
  String get exportedLabel;
}
