import 'package:inject_annotation/inject_annotation.dart';

import 'synthesized_record_type_assisted.inject.dart' as g;

part 'synthesized_record_type_assisted.factory.dart';

@inject
class Logger {}

class Slots {}

class Child {}

class Host {
  @assistedInject
  Host(this.logger, @assisted this.pair, @assisted this.named, @assisted this.mixed, @assisted this.single);

  final Logger logger;
  final (Slots, Child) pair;
  final ({Slots slots, Child child}) named;
  final (List<Slots>, {(Child, Logger)? nested})? mixed;
  final (Slots,) single;
}

@component
abstract class AppComponent {
  static const g.AppComponent$Component Function() create = g.AppComponent$Component.create;

  @inject
  HostFactory get hostFactory;
}
