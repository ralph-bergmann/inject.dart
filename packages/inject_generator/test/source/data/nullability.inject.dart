// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'nullability.dart' as _i1;
import 'package:inject_annotation/inject_annotation.dart' as _i2;

class ComponentNullability$Component implements _i1.ComponentNullability {
  factory ComponentNullability$Component.create({_i1.BarModule? barModule}) =>
      ComponentNullability$Component._(barModule ?? _i1.BarModule());

  ComponentNullability$Component._(_i1.BarModule barModule) {
    _foo$Provider = _Foo$Provider(barModule);
    _bar$Provider = _Bar$Provider(barModule);
    _fooBar$Provider = _FooBar$Provider(
      _foo$Provider,
      _bar$Provider,
      barModule,
    );
  }

  late final _Foo$Provider _foo$Provider;

  late final _Bar$Provider _bar$Provider;

  late final _FooBar$Provider _fooBar$Provider;

  @override
  _i1.FooBar get fooBar => _fooBar$Provider.get();

  @override
  _i1.Foo get foo => _foo$Provider.get();

  @override
  _i1.Bar? get bar => _bar$Provider.get();
}

class _Foo$Provider implements _i2.Provider<_i1.Foo> {
  const _Foo$Provider(this._module);

  final _i1.BarModule _module;

  @override
  _i1.Foo get() => _module.foo();
}

class _Bar$Provider implements _i2.Provider<_i1.Bar?> {
  const _Bar$Provider(this._module);

  final _i1.BarModule _module;

  @override
  _i1.Bar? get() => _module.bar();
}

class _FooBar$Provider implements _i2.Provider<_i1.FooBar> {
  const _FooBar$Provider(
    this._foo$Provider,
    this._bar$Provider,
    this._module,
  );

  final _Foo$Provider _foo$Provider;

  final _Bar$Provider _bar$Provider;

  final _i1.BarModule _module;

  @override
  _i1.FooBar get() => _module.fooBar(
        _foo$Provider.get(),
        _bar$Provider.get(),
      );
}
