import 'package:bookshelf_core/bookshelf_core.dart';
import 'package:inject_annotation/inject_annotation.dart';

/// Fake in-memory backend — no network, so the whole example runs offline.
///
/// A real implementation would wrap `package:http` or `package:dio`; the
/// shape stays identical either way: a plain class, constructed with its
/// config and collaborators, whose methods return [Future]s.
class BooksApi {
  BooksApi(this.baseUrl, this._logger);

  final String baseUrl;
  final Logger _logger;

  static const _passwords = {'alice': 'hunter2', 'bob': 'letmein'};

  static const _shelves = {
    'alice': [
      Book(title: 'Structure and Interpretation of Computer Programs', author: 'Abelson & Sussman'),
      Book(title: 'The Pragmatic Programmer', author: 'Hunt & Thomas'),
    ],
    'bob': [Book(title: 'Design Patterns', author: 'Gamma, Helm, Johnson & Vlissides')],
  };

  /// Validates [username]/[password] and returns an opaque session token.
  ///
  /// Throws [StateError] for unknown users or a wrong password — callers
  /// (see `AuthRepository.login`) turn that into a user-facing error.
  Future<String> authenticate(String username, String password) async {
    _logger.log('POST $baseUrl/login ($username)');
    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (_passwords[username] != password) {
      throw StateError('invalid credentials for $username');
    }
    return 'token-$username';
  }

  /// Returns the canned shelf for the user encoded in [token].
  Future<List<Book>> fetchBooks(String token) async {
    _logger.log('GET $baseUrl/books');
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final String username = token.replaceFirst('token-', '');
    return _shelves[username] ?? const [];
  }
}

/// Runtime-config channel: no default constructor, so wiring `MainComponent`
/// without a base URL is a compile-time error, not a runtime surprise.
///
/// ```dart
/// MainComponent.create(apiModule: const ApiModule('https://books.example.com'));
/// ```
@module
class ApiModule {
  const ApiModule(this.baseUrl);

  final String baseUrl;

  @provides
  @singleton
  BooksApi provideApi(Logger logger) => BooksApi(baseUrl, logger);
}
