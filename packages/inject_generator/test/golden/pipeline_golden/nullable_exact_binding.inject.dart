// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// Generator: inject.dart
// https://pub.dev/packages/inject_annotation
// **************************************************************************

// ignore_for_file: type=lint, type=warning
// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'package:inject_annotation/inject_annotation.dart' as _i2;

import 'nullable_exact_binding.dart' as _i1;

class AppComponent$Component implements _i1.AppComponent {
  factory AppComponent$Component.create({_i1.AppModule? appModule}) =>
      AppComponent$Component._(appModule ?? _i1.AppModule());

  AppComponent$Component._(_i1.AppModule appModule) {
    final clockNullable$Provider = _ClockNullable$Provider(appModule);
    _dashboard$Provider = _Dashboard$Provider(clockNullable$Provider);
    final reportBuilder$Provider = _ReportBuilder$Provider(
      clockNullable$Provider,
    );
    _pageFactory$Provider = _PageFactory$Provider(
      clockNullable$Provider,
      reportBuilder$Provider,
    );
    _string$Provider = _String$Provider(clockNullable$Provider, appModule);
  }

  late final _Dashboard$Provider _dashboard$Provider;

  late final _PageFactory$Provider _pageFactory$Provider;

  late final _String$Provider _string$Provider;

  @override
  _i1.Dashboard get dashboard => _dashboard$Provider.get();

  @override
  _i1.PageFactory get pageFactory => _pageFactory$Provider.get();

  @override
  String get label => _string$Provider.get();
}

class _ClockNullable$Provider implements _i2.Provider<_i1.Clock?> {
  const _ClockNullable$Provider(this._module);

  final _i1.AppModule _module;

  @override
  _i1.Clock? get() => _module.provideClock();
}

class _Dashboard$Provider implements _i2.Provider<_i1.Dashboard> {
  const _Dashboard$Provider(this._clockNullable$Provider);

  final _ClockNullable$Provider _clockNullable$Provider;

  @override
  _i1.Dashboard get() => _i1.Dashboard(_clockNullable$Provider.get());
}

class _PageFactory$Factory implements _i1.PageFactory {
  const _PageFactory$Factory(
    this._clockNullable$Provider,
    this._reportBuilder$Provider,
  );

  final _ClockNullable$Provider _clockNullable$Provider;

  final _ReportBuilder$Provider _reportBuilder$Provider;

  @override
  _i1.Page create(int id) => _i1.Page(
    _clockNullable$Provider.get(),
    _reportBuilder$Provider.get(),
    id,
  );
}

class _PageFactory$Provider implements _i2.Provider<_i1.PageFactory> {
  _PageFactory$Provider(
    this._clockNullable$Provider,
    this._reportBuilder$Provider,
  );

  final _ClockNullable$Provider _clockNullable$Provider;

  final _ReportBuilder$Provider _reportBuilder$Provider;

  late final _i1.PageFactory _factory = _PageFactory$Factory(
    _clockNullable$Provider,
    _reportBuilder$Provider,
  );

  @override
  _i1.PageFactory get() => _factory;
}

class _ReportBuilder$Provider implements _i2.Provider<_i1.ReportBuilder> {
  const _ReportBuilder$Provider(this._clockNullable$Provider);

  final _ClockNullable$Provider _clockNullable$Provider;

  @override
  _i1.ReportBuilder get() =>
      (String title) => _i1.Report(title, _clockNullable$Provider.get());
}

class _String$Provider implements _i2.Provider<String> {
  const _String$Provider(this._clockNullable$Provider, this._module);

  final _ClockNullable$Provider _clockNullable$Provider;

  final _i1.AppModule _module;

  @override
  String get() => _module.provideLabel(_clockNullable$Provider.get());
}
