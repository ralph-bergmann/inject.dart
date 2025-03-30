// ignore_for_file: implementation_imports
// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:inject_annotation/inject_annotation.dart' as _i2;

import 'singleton_inject.dart' as _i1;

class ComponentWithModule$Component implements _i1.ComponentWithModule {
  factory ComponentWithModule$Component.create({_i1.BarModule? barModule}) =>
      ComponentWithModule$Component._(barModule ?? _i1.BarModule());

  ComponentWithModule$Component._(_i1.BarModule barModule) {
    _foo$Provider = _Foo$Provider();
    _foo2$Provider = _Foo2$Provider();
    _bar$Provider = _Bar$Provider(
      _foo$Provider,
      barModule,
    );
  }

  late final _Foo$Provider _foo$Provider;

  late final _Foo2$Provider _foo2$Provider;

  late final _Bar$Provider _bar$Provider;

  @override
  _i1.Foo get foo => _foo$Provider.get();

  @override
  _i1.Foo2 get foo2 => _foo2$Provider.get();

  @override
  _i1.Bar get bar => _bar$Provider.get();
}

class _Foo$Provider implements _i2.Provider<_i1.Foo> {
  _Foo$Provider();

  _i1.Foo? _singleton;

  @override
  _i1.Foo get() => _singleton ??= _i1.Foo();
}

class _Foo2$Provider implements _i2.Provider<_i1.Foo2> {
  _Foo2$Provider();

  _i1.Foo2? _singleton;

  @override
  _i1.Foo2 get() => _singleton ??= const _i1.Foo2();
}

class _Bar$Provider implements _i2.Provider<_i1.Bar> {
  _Bar$Provider(
    this._foo$Provider,
    this._module,
  );

  final _Foo$Provider _foo$Provider;

  final _i1.BarModule _module;

  _i1.Bar? _singleton;

  @override
  _i1.Bar get() => _singleton ??= _module.bar(_foo$Provider.get());
}
