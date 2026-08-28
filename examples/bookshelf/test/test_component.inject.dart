// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// Generator: inject.dart
// https://pub.dev/packages/inject_annotation
// **************************************************************************

// ignore_for_file: type=lint, type=warning
// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:ui' as _i16;

import 'package:bookshelf/src/app/app_module.dart' as _i5;
import 'package:bookshelf/src/login/auth_gate.dart' as _i7;
import 'package:bookshelf/src/login/login_page.dart' as _i13;
import 'package:bookshelf/src/login/login_view_model.dart' as _i15;
import 'package:bookshelf/src/session/book_repository.dart' as _i8;
import 'package:bookshelf/src/session/home_page.dart' as _i9;
import 'package:bookshelf/src/session/session_component.dart' as _i6;
import 'package:bookshelf_api/src/api_module.dart' as _i12;
import 'package:bookshelf_auth/src/auth_module.dart' as _i4;
import 'package:bookshelf_core/src/core_module.dart' as _i2;
import 'package:flutter/src/foundation/basic_types.dart' as _i14;
import 'package:flutter/src/foundation/key.dart' as _i10;
import 'package:flutter/src/widgets/framework.dart' as _i18;
import 'package:inject_annotation/inject_annotation.dart' as _i11;
import 'package:inject_flutter/src/view_model_factory.dart' as _i17;

import 'fake_books_api.dart' as _i3;
import 'test_component.dart' as _i1;

class TestComponent$Component implements _i1.TestComponent {
  factory TestComponent$Component.create({
    _i2.CoreModule? coreModule,
    _i3.FakeApiModule? fakeApiModule,
    _i4.AuthModule? authModule,
    _i5.AppModule? appModule,
  }) => TestComponent$Component._(
    coreModule ?? _i2.CoreModule(),
    fakeApiModule ?? _i3.FakeApiModule(),
    authModule ?? _i4.AuthModule(),
    appModule ?? _i5.AppModule(),
  );

  TestComponent$Component._(
    _i2.CoreModule coreModule,
    _i3.FakeApiModule fakeApiModule,
    _i4.AuthModule authModule,
    _i5.AppModule appModule,
  ) {
    _booksApi$Provider = _BooksApi$Provider(fakeApiModule);
    _logger$Provider = _Logger$Provider(coreModule);
    final authRepository$Provider = _AuthRepository$Provider(
      _booksApi$Provider,
      _logger$Provider,
      authModule,
    );
    final loginViewModel$Provider = _LoginViewModel$Provider(
      authRepository$Provider,
    );
    final viewModelFactoryOfLoginViewModel$Provider =
        _ViewModelFactoryOfLoginViewModel$Provider(loginViewModel$Provider);
    final loginPageFactory$Provider = _LoginPageFactory$Provider(
      viewModelFactoryOfLoginViewModel$Provider,
    );
    _sessionComponentFactory$Provider = _SessionComponentFactory$Provider(this);
    _authGateFactory$Provider = _AuthGateFactory$Provider(
      loginPageFactory$Provider,
      _sessionComponentFactory$Provider,
    );
  }

  late final _BooksApi$Provider _booksApi$Provider;

  late final _Logger$Provider _logger$Provider;

  late final _SessionComponentFactory$Provider
  _sessionComponentFactory$Provider;

  late final _AuthGateFactory$Provider _authGateFactory$Provider;

  @override
  _i6.SessionComponentFactory get sessionFactory =>
      _sessionComponentFactory$Provider.get();

  @override
  _i7.AuthGateFactory get authGateFactory => _authGateFactory$Provider.get();
}

class SessionComponent$Subcomponent implements _i6.SessionComponent {
  factory SessionComponent$Subcomponent.create(
    TestComponent$Component parent, {
    _i6.SessionModule? sessionModule,
    required _i2.Credentials credentials,
  }) => SessionComponent$Subcomponent._(
    parent,
    sessionModule ?? _i6.SessionModule(),
    credentials,
  );

