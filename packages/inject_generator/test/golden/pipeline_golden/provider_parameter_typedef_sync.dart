import 'package:inject_annotation/inject_annotation.dart';

import 'provider_parameter_typedef_sync.inject.dart' as g;

part 'provider_parameter_typedef_sync.factory.dart';

// A typedef provider's extra parameter declared `Provider<T>` over a sync
// binding: the closure passes the provider field straight through.

typedef ItemBuilder = Item Function(String name);

class Clock {
  @inject
  const Clock();
}

class Item {
  const Item(this.name, this.clock);

  final String name;
  final Provider<Clock> clock;
}

class Page {
  @assistedInject
  const Page(this.itemBuilder, @assisted this.title);

  final ItemBuilder itemBuilder;
  final String title;
}

@Component()
abstract class AppComponent {
  static const g.AppComponent$Component Function() create = g.AppComponent$Component.create;

  PageFactory get pageFactory;
}
