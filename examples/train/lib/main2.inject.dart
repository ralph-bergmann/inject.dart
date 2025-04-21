// ignore_for_file: implementation_imports
// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:inject_annotation/inject_annotation.dart' as _i2;

import 'main2.dart' as _i1;

class MainComponent$Component implements _i1.MainComponent {
  factory MainComponent$Component.create({_i1.HttpClientModule? httpClientModule}) =>
      MainComponent$Component._(httpClientModule ?? _i1.HttpClientModule());

  MainComponent$Component._(_i1.HttpClientModule httpClientModule) {
    final loggingListener$Provider = _LoggingListener$Provider();
    final fooBar$Provider = _FooBar$Provider();
    final bar$Provider = _Bar$Provider(fooBar$Provider);
    final appListener$Provider = _AppListener$Provider(bar$Provider);
    _disposableListener$Provider = _DisposableListener$Provider();
    final foo$Provider = _Foo$Provider();
    _app$Provider = _App$Provider(foo$Provider);
    _httpClient$Provider = _HttpClient$Provider(httpClientModule);
  }

  late final _DisposableListener$Provider _disposableListener$Provider;

  late final _App$Provider _app$Provider;

  late final _HttpClient$Provider _httpClient$Provider;

  @override
  _i1.App get app => _app$Provider.get();

  @override
  _i1.HttpClient get httpClient => _httpClient$Provider.get();

  @override
  _i1.DisposableListener get disposableListener => _disposableListener$Provider.get();
}

class _LoggingListener$Provider implements _i2.Provider<_i1.LoggingListener> {
  _LoggingListener$Provider();

  _i1.LoggingListener? _singleton;

  @override
  _i1.LoggingListener get() => _singleton ??= _i1.LoggingListener();
}

class _FooBar$Provider implements _i2.Provider<_i1.FooBar> {
  const _FooBar$Provider();

  @override
  _i1.FooBar get() => _i1.FooBar();
}

class _Bar$Provider implements _i2.Provider<_i1.Bar> {
  const _Bar$Provider(this._fooBar$Provider);

  final _FooBar$Provider _fooBar$Provider;

  @override
  _i1.Bar get() => _i1.Bar(_fooBar$Provider.get());
}

class _AppListener$Provider implements _i2.Provider<_i1.AppListener> {
  _AppListener$Provider(this._bar$Provider);

  final _Bar$Provider _bar$Provider;

  _i1.AppListener? _singleton;

  @override
  _i1.AppListener get() => _singleton ??= _i1.AppListener(_bar$Provider.get());
}

class _DisposableListener$Provider implements _i2.Provider<_i1.DisposableListener> {
  _DisposableListener$Provider();

  _i1.DisposableListener? _singleton;

  @override
  _i1.DisposableListener get() => _singleton ??= _i1.DisposableListener();
}

class _Foo$Provider implements _i2.Provider<_i1.Foo> {
  const _Foo$Provider();

  @override
  _i1.Foo get() => _i1.Foo();
}

class _App$Provider implements _i2.Provider<_i1.App> {
  const _App$Provider(this._foo$Provider);

  final _Foo$Provider _foo$Provider;

  @override
  _i1.App get() => _i1.App(_foo$Provider.get());
}

class _HttpClient$Provider implements _i2.Provider<_i1.HttpClient> {
  _HttpClient$Provider(this._module);

  final _i1.HttpClientModule _module;

  _i1.HttpClient? _singleton;

  @override
  _i1.HttpClient get() => _singleton ??= _module.provideHttpClient();
}
