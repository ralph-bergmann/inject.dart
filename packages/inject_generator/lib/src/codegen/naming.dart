import '../extensions/string_extensions.dart';

/// Synthesized factory class name for an `@assistedInject` constructor.
///
/// Single-constructor (`qualifier` is `null`): `${typeName}Factory`.
/// Multi-constructor (`qualifier` is non-null): `${typeName}${qualifier.capitalize}Factory`.
///
/// This is the single source of truth for the naming rule consumed by both
/// the code-generation phase (`factory_generator.dart`) and the discovery
/// phase (`dependency_discovery.dart`). Keeping it in its own file with a
/// minimal dependency surface (`string_extensions.dart` only) avoids the
/// circular import between `provider_generator.dart` and
/// `dependency_discovery.dart`.
String synthesizedFactoryClassName(String typeName, String? qualifier) {
  final String qualifierSuffix = qualifier != null ? qualifier.capitalize : '';
  return '${typeName}${qualifierSuffix}Factory';
}

/// Matches a qualifier-symbol content that is safe to embed as a suffix in a
/// generated Dart identifier — alphanumerics and underscore only. Empty
/// qualifiers and qualifiers with characters like `-`, `.`, ` `, or `$`
/// would produce invalid Dart identifiers downstream.
final _qualifierIdentifierPattern = RegExp(r'^[a-zA-Z0-9_]+$');

/// Returns `true` if [qualifier] is safe to embed as an identifier-suffix
/// (e.g. in `_<Type><Qualifier>$Provider` or `<Type><Qualifier>Factory`).
///
/// Allowed: non-empty, alphanumeric + underscore only. Rejected: empty,
/// hyphen, dot, space, `$`, and other non-identifier characters.
bool isValidQualifierIdentifier(String qualifier) =>
    qualifier.isNotEmpty && _qualifierIdentifierPattern.hasMatch(qualifier);
