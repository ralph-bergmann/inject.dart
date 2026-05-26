import 'package:inject_annotation/inject_annotation.dart';

@module
class MyModule {
  @provides
  String provideName() => 'test';
}
