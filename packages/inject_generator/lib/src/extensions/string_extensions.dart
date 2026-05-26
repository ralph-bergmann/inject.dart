/// String helpers for identifier casing and package-URI parsing.
extension StringExt on String {
  /// Returns this string with its first character upper-cased.
  String get capitalize => isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';

  /// Returns this string with its first character lower-cased.
  String get uncapitalize => isEmpty ? this : '${this[0].toLowerCase()}${substring(1)}';

  /// Parses a `package:` or `asset:` URI into its scheme, package name, and path.
  ///
  /// Returns `null` if the string is not a recognised `package:` or `asset:` URI.
  ({String scheme, String packageName, String path})? packageLocation() {
    if (startsWith('package:')) {
      final String rest = substring('package:'.length);
      final int slashIndex = rest.indexOf('/');
      if (slashIndex == -1) {
        return null;
      }
      return (scheme: 'package', packageName: rest.substring(0, slashIndex), path: rest.substring(slashIndex + 1));
    }

    if (startsWith('asset:')) {
      final String rest = substring('asset:'.length);
      final int slashIndex = rest.indexOf('/');
      if (slashIndex == -1) {
        return null;
      }
      return (scheme: 'asset', packageName: rest.substring(0, slashIndex), path: rest.substring(slashIndex + 1));
    }

    return null;
  }
}
