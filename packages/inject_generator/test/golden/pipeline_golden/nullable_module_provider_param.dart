// Golden fixture: module providers whose nullable parameters are satisfied by
// a non-nullable binding.
//
// `name` reads `Foo?` through the `Foo` provider, `count` reads `Foo` and `Foo?`
// through one field, and `ratio` turns async because the widened `Bar?` is bound
// by an @asynchronous provider.

import 'package:inject_annotation/inject_annotation.dart';

class Foo {
  const Foo();
}

class Bar {
  const Bar();
}

@module
class AppModule {
  @provides
  Foo provideFoo() => const Foo();

  @provides
  String name(Foo? foo) => '$foo';

  @provides
  int count(Foo foo, Foo? maybeFoo) => 1;

  @provides
  @asynchronous
  Future<Bar> provideBar() async => const Bar();

  @provides
  double ratio(Bar? bar) => 1;
}

@Component([AppModule])
abstract class AppComponent {
  String get name;

  int get count;

  Future<double> get ratio;
}
