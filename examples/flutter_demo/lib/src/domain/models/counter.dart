/// Immutable domain model representing the counter state.
///
/// A plain Dart class with value semantics. Using [freezed] or [built_value]
/// is an option (as recommended by the Flutter architecture skill) but adds
/// codegen noise that would distract from the inject.dart concepts shown here.
/// This is documented as a trade-off in the README.
class Counter {
  const Counter({this.value = 0});

  final int value;

  Counter copyWith({int? value}) => Counter(value: value ?? this.value);

  @override
  bool operator ==(Object other) => other is Counter && other.value == value;

  @override
  int get hashCode => value.hashCode;
}
