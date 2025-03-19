import 'package:flutter/material.dart';
import 'package:inject_annotation/inject_annotation.dart';

import 'main.inject.dart' as g;
import 'src/data/services/database.dart';
import 'src/features/app/my_app.dart';

void main() {
  final mainComponent = MainComponent.create();
  final app = mainComponent.myAppFactory.create();
  runApp(app);
}

/// [MainComponent] which is the root of the dependency graph.
@Component([DataBaseModule])
abstract class MainComponent {
  static const create = g.MainComponent$Component.create;

  @inject
  MyAppFactory get myAppFactory;
}
