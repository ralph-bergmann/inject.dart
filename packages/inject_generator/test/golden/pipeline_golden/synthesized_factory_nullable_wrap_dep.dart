// Isolated coverage: nullable-wrap on a synthesized factory type
// without multi-ctor / qualifier noise.
//
// Espresso has a single @assistedInject constructor that depends on
// `LatteFactory?` — itself a synthesized factory from `Latte`'s @assistedInject
// constructor. The inject-builder must resolve `LatteFactory?` from the
// non-nullable `LatteFactory` binding via nullable-widening, without any
// adapter code; Dart implicit-widens at the call site.
//
// Sibling fixture `synthesized_multi_ctor_nullable_wrapped_factory_dep` covers
// the same widening behaviour combined with multi-ctor + qualifier; this
// fixture isolates the simpler single-axis case.

import 'package:inject_annotation/inject_annotation.dart';

import 'synthesized_factory_nullable_wrap_dep.inject.dart' as g;

part 'synthesized_factory_nullable_wrap_dep.factory.dart';

class Beans {
  @inject
  Beans();
}

class Latte {
  // Synthesizes LatteFactory.
  @assistedInject
  Latte(this.beans, @assisted this.flavor);

  final Beans beans;
  final String flavor;
}

class Espresso {
  // Synthesizes EspressoFactory. Single @assistedInject ctor — no qualifier.
  // The `LatteFactory? latteFactory` parameter exercises the nullable-wrap path.
  @assistedInject
  Espresso(this.beans, this.latteFactory, @assisted this.shots);

  final Beans beans;
  final LatteFactory? latteFactory;
  final int shots;
}

@Component()
abstract class Cafe {
  static const g.Cafe$Component Function() create = g.Cafe$Component.create;

  @inject
  EspressoFactory get espressoFactory;

  @inject
  LatteFactory get latteFactory;
}
