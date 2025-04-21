import 'package:inject_annotation/inject_annotation.dart';

import 'main2.inject.dart' as g;

void main() {
  final component = MainComponent.create();
  final app = component.app;

  final listener = component.disposableListener;
  listener.disposeAll();
}

@Component(
  modules: [HttpClientModule],
  provisionListeners: [LoggingListener, AppListener, DisposableListener],
)
abstract class MainComponent {
  static const create = g.MainComponent$Component.create;

  @inject
  App get app;

  @inject
  HttpClient get httpClient;

  @inject
  DisposableListener get disposableListener;
}

abstract interface class Disposable {
  void dispose();
}

@inject
class App implements Disposable {
  const App(this.foo);

  final Foo foo;

  @override
  void dispose() {
    print('app disposed');
  }
}

// Simulate class from 3rd party package
class HttpClient implements Disposable {
  @override
  void dispose() {
    print('http client disposed');
  }
}

@module
class HttpClientModule {
  @provides
  @singleton
  HttpClient provideHttpClient() => HttpClient();
}

// Listener for all types
@provisionListener
class LoggingListener implements ProvisionListener {
  @override
  void onProvision(ProvisionInvocation provision) {
    final obj = provision.provision();
    print('object $obj created');
  }
}

// Listener only for App
@provisionListener
class AppListener implements ProvisionListener<App> {
  AppListener(this.bar);

  final Bar bar;

  @override
  void onProvision(ProvisionInvocation<App> provision) {
    final obj = provision.provision();
    print('app created');
  }
}

// Listener only for HttpClient
@provisionListener
class HttpClientListener implements ProvisionListener<HttpClient> {
  HttpClientListener(this.bar);

  final Bar bar;

  @override
  void onProvision(ProvisionInvocation<HttpClient> provision) {
    final obj = provision.provision();
    print('http client created');
  }
}

// Listener for types implementing Disposable
@provisionListener
class DisposableListener implements ProvisionListener<Disposable> {
  final List<Disposable> _disposables = [];

  @override
  void onProvision(ProvisionInvocation<Disposable> provision) {
    final disposable = provision.provision();
    _disposables.add(disposable);
  }

  void disposeAll() {
    for (final disposable in _disposables) {
      disposable.dispose();
    }
    _disposables.clear();
  }
}

@inject
class Foo {}

@inject
class Bar {
  const Bar(this.fooBar);

  final FooBar fooBar;
}

@inject
class FooBar {}
