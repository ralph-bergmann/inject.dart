// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// Generator: inject.dart
// https://pub.dev/packages/inject_annotation
// **************************************************************************

// ignore_for_file: type=lint, type=warning
// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'package:inject_annotation/inject_annotation.dart' as _i2;

import 'provider_parameter_typedef_sync.dart' as _i1;

class AppComponent$Component implements _i1.AppComponent {
  factory AppComponent$Component.create() => AppComponent$Component._();

  AppComponent$Component._() {
    final clock$Provider = _Clock$Provider();
    final itemBuilder$Provider = _ItemBuilder$Provider(clock$Provider);
    _pageFactory$Provider = _PageFactory$Provider(itemBuilder$Provider);
  }

  late final _PageFactory$Provider _pageFactory$Provider;

  @override
  _i1.PageFactory get pageFactory => _pageFactory$Provider.get();
}

class _Clock$Provider implements _i2.Provider<_i1.Clock> {
  const _Clock$Provider();

  @override
  _i1.Clock get() => _i1.Clock();
}

class _ItemBuilder$Provider implements _i2.Provider<_i1.ItemBuilder> {
  const _ItemBuilder$Provider(this._clock$Provider);

  final _Clock$Provider _clock$Provider;

  @override
  _i1.ItemBuilder get() =>
      (String name) => _i1.Item(name, _clock$Provider);
}

class _PageFactory$Factory implements _i1.PageFactory {
  const _PageFactory$Factory(this._itemBuilder$Provider);

  final _ItemBuilder$Provider _itemBuilder$Provider;

  @override
  _i1.Page create(String title) => _i1.Page(_itemBuilder$Provider.get(), title);
}

class _PageFactory$Provider implements _i2.Provider<_i1.PageFactory> {
  _PageFactory$Provider(this._itemBuilder$Provider);

  final _ItemBuilder$Provider _itemBuilder$Provider;

  late final _i1.PageFactory _factory = _PageFactory$Factory(
    _itemBuilder$Provider,
  );

  @override
  _i1.PageFactory get() => _factory;
}
