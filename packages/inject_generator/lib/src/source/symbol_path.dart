// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:json_annotation/json_annotation.dart';
import 'package:path/path.dart' as pkg_path;

part 'symbol_path.g.dart';

/// Represents the absolute canonical location of a [symbol] within Dart.
///
/// A [symbol] is mapped to a [path] within a [package]. For example:
///     // A reference to package:collection/collection.dart#MapEquality
///     new SymbolPath('collection', 'lib/collection.dart', 'MapEquality')
///
///     // A reference to dart:core#List
///     new SymbolPath.dartSdk('core', 'List')
@JsonSerializable()
class SymbolPath implements Comparable<SymbolPath> {
  /// Path to the `@Component` annotation.
  static const SymbolPath component = SymbolPath._standard('Component');

  /// Path to the `@Module` annotation.
  static const SymbolPath module = SymbolPath._standard('Module');

  /// Path to the `@ProvisionListener` annotation.
  static const SymbolPath provisionListener =
      SymbolPath('inject_annotation', 'lib/src/api/provision_listener.dart', 'ProvisionListener');

  /// Path to the `@Inject` annotation.
  static const SymbolPath inject = SymbolPath._standard('Inject');

  /// Path to the `@AssistedInject` annotation.
  static const SymbolPath assistedInject = SymbolPath._standard('AssistedInject');

  /// Path to the `@AssistedFactory` annotation.
  static const SymbolPath assistedFactory = SymbolPath._standard('AssistedFactory');

  /// Path to the `@Assisted` annotation.
  static const SymbolPath assisted = SymbolPath._standard('Assisted');

  /// Path to the `@Provides` annotation.
  static const SymbolPath provides = SymbolPath._standard('Provides');

  /// Path to the `@Qualifier` annotation.
  static const SymbolPath qualifier = SymbolPath._standard('Qualifier');

  /// Path to the `@Singleton` annotation.
  static const SymbolPath singleton = SymbolPath._standard('Singleton');

  /// Path to the `@Asynchronous` annotation.
  static const SymbolPath asynchronous = SymbolPath._standard('Asynchronous');

  /// Path to the `async Future` type.
  static const SymbolPath feature = SymbolPath.dartSdk('async', 'Future');

  static const String _dartPackage = 'dart';

  /// An alias to `new SymbolPath.fromAbsoluteUri(Uri.parse(...))`.
  static SymbolPath parseAbsoluteUri(String assetUri, [String? symbolName]) =>
      SymbolPath.fromAbsoluteUri(Uri.parse(assetUri), symbolName);

  /// Name of the package containing the Dart source code.
  ///
  /// If 'dart', is special cased to the Dart SDK. See [isDartSdk].
  final String? package;

  /// Location relative to the package root.
  ///
  /// A fully qualified path in a Dart package (*not* a package URI):
  ///   - 'lib/foo.dart'
  ///   - 'bin/bar.dart'
  ///   - 'test/some/file.dart'
  final String? path;

  /// Name of the top-level symbol within the Dart source code referenced.
  final String symbol;

  /// Constructor.
  ///
  /// [package] is the name of the Dart package containing the symbol. For Dart
  /// core libraries use "dart" as the [package].
  ///
  /// [path] is path to the library within the package. Unlike `import`
  /// statements, [path] must include "lib", "web", "bin", "test" parts of the
  /// path, for example "lib/src/coffee.dart". Paths for Dart core libraries
  /// must be their names without the "lib" prefix, for example "async" for
  /// "dart:async".
  ///
  /// [symbol] is the symbol defined in the library.
  ///
  /// [package], [path] and [symbol] must not be `null` or empty.
  const SymbolPath(this.package, this.path, this.symbol);

  /// Within the dart SDK, reference [symbol] found at [path].
  const SymbolPath.dartSdk(this.path, this.symbol) : package = _dartPackage;

  /// Defines a global symbol that is not scoped to a package/path.
  const SymbolPath.global(this.symbol)
      : package = null,
        path = null;

  /// For standard annotations defined by `package:inject`.
  const SymbolPath._standard(this.symbol)
      : package = 'inject_annotation',
        path = 'lib/src/api/annotations.dart';

