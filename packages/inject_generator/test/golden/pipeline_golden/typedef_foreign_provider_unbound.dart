// Golden fixture (error path): a typedef provider's extra parameter whose class
// is only named `Provider`. It is a plain type with no binding, so it must
// report the missing-binding error even though `I` has an async binding.

import 'package:inject_annotation/inject_annotation.dart';

class Provider<T> {}

class I {}

class Item {
  Item(String name, Provider<I> i);
}

typedef ListFactory = Item Function(String name);

class ListPage {
  @assistedInject
  ListPage(ListFactory f, @assisted String t);
}

@assistedFactory
abstract class ListPageFactory {
  ListPage create(String t);
}

@module
class AppModule {
  @asynchronous
  @provides
  Future<I> provideI() async => I();
}

@Component([AppModule])
abstract class AppComponent {
  ListPageFactory get listPage;
}
