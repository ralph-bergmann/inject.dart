import 'package:analyzer/dart/element/element.dart';

/// Helpers on [ConstructorElement] for named-constructor handling.
extension ConstructorElementExt on ConstructorElement {
  /// Returns the constructor's name, or `null` for the unnamed (`new`) constructor.
  String? get constructorName => (name == null || name!.isEmpty || name == 'new') ? null : name;
}
