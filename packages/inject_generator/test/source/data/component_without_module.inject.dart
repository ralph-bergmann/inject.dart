// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'component_without_module.dart' as _i1;
import 'package:inject_annotation/inject_annotation.dart' as _i2;

class ComponentWithoutModule$Component implements _i1.ComponentWithoutModule {
  factory ComponentWithoutModule$Component.create() =>
      ComponentWithoutModule$Component._();

  ComponentWithoutModule$Component._() {
    _bar$Provider = _Bar$Provider();
    final foo$Provider = _Foo$Provider();
    _fooBar$Provider = _FooBar$Provider(
      foo$Provider,
      _bar$Provider,
    );
  }

  late final _Bar$Provider _bar$Provider;

  late final _FooBar$Provider _fooBar$Provider;

  @override
  _i1.Bar getBar() => _bar$Provider.get();

  @override
  _i1.FooBar getFooBar() => _fooBar$Provider.get();
}

class _Bar$Provider implements _i2.Provider<_i1.Bar> {
  const _Bar$Provider();

  @override
  _i1.Bar get() => _i1.Bar();
}

class _Foo$Provider implements _i2.Provider<_i1.Foo> {
  const _Foo$Provider();

  @override
  _i1.Foo get() => const _i1.Foo();
}

class _FooBar$Provider implements _i2.Provider<_i1.FooBar> {
  const _FooBar$Provider(
    this._foo$Provider,
    this._bar$Provider,
  );

  final _Foo$Provider _foo$Provider;

  final _Bar$Provider _bar$Provider;

  @override
  _i1.FooBar get() => _i1.FooBar(
        _foo$Provider.get(),
        _bar$Provider.get(),
      );
}
