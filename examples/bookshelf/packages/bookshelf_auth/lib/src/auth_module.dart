import 'package:bookshelf_api/bookshelf_api.dart';
import 'package:bookshelf_core/bookshelf_core.dart';
import 'package:inject_annotation/inject_annotation.dart';

/// Cross-package binding: depends on [BooksApi] (from `bookshelf_api`) and
/// [Logger] (from `bookshelf_core`) without depending on either package's
/// module — the app supplies both bindings by installing [ApiModule] and
/// [CoreModule]. `AuthRepository` never learns where they came from.
class AuthRepository {
  AuthRepository(this._api, this._logger);

  final BooksApi _api;
  final Logger _logger;

  /// Authenticates [username]/[password] and returns the resulting
  /// [Credentials] — the value that flows into the session subcomponent.
  Future<Credentials> login(String username, String password) async {
    final User user = User(username: username);
    _logger.log('authenticating ${user.username}');
    final String token = await _api.authenticate(username, password);
    return Credentials(username: username, token: token);
  }
}

@module
class AuthModule {
  @provides
  @singleton
  AuthRepository provideAuthRepository(BooksApi api, Logger logger) => AuthRepository(api, logger);
}
