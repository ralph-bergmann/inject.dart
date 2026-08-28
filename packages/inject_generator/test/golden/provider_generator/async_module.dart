import 'package:inject_annotation/inject_annotation.dart';

import 'async_module.inject.dart' as g;

abstract class Closable {
  void close();
}

class ClosableListener implements ProvisionListener<Closable> {
  ClosableListener();

  final _closables = <Closable>[];

  @override
  void onProvision(Closable instance) => _closables.add(instance);

  void dispose() {
    for (final Closable closable in _closables) {
      closable.close();
    }
  }
}

@inject
@singleton
class HttpClient implements Closable {
  @override
  void close() {}
}

class DatabaseConnection implements Closable {
  const DatabaseConnection(this.client);

  final HttpClient client;

  @override
  void close() {}
}

class DatabaseService {
  const DatabaseService(this.databaseConnection);

  final DatabaseConnection databaseConnection;
}

@module
class DatabaseModule {
  @provides
  @singleton
  @provisionListener
  ClosableListener provideClosableListener() => ClosableListener();

  @provides
  @singleton
  @asynchronous
  Future<DatabaseConnection> provideDatabaseConnection(HttpClient client) async => DatabaseConnection(client);

  @provides
  @asynchronous
  Future<DatabaseService> provideDatabaseService(DatabaseConnection connection) async => DatabaseService(connection);
}

@Component([DatabaseModule])
abstract class AppComponent {
  static const g.AppComponent$Component Function({DatabaseModule? databaseModule}) create =
      g.AppComponent$Component.create;

  @inject
  Future<DatabaseService> get databaseService;

  @inject
  ClosableListener get closableListener;
}

void main() {
  final g.AppComponent$Component c = AppComponent.create();
  c.closableListener.dispose();
}
