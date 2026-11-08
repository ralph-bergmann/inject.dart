// Error-path fixture: two unbound function typedefs whose return type has a
// generative constructor but cannot be instantiated.
//
// AbstractBuilder returns an abstract class and SealedBuilder a sealed class.
// Neither may get a typedef provider: each reports the usual missing-binding
// error at its injecting parameter, and Clock is not discovered.

import 'package:inject_annotation/inject_annotation.dart';

typedef AbstractBuilder = AbstractBuilt Function(String name);
typedef SealedBuilder = SealedBuilt Function(String name);

class Clock {
  @inject
  const Clock();
}

abstract class AbstractBuilt {
  const AbstractBuilt(this.name, this.clock);

  final String name;
  final Clock clock;
}

sealed class SealedBuilt {
  const SealedBuilt(this.name, this.clock);

  final String name;
  final Clock clock;
}

class AbstractPage {
  @assistedInject
  const AbstractPage(this.abstractBuilder, @assisted this.title);

  final AbstractBuilder abstractBuilder;
  final String title;
}

@assistedFactory
abstract class AbstractPageFactory {
  AbstractPage create(String title);
}

class SealedPage {
  @assistedInject
  const SealedPage(this.sealedBuilder, @assisted this.title);

  final SealedBuilder sealedBuilder;
  final String title;
}

@assistedFactory
abstract class SealedPageFactory {
  SealedPage create(String title);
}

@Component()
abstract class TestComponent {
  AbstractPageFactory get abstractPageFactory;

  SealedPageFactory get sealedPageFactory;
}
