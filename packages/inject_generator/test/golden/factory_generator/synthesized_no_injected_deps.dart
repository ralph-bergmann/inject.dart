import 'package:inject_annotation/inject_annotation.dart';

import 'synthesized_no_injected_deps.inject.dart' as g;

part 'synthesized_no_injected_deps.factory.dart';

class Message {
  @assistedInject
  Message(@assisted this.text);

  final String text;
}

@component
abstract class AppComponent {
  static const g.AppComponent$Component Function() create = g.AppComponent$Component.create;

  @inject
  MessageFactory get messageFactory;
}