  /// Create a [SymbolPath] using [assetUri].
  factory SymbolPath.fromAbsoluteUri(Uri assetUri, [String? symbolName]) {
    assetUri = toAssetUri(assetUri);
    symbolName ??= Uri.decodeComponent(assetUri.fragment);
    if (assetUri.scheme == _dartPackage) {
      return SymbolPath.dartSdk(assetUri.path, symbolName);
    }
    if (assetUri.scheme == 'global') {
      return SymbolPath.global(symbolName);
    }
    final paths = assetUri.path.split('/');
    final package = paths.first;
    final path = paths.skip(1).join('/');
    return SymbolPath(package, path, symbolName);
  }

  /// Converts [libUri] to an absolute "asset:" [Uri].
  ///
  /// If [libUri] is already absolute, it is left unchanged.
  ///
  /// Relative URI are rejected with an exception.
  static Uri toAssetUri(Uri libUri) {
    if (libUri.scheme.isEmpty) {
      throw 'Relative library URI not supported: $libUri';
    }

    if (libUri.scheme != 'package') {
      return libUri;
    }

    final inSegments = libUri.path.split('/');
    final outSegments = <String>[inSegments.first, 'lib', ...inSegments.skip(1)];

    return libUri.fragment.isNotEmpty
        ? Uri(
            scheme: 'asset',
            pathSegments: outSegments,
            fragment: libUri.fragment,
          )
        : Uri(
            scheme: 'asset',
            pathSegments: outSegments,
          );
  }

  /// Whether the [path] points within the Dart SDK, not a pub package.
  bool get isDartSdk => package == _dartPackage;

  ///  Whether [symbol] is a global key.
  bool get isGlobal => package == null && path == null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SymbolPath &&
          runtimeType == other.runtimeType &&
          package == other.package &&
          path == other.path &&
          symbol == other.symbol;

  @override
  int get hashCode => package.hashCode ^ path.hashCode ^ symbol.hashCode;

  @override
  int compareTo(SymbolPath symbolPath) {
    var order = symbolPath.package == null ? 0 : package?.compareTo(symbolPath.package!) ?? 0;
    if (order == 0) {
      order = symbolPath.path == null ? 0 : path?.compareTo(symbolPath.path!) ?? 0;
    }
    if (order == 0) {
      order = symbol.compareTo(symbolPath.symbol);
    }
    return order;
  }

  /// Returns a new absolute 'dart:', 'asset:', or 'global:' [Uri].
  Uri toAbsoluteUri() {
    if (isGlobal) {
      return Uri(scheme: 'global', fragment: symbol);
    }
    return Uri(
      scheme: isDartSdk ? _dartPackage : 'asset',
      path: isDartSdk ? path : '$package/$path',
      fragment: symbol,
    );
  }

  /// Returns a [Uri] for this path that can be used in a Dart import statement.
  Uri toDartUri({Uri? relativeTo}) {
    if (isGlobal) {
      throw UnsupportedError('Global keys do not map to Dart source.');
    }

    if (isDartSdk) {
      return Uri(scheme: 'dart', path: path);
    }

    // Attempt to construct relative import.
    if (relativeTo != null) {
      final normalizedBase = relativeTo.normalizePath();
      final baseSegments = normalizedBase.path.split('/')..removeLast();
      final targetSegments = toAbsoluteUri().path.split('/');
      if (baseSegments.first == targetSegments.first && baseSegments[1] == targetSegments[1]) {
        // Ok, we're in the same package and in the same top-level directory.
        final relativePath = pkg_path.relative(
          targetSegments.skip(2).join('/'),
          from: baseSegments.skip(2).join('/'),
        );
        return Uri(path: pkg_path.split(relativePath).join('/'));
      }
    }

    final pathSegments = path?.split('/') ?? [];

    if (pathSegments.first != 'lib') {
      throw StateError('Cannot construct absolute import URI from $relativeTo '
          'to a non-lib Dart file: ${toAbsoluteUri()}');
    }

    final packagePath = pathSegments.sublist(1).join('/');
    return Uri(
      scheme: isDartSdk ? _dartPackage : 'package',
      path: isDartSdk ? path : '$package/$packagePath',
    );
  }

  /// Absolute path to this symbol for use in log messages.
  String toHumanReadableString() => '${toDartUri()}#$symbol';

  factory SymbolPath.fromJson(Map<String, dynamic> json) => _$SymbolPathFromJson(json);

  Map<String, dynamic> toJson() => _$SymbolPathToJson(this);

  @override
  String toString() => 'SymbolPath{package: $package, path: $path, symbol: $symbol}';
}
