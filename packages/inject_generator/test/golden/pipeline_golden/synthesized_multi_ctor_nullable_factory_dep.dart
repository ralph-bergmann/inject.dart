// Regression test for per-constructor $Impl resolvability.
//
// A class with multiple @assistedInject constructors where ONE constructor
// depends on a synthesized factory type (`LatteFactory`). `LatteFactory` is
// generated from `Latte`'s own `@assistedInject` constructor and therefore
// does not exist as a class at factory-builder analysis time — so
// `BindingKey.fromDartType(LatteFactory)` returns null for that constructor's
// dep.
//
// Per-constructor semantics: only `CoffeeMakerFancyFactory`'s $Impl is
// suppressed (its dep is unresolvable at factory-builder time);
// `CoffeeMakerStandardFactory` still gets its $Impl because all of its deps
// are resolvable.

import 'package:inject_annotation/inject_annotation.dart';

import 'synthesized_multi_ctor_nullable_factory_dep.inject.dart' as g;

part 'synthesized_multi_ctor_nullable_factory_dep.factory.dart';

const standard = Qualifier(#standard);
const fancy = Qualifier(#fancy);

class Grinder {
  @inject
  Grinder();
}

// Latte gets a synthesized factory (`LatteFactory`). This factory type does
// not exist at factory-builder analysis time.
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

  // Ctor B: depends on `LatteFactory` which is a synthesized factory type.
  // At factory-builder analysis time `LatteFactory` doesn't exist yet, so
  // `BindingKey.fromDartType(LatteFactory)` returns null — only this
  // constructor's $Impl is suppressed, not ctor A's.
  // The param is non-nullable `LatteFactory` (the binding that exists); the
  // field is nullable so ctor A can initialise it to null.
  @fancy
  @assistedInject
  CoffeeMaker.fancy(this.grinder, LatteFactory latteFactory, @assisted this.beans)
      : latteFactory = latteFactory;

  final Grinder grinder;
  final LatteFactory? latteFactory;
  final int beans;
}

@Component()
abstract class CoffeeShop {
  static const g.CoffeeShop$Component Function() create = g.CoffeeShop$Component.create;

  @inject
  CoffeeMakerStandardFactory get standardFactory;

  @inject
  CoffeeMakerFancyFactory get fancyFactory;

  @inject
  LatteFactory get latteFactory;
}
