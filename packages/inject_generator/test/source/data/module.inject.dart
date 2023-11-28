// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'module.dart' as _i1;
import 'dart:async' as _i2;
import 'package:inject_annotation/inject_annotation.dart' as _i3;

class MainComponent$Component implements _i1.MainComponent {
  factory MainComponent$Component.create({_i1.MainModule? mainModule}) =>
      MainComponent$Component._(mainModule ?? _i1.MainModule());

  MainComponent$Component._(this._mainModule) {
    _initialize();
  }

  final _i1.MainModule _mainModule;

  late final _Addition$Provider _addition$Provider;

  late final _Foo$Provider _foo$Provider;

  late final _Bar$Provider _bar$Provider;

  void _initialize() {
    _addition$Provider = _Addition$Provider(_mainModule);
    _foo$Provider = _Foo$Provider(_mainModule);
    _bar$Provider = _Bar$Provider(
      _foo$Provider,
      _mainModule,
    );
  }

  @override
  _i1.Addition get add => _addition$Provider.get();

  @override
  _i1.Foo get foo => _foo$Provider.get();

  @override
  _i2.Future<_i1.Bar> get bar => _bar$Provider.get();
}

class _Addition$Provider implements _i3.Provider<_i1.Addition> {
  const _Addition$Provider(this._module);

  final _i1.MainModule _module;

  @override
  _i1.Addition get() => _module.provideAddition();
}

class _Foo$Provider implements _i3.Provider<_i1.Foo> {
  _Foo$Provider(this._module);

  final _i1.MainModule _module;

  _i1.Foo? _singleton;

  @override
  _i1.Foo get() => _singleton ??= _module.provideFoo();
}

class _Bar$Provider implements _i3.Provider<_i2.Future<_i1.Bar>> {
  const _Bar$Provider(
    this._foo$Provider,
    this._module,
  );

  final _Foo$Provider _foo$Provider;

  final _i1.MainModule _module;

  @override
  _i2.Future<_i1.Bar> get() async =>
      await _module.provideBar(foo: _foo$Provider.get());
}
