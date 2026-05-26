// Regression test for per-constructor $Impl resolvability with nullable-
// wrapped synthesized factory deps.
//
// Sibling of `synthesized_multi_ctor_nullable_factory_dep.dart` — that
// fixture uses a non-nullable `LatteFactory` parameter. This fixture uses
// an explicit nullable `LatteFactory?` parameter, covering the
// nullable-/Future-wrapped synthesized-factory-dependency case.
//
// Both ctors are @assistedInject; the deluxe ctor depends on `LatteFactory?`.
// `LatteFactory` is itself a synthesized factory (from `Latte`'s own
// `@assistedInject` constructor) and therefore does not exist as a class at
// factory-builder analysis time — `BindingKey.fromDartType(LatteFactory?)`
// must still return null in that phase, so only `CoffeeMakerDeluxeFactory`'s
// $Impl is suppressed. `CoffeeMakerStandardFactory` still gets its $Impl.

import 'package:inject_annotation/inject_annotation.dart';

import 'synthesized_multi_ctor_nullable_wrapped_factory_dep.inject.dart' as g;

part 'synthesized_multi_ctor_nullable_wrapped_factory_dep.factory.dart';

const standard = Qualifier(#standard);
const deluxe = Qualifier(#deluxe);

class Grinder {
  @inject
  Grinder();
}

// `LatteFactory` is synthesized from this class. At factory-builder time the
// `LatteFactory` class does not yet exist.
class Latte {
  @assistedInject
  Latte(this.grinder, @assisted this.flavor);

  final Grinder grinder;
  final String flavor;
}

class CoffeeMaker {
  // Ctor A: all deps resolvable at factory-builder time.
  @standard
  @assistedInject
  CoffeeMaker(this.grinder, @assisted this.beans) : latteFactory = null;

  // Ctor B: nullable-wrapped dep on synthesized `LatteFactory?`. Per-ctor
  // resolvability check must observe this as unresolvable at factory-builder
  // time and suppress only this ctor's $Impl.
  @deluxe
  @assistedInject
  CoffeeMaker.deluxe(this.grinder, LatteFactory? latteFactory, @assisted this.beans)
      : latteFactory = latteFactory;

  final Grinder grinder;
  final LatteFactory? latteFactory;
  final int beans;
}

// `deluxeFactory` is now exposed as a Component entry point.
// The inject-builder resolves `LatteFactory?` via nullable-widening from the
// non-nullable `$LatteFactory` binding, so the full pipeline compiles cleanly.
@Component()
abstract class CoffeeShop {
  static const g.CoffeeShop$Component Function() create = g.CoffeeShop$Component.create;

  @inject
  CoffeeMakerStandardFactory get standardFactory;

  @inject
  CoffeeMakerDeluxeFactory get deluxeFactory;

  @inject
  LatteFactory get latteFactory;
}
