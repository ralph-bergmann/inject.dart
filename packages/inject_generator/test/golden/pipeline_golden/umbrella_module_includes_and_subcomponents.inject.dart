// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// Generator: inject.dart
// https://pub.dev/packages/inject_annotation
// **************************************************************************

// ignore_for_file: type=lint, type=warning
// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:inject_annotation/inject_annotation.dart' as _i2;

import 'umbrella_module_includes_and_subcomponents.dart' as _i1;

class AppComponent$Component implements _i1.AppComponent {
  factory AppComponent$Component.create({
    _i1.ExtraModule? extraModule,
    _i1.CombinedModule? combinedModule,
  }) => AppComponent$Component._(
    extraModule ?? _i1.ExtraModule(),
    combinedModule ?? _i1.CombinedModule(),
  );

  AppComponent$Component._(
    _i1.ExtraModule extraModule,
    _i1.CombinedModule combinedModule,
  ) {
    final labelSubcomponentFactory$Provider =
        _LabelSubcomponentFactory$Provider(this);
    _string$Provider = _String$Provider(
      labelSubcomponentFactory$Provider,
      combinedModule,
    );
    _int$Provider = _Int$Provider(extraModule);
  }

  late final _String$Provider _string$Provider;

  late final _Int$Provider _int$Provider;

  @override
  String get exportedLabel => _string$Provider.get();

  @override
  int get extra => _int$Provider.get();
}

class LabelSubcomponent$Subcomponent implements _i1.LabelSubcomponent {
  factory LabelSubcomponent$Subcomponent.create(
    AppComponent$Component parent, {
    _i1.LabelModule? labelModule,
  }) => LabelSubcomponent$Subcomponent._(
    parent,
    labelModule ?? _i1.LabelModule(),
  );

  LabelSubcomponent$Subcomponent._(this._parent, _i1.LabelModule labelModule) {
    _labelSubcomponent$stringInternal$Provider =
        _LabelSubcomponent$StringInternal$Provider(labelModule);
  }

  final AppComponent$Component _parent;

  late final _LabelSubcomponent$StringInternal$Provider
  _labelSubcomponent$stringInternal$Provider;

  @override
  String get label => _labelSubcomponent$stringInternal$Provider.get();
}

class _LabelSubcomponentFactory$Factory
    implements _i1.LabelSubcomponentFactory {
  const _LabelSubcomponentFactory$Factory(this._parent);

  final AppComponent$Component _parent;

  @override
  _i1.LabelSubcomponent create({_i1.LabelModule? labelModule}) =>
      LabelSubcomponent$Subcomponent.create(_parent, labelModule: labelModule);
}

class _Int$Provider implements _i2.Provider<int> {
  const _Int$Provider(this._module);

  final _i1.ExtraModule _module;

  @override
  int get() => _module.provideExtra();
}

class _LabelSubcomponent$StringInternal$Provider
    implements _i2.Provider<String> {
  const _LabelSubcomponent$StringInternal$Provider(this._module);

  final _i1.LabelModule _module;

  @override
  String get() => _module.provideLabel();
}

class _LabelSubcomponentFactory$Provider
    implements _i2.Provider<_i1.LabelSubcomponentFactory> {
  _LabelSubcomponentFactory$Provider(this._parent);

  final AppComponent$Component _parent;

  late final _i1.LabelSubcomponentFactory _factory =
      _LabelSubcomponentFactory$Factory(_parent);

  @override
  _i1.LabelSubcomponentFactory get() => _factory;
}

class _String$Provider implements _i2.Provider<String> {
  const _String$Provider(this._labelSubcomponentFactory$Provider, this._module);

  final _LabelSubcomponentFactory$Provider _labelSubcomponentFactory$Provider;

  final _i1.CombinedModule _module;

  @override
  String get() =>
      _module.provideExportedLabel(_labelSubcomponentFactory$Provider.get());
}
