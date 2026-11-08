import 'package:inject_annotation/inject_annotation.dart';

import 'typedef_foreign_provider_bound.inject.dart' as g;

part 'typedef_foreign_provider_bound.factory.dart';

// A typedef provider's extra parameter whose class is only named `Provider`.
// It is a plain type with its own binding, so the closure passes the value
// that binding returns from `.get()`, not the binding's provider.

typedef ItemBuilder = Item Function(String name);

class Provider<T> {
  const Provider(this.value);

  final T value;
}

class Clock {
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

@module
class AppModule {
  @provides
  Provider<Clock> provideClockProvider() => Provider(Clock());
}

@Component([AppModule])
abstract class AppComponent {
  static const g.AppComponent$Component Function() create = g.AppComponent$Component.create;

  PageFactory get pageFactory;
}
