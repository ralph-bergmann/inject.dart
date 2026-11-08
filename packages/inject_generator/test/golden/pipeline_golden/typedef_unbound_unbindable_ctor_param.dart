// Error-path fixture: two unbound function typedefs whose return type's
// constructor has a parameter that can never be a binding.
//
// LoadCount returns Future, whose constructor takes the raw function
// `computation`. TickerBuilder returns Ticker, whose constructor takes the
// @inject class Clock before the raw function `onTick`. Neither may get a
// typedef provider: each reports the usual missing-binding error at its
// injecting parameter, nothing is reported inside the SDK, and Clock is not
// discovered.

import 'package:inject_annotation/inject_annotation.dart';

typedef LoadCount = Future<int> Function();
typedef TickerBuilder = Ticker Function(String label);

class Clock {
  @inject
  const Clock();
}

class Ticker {
  const Ticker(this.label, this.clock, this.onTick);

  final String label;
  final Clock clock;
  final void Function() onTick;
}

class LoadingPage {
  @assistedInject
  const LoadingPage(this.loadCount, @assisted this.title);

  final LoadCount loadCount;
  final String title;
}

@assistedFactory
abstract class LoadingPageFactory {
  LoadingPage create(String title);
}

class TickerPage {
  @assistedInject
  const TickerPage(this.tickerBuilder, @assisted this.title);

  final TickerBuilder tickerBuilder;
  final String title;
}

@assistedFactory
abstract class TickerPageFactory {
  TickerPage create(String title);
}

@Component()
abstract class TestComponent {
  LoadingPageFactory get loadingPageFactory;

  TickerPageFactory get tickerPageFactory;
}
