// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'parameter.dart' as _i1;
import 'package:inject/inject.dart' as _i2;

class ParameterComponent$Component implements _i1.ParameterComponent {
  factory ParameterComponent$Component.create(
          {_i1.Inject2Module? inject2Module}) =>
      ParameterComponent$Component._(inject2Module ?? _i1.Inject2Module());

  ParameterComponent$Component._(this._inject2Module) {
    _initialize();
  }

  final _i1.Inject2Module _inject2Module;

  late final _Dependency1$Provider _dependency1$Provider;

  late final _Inject1$Provider _inject1$Provider;

  late final _Inject4Factory$Provider _inject4Factory$Provider;

  late final _Inject3$Provider _inject3$Provider;

  late final _Inject2$Provider _inject2$Provider;

  void _initialize() {
    _dependency1$Provider = _Dependency1$Provider();
    _inject1$Provider = _Inject1$Provider(_dependency1$Provider);
    _inject4Factory$Provider = _Inject4Factory$Provider(_dependency1$Provider);
    _inject3$Provider = _Inject3$Provider(_inject4Factory$Provider);
    _inject2$Provider = _Inject2$Provider(
      _dependency1$Provider,
      _inject2Module,
    );
  }

  @override
  _i1.Inject1 get bar => _inject1$Provider.get();
  @override
  _i1.Inject2 get bar2 => _inject2$Provider.get();
  @override
  _i1.Inject3 get bar4 => _inject3$Provider.get();
}

class _Dependency1$Provider implements _i2.Provider<_i1.Dependency1> {
  const _Dependency1$Provider();

  @override
  _i1.Dependency1 get() => _i1.Dependency1();
}

class _Inject1$Provider implements _i2.Provider<_i1.Inject1> {
  const _Inject1$Provider(this._dependency1$Provider);

  final _Dependency1$Provider _dependency1$Provider;

  @override
  _i1.Inject1 get() => _i1.Inject1(
        _dependency1$Provider.get(),
        foo2: _dependency1$Provider.get(),
        foo3: _dependency1$Provider.get(),
      );
}

class _Inject4Factory$Provider implements _i2.Provider<_i1.Inject4Factory> {
  _Inject4Factory$Provider(this._dependency1$Provider);

  final _Dependency1$Provider _dependency1$Provider;

  _i1.Inject4Factory? _factory;

  @override
  _i1.Inject4Factory get() =>
      _factory ??= _Inject4Factory$Factory(_dependency1$Provider);
}

class _Inject4Factory$Factory implements _i1.Inject4Factory {
  const _Inject4Factory$Factory(this._dependency1$Provider);

  final _Dependency1$Provider _dependency1$Provider;

  @override
  _i1.Inject4 create(_i1.FoDependency2o2 foo) => _i1.Inject4(
        foo,
        _dependency1$Provider.get(),
        foo3: _dependency1$Provider.get(),
        foo4: _dependency1$Provider.get(),
      );
}

class _Inject3$Provider implements _i2.Provider<_i1.Inject3> {
  const _Inject3$Provider(this._inject4Factory$Provider);

  final _Inject4Factory$Provider _inject4Factory$Provider;

  @override
  _i1.Inject3 get() => _i1.Inject3(_inject4Factory$Provider.get());
}

class _Inject2$Provider implements _i2.Provider<_i1.Inject2> {
  const _Inject2$Provider(
    this._dependency1$Provider,
    this._module,
  );

  final _Dependency1$Provider _dependency1$Provider;

  final _i1.Inject2Module _module;

  @override
  _i1.Inject2 get() => _module.bar(
        _dependency1$Provider.get(),
        foo2: _dependency1$Provider.get(),
        foo3: _dependency1$Provider.get(),
      );
}
