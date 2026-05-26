import 'package:inject_annotation/inject_annotation.dart';

import 'inject_named_params.inject.dart' as g;

@inject
class Database {}

@inject
class CounterRepository {
  CounterRepository({required this.database});

  final Database database;
}

@component
abstract class AppComponent {
  static const g.AppComponent$Component Function() create = g.AppComponent$Component.create;

  @inject
  CounterRepository get counterRepository;
}
