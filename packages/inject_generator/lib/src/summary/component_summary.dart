// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of '../summary.dart';

/// JSON-serializable subset of code analysis information about an component
/// class pertaining to an component class.
@JsonSerializable()
class ComponentSummary {
  /// Location of the component this summary describes.
  final SymbolPath clazz;

  /// Modules that are assigned to this component.
  final List<SymbolPath> modules;

  /// ProvidionListeners assigned to this component.
  final List<SymbolPath> provisionListeners;

  /// What this component provides.
  final List<ProviderSummary> providers;

  /// Constructor.
  ///
  /// [clazz], [modules] and [providers] must not be `null` or empty.
  factory ComponentSummary(
    SymbolPath clazz,
    List<SymbolPath> modules,
    List<SymbolPath> provisionListeners,
    Iterable<ProviderSummary> providers,
  ) =>
      ComponentSummary._(
        clazz,
        List<SymbolPath>.unmodifiable(modules),
        List<SymbolPath>.unmodifiable(provisionListeners),
        List<ProviderSummary>.unmodifiable(providers),
      );

  const ComponentSummary._(this.clazz, this.modules, this.provisionListeners, this.providers);

  factory ComponentSummary.fromJson(Map<String, dynamic> json) => _$ComponentSummaryFromJson(json);

  Map<String, dynamic> toJson() => _$ComponentSummaryToJson(this);
}
