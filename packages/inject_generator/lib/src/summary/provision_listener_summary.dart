part of '../summary.dart';

/// Summary of a class annotated with `@provisionListener`.
@JsonSerializable()
class ProvisionListenerSummary {
  /// Location of the analyzed class.
  final SymbolPath clazz;

  /// The type parameter that specifies which objects this listener will monitor.
  ///
  /// If null, the listener will be called for all provisioned objects.
  /// If specified, the listener will only be called for objects of the specified type.
  final LookupKey? typeParameter;

  /// Summary about the constuctor. Needed to know if the listener itself depends on something.
  final ProviderSummary constructor;

  /// Constructor.
  ///
  /// [clazz] is the path to the class annotated with `@provisionListener`.
  /// [typeParameter] represents the generic type parameter `T` in `ProvisionListener<T>`.
  /// [constructor] summary about the constuctor to know dependencies of this listener.
  const ProvisionListenerSummary(this.clazz, this.typeParameter, this.constructor);

  factory ProvisionListenerSummary.fromJson(Map<String, dynamic> json) => _$ProvisionListenerSummaryFromJson(json);

  Map<String, dynamic> toJson() => _$ProvisionListenerSummaryToJson(this);
}
