import 'package:inject_annotation/inject_annotation.dart';

import 'synthesized_function_type_assisted.inject.dart' as g;

part 'synthesized_function_type_assisted.factory.dart';

@inject
class Logger {}

class Slots {}

class Child {}

class Host {
  @assistedInject
  Host(this.logger, @assisted this.builder, @assisted this.onTap, @assisted this.mapper);

  final Logger logger;
  final Child Function(Slots, [Logger?]) builder;
  final void Function(List<Slots>, {required Child child, int? index})? onTap;
  final Child Function<T extends Slots>(T) mapper;
}

@component
abstract class AppComponent {
  static const g.AppComponent$Component Function() create = g.AppComponent$Component.create;

  @inject
  HostFactory get hostFactory;
}