  SessionComponent$Subcomponent._(
    this._parent,
    _i6.SessionModule sessionModule,
    this.credentials,
  ) {
    _sessionComponent$credentials$Provider =
        _SessionComponent$Credentials$Provider(credentials);
    _sessionComponent$bookRepository$Provider =
        _SessionComponent$BookRepository$Provider(
          _parent._booksApi$Provider,
          _sessionComponent$credentials$Provider,
          _parent._logger$Provider,
          sessionModule,
        );
    final sessionComponent$booksViewModel$Provider =
        _SessionComponent$BooksViewModel$Provider(
          _sessionComponent$bookRepository$Provider,
        );
    final sessionComponent$viewModelFactoryOfBooksViewModel$Provider =
        _SessionComponent$ViewModelFactoryOfBooksViewModel$Provider(
          sessionComponent$booksViewModel$Provider,
        );
    _sessionComponent$homePageFactory$Provider =
        _SessionComponent$HomePageFactory$Provider(
          sessionComponent$viewModelFactoryOfBooksViewModel$Provider,
        );
  }

  final TestComponent$Component _parent;

  final _i2.Credentials credentials;

  late final _SessionComponent$Credentials$Provider
  _sessionComponent$credentials$Provider;

  late final _SessionComponent$BookRepository$Provider
  _sessionComponent$bookRepository$Provider;

  late final _SessionComponent$HomePageFactory$Provider
  _sessionComponent$homePageFactory$Provider;

  @override
  _i8.BookRepository get bookRepository =>
      _sessionComponent$bookRepository$Provider.get();

  @override
  _i9.HomePageFactory get homePageFactory =>
      _sessionComponent$homePageFactory$Provider.get();
}

class _SessionComponentFactory$Factory implements _i6.SessionComponentFactory {
  const _SessionComponentFactory$Factory(this._parent);

  final TestComponent$Component _parent;

  @override
  _i6.SessionComponent create(_i2.Credentials credentials) =>
      SessionComponent$Subcomponent.create(_parent, credentials: credentials);
}

class _AuthGateFactory$Factory implements _i7.AuthGateFactory {
  const _AuthGateFactory$Factory(
    this._loginPageFactory$Provider,
    this._sessionComponentFactory$Provider,
  );

  final _LoginPageFactory$Provider _loginPageFactory$Provider;

  final _SessionComponentFactory$Provider _sessionComponentFactory$Provider;

  @override
  _i7.AuthGate create({_i10.Key? key}) => _i7.AuthGate(
    key: key,
    loginPageFactory: _loginPageFactory$Provider.get(),
    sessionFactory: _sessionComponentFactory$Provider.get(),
  );
}

class _AuthGateFactory$Provider implements _i11.Provider<_i7.AuthGateFactory> {
  _AuthGateFactory$Provider(
    this._loginPageFactory$Provider,
    this._sessionComponentFactory$Provider,
  );

  final _LoginPageFactory$Provider _loginPageFactory$Provider;

  final _SessionComponentFactory$Provider _sessionComponentFactory$Provider;

  late final _i7.AuthGateFactory _factory = _AuthGateFactory$Factory(
    _loginPageFactory$Provider,
    _sessionComponentFactory$Provider,
  );

  @override
  _i7.AuthGateFactory get() => _factory;
}

class _AuthRepository$Provider implements _i11.Provider<_i4.AuthRepository> {
  _AuthRepository$Provider(
    this._booksApi$Provider,
    this._logger$Provider,
    this._module,
  );

  final _BooksApi$Provider _booksApi$Provider;

  final _Logger$Provider _logger$Provider;

  final _i4.AuthModule _module;

  late final _i4.AuthRepository _singleton = _create();

  _i4.AuthRepository _create() => _module.provideAuthRepository(
    _booksApi$Provider.get(),
    _logger$Provider.get(),
  );

