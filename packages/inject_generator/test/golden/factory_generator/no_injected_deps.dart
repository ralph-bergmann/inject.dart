import 'package:inject_annotation/inject_annotation.dart';

import 'no_injected_deps.inject.dart' as g;

class Message {
  @assistedInject
  Message(@assisted this.text);

  final String text;
}

@assistedFactory
abstract class MessageFactory {
  Message create(String text);
}

@component
abstract class AppComponent {
  static const g.AppComponent$Component Function() create = g.AppComponent$Component.create;

  @inject
  MessageFactory get messageFactory;
}
