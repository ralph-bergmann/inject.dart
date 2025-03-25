// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'component_without_module.dart' as _i1;
import 'package:inject_annotation/inject_annotation.dart' as _i2;

class ComponentWithoutModule$Component implements _i1.ComponentWithoutModule {
  factory ComponentWithoutModule$Component.create() =>
      ComponentWithoutModule$Component._();

  ComponentWithoutModule$Component._() {
    _bar$Provider = _Bar$Provider();
  }

  late final _Bar$Provider _bar$Provider;

  @override
  _i1.Bar getBar() => _bar$Provider.get();
}

class _Bar$Provider implements _i2.Provider<_i1.Bar> {
  const _Bar$Provider();

  @override
  _i1.Bar get() => _i1.Bar();
}