  @override
  _i4.AuthRepository get() => _singleton;
}

class _BooksApi$Provider implements _i11.Provider<_i12.BooksApi> {
  _BooksApi$Provider(this._module);

  final _i3.FakeApiModule _module;

  late final _i12.BooksApi _singleton = _create();

  _i12.BooksApi _create() => _module.provideApi();

  @override
  _i12.BooksApi get() => _singleton;
}

class _Logger$Provider implements _i11.Provider<_i2.Logger> {
  _Logger$Provider(this._module);

  final _i2.CoreModule _module;

  late final _i2.Logger _singleton = _create();

  _i2.Logger _create() => _module.provideLogger();

  @override
  _i2.Logger get() => _singleton;
}

class _LoginPageFactory$Factory implements _i13.LoginPageFactory {
  const _LoginPageFactory$Factory(
    this._viewModelFactoryOfLoginViewModel$Provider,
  );

  final _ViewModelFactoryOfLoginViewModel$Provider
  _viewModelFactoryOfLoginViewModel$Provider;

  @override
  _i13.LoginPage create({
    _i10.Key? key,
    required _i14.ValueChanged<_i2.Credentials> onLoggedIn,
  }) => _i13.LoginPage(
    key: key,
    viewModelFactory: _viewModelFactoryOfLoginViewModel$Provider.get(),
    onLoggedIn: onLoggedIn,
  );
}

class _LoginPageFactory$Provider
    implements _i11.Provider<_i13.LoginPageFactory> {
  _LoginPageFactory$Provider(this._viewModelFactoryOfLoginViewModel$Provider);

  final _ViewModelFactoryOfLoginViewModel$Provider
  _viewModelFactoryOfLoginViewModel$Provider;

  late final _i13.LoginPageFactory _factory = _LoginPageFactory$Factory(
    _viewModelFactoryOfLoginViewModel$Provider,
  );

  @override
  _i13.LoginPageFactory get() => _factory;
}

class _LoginViewModel$Provider implements _i11.Provider<_i15.LoginViewModel> {
  const _LoginViewModel$Provider(this._authRepository$Provider);

  final _AuthRepository$Provider _authRepository$Provider;

  @override
  _i15.LoginViewModel get() =>
      _i15.LoginViewModel(authRepository: _authRepository$Provider.get());
}

class _SessionComponent$BookRepository$Provider
    implements _i11.Provider<_i8.BookRepository> {
  _SessionComponent$BookRepository$Provider(
    this._booksApi$Provider,
    this._sessionComponent$credentials$Provider,
    this._logger$Provider,
    this._module,
  );

  final _BooksApi$Provider _booksApi$Provider;

  final _SessionComponent$Credentials$Provider
  _sessionComponent$credentials$Provider;

  final _Logger$Provider _logger$Provider;

  final _i6.SessionModule _module;

  late final _i8.BookRepository _singleton = _create();

  _i8.BookRepository _create() => _module.provideBookRepository(
    _booksApi$Provider.get(),
    _sessionComponent$credentials$Provider.get(),
    _logger$Provider.get(),
  );

  @override
  _i8.BookRepository get() => _singleton;
}

class _SessionComponent$BooksViewModel$Provider
    implements _i11.Provider<_i9.BooksViewModel> {
  const _SessionComponent$BooksViewModel$Provider(
    this._sessionComponent$bookRepository$Provider,
  );

  final _SessionComponent$BookRepository$Provider
  _sessionComponent$bookRepository$Provider;

  @override
  _i9.BooksViewModel get() => _i9.BooksViewModel(
    repository: _sessionComponent$bookRepository$Provider.get(),
  );
}

class _SessionComponent$Credentials$Provider
    implements _i11.Provider<_i2.Credentials> {
  const _SessionComponent$Credentials$Provider(this._value);

  final _i2.Credentials _value;

  @override
  _i2.Credentials get() => _value;
}

