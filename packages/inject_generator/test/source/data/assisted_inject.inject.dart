// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'assisted_inject.dart' as _i1;
import 'package:inject_annotation/inject_annotation.dart' as _i2;

class Component$Component implements _i1.Component {
  factory Component$Component.create() => Component$Component._();

  Component$Component._() {
    final foo$Provider = _Foo$Provider();
    _annotatedClassFactory$Provider =
        _AnnotatedClassFactory$Provider(foo$Provider);
    _annotatedConstructorFactory$Provider =
        _AnnotatedConstructorFactory$Provider(foo$Provider);
  }

  late final _AnnotatedClassFactory$Provider _annotatedClassFactory$Provider;

  late final _AnnotatedConstructorFactory$Provider
      _annotatedConstructorFactory$Provider;

  @override
  _i1.AnnotatedClassFactory get annotatedClassFactory =>
      _annotatedClassFactory$Provider.get();

  @override
  _i1.AnnotatedConstructorFactory get annotatedConstructorFactory =>
      _annotatedConstructorFactory$Provider.get();
}

class _Foo$Provider implements _i2.Provider<_i1.Foo> {
  const _Foo$Provider();

  @override
  _i1.Foo get() => _i1.Foo();
}

class _AnnotatedClassFactory$Provider
    implements _i2.Provider<_i1.AnnotatedClassFactory> {
  _AnnotatedClassFactory$Provider(this._foo$Provider);

  final _Foo$Provider _foo$Provider;

  late final _i1.AnnotatedClassFactory _factory =
      _AnnotatedClassFactory$Factory(_foo$Provider);

  @override
  _i1.AnnotatedClassFactory get() => _factory;
}

class _AnnotatedClassFactory$Factory implements _i1.AnnotatedClassFactory {
  const _AnnotatedClassFactory$Factory(this._foo$Provider);

  final _Foo$Provider _foo$Provider;

  @override
  _i1.AnnotatedClass create({required _i1.Bar bar}) => _i1.AnnotatedClass(
        _foo$Provider.get(),
        bar: bar,
      );
}

class _AnnotatedConstructorFactory$Provider
    implements _i2.Provider<_i1.AnnotatedConstructorFactory> {
  _AnnotatedConstructorFactory$Provider(this._foo$Provider);

  final _Foo$Provider _foo$Provider;

  late final _i1.AnnotatedConstructorFactory _factory =
      _AnnotatedConstructorFactory$Factory(_foo$Provider);

  @override
  _i1.AnnotatedConstructorFactory get() => _factory;
}

class _AnnotatedConstructorFactory$Factory
    implements _i1.AnnotatedConstructorFactory {
  const _AnnotatedConstructorFactory$Factory(this._foo$Provider);

  final _Foo$Provider _foo$Provider;

  @override
  _i1.AnnotatedConstructor create({required _i1.Bar bar}) =>
      _i1.AnnotatedConstructor(
        _foo$Provider.get(),
        bar: bar,
      );
}
