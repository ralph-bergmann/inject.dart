// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of '../summary.dart';

/// JSON-serializable subset of code analysis information about a Dart library
/// that includes dependency injection constructs but excludes component classes.
///
/// Component classes of a Dart library are summarized in ComponentsSummary.
///
/// A library summary usually corresponds to a “.dart” file.
@JsonSerializable()
class LibrarySummary {
  /// Points to the Dart file that defines the library from which this summary
  /// was extracted.
  ///
  /// The URI uses the "asset:" scheme.
  final Uri assetUri;

  /// Module classes defined in this library.
  final List<ModuleSummary> modules;

  /// ProvisionListener classes
  final List<ProvisionListenerSummary> provisionListeners;

  /// Injectable classes.
  final List<InjectableSummary> injectables;

  /// Assisted injectable classes.
  final List<InjectableSummary> assistedInjectables;

  /// AssistedInject factory classes.
  final List<FactorySummary> factories;

  /// Constructor.
  factory LibrarySummary(
    Uri assetUri, {
    List<ModuleSummary> modules = const [],
    List<ProvisionListenerSummary> provisionListeners = const [],
    List<InjectableSummary> injectables = const [],
    List<InjectableSummary> assistedInjectables = const [],
    List<FactorySummary> factories = const [],
  }) =>
      LibrarySummary._(
        assetUri,
        modules,
        provisionListeners,
        injectables,
        assistedInjectables,
        factories,
      );

  const LibrarySummary._(
    this.assetUri,
    this.modules,
    this.provisionListeners,
    this.injectables,
    this.assistedInjectables,
    this.factories,
  );

  factory LibrarySummary.fromJson(dynamic json) => _$LibrarySummaryFromJson(json);

  Map<String, dynamic> toJson() => _$LibrarySummaryToJson(this);
}

@JsonSerializable()
class ComponentsSummary {
  /// Points to the Dart file that defines the library from which this summary
  /// was extracted.
  ///
  /// The URI uses the "asset:" scheme.
  final Uri assetUri;

  /// Component classes defined in the library.
  final List<ComponentSummary> components;

  /// Constructor.
  factory ComponentsSummary(
    Uri assetUri, {
    required List<ComponentSummary> components,
  }) =>
      ComponentsSummary._(
        assetUri,
        components,
      );

  const ComponentsSummary._(
    this.assetUri,
    this.components,
  );

  factory ComponentsSummary.fromJson(dynamic json) => _$ComponentsSummaryFromJson(json);

  Map<String, dynamic> toJson() => _$ComponentsSummaryToJson(this);
}