class _SessionComponent$HomePageFactory$Factory implements _i9.HomePageFactory {
  const _SessionComponent$HomePageFactory$Factory(
    this._sessionComponent$viewModelFactoryOfBooksViewModel$Provider,
  );

  final _SessionComponent$ViewModelFactoryOfBooksViewModel$Provider
  _sessionComponent$viewModelFactoryOfBooksViewModel$Provider;

  @override
  _i9.HomePage create({_i10.Key? key, required _i16.VoidCallback onLogout}) =>
      _i9.HomePage(
        key: key,
        viewModelFactory:
            _sessionComponent$viewModelFactoryOfBooksViewModel$Provider.get(),
        onLogout: onLogout,
      );
}

class _SessionComponent$HomePageFactory$Provider
    implements _i11.Provider<_i9.HomePageFactory> {
  _SessionComponent$HomePageFactory$Provider(
    this._sessionComponent$viewModelFactoryOfBooksViewModel$Provider,
  );

  final _SessionComponent$ViewModelFactoryOfBooksViewModel$Provider
  _sessionComponent$viewModelFactoryOfBooksViewModel$Provider;

  late final _i9.HomePageFactory _factory =
      _SessionComponent$HomePageFactory$Factory(
        _sessionComponent$viewModelFactoryOfBooksViewModel$Provider,
      );

  @override
  _i9.HomePageFactory get() => _factory;
}

class _SessionComponent$ViewModelFactoryOfBooksViewModel$Provider
    implements _i11.Provider<_i17.ViewModelFactory<_i9.BooksViewModel>> {
  const _SessionComponent$ViewModelFactoryOfBooksViewModel$Provider(
    this._sessionComponent$booksViewModel$Provider,
  );

  final _SessionComponent$BooksViewModel$Provider
  _sessionComponent$booksViewModel$Provider;

  @override
  _i17.ViewModelFactory<_i9.BooksViewModel> get() =>
      ({
        required _i17.ViewModelWidgetBuilder<_i9.BooksViewModel> builder,
        _i18.Widget? child,
        _i17.ViewModelErrorBuilder? error,
        _i17.ViewModelInitializer<_i9.BooksViewModel>? init,
        _i10.Key? key,
        _i18.Widget? loading,
      }) => _i17.ViewModelBuilder<_i9.BooksViewModel>(
        key: key,
        viewModelProvider: _sessionComponent$booksViewModel$Provider,
        init: init,
        loading: loading,
        error: error,
        builder: builder,
        child: child,
      );
}

class _SessionComponentFactory$Provider
    implements _i11.Provider<_i6.SessionComponentFactory> {
  _SessionComponentFactory$Provider(this._parent);

  final TestComponent$Component _parent;

  late final _i6.SessionComponentFactory _factory =
      _SessionComponentFactory$Factory(_parent);

  @override
  _i6.SessionComponentFactory get() => _factory;
}

class _ViewModelFactoryOfLoginViewModel$Provider
    implements _i11.Provider<_i17.ViewModelFactory<_i15.LoginViewModel>> {
  const _ViewModelFactoryOfLoginViewModel$Provider(
    this._loginViewModel$Provider,
  );

  final _LoginViewModel$Provider _loginViewModel$Provider;

  @override
  _i17.ViewModelFactory<_i15.LoginViewModel> get() =>
      ({
        required _i17.ViewModelWidgetBuilder<_i15.LoginViewModel> builder,
        _i18.Widget? child,
        _i17.ViewModelErrorBuilder? error,
        _i17.ViewModelInitializer<_i15.LoginViewModel>? init,
        _i10.Key? key,
        _i18.Widget? loading,
      }) => _i17.ViewModelBuilder<_i15.LoginViewModel>(
        key: key,
        viewModelProvider: _loginViewModel$Provider,
        init: init,
        loading: loading,
        error: error,
        builder: builder,
        child: child,
      );
}
