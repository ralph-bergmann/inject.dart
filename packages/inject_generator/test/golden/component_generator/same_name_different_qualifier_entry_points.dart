import 'package:inject_annotation/inject_annotation.dart';

const brand = Qualifier(#brand);
const model = Qualifier(#model);

abstract class BrandProvider {
  @inject
  @brand
  String get label;
}

abstract class ModelProvider {
  @inject
  @model
  String get label;
}

@component
abstract class CarComponent implements BrandProvider, ModelProvider {}
