// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'component_with_module.dart' as _i1;
import 'package:inject_annotation/inject_annotation.dart' as _i2;

class ComponentWithModule$Component implements _i1.ComponentWithModule {
  factory ComponentWithModule$Component.create({_i1.BarModule? barModule}) =>
      ComponentWithModule$Component._(barModule ?? _i1.BarModule());

  ComponentWithModule$Component._(_i1.BarModule barModule) {
    _bar$Provider = _Bar$Provider(barModule);
  }

  late final _Bar$Provider _bar$Provider;

  @override
  _i1.Bar get bar => _bar$Provider.get();
}

class _Bar$Provider implements _i2.Provider<_i1.Bar> {
  _Bar$Provider(this._module);

  final _i1.BarModule _module;

  _i1.Bar? _singleton;

  @override
  _i1.Bar get() => _singleton ??= _module.provideBar();
}
