import 'package:inject_annotation/inject_annotation.dart';

import 'subcomp_provider_and_method_entry_points.inject.dart' as g;

part 'subcomp_provider_and_method_entry_points.factory.dart';

// Regression fixture (story 8.1 code review, Low finding): a subcomponent's
// entry points can be a `Provider<T>` getter and a method (not only plain
// getters) exactly like on a `@Component` — previously exercised only by
// `SubcomponentReader` unit tests, never through the full codegen pipeline.

void main() {}

class CoffeeMaker {
  const CoffeeMaker();
}

class Kettle {
  const Kettle();
}

@module
class BrewModule {
  @provides
  CoffeeMaker provideCoffeeMaker() => const CoffeeMaker();

  @provides
  Kettle provideKettle() => const Kettle();
}

@Subcomponent([BrewModule])
abstract class BrewSubcomponent {
  Provider<CoffeeMaker> get coffeeMaker;

  Kettle getKettle();
}

@Module(subcomponents: [BrewSubcomponent])
class AppModule {}

@Component([AppModule])
abstract class AppComponent {
  static const create = g.AppComponent$Component.create;

  BrewSubcomponentFactory get brewFactory;
}
